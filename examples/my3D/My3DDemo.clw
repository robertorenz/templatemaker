! ============================================================================
!  My3DDemo  -  proof-of-concept driver for WebGL2Class (the my3D template's
!  3D scene manager).  A plain hand-coded Clarion program (no ABC) with a wall
!  of fixture buttons - each builds a different 3D scene through the class API
!  and opens it in the default browser as a live WebGL2 page.
!
!  BUILD (from a Clarion 12 command prompt or the IDE):
!    needs  WebGL2Class.inc, WebGL2Class.clw, my3D.engine.js  in this folder.
!    The engine .js is read at run time and inlined into each generated page,
!    so keep my3D.engine.js beside My3DDemo.exe.
! ============================================================================
  PROGRAM

  INCLUDE('WebGL2Class.INC'),ONCE

  MAP
  END

Scene   WebGL2Class

LastMeshCount  LONG
! --- shared scratch variables for the fixture routines (single-threaded demo) ---
M     LONG                                                   ! index of the last-added mesh
I     LONG
IX    LONG
IZ    LONG
COL   LONG
N     LONG
FAILS LONG
ANG   REAL
T     REAL
DIST  REAL
SZ    REAL
PX    REAL
PY    REAL
PZ    REAL
R6    REAL
G6    REAL
B6    REAL
D     REAL
MSG   CSTRING(1300)

Window WINDOW('my3D / WebGL2 - Proof of Concept'),AT(,,420,322),CENTER,SYSTEM,GRAY,FONT('Segoe UI',9),|
         RESIZE
       PROMPT('my3D &mdash; drive a real WebGL2 scene from Clarion'),AT(12,8),USE(?Hdr),FONT('Segoe UI',11,,FONT:bold)
       PROMPT('Each button builds a scene with the class API and opens it in your browser.'),AT(12,22),USE(?Sub)
       GROUP('Primitives & basics'),AT(8,36,200,118),BOXED,USE(?G1)
         BUTTON('1. Spinning cube'),AT(16,50,90,16),USE(?bCube)
         BUTTON('2. Primitive gallery'),AT(112,50,90,16),USE(?bGallery)
         BUTTON('3. Platonic solids'),AT(16,70,90,16),USE(?bPlatonic)
         BUTTON('4. Torus knot'),AT(112,70,90,16),USE(?bKnot)
         BUTTON('5. Sphere grid'),AT(16,90,90,16),USE(?bSphereGrid)
         BUTTON('6. All-primitive grid'),AT(112,90,90,16),USE(?bAllGrid)
         BUTTON('7. Color wheel'),AT(16,110,90,16),USE(?bColorWheel)
         BUTTON('8. Tower of boxes'),AT(112,110,90,16),USE(?bTower)
         BUTTON('9. Helix of spheres'),AT(16,130,90,16),USE(?bHelix)
         BUTTON('10. Random field (120)'),AT(112,130,90,16),USE(?bRandom)
       END
       GROUP('Lighting, material & atmosphere'),AT(8,158,200,98),BOXED,USE(?G2)
         BUTTON('11. Material showcase'),AT(16,172,90,16),USE(?bMaterial)
         BUTTON('12. Point-light trio'),AT(112,172,90,16),USE(?bLights)
         BUTTON('13. Fog field'),AT(16,192,90,16),USE(?bFog)
         BUTTON('14. Glass (opacity)'),AT(112,192,90,16),USE(?bGlass)
         BUTTON('15. Wireframe world'),AT(16,212,90,16),USE(?bWire)
         BUTTON('16. Solar system'),AT(112,212,90,16),USE(?bSolar)
         BUTTON('17. Emissive neon'),AT(16,232,90,16),USE(?bNeon)
         BUTTON('18. Sunset gradient'),AT(112,232,90,16),USE(?bSunset)
       END
       GROUP('Math proof (runs in Clarion)'),AT(214,36,198,118),BOXED,USE(?G3)
         PROMPT('These prove the Vec3 / Mat4 methods compute correctly in pure ' & |
            'Clarion - the same math the engine does on the GPU.'),AT(222,50,182,30),USE(?MathInfo)
         BUTTON('Run Vec3 / Mat4 self-test'),AT(222,86,182,18),USE(?bSelfTest)
         BUTTON('Build a scene FROM Vec3 math'),AT(222,108,182,18),USE(?bVecScene)
         BUTTON('Mega scene (everything)'),AT(222,130,182,18),USE(?bMega)
       END
       GROUP('Last output'),AT(214,158,198,98),BOXED,USE(?G4)
         PROMPT('File:'),AT(222,172),USE(?lblFile)
         STRING(@s64),AT(222,184,182,10),USE(Scene.LastFile),FONT('Consolas',8)
         PROMPT('Meshes in last scene:'),AT(222,200),USE(?lblN)
         STRING(@n-7),AT(316,200),USE(LastMeshCount)
         BUTTON('Re-open last page'),AT(222,216,90,16),USE(?bReopen)
         BUTTON('About / Close'),AT(316,216,88,16),USE(?bAbout)
       END
       STRING('Tip: in the 3D page, drag to orbit, mouse-wheel to zoom, press R to reset the camera.'),|
            AT(12,266),USE(?Tip),FONT('Segoe UI',8),TRN
       BUTTON('Close'),AT(360,300,52,16),USE(?bClose),STD(STD:Close)
     END

  CODE
  OPEN(Window)
  ?Hdr{PROP:Text} = 'my3D - drive a real WebGL2 scene from Clarion'
  ACCEPT
    CASE ACCEPTED()
    OF ?bCube;        DO Fx_Cube
    OF ?bGallery;     DO Fx_Gallery
    OF ?bPlatonic;    DO Fx_Platonic
    OF ?bKnot;        DO Fx_Knot
    OF ?bSphereGrid;  DO Fx_SphereGrid
    OF ?bAllGrid;     DO Fx_AllGrid
    OF ?bColorWheel;  DO Fx_ColorWheel
    OF ?bTower;       DO Fx_Tower
    OF ?bHelix;       DO Fx_Helix
    OF ?bRandom;      DO Fx_Random
    OF ?bMaterial;    DO Fx_Material
    OF ?bLights;      DO Fx_Lights
    OF ?bFog;         DO Fx_Fog
    OF ?bGlass;       DO Fx_Glass
    OF ?bWire;        DO Fx_Wire
    OF ?bSolar;       DO Fx_Solar
    OF ?bNeon;        DO Fx_Neon
    OF ?bSunset;      DO Fx_Sunset
    OF ?bVecScene;    DO Fx_VecScene
    OF ?bMega;        DO Fx_Mega
    OF ?bSelfTest;    DO SelfTest
    OF ?bReopen
      IF Scene.LastFile
        RUN('rundll32.exe url.dll,FileProtocolHandler ' & CLIP(Scene.LastFile))
      ELSE
        MESSAGE('Build a scene first.','my3D',ICON:Asterisk)
      END
    OF ?bAbout
      MESSAGE('my3D / WebGL2Class proof of concept|' & |
        'A pure-Clarion 3D scene manager that emits a self-contained WebGL2 page.||' & |
        '20+ mesh primitives, lights, materials, fog, transforms, and Vec3/Mat4 math.', |
        'About my3D', ICON:Asterisk)
    OF ?bClose
      BREAK
    END
  END
  CLOSE(Window)
  RETURN

!============================================================================
!  Fixtures.  Each rebuilds the scene from scratch, then Show()s it.
!============================================================================
Fx_Cube ROUTINE
  Scene.Reset()
  Scene.SetTitle('1 - Spinning cube')
  Scene.SetColor(0.20, 0.55, 0.95)
  Scene.SetMaterial(0.25, 0.35)
  Scene.SetSpin(0.0, 0.7, 0.0)
  Scene.AddCube(1.6)
  Scene.SetPos(1, 0, 0.8, 0)
  DO ShowIt

Fx_Gallery ROUTINE
  Scene.Reset()
  Scene.SetTitle('2 - Primitive gallery')
  Scene.SetFog(1, 0.02, 0.03, 0.06, 16, 38)
  Scene.AddPointLight(4, 3.5, 4,  1.0, 0.45, 0.25, 1.2, 18)
  Scene.AddPointLight(-4, 3, -3,  0.25, 0.55, 1.0, 1.1, 18)
  Scene.SetColor(0.20, 0.55, 0.95); Scene.SetMaterial(0.2,0.4); Scene.SetSpin(0,0.6,0)
  M = Scene.AddCube(1.4);          Scene.SetPos(M, -4.5, 0.7, 0)
  Scene.SetColor(0.95, 0.35, 0.45); Scene.SetMaterial(0.6,0.25); Scene.SetSpin(0,0,0)
  M = Scene.AddSphere(0.85, 28);   Scene.SetPos(M, -1.5, 0.85, 0)
  Scene.SetColor(0.40, 0.85, 0.55); Scene.SetMaterial(0.1,0.5); Scene.SetSpin(0,0,0.8)
  M = Scene.AddCylinder(0.55,0.55,1.5,40); Scene.SetPos(M, 1.5, 0.75, 0)
  Scene.SetColor(0.98, 0.75, 0.20); Scene.SetMaterial(0.3,0.35); Scene.SetSpin(0,0,0)
  M = Scene.AddCone(0.7, 1.5, 40); Scene.SetPos(M, 4.5, 0.75, 0)
  Scene.SetColor(0.20, 0.85, 0.85); Scene.SetMaterial(0.5,0.3); Scene.SetSpin(0.9,0,0)
  M = Scene.AddTorus(0.7, 0.26, 28, 18); Scene.SetPos(M, -3, 0.7, -3.5)
  Scene.SetColor(0.55, 0.70, 0.95); Scene.SetMaterial(0.4,0.4); Scene.SetSpin(0,0.6,0.2)
  M = Scene.AddIcosa(0.9);         Scene.SetPos(M, 0, 0.9, -3.5)
  Scene.SetColor(0.95, 0.55, 0.25); Scene.SetMaterial(0.4,0.4); Scene.SetSpin(0,0.5,0)
  M = Scene.AddDodeca(0.9);        Scene.SetPos(M, 3, 0.9, -3.5)
  Scene.ResetMaterial()
  Scene.SetColor(0.10, 0.12, 0.16); Scene.SetMaterial(0, 0.9)
  M = Scene.AddPlane(26, 26)
  DO ShowIt

Fx_Platonic ROUTINE
  Scene.Reset()
  Scene.SetTitle('3 - Platonic solids')
  Scene.SetSpin(0.2, 0.5, 0)
  Scene.SetColor(0.30, 0.65, 0.95); M = Scene.AddTetra(0.8);  Scene.SetPos(M, -4.4, 0.9, 0)
  Scene.SetColor(0.35, 0.80, 0.70); M = Scene.AddOcta(0.8);   Scene.SetPos(M, -2.2, 0.9, 0)
  Scene.SetColor(0.95, 0.70, 0.25); M = Scene.AddCube(1.2);   Scene.SetPos(M,  0.0, 0.9, 0)
  Scene.SetColor(0.95, 0.45, 0.40); M = Scene.AddIcosa(0.85); Scene.SetPos(M,  2.2, 0.9, 0)
  Scene.SetColor(0.55, 0.65, 0.95); M = Scene.AddDodeca(0.85);Scene.SetPos(M,  4.4, 0.9, 0)
  DO ShowIt

Fx_Knot ROUTINE
  Scene.Reset()
  Scene.SetTitle('4 - Torus knot')
  Scene.SetCamera(0, 2, 6); Scene.LookAt(0, 0, 0)
  Scene.AddPointLight(3, 4, 3, 1.0, 0.9, 0.6, 1.3, 16)
  Scene.AddPointLight(-3, -2, 2, 0.3, 0.6, 1.0, 1.0, 16)
  Scene.SetColor(0.20, 0.85, 0.85); Scene.SetMaterial(0.8, 0.18); Scene.SetSpin(0, 0.6, 0)
  M = Scene.AddTorusKnot(1.0, 0.30, 2, 3); Scene.SetPos(M, 0, 0, 0)
  Scene.ShowGrid(0, 0, 0, 0, 0, 0)
  DO ShowIt

Fx_SphereGrid ROUTINE
  Scene.Reset()
  Scene.SetTitle('5 - Sphere grid (7x7)')
  Scene.SetCamera(9, 9, 9)
  Scene.SetMaterial(0.6, 0.25)
  LOOP ix = 0 TO 6
    LOOP iz = 0 TO 6
      Scene.SetColor(ix/6.0, 0.5, iz/6.0 * 0.6 + 0.3)
      M = Scene.AddSphere(0.42, 18)
      Scene.SetPos(M, (ix-3)*1.3, 0.5, (iz-3)*1.3)
    END
  END
  DO ShowIt

Fx_AllGrid ROUTINE
  Scene.Reset()
  Scene.SetTitle('6 - All primitives, lined up')
  Scene.SetCamera(0, 8, 13)
  Scene.SetMaterial(0.35, 0.4)
  col = 0
  Scene.SetColor(0.30,0.60,0.95); col+=1; M=Scene.AddCube(1.0);                 Scene.SetPos(M,(col-6)*2,0.7,0)
  Scene.SetColor(0.95,0.40,0.45); col+=1; M=Scene.AddSphere(0.65,24);           Scene.SetPos(M,(col-6)*2,0.7,0)
  Scene.SetColor(0.35,0.80,0.55); col+=1; M=Scene.AddCylinder(0.5,0.5,1.3,32);  Scene.SetPos(M,(col-6)*2,0.7,0)
  Scene.SetColor(0.98,0.72,0.25); col+=1; M=Scene.AddCone(0.6,1.3,32);          Scene.SetPos(M,(col-6)*2,0.7,0)
  Scene.SetColor(0.20,0.82,0.82); col+=1; M=Scene.AddTorus(0.6,0.24,24,16);     Scene.SetPos(M,(col-6)*2,0.7,0)
  Scene.SetColor(0.55,0.70,0.95); col+=1; M=Scene.AddTorusKnot(0.55,0.18,2,3);  Scene.SetPos(M,(col-6)*2,0.7,0)
  Scene.SetColor(0.90,0.55,0.30); col+=1; M=Scene.AddTetra(0.75);               Scene.SetPos(M,(col-6)*2,0.7,0)
  Scene.SetColor(0.45,0.75,0.90); col+=1; M=Scene.AddOcta(0.75);                Scene.SetPos(M,(col-6)*2,0.7,0)
  Scene.SetColor(0.95,0.45,0.55); col+=1; M=Scene.AddIcosa(0.78);               Scene.SetPos(M,(col-6)*2,0.7,0)
  Scene.SetColor(0.60,0.80,0.45); col+=1; M=Scene.AddDodeca(0.78);              Scene.SetPos(M,(col-6)*2,0.7,0)
  Scene.SetColor(0.70,0.74,0.80); col+=1; M=Scene.AddPlane(1.6,1.6);            Scene.SetPos(M,(col-6)*2,0.7,0); Scene.SetRot(M,-1.2,0,0)
  Scene.SetSpin(0, 0.4, 0)
  DO ShowIt

Fx_ColorWheel ROUTINE
  Scene.Reset()
  Scene.SetTitle('7 - Color wheel')
  Scene.SetCamera(0, 9, 10)
  Scene.SetMaterial(0.3, 0.45)
  LOOP i = 0 TO 17
    ang = i / 18.0 * 6.2831853
    ! simple hue ramp across r/g/b (no purple-heavy region)
    r6 = 0.5 + 0.45 * COS(ang)
    g6 = 0.5 + 0.45 * COS(ang - 2.094)
    b6 = 0.45 + 0.35 * COS(ang + 2.094)
    Scene.SetColor(r6, g6, b6)
    M = Scene.AddCube(0.8)
    Scene.SetPos(M, 4.2*COS(ang), 0.6, 4.2*SIN(ang))
    Scene.SetRot(M, 0, ang, 0)
  END
  Scene.SetColor(0.85, 0.86, 0.9); Scene.SetMaterial(0.7, 0.2)
  M = Scene.AddSphere(1.1, 32); Scene.SetPos(M, 0, 0.8, 0)
  DO ShowIt

Fx_Tower ROUTINE
  Scene.Reset()
  Scene.SetTitle('8 - Tower of boxes')
  Scene.SetCamera(7, 7, 7); Scene.LookAt(0, 2.5, 0)
  Scene.SetMaterial(0.3, 0.4)
  LOOP i = 0 TO 11
    Scene.SetColor(0.30 + i/22.0, 0.55, 0.95 - i/22.0)
    M = Scene.AddCube(1.4 - i*0.07)
    Scene.SetPos(M, 0, 0.4 + i*0.62, 0)
    Scene.SetRot(M, 0, i*0.26, 0)
  END
  DO ShowIt

Fx_Helix ROUTINE
  Scene.Reset()
  Scene.SetTitle('9 - Helix of spheres')
  Scene.SetCamera(8, 6, 8); Scene.LookAt(0, 2, 0)
  Scene.SetMaterial(0.55, 0.28)
  LOOP i = 0 TO 47
    t = i / 4.0
    Scene.SetColor(0.4 + 0.4*COS(t), 0.6, 0.9 - 0.3*COS(t))
    M = Scene.AddSphere(0.3, 16)
    Scene.SetPos(M, 2.4*COS(t), i*0.13, 2.4*SIN(t))
  END
  DO ShowIt

Fx_Random ROUTINE
  Scene.Reset()
  Scene.SetTitle('10 - Random field (120 cubes)')
  Scene.SetCamera(0, 14, 18)
  Scene.SetFog(1, 0.02, 0.03, 0.06, 18, 46)
  Scene.SetMaterial(0.3, 0.45)
  LOOP i = 1 TO 120
    Scene.SetColor(RANDOM(20,90)/100.0, RANDOM(40,90)/100.0, RANDOM(40,95)/100.0)
    Scene.SetSpin(0, RANDOM(-60,60)/100.0, 0)
    M = Scene.AddCube(RANDOM(40,120)/100.0)
    Scene.SetPos(M, RANDOM(-90,90)/10.0, RANDOM(3,40)/10.0, RANDOM(-90,90)/10.0)
    Scene.SetRot(M, RANDOM(0,628)/100.0, RANDOM(0,628)/100.0, 0)
  END
  DO ShowIt

Fx_Material ROUTINE
  Scene.Reset()
  Scene.SetTitle('11 - Material showcase (metalness x roughness)')
  Scene.SetCamera(0, 7, 11)
  Scene.AddPointLight(5, 6, 4, 1, 0.95, 0.85, 1.2, 22)
  Scene.SetColor(0.85, 0.78, 0.45)
  LOOP ix = 0 TO 5                                            ! metalness 0..1
    LOOP iz = 0 TO 5                                          ! roughness 0..1
      Scene.SetMaterial(ix/5.0, iz/5.0)
      M = Scene.AddSphere(0.5, 28)
      Scene.SetPos(M, (ix-2.5)*1.4, (iz-2.5)*1.4 + 3.5, 0)
    END
  END
  Scene.ShowGrid(0,0,0,0,0,0)
  DO ShowIt

Fx_Lights ROUTINE
  Scene.Reset()
  Scene.SetTitle('12 - Point-light trio')
  Scene.SetAmbient(0.05, 0.06, 0.08)
  Scene.SetDirLight(-1,-2,-1, 0.2,0.2,0.25, 0.25)
  Scene.AddPointLight( 4, 2.5, 3,  1.0, 0.25, 0.20, 1.6, 14)
  Scene.AddPointLight(-4, 2.5, 3,  0.20, 1.0, 0.40, 1.6, 14)
  Scene.AddPointLight( 0, 2.5,-4,  0.25, 0.45, 1.0, 1.6, 14)
  Scene.SetColor(0.9, 0.9, 0.92); Scene.SetMaterial(0.2, 0.35)
  LOOP i = 0 TO 6
    M = Scene.AddSphere(0.6, 28)
    Scene.SetPos(M, (i-3)*1.6, 0.7, 0)
  END
  Scene.SetColor(0.85,0.85,0.88); Scene.SetMaterial(0,0.95)
  M = Scene.AddPlane(30, 30)
  DO ShowIt

Fx_Fog ROUTINE
  Scene.Reset()
  Scene.SetTitle('13 - Fog field')
  Scene.SetCamera(0, 3, 4); Scene.LookAt(0, 1, -20)
  Scene.SetBackground(0.03, 0.05, 0.08)
  Scene.SetFog(1, 0.03, 0.05, 0.08, 4, 30)
  Scene.SetColor(0.35, 0.75, 0.85); Scene.SetMaterial(0.2, 0.5)
  LOOP i = 0 TO 24
    M = Scene.AddCone(0.6, 1.6, 28)
    Scene.SetPos(M, CHOOSE(i%2=0, -2.2, 2.2), 0.8, -i*1.6)
  END
  DO ShowIt

Fx_Glass ROUTINE
  Scene.Reset()
  Scene.SetTitle('14 - Glass (opacity / blending)')
  Scene.SetCamera(0, 4, 8)
  Scene.AddPointLight(3, 5, 4, 1, 1, 1, 1.2, 20)
  Scene.SetMaterial(0.1, 0.15)
  Scene.SetOpacity(0.45)
  LOOP i = 0 TO 5
    Scene.SetColor(0.3 + i*0.1, 0.7, 0.95 - i*0.08)
    M = Scene.AddSphere(0.9, 32)
    Scene.SetPos(M, (i-2.5)*1.0, 1.2, i*0.4)
  END
  Scene.SetOpacity(1)
  Scene.SetColor(0.85,0.86,0.9); Scene.SetMaterial(0,0.9)
  M = Scene.AddPlane(24,24)
  DO ShowIt

Fx_Wire ROUTINE
  Scene.Reset()
  Scene.SetTitle('15 - Wireframe world')
  Scene.SetWireframe(1)
  Scene.SetColor(0.30, 0.85, 0.70); Scene.SetSpin(0.15, 0.35, 0)
  M = Scene.AddIcosa(1.4);  Scene.SetPos(M, -2.4, 1.4, 0)
  M = Scene.AddTorusKnot(0.9, 0.3, 2, 3); Scene.SetPos(M, 1.4, 1.4, 0); Scene.SetColor(0.95,0.7,0.3)
  M = Scene.AddSphere(1.0, 20); Scene.SetPos(M, 4.4, 1.2, 0); Scene.SetColor(0.5,0.7,0.95)
  DO ShowIt

Fx_Solar ROUTINE
  Scene.Reset()
  Scene.SetTitle('16 - Solar system (positions via Vec3 math)')
  Scene.SetCamera(0, 16, 20)
  Scene.SetAmbient(0.06, 0.06, 0.08)
  Scene.SetDirLight(-1,-1,-1, 0.1,0.1,0.1, 0.1)
  Scene.AddPointLight(0, 0, 0, 1.0, 0.85, 0.4, 2.2, 40)     ! the sun lights everything
  Scene.SetColor(1.0, 0.75, 0.2); Scene.SetEmissive(1.0, 0.6, 0.1)
  M = Scene.AddSphere(1.6, 32); Scene.SetPos(M, 0, 0, 0)
  Scene.SetEmissive(0, 0, 0); Scene.SetMaterial(0.2, 0.6)
  LOOP i = 1 TO 7
    dist = 2.8 + i*1.7
    sz = 0.30 + (i % 3) * 0.18
    Scene.SetColor(0.4 + 0.07*i, 0.55, 0.95 - 0.06*i)
    M = Scene.AddSphere(sz, 24)
    ! place the planet on its orbit using the class's own Vec3 math
    Scene.Vec3Scale(COS(i*0.9), 0, SIN(i*0.9), dist)
    Scene.SetPos(M, Scene.Rx, Scene.Ry, Scene.Rz)
  END
  Scene.ShowGrid(0,0,0,0,0,0)
  DO ShowIt

Fx_Neon ROUTINE
  Scene.Reset()
  Scene.SetTitle('17 - Emissive neon ring')
  Scene.SetBackground(0.01, 0.01, 0.02)
  Scene.SetAmbient(0.02, 0.02, 0.03)
  Scene.SetDirLight(-1,-1,-1, 0.05,0.05,0.05, 0.05)
  LOOP i = 0 TO 11
    ang = i / 12.0 * 6.2831853
    Scene.SetColor(0.1, 0.1, 0.1)
    Scene.SetEmissive(0.5 + 0.5*COS(ang), 0.6, 0.5 + 0.5*SIN(ang))
    Scene.SetSpin(0, 0.5, 0)
    M = Scene.AddTorus(0.5, 0.18, 20, 12)
    Scene.SetPos(M, 3.2*COS(ang), 1.2, 3.2*SIN(ang))
    Scene.SetRot(M, 1.57, 0, 0)
  END
  Scene.SetEmissive(0,0,0)
  DO ShowIt

Fx_Sunset ROUTINE
  Scene.Reset()
  Scene.SetTitle('18 - Sunset gradient')
  Scene.SetBackgroundGradient(0.95, 0.55, 0.25, 0.10, 0.10, 0.22)
  Scene.SetCamera(0, 4, 12); Scene.LookAt(0, 2, 0)
  Scene.SetAmbient(0.25, 0.18, 0.20)
  Scene.SetDirLight(-1, -0.6, -0.4, 1.0, 0.6, 0.35, 1.4)
  Scene.SetColor(0.15, 0.16, 0.22); Scene.SetMaterial(0.3, 0.4)
  LOOP i = 0 TO 8
    M = Scene.AddBox(1.2, RANDOM(20,60)/10.0, 1.2)
    Scene.SetPos(M, (i-4)*1.5, 0, -2)
  END
  DO ShowIt

Fx_VecScene ROUTINE
  Scene.Reset()
  Scene.SetTitle('Scene built FROM Vec3 math (Fibonacci sphere)')
  Scene.SetCamera(0, 0, 9)
  Scene.SetMaterial(0.5, 0.3)
  n = 80
  LOOP i = 0 TO n-1
    ! Fibonacci sphere: y from 1..-1, ring radius from y, golden-angle around
    py = 1 - (i / (n-1.0)) * 2
    px = SQRT(1 - py*py)
    pz = i * 2.39996323                                       ! golden angle (radians)
    ! normalize the direction with the class, then push out to radius 3.4
    Scene.Vec3Normalize(COS(pz)*px, py, SIN(pz)*px)
    Scene.SetColor(0.5 + 0.4*Scene.Rx, 0.6, 0.5 + 0.4*Scene.Rz)
    M = Scene.AddSphere(0.18, 14)
    Scene.SetPos(M, Scene.Rx*3.4, Scene.Ry*3.4, Scene.Rz*3.4)
  END
  Scene.ShowGrid(0,0,0,0,0,0)
  DO ShowIt

Fx_Mega ROUTINE
  Scene.Reset()
  Scene.SetTitle('Mega scene - everything at once')
  Scene.SetCamera(0, 12, 20)
  Scene.SetFog(1, 0.02, 0.03, 0.06, 22, 60)
  Scene.AddPointLight( 8, 6, 6, 1.0, 0.45, 0.25, 1.3, 30)
  Scene.AddPointLight(-8, 6, 6, 0.25, 0.55, 1.0, 1.3, 30)
  Scene.AddPointLight( 0, 8,-8, 0.30, 1.0, 0.55, 1.1, 30)
  ! a ring of mixed primitives
  LOOP i = 0 TO 23
    ang = i / 24.0 * 6.2831853
    Scene.SetColor(0.5+0.4*COS(ang), 0.6, 0.5+0.4*SIN(ang))
    Scene.SetMaterial((i%5)/5.0, ((i+2)%5)/5.0)
    Scene.SetSpin(0, 0.4, 0)
    CASE i % 6
    OF 0; M = Scene.AddCube(0.9)
    OF 1; M = Scene.AddSphere(0.55, 22)
    OF 2; M = Scene.AddCone(0.55, 1.2, 26)
    OF 3; M = Scene.AddTorus(0.5, 0.2, 22, 14)
    OF 4; M = Scene.AddIcosa(0.6)
    ELSE; M = Scene.AddDodeca(0.6)
    END
    Scene.SetPos(M, 7*COS(ang), 0.9, 7*SIN(ang))
  END
  ! centerpiece
  Scene.SetColor(0.20, 0.85, 0.85); Scene.SetMaterial(0.8, 0.18); Scene.SetSpin(0, 0.5, 0)
  M = Scene.AddTorusKnot(1.4, 0.4, 2, 5); Scene.SetPos(M, 0, 3.5, 0)
  Scene.SetColor(0.10, 0.12, 0.16); Scene.SetMaterial(0, 0.9); Scene.SetSpin(0,0,0)
  M = Scene.AddPlane(40, 40)
  DO ShowIt

!============================================================================
ShowIt ROUTINE
  Scene.Show()
  LastMeshCount = Scene.MeshCount()
  DISPLAY

!============================================================================
!  Self-test: prove the Vec3 / Mat4 methods compute correctly in Clarion.
!============================================================================
SelfTest ROUTINE
  FAILS = 0
  MSG = 'Vec3 / Mat4 self-test (pure-Clarion math)|' & |
        '---------------------------------------------|'

  ! Vec3Length(3,4,0) = 5
  d = Scene.Vec3Length(3, 4, 0)
  msg = msg & 'Vec3Length(3,4,0)      = ' & FORMAT(d,@n8.4) & '   (expect 5)|'
  IF ABS(d - 5) > 0.0001 THEN FAILS += 1.

  ! Vec3Dot(1,2,3,4,-5,6) = 4-10+18 = 12
  d = Scene.Vec3Dot(1,2,3, 4,-5,6)
  msg = msg & 'Vec3Dot(1,2,3,4,-5,6)  = ' & FORMAT(d,@n8.4) & '   (expect 12)|'
  IF ABS(d - 12) > 0.0001 THEN FAILS += 1.

  ! Vec3Cross(1,0,0 , 0,1,0) = (0,0,1)
  Scene.Vec3Cross(1,0,0, 0,1,0)
  msg = msg & 'Vec3Cross(X,Y)         = (' & FORMAT(Scene.Rx,@n5.2) & ',' & |
        FORMAT(Scene.Ry,@n5.2) & ',' & FORMAT(Scene.Rz,@n5.2) & ')   (expect 0,0,1)|'
  IF ABS(Scene.Rz - 1) > 0.0001 OR ABS(Scene.Rx) > 0.0001 THEN FAILS += 1.

  ! Vec3Normalize(0,3,4) -> length 1
  Scene.Vec3Normalize(0, 3, 4)
  d = Scene.Vec3Length(Scene.Rx, Scene.Ry, Scene.Rz)
  msg = msg & 'Vec3Normalize len      = ' & FORMAT(d,@n8.4) & '   (expect 1)|'
  IF ABS(d - 1) > 0.0001 THEN FAILS += 1.

  ! Vec3Distance(0,0,0, 1,2,2) = 3
  d = Scene.Vec3Distance(0,0,0, 1,2,2)
  msg = msg & 'Vec3Distance to 1,2,2  = ' & FORMAT(d,@n8.4) & '   (expect 3)|'
  IF ABS(d - 3) > 0.0001 THEN FAILS += 1.

  ! Mat4 identity * translate test: build translate(2,3,4), check element 13..15
  Scene.Mat4Translate(2, 3, 4)
  msg = msg & 'Mat4Translate(2,3,4)   = [' & FORMAT(Scene.Mat[13],@n4.1) & ',' & |
        FORMAT(Scene.Mat[14],@n4.1) & ',' & FORMAT(Scene.Mat[15],@n4.1) & ']   (expect 2,3,4)|'
  IF ABS(Scene.Mat[13]-2) > 0.0001 THEN FAILS += 1.

  ! Mat4 multiply: identity * scale(2,2,2) -> diagonal 2,2,2,1
  Scene.Mat4Identity()
  Scene.Mat4Multiply(2,0,0,0, 0,2,0,0, 0,0,2,0, 0,0,0,1)
  msg = msg & 'I * Scale(2)           = diag(' & FORMAT(Scene.Mat[1],@n4.1) & ',' & |
        FORMAT(Scene.Mat[6],@n4.1) & ',' & FORMAT(Scene.Mat[11],@n4.1) & ')   (expect 2,2,2)|'
  IF ABS(Scene.Mat[1]-2) > 0.0001 OR ABS(Scene.Mat[6]-2) > 0.0001 THEN FAILS += 1.

  ! Deg2Rad(180) = PI
  d = Scene.Deg2Rad(180)
  msg = msg & 'Deg2Rad(180)           = ' & FORMAT(d,@n8.5) & '   (expect 3.14159)|'
  IF ABS(d - 3.14159265) > 0.001 THEN FAILS += 1.

  msg = msg & '---------------------------------------------|'
  IF FAILS = 0
    msg = msg & 'ALL TESTS PASSED.'
    MESSAGE(msg, 'Self-test - PASS', ICON:Asterisk)
  ELSE
    msg = msg & FAILS & ' TEST(S) FAILED.'
    MESSAGE(msg, 'Self-test - FAIL', ICON:Hand)
  END
