import test from 'node:test';
import assert from 'node:assert/strict';
import handler from '../api/recommend.js';
function response(){return {code:0,body:null,headers:{},setHeader(k,v){this.headers[k]=v;},status(c){this.code=c;return this;},json(b){this.body=b;return this;}}}
test('recommend rejects non-POST',async()=>{const r=response();await handler({method:'GET'},r);assert.equal(r.code,405);assert.equal(r.headers.Allow,'POST');});
test('recommend reports missing setup without calling AI',async()=>{const r=response();const old=process.env.SUPABASE_URL;delete process.env.SUPABASE_URL;try{await handler({method:'POST',headers:{}},r);assert.equal(r.code,503);assert.equal(r.body.code,'SETUP_REQUIRED');}finally{if(old!==undefined)process.env.SUPABASE_URL=old;}});
