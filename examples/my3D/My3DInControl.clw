! ============================================================================
!  My3DInControl  -  WebGL2 docked into a single IMAGE control, with normal
!  Clarion controls beside it.
!
!  Scene.SetEmbedControl(?View) confines the docked Edge view to the IMAGE
!  control's rectangle instead of the whole window, so the rest of the window
!  is yours for buttons, lists, etc. The IMAGE is just a layout placeholder -
!  it has no HWND of its own, so the class reads its pixel rectangle via
!  PROP:Pixels + PROP:Xpos/Ypos/Width/Height and hosts the view in a small
!  clipping child window at that rect (which also hides Edge's title bar).
!
!  Requires Microsoft Edge (Windows 10/11) and my3D.engine.js beside the .exe.
!  Build with My3DInControl.cwproj.
! ============================================================================
  PROGRAM

  INCLUDE('WebGL2Class.INC'),ONCE

  MAP
  END

Scene  WebGL2Class
M      LONG

Win WINDOW('my3D rendered inside an IMAGE control'),AT(,,520,344),CENTER,SYSTEM,GRAY,RESIZE,MAX
       IMAGE,AT(8,26,360,310),USE(?View)                     ! the 3D viewport (a placeholder rectangle)
       BUTTON('Re-fit to control'),AT(376,26,128,16),USE(?bFit)
       PROMPT('The 3D scene renders inside the IMAGE control on the left. ' & |
          'These are ordinary Clarion controls beside it - resize the window ' & |
          'and the view re-fits.'),AT(376,52,134,80),USE(?info)
       BUTTON('Close'),AT(452,320,52,16),USE(?bClose),STD(STD:Close)
     END

  CODE
  OPEN(Win)
  0{PROP:MinWidth} = 420; 0{PROP:MinHeight} = 300
  ! ---- build a scene ----
  Scene.SetTitle('Docked in an IMAGE control')
  Scene.SetCamera(8, 6, 11);  Scene.LookAt(0, 0.4, 0)
  Scene.AddPointLight(4, 3.5, 4,  1.0, 0.45, 0.25, 1.2, 18)
  Scene.AddPointLight(-4, 3, -3,  0.25, 0.55, 1.0, 1.1, 18)
  Scene.SetColor(0.20, 0.55, 0.95); Scene.SetMaterial(0.2, 0.4); Scene.SetSpin(0, 0.6, 0)
  M = Scene.AddCube(1.4);          Scene.SetPos(M, -2, 0.7, 0)
  Scene.SetColor(0.20, 0.85, 0.85); Scene.SetMaterial(0.7, 0.2); Scene.SetSpin(0, 0.5, 0)
  M = Scene.AddTorusKnot(0.6, 0.2, 2, 3); Scene.SetPos(M, 1.4, 0.9, 0)
  Scene.SetColor(0.10, 0.12, 0.16); Scene.SetMaterial(0, 0.9); Scene.SetSpin(0, 0, 0)
  M = Scene.AddPlane(20, 20)
  Scene.AddCar(4, 0, -3, 0.5)
  ! ---- dock the view into the IMAGE control (not the whole window) ----
  Scene.SetEmbedControl(?View)
  ACCEPT
    CASE EVENT()
    OF EVENT:OpenWindow
      Scene.ShowEmbedded(0{PROP:Handle})
    OF EVENT:Sized
      Scene.EmbedFit()                                       ! re-fit to the IMAGE control's new rect
    OF EVENT:Moved
      Scene.EmbedFit()
    OF EVENT:CloseWindow
      Scene.EmbedClose()
    END
    CASE ACCEPTED()
    OF ?bFit
      Scene.EmbedFit()
    END
  END
  CLOSE(Win)
  RETURN
