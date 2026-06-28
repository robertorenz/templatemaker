# my3D — WebGL2 examples

Two hand-coded (non-ABC) Clarion 12 programs that exercise **`WebGL2Class`** — the 3D scene manager
shipped by the `my3D` template. Each button builds a scene from the class API and opens it in your default
browser as a live, hardware-accelerated **WebGL2** page (drag to orbit, mouse-wheel to zoom, **R** to reset
the camera).

* **`My3DModels`** — a gallery of **10 real-world objects modelled from primitives** (see below).
* **`My3DDemo`** — **20 fixture scenes** that stress every feature of the class.

## `My3DModels` — model gallery

Ten recognisable objects, each assembled **only** from boxes, spheres, cylinders and cones — so the source
doubles as a cookbook for composing primitives. Build it with `My3DModels.cwproj`.

| Model | Built from |
|-------|------------|
| **Car** | body + skirt + cabin boxes, tinted-glass box, 4 cylinder tyres (rolled 90°) + hubcaps, glowing headlight spheres |
| **Airplane** | cylinder fuselage + cone nose (both turned onto +X), box wings/tail/fin, a squashed-sphere canopy, two engine pods |
| **Rocket** | cylinder body, cone nose, glowing window, 4 box fins around the base, a downward-pointing emissive flame cone |
| **Wind turbine** | tapered cylinder tower, box nacelle, sphere hub, 3 box blades at 120° |
| **Robot** | box torso/head, cylinder arms & legs, box feet, sphere hands, glowing eyes + chest light, antenna |
| **Table & chairs** | box tabletop on 4 cylinder legs, ringed by 4 chairs (seat + back + pedestal), backs turned to face the table |
| **House** | box walls, a **4-sided cone roof turned 45°** (a square pyramid), door, glowing windows, chimney |
| **Building foundation** | concrete slab, perimeter stem walls, a 3×3 grid of footing pads with rebar columns |
| **Skyscraper** | a tapered stack of glass-blue floor boxes topped with a cylinder antenna |
| **Park** | alternating pine trees (stacked cones) and round trees (clustered spheres) on cylinder trunks |

Each model is one `ROUTINE` — open [`My3DModels.clw`](My3DModels.clw) to see exactly how it is composed.
The orientation tricks worth stealing: a wheel is a cylinder rotated `1.5708` about X; a fuselage is a
cylinder rotated about Z; a square pyramid is `AddCone(r, h, 4)` turned `0.7854` about Y; a downward flame is
a cone rotated `3.14159` about X.

These same models are also built into the class as one-call **special meshes** —
`Scene.AddCar(x, y, z, scale)`, `Scene.AddHouse(...)`, etc. — which is what the `my3D` template emits when
you pick a **(model)** entry from its Shape dropdown. The **Town** button builds a whole town that way (one
call per object); see `Mdl_Town` in [`My3DModels.clw`](My3DModels.clw).

## `My3DDemo` — feature fixtures

`My3DDemo` exercises every feature of the class with **20 fixture scenes**.

## Fixtures

| # | Scene | What it shows |
|---|-------|---------------|
| 1 | Spinning cube | the minimal case |
| 2 | Primitive gallery | cube / sphere / cylinder / cone / torus / icosa / dodeca + fog + 2 point lights |
| 3 | Platonic solids | tetra, octa, cube, icosa, dodeca |
| 4 | Torus knot | a (2,3) knot under two coloured point lights |
| 5 | Sphere grid | a 7×7 lattice, colour ramped per cell |
| 6 | All-primitive grid | every primitive lined up |
| 7 | Color wheel | a ring of cubes around a central sphere |
| 8 | Tower of boxes | stacked, shrinking, twisted |
| 9 | Helix of spheres | positions from `sin`/`cos` |
| 10 | Random field | 120 cubes (`RANDOM`), fogged |
| 11 | Material showcase | a 6×6 metalness × roughness matrix |
| 12 | Point-light trio | three coloured lights over white spheres |
| 13 | Fog field | cones receding into fog |
| 14 | Glass | translucent overlapping spheres (opacity / blending) |
| 15 | Wireframe world | icosa + knot + sphere as wireframes |
| 16 | Solar system | a glowing sun; planet orbits placed with the class's **`Vec3`** maths |
| 17 | Emissive neon | a ring of glowing tori |
| 18 | Sunset gradient | gradient background + warm key light |
| — | Scene from Vec3 maths | a Fibonacci sphere built with `Vec3Normalize` |
| — | Mega scene | everything at once |
| — | **Vec3 / Mat4 self-test** | proves the maths methods compute correctly in pure Clarion |

## Build & run

From a Clarion 12 command prompt (or the IDE — open `My3DDemo.cwproj`):

```
msbuild My3DDemo.cwproj -t:Build -p:Configuration=Debug -p:Platform=Win32 ^
        -p:ClarionBinPath="C:\clarion12\bin"
```

This folder is a **self-contained copy** of the class for a runnable sample —
`WebGL2Class.inc`, `WebGL2Class.clw` and `my3D.engine.js` are mirrored from
[`../../templates/my3D/`](../../templates/my3D/) (edit them there, not here). Keep
`my3D.engine.js` next to `My3DDemo.exe`: it is read at run time and inlined into every page the app writes,
so each generated `.html` is fully self-contained and shareable.
