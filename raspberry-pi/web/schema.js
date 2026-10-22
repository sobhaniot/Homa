/* مرجع فرم و چیدمان روی رزبری است؛ نمایشگرها فقط قرارداد را رندر می‌کنند. */
var HomaSchema=(function(){
  'use strict';
  var host=document.createElement('section'), rows=[], current=null, send=null, notify=null;
  host.className='schema-editor';
  document.getElementById('moduleForm').insertBefore(host,document.getElementById('saveModule'));
  document.getElementById('moduleTemp').parentNode.hidden=true;
  document.getElementById('moduleHyster').parentNode.hidden=true;
  var notice=document.querySelector('#moduleForm .notice');notice.textContent='ذخیرهٔ کارت فقط تعریف نمایش را تغییر می‌دهد. ارسال مقادیر به دستگاه دکمه و تأیید جدا دارد.';
  function node(tag,text){var n=document.createElement(tag);if(text!==undefined)n.textContent=text;return n;}
  function input(parent,label,value,type){var l=node('label',label),i=node('input');i.type=type||'text';if(i.type==='checkbox')i.checked=!!value;else i.value=value===undefined||value===null?'':value;l.appendChild(i);parent.appendChild(l);return i;}
  function add(field){var card=node('div'),row={};card.className='schema-field';
    row.key=input(card,'کلید پیام',field.key);row.label=input(card,'عنوان',field.label);
    var l=node('label','نوع ورودی'),s=node('select');[['auto','تشخیص خودکار'],['number','اعشاری'],['integer','صحیح'],['text','متن'],['boolean','روشن/خاموش']].forEach(function(pair){var o=node('option',pair[1]);o.value=pair[0];s.appendChild(o);});s.value=field.inferred?'auto':(field.type||'auto');l.appendChild(s);card.appendChild(l);row.type=s;
    row.unit=input(card,'واحد',field.unit||'');row.visible=input(card,'نمایش',field.visible!==false,'checkbox');row.editable=input(card,'قابل تنظیم با Param',field.editable===true,'checkbox');
    row.min=input(card,'کمینه',field.min,'number');row.max=input(card,'بیشینه',field.max,'number');row.step=input(card,'گام',field.step,'number');[row.min,row.max,row.step].forEach(function(i){i.step='any';});
    var b=node('button','حذف فیلد');b.type='button';b.className='secondary';b.onclick=function(){card.remove();rows=rows.filter(function(r){return r!==row;});};card.appendChild(b);
    ['بالا','پایین'].forEach(function(label,index){var move=node('button',label);move.type='button';move.className='secondary';move.onclick=function(){var from=rows.indexOf(row),to=from+(index?1:-1);if(to<0||to>=rows.length)return;rows.splice(from,1);rows.splice(to,0,row);rows.forEach(function(r){document.getElementById('schemaRows').appendChild(r.card);});};card.appendChild(move);});row.card=card;rows.push(row);document.getElementById('schemaRows').appendChild(card);
  }
  var columns,order,interval;
  function open(module,api,message){current=module;send=api;notify=message;host.textContent='';rows=[];
    host.appendChild(node('h3','چیدمان و فیلدهای مشترک همهٔ نمایشگرها'));
    host.appendChild(node('p','نوع از آخرین پیام پیشنهاد می‌شود. فقط فیلدی را قابل تنظیم کنید که فریم‌ور واقعاً در پیام Param می‌پذیرد. انتخاب نوع و حدود را پیش از ذخیره بررسی کنید.'));
    var ui=module&&module.ui||{columns:2,order:0,refresh_seconds:30,fields:[]},layout=node('div');layout.className='fields';
    columns=input(layout,'ستون‌های اطلاعات (۱ یا ۲)',ui.columns,'number');columns.min='1';columns.max='2';order=input(layout,'ترتیب کارت',ui.order,'number');order.min='0';interval=input(layout,'فاصلهٔ تازه‌خوانی نمایشگر (ثانیه)',ui.refresh_seconds,'number');interval.min='5';host.appendChild(layout);
    var list=node('div');list.id='schemaRows';host.appendChild(list);(ui.fields||[]).forEach(add);
    var plus=node('button','+ فیلد دستی');plus.type='button';plus.onclick=function(){add({key:'',label:'',type:'auto',visible:true});};host.appendChild(plus);
    var detect=node('button','دریافت نمونه و تشخیص فیلدها');detect.type='button';detect.className='secondary';detect.onclick=function(){if(!current)return notify('ابتدا کارت و تاپیک‌هایش را ذخیره کنید؛ سپس بعد از دریافت اولین پاسخ، کارت را دوباره باز کنید.');send('POST','/api/modules/'+current.id+'/request',{},function(error){notify(error||'درخواست اطلاعات فرستاده شد؛ پس از دریافت پاسخ کارت را ببندید و دوباره باز کنید.');});};host.appendChild(detect);
    if(!ui.fields.length)host.appendChild(node('p','هنوز پیام نمونه نداریم. کارت را ذخیره کنید و پس از اولین پاسخ باز کنید؛ یا فیلد را دستی تعریف کنید.'));
    var editable=(ui.fields||[]).filter(function(f){return f.editable;});if(!editable.length||!current)return;
    host.appendChild(node('h3','مقادیر قابل تنظیم دستگاه'));var values=[],box=node('div');box.className='fields';editable.forEach(function(f){var i=input(box,f.label,f.value,f.type==='boolean'?'checkbox':f.type==='text'?'text':'number');if(i.type==='number'){i.step=f.type==='integer'?'1':(f.step||'any');if(f.min!==undefined)i.min=f.min;if(f.max!==undefined)i.max=f.max;}values.push({field:f,input:i});});host.appendChild(box);
    var apply=node('button','ارسال مقادیر به دستگاه');apply.type='button';apply.onclick=function(){var data={};for(var i=0;i<values.length;i++){var item=values[i],f=item.field,v=item.input;if(v.type==='checkbox')data[f.key]=v.checked;else if(f.type==='text')data[f.key]=v.value;else {if(v.value.trim()===''||!isFinite(Number(v.value)))return notify('مقدار '+f.label+' نامعتبر است');data[f.key]=Number(v.value);}}for(var vi=0;vi<values.length;vi++){var vf=values[vi].field,oldValue=vf.type==='boolean'?vf.value===true:vf.value;if((vf.type==='number'||vf.type==='integer')&&oldValue!==null&&oldValue!==undefined)oldValue=Number(oldValue);if(data[vf.key]===oldValue)delete data[vf.key];}if(!Object.keys(data).length)return notify('مقداری تغییر نکرده است');if(!confirm('این مقادیر واقعاً برای دستگاه ارسال شوند؟'))return;apply.disabled=true;send('POST','/api/modules/'+current.id+'/settings',{values:data,confirm:true,schema_revision:ui.revision},function(error){apply.disabled=false;notify(error||'در صف ارسال قرار گرفت؛ هنوز تأیید دریافت دستگاه نیست.');});};host.appendChild(apply);
  }
  function read(data){data.columns=Number(columns.value);data.order=Number(order.value);data.client_interval=Number(interval.value);data.fields=rows.map(function(r){var f={key:r.key.value.trim(),label:r.label.value.trim(),type:r.type.value,visible:r.visible.checked,editable:r.editable.checked,unit:r.unit.value};['min','max','step'].forEach(function(k){if(r[k].value!=='')f[k]=Number(r[k].value);});return f;});}
  return {open:open,read:read};
}());
