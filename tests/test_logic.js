const fs=require('fs');
const src=fs.readFileSync(__dirname + '/../qml/clocklogic.js','utf8').replace('.pragma library','');
const L=new Function(src+';return {compute,fmt,timeText,daySubtitle,nextDelay,burnOffset,palettes,pad};')();
const assert=require('assert');
let d=new Date(2026,10,3,12,0,0,0); let t=L.compute(d,{});
assert(Math.abs(t.day.p-0.5)<1e-9); assert.equal(t.month.segs,30);
assert(Math.abs(t.month.p-(2.5/30))<1e-9); assert.equal(t.hour.p,0); assert.equal(t.minute.p,0);
// semana: martes 12:00 -> (1.5)/7
assert(Math.abs(t.week.p-1.5/7)<1e-9);
// año
const y0=new Date(2026,0,1),y1=new Date(2027,0,1); assert(Math.abs(t.year.p-(d-y0)/(y1-y0))<1e-12);
// jornada 8-18 a las 13:00 -> 0.5
t=L.compute(new Date(2026,10,3,13,0),{workMode:true,workStart:8,workEnd:18}); assert(Math.abs(t.day.p-0.5)<1e-9); assert.equal(t.day.segs,10);
assert.equal(L.daySubtitle(t.day,false),'quedan 5 h 00 min de jornada');
t=L.compute(new Date(2026,10,3,7,15),{workMode:true,workStart:8,workEnd:18}); assert.equal(L.daySubtitle(t.day,false),'jornada en 45 min');
t=L.compute(new Date(2026,10,3,19,0),{workMode:true,workStart:8,workEnd:18}); assert.equal(L.daySubtitle(t.day,false),'jornada terminada');
t=L.compute(new Date(2026,10,3,23,59,30),{}); assert.equal(L.daySubtitle(t.day,false),'quedan 1 min del día'); assert.equal(L.daySubtitle(t.day,true),'quedan 30 s del día');
// febrero bisiesto 2028
assert.equal(L.compute(new Date(2028,1,10),{}).month.segs,29);
assert.equal(L.fmt(17*86400e3+4*3600e3+5,false),'17 d 4 h');
assert.equal(L.fmt(125e3,true),'2 min 05 s');
assert.equal(L.timeText(new Date(2026,0,1,0,5,9),true,true),'12:05:09');
assert.equal(L.timeText(new Date(2026,0,1,13,5,9),false,false),'13:05');
assert.equal(L.nextDelay(new Date(2026,0,1,0,0,10,250),true,false),758);
assert.equal(L.nextDelay(new Date(2026,0,1,0,0,10,250),false,false),49758);
for(let k=0;k<500;k++){const o=L.burnOffset(k,8); assert(Math.hypot(o.x,o.y)<=8+1e-9);}
// distinct consecutive positions
const a=L.burnOffset(1,8),b=L.burnOffset(2,8); assert(Math.hypot(a.x-b.x,a.y-b.y)>1);
// sweep a full day: monotonic
let prev=-1; for(let m=0;m<1440;m+=7){const p=L.compute(new Date(2026,10,3,0,m),{}).day.p; assert(p>=prev); prev=p;}
console.log('OK – todas las pruebas pasaron');
