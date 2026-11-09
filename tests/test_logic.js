const fs=require('fs');
const src=fs.readFileSync(__dirname + '/../qml/clocklogic.js','utf8').replace('.pragma library','');
const L=new Function(src+';return {compute,fmt,timeText,daySubtitle,nextDelay,burnOffset,palettes,pad,formatDate,usesSeconds,parseHM,fmtHM,isoWeek,dayOfYear,styles,timePresets,datePresets,styleNames,paletteNames,datePresetsFor,remainingText,mixMaster,mixScale};')();
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
// jornada con minutos escritos a mano: 7:45 a 16:20
t=L.compute(new Date(2026,10,3,7,40),{workMode:true,workStart:465/60,workEnd:980/60}); assert.equal(L.daySubtitle(t.day,false),'jornada en 5 min');
t=L.compute(new Date(2026,10,3,16,10),{workMode:true,workStart:465/60,workEnd:980/60}); assert.equal(L.daySubtitle(t.day,false),'quedan 10 min de jornada');
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

// ---------- formatos con códigos ----------
const f=new Date(2026,10,8,20,5,9);   // domingo 8 nov 2026, 20:05:09
assert.equal(L.formatDate(f,'HH:mm'),'20:05');
assert.equal(L.formatDate(f,'H:m:s'),'20:5:9');
assert.equal(L.formatDate(f,'hh:mm:ss A'),'08:05:09 PM');
assert.equal(L.formatDate(f,'h:mm a'),'8:05 pm');
assert.equal(L.formatDate(new Date(2026,0,1,0,7),'h:mm A'),'12:07 AM');
assert.equal(L.formatDate(f,"dddd d 'de' MMMM"),'domingo 8 de noviembre');
assert.equal(L.formatDate(f,'ddd dd/MM/yy'),'dom 08/11/26');
assert.equal(L.formatDate(f,'MMM yyyy'),'nov 2026');
assert.equal(L.formatDate(f,"HH'h'mm"),'20h05');
assert.equal(L.formatDate(f,"'it''s' HH"),"it's 20");
assert.equal(L.formatDate(f,"d MMM | 'semana' w"),'8 nov \n semana 45');
assert.equal(L.formatDate(f,'Q'),'4');
assert.equal(L.formatDate(f,'DDD'),'312');
assert.equal(L.formatDate(new Date(2026,0,1),'D'),'1');
assert.equal(L.formatDate(f,"'sin cierre"),'sin cierre');
assert.equal(L.formatDate(f,''),'');
// semana ISO en bordes de año
assert.equal(L.isoWeek(new Date(2026,0,1)),1);   // jueves
assert.equal(L.isoWeek(new Date(2027,0,1)),53);  // viernes -> semana 53 de 2026
assert.equal(L.isoWeek(new Date(2024,11,30)),1); // lunes -> semana 1 de 2025
assert.equal(L.isoWeek(new Date(2021,0,3)),53);  // domingo
assert.equal(L.dayOfYear(new Date(2028,11,31)),366);
assert(L.usesSeconds('HH:mm:ss')); assert(!L.usesSeconds('HH:mm')); assert(!L.usesSeconds("HH 'segs'"));
for(const p of L.timePresets.concat(L.datePresets)) assert(L.formatDate(f,p).length>0);
assert.equal(L.styles.length,8);

// ---------- horas escritas a mano ----------
assert.equal(L.parseHM('8'),480);
assert.equal(L.parseHM(' 08:15 '),495);
assert.equal(L.parseHM('8.5'),485);
assert.equal(L.parseHM('7h45'),465);
assert.equal(L.parseHM('7:'),420);
assert.equal(L.parseHM('1730'),1050);
assert.equal(L.parseHM('930'),570);
assert.equal(L.parseHM('24:00'),1440);
assert.equal(L.parseHM('24:01'),-1);
assert.equal(L.parseHM('25'),-1);
assert.equal(L.parseHM('8:60'),-1);
assert.equal(L.parseHM('abc'),-1);
assert.equal(L.parseHM(''),-1);
assert.equal(L.fmtHM(495),'08:15');
assert.equal(L.fmtHM(1440),'24:00');
for(let v=0;v<=1440;v+=7) assert.equal(L.parseHM(L.fmtHM(v)),v);

// ---------- inglés ----------
t=L.compute(new Date(2026,10,3,13,0),{workMode:true,workStart:8,workEnd:18});
assert.equal(L.daySubtitle(t.day,false,'en'),'5 h 00 min left in workday');
t=L.compute(new Date(2026,10,3,7,15),{workMode:true,workStart:8,workEnd:18}); assert.equal(L.daySubtitle(t.day,false,'en'),'workday starts in 45 min');
t=L.compute(new Date(2026,10,3,19,0),{workMode:true,workStart:8,workEnd:18}); assert.equal(L.daySubtitle(t.day,false,'en'),'workday over');
t=L.compute(new Date(2026,10,3,23,59,30),{}); assert.equal(L.daySubtitle(t.day,true,'en'),'30 s left today');
assert.equal(L.daySubtitle(t.day,true),'quedan 30 s del día');
assert.equal(L.remainingText('Month',125e3,true,'en'),'Month · 2 min 05 s left');
assert.equal(L.remainingText('Mes',125e3,true,'es'),'Mes · quedan 2 min 05 s');
assert.equal(L.formatDate(f,'dddd, MMMM d','en'),'Sunday, November 8');
assert.equal(L.formatDate(f,'ddd MMM','en'),'Sun Nov');
assert.equal(L.formatDate(f,'ddd MMM','es'),'dom nov');
assert.equal(L.styleNames('en').length,8); assert.equal(L.styleNames('es')[7],'Analógico');
assert.equal(L.paletteNames('en')[1],'Sunset');
for(const p of L.datePresetsFor('en')) assert(L.formatDate(f,p,'en').length>0);

// ---------- mezclador ----------
assert.equal(L.mixMaster([0.2,0.8,0.5]),0.8);
assert.deepEqual(L.mixScale([0.2,0.8,0.4],0.4),[0.1,0.4,0.2]);
assert.deepEqual(L.mixScale([0.5,1],1),[0.5,1]);
assert.deepEqual(L.mixScale([0,0],0.6),[0.6,0.6]);
assert.deepEqual(L.mixScale([0.3,0.6],2),[0.5,1]);
assert.equal(L.mixMaster([]),0);

console.log('OK – todas las pruebas pasaron');
