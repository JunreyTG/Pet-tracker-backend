#pragma once

static const char Dashboard[] PROGMEM = R"HTML(<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Pet Tracker</title>
<style>
 :root{color-scheme:light dark;font-family:system-ui}body{margin:0;background:light-dark(#f1f5f9,#0f172a);color:light-dark(#1e293b,#f8fafc)}
 header{padding:14px 20px;background:#123226;color:#fff;font-weight:800}main{max-width:760px;margin:auto;padding:16px}
 section{padding:16px;margin-bottom:12px;background:light-dark(#fff,#1e293b);border-radius:16px}
 #map,#trail{width:100%;height:clamp(180px,38vh,360px);background:light-dark(#e2e8f0,#334155);border-radius:12px}
 svg[hidden],div[hidden],a[hidden]{display:none}label{display:block;margin-top:10px}
 td{padding:5px 12px 5px 0;overflow-wrap:anywhere}button,input{font:inherit;padding:8px 10px;margin-block:6px}
 button{border:0;border-radius:8px;background:#105b36;color:#fff;min-height:44px}input{box-sizing:border-box;max-width:100%}
 a{color:light-dark(#075e35,#6ee7a0)}.badge{font-weight:750}.help{font-size:.9rem}
</style></head><body>
<header>Pet Tracker · Local dashboard</header>
<main>
 <section>
  <div id="state" class="badge" role="status">Connecting to tracker…</div>
  <div id="map" hidden></div><svg id="trail" viewBox="0 0 320 180" role="img" aria-label="Tracker trail without a basemap"><polyline id="path" fill="none" stroke="#ff5a1f" stroke-width="3"/><circle id="dot" r="4" fill="#16c36a" visibility="hidden"/></svg>
  <p id="mapNote" class="help">Local trail view. Internet access is needed for the street map.</p>
  <table><tbody>
   <tr><td>Tracker code</td><td id="code">—</td></tr>
   <tr><td>Position</td><td id="pos">—</td></tr><tr><td>Satellites</td><td id="sats">—</td></tr>
   <tr><td>HDOP</td><td id="hdop">—</td></tr><tr><td>Speed</td><td id="speed">—</td></tr>
   <tr><td>Distance from Home</td><td id="dist">—</td></tr><tr><td>GPS bytes received</td><td id="chars">—</td></tr>
   <tr><td>Last cloud response</td><td id="cloud">—</td></tr>
  </tbody></table>
  <a id="maps" target="_blank" rel="noopener noreferrer" hidden>Open in Google Maps</a>
 </section>
 <section>
  <strong>Local Home zone</strong>
  <p class="help">This setting applies to this tracker only. Manage app safe zones separately.</p>
  <label for="key">Setup hotspot password</label><input id="key" type="password" autocomplete="off">
  <div><button id="home">Set Home to current position</button></div>
  <label for="radius">Safe radius (meters)</label><input id="radius" type="number" min="10" max="5000" step="1"> <button id="save">Save radius</button>
  <div id="result" role="status"></div>
 </section>
</main>
<script>
const $=id=>document.getElementById(id);
let map,marker,circle,line,centered=false,radiusEdited=false,streetMap=false;
const link=document.createElement('link');
link.rel='stylesheet';link.href='https://unpkg.com/leaflet@1.9.4/dist/leaflet.css';
link.integrity='sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=';link.crossOrigin='anonymous';
document.head.append(link);
const script=document.createElement('script');
script.src='https://unpkg.com/leaflet@1.9.4/dist/leaflet.js';
script.integrity='sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=';script.crossOrigin='anonymous';
script.onload=()=>{
 $('map').hidden=false;
 map=L.map('map').setView([0,0],2);
 const tiles=L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png',{maxZoom:19,attribution:'© OpenStreetMap contributors'}).addTo(map);
 tiles.on('tileload',()=>{if(!streetMap){streetMap=true;$('trail').setAttribute('hidden','');$('mapNote').hidden=true;}});
 setTimeout(()=>{if(!streetMap){$('map').hidden=true;map.remove();map=null;}},12000);
 line=L.polyline([],{color:'#ff5a1f'}).addTo(map);
};
document.head.append(script);

function drawTrail(points,position){
 const all=position?[...points,position]:points;
 if(!all.length){$('path').setAttribute('points','');$('dot').setAttribute('visibility','hidden');return;}
 const lat=all.map(p=>p[0]),lon=all.map(p=>p[1]);
 const loLat=Math.min(...lat),loLon=Math.min(...lon);
 const dy=Math.max(...lat)-loLat,dx=Math.max(...lon)-loLon;
 const scale=Math.min(290/(dx||0.000001),150/(dy||0.000001));
 const pixel=p=>[160+(p[1]-loLon-dx/2)*scale,90-(p[0]-loLat-dy/2)*scale];
 $('path').setAttribute('points',points.map(p=>pixel(p).join(',')).join(' '));
 const dot=pixel(position||all[all.length-1]);
 $('dot').setAttribute('cx',dot[0]);$('dot').setAttribute('cy',dot[1]);$('dot').setAttribute('visibility','visible');
}

async function json(path){
 const r=await fetch(path,{cache:'no-store',signal:AbortSignal.timeout(4500)});
 if(!r.ok)throw Error(r.status);return r.json();
}
async function refresh(){
 try{
  const s=await json('/api/status');
  const p=s.fix?[s.lat,s.lng]:null;
  $('code').textContent=s.device_id;$('sats').textContent=s.sats;$('hdop').textContent=s.hdop?.toFixed(1)??'—';
  $('chars').textContent=s.chars+(s.chars===0?' — check wiring or baud rate':'');
  $('speed').textContent=s.speed==null?'—':s.speed.toFixed(1)+' km/h';
  $('dist').textContent=s.dist<0?'—':Math.round(s.dist)+' m';
  $('cloud').textContent=s.cloud_code===0?'No report yet':s.cloud_code<0?'Connection failed':'HTTP '+s.cloud_code;
  if(!radiusEdited&&document.activeElement!==$('radius'))$('radius').value=s.radius;
  $('state').textContent=!s.fix?'Waiting for GPS fix…':!s.usable_fix?'GPS fix is not accurate enough yet':!s.homeSet?'GPS ready — set Home':!s.fence_known?'Checking Home zone…':s.outside?'Outside Home zone':'Inside Home zone';
  $('pos').textContent=p?p.map(v=>v.toFixed(6)).join(', '):'—';
  $('maps').hidden=!p;
  if(p)$('maps').href='https://maps.google.com/?q='+encodeURIComponent(p.join(','));
  if(map&&p){
   if(!marker)marker=L.circleMarker(p,{color:'#16c36a',radius:7}).addTo(map);else marker.setLatLng(p);
   if(!centered){map.setView(p,17);centered=true;}
  }
  if(map&&s.homeSet){
   const h=[s.homeLat,s.homeLng];
   if(!circle)circle=L.circle(h,{radius:s.radius,color:'#16c36a'}).addTo(map);else{circle.setLatLng(h);circle.setRadius(s.radius);}
  }
  const points=await json('/api/trail');
  if(map)line.setLatLngs(points);
  if(!streetMap)drawTrail(points,p);
 }catch(e){$('state').textContent='Tracker response unavailable — reconnect to its network.';}
 finally{setTimeout(refresh,3000);}
}
async function edit(path){
 const key=$('key').value;
 if(!key){$('result').textContent='Enter your tracker setup password.';return;}
 try{
  const r=await fetch(path,{method:'POST',headers:{'X-Tracker-Key':key},signal:AbortSignal.timeout(4500)});
  $('result').textContent=await r.text();
  if(r.ok){$('key').value='';radiusEdited=false;}
 }catch(e){$('result').textContent='Could not reach the tracker.';}
}
$('radius').addEventListener('input',()=>{radiusEdited=true;});
$('home').addEventListener('click',()=>edit('/api/sethome'));
$('save').addEventListener('click',()=>edit('/api/radius?m='+encodeURIComponent($('radius').value)));
refresh();
</script></body></html>)HTML";
