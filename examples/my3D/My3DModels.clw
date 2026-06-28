! ============================================================================
!  My3DModels  -  a gallery of real-world objects modelled from primitives with
!  WebGL2Class (the my3D template's 3D scene manager). Each button assembles a
!  recognisable model out of boxes, spheres, cylinders and cones, then opens it
!  in the browser as a live WebGL2 scene (drag to orbit, wheel to zoom, R reset).
!
!  Every model here is built ONLY from the public class API - the same calls the
!  my3D control template generates - so it doubles as a cookbook for composing
!  primitives into vehicles, buildings and machines.
!
!  BUILD: needs WebGL2Class.inc/.clw + my3D.engine.js in this folder (see README).
! ============================================================================
  PROGRAM

  INCLUDE('WebGL2Class.INC'),ONCE

  MAP
  END

Scene   WebGL2Class

LastMeshCount  LONG
M     LONG                                                   ! index of the last-added mesh
I     LONG
J     LONG
A     REAL                                                   ! angle scratch (radians)
XX    REAL
ZZ    REAL

Window WINDOW('my3D - 3D Model Gallery'),AT(,,360,250),CENTER,SYSTEM,GRAY,FONT('Segoe UI',9),RESIZE
       PROMPT('my3D &mdash; models built from primitives'),AT(12,8),USE(?Hdr),FONT('Segoe UI',11,,FONT:bold)
       PROMPT('Each button assembles a model from boxes, spheres, cylinders &&  cones and opens it in your browser.'),AT(12,22,336,10),USE(?Sub)
       GROUP('Vehicles &&  machines'),AT(8,38,168,94),BOXED,USE(?G1)
         BUTTON('&Car'),AT(16,52,72,16),USE(?bCar)
         BUTTON('&Airplane'),AT(96,52,72,16),USE(?bPlane)
         BUTTON('&Rocket'),AT(16,72,72,16),USE(?bRocket)
         BUTTON('&Wind turbine'),AT(96,72,72,16),USE(?bTurbine)
         BUTTON('Ro&bot'),AT(16,92,72,16),USE(?bRobot)
         BUTTON('&Table &&  chairs'),AT(96,92,72,16),USE(?bTable)
       END
       GROUP('Buildings &&  scenery'),AT(184,38,168,94),BOXED,USE(?G2)
         BUTTON('&House'),AT(192,52,72,16),USE(?bHouse)
         BUTTON('&Foundation'),AT(272,52,72,16),USE(?bFoundation)
         BUTTON('&Skyscraper'),AT(192,72,72,16),USE(?bTower)
         BUTTON('&Park (trees)'),AT(272,72,72,16),USE(?bPark)
       END
       GROUP('Last output'),AT(8,140,344,72),BOXED,USE(?G3)
         PROMPT('File:'),AT(16,154),USE(?lblFile)
         STRING(@s80),AT(40,154,304,10),USE(Scene.LastFile),FONT('Consolas',8)
         PROMPT('Meshes in last model:'),AT(16,170),USE(?lblN)
         STRING(@n-7),AT(120,170),USE(LastMeshCount)
         BUTTON('Re-open last page'),AT(16,186,100,16),USE(?bReopen)
         BUTTON('About'),AT(124,186,70,16),USE(?bAbout)
       END
       STRING('Tip: drag to orbit, mouse-wheel to zoom, press R to reset the camera.'),AT(12,220),USE(?Tip),FONT('Segoe UI',8),TRN
       BUTTON('Close'),AT(300,228,52,16),USE(?bClose),STD(STD:Close)
     END

  CODE
  OPEN(Window)
  ?Hdr{PROP:Text} = 'my3D - models built from primitives'
  ACCEPT
    CASE ACCEPTED()
    OF ?bCar;        DO Mdl_Car
    OF ?bPlane;      DO Mdl_Plane
    OF ?bRocket;     DO Mdl_Rocket
    OF ?bTurbine;    DO Mdl_Turbine
    OF ?bRobot;      DO Mdl_Robot
    OF ?bTable;      DO Mdl_Table
    OF ?bHouse;      DO Mdl_House
    OF ?bFoundation; DO Mdl_Foundation
    OF ?bTower;      DO Mdl_Skyscraper
    OF ?bPark;       DO Mdl_Park
    OF ?bReopen
      IF Scene.LastFile
        RUN('rundll32.exe url.dll,FileProtocolHandler ' & CLIP(Scene.LastFile))
      ELSE
        MESSAGE('Build a model first.','my3D',ICON:Asterisk)
      END
    OF ?bAbout
      MESSAGE('my3D - 3D Model Gallery|' & |
        'Ten real-world objects, each assembled purely from the WebGL2Class ' & |
        'primitives (box, sphere, cylinder, cone) and shown live in WebGL2.||' & |
        'Open the .clw to see exactly how each one is built.', |
        'About', ICON:Asterisk)
    OF ?bClose
      BREAK
    END
  END
  CLOSE(Window)
  RETURN

!============================================================================
ShowIt ROUTINE
  Scene.Show()
  LastMeshCount = Scene.MeshCount()
  DISPLAY

!============================================================================
!  1. CAR  (faces +X)  -  body, cabin, glass, 4 wheels + hubcaps, headlights
!============================================================================
Mdl_Car ROUTINE
  Scene.Reset(); Scene.SetTitle('Car')
  Scene.SetCamera(7, 4, 8.5); Scene.LookAt(0, 0.8, 0)
  Scene.SetColor(0.10,0.11,0.13); Scene.SetMaterial(0, 0.95); M = Scene.AddPlane(30, 30)
  Scene.SetColor(0.80,0.12,0.12); Scene.SetMaterial(0.5, 0.3)
  M = Scene.AddBox(4.2,0.8,1.9);  Scene.SetPos(M, 0, 0.95, 0)         ! body
  M = Scene.AddBox(4.4,0.45,1.7); Scene.SetPos(M, 0, 0.62, 0)         ! lower skirt
  M = Scene.AddBox(2.1,0.8,1.65); Scene.SetPos(M, -0.3, 1.65, 0)      ! cabin
  Scene.SetColor(0.12,0.16,0.22); Scene.SetMaterial(0.3,0.1); Scene.SetOpacity(0.75)
  M = Scene.AddBox(2.0,0.65,1.55); Scene.SetPos(M, -0.3, 1.66, 0); Scene.SetOpacity(1)  ! glass
  Scene.SetColor(0.07,0.07,0.08); Scene.SetMaterial(0.1, 0.85)
  LOOP I = 0 TO 3                                                     ! 4 tyres
    XX = CHOOSE(I < 2, 1.35, -1.35)
    ZZ = CHOOSE(I % 2 = 0, 1.0, -1.0)
    M = Scene.AddCylinder(0.55,0.55,0.4,28); Scene.SetPos(M, XX, 0.55, ZZ); Scene.SetRot(M, 1.5708, 0, 0)
  END
  Scene.SetColor(0.75,0.76,0.80); Scene.SetMaterial(0.85, 0.2)
  LOOP I = 0 TO 3                                                     ! hubcaps
    XX = CHOOSE(I < 2, 1.35, -1.35)
    ZZ = CHOOSE(I % 2 = 0, 1.0, -1.0)
    M = Scene.AddCylinder(0.22,0.22,0.42,20); Scene.SetPos(M, XX, 0.55, ZZ); Scene.SetRot(M, 1.5708, 0, 0)
  END
  Scene.SetColor(1,0.95,0.7); Scene.SetEmissive(0.9,0.82,0.45)       ! headlights
  M = Scene.AddSphere(0.17,14); Scene.SetPos(M, 2.13, 0.95, 0.6)
  M = Scene.AddSphere(0.17,14); Scene.SetPos(M, 2.13, 0.95, -0.6)
  Scene.SetEmissive(0,0,0)
  DO ShowIt

!============================================================================
!  2. AIRPLANE  (faces +X)  -  fuselage, nose cone, wings, tail, engines
!============================================================================
Mdl_Plane ROUTINE
  Scene.Reset(); Scene.SetTitle('Airplane')
  Scene.SetCamera(8, 5, 9); Scene.LookAt(0, 2, 0)
  Scene.SetColor(0.85,0.87,0.90); Scene.SetMaterial(0.6, 0.3)
  M = Scene.AddCylinder(0.5,0.5,5,24); Scene.SetPos(M, 0, 2.2, 0); Scene.SetRot(M, 0, 0, 1.5708)   ! fuselage
  Scene.SetColor(0.80,0.20,0.20)
  M = Scene.AddCone(0.5,1.0,24); Scene.SetPos(M, 2.95, 2.2, 0); Scene.SetRot(M, 0, 0, -1.5708)     ! nose
  Scene.SetColor(0.30,0.45,0.85); Scene.SetMaterial(0.4, 0.4)
  M = Scene.AddBox(1.5,0.14,5.4); Scene.SetPos(M, 0.1, 2.1, 0)        ! main wings
  M = Scene.AddBox(0.8,0.1,2.2);  Scene.SetPos(M, -2.2, 2.2, 0)       ! tail stabiliser
  Scene.SetColor(0.80,0.20,0.20)
  M = Scene.AddBox(0.7,0.9,0.14); Scene.SetPos(M, -2.2, 2.65, 0)      ! tail fin
  Scene.SetColor(0.12,0.16,0.22); Scene.SetMaterial(0.3,0.1); Scene.SetOpacity(0.8)
  M = Scene.AddSphere(0.42,18); Scene.SetPos(M, 1.4, 2.5, 0); Scene.SetScale(M, 1.2, 0.7, 0.9); Scene.SetOpacity(1)  ! canopy
  Scene.SetColor(0.2,0.2,0.22); Scene.SetMaterial(0.5, 0.4)
  M = Scene.AddCylinder(0.26,0.26,1.2,16); Scene.SetPos(M, 0.3, 1.75, 1.7);  Scene.SetRot(M, 0, 0, 1.5708)  ! engines
  M = Scene.AddCylinder(0.26,0.26,1.2,16); Scene.SetPos(M, 0.3, 1.75, -1.7); Scene.SetRot(M, 0, 0, 1.5708)
  DO ShowIt

!============================================================================
!  3. ROCKET  -  body, nose cone, window, 4 fins, exhaust flame
!============================================================================
Mdl_Rocket ROUTINE
  Scene.Reset(); Scene.SetTitle('Rocket')
  Scene.SetCamera(7, 5, 9); Scene.LookAt(0, 3, 0)
  Scene.SetColor(0.20,0.50,0.30); Scene.SetMaterial(0, 0.9); M = Scene.AddPlane(40, 40)
  Scene.SetColor(0.92,0.92,0.95); Scene.SetMaterial(0.5, 0.3)
  M = Scene.AddCylinder(0.7,0.7,4.5,28); Scene.SetPos(M, 0, 3.0, 0)   ! body
  Scene.SetColor(0.85,0.20,0.20)
  M = Scene.AddCone(0.7,1.6,28); Scene.SetPos(M, 0, 6.05, 0)          ! nose
  Scene.SetColor(0.30,0.55,0.85); Scene.SetEmissive(0.15,0.3,0.5)
  M = Scene.AddSphere(0.28,18); Scene.SetPos(M, 0, 4.3, 0.62); Scene.SetEmissive(0,0,0)  ! window
  Scene.SetColor(0.85,0.20,0.20); Scene.SetMaterial(0.4, 0.4)
  LOOP I = 0 TO 3                                                     ! fins
    A = I * 1.5708
    M = Scene.AddBox(0.12,1.2,0.9); Scene.SetPos(M, 0.7*SIN(A), 1.2, 0.7*COS(A)); Scene.SetRot(M, 0, A, 0)
  END
  Scene.SetColor(1.0,0.6,0.1); Scene.SetEmissive(1.0,0.45,0.05)
  M = Scene.AddCone(0.55,1.4,20); Scene.SetPos(M, 0, 0.2, 0); Scene.SetRot(M, 3.14159, 0, 0)  ! flame (points down)
  Scene.SetEmissive(0,0,0)
  DO ShowIt

!============================================================================
!  4. WIND TURBINE  -  tapered tower, nacelle, hub, three blades at 120 deg
!============================================================================
Mdl_Turbine ROUTINE
  Scene.Reset(); Scene.SetTitle('Wind turbine')
  Scene.SetCamera(8, 5, 9); Scene.LookAt(0, 4, 0)
  Scene.SetColor(0.30,0.55,0.35); Scene.SetMaterial(0, 0.9); M = Scene.AddPlane(40, 40)
  Scene.SetColor(0.90,0.92,0.95); Scene.SetMaterial(0.3, 0.4)
  M = Scene.AddCylinder(0.18,0.40,6.5,28); Scene.SetPos(M, 0, 3.25, 0)  ! tower
  M = Scene.AddBox(1.4,0.6,0.7); Scene.SetPos(M, 0, 6.6, 0.1)           ! nacelle
  Scene.SetColor(0.85,0.87,0.9)
  M = Scene.AddSphere(0.3,18); Scene.SetPos(M, 0, 6.6, 0.55)            ! hub
  Scene.SetColor(0.95,0.96,0.98); Scene.SetMaterial(0.2, 0.5)
  LOOP I = 0 TO 2                                                       ! 3 blades
    A = I * 2.0944
    M = Scene.AddBox(0.18,3.4,0.55); Scene.SetPos(M, -1.7*SIN(A), 6.6+1.7*COS(A), 0.6); Scene.SetRot(M, 0, 0, A)
  END
  DO ShowIt

!============================================================================
!  5. ROBOT  -  legs, feet, torso, chest light, arms, hands, head, eyes, antenna
!============================================================================
Mdl_Robot ROUTINE
  Scene.Reset(); Scene.SetTitle('Robot')
  Scene.SetCamera(6, 5, 8); Scene.LookAt(0, 2.2, 0)
  Scene.SetColor(0.20,0.22,0.26); Scene.SetMaterial(0, 0.9); M = Scene.AddPlane(30, 30)
  Scene.SetColor(0.45,0.48,0.52); Scene.SetMaterial(0.7, 0.3)
  M = Scene.AddCylinder(0.22,0.22,1.4,16); Scene.SetPos(M, -0.45, 0.7, 0)   ! legs
  M = Scene.AddCylinder(0.22,0.22,1.4,16); Scene.SetPos(M,  0.45, 0.7, 0)
  Scene.SetColor(0.25,0.27,0.30); Scene.SetMaterial(0.4, 0.5)
  M = Scene.AddBox(0.5,0.25,0.8); Scene.SetPos(M, -0.45, 0.12, 0.1)         ! feet
  M = Scene.AddBox(0.5,0.25,0.8); Scene.SetPos(M,  0.45, 0.12, 0.1)
  Scene.SetColor(0.25,0.45,0.75); Scene.SetMaterial(0.6, 0.3)
  M = Scene.AddBox(1.6,1.8,0.9); Scene.SetPos(M, 0, 2.3, 0)                 ! torso
  Scene.SetColor(0.3,0.9,0.5); Scene.SetEmissive(0.2,0.7,0.35)
  M = Scene.AddSphere(0.18,16); Scene.SetPos(M, 0, 2.5, 0.5); Scene.SetEmissive(0,0,0)  ! chest light
  Scene.SetColor(0.45,0.48,0.52); Scene.SetMaterial(0.7, 0.3)
  M = Scene.AddCylinder(0.18,0.18,1.6,16); Scene.SetPos(M, -1.0, 2.3, 0)    ! arms
  M = Scene.AddCylinder(0.18,0.18,1.6,16); Scene.SetPos(M,  1.0, 2.3, 0)
  Scene.SetColor(0.85,0.7,0.2); Scene.SetMaterial(0.5, 0.4)
  M = Scene.AddSphere(0.22,16); Scene.SetPos(M, -1.0, 1.45, 0)              ! hands
  M = Scene.AddSphere(0.22,16); Scene.SetPos(M,  1.0, 1.45, 0)
  Scene.SetColor(0.55,0.58,0.62); Scene.SetMaterial(0.7, 0.3)
  M = Scene.AddBox(0.9,0.8,0.8); Scene.SetPos(M, 0, 3.6, 0)                 ! head
  Scene.SetColor(0.9,0.95,1.0); Scene.SetEmissive(0.6,0.7,0.9)
  M = Scene.AddSphere(0.12,14); Scene.SetPos(M, -0.22, 3.65, 0.42)          ! eyes
  M = Scene.AddSphere(0.12,14); Scene.SetPos(M,  0.22, 3.65, 0.42); Scene.SetEmissive(0,0,0)
  Scene.SetColor(0.5,0.5,0.55); Scene.SetMaterial(0.6, 0.3)
  M = Scene.AddCylinder(0.04,0.04,0.5,8); Scene.SetPos(M, 0, 4.25, 0)       ! antenna
  Scene.SetColor(0.9,0.2,0.2); Scene.SetEmissive(0.7,0.1,0.1)
  M = Scene.AddSphere(0.1,12); Scene.SetPos(M, 0, 4.55, 0); Scene.SetEmissive(0,0,0)
  DO ShowIt

!============================================================================
!  6. TABLE &  CHAIRS  -  a tabletop on four legs, ringed by four chairs
!============================================================================
Mdl_Table ROUTINE
  Scene.Reset(); Scene.SetTitle('Table & chairs')
  Scene.SetCamera(7, 6, 8); Scene.LookAt(0, 0.8, 0)
  Scene.SetColor(0.30,0.30,0.33); Scene.SetMaterial(0, 0.9); M = Scene.AddPlane(30, 30)
  Scene.SetColor(0.55,0.36,0.20); Scene.SetMaterial(0.2, 0.5)
  M = Scene.AddBox(3.0,0.16,1.6); Scene.SetPos(M, 0, 1.5, 0)          ! tabletop
  Scene.SetColor(0.40,0.26,0.14)
  LOOP I = 0 TO 3                                                     ! table legs
    XX = CHOOSE(I < 2, -1.35, 1.35)
    ZZ = CHOOSE(I % 2 = 0, -0.65, 0.65)
    M = Scene.AddCylinder(0.09,0.09,1.5,10); Scene.SetPos(M, XX, 0.75, ZZ)
  END
  LOOP I = 0 TO 3                                                     ! 4 chairs around it
    A = I * 1.5708
    XX = 2.3 * SIN(A)
    ZZ = 2.3 * COS(A)
    Scene.SetColor(0.45,0.30,0.18); Scene.SetMaterial(0.2, 0.6)
    M = Scene.AddBox(0.9,0.12,0.9); Scene.SetPos(M, XX, 0.9, ZZ)       ! seat
    M = Scene.AddBox(0.9,0.9,0.12); Scene.SetPos(M, XX+0.39*SIN(A), 1.35, ZZ+0.39*COS(A)); Scene.SetRot(M, 0, A, 0)  ! back
    M = Scene.AddCylinder(0.07,0.07,0.9,8); Scene.SetPos(M, XX, 0.45, ZZ)  ! pedestal
  END
  DO ShowIt

!============================================================================
!  7. HOUSE  -  walls, a square pyramid roof, door, windows, chimney
!============================================================================
Mdl_House ROUTINE
  Scene.Reset(); Scene.SetTitle('House')
  Scene.SetCamera(8, 5, 9); Scene.LookAt(0, 1.6, 0)
  Scene.SetColor(0.30,0.55,0.30); Scene.SetMaterial(0, 0.9); M = Scene.AddPlane(40, 40)  ! lawn
  Scene.SetColor(0.90,0.85,0.72); Scene.SetMaterial(0.1, 0.7)
  M = Scene.AddBox(5,2.6,4); Scene.SetPos(M, 0, 1.3, 0)               ! walls
  Scene.SetColor(0.55,0.18,0.14); Scene.SetMaterial(0.1, 0.6)
  M = Scene.AddCone(3.6,1.8,4); Scene.SetPos(M, 0, 3.5, 0); Scene.SetRot(M, 0, 0.7854, 0)  ! pyramid roof (4-sided cone, turned 45 deg)
  Scene.SetColor(0.45,0.28,0.15)
  M = Scene.AddBox(0.9,1.6,0.12); Scene.SetPos(M, 0, 0.8, 2.02)       ! door
  Scene.SetColor(0.55,0.75,0.95); Scene.SetEmissive(0.25,0.40,0.55); Scene.SetMaterial(0.3, 0.2)
  M = Scene.AddBox(0.9,0.9,0.12);  Scene.SetPos(M, -1.6, 1.5, 2.02)   ! windows
  M = Scene.AddBox(0.9,0.9,0.12);  Scene.SetPos(M,  1.6, 1.5, 2.02)
  M = Scene.AddBox(0.12,0.9,0.9);  Scene.SetPos(M, -2.52, 1.5, 0)
  M = Scene.AddBox(0.12,0.9,0.9);  Scene.SetPos(M,  2.52, 1.5, 0)
  Scene.SetEmissive(0,0,0)
  Scene.SetColor(0.5,0.4,0.35); Scene.SetMaterial(0.1, 0.8)
  M = Scene.AddBox(0.5,1.4,0.5); Scene.SetPos(M, 1.4, 3.6, -0.6)      ! chimney
  DO ShowIt

!============================================================================
!  8. BUILDING FOUNDATION  -  slab, perimeter stem walls, footing pads, rebar
!============================================================================
Mdl_Foundation ROUTINE
  Scene.Reset(); Scene.SetTitle('Building foundation')
  Scene.SetCamera(11, 8, 12); Scene.LookAt(0, 0.6, 0)
  Scene.SetColor(0.45,0.40,0.32); Scene.SetMaterial(0, 0.95); M = Scene.AddPlane(40, 40)  ! ground
  Scene.SetColor(0.62,0.62,0.64); Scene.SetMaterial(0.05, 0.85)
  M = Scene.AddBox(10,0.3,8); Scene.SetPos(M, 0, 0.15, 0)             ! slab
  Scene.SetColor(0.55,0.55,0.57)
  M = Scene.AddBox(10,1.0,0.4); Scene.SetPos(M, 0, 0.7,  3.8)         ! stem walls
  M = Scene.AddBox(10,1.0,0.4); Scene.SetPos(M, 0, 0.7, -3.8)
  M = Scene.AddBox(0.4,1.0,7.2); Scene.SetPos(M,  4.8, 0.7, 0)
  M = Scene.AddBox(0.4,1.0,7.2); Scene.SetPos(M, -4.8, 0.7, 0)
  LOOP I = 0 TO 2                                                     ! 3x3 footings + rebar
    LOOP J = 0 TO 2
      XX = (I-1) * 4.0
      ZZ = (J-1) * 3.0
      Scene.SetColor(0.58,0.58,0.60); Scene.SetMaterial(0.05, 0.85)
      M = Scene.AddBox(1.0,0.5,1.0); Scene.SetPos(M, XX, 0.25, ZZ)    ! footing pad
      Scene.SetColor(0.70,0.30,0.12); Scene.SetMaterial(0.5, 0.5)
      M = Scene.AddCylinder(0.06,0.06,1.8,8); Scene.SetPos(M, XX, 1.2, ZZ)  ! rebar column
    END
  END
  DO ShowIt

!============================================================================
!  9. SKYSCRAPER  -  a tapered stack of glass floors topped with an antenna
!============================================================================
Mdl_Skyscraper ROUTINE
  Scene.Reset(); Scene.SetTitle('Skyscraper')
  Scene.SetCamera(10, 12, 14); Scene.LookAt(0, 5, 0)
  Scene.SetColor(0.25,0.40,0.30); Scene.SetMaterial(0, 0.9); M = Scene.AddPlane(50, 50)
  Scene.SetMaterial(0.6, 0.25)
  LOOP I = 0 TO 16
    A = 3.0 - I * 0.14                                                ! taper the width as it rises
    Scene.SetColor(0.35 - I*0.01, 0.55, 0.75)
    M = Scene.AddBox(A, 0.8, A); Scene.SetPos(M, 0, 0.4 + I*0.8, 0)
  END
  Scene.SetColor(0.8,0.8,0.82); Scene.SetMaterial(0.7, 0.3)
  M = Scene.AddCylinder(0.05,0.05,2,8); Scene.SetPos(M, 0, 14.0, 0)   ! antenna
  DO ShowIt

!============================================================================
!  10. PARK  -  alternating pine (stacked cones) and round (spheres) trees
!============================================================================
Mdl_Park ROUTINE
  Scene.Reset(); Scene.SetTitle('Park - trees')
  Scene.SetCamera(9, 6, 11); Scene.LookAt(0, 1.8, 0)
  Scene.SetColor(0.25,0.55,0.28); Scene.SetMaterial(0, 0.9); M = Scene.AddPlane(40, 40)
  LOOP I = 0 TO 4
    XX = (I-2) * 3.0
    Scene.SetColor(0.42,0.28,0.15); Scene.SetMaterial(0.1, 0.8)
    M = Scene.AddCylinder(0.22,0.30,1.4,12); Scene.SetPos(M, XX, 0.7, 0)   ! trunk
    IF I % 2 = 0                                                      ! pine: 3 stacked cones
      Scene.SetColor(0.16,0.45,0.22); Scene.SetMaterial(0, 0.7)
      M = Scene.AddCone(1.1,1.4,16); Scene.SetPos(M, XX, 1.9, 0)
      M = Scene.AddCone(0.9,1.2,16); Scene.SetPos(M, XX, 2.6, 0)
      M = Scene.AddCone(0.7,1.0,16); Scene.SetPos(M, XX, 3.3, 0)
    ELSE                                                             ! round tree: clustered spheres
      Scene.SetColor(0.22,0.55,0.25); Scene.SetMaterial(0, 0.7)
      M = Scene.AddSphere(1.0,18); Scene.SetPos(M, XX, 2.3, 0)
      M = Scene.AddSphere(0.8,18); Scene.SetPos(M, XX-0.5, 2.0, 0.4)
      M = Scene.AddSphere(0.8,18); Scene.SetPos(M, XX+0.5, 2.1, -0.3)
    END
  END
  DO ShowIt
