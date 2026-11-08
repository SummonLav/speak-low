(() => {
  'use strict';
  const {designs,svg} = window.SpeakLowMarks;
  const editor=window.SpeakLowShapeEditor;
  const faces=designs.filter(d=>d.family==='face');
  const mark=(design,options)=>svg(design,{...options,changes:editor.changes(design.id)});
  const $ = selector => document.querySelector(selector);
  const indexOf = design => designs.indexOf(design);
  const pad = n => String(n).padStart(2,'0');
  const icon = name => '<svg class="icon" aria-hidden="true"><use href="#i-'+name+'"/></svg>';
  const options = new URLSearchParams(location.search);
  let word=options.get('word')==='anything'?'speak anything':'speak-low', dark=false;
  let active = designs.find(d => '#'+d.id === location.hash) || designs[0];
  let filter=options.get('series')===active.family?active.family:'all';
  let editing=options.get('edit')==='1';
  if(editing && active.family!=='face') {active=faces[0];filter='face';}
  let lastFace=active.family==='face'?active:faces[0];
  editor.restore(active.id,options);
  const listed = () => designs.filter(d => filter==='all' || d.family===filter);
  const surface = () => $('#proof-board').dataset.dark = String(dark);

  function renderCatalog() {
    const catalog=$('#catalog');
    catalog.replaceChildren();
    for(const d of listed()) {
      const button=document.createElement('button');
      button.type='button'; button.className='concept'; button.dataset.id=d.id;
      button.style.setProperty('--board',d.board);
      button.setAttribute('aria-label','预览'+d.name+' / '+d.english);
      button.setAttribute('aria-pressed',String(d===active));
      button.innerHTML='<span class="thumb" aria-hidden="true">'+mark(d,{kind:'thumb',word})+'<span class="check">'+icon('check')+'</span></span>'+
        '<span class="card-caption"><span class="card-no">'+pad(indexOf(d)+1)+'</span>'+d.name+'</span>';
      catalog.append(button);
    }
  }
  function proofs() {
    surface();
    $('#sizes').innerHTML=[16,32,48].map(size=>'<div class="size-example"><div style="width:'+size+'px;height:'+size+
      'px;--board:'+active.board+'">'+mark(active,{kind:'icon',word})+'</div><span class="scale">'+size+'</span></div>').join('');
    $('#signature').innerHTML=active.family==='face'?mark(active,{kind:'logo',word,dark}):
      mark(active,{kind:'icon'})+'<span class="signature-text">speak-low</span>';
  }
  function renderPalette() {
    $('#colors').innerHTML=active.palette.map(hex=>'<button type="button" class="swatch" data-color="'+hex+
      '" style="--swatch:'+hex+'" aria-label="复制色值 '+hex+'"><span class="tooltip">'+hex.toUpperCase()+'</span></button>').join('');
  }
  function drawFaceChoice(design) {
    const button=$('#face-picker [data-face="'+design.id+'"]');
    button.querySelector('.mini-mark').innerHTML=mark(design,{kind:'icon',word});
    button.setAttribute('aria-pressed',String(design===active));
  }
  function draw() {
    $('#drawing').innerHTML=mark(active,{word});
    proofs();
    if(editing) {
      drawFaceChoice(active);
      editor.sync();
    }
  }
  function display() {
    editor.setDesign(active);
    $('.filters').hidden=editing;
    $('#catalog').hidden=editing;
    $('#shape-panel').hidden=!editing;
    $('#handle-hint').hidden=!editing;
    $('#handles').toggleAttribute('hidden',!editing);
    document.querySelectorAll('[data-mode]').forEach(b=>b.setAttribute('aria-pressed',String((b.dataset.mode==='shape')===editing)));
    document.querySelectorAll('[data-face]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.face===active.id)));
    renderPalette();
    $('#plate').style.background=active.board;
    $('#plate').classList.toggle('dark-plate',Boolean(active.reverse));
    $('#family').textContent=active.family==='type'?'字形气泡':'表情字标';
    $('#name').textContent=active.name;
    $('#english').textContent=active.english;
    $('#note').textContent=active.note;
    $('#counter').textContent=pad(indexOf(active)+1)+' / '+pad(designs.length);
    $('#copy-options').hidden=active.family!=='face';
    document.querySelectorAll('[data-word]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.word===word)));
    document.querySelectorAll('.concept').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.id===active.id)));
    draw();
  }
  function writeURL() {
    const url = new URL(location.href);
    if (word==='speak anything') url.searchParams.set('word','anything'); else url.searchParams.delete('word');
    if (filter!=='all') url.searchParams.set('series',filter); else url.searchParams.delete('series');
    if(editing) url.searchParams.set('edit','1'); else url.searchParams.delete('edit');
    editor.save(active.id,url.searchParams);
    url.hash=active.id;
    if (url.href!==location.href) {
      try { history.replaceState(null,'',url.href); } catch { location.hash=active.id; }
    }
  }
  function choose(design) {
    if(!design) return;
    active=design;
    if(design.family==='face') lastFace=design; else editing=false;
    display();
    writeURL();
  }
  function mode(next) {
    editing=next==='shape';
    if(editing && filter==='type') filter='face';
    document.querySelectorAll('[data-filter]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.filter===filter)));
    if(!editing) renderCatalog();
    choose(editing?lastFace:active);
  }
  function step(n) {
    const set=editing?faces:listed();
    choose(set[(set.indexOf(active)+n+set.length)%set.length]);
  }
  function changeFilter(value) {
    filter=value;
    document.querySelectorAll('[data-filter]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.filter===filter)));
    renderCatalog();
    choose(listed().includes(active)?active:listed()[0]);
  }
  editor.init(draw,writeURL);
  for(const d of faces) {
    const button=document.createElement('button');
    button.type='button'; button.dataset.face=d.id;
    button.innerHTML='<span aria-hidden="true" class="mini-mark"></span><span>'+d.name+'</span>';
    button.querySelector('.mini-mark').style.background=d.board;
    $('#face-picker').append(button);
    drawFaceChoice(d);
  }
  $('.work-modes').addEventListener('click',e=>{
    const button=e.target.closest('[data-mode]');
    if(button) mode(button.dataset.mode);
  });
  $('#face-picker').addEventListener('click',e=>{
    const button=e.target.closest('[data-face]');
    if(button) choose(faces.find(d=>d.id===button.dataset.face));
  });
  $('#catalog').addEventListener('click',e=>{
    const b=e.target.closest('button[data-id]');
    if(b) choose(designs.find(d=>d.id===b.dataset.id));
  });
  document.querySelector('.filters').addEventListener('click',e=>{
    const b=e.target.closest('button[data-filter]'); if(b)changeFilter(b.dataset.filter);
  });
  $('#previous').addEventListener('click',()=>step(-1));
  $('#next').addEventListener('click',()=>step(1));
  document.querySelector('.surface-picker').addEventListener('click',e=>{
    const b=e.target.closest('button[data-surface]'); if(!b)return;
    dark=b.dataset.surface==='dark';
    document.querySelectorAll('[data-surface]').forEach(k=>k.setAttribute('aria-pressed',String(k===b)));
    proofs();
  });
  $('.word-picker').addEventListener('click',e=>{
    const b=e.target.closest('button[data-word]'); if(!b)return;
    word=b.dataset.word;renderCatalog();choose(active);
  });
  $('#export').addEventListener('click',()=>{
    const blob=new Blob([mark(active,{kind:'logo',word})],{type:'image/svg+xml;charset=utf-8'});
    const url=URL.createObjectURL(blob);
    const a=document.createElement('a');a.href=url;
    a.download='speak-low-'+active.id+(active.family==='face'?'-'+word.replace(' ','-'):'')+'.svg';
    document.body.append(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),3000);
    $('#status').textContent='已导出「'+active.name+'」的 SVG 文件';
  });
  $('#colors').addEventListener('click',async e=>{
    const b=e.target.closest('button[data-color]');if(!b)return;
    const hex=b.dataset.color.toUpperCase();
    try {
      if(!navigator.clipboard)throw Error();
      await navigator.clipboard.writeText(hex);
      b.classList.add('copied');b.querySelector('.tooltip').textContent='已复制';
      $('#status').textContent='已复制 '+hex;
      setTimeout(()=>{b.classList.remove('copied');b.querySelector('.tooltip').textContent=hex;},1100);
    } catch { window.prompt('复制这个色值',hex); }
  });
  $('.brand').addEventListener('click',e=>{e.preventDefault();editing=false;changeFilter('all');choose(designs[0]);});
  window.addEventListener('hashchange',()=>{
    const target=designs.find(d=>'#'+d.id===location.hash);
    if(!target)return;
    if(!listed().includes(target))changeFilter('all');
    choose(target);
  });
  document.querySelectorAll('[data-filter]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.filter===filter)));
  renderCatalog();display();
})();
