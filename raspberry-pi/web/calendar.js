/* تقویم شمسی محلی؛ تبدیل تاریخ با jalaali-js 1.2.8 و بدون وابستگی اینترنتی. */
(function(root,factory){if(typeof module==='object'&&module.exports)module.exports=factory(require('./jalaali.js'));else root.HomaDate=factory(root.jalaali);}(typeof window!=='undefined'?window:this,function(jalaali){
'use strict';
var months=['فروردین','اردیبهشت','خرداد','تیر','مرداد','شهریور','مهر','آبان','آذر','دی','بهمن','اسفند'];
function fa(value){return String(value).replace(/[0-9]/g,function(d){return '۰۱۲۳۴۵۶۷۸۹'.charAt(Number(d));});}
function latin(value){return String(value).replace(/[۰-۹]/g,function(d){return String('۰۱۲۳۴۵۶۷۸۹'.indexOf(d));}).replace(/[٠-٩]/g,function(d){return String('٠١٢٣٤٥٦٧٨٩'.indexOf(d));});}
function pad(v){return (v<10?'0':'')+v;}
var formatter=null;
try{if(typeof Intl!=='undefined'){formatter=new Intl.DateTimeFormat('en-GB',{timeZone:'Asia/Tehran',year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',second:'2-digit',hour12:false});if(!formatter.formatToParts)formatter=null;}}catch(ignore){formatter=null;}
function parts(ts){
  if(formatter){var values={},list=formatter.formatToParts(new Date(ts*1000));for(var i=0;i<list.length;i++)values[list[i].type]=list[i].value;return {gy:Number(values.year),gm:Number(values.month),gd:Number(values.day),h:Number(values.hour)%24,min:Number(values.minute),s:Number(values.second)};}
  // مرورگر قدیمی فاقد Intl: داده‌های فعلی پروژه مربوط به سال‌های پس از ۲۰۲۳
  // هستند که ساعت ایران در تمام سال UTC+03:30 است. مرز فیلتر روز در سرور محاسبه می‌شود.
  var d=new Date(ts*1000+210*60000);return {gy:d.getUTCFullYear(),gm:d.getUTCMonth()+1,gd:d.getUTCDate(),h:d.getUTCHours(),min:d.getUTCMinutes(),s:d.getUTCSeconds()};
}
function today(ts){var p=parts(ts===undefined?Date.now()/1000:ts);return jalaali.toJalaali(p.gy,p.gm,p.gd);}
function inputDate(j){return fa(j.jy+'/'+pad(j.jm)+'/'+pad(j.jd));}
function format(ts){if(ts===null||ts===undefined)return 'هنوز دریافت نشده';var p=parts(ts),j=jalaali.toJalaali(p.gy,p.gm,p.gd);return inputDate(j)+'، ساعت '+fa(pad(p.h)+':'+pad(p.min)+':'+pad(p.s));}
function parse(value){var match=/^(\d{4})[\/-](\d{1,2})[\/-](\d{1,2})$/.exec(latin(value).replace(/^\s+|\s+$/g,''));if(!match)throw new Error('تاریخ شمسی را مانند ۱۴۰۵/۰۷/۲۹ وارد کنید');var j={jy:Number(match[1]),jm:Number(match[2]),jd:Number(match[3])};try{if(!jalaali.isValidJalaaliDate(j.jy,j.jm,j.jd))throw new Error();}catch(ignore){throw new Error('روز یا ماه تاریخ شمسی معتبر نیست');}return j;}
function iso(value){var j=parse(value),g=jalaali.toGregorian(j.jy,j.jm,j.jd);return g.gy+'-'+pad(g.gm)+'-'+pad(g.gd);}
function range(days,ts){var p=parts(ts===undefined?Date.now()/1000:ts),d=new Date(Date.UTC(p.gy,p.gm-1,p.gd)-(days-1)*86400000);return {from:inputDate(jalaali.toJalaali(d.getUTCFullYear(),d.getUTCMonth()+1,d.getUTCDate())),to:inputDate(jalaali.toJalaali(p.gy,p.gm,p.gd))};}
function grid(jy,jm){var g=jalaali.toGregorian(jy,jm,1);return {offset:(new Date(Date.UTC(g.gy,g.gm-1,g.gd)).getUTCDay()+1)%7,days:jalaali.jalaaliMonthLength(jy,jm)};}
function init(notify){
  var modal=document.getElementById('calendarModal'),body=document.getElementById('calendarDays'),month=document.getElementById('calendarMonth'),year=document.getElementById('calendarYear');
  var target=null,trigger=null,selected=null,view=today(),current=today();
  function element(tag,value){var n=document.createElement(tag);n.textContent=value;return n;}
  for(var i=0;i<months.length;i++){var option=element('option',months[i]);option.value=i+1;month.appendChild(option);}
  function close(){modal.hidden=true;if(trigger)trigger.focus();}
  function choose(j){target.value=inputDate(j);close();}
  function render(){
    year.textContent='';for(var y=Math.min(current.jy-15,view.jy-1);y<=Math.max(current.jy+10,view.jy+1);y++){var option=element('option',fa(y));option.value=y;year.appendChild(option);}year.value=view.jy;month.value=view.jm;
    document.getElementById('calendarCaption').textContent=months[view.jm-1]+' '+fa(view.jy);
    document.getElementById('calendarHint').textContent=selected?'انتخاب فعلی: '+inputDate(selected):'یک روز را انتخاب کنید';
    body.textContent='';var layout=grid(view.jy,view.jm);
    for(var b=0;b<layout.offset;b++){var blank=element('span','');blank.className='calendar-blank';body.appendChild(blank);}
    for(var d=1;d<=layout.days;d++)(function(day){var button=element('button',fa(day));button.type='button';button.className='calendar-day';button.setAttribute('aria-label',fa(day)+' '+months[view.jm-1]+' '+fa(view.jy));if(selected&&selected.jy===view.jy&&selected.jm===view.jm&&selected.jd===day){button.className+=' selected';button.setAttribute('aria-pressed','true');}if(current.jy===view.jy&&current.jm===view.jm&&current.jd===day)button.className+=' today';button.onclick=function(){choose({jy:view.jy,jm:view.jm,jd:day});};body.appendChild(button);}(d));
  }
  function open(input,button){target=input;trigger=button;current=today();selected=null;if(input.value){try{selected=parse(input.value);}catch(error){notify(error.message);}}view=selected?{jy:selected.jy,jm:selected.jm,jd:selected.jd}:today();document.getElementById('calendarTitle').textContent=input.id==='historyFrom'?'انتخاب تاریخ شروع':'انتخاب تاریخ پایان';render();modal.hidden=false;document.getElementById('calendarClose').focus();}
  var buttons=document.querySelectorAll('[data-calendar]');for(var j=0;j<buttons.length;j++)buttons[j].onclick=function(){open(document.getElementById(this.getAttribute('data-calendar')),this);};
  function move(delta){view.jm+=delta;if(view.jm<1){view.jm=12;view.jy--;}if(view.jm>12){view.jm=1;view.jy++;}render();}
  document.getElementById('calendarPrevious').onclick=function(){move(-1);};document.getElementById('calendarNext').onclick=function(){move(1);};
  month.onchange=function(){view.jm=Number(this.value);render();};year.onchange=function(){view.jy=Number(this.value);render();};
  document.getElementById('calendarToday').onclick=function(){choose(today());};document.getElementById('calendarClear').onclick=function(){target.value='';close();};document.getElementById('calendarClose').onclick=close;
  modal.onclick=function(event){if(event.target===modal)close();};document.addEventListener('keydown',function(event){if(!modal.hidden&&event.keyCode===27)close();});
}
return {fa:fa,latin:latin,format:format,parse:parse,iso:iso,range:range,grid:grid,today:today,init:init};
}));
