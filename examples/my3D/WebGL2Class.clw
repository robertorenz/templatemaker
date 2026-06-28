! ============================================================================
!  WebGL2Class - implementation.  Builds a self-contained WebGL2 .html page
!  (scene data + the my3D engine) and opens it in the default browser.
!  Pure Clarion: ASCII-driver file IO + RUN(rundll32 FileProtocolHandler).
!  Store this file in ANSI (not UTF-8).
! ============================================================================
  MEMBER

  MAP
  END

  INCLUDE('WebGL2Class.INC'),ONCE

WebGL2:PI         EQUATE(3.14159265358979)

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
  SELF.Reset()

WebGL2Class.Reset PROCEDURE()
  CODE
  SELF.Title = 'my3D / WebGL2'
  SELF.CanvasW = 1000; SELF.CanvasH = 640; SELF.Antialias = 1
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
