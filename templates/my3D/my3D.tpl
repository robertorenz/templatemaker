#TEMPLATE(my3D,'my3D - WebGL2 3D scenes driven from Clarion - v1.0'),FAMILY('ABC')
#!-----------------------------------------------------------------------------
#!  my3D template set  -  drive a real WebGL2 3D scene from Clarion.
#!
#!  The WebGL2Class builds a self-contained .HTML page (scene data + the my3D
#!  WebGL2 engine) and opens it in the default browser. Configure cameras,
#!  lights, materials, 20+ mesh primitives, fog, a grid and axes - all from the
#!  AppGen prompts below; no JavaScript required.
#!
#!  my3DGlobal  (APPLICATION) - INCLUDEs WebGL2Class. Add once, globally
#!                              (or just drop the control template - it self-includes).
#!  my3DViewer  (CONTROL)     - drag onto a window: drops a "View 3D Scene" button
#!                              and wires a fully-configured scene to it. MULTI, so
#!                              several independent viewers per window are fine.
#!
#!  REQUIRED FILES (copy beside this .tpl onto the redirection path, ANSI/CRLF):
#!    WebGL2Class.INC, WebGL2Class.CLW   (compiled into the app)
#!    my3D.engine.js                     (read at RUN time; ship it next to the .EXE)
#!-----------------------------------------------------------------------------
#!#############################################################################
#!  GLOBAL EXTENSION - my3DGlobal
#!#############################################################################
#EXTENSION(my3DGlobal,'my3D - Global (add once per application)'),APPLICATION
#SHEET
  #TAB('&General')
    #BOXED('my3D Global')
      #DISPLAY('my3D Global - Version 1.0')
      #DISPLAY('Adds the WebGL2Class 3D-scene manager.')
      #DISPLAY('Copy WebGL2Class.INC + WebGL2Class.CLW to the redirection path,')
      #DISPLAY('and ship my3D.engine.js beside the compiled .EXE.')
    #ENDBOXED
    #BOXED('Options')
      #PROMPT('&Disable this template',CHECK),%my3DGlobalDisable,DEFAULT(0),AT(10)
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#AT(%AfterGlobalIncludes),WHERE(%my3DGlobalDisable=0)
INCLUDE('WebGL2Class.INC'),ONCE
#ENDAT
#!#############################################################################
#!  CONTROL TEMPLATE - my3DViewer  -  drag a "View 3D Scene" button onto a window
#!#############################################################################
#!  Drops a BUTTON and wires a complete scene to it. Self-contained: it emits
#!  INCLUDE('WebGL2Class.INC'),ONCE so the my3DGlobal extension is optional.
#!  WINDOW + MULTI = as many independent viewers per window as you like.
#!#############################################################################
#CONTROL(my3DViewer,'my3D - 3D Scene Viewer button (drag onto a window)'),WINDOW,MULTI,DESCRIPTION('3D Viewer ' & %my3DObject),HLP('~my3D.htm')
  CONTROLS
    BUTTON('View 3D Scene...'),AT(,,120,16),USE(?my3DButton)
  END
#SHEET
  #TAB('&General')
    #BOXED('Object')
      #PROMPT('&Disable this viewer',CHECK),%my3DDisable,DEFAULT(0),AT(10)
      #PROMPT('&Object name:',@s64),%my3DObject,REQ,DEFAULT('Scene' & %ActiveTemplateInstance)
      #PROMPT('&Page title:',@s64),%my3DTitle,DEFAULT('my3D / WebGL2 Scene')
      #PROMPT('&Show in:',DROP('External browser[0]|Embedded - docked Edge (real WebGL2)[1]')),%my3DDisplayMode,DEFAULT('0')
      #ENABLE(%my3DDisplayMode='1')
        #PROMPT('Dock into this &control (blank = the whole window):',FROM(%Control,%ControlType='IMAGE' OR %ControlType='REGION')),%my3DDockCtrl,DEFAULT('')
      #ENDENABLE
      #PROMPT('Open the scene &automatically when the window opens',CHECK),%my3DAutoOpen,DEFAULT(0),AT(10)
      #BOXED('')
        #DISPLAY('Embedded docks a borderless Edge window (real WebGL2) into this window.')
        #DISPLAY('Pick an IMAGE/REGION to confine it to that control, or leave blank to')
        #DISPLAY('fill the window. Needs Microsoft Edge (Win10/11) + my3D.engine.js by the .exe.')
      #ENDBOXED
    #ENDBOXED
    #BOXED('Canvas')
      #PROMPT('&Width (px):',SPIN(@n5,320,4000,10)),%my3DW,DEFAULT(1000)
      #PROMPT('&Height (px):',SPIN(@n5,240,4000,10)),%my3DH,DEFAULT(640)
      #PROMPT('&Antialias',CHECK),%my3DAA,DEFAULT(1),AT(10)
    #ENDBOXED
  #ENDTAB
  #TAB('&Camera')
    #BOXED('Eye position')
      #PROMPT('Camera &X:',@n-9.2),%my3DCamX,DEFAULT(7)
      #PROMPT('Camera &Y:',@n-9.2),%my3DCamY,DEFAULT(6)
      #PROMPT('Camera &Z:',@n-9.2),%my3DCamZ,DEFAULT(11)
    #ENDBOXED
    #BOXED('Look-at target')
      #PROMPT('Target X:',@n-9.2),%my3DTgtX,DEFAULT(0)
      #PROMPT('Target Y:',@n-9.2),%my3DTgtY,DEFAULT(0.4)
      #PROMPT('Target Z:',@n-9.2),%my3DTgtZ,DEFAULT(0)
    #ENDBOXED
    #BOXED('Lens')
      #PROMPT('&Field of view (deg):',SPIN(@n3,10,120,1)),%my3DFov,DEFAULT(50)
      #PROMPT('Auto-&orbit the camera',CHECK),%my3DOrbit,DEFAULT(1),AT(10)
      #PROMPT('Orbit &speed (rad/s):',@n-5.2),%my3DOrbitSpeed,DEFAULT(0.3)
    #ENDBOXED
  #ENDTAB
  #TAB('&Scene')
    #BOXED('Background')
      #PROMPT('&Top color:',COLOR),%my3DBgTop,DEFAULT(00140906H)
      #PROMPT('&Bottom color:',COLOR),%my3DBgBot,DEFAULT(00050201H)
    #ENDBOXED
    #BOXED('Grid &&  axes')
      #PROMPT('Show &grid',CHECK),%my3DGridOn,DEFAULT(1),AT(10)
      #PROMPT('Grid si&ze:',@n-7.1),%my3DGridSize,DEFAULT(20)
      #PROMPT('Grid &divisions:',SPIN(@n3,1,200,1)),%my3DGridDiv,DEFAULT(20)
      #PROMPT('Grid &color:',COLOR),%my3DGridColor,DEFAULT(00382716H)
      #PROMPT('Show &axes',CHECK),%my3DAxesOn,DEFAULT(1),AT(10)
      #PROMPT('Axes si&ze:',@n-7.1),%my3DAxesSize,DEFAULT(3)
    #ENDBOXED
    #BOXED('Fog &&  style')
      #PROMPT('Enable &fog',CHECK),%my3DFogOn,DEFAULT(0),AT(10)
      #PROMPT('Fog c&olor:',COLOR),%my3DFogColor,DEFAULT(00060302H)
      #PROMPT('Fog &near:',@n-7.1),%my3DFogNear,DEFAULT(14)
      #PROMPT('Fog fa&r:',@n-7.1),%my3DFogFar,DEFAULT(38)
      #PROMPT('&Wireframe (all meshes)',CHECK),%my3DWire,DEFAULT(0),AT(10)
    #ENDBOXED
  #ENDTAB
  #TAB('&Lighting')
    #BOXED('Ambient &&  key (directional) light')
      #PROMPT('&Ambient color:',COLOR),%my3DAmb,DEFAULT(002E2A24H)
      #PROMPT('Direction X:',@n-7.2),%my3DDirX,DEFAULT(-1)
      #PROMPT('Direction Y:',@n-7.2),%my3DDirY,DEFAULT(-2)
      #PROMPT('Direction Z:',@n-7.2),%my3DDirZ,DEFAULT(-1.3)
      #PROMPT('&Key light color:',COLOR),%my3DDirColor,DEFAULT(00E6F7FFH)
      #PROMPT('Key &intensity:',@n-5.2),%my3DDirInt,DEFAULT(1.05)
    #ENDBOXED
    #BUTTON('Point lights'),MULTI(%my3DPL,'Light at ' & %my3DPLx & ',' & %my3DPLy & ',' & %my3DPLz),INLINE
      #PROMPT('X:',@n-9.2),%my3DPLx,DEFAULT(4)
      #PROMPT('Y:',@n-9.2),%my3DPLy,DEFAULT(3)
      #PROMPT('Z:',@n-9.2),%my3DPLz,DEFAULT(4)
      #PROMPT('Color:',COLOR),%my3DPLColor,DEFAULT(002973FFH)
      #PROMPT('Intensity:',@n-5.2),%my3DPLInt,DEFAULT(1.2)
      #PROMPT('Range:',@n-7.1),%my3DPLRange,DEFAULT(18)
    #ENDBUTTON
  #ENDTAB
  #TAB('&Meshes')
    #DISPLAY('Add 3D objects to the scene. Params 1-4 mean different things per shape')
    #DISPLAY('(e.g. Sphere = radius, segments; Box = width, height, depth).')
    #DISPLAY('MODELS (Car, House, ...) are multi-part objects: only Position &&  Uniform')
    #DISPLAY('scale apply - set Position Y to 0 so the model sits on the ground.')
    #BUTTON('Meshes'),MULTI(%my3DMesh,%my3DMeshType & ' @ ' & %my3DMeshX & ',' & %my3DMeshY & ',' & %my3DMeshZ),INLINE
      #PROMPT('&Shape:',DROP('Box / Cube[box]|Sphere[sphere]|Cylinder[cylinder]|Cone[cone]|Plane[plane]|Torus[torus]|Torus knot[torusknot]|Tetrahedron[tetra]|Octahedron[octa]|Icosahedron[icosa]|Dodecahedron[dodeca]|-- Car (model)[car]|-- Airplane (model)[airplane]|-- Rocket (model)[rocket]|-- Wind turbine (model)[turbine]|-- Robot (model)[robot]|-- Table+Chairs (model)[table]|-- House (model)[house]|-- Foundation (model)[foundation]|-- Skyscraper (model)[skyscraper]|-- Trees (model)[trees]')),%my3DMeshType,DEFAULT('box')
      #PROMPT('Param &1 (size/radius/width):',@n-9.3),%my3DMeshP1,DEFAULT(1)
      #PROMPT('Param &2 (height/segments/depth):',@n-9.3),%my3DMeshP2,DEFAULT(1)
      #PROMPT('Param &3 (segments/depth):',@n-9.3),%my3DMeshP3,DEFAULT(1)
      #PROMPT('Param &4 (segments):',@n-9.3),%my3DMeshP4,DEFAULT(0)
      #PROMPT('Position &X:',@n-9.2),%my3DMeshX,DEFAULT(0)
      #PROMPT('Position &Y:',@n-9.2),%my3DMeshY,DEFAULT(0.7)
      #PROMPT('Position &Z:',@n-9.2),%my3DMeshZ,DEFAULT(0)
      #PROMPT('Uniform &scale:',@n-7.3),%my3DMeshScale,DEFAULT(1)
      #PROMPT('&Color:',COLOR),%my3DMeshColor,DEFAULT(00F08C33H)
      #PROMPT('&Metalness (0-1):',@n-4.2),%my3DMeshMetal,DEFAULT(0.2)
      #PROMPT('&Roughness (0-1):',@n-4.2),%my3DMeshRough,DEFAULT(0.45)
      #PROMPT('Spin &Y (rad/s):',@n-5.2),%my3DMeshSpin,DEFAULT(0)
      #PROMPT('&Emissive (glow) color:',COLOR),%my3DMeshEmissive,DEFAULT(00000000H)
    #ENDBUTTON
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#! Capture THIS instance's BUTTON field equate (auto-uniqued by AppGen on drop)
#ATSTART
  #DECLARE(%my3DButtonFeq)
  #FOR(%Control),WHERE(%ControlInstance=%ActiveTemplateInstance)
    #SET(%my3DButtonFeq,%Control)
  #ENDFOR
#ENDAT
#!
#! Self-contained: pull in the class globally (ONCE = safe alongside my3DGlobal
#! or another viewer on the same window).
#AT(%CustomGlobalDeclarations),WHERE(%my3DDisable=0)
INCLUDE('WebGL2Class.INC'),ONCE
#ENDAT
#!
#AT(%DataSection),WHERE(%my3DDisable=0)
%my3DObject          WebGL2Class                             ! one 3D scene object for this viewer
#ENDAT
#!
#! Build the scene once (OpenWindow) and show it on the button press. PRIORITY(2000)
#! sits above the framework's own TakeWindowEvent scaffolding (registered at 2500).
#AT(%WindowManagerMethodCodeSection,'TakeWindowEvent','(),BYTE'),PRIORITY(2000),WHERE(%my3DDisable=0)
  CASE EVENT()
  OF EVENT:OpenWindow
    %my3DObject.Reset()
    %my3DObject.SetTitle('%my3DTitle')
    %my3DObject.SetCanvas(%my3DW, %my3DH)
    %my3DObject.SetAntialias(%my3DAA)
    %my3DObject.SetBackgroundGradientCl(%my3DBgTop, %my3DBgBot)
    %my3DObject.SetCamera(%my3DCamX, %my3DCamY, %my3DCamZ)
    %my3DObject.LookAt(%my3DTgtX, %my3DTgtY, %my3DTgtZ)
    %my3DObject.SetFOV(%my3DFov)
    %my3DObject.OrbitCamera(%my3DOrbit, %my3DOrbitSpeed)
    %my3DObject.SetAmbientCl(%my3DAmb)
    %my3DObject.SetDirLightCl(%my3DDirX, %my3DDirY, %my3DDirZ, %my3DDirColor, %my3DDirInt)
#FOR(%my3DPL)
    %my3DObject.AddPointLightCl(%my3DPLx, %my3DPLy, %my3DPLz, %my3DPLColor, %my3DPLInt, %my3DPLRange)
#ENDFOR
    %my3DObject.ShowGridCl(%my3DGridOn, %my3DGridSize, %my3DGridDiv, %my3DGridColor)
    %my3DObject.ShowAxes(%my3DAxesOn, %my3DAxesSize)
    %my3DObject.SetFogCl(%my3DFogOn, %my3DFogColor, %my3DFogNear, %my3DFogFar)
    %my3DObject.SetWireframe(%my3DWire)
#FOR(%my3DMesh)
#CASE(%my3DMeshType)
#OF('car')
    %my3DObject.AddCar(%my3DMeshX, %my3DMeshY, %my3DMeshZ, %my3DMeshScale)
#OF('airplane')
    %my3DObject.AddAirplane(%my3DMeshX, %my3DMeshY, %my3DMeshZ, %my3DMeshScale)
#OF('rocket')
    %my3DObject.AddRocket(%my3DMeshX, %my3DMeshY, %my3DMeshZ, %my3DMeshScale)
#OF('turbine')
    %my3DObject.AddWindTurbine(%my3DMeshX, %my3DMeshY, %my3DMeshZ, %my3DMeshScale)
#OF('robot')
    %my3DObject.AddRobot(%my3DMeshX, %my3DMeshY, %my3DMeshZ, %my3DMeshScale)
#OF('table')
    %my3DObject.AddTableSet(%my3DMeshX, %my3DMeshY, %my3DMeshZ, %my3DMeshScale)
#OF('house')
    %my3DObject.AddHouse(%my3DMeshX, %my3DMeshY, %my3DMeshZ, %my3DMeshScale)
#OF('foundation')
    %my3DObject.AddFoundation(%my3DMeshX, %my3DMeshY, %my3DMeshZ, %my3DMeshScale)
#OF('skyscraper')
    %my3DObject.AddSkyscraper(%my3DMeshX, %my3DMeshY, %my3DMeshZ, %my3DMeshScale)
#OF('trees')
    %my3DObject.AddTrees(%my3DMeshX, %my3DMeshY, %my3DMeshZ, %my3DMeshScale)
#ELSE
    %my3DObject.SetColorCl(%my3DMeshColor)
    %my3DObject.SetEmissiveCl(%my3DMeshEmissive)
    %my3DObject.SetMaterial(%my3DMeshMetal, %my3DMeshRough)
    %my3DObject.SetSpin(0, %my3DMeshSpin, 0)
    %my3DObject.SetUniformScale(%my3DObject.AddMesh('%my3DMeshType', %my3DMeshP1, %my3DMeshP2, %my3DMeshP3, %my3DMeshP4, 0, 0), %my3DMeshScale)
    %my3DObject.SetPos(%my3DObject.MeshCount(), %my3DMeshX, %my3DMeshY, %my3DMeshZ)
#ENDCASE
#ENDFOR
#IF(%my3DAutoOpen)
#IF(%my3DDisplayMode = '1')
#IF(%my3DDockCtrl)
    %my3DObject.SetEmbedControl(%my3DDockCtrl)           ! confine the view to this control
#ENDIF
    %my3DObject.ShowEmbedded(0{PROP:Handle})              ! dock the 3D into this window
#ELSE
    %my3DObject.Show()                                    ! open in the default browser
#ENDIF
#ENDIF
  OF EVENT:Accepted
    IF FIELD() = %my3DButtonFeq
#IF(%my3DDisplayMode = '1')
#IF(%my3DDockCtrl)
      %my3DObject.SetEmbedControl(%my3DDockCtrl)
#ENDIF
      %my3DObject.ShowEmbedded(0{PROP:Handle})
#ELSE
      %my3DObject.Show()
#ENDIF
    END
#IF(%my3DDisplayMode = '1')
  OF EVENT:Sized
    %my3DObject.EmbedFit()                                ! the overlay follows the window's size
  OF EVENT:Moved
    %my3DObject.EmbedFit()                                ! ...and its position
  OF EVENT:CloseWindow
    %my3DObject.EmbedClose()                              ! close the docked Edge window with this one
#ENDIF
  END
#ENDAT
#!-----------------------------------------------------------------------------
#! End of my3D template set
#!-----------------------------------------------------------------------------
