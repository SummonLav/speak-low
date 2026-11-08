// Original vector drawings. All lettering in the exported marks is made of paths.
(() => {
  'use strict';
  const ink = '#191919';
  const paper = '#fafafa';
  const path = (d, color = ink, attributes = '') => `<path fill="${color}" d="${d}" ${attributes}/>`;
  const line = (d, weight, color = ink, cap = 'round') =>
    `<path d="${d}" fill="none" stroke="${color}" stroke-width="${weight}" stroke-linecap="${cap}" stroke-linejoin="round"/>`;
  const group = (transform, contents) => `<g transform="${transform}">${contents}</g>`;
  const circle = (x, y, r, color = ink) => `<circle cx="${x}" cy="${y}" r="${r}" fill="${color}"/>`;

  // Each capital occupies roughly 44 × 60 units. The individual placements below
  // determine the rhythm, width, tilt and baseline of each impression.
  const capitals = {
    S:'M39 8C27 0 8 3 6 16C3 30 22 30 31 35C48 44 37 61 23 61Q11 62 3 53',
    P:'M6 61L5 4Q40 -1 41 18C42 33 24 35 6 34',
    E:'M38 4L5 6L8 60L42 57M7 32L32 30',
    A:'M1 60L24 3L43 60M10 40L34 38',
    K:'M6 3L6 61M40 3L8 34L42 59',
    N:'M5 61L4 4L40 59L40 3',
    Y:'M1 4L22 33L42 3M22 33L21 60',
    T:'M1 5L44 3M24 5L22 61',
    H:'M5 4L7 60M40 2L40 60M8 32L38 30',
    I:'M16 4L29 4M23 5L22 59M14 60L30 60',
    G:'M39 13C23 -6 1 7 4 34C6 63 29 70 42 51L40 34L26 35'
  };
  function letters(word, layout, color = ink, weight = 9) {
    return [...word].map((c,i) => {
      const [x,y,angle,sx,sy=sx] = layout[i];
      return group(`translate(${x} ${y}) rotate(${angle}) scale(${sx} ${sy}) translate(-22 -31)`, line(capitals[c], weight, color));
    }).join('');
  }
  const spark = (x,y,size,color=ink,turn=0) => group(`translate(${x} ${y}) rotate(${turn}) scale(${size})`,
    line('M-15 0L14 -1M-1 -15L1 14M-11 -11L10 10M-10 11L10 -11',3.8,color));
  const bolt = (x,y,s,c,angle=0) => group(`translate(${x} ${y}) rotate(${angle}) scale(${s})`,
    path('M-3 -19L10 -21L3 -4L13 -6L-8 21L-4 3L-14 6Z',c));

  // Small, seamless scanned-paper-like tile, generated from a fixed seed.
  // The very same image is embedded in a downloaded SVG; no external asset links.
  function grainTile() {
    const size = 160, canvas = document.createElement('canvas');
    canvas.width = canvas.height = size;
    const ctx = canvas.getContext('2d');
    let seed = 714939;
    const random = () => ((seed = (Math.imul(seed,1664525) + 1013904223) >>> 0) / 4294967296);
    const pixels = ctx.createImageData(size,size);
    for (let i=0; i<pixels.data.length; i+=4) {
      const light = random() > .48, t = light ? 252 : 21;
      pixels.data[i]=pixels.data[i+1]=pixels.data[i+2]=t;
      pixels.data[i+3]=Math.round(4 + 83 * Math.pow(random(),2.6));
    }
    ctx.putImageData(pixels,0,0);
    for (let i=0;i<80;i++) {
      ctx.fillStyle=random()<.65?'rgba(255,255,255,.28)':'rgba(35,35,35,.18)';
      ctx.fillRect(random()*size,random()*size,random()*2.4+.4,random()*.8+.4);
    }
    return canvas.toDataURL('image/png');
  }
  const texture = grainTile();
  let serial=0;
  const chatterBubble='M83 382L132 293L119 258L119 201L134 147L171 105L221 83L287 66L378 64L460 71L528 82L570 104L594 142L607 182L605 226L590 265L565 295L529 311L473 324L385 332L310 333L238 324L194 309L150 339Z';
  function chatter(fill) {
    const first = [[208,170,-20,1.27,1.23],[282,150,12,1.25,1.32],[359,161,-13,1.24,1.19],[435,152,16,1.24,1.38],[516,165,-16,1.25,1.25]];
    const second = [[176,245,-17,.91,.96],[229,249,12,.90,1],[283,237,-13,.91,.95],[343,248,15,1,1.03],[400,241,-9,.96,1.01],[450,244,15,.88,1.01],[500,239,-14,.90,.99],[554,226,13,.86,.94]];
    return path(chatterBubble, fill) + letters('SPEAK',first,ink,10.5) + letters('ANYTHING',second,ink,9) +
      spark(153,172,.39,ink,-13) + spark(554,138,.47,ink,5) +
      line('M241 289Q289 278 325 285M245 298L279 293',4,ink) +
      path('M440 286Q467 277 489 279Q471 282 443 290Z',ink) +
      circle(535,274,3.2) + circle(328,104,2.2);
  }
  const cutBubble='M107 145L157 110L212 108L222 77L503 63L566 89L561 115L605 119L625 165L594 207L623 231L601 279L550 311L462 322L423 313L399 338L291 342L258 329L168 351L198 307L124 312L97 282L121 252L87 217L110 185Z';
  function overprint() {
    const first=[[197,166,-13,1.22,1.33],[274,151,-6,1.25,1.28],[355,148,-12,1.35,1.44],[440,139,-7,1.35,1.36],[523,137,-14,1.26,1.37]];
    const second=[[172,253,-9,.98,1.04],[227,246,-3,.99,1.07],[286,240,-14,1,1.08],[345,239,-2,1.02,1.1],[408,232,-10,.99,1.12],[458,226,-3,.94,1.13],[508,220,-11,.94,1.08],[560,221,-4,.91,1.06]];
    const type=(c)=>letters('SPEAK',first,c,10.7)+letters('ANYTHING',second,c,10.3);
    return group('translate(7 10)',path(cutBubble,'#858585')) + path(cutBubble,'#242424') +
      group('translate(3 -3)',type('#858585')) + type('#fafafa') +
      bolt(157,203,.55,'#bdbdbd',18) + line('M422 275L537 255M461 279L523 267',5,'#fafafa','square') +
      path('M293 104l17 -12l-4 9l13 -2l-16 12l4 -8z','#fafafa');
  }
  const orbitBubble='M136 214C120 171 153 139 166 126C162 88 218 72 256 72C292 44 343 52 367 59C407 35 451 48 479 67C529 59 567 87 568 114C615 120 630 162 613 190C646 219 626 256 599 272C603 307 569 331 526 329C492 366 457 364 425 351C380 371 338 356 318 347L255 386L266 342C233 353 196 341 187 321C137 321 114 291 128 260C103 247 114 222 136 214Z';
  function orbit(){
    const upper=[[202,179,-32,.99,1.11],[272,133,-17,1.08,1.11],[350,118,-5,1.11,1.12],[432,121,12,1.1,1.16],[509,148,28,1.07,1.12]];
    const lower=[[185,253,23,.83,.95],[238,276,18,.87,.97],[293,286,13,.89,.99],[349,293,5,.94,1],[409,287,-8,.90,.98],[458,277,-14,.86,.94],[508,259,-20,.86,.95],[555,227,-30,.87,.94]];
    return path(orbitBubble,'#f9f9f9') + letters('SPEAK',upper,'#191919',9.8) + letters('ANYTHING',lower,'#191919',9.5) +
      group('translate(363 205) rotate(-12)',path('M-64 -4Q-18 -8 -10 -41Q0 -16 14 -14Q26 -11 53 -24Q37 -8 40 -2Q43 5 73 8Q28 11 16 33Q5 18 -8 17Q-28 15 -50 26Q-35 8 -64 -4Z','#555555')) +
      line('M261 208Q252 203 245 205M467 182L480 172',4,'#191919') + circle(475,204,3,'#191919');
  }

  // Purpose-drawn single-storey lowercase lettering for the face lockups.
  const lowerGlyphs={
    s:[29,'M24 15Q17 10 9 14Q0 19 9 24L20 28Q30 34 20 39Q10 43 3 37'],
    p:[33,'M5 15L5 52M6 25C8 11 28 9 29 24C31 40 12 46 6 33'],
    e:[32,'M4 27L28 26C28 8 8 9 4 23C-1 38 14 46 27 36'],
    a:[33,'M27 14L27 39M26 22C22 9 4 11 3 26C2 40 18 46 26 32'],
    k:[30,'M5 1L5 40M26 14L6 29M16 24L28 39'],
    '-':[18,'M3 26L15 26'],
    l:[14,'M5 1L5 35Q5 39 9 39'],
    o:[33,'M15 13C-1 13 -1 40 16 40C33 40 33 13 15 13Z'],
    w:[47,'M2 14L11 39L22 16L33 39L43 14'],
    n:[34,'M5 14L5 39M6 24C10 11 28 8 28 24L28 39'],
    y:[32,'M2 14L15 39M29 14L10 53'],
    t:[23,'M10 5L10 32Q10 42 20 38M3 16L20 15'],
    h:[34,'M5 1L5 40M6 24C10 11 28 8 28 24L28 39'],
    i:[13,'M6 16L6 39M6 4L6 5'],
    g:[34,'M27 14L27 39Q26 58 7 50M26 22C22 9 4 11 3 26C2 40 18 45 26 32']
  };
  function wordmark(word,x,y,width,color=ink) {
    let advance=0, shapes='';
    for (const c of word) {
      const [w,d]=lowerGlyphs[c];
      shapes+=group(`translate(${advance} 0)`,line(d,6.7,color));
      advance+=w+3;
    }
    return group(`translate(${x} ${y}) scale(${width/advance})`,shapes);
  }
  const facePaths={
    smile:'M16 2C43 -2 82 0 103 3C118 6 122 19 120 38L115 69C112 88 102 95 85 95L58 95C47 95 38 109 30 110C24 110 31 95 22 94C7 93 1 85 1 69L0 26C0 13 4 5 16 2Z',
    gasp:'M21 0L92 3C109 4 116 12 118 28L123 76C124 92 113 100 97 98L68 95C58 95 53 89 45 94L27 105C19 108 26 94 18 92C5 88 -1 83 0 68L3 23Q5 3 21 0Z',
    hum:'M0 23Q0 4 18 4L49 5C67 6 70 -1 85 0L100 2Q117 4 118 21L120 71Q119 87 102 89L97 90Q94 91 96 102Q95 110 85 102L70 91L19 91Q0 91 0 72Z'
  };
  function face(mood,fill,features,outline) {
    const border=outline?'stroke="'+outline+'" stroke-width="2.4" stroke-linejoin="round"':'';
    const base=path(facePaths[mood],fill,border);
    if(mood==='smile') return base + line('M60 42L60 49M78 40L78 47',6.2,features) + line('M58 61Q70 68 82 56',5.1,features);
    if(mood==='gasp') return base + line('M47 42L46 48M64 44L63 50',6.2,features) +
      path('M53 55C69 55 67 72 54 72C39 72 39 55 53 55Z',features) + path('M53 60C60 59 62 66 55 67C48 67 47 61 53 60Z',fill);
    return base + line('M39 40Q43 47 48 40M58 39Q62 46 67 39',4.8,features) + line('M45 55Q52 62 61 54',4.3,features);
  }
  function drawMascot(id,dark=false) {
    const solid=dark?paper:ink, cut=dark?ink:paper;
    if (id==='side-smile') return face('smile',solid,cut);
    if (id==='blue-note') return group('rotate(-7 60 54)',face('gasp',paper,ink,dark?null:ink));
    return group('translate(0 1) rotate(-7 50 50) scale(.79)',face('hum',paper,ink,ink)) +
      group('translate(51 35) rotate(9 52 45) scale(.74)',face('smile',ink,paper,paper));
  }
  function faceLockup(id,word,dark=false) {
    const color=dark?paper:ink;
    const isPair=id==='double-talk';
    const icon=group(`translate(${isPair?99:96} ${isPair?135:139}) scale(${isPair?1.48:1.52})`,drawMascot(id,dark));
    const x=isPair?331:315;
    if(word==='speak anything') return icon+wordmark('speak',x,144,164,color)+wordmark('anything',x,207,255,color);
    return icon+wordmark('speak-low',x,185,300,color);
  }

  const designs=[
    {id:'paper-chatter',name:'纸片喊话',english:'Paper Chatter',family:'type',board:'#262626',reverse:true,palette:['#262626',paper,ink],note:'两排手写字母各自歪斜，挤进一只剪纸气泡。',bounds:[74,56,545,337],draw:()=>chatter(paper)},
    {id:'off-register',name:'错版声浪',english:'Off Register',family:'type',board:'#e5e5e5',palette:['#e5e5e5','#242424','#858585','#fafafa'],note:'白字向上斜排，银灰色的套印错开半个笔画。',bounds:[79,55,563,312],draw:overprint},
    {id:'orbital',name:'绕个圈说',english:'Roundabout',family:'type',board:'#a9a9a9',palette:['#a9a9a9','#f9f9f9','#191919','#555555'],note:'字母沿弧线散开，围住中间一枚星芒。',bounds:[100,36,540,361],draw:orbit},
    {id:'side-smile',name:'笑着说',english:'Side Smile',family:'face',board:'#eeeeee',palette:['#eeeeee',ink,paper],note:'墨黑气泡侧着笑，圆头字标在它右边接话。',bounds:[86,130,541,187]},
    {id:'blue-note',name:'小小惊叹',english:'Little Oh',family:'face',board:'#202020',reverse:true,palette:['#202020',paper,ink],note:'黑底上留出一只白色气泡，圆嘴微张。',bounds:[79,120,548,200]},
    {id:'double-talk',name:'一起说',english:'Double Talk',family:'face',board:'#d1d1d1',palette:['#d1d1d1',paper,ink],note:'两只气泡一前一后，把一句话接成对话。',bounds:[87,127,559,196]}
  ];
  function svg(design,{kind='board',word='speak-low',dark=Boolean(design.reverse)}={}) {
    const uid='sl'+(++serial);
    const type=design.family==='type';
    const onBoard=kind==='board'||kind==='thumb';
    const art=type?design.draw():faceLockup(design.id,word,onBoard?Boolean(design.reverse):dark);
    const view=kind==='icon'?(type?design.bounds:[-8,-13,152,151]):kind==='logo'?design.bounds:[0,0,720,440];
    const pattern=`<pattern id="${uid}g" patternUnits="userSpaceOnUse" width="143" height="143"><image width="143" height="143" href="${texture}"/></pattern>`;
    const plate=onBoard?`<rect width="720" height="440" fill="${design.board}"/>`:'';
    const silhouette=({'paper-chatter':chatterBubble,'off-register':cutBubble,orbital:orbitBubble})[design.id];
    const clipping=type&&!onBoard ? '<clipPath id="'+uid+'c"><path d="'+silhouette+'"/></clipPath>' : '';
    const grain=type && kind!=='icon';
    const textureLayer=grain ? '<rect width="720" height="440" fill="url(#'+uid+'g)" opacity=".67"'+
      (clipping?' clip-path="url(#'+uid+'c)"':'')+' pointer-events="none"/>' : '';
    const shape=kind==='icon'&&!type?drawMascot(design.id,dark):art;
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${view.join(' ')}" role="img" aria-label="${design.name} · ${type?'speak anything':word}" preserveAspectRatio="xMidYMid ${kind==='thumb'?'slice':'meet'}"><title>${design.english} — ${type?'speak anything':word}</title>${textureLayer?'<defs>'+pattern+clipping+'</defs>':''}${plate}${shape}${textureLayer}</svg>`;
  }
  window.SpeakLowMarks=Object.freeze({designs,svg});
})();
