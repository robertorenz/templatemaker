! ============================================================================
!  My3DEmbedded  -  a WebGL2 3D scene docked INSIDE a Clarion window.
!
!  WebGL2Class.ShowEmbedded() launches a borderless Edge "--app" window (real
!  WebGL2) off-screen, then re-parents it into this Clarion window with the
!  Win32 SetParent. Edge runs in its OWN process, so its Chromium message pump
!  never re-enters Clarion's event loop - no DLL, no import lib, no crash.
!
!  Drag inside the view to orbit, mouse-wheel to zoom, press R to reset.
!
!  Requires Microsoft Edge (ships with Windows 10/11) and my3D.engine.js beside
!  the .exe. Build with My3DEmbedded.cwproj.
! ============================================================================
  PROGRAM

  INCLUDE('WebGL2Class.INC'),ONCE

  MAP
  END

Scene  WebGL2Class
M      LONG

Win WINDOW('my3D - WebGL2 docked inside a Clarion window'),AT(,,560,400),CENTER,SYSTEM,GRAY,RESIZE,MAX
    END

  CODE
  OPEN(Win)
  0{PROP:MinWidth}  = 360
  0{PROP:MinHeight} = 260
  ! ---- build a little scene ----
  Scene.SetTitle('Docked WebGL2 viewer')
  Scene.SetCanvas(900, 600)
  Scene.SetCamera(8, 6, 11);  Scene.LookAt(0, 0.4, 0)
  Scene.AddPointLight(4, 3.5, 4,  1.0, 0.45, 0.25, 1.2, 18)
  Scene.AddPointLight(-4, 3, -3,  0.25, 0.55, 1.0, 1.1, 18)
  Scene.SetColor(0.20, 0.55, 0.95); Scene.SetMaterial(0.2, 0.4); Scene.SetSpin(0, 0.6, 0)
  M = Scene.AddCube(1.4);          Scene.SetPos(M, -3, 0.7, 0)
  Scene.SetColor(0.20, 0.85, 0.85); Scene.SetMaterial(0.7, 0.2); Scene.SetSpin(0, 0.5, 0)
  M = Scene.AddTorusKnot(0.6, 0.2, 2, 3); Scene.SetPos(M, 0, 0.9, 0)
  Scene.SetColor(0.95, 0.35, 0.45); Scene.SetMaterial(0.6, 0.25); Scene.SetSpin(0, 0, 0)
  M = Scene.AddSphere(0.85, 28);   Scene.SetPos(M, 2.6, 0.85, 0)
  Scene.SetColor(0.10, 0.12, 0.16); Scene.SetMaterial(0, 0.9); Scene.SetSpin(0, 0, 0)
  M = Scene.AddPlane(26, 26)
  Scene.AddHouse(5, 0, -4, 0.6)
  Scene.AddCar(-5, 0, -4, 0.6)
  ACCEPT
    CASE EVENT()
    OF EVENT:OpenWindow
      Scene.ShowEmbedded(0{PROP:Handle})                     ! dock once the window is realized + sized
    OF EVENT:Sized
      Scene.EmbedFit()                                       ! keep the view filling the window
    OF EVENT:CloseWindow
      Scene.EmbedClose()                                     ! close the docked Edge window with this one
    END
  END
  CLOSE(Win)
  RETURN
