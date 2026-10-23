import type {SupabaseClient} from '@supabase/supabase-js';
// Integration entry points: UI wiring is pending project access and RLS validation.
export function createEducationRepository(client:SupabaseClient){
 const db=client.schema('education');
 return {
  async profile(userId:string){const {data,error}=await db.from('profiles').select('*').eq('id',userId).single();if(error)throw error;return data;},
  async quests(){const {data,error}=await db.from('quests').select('*');if(error)throw error;return data;},
  async submit(questId:string,body:string){const {error}=await db.rpc('submit_evidence',{qid:questId,body});if(error)throw error;},
  async review(questId:string,decision:'verified'|'changes_requested',note:string,scores:number[]){const {error}=await db.rpc('review_evidence',{qid:questId,decision,note,scores});if(error)throw error;},
  async parentSummary(studentId:string){const {data,error}=await db.rpc('parent_summary',{learner:studentId});if(error)throw error;return data;},
  async recommendation(){const {data,error}=await client.functions.invoke('recommend');if(error)throw error;return data;},
  async upload(userId:string,file:File){if(file.size>5242880)throw Error('Maximum file size: 5 MB');const path=`${userId}/${crypto.randomUUID()}/${file.name.replace(/[^a-zA-Z0-9._-]/g,'_')}`;const {error}=await client.storage.from('education-evidence').upload(path,file,{upsert:false});if(error)throw error;return path;}
 };
}
