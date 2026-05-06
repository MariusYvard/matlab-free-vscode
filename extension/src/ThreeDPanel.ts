/**
 * ThreeDPanel.ts — matlab-free-vscode
 * Panneau Webview Three.js pour les objets 3D générés par Octave.
 * Gère : patch avec cdata/colormap, surf, mesh, VRML (.wrl), camlight, lighting.
 */

import * as vscode from 'vscode'
import * as fs     from 'fs'

export interface ThreeDPayload {
    type:      string
    kind?:     'patch' | 'surf' | 'vrml'
    vertices?: number[][]
    faces?:    number[][]
    X?:        number[][]
    Y?:        number[][]
    Z?:        number[][]
    cdata?:    number[]
    facecolor?: string | number[]
    edgecolor?: string
    colormap?:  string
    colorbar?:  boolean
    wrl?:       string
    json?:      string
}

export class ThreeDPanel {
    private static panels: ThreeDPanel[] = []
    private static activePanel: ThreeDPanel | null = null

    static show(id: string, rawPayload: ThreeDPayload): void {
        let payload = rawPayload
        if (payload.json && fs.existsSync(payload.json)) {
            try {
                const data = JSON.parse(fs.readFileSync(payload.json, 'utf8'))
                payload = { ...payload, ...data }
            } catch { /* garde le payload brut */ }
        }

        const col = vscode.ViewColumn.Beside
        const vsPanel = vscode.window.createWebviewPanel(
            'mfv3d',
            `3D — ${id.slice(-6)}`,
            col,
            {
                enableScripts:           true,
                retainContextWhenHidden: true,
                localResourceRoots:      [],
            }
        )
        const p = new ThreeDPanel(vsPanel, payload)
        ThreeDPanel.panels.push(p)
        ThreeDPanel.activePanel = p
        vsPanel.onDidDispose(() => {
            ThreeDPanel.panels = ThreeDPanel.panels.filter(x => x !== p)
            if (ThreeDPanel.activePanel === p) ThreeDPanel.activePanel = null
        })
        vsPanel.onDidChangeViewState(e => {
            if (e.webviewPanel.active) ThreeDPanel.activePanel = p
        })
    }

    static broadcast(msg: object): void {
        ThreeDPanel.activePanel?.vsPanel.webview.postMessage(msg)
    }

    static setTitle(title: string): void {
        if (ThreeDPanel.activePanel)
            ThreeDPanel.activePanel.vsPanel.title = `3D — ${title}`
    }

    private constructor(
        private readonly vsPanel: vscode.WebviewPanel,
        payload: ThreeDPayload,
    ) {
        vsPanel.webview.html = ThreeDPanel.buildHtml(payload)
    }

    private static buildHtml(payload: ThreeDPayload): string {
        const safe = JSON.stringify(payload)
            .replace(/</g, '\\u003c')
            .replace(/>/g, '\\u003e')

        return /* html */`<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<meta http-equiv="Content-Security-Policy"
      content="default-src 'none';
               script-src https://cdn.jsdelivr.net 'unsafe-inline';
               connect-src https://cdn.jsdelivr.net;
               style-src 'unsafe-inline';
               img-src data: blob:;">
<style>
  *{margin:0;padding:0;box-sizing:border-box}
  body{background:#1a1a1a;display:flex;overflow:hidden}
  #wrap{flex:1;position:relative}
  canvas{width:100%;height:100vh;display:block}
  #cbar{width:64px;display:flex;flex-direction:column;align-items:center;
    justify-content:space-between;padding:20px 6px;background:#222;
    font:11px monospace;color:#ccc}
  #cbar.hidden{display:none}
  #cbar canvas{width:20px;height:calc(100vh - 60px);display:block}
  #tb{position:absolute;top:6px;left:6px;display:flex;gap:6px;z-index:10}
  #tb button{background:#2a2a2a;border:1px solid #555;color:#bbb;
    padding:3px 9px;border-radius:3px;cursor:pointer;font-size:11px}
  #tb button:hover{background:#3a3a3a}
  #hint{position:absolute;bottom:6px;left:6px;color:#555;font:10px monospace;pointer-events:none}
</style>
</head>
<body>
<div id="wrap">
  <canvas id="c"></canvas>
  <div id="tb">
    <button onclick="resetCam()">&#x27F3; Reset</button>
    <button onclick="toggleWire()">&#x2B21; Wireframe</button>
    <button id="projBtn" onclick="toggleProj()">&#x2291; Ortho</button>
  </div>
  <div id="hint">Drag · Scroll · Shift+drag pan</div>
</div>
<div id="cbar" class="hidden">
  <span id="cbar-max">1.0</span>
  <canvas id="cbar-c" width="20" height="400"></canvas>
  <span id="cbar-min">0.0</span>
</div>

<script type="module">
import * as THREE from 'https://cdn.jsdelivr.net/npm/three@0.153/build/three.module.js'
import {VRMLLoader}    from 'https://cdn.jsdelivr.net/npm/three@0.153/examples/jsm/loaders/VRMLLoader.js'
import {OrbitControls} from 'https://cdn.jsdelivr.net/npm/three@0.153/examples/jsm/controls/OrbitControls.js'

const payload = ${safe}

const canvas   = document.getElementById('c')
const renderer = new THREE.WebGLRenderer({canvas, antialias:true})
renderer.setPixelRatio(devicePixelRatio)
renderer.shadowMap.enabled = true
renderer.setSize(canvas.parentElement.clientWidth, window.innerHeight)

const scene = new THREE.Scene()
scene.background = new THREE.Color(0x1a1a1a)

const aspect = canvas.parentElement.clientWidth / window.innerHeight
const perspCam = new THREE.PerspectiveCamera(60, aspect, 0.001, 1e6)
perspCam.position.set(1,1,2)
let orthoSize = 2
const orthoCam = new THREE.OrthographicCamera(
  -orthoSize*aspect, orthoSize*aspect, orthoSize, -orthoSize, 0.001, 1e6)
orthoCam.position.set(1,1,2)
let useOrtho = false
let camera = perspCam

const controls = new OrbitControls(camera, renderer.domElement)
controls.enableDamping = true; controls.dampingFactor = 0.08
controls.screenSpacePanning = true

scene.add(new THREE.AmbientLight(0xffffff, 0.45))
const camLight = new THREE.PointLight(0xffffff, 0.9, 0)
scene.add(camLight)
scene.add(Object.assign(new THREE.DirectionalLight(0xffffff,0.4),
  {position: new THREE.Vector3(2,4,3)}))

const axes = new THREE.AxesHelper(0)
scene.add(axes)

const CMAPS = {
  jet:    t => { const c=new THREE.Color();
                 c.r=Math.min(Math.max(1.5-Math.abs(4*t-3),0),1);
                 c.g=Math.min(Math.max(1.5-Math.abs(4*t-2),0),1);
                 c.b=Math.min(Math.max(1.5-Math.abs(4*t-1),0),1); return c },
  hot:    t => new THREE.Color(Math.min(t*3,1),Math.min(Math.max(t*3-1,0),1),Math.min(Math.max(t*3-2,0),1)),
  cool:   t => new THREE.Color(t,1-t,1),
  gray:   t => new THREE.Color(t,t,t),
  viridis:t => {
    const stops=[[0.267,0.005,0.329],[0.128,0.566,0.551],[0.369,0.788,0.383],[0.993,0.906,0.144]]
    const i=Math.min(3,Math.floor(t*3)), f=t*3-i
    const a=stops[i],b=stops[Math.min(3,i+1)]
    return new THREE.Color(a[0]+(b[0]-a[0])*f,a[1]+(b[1]-a[1])*f,a[2]+(b[2]-a[2])*f) },
  parula: t => {
    const stops=[[0.208,0.166,0.529],[0.086,0.532,0.801],[0.233,0.745,0.631],[0.992,0.906,0.145]]
    const i=Math.min(3,Math.floor(t*3)), f=t*3-i
    const a=stops[i],b=stops[Math.min(3,i+1)]
    return new THREE.Color(a[0]+(b[0]-a[0])*f,a[1]+(b[1]-a[1])*f,a[2]+(b[2]-a[2])*f) }
}
function getColor(t, cm='jet') { return (CMAPS[cm]||CMAPS.jet)(Math.max(0,Math.min(1,t))) }

function drawColorbar(cm, vmin, vmax) {
  document.getElementById('cbar').classList.remove('hidden')
  document.getElementById('cbar-min').textContent = vmin.toFixed(4)
  document.getElementById('cbar-max').textContent = vmax.toFixed(4)
  const c=document.getElementById('cbar-c'), ctx=c.getContext('2d'), h=c.height
  for(let y=0;y<h;y++){
    const col=getColor(1-y/h,cm)
    ctx.fillStyle=\`rgb(\${Math.round(col.r*255)},\${Math.round(col.g*255)},\${Math.round(col.b*255)})\`
    ctx.fillRect(0,y,20,1)
  }
}

function buildPatch(p) {
  const geo = new THREE.BufferGeometry()
  const vFlat = new Float32Array(p.vertices.flat())
  geo.setAttribute('position', new THREE.BufferAttribute(vFlat,3))
  const fIdx = p.faces.map(f=>f.slice(0,3).map(i=>i-1)).flat()
  geo.setIndex(fIdx)
  if(p.cdata && p.cdata.length>0) {
    const cd=p.cdata, vmin=Math.min(...cd), vmax=Math.max(...cd)
    const cm=p.colormap||'jet'
    const isByFace=(cd.length===p.faces.length)
    const cols=new Float32Array(p.vertices.length*3)
    if(isByFace) {
      const sums=new Float32Array(p.vertices.length)
      const cnt =new Float32Array(p.vertices.length)
      p.faces.forEach((f,fi)=>f.slice(0,3).forEach(vi=>{sums[vi-1]+=cd[fi];cnt[vi-1]++}))
      for(let i=0;i<p.vertices.length;i++){
        const v=cnt[i]>0?sums[i]/cnt[i]:vmin
        const c=getColor((vmax>vmin)?(v-vmin)/(vmax-vmin):0, cm)
        cols[i*3]=c.r; cols[i*3+1]=c.g; cols[i*3+2]=c.b
      }
    } else {
      for(let i=0;i<p.vertices.length;i++){
        const c=getColor((vmax>vmin)?(cd[i]-vmin)/(vmax-vmin):0, cm)
        cols[i*3]=c.r; cols[i*3+1]=c.g; cols[i*3+2]=c.b
      }
    }
    geo.setAttribute('color', new THREE.BufferAttribute(cols,3))
    if(p.colorbar) drawColorbar(cm,vmin,vmax)
  }
  geo.computeVertexNormals()
  return geo
}

function buildSurf(p) {
  const X=p.X, Y=p.Y, Z=p.Z
  const rows=X.length, cols=X[0].length
  const geo=new THREE.BufferGeometry()
  const verts=[], idxs=[], cm=p.colormap||'jet'
  let zmin=Infinity, zmax=-Infinity
  for(let i=0;i<rows;i++) for(let j=0;j<cols;j++){
    zmin=Math.min(zmin,Z[i][j]); zmax=Math.max(zmax,Z[i][j])
  }
  const cols3=[]
  for(let i=0;i<rows;i++) for(let j=0;j<cols;j++){
    verts.push(X[i][j],Y[i][j],Z[i][j])
    const c=getColor((zmax>zmin)?(Z[i][j]-zmin)/(zmax-zmin):0, cm)
    cols3.push(c.r,c.g,c.b)
  }
  for(let i=0;i<rows-1;i++) for(let j=0;j<cols-1;j++){
    const a=i*cols+j,b=a+1,c=(i+1)*cols+j,d=c+1
    idxs.push(a,c,b, b,c,d)
  }
  geo.setAttribute('position',new THREE.BufferAttribute(new Float32Array(verts),3))
  geo.setAttribute('color',new THREE.BufferAttribute(new Float32Array(cols3),3))
  geo.setIndex(idxs)
  geo.computeVertexNormals()
  return geo
}

function buildMat(payload, hasColors) {
  const fc=payload.facecolor
  if(fc==='interp'||fc==='flat'||!fc) {
    return new THREE.MeshPhongMaterial({
      vertexColors:hasColors, color:hasColors?0xffffff:0x4a90d9,
      shininess:60, side:THREE.DoubleSide})
  }
  if(Array.isArray(fc)) {
    return new THREE.MeshPhongMaterial({color:new THREE.Color(...fc),shininess:60,side:THREE.DoubleSide})
  }
  if(fc==='none') return new THREE.MeshBasicMaterial({visible:false})
  return new THREE.MeshPhongMaterial({color:0xccaa88,shininess:40,side:THREE.DoubleSide})
}

let meshObj=null; let wireObj=null
async function load() {
  const kind=payload.kind||(payload.wrl?'vrml':payload.vertices?'patch':'surf')
  if(kind==='vrml' && payload.wrl) {
    new VRMLLoader().load(payload.wrl, obj=>{
      scene.add(obj); meshObj=obj; fitCamera(obj)
    })
    return
  }
  let geo, mat
  if(kind==='surf' && payload.X) {
    geo=buildSurf(payload)
    mat=new THREE.MeshPhongMaterial({vertexColors:true,shininess:60,side:THREE.DoubleSide})
  } else if(payload.vertices) {
    geo=buildPatch(payload)
    mat=buildMat(payload, !!geo.attributes.color)
  } else return
  const mesh=new THREE.Mesh(geo,mat)
  mesh.castShadow=true; mesh.receiveShadow=true
  scene.add(mesh); meshObj=mesh
  if(payload.edgecolor && payload.edgecolor!=='none') {
    wireObj=new THREE.LineSegments(
      new THREE.WireframeGeometry(geo),
      new THREE.LineBasicMaterial({color:0x444,opacity:0.25,transparent:true}))
    scene.add(wireObj)
  }
  fitCamera(mesh)
}

function fitCamera(obj) {
  const box=new THREE.Box3().setFromObject(obj)
  const center=box.getCenter(new THREE.Vector3())
  const size=box.getSize(new THREE.Vector3()).length()
  controls.target.copy(center)
  perspCam.position.copy(center).addScalar(size*0.8)
  perspCam.near=size*0.001; perspCam.far=size*100
  perspCam.updateProjectionMatrix()
  orthoCam.position.copy(perspCam.position)
  axes.scale.setScalar(size*0.15)
  controls.update()
}

let wireMode=false
window.resetCam  = ()=>{ if(meshObj) fitCamera(meshObj) }
window.toggleWire= ()=>{
  wireMode=!wireMode
  if(meshObj) meshObj.traverse(o=>{if(o.isMesh) o.material.wireframe=wireMode})
}
window.toggleProj= ()=>{
  useOrtho=!useOrtho
  camera= useOrtho ? orthoCam : perspCam
  controls.object=camera
  document.getElementById('projBtn').textContent=useOrtho?'&#x2291; Persp':'&#x2291; Ortho'
}

window.addEventListener('message', e=>{
  const m=e.data; if(!m) return
  if(m.type==='camlight') camLight.position.copy(camera.position)
  if(m.type==='lighting' && meshObj) {
    const modes={phong:THREE.MeshPhongMaterial,flat:THREE.MeshLambertMaterial,
                 none:THREE.MeshBasicMaterial}
    const Cls=modes[m.mode]||THREE.MeshPhongMaterial
    meshObj.traverse(o=>{ if(!o.isMesh) return
      const old=o.material
      o.material=new Cls({vertexColors:old.vertexColors,color:old.color,side:THREE.DoubleSide,
                          ...(Cls===THREE.MeshPhongMaterial?{shininess:80}:{})})
    })
  }
  if(m.type==='colorbar') document.getElementById('cbar').classList.toggle('hidden',!m.visible)
})

window.addEventListener('resize',()=>{
  const w=canvas.parentElement.clientWidth, h=window.innerHeight
  renderer.setSize(w,h)
  perspCam.aspect=w/h; perspCam.updateProjectionMatrix()
  const a=w/h
  orthoCam.left=-orthoSize*a; orthoCam.right=orthoSize*a
  orthoCam.updateProjectionMatrix()
})

;(function animate(){
  requestAnimationFrame(animate)
  controls.update()
  camLight.position.copy(camera.position)
  renderer.render(scene, camera)
})()

load()
</script>
</body>
</html>`
    }
}
