! ============================================================================
!  DataMatrixClass - implementation. Data Matrix (ECC200) encoder + drawing.
!  Port of the ZXing-validated C# reference (designer/BarcodeCore/DataMatrix.cs).
!  bare MEMBER + module MAP (so BUILTINS.CLW resolves); SELF.Modulo; INT();
!  bit ops via BSHIFT/BAND. This file MUST be stored in ANSI (not UTF-8).
! ============================================================================
  MEMBER

  MAP
  END

  INCLUDE('DataMatrixClass.INC'),ONCE

DataMatrixClass.Construct PROCEDURE()
  CODE
  SELF.Init()

DataMatrixClass.Destruct PROCEDURE()
  CODE

!=== GF(256) tables (0x12D) + size table =====================================
DataMatrixClass.Init PROCEDURE()
x  LONG
i  LONG
  CODE
  IF SELF.Ready = 1 THEN RETURN.
  x = 1
  LOOP i = 0 TO 254
    SELF.GFExp[i+1] = x
    SELF.GFLog[x+1] = i
    x = BSHIFT(x,1)
    IF BAND(x,0100h) THEN x = BXOR(x,012Dh).
  END
  LOOP i = 255 TO 511
    SELF.GFExp[i+1] = SELF.GFExp[i-255+1]
  END
  ! size table: dim, region, data CW, EC CW
  SELF.SzDim[1]=10; SELF.SzReg[1]=8;  SELF.SzData[1]=3;  SELF.SzEc[1]=5
  SELF.SzDim[2]=12; SELF.SzReg[2]=10; SELF.SzData[2]=5;  SELF.SzEc[2]=7
  SELF.SzDim[3]=14; SELF.SzReg[3]=12; SELF.SzData[3]=8;  SELF.SzEc[3]=10
  SELF.SzDim[4]=16; SELF.SzReg[4]=14; SELF.SzData[4]=12; SELF.SzEc[4]=12
  SELF.SzDim[5]=18; SELF.SzReg[5]=16; SELF.SzData[5]=18; SELF.SzEc[5]=14
  SELF.SzDim[6]=20; SELF.SzReg[6]=18; SELF.SzData[6]=22; SELF.SzEc[6]=18
  SELF.SzDim[7]=22; SELF.SzReg[7]=20; SELF.SzData[7]=30; SELF.SzEc[7]=20
  SELF.SzDim[8]=24; SELF.SzReg[8]=22; SELF.SzData[8]=36; SELF.SzEc[8]=24
  SELF.SzDim[9]=26; SELF.SzReg[9]=24; SELF.SzData[9]=44; SELF.SzEc[9]=28
  SELF.Ready = 1

DataMatrixClass.Modulo PROCEDURE(LONG a,LONG b)
  CODE
  RETURN a - INT(a/b)*b

DataMatrixClass.GfMul PROCEDURE(LONG a,LONG b)
  CODE
  IF a = 0 OR b = 0 THEN RETURN 0.
  RETURN SELF.GFExp[ SELF.GFLog[a+1] + SELF.GFLog[b+1] + 1 ]

!=== Reed-Solomon (base 1): SELF.CW[1..dataLen] -> EC at SELF.CW[dataLen+1..] ==
DataMatrixClass.ReedSolomon PROCEDURE(LONG dataLen,LONG ecLen)
g    LONG,DIM(40)
ng   LONG,DIM(40)
gen  LONG,DIM(40)
res  LONG,DIM(40)
glen LONG
i    LONG
j    LONG
d    LONG
factor LONG
  CODE
  g[1] = 1; glen = 1                                          ! generator: roots a^1..a^ecLen
  LOOP i = 0 TO ecLen-1
    LOOP j = 1 TO glen+1; ng[j] = 0; END
    LOOP j = 1 TO glen
      ng[j]   = BXOR(ng[j],   g[j])
      ng[j+1] = BXOR(ng[j+1], SELF.GfMul(g[j], SELF.GFExp[i+1+1]))      ! Exp[i+1] in 0-based = GFExp[i+2]
    END
    glen += 1
    LOOP j = 1 TO glen; g[j] = ng[j]; END
  END
  LOOP i = 1 TO ecLen; gen[i] = g[i+1]; END
  LOOP i = 1 TO ecLen; res[i] = 0; END
  LOOP d = 1 TO dataLen
    factor = BXOR(SELF.CW[d], res[1])
    LOOP i = 1 TO ecLen-1; res[i] = res[i+1]; END
    res[ecLen] = 0
    LOOP i = 1 TO ecLen; res[i] = BXOR(res[i], SELF.GfMul(gen[i], factor)); END
  END
  LOOP i = 1 TO ecLen; SELF.CW[dataLen+i] = BAND(res[i],0FFh); END

!=== ECC200 placement ========================================================
DataMatrixClass.PModule PROCEDURE(LONG row,LONG col,LONG pos,LONG b)
  CODE
  IF row < 0
    row += SELF.PNrow
    col += 4 - SELF.Modulo(SELF.PNrow+4, 8)
  END
  IF col < 0
    col += SELF.PNcol
    row += 4 - SELF.Modulo(SELF.PNcol+4, 8)
  END
  SELF.RBit[row+1, col+1] = BAND(BSHIFT(SELF.CW[pos], -(8-b)), 1)
  SELF.RSet[row+1, col+1] = 1

DataMatrixClass.PUtah PROCEDURE(LONG row,LONG col,LONG pos)
  CODE
  SELF.PModule(row-2, col-2, pos, 1); SELF.PModule(row-2, col-1, pos, 2)
  SELF.PModule(row-1, col-2, pos, 3); SELF.PModule(row-1, col-1, pos, 4)
  SELF.PModule(row-1, col,   pos, 5); SELF.PModule(row,   col-2, pos, 6)
  SELF.PModule(row,   col-1, pos, 7); SELF.PModule(row,   col,   pos, 8)

DataMatrixClass.PCorner PROCEDURE(LONG which,LONG pos)
nr  LONG
nc  LONG
  CODE
  nr = SELF.PNrow; nc = SELF.PNcol
  CASE which
  OF 1
    SELF.PModule(nr-1,0,pos,1); SELF.PModule(nr-1,1,pos,2); SELF.PModule(nr-1,2,pos,3)
    SELF.PModule(0,nc-2,pos,4); SELF.PModule(0,nc-1,pos,5); SELF.PModule(1,nc-1,pos,6)
    SELF.PModule(2,nc-1,pos,7); SELF.PModule(3,nc-1,pos,8)
  OF 2
    SELF.PModule(nr-3,0,pos,1); SELF.PModule(nr-2,0,pos,2); SELF.PModule(nr-1,0,pos,3)
    SELF.PModule(0,nc-4,pos,4); SELF.PModule(0,nc-3,pos,5); SELF.PModule(0,nc-2,pos,6)
    SELF.PModule(0,nc-1,pos,7); SELF.PModule(1,nc-1,pos,8)
  OF 3
    SELF.PModule(nr-3,0,pos,1); SELF.PModule(nr-2,0,pos,2); SELF.PModule(nr-1,0,pos,3)
    SELF.PModule(0,nc-2,pos,4); SELF.PModule(0,nc-1,pos,5); SELF.PModule(1,nc-1,pos,6)
    SELF.PModule(2,nc-1,pos,7); SELF.PModule(3,nc-1,pos,8)
  ELSE
    SELF.PModule(nr-1,0,pos,1); SELF.PModule(nr-1,nc-1,pos,2); SELF.PModule(0,nc-3,pos,3)
    SELF.PModule(0,nc-2,pos,4); SELF.PModule(0,nc-1,pos,5); SELF.PModule(1,nc-3,pos,6)
    SELF.PModule(1,nc-2,pos,7); SELF.PModule(1,nc-1,pos,8)
  END

DataMatrixClass.Placement PROCEDURE()
nr  LONG
nc  LONG
p   LONG
row LONG
col LONG
r   LONG
c   LONG
  CODE
  nr = SELF.PNrow; nc = SELF.PNcol
  LOOP r = 1 TO nr
    LOOP c = 1 TO nc
      SELF.RBit[r,c] = 0; SELF.RSet[r,c] = 0
    END
  END
  p = 1; row = 4; col = 0
  LOOP
    IF row = nr AND col = 0 THEN SELF.PCorner(1,p); p += 1.
    IF row = nr-2 AND col = 0 AND SELF.Modulo(nc,4) <> 0 THEN SELF.PCorner(2,p); p += 1.
    IF row = nr-2 AND col = 0 AND SELF.Modulo(nc,8) = 4 THEN SELF.PCorner(3,p); p += 1.
    IF row = nr+4 AND col = 2 AND SELF.Modulo(nc,8) = 0 THEN SELF.PCorner(4,p); p += 1.
    LOOP
      IF row < nr AND col >= 0 AND SELF.RSet[row+1,col+1] = 0
        SELF.PUtah(row,col,p); p += 1
      END
      row -= 2; col += 2
    UNTIL row < 0 OR col >= nc
    row += 1; col += 3
    LOOP
      IF row >= 0 AND col < nc AND SELF.RSet[row+1,col+1] = 0
        SELF.PUtah(row,col,p); p += 1
      END
      row += 2; col -= 2
    UNTIL row >= nr OR col < 0
    row += 3; col += 1
  UNTIL row >= nr AND col >= nc
  IF SELF.RSet[nr,nc] = 0                                     ! special bottom-right corner
    SELF.RBit[nr,nc] = 1; SELF.RBit[nr-1,nc-1] = 1
    SELF.RSet[nr,nc] = 1; SELF.RSet[nr-1,nc-1] = 1
  END

!=== the encoder: value -> SELF.Cells / SELF.N  (1 ok, 0 = too large) =========
DataMatrixClass.Build PROCEDURE(*CSTRING pValue)
s       CSTRING(256)
i       LONG
c       LONG
c2      LONG
si      LONG
region  LONG
dataCnt LONG
ecCnt   LONG
pos     LONG
rr      LONG
cc      LONG
rnd     LONG
v       LONG
  CODE
  SELF.Init()
  s = CLIP(pValue)
  ! ---- ASCII encodation ----
  SELF.NData = 0
  i = 1
  LOOP WHILE i <= LEN(s)
    c = VAL(s[i])
    IF c >= 48 AND c <= 57 AND i < LEN(s) AND VAL(s[i+1]) >= 48 AND VAL(s[i+1]) <= 57
      SELF.NData += 1
      SELF.Data[SELF.NData] = (c-48)*10 + (VAL(s[i+1])-48) + 130
      i += 2
    ELSIF c < 128
      SELF.NData += 1; SELF.Data[SELF.NData] = c + 1
      i += 1
    ELSE
      SELF.NData += 1; SELF.Data[SELF.NData] = 235
      SELF.NData += 1; SELF.Data[SELF.NData] = (c-128) + 1
      i += 1
    END
  END
  ! ---- choose the smallest square that fits ----
  si = 0
  LOOP i = 1 TO 9
    IF SELF.NData <= SELF.SzData[i] THEN si = i; BREAK.
  END
  IF si = 0 THEN RETURN 0.                                   ! too large for 26x26
  SELF.N  = SELF.SzDim[si]
  region  = SELF.SzReg[si]
  dataCnt = SELF.SzData[si]
  ecCnt   = SELF.SzEc[si]
  ! ---- pad: first 129, then 253-state randomisation ----
  IF SELF.NData < dataCnt
    SELF.NData += 1; SELF.Data[SELF.NData] = 129
    LOOP WHILE SELF.NData < dataCnt
      rnd = SELF.Modulo(149*(SELF.NData+1), 253) + 1
      v = 129 + rnd
      IF v > 254 THEN v -= 254.
      SELF.NData += 1; SELF.Data[SELF.NData] = v
    END
  END
  ! ---- codewords = data + EC ----
  LOOP i = 1 TO dataCnt; SELF.CW[i] = SELF.Data[i]; END
  SELF.ReedSolomon(dataCnt, ecCnt)
  ! ---- placement ----
  SELF.PNrow = region; SELF.PNcol = region
  SELF.Placement()
  ! ---- wrap with finder -> SELF.Cells ----
  CLEAR(SELF.Cells)
  LOOP rr = 0 TO region-1
    LOOP cc = 0 TO region-1
      SELF.Cells[rr+2, cc+2] = SELF.RBit[rr+1, cc+1]          ! data region -> m[r+1][c+1]
    END
  END
  LOOP i = 0 TO SELF.N-1
    SELF.Cells[i+1, 1]      = 1                               ! left solid
    SELF.Cells[i+1, SELF.N] = CHOOSE(SELF.Modulo(i,2)=1, 1, 0)! right timing
    SELF.Cells[SELF.N, i+1] = 1                               ! bottom solid
    SELF.Cells[1, i+1]      = CHOOSE(SELF.Modulo(i,2)=0, 1, 0)! top timing
  END
  RETURN 1

!=== drawing (same module-grid paint as QRCodeClass) =========================
DataMatrixClass.Paint PROCEDURE(SIGNED pImageFeq,LONG pDark,LONG pLight,LONG pQuiet)
ImgX  LONG
ImgY  LONG
imgW  LONG
imgH  LONG
n     LONG
q     LONG
side  LONG
cell  LONG
qpix  LONG
offX  LONG
offY  LONG
r     LONG
c     LONG
  CODE
  q = pQuiet; IF q < 0 THEN q = 0.
  n = SELF.N; side = n + 2*q
  GETPOSITION(pImageFeq, ImgX, ImgY, imgW, imgH)
  cell = INT(imgW/side); IF INT(imgH/side) < cell THEN cell = INT(imgH/side).
  IF cell < 1 THEN cell = 1.
  qpix = cell*side
  offX = ImgX + INT((imgW-qpix)/2); offY = ImgY + INT((imgH-qpix)/2)
  SETPENCOLOR(pLight)
  BOX(ImgX, ImgY, imgW, imgH, pLight)
  SETPENCOLOR(pDark)
  LOOP r = 0 TO n-1
    LOOP c = 0 TO n-1
      IF SELF.Cells[r+1, c+1] = 1
        BOX(offX+(c+q)*cell, offY+(r+q)*cell, cell, cell, pDark)
      END
    END
  END

DataMatrixClass.Draw PROCEDURE(SIGNED pImageFeq,*CSTRING pValue,LONG pDark,LONG pLight,LONG pQuiet)
  CODE
  IF SELF.Build(pValue) = 0 THEN RETURN.
  SETTARGET(,pImageFeq)
  BLANK
  SELF.Paint(pImageFeq, pDark, pLight, pQuiet)
  SETTARGET()
