// Geometry in the original mascot coordinate system. Controls change the outline;
// the eyes, mouth and wordmark keep their original stroke widths.
(() => {
  'use strict';
  const fields = [
    {key:'width', label:'宽度', min:60, max:145, unit:'%'},
    {key:'height', label:'高度', min:60, max:145, unit:'%'},
    {key:'corner', label:'圆角', min:5, max:160, unit:'%'},
    {key:'angle', label:'倾斜', min:-25, max:25, unit:'°'},
    {key:'position', label:'尾巴位置', min:0, max:100, unit:'%'},
    {key:'length', label:'尾巴长度', min:0, max:240, unit:'%'}
  ];
  const moods = {'side-smile':['smile'], 'blue-note':['gasp'], 'double-talk':['smile','hum']};
  const defaults = mood => ({width:100,height:100,corner:100,angle:mood==='gasp'?-7:0,position:mood==='hum'?100:0,length:100});
  const limit = (field,value) => Math.min(field.max, Math.max(field.min, Math.round(value)));
  const short = value => Number(value.toFixed(3));
  const pair = p => p.map(short).join(' ');

  // Endpoints of the original lower corners and control points of each hand-drawn
  // tail. Interpolate on the sloping lower edge so the tail stays attached.
  const tails = {
    smile:{left:[22,94],right:[85,95],base:[22,58],tip:[30,110],
      points:[['C',47,95,38,109,30,110],['C',24,110,31,95,22,94]]},
    gasp:{left:[18,92],right:[97,98],base:[18,68],tip:[27,105],
      points:[['C',58,95,53,89,45,94],['L',27,105],['C',19,108,26,94,18,92]]},
    hum:{left:[19,91],right:[102,89],base:[70,102],tip:[93,106],
      points:[['L',97,90],['Q',94,91,96,102],['Q',95,110,85,102],['L',70,91]]}
  };
  function tailGeometry(mood, settings, left, right) {
    const ref=tails[mood];
    const span=right[0]-left[0], originalWidth=ref.base[1]-ref.base[0];
    const width=Math.min(originalWidth,span*.76), travel=span-width;
    const base=left[0]+travel*settings.position/100;
    const baseline=(a,b,x)=>a[1]+(b[1]-a[1])*(x-a[0])/(b[0]-a[0]);
    function project(x,y) {
      const px=base+(x-ref.base[0])*width/originalWidth;
      const delta=y-baseline(ref.left,ref.right,x);
      return [px,baseline(left,right,px)+delta*settings.length/100];
    }
    const commands=['L'+pair(project(ref.base[1],baseline(ref.left,ref.right,ref.base[1])))];
    if(settings.length) {
      for(const [cmd,...coords] of ref.points) {
        const points=[];
        for(let i=0;i<coords.length;i+=2) points.push(pair(project(coords[i],coords[i+1])));
        commands.push(cmd+points.join(' '));
      }
    }
    commands.push('L'+pair(left));
    return {path:commands.join(''), tip:project(...ref.tip), travel,
      rise:ref.tip[1]-baseline(ref.left,ref.right,ref.tip[0]),
      slope:(right[1]-left[1])/span};
  }

  function geometry(mood,s) {
    const radius=s.corner/100;
    const corner=(cx,cy)=>(x,y)=>[cx+(x-cx)*radius,cy+(y-cy)*radius];
    let top, bottom, tail;
    if(mood==='smile') {
      const tl=corner(0,0),tr=corner(120,3),br=corner(115,95),bl=corner(0,94);
      tail=tailGeometry(mood,s,bl(22,94),br(85,95));
      top='M'+pair(tl(16,2))+'C43 -2 82 0 '+pair(tr(103,3))+'C'+[tr(118,6),tr(122,19),tr(120,38)].map(pair).join(' ')+
        'L'+pair(br(115,69))+'C'+[br(112,88),br(102,95),br(85,95)].map(pair).join(' ');
      bottom='C'+[bl(7,93),bl(1,85),bl(1,69)].map(pair).join(' ')+'L'+pair(tl(0,26))+'C'+[tl(0,13),tl(4,5),tl(16,2)].map(pair).join(' ');
    } else if(mood==='gasp') {
      const tl=corner(3,0),tr=corner(117,3),br=corner(124,98),bl=corner(0,92);
      tail=tailGeometry(mood,s,bl(18,92),br(97,98));
      top='M'+pair(tl(21,0))+'L'+pair(tr(92,3))+'C'+[tr(109,4),tr(116,12),tr(118,28)].map(pair).join(' ')+
        'L'+pair(br(123,76))+'C'+[br(124,92),br(113,100),br(97,98)].map(pair).join(' ');
      bottom='C'+[bl(5,88),bl(-1,83),bl(0,68)].map(pair).join(' ')+'L'+pair(tl(3,23))+'Q'+[tl(5,3),tl(21,0)].map(pair).join(' ');
    } else {
      const tl=corner(0,4),tr=corner(118,2),br=corner(120,90),bl=corner(0,91);
      tail=tailGeometry(mood,s,bl(19,91),br(102,89));
      top='M'+pair(tl(0,23))+'Q'+[tl(0,4),tl(18,4)].map(pair).join(' ')+'L49 5C67 6 70 -1 85 0L'+pair(tr(100,2))+
        'Q'+[tr(117,4),tr(118,21)].map(pair).join(' ')+'L'+pair(br(120,71))+'Q'+[br(119,87),br(102,89)].map(pair).join(' ');
      bottom='Q'+[bl(0,91),bl(0,72)].map(pair).join(' ');
    }
    return {path:top+tail.path+bottom+'Z', tail, scale:'translate(60 47) scale('+s.width/100+' '+s.height/100+') translate(-60 -47)'};
  }
  window.SpeakLowBubbles=Object.freeze({fields,moods,defaults,limit,geometry});
})();
