/* آزمون تبدیل و مرزهای تقویم؛ وابسته به ساعت یا منطقهٔ زمانی کامپیوتر نیست. */
'use strict';
var assert=require('assert'),vm=require('vm'),fs=require('fs'),path=require('path');
var calendar=require('../web/calendar.js');
assert.strictEqual(calendar.iso('۱۴۰۵/۰۷/۲۹'),'2026-10-21');
assert.strictEqual(calendar.iso('١٤٠٥/٧/٢٩'),'2026-10-21');
assert.strictEqual(calendar.iso('1399/12/30'),'2021-03-20');
assert.strictEqual(calendar.iso('1400/01/01'),'2021-03-21');
assert.throws(function(){calendar.iso('1400/12/30');});
assert.throws(function(){calendar.iso('1405/07/31');});
assert.throws(function(){calendar.iso('1405/13/01');});
assert.strictEqual(calendar.fa(123),'۱۲۳');
var midnight=Date.parse('2026-10-20T20:30:00Z')/1000;
assert.strictEqual(calendar.format(midnight),'۱۴۰۵/۰۷/۲۹، ساعت ۰۰:۰۰:۰۰');
assert.strictEqual(calendar.format(midnight-1),'۱۴۰۵/۰۷/۲۸، ساعت ۲۳:۵۹:۵۹');
assert.deepStrictEqual(calendar.range(7,midnight),{from:'۱۴۰۵/۰۷/۲۳',to:'۱۴۰۵/۰۷/۲۹'});
assert.strictEqual(calendar.grid(1399,12).days,30);
assert.strictEqual(calendar.grid(1400,12).days,29);
// همان مسیر بدون Intl که مرورگر قدیمی تبلت استفاده خواهد کرد.
var context={module:{exports:{}},require:function(){return require('../web/jalaali.js');},Date:Date,Intl:undefined};
vm.runInNewContext(fs.readFileSync(path.join(__dirname,'../web/calendar.js'),'utf8'),context);
assert.strictEqual(context.module.exports.format(midnight),'۱۴۰۵/۰۷/۲۹، ساعت ۰۰:۰۰:۰۰');
console.log('Calendar checks passed: Persian digits, leap day, Tehran midnight, range and no-Intl fallback.');
