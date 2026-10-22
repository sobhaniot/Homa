// آزمون DOM با پاسخ‌های ساختگی؛ هیچ شبکه یا فرمان دستگاه واقعی استفاده نمی‌شود.
const fs=require('fs'),path=require('path'),assert=require('assert/strict');
const {JSDOM}=require('C:/Users/Sobhan/node_modules/jsdom');
const root=path.resolve(__dirname,'../web');
const dom=new JSDOM(fs.readFileSync(path.join(root,'index.html'),'utf8'),{url:'http://homa.test/',runScripts:'outside-only'});
const w=dom.window,requests=[];
const moduleData={id:'fridge-test',name:'یخچال تست',kind:'refrigerator',route:'local',request_topic:'test/info',response_topic:'test/result',request_payload:'{"type":"Info"}',interval:300,timeout:120,enabled:true,polling:true,share:'off',temperature:9,hysteresis:1,
  latest:{ts:123,payload:'{"TempIn":8.5,"Temp":9,"Hyster":1}',parsed:null},online:true,
  ui:{columns:2,order:0,refresh_seconds:30,revision:'test-revision',fields:[
    {key:'TempIn',label:'دمای داخل',type:'number',inferred:true,value:8.5,visible:true,editable:false},
    {key:'Temp',label:'دما',type:'number',value:9,visible:true,editable:true,min:-50,max:80,step:0.1},
    {key:'Hyster',label:'هیسترسیس',type:'number',value:1,visible:true,editable:true,min:0.1,max:30,step:0.1}]}};
w.setInterval=()=>0;w.setTimeout=()=>0;w.confirm=()=>true;
w.HomaDate={init(){},format(v){return String(v);},fa(v){return String(v);}};
w.XMLHttpRequest=class {
  open(method,url){this.method=method;this.url=url;}setRequestHeader(){}
  send(raw){const data=raw===null?null:JSON.parse(raw);requests.push({method:this.method,url:this.url,data});this.status=200;
    let body={};if(this.url==='/api/auth-mode')body={required:false};
    else if(this.url==='/api/config')body={external:{host:'test',port:1883,enabled:true,client_id:'test',username:'',tls:false},retention_days:30,installation:'test'};
    else if(this.url==='/api/status')body={brokers:{local:{connected:true},external:{connected:true}},disk_free:100,database_bytes:1,uptime:60};
    else if(this.url==='/api/modules')body=this.method==='GET'?[moduleData]:data;
    else if(this.url.endsWith('/settings')){body={queued:true,device_acknowledged:false};this.status=202;}
    this.responseText=JSON.stringify(body);this.onload();
  }
};
w.eval(fs.readFileSync(path.join(root,'schema.js'),'utf8'));
w.eval(fs.readFileSync(path.join(root,'app.js'),'utf8'));
assert.equal(w.document.querySelectorAll('#moduleCards article').length,1,'anonymous fresh browser loads module list');
w.document.querySelector('#moduleCards .heading button').click();
assert.equal(w.document.querySelectorAll('.schema-field').length,3);
assert.equal(w.document.querySelector('.schema-field select').value,'auto','inferred type stays automatic when saved');
w.document.querySelector('.schema-field input[type=checkbox]').checked=false;
w.document.getElementById('moduleForm').dispatchEvent(new w.Event('submit',{bubbles:true,cancelable:true}));
const saved=requests.find(r=>r.method==='PUT'&&r.url==='/api/modules').data;
assert.equal(saved.fields[0].visible,false);assert.equal(saved.fields[0].type,'auto');
assert.equal(saved.apply_parameters,undefined,'layout save never sends operational parameters');
assert.equal(requests.some(r=>r.url.endsWith('/settings')),false);
w.document.querySelector('#moduleCards .heading button').click();
const label=Array.from(w.document.querySelectorAll('.schema-editor label')).find(l=>l.firstChild.nodeValue==='دما');
assert.equal(label.querySelector('input').type,'number');label.querySelector('input').value='8';
Array.from(w.document.querySelectorAll('.schema-editor button')).find(b=>b.textContent==='ارسال مقادیر به دستگاه').click();
const command=requests.find(r=>r.url.endsWith('/settings')).data;
assert.equal(command.schema_revision,'test-revision');assert.equal(command.confirm,true);assert.equal(command.values.Temp,8);
assert.equal(w.document.querySelectorAll('#moduleCards .value').length,3);
dom.window.close();console.log('Web schema: anonymous catalog, inference, selection, safe save and explicit typed command OK');
