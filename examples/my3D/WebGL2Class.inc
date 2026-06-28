!ABCIncludeFile
! ============================================================================
!  WebGL2Class - a 3D scene manager for Clarion that drives a real WebGL2
!  renderer. You build a scene through a rich OOP API (camera, lights,
!  materials, 20+ mesh primitives, transforms, vector & matrix math); the
!  class emits a single self-contained .HTML file - the SCENE data plus the
!  verified my3D WebGL2 engine - and opens it in the default browser.
!
!  Pure Clarion: no DLLs, no COM, no external packages. The only companion
!  file is my3D.engine.js (shipped beside this .INC); SaveHtml() inlines it
!  into the generated page so the output HTML is fully self-contained.
!
!  QUICK START (or let the my3D template wire it for you):
!    INCLUDE('WebGL2Class.INC'),ONCE        ! once, globally
!    Scene  WebGL2Class
!    Scene.SetCanvas(1000, 640)
!    Scene.SetCamera(7, 6, 11);  Scene.LookAt(0, 0.5, 0)
!    Scene.SetDirLight(-1,-2,-1.3, 1,0.97,0.9, 1.1)
!    Scene.AddPointLight(4,3,4, 1,0.4,0.2, 1.2, 18)
!    Scene.ShowGrid(1, 20, 20, 0.13,0.16,0.22)
!    Scene.SetColor(0.20,0.55,0.95);  Scene.SetSpin(0,0.6,0)
!    Scene.AddCube(1.4)
!    Scene.Show()                            ! writes a temp .html and launches it
!
!  This file MUST be stored in ANSI (not UTF-8).
! ============================================================================

WebGL2:MaxMesh    EQUATE(256)                                ! scene mesh capacity
WebGL2:MaxLight   EQUATE(8)                                  ! point-light capacity (matches the shader)

! mesh type ids (also accepted as the strings used by the engine)
WebGL2:Box        EQUATE(1)
WebGL2:Sphere     EQUATE(2)
WebGL2:Cylinder   EQUATE(3)
WebGL2:Cone       EQUATE(4)
WebGL2:Plane      EQUATE(5)
WebGL2:Torus      EQUATE(6)
WebGL2:TorusKnot  EQUATE(7)
WebGL2:Tetra      EQUATE(8)
WebGL2:Octa       EQUATE(9)
WebGL2:Icosa      EQUATE(10)
WebGL2:Dodeca     EQUATE(11)

WebGL2Class CLASS,TYPE,MODULE('WebGL2Class.CLW'),LINK('WebGL2Class.CLW')
! ---- page / canvas ----
Title             CSTRING(128)
CanvasW           LONG
CanvasH           LONG
Antialias         BYTE
EngineFile        CSTRING(260)                               ! my3D.engine.js (found on the redirection path)
LastFile          CSTRING(260)                               ! the .html written by the last Save/Show
! ---- background ----
BgGradient        BYTE                                       ! 1 = vertical gradient, 0 = solid
BgR               REAL                                       ! solid / gradient bottom
BgG               REAL
BgB               REAL
BgTopR            REAL                                       ! gradient top
BgTopG            REAL
BgTopB            REAL
! ---- fog ----
FogOn             BYTE
FogR              REAL
FogG              REAL
FogB              REAL
FogNear           REAL
FogFar            REAL
! ---- camera ----
CamX              REAL
CamY              REAL
CamZ              REAL
TgtX              REAL
TgtY              REAL
TgtZ              REAL
Fov               REAL
ClipNear          REAL
ClipFar           REAL
Orbit             BYTE
OrbitSpeed        REAL
! ---- ambient + directional light ----
AmbR              REAL
AmbG              REAL
AmbB              REAL
DirX              REAL
DirY              REAL
DirZ              REAL
DirR              REAL
DirG              REAL
DirB              REAL
DirInt            REAL
! ---- grid / axes / global wireframe ----
GridOn            BYTE
GridSize          REAL
GridDiv           LONG
GridR             REAL
GridG             REAL
GridB             REAL
AxesOn            BYTE
AxesSize          REAL
Wireframe         BYTE
! ---- "current material" state, applied to the next Add* ----
CurR              REAL
CurG              REAL
CurB              REAL
CurMetal          REAL
CurRough          REAL
CurOpacity        REAL
CurEmiR           REAL
CurEmiG           REAL
CurEmiB           REAL
CurSpinX          REAL
CurSpinY          REAL
CurSpinZ          REAL
! ---- point lights ----
NLight            LONG
PLPosX            REAL,DIM(WebGL2:MaxLight)
PLPosY            REAL,DIM(WebGL2:MaxLight)
PLPosZ            REAL,DIM(WebGL2:MaxLight)
PLColR            REAL,DIM(WebGL2:MaxLight)
PLColG            REAL,DIM(WebGL2:MaxLight)
PLColB            REAL,DIM(WebGL2:MaxLight)
PLInt             REAL,DIM(WebGL2:MaxLight)
PLRange           REAL,DIM(WebGL2:MaxLight)
! ---- meshes ----
NMesh             LONG
MType             CSTRING(16),DIM(WebGL2:MaxMesh)
MP1               REAL,DIM(WebGL2:MaxMesh)                   ! geometry params 1..6
MP2               REAL,DIM(WebGL2:MaxMesh)
MP3               REAL,DIM(WebGL2:MaxMesh)
MP4               REAL,DIM(WebGL2:MaxMesh)
MP5               REAL,DIM(WebGL2:MaxMesh)
MP6               REAL,DIM(WebGL2:MaxMesh)
MPosX             REAL,DIM(WebGL2:MaxMesh)
MPosY             REAL,DIM(WebGL2:MaxMesh)
MPosZ             REAL,DIM(WebGL2:MaxMesh)
MRotX             REAL,DIM(WebGL2:MaxMesh)
MRotY             REAL,DIM(WebGL2:MaxMesh)
MRotZ             REAL,DIM(WebGL2:MaxMesh)
MSclX             REAL,DIM(WebGL2:MaxMesh)
MSclY             REAL,DIM(WebGL2:MaxMesh)
MSclZ             REAL,DIM(WebGL2:MaxMesh)
MColR             REAL,DIM(WebGL2:MaxMesh)
MColG             REAL,DIM(WebGL2:MaxMesh)
MColB             REAL,DIM(WebGL2:MaxMesh)
MMetal            REAL,DIM(WebGL2:MaxMesh)
MRough            REAL,DIM(WebGL2:MaxMesh)
MOpacity          REAL,DIM(WebGL2:MaxMesh)
MEmiR             REAL,DIM(WebGL2:MaxMesh)
MEmiG             REAL,DIM(WebGL2:MaxMesh)
MEmiB             REAL,DIM(WebGL2:MaxMesh)
MSpinX            REAL,DIM(WebGL2:MaxMesh)
MSpinY            REAL,DIM(WebGL2:MaxMesh)
MSpinZ            REAL,DIM(WebGL2:MaxMesh)
MWire             BYTE,DIM(WebGL2:MaxMesh)
! ---- scratch results for the vector/matrix math methods ----
Rx                REAL                                       ! Vec3 result (Cross/Normalize/Add/...)
Ry                REAL
Rz                REAL
Mat               REAL,DIM(16)                               ! Mat4 result (column-major)
! ---- lifecycle -------------------------------------------------------------
Construct         PROCEDURE
Reset             PROCEDURE                                  ! back to defaults, empty scene
ClearScene        PROCEDURE                                  ! drop all meshes + point lights, keep settings
! ---- page / canvas / background --------------------------------------------
SetTitle          PROCEDURE(STRING pTitle)
SetCanvas         PROCEDURE(LONG pW,LONG pH)
SetAntialias      PROCEDURE(BYTE pOn)
SetBackground     PROCEDURE(REAL pR,REAL pG,REAL pB)
SetBackgroundGradient PROCEDURE(REAL pTopR,REAL pTopG,REAL pTopB,REAL pBotR,REAL pBotG,REAL pBotB)
SetFog            PROCEDURE(BYTE pOn,REAL pR,REAL pG,REAL pB,REAL pNear,REAL pFar)
SetSolidBackgroundCl    PROCEDURE(LONG pClarionColor)        ! Clarion-COLOR convenience wrappers
SetBackgroundGradientCl PROCEDURE(LONG pTopColor,LONG pBotColor)
SetFogCl          PROCEDURE(BYTE pOn,LONG pClarionColor,REAL pNear,REAL pFar)
! ---- camera ----------------------------------------------------------------
SetCamera         PROCEDURE(REAL pX,REAL pY,REAL pZ)
LookAt            PROCEDURE(REAL pX,REAL pY,REAL pZ)
SetFOV            PROCEDURE(REAL pDeg)
SetClip           PROCEDURE(REAL pNear,REAL pFar)
OrbitCamera       PROCEDURE(BYTE pOn,REAL pSpeed)
! ---- lighting --------------------------------------------------------------
SetAmbient        PROCEDURE(REAL pR,REAL pG,REAL pB)
SetDirLight       PROCEDURE(REAL pDX,REAL pDY,REAL pDZ,REAL pR,REAL pG,REAL pB,REAL pIntensity)
AddPointLight     PROCEDURE(REAL pX,REAL pY,REAL pZ,REAL pR,REAL pG,REAL pB,REAL pIntensity,REAL pRange),LONG,PROC
SetAmbientCl      PROCEDURE(LONG pClarionColor)
SetDirLightCl     PROCEDURE(REAL pDX,REAL pDY,REAL pDZ,LONG pClarionColor,REAL pIntensity)
AddPointLightCl   PROCEDURE(REAL pX,REAL pY,REAL pZ,LONG pClarionColor,REAL pIntensity,REAL pRange),LONG,PROC
ClearLights       PROCEDURE
! ---- helpers / scene chrome ------------------------------------------------
ShowGrid          PROCEDURE(BYTE pOn,REAL pSize,LONG pDiv,REAL pR,REAL pG,REAL pB)
ShowGridCl        PROCEDURE(BYTE pOn,REAL pSize,LONG pDiv,LONG pClarionColor)
ShowAxes          PROCEDURE(BYTE pOn,REAL pSize)
SetWireframe      PROCEDURE(BYTE pOn)
! ---- "current material" state (applies to the NEXT Add*) -------------------
SetColor          PROCEDURE(REAL pR,REAL pG,REAL pB)
SetColorCl        PROCEDURE(LONG pClarionColor)              ! 0xBBGGRR Clarion color -> 0..1 rgb
SetEmissiveCl     PROCEDURE(LONG pClarionColor)
SetMaterial       PROCEDURE(REAL pMetalness,REAL pRoughness)
SetOpacity        PROCEDURE(REAL pOpacity)
SetEmissive       PROCEDURE(REAL pR,REAL pG,REAL pB)
SetSpin           PROCEDURE(REAL pSX,REAL pSY,REAL pSZ)      ! radians/sec applied to the next Add*
ResetMaterial     PROCEDURE                                  ! current material/spin back to neutral
! ---- mesh adders (each returns the new mesh index, 1-based) ----------------
AddMesh           PROCEDURE(STRING pType,REAL pP1,REAL pP2,REAL pP3,REAL pP4,REAL pP5,REAL pP6),LONG,PROC
AddBox            PROCEDURE(REAL pW,REAL pH,REAL pD),LONG,PROC
AddCube           PROCEDURE(REAL pSize),LONG,PROC
AddSphere         PROCEDURE(REAL pRadius,LONG pSegments),LONG,PROC
AddCylinder       PROCEDURE(REAL pRTop,REAL pRBot,REAL pHeight,LONG pSeg),LONG,PROC
AddCone           PROCEDURE(REAL pRadius,REAL pHeight,LONG pSeg),LONG,PROC
AddPlane          PROCEDURE(REAL pW,REAL pD),LONG,PROC
AddTorus          PROCEDURE(REAL pR,REAL pTube,LONG pRadSeg,LONG pTubeSeg),LONG,PROC
AddTorusKnot      PROCEDURE(REAL pR,REAL pTube,LONG pP,LONG pQ),LONG,PROC
AddTetra          PROCEDURE(REAL pR),LONG,PROC
AddOcta           PROCEDURE(REAL pR),LONG,PROC
AddIcosa          PROCEDURE(REAL pR),LONG,PROC
AddDodeca         PROCEDURE(REAL pR),LONG,PROC
! ---- composite models: many primitives assembled at an origin + uniform -----
!      scale. Each returns the 1-based index of the model's FIRST mesh. The
!      pX,pY,pZ origin is the ground point the model sits on.
AddCar            PROCEDURE(REAL pX,REAL pY,REAL pZ,REAL pScale),LONG,PROC
AddAirplane       PROCEDURE(REAL pX,REAL pY,REAL pZ,REAL pScale),LONG,PROC
AddRocket         PROCEDURE(REAL pX,REAL pY,REAL pZ,REAL pScale),LONG,PROC
AddWindTurbine    PROCEDURE(REAL pX,REAL pY,REAL pZ,REAL pScale),LONG,PROC
AddRobot          PROCEDURE(REAL pX,REAL pY,REAL pZ,REAL pScale),LONG,PROC
AddTableSet       PROCEDURE(REAL pX,REAL pY,REAL pZ,REAL pScale),LONG,PROC
AddHouse          PROCEDURE(REAL pX,REAL pY,REAL pZ,REAL pScale),LONG,PROC
AddFoundation     PROCEDURE(REAL pX,REAL pY,REAL pZ,REAL pScale),LONG,PROC
AddSkyscraper     PROCEDURE(REAL pX,REAL pY,REAL pZ,REAL pScale),LONG,PROC
AddTrees          PROCEDURE(REAL pX,REAL pY,REAL pZ,REAL pScale),LONG,PROC
! ---- per-mesh transforms (1-based index; no-op if out of range) ------------
SetPos            PROCEDURE(LONG pIdx,REAL pX,REAL pY,REAL pZ)
SetRot            PROCEDURE(LONG pIdx,REAL pX,REAL pY,REAL pZ)
SetScale          PROCEDURE(LONG pIdx,REAL pSX,REAL pSY,REAL pSZ)
SetUniformScale   PROCEDURE(LONG pIdx,REAL pS)
SetMeshColor      PROCEDURE(LONG pIdx,REAL pR,REAL pG,REAL pB)
SpinMesh          PROCEDURE(LONG pIdx,REAL pSX,REAL pSY,REAL pSZ)
MeshCount         PROCEDURE(),LONG
! ---- Vec3 math (computes in Clarion; Cross/Normalize/... post to Rx,Ry,Rz) -
Vec3Length        PROCEDURE(REAL pX,REAL pY,REAL pZ),REAL
Vec3Distance      PROCEDURE(REAL pX1,REAL pY1,REAL pZ1,REAL pX2,REAL pY2,REAL pZ2),REAL
Vec3Dot           PROCEDURE(REAL pAX,REAL pAY,REAL pAZ,REAL pBX,REAL pBY,REAL pBZ),REAL
Vec3Add           PROCEDURE(REAL pAX,REAL pAY,REAL pAZ,REAL pBX,REAL pBY,REAL pBZ)
Vec3Sub           PROCEDURE(REAL pAX,REAL pAY,REAL pAZ,REAL pBX,REAL pBY,REAL pBZ)
Vec3Scale         PROCEDURE(REAL pX,REAL pY,REAL pZ,REAL pS)
Vec3Cross         PROCEDURE(REAL pAX,REAL pAY,REAL pAZ,REAL pBX,REAL pBY,REAL pBZ)
Vec3Normalize     PROCEDURE(REAL pX,REAL pY,REAL pZ)
Vec3Lerp          PROCEDURE(REAL pAX,REAL pAY,REAL pAZ,REAL pBX,REAL pBY,REAL pBZ,REAL pT)
! ---- Mat4 math (4x4, column-major; results land in SELF.Mat[1..16]) --------
Mat4Identity      PROCEDURE
Mat4Translate     PROCEDURE(REAL pX,REAL pY,REAL pZ)
Mat4Scale         PROCEDURE(REAL pX,REAL pY,REAL pZ)
Mat4RotateX       PROCEDURE(REAL pRad)
Mat4RotateY       PROCEDURE(REAL pRad)
Mat4RotateZ       PROCEDURE(REAL pRad)
Mat4Perspective   PROCEDURE(REAL pFovDeg,REAL pAspect,REAL pNear,REAL pFar)
Mat4Multiply      PROCEDURE(REAL pA1,REAL pA2,REAL pA3,REAL pA4,REAL pA5,REAL pA6,REAL pA7,REAL pA8,REAL pA9,REAL pA10,REAL pA11,REAL pA12,REAL pA13,REAL pA14,REAL pA15,REAL pA16) ! multiplies SELF.Mat (left) by the 16 values (right) -> SELF.Mat
Deg2Rad           PROCEDURE(REAL pDeg),REAL
Rad2Deg           PROCEDURE(REAL pRad),REAL
! ---- output ----------------------------------------------------------------
SaveHtml          PROCEDURE(STRING pFilename),BYTE,PROC      ! write the scene + engine to an .html file; 1 = ok
Show              PROCEDURE(),BYTE,PROC                      ! save to a temp .html and launch the default browser
ShowFile          PROCEDURE(STRING pFilename),BYTE,PROC      ! save to pFilename and launch it
! ---- internal --------------------------------------------------------------
PlaceModel        PROCEDURE(LONG pStart,REAL pOX,REAL pOY,REAL pOZ,REAL pScale) ! offset+scale meshes pStart..end
ClToRGB           PROCEDURE(LONG pClarionColor,*REAL pR,*REAL pG,*REAL pB) ! 0xBBGGRR -> 0..1 rgb
NumStr            PROCEDURE(REAL pV),STRING                  ! compact JS number text
ColStr            PROCEDURE(REAL pR,REAL pG,REAL pB),STRING  ! "[r,g,b]"
JsEsc             PROCEDURE(STRING pText),STRING             ! escape ' \ for a JS single-quoted string
FindEngine        PROCEDURE(),STRING                         ! locate my3D.engine.js on the redirection path
TempHtmlPath      PROCEDURE(),STRING                         ! a writable scratch .html path
WriteLine         PROCEDURE(STRING pLine)                    ! internal: append one line to the open output file
EmitScene         PROCEDURE                                  ! internal: write the window.SCENE = {...} block
                  END
