// Shape controls share the same geometry and coordinate system as the exported mark.
(() => {
  'use strict';
  const {fields,moods,defaults,limit,geometry}=window.SpeakLowBubbles;
  const $=selector=>document.querySelector(selector);
  const values={};
  let design, layer, invalidate, commit;
  let gesture=null;
  const lastLayer={};
  const defaultsForLayer=()=>defaults(layer);
  const current=()=>values[design.id]?.[layer] ?? defaultsForLayer();
  const fieldFor=key=>fields.find(field=>field.key===key);

  function setLayerValues(id,mood,settings) {
    const initial=defaults(mood);
    if(fields.every(({key})=>settings[key]===initial[key])) {
      if(values[id]) {
        delete values[id][mood];
        if(Object.keys(values[id]).length===0) delete values[id];
      }
    } else {
      (values[id]??={})[mood]=settings;
    }
  }
  function restore(id,query) {
    if(!moods[id]) return;
    for(const entry of (query.get('shape')||'').split(';')) {
      const [mood,encoded]=entry.split(':');
      if(!moods[id].includes(mood)||!encoded) continue;
      const parts=encoded.split(',');
      if(parts.length!==fields.length || !parts.every(p=>/^-?\d{1,4}$/.test(p))) continue;
      setLayerValues(id,mood,Object.fromEntries(fields.map((f,i)=>[f.key,limit(f,Number(parts[i]))])));
    }
    if(moods[id].includes(query.get('layer'))) lastLayer[id]=query.get('layer');
  }
  function save(id,params) {
    const encoded=(moods[id]||[]).filter(m=>values[id]?.[m]).map(m=>
      m+':'+fields.map(f=>values[id][m][f.key]).join(','));
    if(encoded.length) params.set('shape',encoded.join(';')); else params.delete('shape');
    if(lastLayer[id] && lastLayer[id]!==moods[id]?.[0]) params.set('layer',lastLayer[id]);
    else params.delete('layer');
  }
  function setDesign(next) {
    design=next;
    layer=lastLayer[next.id] ?? moods[next.id]?.[0];
  }
  function selectLayer(mood) {
    lastLayer[design.id]=mood;
    layer=mood;
    sync();
    commit();
  }
  function update(partial) {
    const updated={...current(),...partial};
    setLayerValues(design.id,layer,updated);
    invalidate();
  }
  function init(onEdit,onCommit) {
    invalidate=onEdit;
    commit=onCommit;
    for(const field of fields) {
      const wrapper=document.createElement('div');
      wrapper.className='shape-control';
      const label=document.createElement('label'), output=document.createElement('output');
      const input=document.createElement('input');
      input.type='range'; input.id='shape-'+field.key; input.min=field.min; input.max=field.max;
      input.step=1; label.htmlFor=input.id; label.textContent=field.label;
      output.setAttribute('for',input.id); output.id=input.id+'-value'; output.setAttribute('aria-hidden','true');
      wrapper.append(label,output,input);
      $(field.key==='length'||field.key==='position'?'#tail-fields':'#body-fields').append(wrapper);
      input.addEventListener('input',()=>update({[field.key]:Number(input.value)}));
      input.addEventListener('change',onCommit);
    }
    $('#reset-shape').addEventListener('click',()=>{update(defaultsForLayer());commit();});
    $('#layer-picker').addEventListener('click',e=>{
      const button=e.target.closest('[data-layer]');
      if(button && moods[design.id].includes(button.dataset.layer)) selectLayer(button.dataset.layer);
    });
    const handles=$('#handles');
    handles.addEventListener('pointerdown',startDrag);
    handles.addEventListener('pointermove',moveDrag);
    for(const event of ['pointerup','pointercancel','lostpointercapture']) {
      handles.addEventListener(event,e=>{
        if(!gesture || e.pointerId!==gesture.id) return;
        gesture=null;
        if(handles.hasPointerCapture(e.pointerId)) handles.releasePointerCapture(e.pointerId);
        commit();
      });
    }
  }
  function sync() {
    if(!layer) return;
    const settings=current();
    const hasEdit=Boolean(values[design.id]?.[layer]);
    $('#reset-shape').disabled=!hasEdit;
    $('#layer-picker').hidden=moods[design.id].length===1;
    document.querySelectorAll('[data-layer]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.layer===layer)));
    for(const {key,min,max,unit} of fields) {
      const input=$('#shape-'+key), value=settings[key], valueText=value+unit;
      input.value=value;
      input.setAttribute('aria-valuetext',valueText);
      input.style.setProperty('--progress',100*(value-min)/(max-min)+'%');
      $('#shape-'+key+'-value').value=valueText;
    }
    drawHandles(settings);
  }
  function frame() { return $('#drawing').querySelector('[data-frame="'+layer+'"]'); }
  function drawHandles(s) {
    const selected=frame(), handles=$('#handles');
    if(!selected || handles.hasAttribute('hidden')) return;
    const matrix=handles.getScreenCTM().inverse().multiply(selected.getScreenCTM());
    const map=([x,y])=>new DOMPoint(60+(x-60)*s.width/100,47+(y-47)*s.height/100).matrixTransform(matrix);
    const pointString=p=>p.x+' '+p.y;
    const size=map([120,0]), tip=map(geometry(layer,s).tail.tip);
    handles.querySelector('[data-handle="size"]').setAttribute('transform','translate('+pointString(size)+')');
    handles.querySelector('[data-handle="tail"]').setAttribute('transform','translate('+pointString(tip)+')');
    const corner=[map([103,0]),size,map([120,17])];
    $('#handle-box').setAttribute('d','M'+corner.map(pointString).join(' L'));
  }
  function startDrag(e) {
    const handle=e.target.closest('[data-handle]');
    if(!handle || gesture || e.button!==0) return;
    e.preventDefault();
    const inverse=frame().getScreenCTM().inverse();
    const settings={...current()};
    gesture={id:e.pointerId,handle:handle.dataset.handle,inverse,settings,
      start:new DOMPoint(e.clientX,e.clientY).matrixTransform(inverse),tail:geometry(layer,settings).tail};
    $('#handles').setPointerCapture(e.pointerId);
  }
  function moveDrag(e) {
    if(!gesture || e.pointerId!==gesture.id) return;
    const {inverse,start,handle,settings:s,tail}=gesture;
    const point=new DOMPoint(e.clientX,e.clientY).matrixTransform(inverse);
    const dx=point.x-start.x,dy=point.y-start.y;
    if(handle==='size') {
      update({width:limit(fieldFor('width'),s.width+dx/60*100), height:limit(fieldFor('height'),s.height-dy/47*100)});
    } else {
      const position=limit(fieldFor('position'),s.position+dx/(s.width/100)/tail.travel*100);
      const movedX=(position-s.position)*tail.travel/100;
      update({position,length:limit(fieldFor('length'),s.length+(dy/(s.height/100)-tail.slope*movedX)/tail.rise*100)});
    }
  }
  window.SpeakLowShapeEditor={init,setDesign,restore,save,sync,changes:id=>values[id]};
})();
