import test from 'node:test';
import assert from 'node:assert/strict';
import {seed,reviewQuest,recommend} from '../src/domain.js';
test('review requires authorised role',()=>assert.throws(()=>reviewQuest(seed(),'q2','student','verified','Good evidence',[3,3,3]),/permission/));
test('review requires all criteria',()=>assert.throws(()=>reviewQuest(seed(),'q2','teacher','verified','Good evidence',[0,3,3]),/criteria/));
test('approval records feedback and issues one reward',()=>{const d=reviewQuest(seed(),'q2','teacher','verified','Clear example',[3,3,3]);assert.equal(d.quests.find(q=>q.id==='q2').status,'verified');assert.equal(d.rewards.filter(r=>r.quest==='q2').length,1);assert.throws(()=>reviewQuest(d,'q2','teacher','verified','Again',[3,3,3]),/submitted/)});
test('revision does not grant points',()=>{const d=reviewQuest(seed(),'q2','teacher','changes_requested','Add a clearer example',[]);assert.equal(d.quests.find(q=>q.id==='q2').status,'changes_requested');assert.equal(d.rewards.filter(r=>r.quest==='q2').length,0)});
test('short availability selects a smaller activity',()=>{const d=seed();const r=recommend(d.profiles.find(p=>p.id==='meera'),d.quests);assert.equal(r.quest.id,'q6');assert.match(r.reason,/shorter/)});
test('verified activities are not recommended',()=>{const d=seed();const r=recommend(d.profiles.find(p=>p.id==='kabir'),d.quests);assert.equal(r.quest,undefined)});
