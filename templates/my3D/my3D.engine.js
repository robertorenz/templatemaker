
/* =====================================================================
   my3D / WebGL2 engine  —  data-driven renderer.
   The Clarion WebGL2Class emits this engine verbatim plus a SCENE object.
   Drag = orbit, wheel = dolly, R = reset camera.
   ===================================================================== */

/* ------- minimal mat4 (column-major, like WebGL) ------- */
const M4 = {
  ident(){return new Float32Array([1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1]);},
  mul(a,b){const o=new Float32Array(16);
    for(let c=0;c<4;c++)for(let r=0;r<4;r++){let s=0;
      for(let k=0;k<4;k++)s+=a[k*4+r]*b[c*4+k];o[c*4+r]=s;}return o;},
  persp(fovyDeg,asp,n,f){const t=Math.tan(fovyDeg*Math.PI/360),nf=1/(n-f);
    return new Float32Array([1/(asp*t),0,0,0, 0,1/t,0,0, 0,0,(f+n)*nf,-1, 0,0,2*f*n*nf,0]);},
  look(eye,ctr,up){
    let z=V.norm(V.sub(eye,ctr)); if(V.len(z)<1e-6)z=[0,0,1];
    let x=V.norm(V.cross(up,z)); if(V.len(x)<1e-6)x=[1,0,0];
    let y=V.cross(z,x);
    return new Float32Array([x[0],y[0],z[0],0, x[1],y[1],z[1],0, x[2],y[2],z[2],0,
      -V.dot(x,eye),-V.dot(y,eye),-V.dot(z,eye),1]);},
  trans(x,y,z){const m=M4.ident();m[12]=x;m[13]=y;m[14]=z;return m;},
  scale(x,y,z){const m=M4.ident();m[0]=x;m[5]=y;m[10]=z;return m;},
  rotX(a){const c=Math.cos(a),s=Math.sin(a);const m=M4.ident();m[5]=c;m[6]=s;m[9]=-s;m[10]=c;return m;},
  rotY(a){const c=Math.cos(a),s=Math.sin(a);const m=M4.ident();m[0]=c;m[2]=-s;m[8]=s;m[10]=c;return m;},
  rotZ(a){const c=Math.cos(a),s=Math.sin(a);const m=M4.ident();m[0]=c;m[1]=s;m[4]=-s;m[5]=c;return m;},
  /* upper-left 3x3 inverse-transpose -> normal matrix (mat3 as 9 floats) */
  normal(m){
    const a00=m[0],a01=m[1],a02=m[2],a10=m[4],a11=m[5],a12=m[6],a20=m[8],a21=m[9],a22=m[10];
    const b01= a22*a11-a12*a21, b11=-a22*a10+a12*a20, b21= a21*a10-a11*a20;
    let det=a00*b01+a01*b11+a02*b21; det=det?1/det:0;
    return new Float32Array([
      b01*det,(-a22*a01+a02*a21)*det,( a12*a01-a02*a11)*det,
      b11*det,( a22*a00-a02*a20)*det,(-a12*a00+a02*a10)*det,
      b21*det,(-a21*a00+a01*a20)*det,( a11*a00-a01*a10)*det]);}
};
const V = {
  sub(a,b){return [a[0]-b[0],a[1]-b[1],a[2]-b[2]];},
  add(a,b){return [a[0]+b[0],a[1]+b[1],a[2]+b[2]];},
  cross(a,b){return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];},
  dot(a,b){return a[0]*b[0]+a[1]*b[1]+a[2]*b[2];},
  len(a){return Math.hypot(a[0],a[1],a[2]);},
  norm(a){const l=V.len(a)||1;return [a[0]/l,a[1]/l,a[2]/l];}
};

/* ===================== geometry builders ===================== */
/* each returns {p:[xyz...], n:[xyz...], i:[...]} (triangles, indexed) */
function pushTri(g,a,b,c){ // for flat-shaded non-indexed solids
  const n=V.norm(V.cross(V.sub(b,a),V.sub(c,a)));
  for(const v of [a,b,c]){g.p.push(v[0],v[1],v[2]);g.n.push(n[0],n[1],n[2]);g.i.push(g.i.length);}
}
function box(w,h,d){const g={p:[],n:[],i:[]};const x=w/2,y=h/2,z=d/2;
  const v=[[-x,-y,z],[x,-y,z],[x,y,z],[-x,y,z],[-x,-y,-z],[x,-y,-z],[x,y,-z],[-x,y,-z]];
  const f=[[0,1,2,3],[5,4,7,6],[3,2,6,7],[4,5,1,0],[1,5,6,2],[4,0,3,7]];
  for(const q of f){pushTri(g,v[q[0]],v[q[1]],v[q[2]]);pushTri(g,v[q[0]],v[q[2]],v[q[3]]);}
  return g;}
function sphere(r,seg){seg=Math.max(3,seg|0);const rings=seg,segs=seg*2;const g={p:[],n:[],i:[]};
  for(let y=0;y<=rings;y++){const v=y/rings,ph=v*Math.PI;
    for(let x=0;x<=segs;x++){const u=x/segs,th=u*2*Math.PI;
      const nx=Math.sin(ph)*Math.cos(th),ny=Math.cos(ph),nz=Math.sin(ph)*Math.sin(th);
      g.p.push(nx*r,ny*r,nz*r);g.n.push(nx,ny,nz);}}
  for(let y=0;y<rings;y++)for(let x=0;x<segs;x++){const a=y*(segs+1)+x,b=a+segs+1;
    g.i.push(a,b,a+1, b,b+1,a+1);}return g;}
function cylinder(rt,rb,h,seg){seg=Math.max(3,seg|0);const g={p:[],n:[],i:[]};const y=h/2;
  for(let s=0;s<seg;s++){const t0=s/seg*2*Math.PI,t1=(s+1)/seg*2*Math.PI;
    const c0=Math.cos(t0),s0=Math.sin(t0),c1=Math.cos(t1),s1=Math.sin(t1);
    const top0=[c0*rt,y,s0*rt],top1=[c1*rt,y,s1*rt],bot0=[c0*rb,-y,s0*rb],bot1=[c1*rb,-y,s1*rb];
    pushTri(g,bot0,bot1,top1);pushTri(g,bot0,top1,top0);
    if(rt>1e-4){pushTri(g,[0,y,0],top0,top1);}
    if(rb>1e-4){pushTri(g,[0,-y,0],bot1,bot0);}}
  return g;}
function cone(r,h,seg){return cylinder(0,r,h,seg);}
function plane(w,d){const g={p:[],n:[],i:[]};const x=w/2,z=d/2;
  pushTri(g,[-x,0,z],[x,0,z],[x,0,-z]);pushTri(g,[-x,0,z],[x,0,-z],[-x,0,-z]);return g;}
function torus(R,rt,rs,ts){rs=Math.max(3,rs|0);ts=Math.max(3,ts|0);const g={p:[],n:[],i:[]};
  for(let i=0;i<=rs;i++){const u=i/rs*2*Math.PI;
    for(let j=0;j<=ts;j++){const v=j/ts*2*Math.PI;
      const cx=Math.cos(u)*R,cz=Math.sin(u)*R;
      const px=Math.cos(u)*(R+rt*Math.cos(v)),py=rt*Math.sin(v),pz=Math.sin(u)*(R+rt*Math.cos(v));
      g.p.push(px,py,pz);const nn=V.norm([px-cx,py,pz-cz]);g.n.push(nn[0],nn[1],nn[2]);}}
  for(let i=0;i<rs;i++)for(let j=0;j<ts;j++){const a=i*(ts+1)+j,b=a+ts+1;g.i.push(a,b,a+1,b,b+1,a+1);}
  return g;}
function torusKnot(R,rt,p,q,tubeSeg,radSeg){
  p=p||2;q=q||3;tubeSeg=tubeSeg||120;radSeg=radSeg||10;const g={p:[],n:[],i:[]};
  const cur=t=>{const u=t,r=R*(2+Math.cos(q*u))*0.5;
    return [r*Math.cos(p*u),r*Math.sin(p*u),R*Math.sin(q*u)*0.5];};
  for(let i=0;i<=tubeSeg;i++){const u=i/tubeSeg*2*Math.PI;
    const P0=cur(u),P1=cur(u+0.01);let T=V.norm(V.sub(P1,P0));
    let N=V.norm(V.cross(T,[0,1,0]));if(V.len(N)<1e-3)N=V.norm(V.cross(T,[1,0,0]));
    let B=V.norm(V.cross(T,N));
    for(let j=0;j<=radSeg;j++){const v=j/radSeg*2*Math.PI;
      const cx=Math.cos(v),cy=Math.sin(v);
      const nx=cx*N[0]+cy*B[0],ny=cx*N[1]+cy*B[1],nz=cx*N[2]+cy*B[2];
      g.p.push(P0[0]+rt*nx,P0[1]+rt*ny,P0[2]+rt*nz);g.n.push(nx,ny,nz);}}
  for(let i=0;i<tubeSeg;i++)for(let j=0;j<radSeg;j++){const a=i*(radSeg+1)+j,b=a+radSeg+1;
    g.i.push(a,b,a+1,b,b+1,a+1);}return g;}
/* platonic solids via vertex/face tables, flat shaded */
function polyhedron(verts,faces,r){const g={p:[],n:[],i:[]};
  const vs=verts.map(v=>{const s=r/V.len(v);return [v[0]*s,v[1]*s,v[2]*s];});
  for(const f of faces){for(let k=1;k<f.length-1;k++)pushTri(g,vs[f[0]],vs[f[k]],vs[f[k+1]]);}
  return g;}
function tetra(r){return polyhedron([[1,1,1],[-1,-1,1],[-1,1,-1],[1,-1,-1]],
  [[2,1,0],[0,3,2],[1,3,0],[2,3,1]],r);}
function octa(r){return polyhedron([[1,0,0],[-1,0,0],[0,1,0],[0,-1,0],[0,0,1],[0,0,-1]],
  [[0,2,4],[2,1,4],[1,3,4],[3,0,4],[2,0,5],[1,2,5],[3,1,5],[0,3,5]],r);}
function icosa(r){const t=(1+Math.sqrt(5))/2;
  const v=[[-1,t,0],[1,t,0],[-1,-t,0],[1,-t,0],[0,-1,t],[0,1,t],[0,-1,-t],[0,1,-t],
    [t,0,-1],[t,0,1],[-t,0,-1],[-t,0,1]];
  const f=[[0,11,5],[0,5,1],[0,1,7],[0,7,10],[0,10,11],[1,5,9],[5,11,4],[11,10,2],[10,7,6],[7,1,8],
    [3,9,4],[3,4,2],[3,2,6],[3,6,8],[3,8,9],[4,9,5],[2,4,11],[6,2,10],[8,6,7],[9,8,1]];
  return polyhedron(v,f,r);}
function dodeca(r){const t=(1+Math.sqrt(5))/2,n=1/t;
  const v=[[-1,-1,-1],[-1,-1,1],[-1,1,-1],[-1,1,1],[1,-1,-1],[1,-1,1],[1,1,-1],[1,1,1],
    [0,-n,-t],[0,-n,t],[0,n,-t],[0,n,t],[-n,-t,0],[-n,t,0],[n,-t,0],[n,t,0],
    [-t,0,-n],[t,0,-n],[-t,0,n],[t,0,n]];
  const f=[[3,11,7],[3,7,15],[3,15,13],[7,19,17],[7,17,6],[7,6,15],[17,4,8],[17,8,10],[17,10,6],
    [8,0,16],[8,16,2],[8,2,10],[0,12,1],[0,1,18],[0,18,16],[6,10,2],[6,2,13],[13,2,16],
    [13,16,18],[13,18,3],[3,18,1],[3,1,11],[11,1,12],[11,12,9],[11,9,7],[7,9,19],[19,9,5],
    [19,5,4],[19,4,17],[4,5,14],[4,14,8],[8,14,0],[0,14,12],[12,14,5],[12,5,9]];
  return polyhedron(v,f,r);}

function buildGeo(type,params){const a=params||[];
  switch((type||'box').toLowerCase()){
    case 'box': return box(a[0]||1,a[1]||a[0]||1,a[2]||a[0]||1);
    case 'sphere': return sphere(a[0]||0.7,a[1]||24);
    case 'cylinder': return cylinder(a[0]??0.5,a[1]??0.5,a[2]||1,a[3]||32);
    case 'cone': return cone(a[0]||0.6,a[1]||1.2,a[2]||32);
    case 'plane': return plane(a[0]||2,a[1]||a[0]||2);
    case 'torus': return torus(a[0]||0.7,a[1]||0.28,a[2]||24,a[3]||16);
    case 'torusknot': return torusKnot(a[0]||0.8,a[1]||0.22,a[2]||2,a[3]||3,a[4]||140,a[5]||12);
    case 'tetra': return tetra(a[0]||0.8);
    case 'octa': return octa(a[0]||0.8);
    case 'icosa': return icosa(a[0]||0.8);
    case 'dodeca': return dodeca(a[0]||0.8);
    default: return box(1,1,1);
  }
}

/* ===================== WebGL plumbing ===================== */
const SC = window.SCENE || {};
const canvas = document.getElementById('gl');
const errBox = document.getElementById('err');
function fail(m){errBox.style.display='block';errBox.textContent='WebGL2 error:\n'+m;throw new Error(m);}
const gl = canvas.getContext('webgl2',{antialias:(SC.canvas&&SC.canvas.aa)!==false});
if(!gl) fail('WebGL2 is not available in this browser.');

function sh(type,src){const s=gl.createShader(type);gl.shaderSource(s,src);gl.compileShader(s);
  if(!gl.getShaderParameter(s,gl.COMPILE_STATUS))fail(gl.getShaderInfoLog(s)+'\n'+src);return s;}
function prog(vs,fs){const p=gl.createProgram();gl.attachShader(p,sh(gl.VERTEX_SHADER,vs));
  gl.attachShader(p,sh(gl.FRAGMENT_SHADER,fs));gl.linkProgram(p);
  if(!gl.getProgramParameter(p,gl.LINK_STATUS))fail(gl.getProgramInfoLog(p));return p;}

const MAXP = 8;
const meshVS = `#version 300 es
layout(location=0) in vec3 aPos; layout(location=1) in vec3 aNor;
uniform mat4 uProj,uView,uModel; uniform mat3 uNorm;
out vec3 vN; out vec3 vWorld;
void main(){vec4 w=uModel*vec4(aPos,1.0); vWorld=w.xyz; vN=normalize(uNorm*aNor);
  gl_Position=uProj*uView*w;}`;
const meshFS = `#version 300 es
precision highp float;
in vec3 vN; in vec3 vWorld; out vec4 frag;
uniform vec3 uCam, uAmbient, uDirDir, uDirCol; uniform float uDirInt;
uniform int uNP; uniform vec3 uPPos[${MAXP}], uPCol[${MAXP}]; uniform float uPInt[${MAXP}], uPRange[${MAXP}];
uniform vec3 uColor, uEmissive; uniform float uMetal, uRough, uOpacity;
uniform int uFog; uniform vec3 uFogCol; uniform float uFogN, uFogF;
void main(){
  vec3 N=normalize(vN); vec3 Vd=normalize(uCam-vWorld);
  float shin=mix(4.0,80.0,1.0-clamp(uRough,0.0,1.0));
  float specStr=mix(0.25,0.9,1.0-clamp(uRough,0.0,1.0));
  vec3 baseAmb=uAmbient*uColor;
  vec3 col=baseAmb+uEmissive;
  // directional
  {vec3 L=normalize(-uDirDir); float d=max(dot(N,L),0.0);
   vec3 H=normalize(L+Vd); float sp=pow(max(dot(N,H),0.0),shin)*specStr;
   vec3 specCol=mix(vec3(1.0),uColor,uMetal);
   col+=uDirCol*uDirInt*(uColor*d + specCol*sp*step(0.0001,d));}
  // point lights
  for(int i=0;i<${MAXP};i++){ if(i>=uNP) break;
   vec3 Ld=uPPos[i]-vWorld; float dist=length(Ld); vec3 L=Ld/max(dist,1e-4);
   float att=clamp(1.0-dist/max(uPRange[i],1e-4),0.0,1.0); att*=att;
   float d=max(dot(N,L),0.0);
   vec3 H=normalize(L+Vd); float sp=pow(max(dot(N,H),0.0),shin)*specStr;
   vec3 specCol=mix(vec3(1.0),uColor,uMetal);
   col+=uPCol[i]*uPInt[i]*att*(uColor*d+specCol*sp*step(0.0001,d));}
  if(uFog==1){float f=clamp((distance(uCam,vWorld)-uFogN)/max(uFogF-uFogN,1e-4),0.0,1.0);
    col=mix(col,uFogCol,f);}
  frag=vec4(col,uOpacity);}`;
const lineVS = `#version 300 es
layout(location=0) in vec3 aPos; layout(location=1) in vec3 aCol;
uniform mat4 uProj,uView; out vec3 vC;
void main(){vC=aCol; gl_Position=uProj*uView*vec4(aPos,1.0);}`;
const lineFS = `#version 300 es
precision highp float; in vec3 vC; out vec4 frag; void main(){frag=vec4(vC,1.0);}`;

const mp = prog(meshVS,meshFS);
const lp = prog(lineVS,lineFS);
const U = {};
for(const n of ['uProj','uView','uModel','uNorm','uCam','uAmbient','uDirDir','uDirCol','uDirInt',
  'uNP','uColor','uEmissive','uMetal','uRough','uOpacity','uFog','uFogCol','uFogN','uFogF'])
  U[n]=gl.getUniformLocation(mp,n);
for(let i=0;i<MAXP;i++){U['uPPos'+i]=gl.getUniformLocation(mp,`uPPos[${i}]`);
  U['uPCol'+i]=gl.getUniformLocation(mp,`uPCol[${i}]`);
  U['uPInt'+i]=gl.getUniformLocation(mp,`uPInt[${i}]`);
  U['uPRange'+i]=gl.getUniformLocation(mp,`uPRange[${i}]`);}
const LU={uProj:gl.getUniformLocation(lp,'uProj'),uView:gl.getUniformLocation(lp,'uView')};

function makeMesh(geo,wire){
  const vao=gl.createVertexArray();gl.bindVertexArray(vao);
  const inter=[];for(let k=0;k<geo.p.length/3;k++){
    inter.push(geo.p[k*3],geo.p[k*3+1],geo.p[k*3+2],geo.n[k*3],geo.n[k*3+1],geo.n[k*3+2]);}
  const vb=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,vb);
  gl.bufferData(gl.ARRAY_BUFFER,new Float32Array(inter),gl.STATIC_DRAW);
  gl.enableVertexAttribArray(0);gl.vertexAttribPointer(0,3,gl.FLOAT,false,24,0);
  gl.enableVertexAttribArray(1);gl.vertexAttribPointer(1,3,gl.FLOAT,false,24,12);
  let idx=geo.i,mode=gl.TRIANGLES;
  if(wire){const li=[];for(let t=0;t<geo.i.length;t+=3){const a=geo.i[t],b=geo.i[t+1],c=geo.i[t+2];
      li.push(a,b,b,c,c,a);}idx=li;mode=gl.LINES;}
  const ib=gl.createBuffer();gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER,ib);
  gl.bufferData(gl.ELEMENT_ARRAY_BUFFER,new Uint32Array(idx),gl.STATIC_DRAW);
  gl.bindVertexArray(null);
  return {vao,count:idx.length,mode};
}
function makeLines(pos,col){
  const vao=gl.createVertexArray();gl.bindVertexArray(vao);
  const inter=[];for(let k=0;k<pos.length/3;k++){
    inter.push(pos[k*3],pos[k*3+1],pos[k*3+2],col[k*3],col[k*3+1],col[k*3+2]);}
  const vb=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,vb);
  gl.bufferData(gl.ARRAY_BUFFER,new Float32Array(inter),gl.STATIC_DRAW);
  gl.enableVertexAttribArray(0);gl.vertexAttribPointer(0,3,gl.FLOAT,false,24,0);
  gl.enableVertexAttribArray(1);gl.vertexAttribPointer(1,3,gl.FLOAT,false,24,12);
  gl.bindVertexArray(null);return {vao,count:pos.length/3};
}

/* ---- build scene objects ---- */
const wireGlobal = !!SC.wireframe;
const objs = (SC.meshes||[]).map(m=>{
  const geo=buildGeo(m.type,m.params);
  const wire=wireGlobal||!!m.wire;
  return {gl:makeMesh(geo,wire),m,wire,
    pos:m.pos||[0,0,0],rot:(m.rot||[0,0,0]).slice(),scale:m.scale||[1,1,1],spin:m.spin||[0,0,0]};
});

/* grid + axes line buffers */
let gridObj=null, axesObj=null;
if(SC.grid&&SC.grid.on){const sz=SC.grid.size||20,dv=SC.grid.div||20,c=SC.grid.color||[0.2,0.22,0.28];
  const p=[],col=[];const h=sz/2,st=sz/dv;
  for(let i=0;i<=dv;i++){const x=-h+i*st;
    p.push(x,0,-h,x,0,h,-h,0,x,h,0,x);for(let k=0;k<4;k++)col.push(c[0],c[1],c[2]);}
  gridObj=makeLines(p,col);}
if(SC.axes&&SC.axes.on){const s=SC.axes.size||3;
  const p=[0,0,0,s,0,0, 0,0,0,0,s,0, 0,0,0,0,0,s];
  const col=[1,.3,.3,1,.3,.3, .3,1,.3,.3,1,.3, .4,.5,1,.4,.5,1];
  axesObj=makeLines(p,col);}

/* ===================== camera ===================== */
const cam=SC.camera||{};
const target=cam.target||[0,0,0];
let radius, yaw, pitch;
(function(){const p=cam.pos||[6,5,9];const d=V.sub(p,target);radius=V.len(d)||12;
  yaw=Math.atan2(d[0],d[2]);pitch=Math.asin(d[1]/radius);})();
let orbit=cam.orbit!==false, orbitSpeed=cam.orbitSpeed!=null?cam.orbitSpeed:0.3;
function eye(){return [target[0]+radius*Math.cos(pitch)*Math.sin(yaw),
  target[1]+radius*Math.sin(pitch), target[2]+radius*Math.cos(pitch)*Math.cos(yaw)];}
/* mouse */
let drag=false,lx=0,ly=0;
canvas.addEventListener('mousedown',e=>{drag=true;lx=e.clientX;ly=e.clientY;orbit=false;});
addEventListener('mouseup',()=>drag=false);
addEventListener('mousemove',e=>{if(!drag)return;yaw-=(e.clientX-lx)*0.008;
  pitch=Math.max(-1.5,Math.min(1.5,pitch+(e.clientY-ly)*0.008));lx=e.clientX;ly=e.clientY;});
canvas.addEventListener('wheel',e=>{e.preventDefault();
  radius=Math.max(1.2,Math.min(400,radius*(1+Math.sign(e.deltaY)*0.08)));},{passive:false});
addEventListener('keydown',e=>{if(e.key==='r'||e.key==='R'){const p=cam.pos||[6,5,9];
  const d=V.sub(p,target);radius=V.len(d)||12;yaw=Math.atan2(d[0],d[2]);pitch=Math.asin(d[1]/radius);
  orbit=cam.orbit!==false;}});

/* ===================== sizing ===================== */
function resize(){const cw=(SC.canvas&&SC.canvas.w)||960,ch=(SC.canvas&&SC.canvas.h)||600;
  const dpr=Math.min(devicePixelRatio||1,2);
  canvas.style.width=cw+'px';canvas.style.height=ch+'px';
  canvas.width=Math.round(cw*dpr);canvas.height=Math.round(ch*dpr);}
resize();addEventListener('resize',resize);

/* ===================== lights ===================== */
const L=SC.lights||{};
const amb=L.ambient||[0.22,0.24,0.3];
const dir=(L.dir&&L.dir.dir)||[-1,-2,-1.3];
const dirCol=(L.dir&&L.dir.color)||[1,1,1];
const dirInt=(L.dir&&L.dir.intensity!=null)?L.dir.intensity:1.0;
const pts=(L.points||[]).slice(0,MAXP);

/* ===================== background ===================== */
const bg=SC.background||{type:'solid',color:[0.04,0.05,0.08]};
function bgClear(){let c=bg.color||(bg.bottom)||[0.04,0.05,0.08];
  gl.clearColor(c[0],c[1],c[2],1);gl.clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT);}

/* HUD */
document.getElementById('hud').innerHTML =
  `<b>${(SC.title||'my3D / WebGL2').replace(/</g,'&lt;')}</b><br>`+
  `<span class="k">meshes</span> ${objs.length} &nbsp; `+
  `<span class="k">point lights</span> ${pts.length}<br>`+
  `<span class="k">drag</span> orbit &nbsp; <span class="k">wheel</span> dolly &nbsp; <span class="k">R</span> reset`;

/* ===================== render loop ===================== */
gl.enable(gl.DEPTH_TEST);
let last=performance.now(),fpsAcc=0,fpsN=0,fpsT=0;
function frame(now){const dt=Math.min(0.05,(now-last)/1000);last=now;
  fpsAcc+=1/Math.max(dt,1e-4);fpsN++;fpsT+=dt;
  if(fpsT>0.5){document.getElementById('fps').textContent=Math.round(fpsAcc/fpsN)+' fps';fpsAcc=0;fpsN=0;fpsT=0;}
  if(orbit) yaw+=orbitSpeed*dt;

  gl.viewport(0,0,canvas.width,canvas.height);
  bgClear();
  const asp=canvas.width/canvas.height;
  const proj=M4.persp(cam.fov||50,asp,cam.near||0.1,cam.far||300);
  const E=eye();const view=M4.look(E,target,[0,1,0]);

  /* lines first (grid/axes) */
  if(gridObj||axesObj){gl.useProgram(lp);
    gl.uniformMatrix4fv(LU.uProj,false,proj);gl.uniformMatrix4fv(LU.uView,false,view);
    if(gridObj){gl.bindVertexArray(gridObj.vao);gl.drawArrays(gl.LINES,0,gridObj.count);}
    if(axesObj){gl.bindVertexArray(axesObj.vao);gl.drawArrays(gl.LINES,0,axesObj.count);}}

  /* meshes */
  gl.useProgram(mp);
  gl.uniformMatrix4fv(U.uProj,false,proj);gl.uniformMatrix4fv(U.uView,false,view);
  gl.uniform3fv(U.uCam,E);gl.uniform3fv(U.uAmbient,amb);
  gl.uniform3fv(U.uDirDir,dir);gl.uniform3fv(U.uDirCol,dirCol);gl.uniform1f(U.uDirInt,dirInt);
  gl.uniform1i(U.uNP,pts.length);
  pts.forEach((p,i)=>{gl.uniform3fv(U['uPPos'+i],p.pos||[0,0,0]);
    gl.uniform3fv(U['uPCol'+i],p.color||[1,1,1]);
    gl.uniform1f(U['uPInt'+i],p.intensity!=null?p.intensity:1);
    gl.uniform1f(U['uPRange'+i],p.range||20);});
  const fog=SC.fog&&SC.fog.on;
  gl.uniform1i(U.uFog,fog?1:0);
  if(fog){gl.uniform3fv(U.uFogCol,SC.fog.color||bg.color||[0,0,0]);
    gl.uniform1f(U.uFogN,SC.fog.near||8);gl.uniform1f(U.uFogF,SC.fog.far||40);}

  for(const o of objs){
    o.rot[0]+=o.spin[0]*dt;o.rot[1]+=o.spin[1]*dt;o.rot[2]+=o.spin[2]*dt;
    let model=M4.trans(o.pos[0],o.pos[1],o.pos[2]);
    model=M4.mul(model,M4.rotY(o.rot[1]));model=M4.mul(model,M4.rotX(o.rot[0]));
    model=M4.mul(model,M4.rotZ(o.rot[2]));
    model=M4.mul(model,M4.scale(o.scale[0],o.scale[1],o.scale[2]));
    gl.uniformMatrix4fv(U.uModel,false,model);
    gl.uniformMatrix3fv(U.uNorm,false,M4.normal(model));
    const mm=o.m;
    gl.uniform3fv(U.uColor,mm.color||[0.8,0.8,0.85]);
    gl.uniform3fv(U.uEmissive,mm.emissive||[0,0,0]);
    gl.uniform1f(U.uMetal,mm.metalness!=null?mm.metalness:0.1);
    gl.uniform1f(U.uRough,mm.roughness!=null?mm.roughness:0.55);
    const op=mm.opacity!=null?mm.opacity:1;
    gl.uniform1f(U.uOpacity,op);
    if(op<1){gl.enable(gl.BLEND);gl.blendFunc(gl.SRC_ALPHA,gl.ONE_MINUS_SRC_ALPHA);}else gl.disable(gl.BLEND);
    gl.bindVertexArray(o.gl.vao);
    gl.drawElements(o.gl.mode,o.gl.count,gl.UNSIGNED_INT,0);
  }
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);
