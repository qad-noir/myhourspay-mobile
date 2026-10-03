const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync('web/google_auth_frame.html','utf8').match(/<script>([\s\S]*?)<\/script>/)[1];
function frame(nonce) {
  let options, renders = 0, completed;
  const google = {accounts:{id:{initialize(value){options=value;},renderButton(){renders++;}}}};
  const context = {window:{google},google,document:{getElementById(){return {}; }},TextDecoder,Uint8Array,atob};
  vm.createContext(context); vm.runInContext(source,context);
  context.window.mhpInitializeGoogle('fixture-client',nonce,value=>completed=value);
  return {context,options,get renders(){return renders;},get completed(){return completed;}};
}
test('each browser attempt initializes a new GIS document with the unchanged nonce',()=>{
  const first=frame('1'.padStart(64,'0')),second=frame('2'.padStart(64,'0'));
  assert.notEqual(first.options.nonce,second.options.nonce);
  assert.equal(first.options.nonce,'1'.padStart(64,'0'));
  assert.equal(first.options.auto_select,false);
  assert.equal(first.renders,1);
  first.context.window.mhpInitializeGoogle('fixture-client','other',()=>{});
  assert.equal(first.renders,1);
});
test('browser credential callback returns transient token and Google display name',()=>{
  const attempt=frame('1'.padStart(64,'0'));
  const payload=Buffer.from(JSON.stringify({name:'Fixture Name'})).toString('base64url');
  attempt.options.callback({credential:`header.${payload}.signature`});
  assert.equal(attempt.completed.name,'Fixture Name');
  assert.equal(attempt.completed.idToken,`header.${payload}.signature`);
});
