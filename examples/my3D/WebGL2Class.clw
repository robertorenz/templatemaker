! ============================================================================
!  WebGL2Class - implementation.  Builds a self-contained WebGL2 .html page
!  (scene data + the my3D engine) and opens it in the default browser.
!  Pure Clarion: ASCII-driver file IO + RUN(rundll32 FileProtocolHandler).
!  Store this file in ANSI (not UTF-8).
! ============================================================================
  MEMBER

  MAP                                                        ! Win32 used to dock a borderless Edge window
    MODULE('Win32')                                          ! (all user32/kernel32 - linked by every Clarion app)
      wgFindWindowEx (ULONG,ULONG,*CSTRING,*CSTRING),ULONG,PASCAL,RAW,NAME('FindWindowExA')
      wgSetParent    (ULONG,ULONG),ULONG,PASCAL,NAME('SetParent')
      wgSetWindowLong(ULONG,SIGNED,LONG),LONG,PASCAL,NAME('SetWindowLongA')
      wgMoveWindow   (ULONG,SIGNED,SIGNED,SIGNED,SIGNED,SIGNED),SIGNED,PASCAL,NAME('MoveWindow')
      wgGetClientRect(ULONG,*LONG),SIGNED,PASCAL,RAW,NAME('GetClientRect')
      wgIsWindow     (ULONG),SIGNED,PASCAL,NAME('IsWindow')
      wgGetActiveWin (),ULONG,PASCAL,NAME('GetActiveWindow')
      wgGetForeWin   (),ULONG,PASCAL,NAME('GetForegroundWindow')
      wgPostMessage  (ULONG,ULONG,ULONG,LONG),SIGNED,PASCAL,NAME('PostMessageA')
      wgSleep        (ULONG),PASCAL,NAME('Sleep')
      wgCreateWindow (ULONG,*CSTRING,*CSTRING,ULONG,SIGNED,SIGNED,SIGNED,SIGNED,ULONG,ULONG,ULONG,ULONG),ULONG,PASCAL,RAW,NAME('CreateWindowExA')
      wgGetModule    (ULONG),ULONG,PASCAL,NAME('GetModuleHandleA')
      wgDestroyWindow(ULONG),SIGNED,PASCAL,NAME('DestroyWindow')
      wgClientToScreen(ULONG,*LONG),SIGNED,PASCAL,RAW,NAME('ClientToScreen')
      wgSetWindowRgn (ULONG,ULONG,SIGNED),SIGNED,PASCAL,NAME('SetWindowRgn')
      wgCreateRectRgn(SIGNED,SIGNED,SIGNED,SIGNED),ULONG,PASCAL,NAME('CreateRectRgn')
      wgSetForeground(ULONG),SIGNED,PASCAL,NAME('SetForegroundWindow')
      wgSetWindowPos (ULONG,ULONG,SIGNED,SIGNED,SIGNED,SIGNED,ULONG),SIGNED,PASCAL,NAME('SetWindowPos')
      wgGetWinPid    (ULONG,*ULONG),ULONG,PASCAL,RAW,NAME('GetWindowThreadProcessId')
    END
    MODULE('kernel32')                                      ! launch taskkill HIDDEN to tear down the whole Edge tree
      wgCreateProcess(LONG,*CSTRING,LONG,LONG,LONG,ULONG,LONG,LONG,LONG,LONG),LONG,PASCAL,PROC,NAME('CreateProcessA')
      wgCloseHandle  (LONG),LONG,PASCAL,PROC,NAME('CloseHandle')  ! wg-prefixed Clarion label so it can't clash with ABC's CloseHandle
    END
  END

  INCLUDE('WebGL2Class.INC'),ONCE

WebGL2:PI         EQUATE(3.14159265358979)
WG2:GWL_STYLE     EQUATE(-16)                                ! Win32 constants for the docked-Edge embed
WG2:WS_CHILD      EQUATE(40000000h)
WG2:WS_VISIBLE    EQUATE(10000000h)
WG2:WS_CLIPCH     EQUATE(02000000h)                          ! WS_CLIPCHILDREN
WG2:GWL_HWNDPARENT EQUATE(-8)                                ! SetWindowLong index for a window's owner
WG2:WS_POPUP      EQUATE(80000000h)                          ! a fixed, frameless, non-resizable popup
WG2:SWP_FRAME     EQUATE(0027h)                              ! SWP_NOMOVE+NOSIZE+NOZORDER+FRAMECHANGED
WG2:WM_CLOSE      EQUATE(0010h)
WG2:STARTF_USESHOWWINDOW EQUATE(00000001h)                  ! honour wShowWindow in STARTUPINFO
WG2:SW_HIDE       EQUATE(0)                                  ! no window for the taskkill helper
WG2:CREATE_NO_WINDOW EQUATE(08000000h)                      ! no console window for the (console) taskkill

! --- module-scope ASCII files (THREAD'd) used for streaming text IO ---------
OutF FILE,DRIVER('ASCII'),NAME(''),PRE(OutF),CREATE,THREAD
Rec    RECORD
Line     STRING(902)                                         ! ASCII driver trims trailing blanks -> variable-length lines
       END
     END

EngF FILE,DRIVER('ASCII'),NAME(''),PRE(EngF),THREAD
Rec    RECORD
Line     STRING(902)
       END
     END

!=== lifecycle ==============================================================
WebGL2Class.Construct PROCEDURE()
  CODE
  SELF.EngineFile = 'my3D.engine.js'
  SELF.EmbedInset = 33                                       ! px to hide Edge's app title bar when docked
  SELF.EdgeExe = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
  IF ~EXISTS(SELF.EdgeExe)
    SELF.EdgeExe = 'C:\Program Files\Microsoft\Edge\Application\msedge.exe'
  END
  SELF.Reset()

WebGL2Class.Destruct PROCEDURE()
  CODE
  SELF.EmbedClose()                                          ! never leak an msedge.exe, even if EVENT:CloseWindow was missed or the app died abnormally

WebGL2Class.Reset PROCEDURE()
  CODE
  SELF.Title = 'my3D / WebGL2'
  SELF.CanvasW = 1000; SELF.CanvasH = 640; SELF.Antialias = 1
  SELF.ShowHud = 1; SELF.ShowFps = 1
  SELF.BgGradient = 1
  SELF.BgTopR = 0.06; SELF.BgTopG = 0.09; SELF.BgTopB = 0.15
  SELF.BgR = 0.02; SELF.BgG = 0.03; SELF.BgB = 0.06
  SELF.FogOn = 0; SELF.FogR = 0.02; SELF.FogG = 0.03; SELF.FogB = 0.06
  SELF.FogNear = 12; SELF.FogFar = 36
  SELF.CamX = 7; SELF.CamY = 6; SELF.CamZ = 11
  SELF.TgtX = 0; SELF.TgtY = 0.4; SELF.TgtZ = 0
  SELF.Fov = 50; SELF.ClipNear = 0.1; SELF.ClipFar = 300
  SELF.Orbit = 1; SELF.OrbitSpeed = 0.3
  SELF.AmbR = 0.18; SELF.AmbG = 0.20; SELF.AmbB = 0.26
  SELF.DirX = -1; SELF.DirY = -2; SELF.DirZ = -1.3
  SELF.DirR = 1; SELF.DirG = 0.97; SELF.DirB = 0.90; SELF.DirInt = 1.05
  SELF.GridOn = 1; SELF.GridSize = 20; SELF.GridDiv = 20
  SELF.GridR = 0.13; SELF.GridG = 0.16; SELF.GridB = 0.22
  SELF.AxesOn = 1; SELF.AxesSize = 3
  SELF.Wireframe = 0
  SELF.DisplayMode = WebGL2:External
  SELF.ResetMaterial()
  SELF.ClearScene()

WebGL2Class.ClearScene PROCEDURE()
  CODE
  SELF.NMesh = 0
  SELF.NLight = 0

!=== page / canvas / background =============================================
WebGL2Class.SetTitle PROCEDURE(STRING pTitle)
  CODE
  SELF.Title = CLIP(pTitle)

WebGL2Class.SetCanvas PROCEDURE(LONG pW,LONG pH)
  CODE
  IF pW > 0 THEN SELF.CanvasW = pW.
  IF pH > 0 THEN SELF.CanvasH = pH.

WebGL2Class.SetAntialias PROCEDURE(BYTE pOn)
  CODE
  SELF.Antialias = CHOOSE(pOn <> 0, 1, 0)

WebGL2Class.SetHud PROCEDURE(BYTE pOn)
  CODE
  SELF.ShowHud = CHOOSE(pOn <> 0, 1, 0)

WebGL2Class.SetFps PROCEDURE(BYTE pOn)
  CODE
  SELF.ShowFps = CHOOSE(pOn <> 0, 1, 0)

WebGL2Class.SetBackground PROCEDURE(REAL pR,REAL pG,REAL pB)
  CODE
  SELF.BgGradient = 0
  SELF.BgR = pR; SELF.BgG = pG; SELF.BgB = pB

WebGL2Class.SetBackgroundGradient PROCEDURE(REAL pTopR,REAL pTopG,REAL pTopB,REAL pBotR,REAL pBotG,REAL pBotB)
  CODE
  SELF.BgGradient = 1
  SELF.BgTopR = pTopR; SELF.BgTopG = pTopG; SELF.BgTopB = pTopB
  SELF.BgR = pBotR;    SELF.BgG = pBotG;    SELF.BgB = pBotB

WebGL2Class.SetFog PROCEDURE(BYTE pOn,REAL pR,REAL pG,REAL pB,REAL pNear,REAL pFar)
  CODE
  SELF.FogOn = CHOOSE(pOn <> 0, 1, 0)
  SELF.FogR = pR; SELF.FogG = pG; SELF.FogB = pB
  SELF.FogNear = pNear; SELF.FogFar = pFar

WebGL2Class.SetSolidBackgroundCl PROCEDURE(LONG pClarionColor)
r REAL
g REAL
b REAL
  CODE
  SELF.ClToRGB(pClarionColor, r, g, b)
  SELF.SetBackground(r, g, b)

WebGL2Class.SetBackgroundGradientCl PROCEDURE(LONG pTopColor,LONG pBotColor)
tr REAL
tg REAL
tb REAL
br REAL
bg REAL
bb REAL
  CODE
  SELF.ClToRGB(pTopColor, tr, tg, tb)
  SELF.ClToRGB(pBotColor, br, bg, bb)
  SELF.SetBackgroundGradient(tr, tg, tb, br, bg, bb)

WebGL2Class.SetFogCl PROCEDURE(BYTE pOn,LONG pClarionColor,REAL pNear,REAL pFar)
r REAL
g REAL
b REAL
  CODE
  SELF.ClToRGB(pClarionColor, r, g, b)
  SELF.SetFog(pOn, r, g, b, pNear, pFar)

!=== camera =================================================================
WebGL2Class.SetCamera PROCEDURE(REAL pX,REAL pY,REAL pZ)
  CODE
  SELF.CamX = pX; SELF.CamY = pY; SELF.CamZ = pZ

WebGL2Class.LookAt PROCEDURE(REAL pX,REAL pY,REAL pZ)
  CODE
  SELF.TgtX = pX; SELF.TgtY = pY; SELF.TgtZ = pZ

WebGL2Class.SetFOV PROCEDURE(REAL pDeg)
  CODE
  IF pDeg > 1 AND pDeg < 179 THEN SELF.Fov = pDeg.

WebGL2Class.SetClip PROCEDURE(REAL pNear,REAL pFar)
  CODE
  IF pNear > 0 THEN SELF.ClipNear = pNear.
  IF pFar > pNear THEN SELF.ClipFar = pFar.

WebGL2Class.OrbitCamera PROCEDURE(BYTE pOn,REAL pSpeed)
  CODE
  SELF.Orbit = CHOOSE(pOn <> 0, 1, 0)
  SELF.OrbitSpeed = pSpeed

!=== lighting ===============================================================
WebGL2Class.SetAmbient PROCEDURE(REAL pR,REAL pG,REAL pB)
  CODE
  SELF.AmbR = pR; SELF.AmbG = pG; SELF.AmbB = pB

WebGL2Class.SetDirLight PROCEDURE(REAL pDX,REAL pDY,REAL pDZ,REAL pR,REAL pG,REAL pB,REAL pIntensity)
  CODE
  SELF.DirX = pDX; SELF.DirY = pDY; SELF.DirZ = pDZ
  SELF.DirR = pR; SELF.DirG = pG; SELF.DirB = pB; SELF.DirInt = pIntensity

WebGL2Class.AddPointLight PROCEDURE(REAL pX,REAL pY,REAL pZ,REAL pR,REAL pG,REAL pB,REAL pIntensity,REAL pRange)
  CODE
  IF SELF.NLight >= WebGL2:MaxLight THEN RETURN 0.
  SELF.NLight += 1
  SELF.PLPosX[SELF.NLight] = pX; SELF.PLPosY[SELF.NLight] = pY; SELF.PLPosZ[SELF.NLight] = pZ
  SELF.PLColR[SELF.NLight] = pR; SELF.PLColG[SELF.NLight] = pG; SELF.PLColB[SELF.NLight] = pB
  SELF.PLInt[SELF.NLight] = pIntensity; SELF.PLRange[SELF.NLight] = pRange
  RETURN SELF.NLight

WebGL2Class.SetAmbientCl PROCEDURE(LONG pClarionColor)
r REAL
g REAL
b REAL
  CODE
  SELF.ClToRGB(pClarionColor, r, g, b)
  SELF.SetAmbient(r, g, b)

WebGL2Class.SetDirLightCl PROCEDURE(REAL pDX,REAL pDY,REAL pDZ,LONG pClarionColor,REAL pIntensity)
r REAL
g REAL
b REAL
  CODE
  SELF.ClToRGB(pClarionColor, r, g, b)
  SELF.SetDirLight(pDX, pDY, pDZ, r, g, b, pIntensity)

WebGL2Class.AddPointLightCl PROCEDURE(REAL pX,REAL pY,REAL pZ,LONG pClarionColor,REAL pIntensity,REAL pRange)
r REAL
g REAL
b REAL
  CODE
  SELF.ClToRGB(pClarionColor, r, g, b)
  RETURN SELF.AddPointLight(pX, pY, pZ, r, g, b, pIntensity, pRange)

WebGL2Class.ClearLights PROCEDURE()
  CODE
  SELF.NLight = 0

!=== helpers / scene chrome =================================================
WebGL2Class.ShowGrid PROCEDURE(BYTE pOn,REAL pSize,LONG pDiv,REAL pR,REAL pG,REAL pB)
  CODE
  SELF.GridOn = CHOOSE(pOn <> 0, 1, 0)
  IF pSize > 0 THEN SELF.GridSize = pSize.
  IF pDiv > 0 THEN SELF.GridDiv = pDiv.
  SELF.GridR = pR; SELF.GridG = pG; SELF.GridB = pB

WebGL2Class.ShowGridCl PROCEDURE(BYTE pOn,REAL pSize,LONG pDiv,LONG pClarionColor)
r REAL
g REAL
b REAL
  CODE
  SELF.ClToRGB(pClarionColor, r, g, b)
  SELF.ShowGrid(pOn, pSize, pDiv, r, g, b)

WebGL2Class.ShowAxes PROCEDURE(BYTE pOn,REAL pSize)
  CODE
  SELF.AxesOn = CHOOSE(pOn <> 0, 1, 0)
  IF pSize > 0 THEN SELF.AxesSize = pSize.

WebGL2Class.SetWireframe PROCEDURE(BYTE pOn)
  CODE
  SELF.Wireframe = CHOOSE(pOn <> 0, 1, 0)

!=== current-material state =================================================
WebGL2Class.SetColor PROCEDURE(REAL pR,REAL pG,REAL pB)
  CODE
  SELF.CurR = pR; SELF.CurG = pG; SELF.CurB = pB

WebGL2Class.SetColorCl PROCEDURE(LONG pClarionColor)
c  LONG
  CODE
  c = pClarionColor                                          ! Clarion color = 0x00BBGGRR
  SELF.CurR = BAND(c, 0FFh) / 255.0
  SELF.CurG = BAND(BSHIFT(c, -8), 0FFh) / 255.0
  SELF.CurB = BAND(BSHIFT(c, -16), 0FFh) / 255.0

WebGL2Class.SetEmissiveCl PROCEDURE(LONG pClarionColor)
r REAL
g REAL
b REAL
  CODE
  SELF.ClToRGB(pClarionColor, r, g, b)
  SELF.SetEmissive(r, g, b)

WebGL2Class.SetMaterial PROCEDURE(REAL pMetalness,REAL pRoughness)
  CODE
  SELF.CurMetal = pMetalness; SELF.CurRough = pRoughness

WebGL2Class.SetOpacity PROCEDURE(REAL pOpacity)
  CODE
  SELF.CurOpacity = pOpacity

WebGL2Class.SetEmissive PROCEDURE(REAL pR,REAL pG,REAL pB)
  CODE
  SELF.CurEmiR = pR; SELF.CurEmiG = pG; SELF.CurEmiB = pB

WebGL2Class.SetSpin PROCEDURE(REAL pSX,REAL pSY,REAL pSZ)
  CODE
  SELF.CurSpinX = pSX; SELF.CurSpinY = pSY; SELF.CurSpinZ = pSZ

WebGL2Class.ResetMaterial PROCEDURE()
  CODE
  SELF.CurR = 0.80; SELF.CurG = 0.82; SELF.CurB = 0.86
  SELF.CurMetal = 0.15; SELF.CurRough = 0.55; SELF.CurOpacity = 1
  SELF.CurEmiR = 0; SELF.CurEmiG = 0; SELF.CurEmiB = 0
  SELF.CurSpinX = 0; SELF.CurSpinY = 0; SELF.CurSpinZ = 0

!=== mesh adders ============================================================
WebGL2Class.AddMesh PROCEDURE(STRING pType,REAL pP1,REAL pP2,REAL pP3,REAL pP4,REAL pP5,REAL pP6)
i  LONG
  CODE
  IF SELF.NMesh >= WebGL2:MaxMesh THEN RETURN 0.
  SELF.NMesh += 1; i = SELF.NMesh
  SELF.MType[i] = LOWER(CLIP(pType))
  SELF.MP1[i] = pP1; SELF.MP2[i] = pP2; SELF.MP3[i] = pP3
  SELF.MP4[i] = pP4; SELF.MP5[i] = pP5; SELF.MP6[i] = pP6
  SELF.MPosX[i] = 0; SELF.MPosY[i] = 0; SELF.MPosZ[i] = 0
  SELF.MRotX[i] = 0; SELF.MRotY[i] = 0; SELF.MRotZ[i] = 0
  SELF.MSclX[i] = 1; SELF.MSclY[i] = 1; SELF.MSclZ[i] = 1
  SELF.MColR[i] = SELF.CurR; SELF.MColG[i] = SELF.CurG; SELF.MColB[i] = SELF.CurB
  SELF.MMetal[i] = SELF.CurMetal; SELF.MRough[i] = SELF.CurRough; SELF.MOpacity[i] = SELF.CurOpacity
  SELF.MEmiR[i] = SELF.CurEmiR; SELF.MEmiG[i] = SELF.CurEmiG; SELF.MEmiB[i] = SELF.CurEmiB
  SELF.MSpinX[i] = SELF.CurSpinX; SELF.MSpinY[i] = SELF.CurSpinY; SELF.MSpinZ[i] = SELF.CurSpinZ
  SELF.MWire[i] = SELF.Wireframe
  RETURN i

WebGL2Class.AddBox PROCEDURE(REAL pW,REAL pH,REAL pD)
  CODE
  RETURN SELF.AddMesh('box', pW, pH, pD, 0, 0, 0)

WebGL2Class.AddCube PROCEDURE(REAL pSize)
  CODE
  RETURN SELF.AddMesh('box', pSize, pSize, pSize, 0, 0, 0)

WebGL2Class.AddSphere PROCEDURE(REAL pRadius,LONG pSegments)
  CODE
  RETURN SELF.AddMesh('sphere', pRadius, CHOOSE(pSegments>0,pSegments,24), 0, 0, 0, 0)

WebGL2Class.AddCylinder PROCEDURE(REAL pRTop,REAL pRBot,REAL pHeight,LONG pSeg)
  CODE
  RETURN SELF.AddMesh('cylinder', pRTop, pRBot, pHeight, CHOOSE(pSeg>0,pSeg,32), 0, 0)

WebGL2Class.AddCone PROCEDURE(REAL pRadius,REAL pHeight,LONG pSeg)
  CODE
  RETURN SELF.AddMesh('cone', pRadius, pHeight, CHOOSE(pSeg>0,pSeg,32), 0, 0, 0)

WebGL2Class.AddPlane PROCEDURE(REAL pW,REAL pD)
  CODE
  RETURN SELF.AddMesh('plane', pW, pD, 0, 0, 0, 0)

WebGL2Class.AddTorus PROCEDURE(REAL pR,REAL pTube,LONG pRadSeg,LONG pTubeSeg)
  CODE
  RETURN SELF.AddMesh('torus', pR, pTube, CHOOSE(pRadSeg>0,pRadSeg,24), CHOOSE(pTubeSeg>0,pTubeSeg,16), 0, 0)

WebGL2Class.AddTorusKnot PROCEDURE(REAL pR,REAL pTube,LONG pP,LONG pQ)
  CODE
  RETURN SELF.AddMesh('torusknot', pR, pTube, CHOOSE(pP>0,pP,2), CHOOSE(pQ>0,pQ,3), 0, 0)

WebGL2Class.AddTetra PROCEDURE(REAL pR)
  CODE
  RETURN SELF.AddMesh('tetra', pR, 0, 0, 0, 0, 0)

WebGL2Class.AddOcta PROCEDURE(REAL pR)
  CODE
  RETURN SELF.AddMesh('octa', pR, 0, 0, 0, 0, 0)

WebGL2Class.AddIcosa PROCEDURE(REAL pR)
  CODE
  RETURN SELF.AddMesh('icosa', pR, 0, 0, 0, 0, 0)

WebGL2Class.AddDodeca PROCEDURE(REAL pR)
  CODE
  RETURN SELF.AddMesh('dodeca', pR, 0, 0, 0, 0, 0)

!=== composite models =======================================================
!  Each builds a model from primitives at the origin (scale 1), then PlaceModel
!  offsets + scales those meshes to where the caller wants them. ResetMaterial
!  first so no inherited colour/spin/opacity leaks into the model.
WebGL2Class.PlaceModel PROCEDURE(LONG pStart,REAL pOX,REAL pOY,REAL pOZ,REAL pScale)
i  LONG
  CODE
  LOOP i = pStart TO SELF.NMesh
    SELF.MPosX[i] = pOX + pScale * SELF.MPosX[i]
    SELF.MPosY[i] = pOY + pScale * SELF.MPosY[i]
    SELF.MPosZ[i] = pOZ + pScale * SELF.MPosZ[i]
    SELF.MSclX[i] = SELF.MSclX[i] * pScale
    SELF.MSclY[i] = SELF.MSclY[i] * pScale
    SELF.MSclZ[i] = SELF.MSclZ[i] * pScale
  END

WebGL2Class.AddCar PROCEDURE(REAL pX,REAL pY,REAL pZ,REAL pScale)
start LONG
M     LONG
i     LONG
xx    REAL
zz    REAL
  CODE
  start = SELF.NMesh + 1; SELF.ResetMaterial()
  SELF.SetColor(0.80,0.12,0.12); SELF.SetMaterial(0.5,0.3)
  M=SELF.AddBox(4.2,0.8,1.9);  SELF.SetPos(M,0,0.95,0)
  M=SELF.AddBox(4.4,0.45,1.7); SELF.SetPos(M,0,0.62,0)
  M=SELF.AddBox(2.1,0.8,1.65); SELF.SetPos(M,-0.3,1.65,0)
  SELF.SetColor(0.12,0.16,0.22); SELF.SetMaterial(0.3,0.1); SELF.SetOpacity(0.75)
  M=SELF.AddBox(2.0,0.65,1.55); SELF.SetPos(M,-0.3,1.66,0); SELF.SetOpacity(1)
  SELF.SetColor(0.07,0.07,0.08); SELF.SetMaterial(0.1,0.85)
  LOOP i=0 TO 3
    xx=CHOOSE(i<2,1.35,-1.35); zz=CHOOSE(i%2=0,1.0,-1.0)
    M=SELF.AddCylinder(0.55,0.55,0.4,28); SELF.SetPos(M,xx,0.55,zz); SELF.SetRot(M,1.5708,0,0)
  END
  SELF.SetColor(0.75,0.76,0.80); SELF.SetMaterial(0.85,0.2)
  LOOP i=0 TO 3
    xx=CHOOSE(i<2,1.35,-1.35); zz=CHOOSE(i%2=0,1.0,-1.0)
    M=SELF.AddCylinder(0.22,0.22,0.42,20); SELF.SetPos(M,xx,0.55,zz); SELF.SetRot(M,1.5708,0,0)
  END
  SELF.SetColor(1,0.95,0.7); SELF.SetEmissive(0.9,0.82,0.45)
  M=SELF.AddSphere(0.17,14); SELF.SetPos(M,2.13,0.95,0.6)
  M=SELF.AddSphere(0.17,14); SELF.SetPos(M,2.13,0.95,-0.6)
  SELF.PlaceModel(start, pX, pY, pZ, pScale); RETURN start

WebGL2Class.AddAirplane PROCEDURE(REAL pX,REAL pY,REAL pZ,REAL pScale)
start LONG
M     LONG
  CODE
  start = SELF.NMesh + 1; SELF.ResetMaterial()
  SELF.SetColor(0.85,0.87,0.90); SELF.SetMaterial(0.6,0.3)
  M=SELF.AddCylinder(0.5,0.5,5,24); SELF.SetPos(M,0,2.2,0); SELF.SetRot(M,0,0,1.5708)
  SELF.SetColor(0.80,0.20,0.20)
  M=SELF.AddCone(0.5,1.0,24); SELF.SetPos(M,2.95,2.2,0); SELF.SetRot(M,0,0,-1.5708)
  SELF.SetColor(0.30,0.45,0.85); SELF.SetMaterial(0.4,0.4)
  M=SELF.AddBox(1.5,0.14,5.4); SELF.SetPos(M,0.1,2.1,0)
  M=SELF.AddBox(0.8,0.1,2.2);  SELF.SetPos(M,-2.2,2.2,0)
  SELF.SetColor(0.80,0.20,0.20)
  M=SELF.AddBox(0.7,0.9,0.14); SELF.SetPos(M,-2.2,2.65,0)
  SELF.SetColor(0.12,0.16,0.22); SELF.SetMaterial(0.3,0.1); SELF.SetOpacity(0.8)
  M=SELF.AddSphere(0.42,18); SELF.SetPos(M,1.4,2.5,0); SELF.SetScale(M,1.2,0.7,0.9); SELF.SetOpacity(1)
  SELF.SetColor(0.2,0.2,0.22); SELF.SetMaterial(0.5,0.4)
  M=SELF.AddCylinder(0.26,0.26,1.2,16); SELF.SetPos(M,0.3,1.75,1.7);  SELF.SetRot(M,0,0,1.5708)
  M=SELF.AddCylinder(0.26,0.26,1.2,16); SELF.SetPos(M,0.3,1.75,-1.7); SELF.SetRot(M,0,0,1.5708)
  SELF.PlaceModel(start, pX, pY, pZ, pScale); RETURN start

WebGL2Class.AddRocket PROCEDURE(REAL pX,REAL pY,REAL pZ,REAL pScale)
start LONG
M     LONG
i     LONG
a     REAL
  CODE
  start = SELF.NMesh + 1; SELF.ResetMaterial()
  SELF.SetColor(0.92,0.92,0.95); SELF.SetMaterial(0.5,0.3)
  M=SELF.AddCylinder(0.7,0.7,4.5,28); SELF.SetPos(M,0,3.0,0)
  SELF.SetColor(0.85,0.20,0.20)
  M=SELF.AddCone(0.7,1.6,28); SELF.SetPos(M,0,6.05,0)
  SELF.SetColor(0.30,0.55,0.85); SELF.SetEmissive(0.15,0.3,0.5)
  M=SELF.AddSphere(0.28,18); SELF.SetPos(M,0,4.3,0.62); SELF.SetEmissive(0,0,0)
  SELF.SetColor(0.85,0.20,0.20); SELF.SetMaterial(0.4,0.4)
  LOOP i=0 TO 3
    a=i*1.5708
    M=SELF.AddBox(0.12,1.2,0.9); SELF.SetPos(M,0.7*SIN(a),1.2,0.7*COS(a)); SELF.SetRot(M,0,a,0)
  END
  SELF.SetColor(1.0,0.6,0.1); SELF.SetEmissive(1.0,0.45,0.05)
  M=SELF.AddCone(0.55,1.4,20); SELF.SetPos(M,0,0.2,0); SELF.SetRot(M,3.14159,0,0)
  SELF.PlaceModel(start, pX, pY, pZ, pScale); RETURN start

WebGL2Class.AddWindTurbine PROCEDURE(REAL pX,REAL pY,REAL pZ,REAL pScale)
start LONG
M     LONG
i     LONG
a     REAL
  CODE
  start = SELF.NMesh + 1; SELF.ResetMaterial()
  SELF.SetColor(0.90,0.92,0.95); SELF.SetMaterial(0.3,0.4)
  M=SELF.AddCylinder(0.18,0.40,6.5,28); SELF.SetPos(M,0,3.25,0)
  M=SELF.AddBox(1.4,0.6,0.7); SELF.SetPos(M,0,6.6,0.1)
  SELF.SetColor(0.85,0.87,0.9)
  M=SELF.AddSphere(0.3,18); SELF.SetPos(M,0,6.6,0.55)
  SELF.SetColor(0.95,0.96,0.98); SELF.SetMaterial(0.2,0.5)
  LOOP i=0 TO 2
    a=i*2.0944
    M=SELF.AddBox(0.18,3.4,0.55); SELF.SetPos(M,-1.7*SIN(a),6.6+1.7*COS(a),0.6); SELF.SetRot(M,0,0,a)
  END
  SELF.PlaceModel(start, pX, pY, pZ, pScale); RETURN start

WebGL2Class.AddRobot PROCEDURE(REAL pX,REAL pY,REAL pZ,REAL pScale)
start LONG
M     LONG
  CODE
  start = SELF.NMesh + 1; SELF.ResetMaterial()
  SELF.SetColor(0.45,0.48,0.52); SELF.SetMaterial(0.7,0.3)
  M=SELF.AddCylinder(0.22,0.22,1.4,16); SELF.SetPos(M,-0.45,0.7,0)
  M=SELF.AddCylinder(0.22,0.22,1.4,16); SELF.SetPos(M,0.45,0.7,0)
  SELF.SetColor(0.25,0.27,0.30); SELF.SetMaterial(0.4,0.5)
  M=SELF.AddBox(0.5,0.25,0.8); SELF.SetPos(M,-0.45,0.12,0.1)
  M=SELF.AddBox(0.5,0.25,0.8); SELF.SetPos(M,0.45,0.12,0.1)
  SELF.SetColor(0.25,0.45,0.75); SELF.SetMaterial(0.6,0.3)
  M=SELF.AddBox(1.6,1.8,0.9); SELF.SetPos(M,0,2.3,0)
  SELF.SetColor(0.3,0.9,0.5); SELF.SetEmissive(0.2,0.7,0.35)
  M=SELF.AddSphere(0.18,16); SELF.SetPos(M,0,2.5,0.5); SELF.SetEmissive(0,0,0)
  SELF.SetColor(0.45,0.48,0.52); SELF.SetMaterial(0.7,0.3)
  M=SELF.AddCylinder(0.18,0.18,1.6,16); SELF.SetPos(M,-1.0,2.3,0)
  M=SELF.AddCylinder(0.18,0.18,1.6,16); SELF.SetPos(M,1.0,2.3,0)
  SELF.SetColor(0.85,0.7,0.2); SELF.SetMaterial(0.5,0.4)
  M=SELF.AddSphere(0.22,16); SELF.SetPos(M,-1.0,1.45,0)
  M=SELF.AddSphere(0.22,16); SELF.SetPos(M,1.0,1.45,0)
  SELF.SetColor(0.55,0.58,0.62); SELF.SetMaterial(0.7,0.3)
  M=SELF.AddBox(0.9,0.8,0.8); SELF.SetPos(M,0,3.6,0)
  SELF.SetColor(0.9,0.95,1.0); SELF.SetEmissive(0.6,0.7,0.9)
  M=SELF.AddSphere(0.12,14); SELF.SetPos(M,-0.22,3.65,0.42)
  M=SELF.AddSphere(0.12,14); SELF.SetPos(M,0.22,3.65,0.42); SELF.SetEmissive(0,0,0)
  SELF.SetColor(0.5,0.5,0.55); SELF.SetMaterial(0.6,0.3)
  M=SELF.AddCylinder(0.04,0.04,0.5,8); SELF.SetPos(M,0,4.25,0)
  SELF.SetColor(0.9,0.2,0.2); SELF.SetEmissive(0.7,0.1,0.1)
  M=SELF.AddSphere(0.1,12); SELF.SetPos(M,0,4.55,0); SELF.SetEmissive(0,0,0)
  SELF.PlaceModel(start, pX, pY, pZ, pScale); RETURN start

WebGL2Class.AddTableSet PROCEDURE(REAL pX,REAL pY,REAL pZ,REAL pScale)
start LONG
M     LONG
i     LONG
xx    REAL
zz    REAL
a     REAL
  CODE
  start = SELF.NMesh + 1; SELF.ResetMaterial()
  SELF.SetColor(0.55,0.36,0.20); SELF.SetMaterial(0.2,0.5)
  M=SELF.AddBox(3.0,0.16,1.6); SELF.SetPos(M,0,1.5,0)
  SELF.SetColor(0.40,0.26,0.14)
  LOOP i=0 TO 3
    xx=CHOOSE(i<2,-1.35,1.35); zz=CHOOSE(i%2=0,-0.65,0.65)
    M=SELF.AddCylinder(0.09,0.09,1.5,10); SELF.SetPos(M,xx,0.75,zz)
  END
  LOOP i=0 TO 3
    a=i*1.5708; xx=2.3*SIN(a); zz=2.3*COS(a)
    SELF.SetColor(0.45,0.30,0.18); SELF.SetMaterial(0.2,0.6)
    M=SELF.AddBox(0.9,0.12,0.9); SELF.SetPos(M,xx,0.9,zz)
    M=SELF.AddBox(0.9,0.9,0.12); SELF.SetPos(M,xx+0.39*SIN(a),1.35,zz+0.39*COS(a)); SELF.SetRot(M,0,a,0)
    M=SELF.AddCylinder(0.07,0.07,0.9,8); SELF.SetPos(M,xx,0.45,zz)
  END
  SELF.PlaceModel(start, pX, pY, pZ, pScale); RETURN start

WebGL2Class.AddHouse PROCEDURE(REAL pX,REAL pY,REAL pZ,REAL pScale)
start LONG
M     LONG
  CODE
  start = SELF.NMesh + 1; SELF.ResetMaterial()
  SELF.SetColor(0.90,0.85,0.72); SELF.SetMaterial(0.1,0.7)
  M=SELF.AddBox(5,2.6,4); SELF.SetPos(M,0,1.3,0)
  SELF.SetColor(0.55,0.18,0.14); SELF.SetMaterial(0.1,0.6)
  M=SELF.AddCone(3.6,1.8,4); SELF.SetPos(M,0,3.5,0); SELF.SetRot(M,0,0.7854,0)
  SELF.SetColor(0.45,0.28,0.15)
  M=SELF.AddBox(0.9,1.6,0.12); SELF.SetPos(M,0,0.8,2.02)
  SELF.SetColor(0.55,0.75,0.95); SELF.SetEmissive(0.25,0.40,0.55); SELF.SetMaterial(0.3,0.2)
  M=SELF.AddBox(0.9,0.9,0.12);  SELF.SetPos(M,-1.6,1.5,2.02)
  M=SELF.AddBox(0.9,0.9,0.12);  SELF.SetPos(M,1.6,1.5,2.02)
  M=SELF.AddBox(0.12,0.9,0.9);  SELF.SetPos(M,-2.52,1.5,0)
  M=SELF.AddBox(0.12,0.9,0.9);  SELF.SetPos(M,2.52,1.5,0)
  SELF.SetEmissive(0,0,0)
  SELF.SetColor(0.5,0.4,0.35); SELF.SetMaterial(0.1,0.8)
  M=SELF.AddBox(0.5,1.4,0.5); SELF.SetPos(M,1.4,3.6,-0.6)
  SELF.PlaceModel(start, pX, pY, pZ, pScale); RETURN start

WebGL2Class.AddFoundation PROCEDURE(REAL pX,REAL pY,REAL pZ,REAL pScale)
start LONG
M     LONG
i     LONG
j     LONG
xx    REAL
zz    REAL
  CODE
  start = SELF.NMesh + 1; SELF.ResetMaterial()
  SELF.SetColor(0.62,0.62,0.64); SELF.SetMaterial(0.05,0.85)
  M=SELF.AddBox(10,0.3,8); SELF.SetPos(M,0,0.15,0)
  SELF.SetColor(0.55,0.55,0.57)
  M=SELF.AddBox(10,1.0,0.4); SELF.SetPos(M,0,0.7,3.8)
  M=SELF.AddBox(10,1.0,0.4); SELF.SetPos(M,0,0.7,-3.8)
  M=SELF.AddBox(0.4,1.0,7.2); SELF.SetPos(M,4.8,0.7,0)
  M=SELF.AddBox(0.4,1.0,7.2); SELF.SetPos(M,-4.8,0.7,0)
  LOOP i=0 TO 2
    LOOP j=0 TO 2
      xx=(i-1)*4.0; zz=(j-1)*3.0
      SELF.SetColor(0.58,0.58,0.60); SELF.SetMaterial(0.05,0.85)
      M=SELF.AddBox(1.0,0.5,1.0); SELF.SetPos(M,xx,0.25,zz)
      SELF.SetColor(0.70,0.30,0.12); SELF.SetMaterial(0.5,0.5)
      M=SELF.AddCylinder(0.06,0.06,1.8,8); SELF.SetPos(M,xx,1.2,zz)
    END
  END
  SELF.PlaceModel(start, pX, pY, pZ, pScale); RETURN start

WebGL2Class.AddSkyscraper PROCEDURE(REAL pX,REAL pY,REAL pZ,REAL pScale)
start LONG
M     LONG
i     LONG
a     REAL
  CODE
  start = SELF.NMesh + 1; SELF.ResetMaterial()
  SELF.SetMaterial(0.6,0.25)
  LOOP i=0 TO 16
    a=3.0-i*0.14
    SELF.SetColor(0.35-i*0.01,0.55,0.75)
    M=SELF.AddBox(a,0.8,a); SELF.SetPos(M,0,0.4+i*0.8,0)
  END
  SELF.SetColor(0.8,0.8,0.82); SELF.SetMaterial(0.7,0.3)
  M=SELF.AddCylinder(0.05,0.05,2,8); SELF.SetPos(M,0,14.0,0)
  SELF.PlaceModel(start, pX, pY, pZ, pScale); RETURN start

WebGL2Class.AddTrees PROCEDURE(REAL pX,REAL pY,REAL pZ,REAL pScale)
start LONG
M     LONG
i     LONG
xx    REAL
  CODE
  start = SELF.NMesh + 1; SELF.ResetMaterial()
  LOOP i=0 TO 4
    xx=(i-2)*3.0
    SELF.SetColor(0.42,0.28,0.15); SELF.SetMaterial(0.1,0.8)
    M=SELF.AddCylinder(0.22,0.30,1.4,12); SELF.SetPos(M,xx,0.7,0)
    IF i%2 = 0
      SELF.SetColor(0.16,0.45,0.22); SELF.SetMaterial(0,0.7)
      M=SELF.AddCone(1.1,1.4,16); SELF.SetPos(M,xx,1.9,0)
      M=SELF.AddCone(0.9,1.2,16); SELF.SetPos(M,xx,2.6,0)
      M=SELF.AddCone(0.7,1.0,16); SELF.SetPos(M,xx,3.3,0)
    ELSE
      SELF.SetColor(0.22,0.55,0.25); SELF.SetMaterial(0,0.7)
      M=SELF.AddSphere(1.0,18); SELF.SetPos(M,xx,2.3,0)
      M=SELF.AddSphere(0.8,18); SELF.SetPos(M,xx-0.5,2.0,0.4)
      M=SELF.AddSphere(0.8,18); SELF.SetPos(M,xx+0.5,2.1,-0.3)
    END
  END
  SELF.PlaceModel(start, pX, pY, pZ, pScale); RETURN start

!=== per-mesh transforms ====================================================
WebGL2Class.SetPos PROCEDURE(LONG pIdx,REAL pX,REAL pY,REAL pZ)
  CODE
  IF pIdx < 1 OR pIdx > SELF.NMesh THEN RETURN.
  SELF.MPosX[pIdx] = pX; SELF.MPosY[pIdx] = pY; SELF.MPosZ[pIdx] = pZ

WebGL2Class.SetRot PROCEDURE(LONG pIdx,REAL pX,REAL pY,REAL pZ)
  CODE
  IF pIdx < 1 OR pIdx > SELF.NMesh THEN RETURN.
  SELF.MRotX[pIdx] = pX; SELF.MRotY[pIdx] = pY; SELF.MRotZ[pIdx] = pZ

WebGL2Class.SetScale PROCEDURE(LONG pIdx,REAL pSX,REAL pSY,REAL pSZ)
  CODE
  IF pIdx < 1 OR pIdx > SELF.NMesh THEN RETURN.
  SELF.MSclX[pIdx] = pSX; SELF.MSclY[pIdx] = pSY; SELF.MSclZ[pIdx] = pSZ

WebGL2Class.SetUniformScale PROCEDURE(LONG pIdx,REAL pS)
  CODE
  SELF.SetScale(pIdx, pS, pS, pS)

WebGL2Class.SetMeshColor PROCEDURE(LONG pIdx,REAL pR,REAL pG,REAL pB)
  CODE
  IF pIdx < 1 OR pIdx > SELF.NMesh THEN RETURN.
  SELF.MColR[pIdx] = pR; SELF.MColG[pIdx] = pG; SELF.MColB[pIdx] = pB

WebGL2Class.SpinMesh PROCEDURE(LONG pIdx,REAL pSX,REAL pSY,REAL pSZ)
  CODE
  IF pIdx < 1 OR pIdx > SELF.NMesh THEN RETURN.
  SELF.MSpinX[pIdx] = pSX; SELF.MSpinY[pIdx] = pSY; SELF.MSpinZ[pIdx] = pSZ

WebGL2Class.MeshCount PROCEDURE()
  CODE
  RETURN SELF.NMesh

!=== Vec3 math ==============================================================
WebGL2Class.Vec3Length PROCEDURE(REAL pX,REAL pY,REAL pZ)
  CODE
  RETURN SQRT(pX*pX + pY*pY + pZ*pZ)

WebGL2Class.Vec3Distance PROCEDURE(REAL pX1,REAL pY1,REAL pZ1,REAL pX2,REAL pY2,REAL pZ2)
  CODE
  RETURN SELF.Vec3Length(pX2-pX1, pY2-pY1, pZ2-pZ1)

WebGL2Class.Vec3Dot PROCEDURE(REAL pAX,REAL pAY,REAL pAZ,REAL pBX,REAL pBY,REAL pBZ)
  CODE
  RETURN pAX*pBX + pAY*pBY + pAZ*pBZ

WebGL2Class.Vec3Add PROCEDURE(REAL pAX,REAL pAY,REAL pAZ,REAL pBX,REAL pBY,REAL pBZ)
  CODE
  SELF.Rx = pAX+pBX; SELF.Ry = pAY+pBY; SELF.Rz = pAZ+pBZ

WebGL2Class.Vec3Sub PROCEDURE(REAL pAX,REAL pAY,REAL pAZ,REAL pBX,REAL pBY,REAL pBZ)
  CODE
  SELF.Rx = pAX-pBX; SELF.Ry = pAY-pBY; SELF.Rz = pAZ-pBZ

WebGL2Class.Vec3Scale PROCEDURE(REAL pX,REAL pY,REAL pZ,REAL pS)
  CODE
  SELF.Rx = pX*pS; SELF.Ry = pY*pS; SELF.Rz = pZ*pS

WebGL2Class.Vec3Cross PROCEDURE(REAL pAX,REAL pAY,REAL pAZ,REAL pBX,REAL pBY,REAL pBZ)
  CODE
  SELF.Rx = pAY*pBZ - pAZ*pBY
  SELF.Ry = pAZ*pBX - pAX*pBZ
  SELF.Rz = pAX*pBY - pAY*pBX

WebGL2Class.Vec3Normalize PROCEDURE(REAL pX,REAL pY,REAL pZ)
len  REAL
  CODE
  len = SELF.Vec3Length(pX, pY, pZ)
  IF len = 0 THEN len = 1.
  SELF.Rx = pX/len; SELF.Ry = pY/len; SELF.Rz = pZ/len

WebGL2Class.Vec3Lerp PROCEDURE(REAL pAX,REAL pAY,REAL pAZ,REAL pBX,REAL pBY,REAL pBZ,REAL pT)
  CODE
  SELF.Rx = pAX + (pBX-pAX)*pT
  SELF.Ry = pAY + (pBY-pAY)*pT
  SELF.Rz = pAZ + (pBZ-pAZ)*pT

!=== Mat4 math (column-major; SELF.Mat[1..16]) ==============================
WebGL2Class.Mat4Identity PROCEDURE()
i  LONG
  CODE
  LOOP i = 1 TO 16; SELF.Mat[i] = 0.
  SELF.Mat[1] = 1; SELF.Mat[6] = 1; SELF.Mat[11] = 1; SELF.Mat[16] = 1

WebGL2Class.Mat4Translate PROCEDURE(REAL pX,REAL pY,REAL pZ)
  CODE
  SELF.Mat4Identity()
  SELF.Mat[13] = pX; SELF.Mat[14] = pY; SELF.Mat[15] = pZ

WebGL2Class.Mat4Scale PROCEDURE(REAL pX,REAL pY,REAL pZ)
  CODE
  SELF.Mat4Identity()
  SELF.Mat[1] = pX; SELF.Mat[6] = pY; SELF.Mat[11] = pZ

WebGL2Class.Mat4RotateX PROCEDURE(REAL pRad)
c  REAL
s  REAL
  CODE
  c = COS(pRad); s = SIN(pRad)
  SELF.Mat4Identity()
  SELF.Mat[6] = c; SELF.Mat[7] = s; SELF.Mat[10] = -s; SELF.Mat[11] = c

WebGL2Class.Mat4RotateY PROCEDURE(REAL pRad)
c  REAL
s  REAL
  CODE
  c = COS(pRad); s = SIN(pRad)
  SELF.Mat4Identity()
  SELF.Mat[1] = c; SELF.Mat[3] = -s; SELF.Mat[9] = s; SELF.Mat[11] = c

WebGL2Class.Mat4RotateZ PROCEDURE(REAL pRad)
c  REAL
s  REAL
  CODE
  c = COS(pRad); s = SIN(pRad)
  SELF.Mat4Identity()
  SELF.Mat[1] = c; SELF.Mat[2] = s; SELF.Mat[5] = -s; SELF.Mat[6] = c

WebGL2Class.Mat4Perspective PROCEDURE(REAL pFovDeg,REAL pAspect,REAL pNear,REAL pFar)
t   REAL
nf  REAL
i   LONG
  CODE
  t = TAN(pFovDeg * WebGL2:PI / 360)
  IF pFar = pNear THEN nf = 0 ELSE nf = 1 / (pNear - pFar).
  LOOP i = 1 TO 16; SELF.Mat[i] = 0.
  IF pAspect = 0 OR t = 0 THEN RETURN.
  SELF.Mat[1] = 1 / (pAspect * t)
  SELF.Mat[6] = 1 / t
  SELF.Mat[11] = (pFar + pNear) * nf
  SELF.Mat[12] = -1
  SELF.Mat[15] = 2 * pFar * pNear * nf

WebGL2Class.Mat4Multiply PROCEDURE(REAL pA1,REAL pA2,REAL pA3,REAL pA4,REAL pA5,REAL pA6,REAL pA7,REAL pA8,REAL pA9,REAL pA10,REAL pA11,REAL pA12,REAL pA13,REAL pA14,REAL pA15,REAL pA16)
B    REAL,DIM(16)
OutM REAL,DIM(16)
col  LONG
row  LONG
k    LONG
sum  REAL
  CODE
  B[1]=pA1;  B[2]=pA2;  B[3]=pA3;  B[4]=pA4
  B[5]=pA5;  B[6]=pA6;  B[7]=pA7;  B[8]=pA8
  B[9]=pA9;  B[10]=pA10; B[11]=pA11; B[12]=pA12
  B[13]=pA13; B[14]=pA14; B[15]=pA15; B[16]=pA16
  LOOP col = 0 TO 3
    LOOP row = 0 TO 3
      sum = 0
      LOOP k = 0 TO 3
        sum += SELF.Mat[k*4 + row + 1] * B[col*4 + k + 1]
      END
      OutM[col*4 + row + 1] = sum
    END
  END
  LOOP col = 1 TO 16; SELF.Mat[col] = OutM[col].

WebGL2Class.Deg2Rad PROCEDURE(REAL pDeg)
  CODE
  RETURN pDeg * WebGL2:PI / 180

WebGL2Class.Rad2Deg PROCEDURE(REAL pRad)
  CODE
  RETURN pRad * 180 / WebGL2:PI

!=== output =================================================================
WebGL2Class.SaveHtml PROCEDURE(STRING pFilename)
engPath  CSTRING(260)
inlined  BYTE
  CODE
  OutF{PROP:Name} = CLIP(pFilename)
  CREATE(OutF); IF ERRORCODE() THEN RETURN 0.
  OPEN(OutF, 12h)                                            ! 12h = ReadWrite / DenyAll
  IF ERRORCODE() THEN RETURN 0.
  EMPTY(OutF)
  SELF.LastFile = CLIP(pFilename)

  SELF.WriteLine('<!DOCTYPE html>')
  SELF.WriteLine('<html lang="en"><head><meta charset="utf-8">')
  SELF.WriteLine('<meta name="viewport" content="width=device-width,initial-scale=1">')
  SELF.WriteLine('<title>' & SELF.JsEsc(SELF.Title) & '</title>')
  SELF.WriteLine('<style>')
  SELF.WriteLine('  html,body{margin:0;height:100%;background:#0a0e16;color:#cfd6e4;')
  SELF.WriteLine('    font-family:Segoe UI,Roboto,Helvetica,Arial,sans-serif;overflow:hidden}')
  SELF.WriteLine('  #wrap{position:fixed;inset:0;display:flex;align-items:center;justify-content:center}')
  SELF.WriteLine('  canvas{display:block;background:#000;box-shadow:0 18px 60px rgba(0,0,0,.6);border-radius:10px}')
  SELF.WriteLine('  #hud{position:fixed;left:14px;top:12px;font-size:12px;line-height:1.5;')
  SELF.WriteLine('    padding:10px 13px;background:rgba(13,18,28,.72);border:1px solid #1f2a3d;')
  SELF.WriteLine('    border-radius:8px;pointer-events:none}')
  SELF.WriteLine('  #hud b{color:#5ad1c0;font-size:13px} #hud .k{color:#7f8aa3}')
  SELF.WriteLine('  #fps{position:fixed;right:14px;top:12px;font-size:12px;color:#7f8aa3;')
  SELF.WriteLine('    background:rgba(13,18,28,.72);border:1px solid #1f2a3d;border-radius:8px;padding:6px 10px}')
  SELF.WriteLine('  #err{position:fixed;left:14px;bottom:14px;right:14px;color:#ff8a8a;font-size:13px;')
  SELF.WriteLine('    white-space:pre-wrap;display:none;background:rgba(40,10,12,.85);padding:10px;border-radius:8px}')
  SELF.WriteLine('</style></head><body>')
  SELF.WriteLine('<div id="wrap"><canvas id="gl"></canvas></div>')
  SELF.WriteLine('<div id="hud"></div><div id="fps">--- fps</div><div id="err"></div>')

  SELF.WriteLine('<script>')
  SELF.EmitScene()
  SELF.WriteLine('</script>')

  ! ---- the WebGL2 engine: inline it (self-contained) or reference it ----
  SELF.WriteLine('<script>')
  engPath = SELF.FindEngine()
  inlined = 0
  IF engPath
    EngF{PROP:Name} = engPath
    OPEN(EngF, 40h)                                          ! 40h = ReadOnly + DenyNone
    IF ~ERRORCODE()
      SET(EngF)                                              ! position at the first line for sequential read
      LOOP
        NEXT(EngF)
        IF ERRORCODE() THEN BREAK.
        SELF.WriteLine(CLIP(EngF:Line))
      END
      CLOSE(EngF)
      inlined = 1
    END
  END
  SELF.WriteLine('</script>')
  IF ~inlined                                                ! engine not found - load it from beside the page
    SELF.WriteLine('<script src="' & CLIP(SELF.EngineFile) & '"></script>')
  END

  SELF.WriteLine('</body></html>')
  CLOSE(OutF)
  RETURN 1

WebGL2Class.Show PROCEDURE()
  CODE
  RETURN SELF.ShowFile(SELF.TempHtmlPath())

WebGL2Class.ShowFile PROCEDURE(STRING pFilename)
full  CSTRING(300)
  CODE
  IF ~SELF.SaveHtml(pFilename) THEN RETURN 0.
  full = CLIP(pFilename)
  IF ~INSTRING(':', full, 1, 1) AND full[1] <> '\'           ! relative -> make absolute so the browser finds it
    full = CLIP(PATH()) & '\' & CLIP(pFilename)
  END
  SELF.LastFile = full
  RUN('rundll32.exe url.dll,FileProtocolHandler ' & full)
  RETURN 1

!=== embedded display (a borderless Edge OVERLAY owned by the Clarion window) =
!  Launches a separate-process "msedge --app" window and positions it OVER the
!  host window (or a control in it), set as an OWNED window of the host so it
!  stays above it, moves/hides with it. It stays a TOP-LEVEL window (not a
!  child), so it keeps full native mouse + keyboard interaction; SetWindowRgn
!  clips Edge's app title bar away. Call EmbedFit on EVENT:Sized AND EVENT:Moved.
WebGL2Class.ResolveHost PROCEDURE(ULONG pHwnd)
h  ULONG
  CODE
  h = pHwnd
  IF ~wgIsWindow(h) THEN h = wgGetActiveWin().                ! Clarion's {PROP:Handle} isn't always a real HWND
  IF ~wgIsWindow(h) THEN h = wgGetForeWin().
  RETURN h

WebGL2Class.SetEmbedControl PROCEDURE(SIGNED pFeq)
  CODE
  SELF.HostFeq = pFeq                                         ! 0 = fill the whole window; otherwise this control's rect

WebGL2Class.ShowEmbedded PROCEDURE(ULONG pHostHwnd)
path  CSTRING(300)
url   CSTRING(330)
title CSTRING(140)
cls   CSTRING(20)
cmd   CSTRING(700)
tries LONG
  CODE
  SELF.HostHwnd = SELF.ResolveHost(pHostHwnd)
  IF ~SELF.HostHwnd THEN RETURN 0.
  SELF.DisplayMode = WebGL2:Embedded                          ! before SaveHtml: the page moves its HUD to the bottom
  ! a unique page title so we can find exactly this Edge window
  SELF.Title = CLIP(SELF.Title) & ' #' & RANDOM(100000, 999999)
  path = SELF.TempHtmlPath()
  IF ~SELF.SaveHtml(path) THEN RETURN 0.
  SELF.LastFile = path
  url = SELF.FileUrl(path)
  ! launch a borderless Edge app window, off-screen, in its own profile
  cmd = '"' & CLIP(SELF.EdgeExe) & '" --app=' & CLIP(url) |
      & ' --window-size=' & SELF.CanvasW & ',' & SELF.CanvasH |
      & ' --window-position=-32000,-32000 --new-window' |
      & ' --no-first-run --no-default-browser-check --disable-sync' |
      & ' --disable-features=msImplicitSignin,msEdgeWelcomePage,msEdgeIdentityFre' |
      & ' --user-data-dir="' & CLIP(SELF.TempHtmlPath()) & '.edge"'
  RUN(cmd)                                                    ! async - returns immediately
  title = CLIP(SELF.Title)
  cls   = 'Chrome_WidgetWin_1'
  SELF.EdgeHwnd = 0
  LOOP tries = 1 TO 80                                        ! wait up to ~4s for the window to appear
    SELF.EdgeHwnd = wgFindWindowEx(0, 0, cls, title)
    IF SELF.EdgeHwnd THEN BREAK.
    wgSleep(50)
  END
  IF ~SELF.EdgeHwnd THEN RETURN 0.
  SELF.EdgePid = 0
  wgGetWinPid(SELF.EdgeHwnd, SELF.EdgePid)                    ! remember the browser process so EmbedClose can kill its whole tree
  ! OWN it by the Clarion window (stays above it, hides when it minimises) but
  ! keep it top-level - that's what preserves full mouse/keyboard interaction.
  wgSetWindowLong(SELF.EdgeHwnd, WG2:GWL_HWNDPARENT, SELF.HostHwnd)
  ! strip the frame: WS_POPUP only -> no resize border, no caption, fixed size
  wgSetWindowLong(SELF.EdgeHwnd, WG2:GWL_STYLE, BOR(WG2:WS_POPUP, WG2:WS_VISIBLE))
  wgSetWindowPos(SELF.EdgeHwnd, 0, 0, 0, 0, 0, WG2:SWP_FRAME)  ! apply the style change
  SELF.EmbedFit()
  SELF.EmbedFocus()
  RETURN 1

WebGL2Class.EmbedFit PROCEDURE()
rc    LONG,DIM(4)
pt    LONG,DIM(2)
x     LONG
y     LONG
w     LONG
h     LONG
savePx BYTE
f     SIGNED
rgn   ULONG
  CODE
  IF ~SELF.EdgeHwnd OR ~SELF.HostHwnd THEN RETURN 0.
  IF SELF.HostFeq                                            ! confine to a control's pixel rect
    savePx = 0{PROP:Pixels}
    0{PROP:Pixels} = 1
    f = SELF.HostFeq
    x = f{PROP:Xpos}; y = f{PROP:Ypos}; w = f{PROP:Width}; h = f{PROP:Height}
    0{PROP:Pixels} = savePx
  ELSE                                                       ! fill the whole client area
    wgGetClientRect(SELF.HostHwnd, rc[1])
    x = 0; y = 0; w = rc[3]; h = rc[4]
  END
  IF w < 1 OR h < 1 THEN RETURN 0.
  pt[1] = x; pt[2] = y                                       ! client (x,y) -> screen
  wgClientToScreen(SELF.HostHwnd, pt[1])
  ! the overlay is shifted up by EmbedInset; SetWindowRgn shows only the content
  ! below the title bar, so the visible area maps exactly onto the target rect.
  wgMoveWindow(SELF.EdgeHwnd, pt[1], pt[2] - SELF.EmbedInset, w, h + SELF.EmbedInset, 1)
  rgn = wgCreateRectRgn(0, SELF.EmbedInset, w, h + SELF.EmbedInset)
  wgSetWindowRgn(SELF.EdgeHwnd, rgn, 1)                       ! window owns the region (don't delete it)
  RETURN 1

WebGL2Class.EmbedSetBounds PROCEDURE(LONG pX,LONG pY,LONG pW,LONG pH)
  CODE
  IF ~SELF.EdgeHwnd THEN RETURN 0.
  wgMoveWindow(SELF.EdgeHwnd, pX, pY, pW, pH, 1)
  RETURN 1

WebGL2Class.EmbedReady PROCEDURE()
  CODE
  RETURN CHOOSE(SELF.EdgeHwnd <> 0, 1, 0)

!  Bring the overlay to the foreground (it's a real top-level window, so this
!  gives it the mouse + keyboard). Call it to hand input back to the 3D.
WebGL2Class.EmbedFocus PROCEDURE()
  CODE
  IF SELF.EdgeHwnd THEN wgSetForeground(SELF.EdgeHwnd).

WebGL2Class.EmbedClose PROCEDURE()
cmd  CSTRING(64)
ok   LONG
si   GROUP                                                    ! STARTUPINFOA - lets us hide the taskkill window
cb     ULONG
lpReserved   LONG(0)
lpDesktop    LONG(0)
lpTitle      LONG(0)
dwX          ULONG
dwY          ULONG
dwXSize      ULONG
dwYSize      ULONG
dwXCount     ULONG
dwYCount     ULONG
dwFill       ULONG
dwFlags      ULONG
wShow        SHORT(0)
cbReserved2  SHORT(0)
lpReserved2  LONG(0)
hStdIn       LONG
hStdOut      LONG
hStdErr      LONG
     END
pi   GROUP                                                    ! PROCESS_INFORMATION
hProcess     LONG
hThread      LONG
dwPid        ULONG
dwTid        ULONG
     END
  CODE
  IF SELF.EdgeHwnd
    wgPostMessage(SELF.EdgeHwnd, WG2:WM_CLOSE, 0, 0)          ! ask the overlay window to close gracefully (releases the profile lock)
    SELF.EdgeHwnd = 0
  END
  IF SELF.EdgePid                                             ! GUARANTEED backstop: kill the Edge browser AND its whole child tree
    wgSleep(120)                                             ! give the graceful close a moment first
    cmd = 'taskkill /F /T /PID ' & SELF.EdgePid              ! /T = the GPU/renderer/network/crashpad children too
    si.cb = SIZE(si); si.dwFlags = WG2:STARTF_USESHOWWINDOW; si.wShow = WG2:SW_HIDE
    ok = wgCreateProcess(0, cmd, 0, 0, 0, WG2:CREATE_NO_WINDOW, 0, 0, ADDRESS(si), ADDRESS(pi))
    IF ok                                                     ! release the handles taskkill handed back
      wgCloseHandle(pi.hThread)
      wgCloseHandle(pi.hProcess)
    END
    SELF.EdgePid = 0
  END

WebGL2Class.FileUrl PROCEDURE(STRING pPath)
s  CSTRING(320)
i  LONG
  CODE
  s = CLIP(pPath)
  LOOP i = 1 TO LEN(s)
    IF s[i : i] = '\' THEN s[i : i] = '/'.                   ! file URLs use forward slashes
  END
  RETURN 'file:///' & s

!=== internal ===============================================================
WebGL2Class.WriteLine PROCEDURE(STRING pLine)
  CODE
  OutF:Line = pLine
  ADD(OutF)

WebGL2Class.ClToRGB PROCEDURE(LONG pClarionColor,*REAL pR,*REAL pG,*REAL pB)
c  LONG
  CODE
  c = pClarionColor                                          ! Clarion color = 0x00BBGGRR
  pR = BAND(c, 0FFh) / 255.0
  pG = BAND(BSHIFT(c, -8), 0FFh) / 255.0
  pB = BAND(BSHIFT(c, -16), 0FFh) / 255.0

WebGL2Class.NumStr PROCEDURE(REAL pV)
src STRING(48)
s   STRING(48)
i   LONG
op  LONG
n   LONG
  CODE
  ! Format the MAGNITUDE: the @n picture here drops the sign and inserts grouping
  ! commas, so we format ABS(), strip the commas, then re-apply the sign ourselves.
  src = LEFT(FORMAT(ABS(pV), @n23.6))
  op = 0
  LOOP i = 1 TO LEN(CLIP(src))
    IF src[i : i] = ',' THEN CYCLE.                          ! drop thousands separators
    op += 1; s[op : op] = src[i : i]
  END
  n = op
  LOOP WHILE n > 1 AND s[n : n] = '0'                        ! trim trailing zeros
    n -= 1
  END
  IF n >= 1 AND s[n : n] = '.' THEN n -= 1.                  ! and a dangling decimal point
  IF n < 1 THEN RETURN '0'.
  IF pV < 0 AND ~(n = 1 AND s[1 : 1] = '0')                 ! re-apply sign (but not for -0)
    RETURN '-' & s[1 : n]
  END
  RETURN s[1 : n]

WebGL2Class.ColStr PROCEDURE(REAL pR,REAL pG,REAL pB)
  CODE
  RETURN '[' & SELF.NumStr(pR) & ',' & SELF.NumStr(pG) & ',' & SELF.NumStr(pB) & ']'

WebGL2Class.JsEsc PROCEDURE(STRING pText)
o  STRING(512)
i  LONG
op LONG
c  STRING(1)
  CODE
  op = 0
  LOOP i = 1 TO LEN(CLIP(pText))
    c = pText[i : i]
    IF c = '''' OR c = '\'                                   ! escape ' and backslash
      op += 1; o[op : op] = '\'
    END
    op += 1; o[op : op] = c
    IF op >= 510 THEN BREAK.
  END
  RETURN o[1 : op]

WebGL2Class.FindEngine PROCEDURE()
p  CSTRING(300)
  CODE
  IF EXISTS(CLIP(SELF.EngineFile)) THEN RETURN CLIP(SELF.EngineFile).
  p = CLIP(PATH()) & '\' & CLIP(SELF.EngineFile)             ! try the current/app folder
  IF EXISTS(p) THEN RETURN p.
  RETURN ''                                                  ! not found - SaveHtml falls back to a <script src>

WebGL2Class.TempHtmlPath PROCEDURE()
  CODE
  RETURN CLIP(PATH()) & '\my3D_preview.html'

!--- the window.SCENE = {...} block -----------------------------------------
WebGL2Class.EmitScene PROCEDURE()
i  LONG
line CSTRING(900)
  CODE
  SELF.WriteLine('window.SCENE = {')
  SELF.WriteLine('  title:''' & SELF.JsEsc(SELF.Title) & ''',')
  SELF.WriteLine('  canvas:{w:' & SELF.NumStr(SELF.CanvasW) & ',h:' & SELF.NumStr(SELF.CanvasH) |
    & ',aa:' & CHOOSE(SELF.Antialias<>0,'true','false') & '},')
  SELF.WriteLine('  hud:' & CHOOSE(SELF.ShowHud<>0,'true','false') |
    & ',fps:' & CHOOSE(SELF.ShowFps<>0,'true','false') & ',')
  IF SELF.BgGradient
    SELF.WriteLine('  background:{type:''gradient'',top:' & SELF.ColStr(SELF.BgTopR,SELF.BgTopG,SELF.BgTopB) |
      & ',bottom:' & SELF.ColStr(SELF.BgR,SELF.BgG,SELF.BgB) |
      & ',color:' & SELF.ColStr(SELF.BgR,SELF.BgG,SELF.BgB) & '},')
  ELSE
    SELF.WriteLine('  background:{type:''solid'',color:' & SELF.ColStr(SELF.BgR,SELF.BgG,SELF.BgB) & '},')
  END
  SELF.WriteLine('  fog:{on:' & CHOOSE(SELF.FogOn<>0,'true','false') & ',color:' |
    & SELF.ColStr(SELF.FogR,SELF.FogG,SELF.FogB) |
    & ',near:' & SELF.NumStr(SELF.FogNear) & ',far:' & SELF.NumStr(SELF.FogFar) & '},')
  SELF.WriteLine('  camera:{pos:' & SELF.ColStr(SELF.CamX,SELF.CamY,SELF.CamZ) |
    & ',target:' & SELF.ColStr(SELF.TgtX,SELF.TgtY,SELF.TgtZ) |
    & ',fov:' & SELF.NumStr(SELF.Fov) & ',near:' & SELF.NumStr(SELF.ClipNear) |
    & ',far:' & SELF.NumStr(SELF.ClipFar) & ',orbit:' & CHOOSE(SELF.Orbit<>0,'true','false') |
    & ',orbitSpeed:' & SELF.NumStr(SELF.OrbitSpeed) & '},')
  ! lights
  SELF.WriteLine('  lights:{ambient:' & SELF.ColStr(SELF.AmbR,SELF.AmbG,SELF.AmbB) & ',')
  SELF.WriteLine('    dir:{dir:' & SELF.ColStr(SELF.DirX,SELF.DirY,SELF.DirZ) |
    & ',color:' & SELF.ColStr(SELF.DirR,SELF.DirG,SELF.DirB) |
    & ',intensity:' & SELF.NumStr(SELF.DirInt) & '},')
  SELF.WriteLine('    points:[')
  LOOP i = 1 TO SELF.NLight
    line = '      {pos:' & SELF.ColStr(SELF.PLPosX[i],SELF.PLPosY[i],SELF.PLPosZ[i]) |
      & ',color:' & SELF.ColStr(SELF.PLColR[i],SELF.PLColG[i],SELF.PLColB[i]) |
      & ',intensity:' & SELF.NumStr(SELF.PLInt[i]) & ',range:' & SELF.NumStr(SELF.PLRange[i]) & '}'
    IF i < SELF.NLight THEN line = CLIP(line) & ','.
    SELF.WriteLine(line)
  END
  SELF.WriteLine('    ]},')
  ! grid / axes / wireframe
  SELF.WriteLine('  grid:{on:' & CHOOSE(SELF.GridOn<>0,'true','false') |
    & ',size:' & SELF.NumStr(SELF.GridSize) & ',div:' & SELF.NumStr(SELF.GridDiv) |
    & ',color:' & SELF.ColStr(SELF.GridR,SELF.GridG,SELF.GridB) & '},')
  SELF.WriteLine('  axes:{on:' & CHOOSE(SELF.AxesOn<>0,'true','false') |
    & ',size:' & SELF.NumStr(SELF.AxesSize) & '},')
  SELF.WriteLine('  wireframe:' & CHOOSE(SELF.Wireframe<>0,'true','false') & ',')
  ! meshes
  SELF.WriteLine('  meshes:[')
  LOOP i = 1 TO SELF.NMesh
    line = '    {type:''' & CLIP(SELF.MType[i]) & ''',params:[' |
      & SELF.NumStr(SELF.MP1[i]) & ',' & SELF.NumStr(SELF.MP2[i]) & ',' & SELF.NumStr(SELF.MP3[i]) & ',' |
      & SELF.NumStr(SELF.MP4[i]) & ',' & SELF.NumStr(SELF.MP5[i]) & ',' & SELF.NumStr(SELF.MP6[i]) & ']' |
      & ',pos:' & SELF.ColStr(SELF.MPosX[i],SELF.MPosY[i],SELF.MPosZ[i]) |
      & ',rot:' & SELF.ColStr(SELF.MRotX[i],SELF.MRotY[i],SELF.MRotZ[i]) |
      & ',scale:' & SELF.ColStr(SELF.MSclX[i],SELF.MSclY[i],SELF.MSclZ[i]) |
      & ',color:' & SELF.ColStr(SELF.MColR[i],SELF.MColG[i],SELF.MColB[i]) |
      & ',metalness:' & SELF.NumStr(SELF.MMetal[i]) & ',roughness:' & SELF.NumStr(SELF.MRough[i]) |
      & ',opacity:' & SELF.NumStr(SELF.MOpacity[i]) |
      & ',emissive:' & SELF.ColStr(SELF.MEmiR[i],SELF.MEmiG[i],SELF.MEmiB[i]) |
      & ',spin:' & SELF.ColStr(SELF.MSpinX[i],SELF.MSpinY[i],SELF.MSpinZ[i]) |
      & ',wire:' & CHOOSE(SELF.MWire[i]<>0,'true','false') & '}'
    IF i < SELF.NMesh THEN line = CLIP(line) & ','.
    SELF.WriteLine(line)
  END
  SELF.WriteLine('  ]')
  SELF.WriteLine('};')
