# my3D — WebGL2 proof-of-concept app

`My3DDemo` is a hand-coded (non-ABC) Clarion 12 program that exercises **`WebGL2Class`** — the 3D scene
manager shipped by the `my3D` template — with **20 fixture scenes**. Each button builds a different scene
from the class API and opens it in your default browser as a live, hardware-accelerated **WebGL2** page
(drag to orbit, mouse-wheel to zoom, **R** to reset the camera).

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
