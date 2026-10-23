-- Apply to a dedicated prototype project. No existing tables are modified.
create schema if not exists education;
create table education.institutions(id uuid primary key default gen_random_uuid(), name text not null);
create table education.memberships(id uuid primary key default gen_random_uuid(),institution_id uuid not null references education.institutions(id),user_id uuid not null references auth.users(id),role text not null check(role in ('student','teacher','mentor','parent','counsellor','admin')),unique(institution_id,user_id,role));
create table education.profiles(id uuid primary key references auth.users(id),institution_id uuid not null references education.institutions(id),name text not null,section text not null default '',goal text not null default '',minutes integer not null default 30 check(minutes between 5 and 120),interest text not null default '');
create table education.relationships(institution_id uuid not null references education.institutions(id),staff_id uuid not null references auth.users(id),student_id uuid not null references education.profiles(id),relationship text not null check(relationship in ('teacher','mentor','parent','counsellor')),primary key(institution_id,staff_id,student_id,relationship));
create table education.quests(id uuid primary key default gen_random_uuid(),institution_id uuid not null references education.institutions(id),student_id uuid not null references education.profiles(id),reviewer_id uuid not null references auth.users(id),title text not null,attribute text not null check(attribute in ('Fitness','Intellectual','Emotional','Social','Spiritual')),skill text not null,description text not null,criteria jsonb not null check(jsonb_array_length(criteria)=3),framework_version text not null default '1.0',minutes integer not null check(minutes>0),xp integer not null default 20 check(xp between 0 and 200),status text not null default 'assigned' check(status in ('assigned','submitted','changes_requested','verified')),evidence text not null default '',feedback text not null default '',ratings integer[],submitted_at timestamptz,reviewed_at timestamptz);
create table education.reviews(id uuid primary key default gen_random_uuid(),quest_id uuid not null references education.quests(id),reviewer_id uuid not null references auth.users(id),decision text not null check(decision in ('verified','changes_requested')),feedback text not null,ratings integer[],created_at timestamptz not null default now());
create table education.rewards(quest_id uuid primary key references education.quests(id),student_id uuid not null references education.profiles(id),points integer not null,created_at timestamptz not null default now());
create table education.reflections(id uuid primary key default gen_random_uuid(),student_id uuid not null references education.profiles(id),body text not null,created_at timestamptz not null default now());
create table education.interventions(id uuid primary key default gen_random_uuid(),institution_id uuid not null references education.institutions(id),student_id uuid not null references education.profiles(id),owner_id uuid not null references auth.users(id),reason text not null,action text not null,status text not null default 'open' check(status in ('open','completed')),created_at timestamptz not null default now());
create table education.ai_usage(user_id uuid not null references auth.users(id),day date not null default current_date,count integer not null default 1,primary key(user_id,day));
-- Memberships and relationships are provisioned by an authorised administrator via a server management path.
create function education.is_member(inst uuid) returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from education.memberships where institution_id=inst and user_id=auth.uid())$$;
create function education.can_support(inst uuid, learner uuid) returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from education.relationships r join education.memberships m on m.user_id=r.staff_id and m.institution_id=r.institution_id and m.role=r.relationship where r.institution_id=inst and r.student_id=learner and r.staff_id=auth.uid() and r.relationship in ('teacher','mentor'))$$;
create function education.can_view_shared(inst uuid, learner uuid) returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from education.relationships r join education.memberships m on m.user_id=r.staff_id and m.institution_id=r.institution_id and m.role=r.relationship where r.institution_id=inst and r.student_id=learner and r.staff_id=auth.uid() and r.relationship='parent')$$;
alter table education.institutions enable row level security;
alter table education.memberships enable row level security;
alter table education.profiles enable row level security;
alter table education.relationships enable row level security;
alter table education.quests enable row level security;
alter table education.reviews enable row level security;
alter table education.rewards enable row level security;
alter table education.reflections enable row level security;
alter table education.interventions enable row level security;
alter table education.ai_usage enable row level security;
create policy institution_read on education.institutions for select to authenticated using(education.is_member(id));
create policy membership_self on education.memberships for select to authenticated using(user_id=auth.uid());
create policy relationship_self on education.relationships for select to authenticated using(staff_id=auth.uid() or student_id=auth.uid());
create policy profile_read on education.profiles for select to authenticated using(id=auth.uid() or education.can_support(institution_id,id) or education.can_view_shared(institution_id,id));
create policy profile_update on education.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());
create policy quest_read on education.quests for select to authenticated using(student_id=auth.uid() or education.can_support(institution_id,student_id));
create policy review_read on education.reviews for select to authenticated using(exists(select 1 from education.quests q where q.id=quest_id));
create policy reward_read on education.rewards for select to authenticated using(student_id=auth.uid() or exists(select 1 from education.profiles p where p.id=student_id and education.can_support(p.institution_id,p.id)));
create policy reflection_own on education.reflections for all to authenticated using(student_id=auth.uid()) with check(student_id=auth.uid());
create policy intervention_read on education.interventions for select to authenticated using(student_id=auth.uid() or owner_id=auth.uid());
create policy intervention_create on education.interventions for insert to authenticated with check(owner_id=auth.uid() and education.can_support(institution_id,student_id));
create policy intervention_update on education.interventions for update to authenticated using(owner_id=auth.uid() and education.can_support(institution_id,student_id)) with check(owner_id=auth.uid() and education.can_support(institution_id,student_id));
create function education.submit_evidence(qid uuid, body text) returns void language plpgsql security definer set search_path='' as $$begin
 if length(trim(body))<30 or length(body)>20000 then raise exception 'Evidence must contain 30–20000 characters';end if;
 update education.quests set evidence=body,status='submitted',submitted_at=now() where id=qid and student_id=auth.uid() and education.is_member(institution_id) and status in ('assigned','changes_requested');
 if not found then raise exception 'Submission is not permitted';end if;
end$$;
create function education.review_evidence(qid uuid, decision text, note text, scores integer[]) returns void language plpgsql security definer set search_path='' as $$declare q education.quests;begin
 select * into q from education.quests where id=qid for update;
 if q.id is null or q.reviewer_id<>auth.uid() or not education.can_support(q.institution_id,q.student_id) then raise exception 'Review not permitted';end if;
 if q.status<>'submitted' then raise exception 'Already reviewed or not submitted';end if;
 if decision not in ('verified','changes_requested') or length(trim(note))<3 then raise exception 'Invalid decision or feedback';end if;
 if decision='verified' and (scores is null or cardinality(scores)<>3 or array_position(scores,null) is not null or not(scores <@ array[1,2,3,4])) then raise exception 'Three rubric scores from 1 to 4 required';end if;
 insert into education.reviews(quest_id,reviewer_id,decision,feedback,ratings) values(qid,auth.uid(),decision,note,scores);
 update education.quests set status=decision,feedback=note,ratings=scores,reviewed_at=now() where id=qid;
 if decision='verified' then insert into education.rewards(quest_id,student_id,points) values(qid,q.student_id,q.xp) on conflict(quest_id) do nothing;end if;
end$$;
-- Parent summaries exclude evidence bodies, reflections and non-shared records.
create function education.parent_summary(learner uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$declare p education.profiles;begin
 select * into p from education.profiles where id=learner;
 if p.id is null or not education.can_view_shared(p.institution_id,learner) then raise exception 'Not permitted';end if;
 return jsonb_build_object('name',p.name,'goal',p.goal,'achievements',coalesce((select jsonb_agg(jsonb_build_object('title',q.title,'skill',q.skill,'attribute',q.attribute,'reviewed_at',q.reviewed_at)) from education.quests q where q.student_id=learner and q.status='verified'),'[]'::jsonb));end$$;
create function education.consume_ai_budget() returns boolean language plpgsql security definer set search_path='' as $$declare used integer;begin
 if auth.uid() is null then return false;end if;
 insert into education.ai_usage(user_id,day,count) values(auth.uid(),current_date,1) on conflict(user_id,day) do update set count=education.ai_usage.count+1 where education.ai_usage.count<20 returning count into used;
 return used is not null;
end$$;
revoke all on all functions in schema education from public,anon;
grant usage on schema education to authenticated;
grant select on education.institutions,education.memberships,education.profiles,education.relationships,education.quests,education.reviews,education.rewards,education.interventions to authenticated;
grant update(goal,minutes,interest) on education.profiles to authenticated;
grant select,insert,update,delete on education.reflections to authenticated;
grant insert on education.interventions to authenticated;
grant update(status) on education.interventions to authenticated;
grant execute on function education.is_member(uuid),education.can_support(uuid,uuid),education.can_view_shared(uuid,uuid),education.submit_evidence(uuid,text),education.review_evidence(uuid,text,text,integer[]),education.parent_summary(uuid),education.consume_ai_budget() to authenticated;
-- No authenticated direct writes to quests, reviews or rewards. Only validated RPCs.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('education-evidence','education-evidence',false,5242880,array['application/pdf','image/png','image/jpeg','text/plain']) on conflict(id) do nothing;
create policy education_upload_own on storage.objects for insert to authenticated with check(bucket_id='education-evidence' and (storage.foldername(name))[1]=auth.uid()::text);
create policy education_read_own on storage.objects for select to authenticated using(bucket_id='education-evidence' and (storage.foldername(name))[1]=auth.uid()::text);
-- Reviewer downloads need an evidence-object relationship and a reviewed access policy before enabling file-based assessment.
