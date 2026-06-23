! ============================================================================
!  AztecClass - implementation. Aztec Code encoder + drawing.
!  Port of the ZXing-validated C# reference (designer/BarcodeCore/Aztec.cs).
!  bare MEMBER + module MAP; SELF.Modulo; INT(); bit ops via BSHIFT/BAND/BOR/BXOR.
!  This file MUST be stored in ANSI (not UTF-8).
! ============================================================================
  MEMBER

  MAP
  END

  INCLUDE('AztecClass.INC'),ONCE

AztecClass.Construct PROCEDURE()
  CODE
  SELF.Init()

AztecClass.Destruct PROCEDURE()
  CODE

AztecClass.Init PROCEDURE()
i  LONG
  CODE
  IF SELF.Ready = 1 THEN RETURN.
  LOOP i = 1 TO 2;  SELF.WordSizeTbl[i] = 6;  END
  LOOP i = 3 TO 8;  SELF.WordSizeTbl[i] = 8;  END
  LOOP i = 9 TO 22; SELF.WordSizeTbl[i] = 10; END
  LOOP i = 23 TO 32;SELF.WordSizeTbl[i] = 12; END
  SELF.Ready = 1

AztecClass.Modulo PROCEDURE(LONG a,LONG b)
  CODE
  RETURN a - INT(a/b)*b

AztecClass.SetCell PROCEDURE(LONG x,LONG y)
  CODE
  SELF.Cells[y+1, x+1] = 1

!=== Galois field GF(2^wordSize), rebuilt per field ==========================
AztecClass.GfBuild PROCEDURE(LONG wordSize)
prim  LONG
size  LONG
x     LONG
i     LONG
  CODE
  CASE wordSize
  OF 4;  prim = 013h
  OF 6;  prim = 043h
  OF 8;  prim = 012Dh
  OF 10; prim = 0409h
  ELSE;  prim = 01069h
  END
  size = BSHIFT(1, wordSize)
  SELF.GFSize = size
  x = 1
  LOOP i = 0 TO size-2
    SELF.GFExp[i+1] = x
    SELF.GFLog[x+1] = i
    x = BSHIFT(x,1)
    IF BAND(x,size) THEN x = BXOR(x,prim).
  END
  LOOP i = size-1 TO 2*size-2
    SELF.GFExp[i+1] = SELF.GFExp[i-(size-1)+1]
  END

AztecClass.GfMul PROCEDURE(LONG a,LONG b)
  CODE
  IF a = 0 OR b = 0 THEN RETURN 0.
  RETURN SELF.GFExp[ SELF.GFLog[a+1] + SELF.GFLog[b+1] + 1 ]

!=== Reed-Solomon (base 1) over the current GF: SELF.RsIn -> SELF.RsOut ========
AztecClass.RsEcc PROCEDURE(LONG dataLen,LONG ecLen)
g      LONG,DIM(400)
ng     LONG,DIM(400)
coeffs LONG,DIM(400)
res    LONG,DIM(400)
glen   LONG
i      LONG
j      LONG
d      LONG
factor LONG
  CODE
  g[1] = 1; glen = 1
  LOOP i = 0 TO ecLen-1
    LOOP j = 1 TO glen+1; ng[j] = 0; END
    LOOP j = 1 TO glen
      ng[j]   = BXOR(ng[j],   g[j])
      ng[j+1] = BXOR(ng[j+1], SELF.GfMul(g[j], SELF.GFExp[i+1+1]))     ! a^(i+1)
    END
    glen += 1
    LOOP j = 1 TO glen; g[j] = ng[j]; END
  END
  LOOP i = 1 TO ecLen; coeffs[i] = g[i+1]; END
  LOOP i = 1 TO ecLen; res[i] = 0; END
  LOOP d = 1 TO dataLen
    factor = BXOR(SELF.RsIn[d], res[1])
    LOOP i = 1 TO ecLen-1; res[i] = res[i+1]; END
    res[ecLen] = 0
    LOOP i = 1 TO ecLen; res[i] = BXOR(res[i], SELF.GfMul(coeffs[i], factor)); END
  END
  LOOP i = 1 TO ecLen; SELF.RsOut[i] = res[i]; END

!=== the encoder: value -> SELF.Cells / SELF.N  (1 ok, 0 = too large) =========
AztecClass.Build PROCEDURE(*CSTRING pValue)
s        CSTRING(2200)
n        LONG
i        LONG
j        LONG
k        LONG
b        LONG
apV      LONG
apN      LONG
wordSize LONG
eccBits  LONG
totalSizeBits LONG
compact  BYTE
layers   LONG
totalBitsInLayers LONG
usable   LONG
ii       LONG
word     LONG
messageWords LONG
totalWords   LONG
ecLen    LONG
startPad LONG
baseMatrixSize LONG
matrixSize LONG
origCenter LONG
ctr      LONG
newOffset LONG
rowOffset LONG
rowSize  LONG
columnOffset LONG
center   LONG
sz       LONG
off      LONG
mw       LONG
nmode    LONG
nmn      LONG
ecm      LONG
  CODE
  SELF.Init()
  s = CLIP(pValue)
  n = LEN(s)
  ! ---- high-level: binary shift of the whole input ----
  SELF.NBits = 0
  apV = 31; apN = 5; DO AppB                                  ! B/S in Upper
  IF n <= 31
    apV = n; apN = 5; DO AppB
  ELSE
    apV = 0; apN = 5; DO AppB
    apV = n-31; apN = 11; DO AppB
  END
  LOOP j = 1 TO n
    apV = VAL(s[j]); apN = 8; DO AppB
  END
  ! ---- choose compact/full, layers, word size ----
  eccBits = INT(SELF.NBits*23/100) + 11
  totalSizeBits = SELF.NBits + eccBits
  wordSize = 0; layers = 0; SELF.NStuffed = 0; ii = 0
  LOOP
    IF ii > 32 THEN RETURN 0.
    compact = CHOOSE(ii <= 3, 1, 0)
    layers = CHOOSE(compact = 1, ii+1, ii)
    totalBitsInLayers = (CHOOSE(compact = 1, 88, 112) + 16*layers) * layers
    IF totalBitsInLayers < totalSizeBits
      ii += 1; CYCLE
    END
    IF SELF.NStuffed = 0 OR wordSize <> SELF.WordSizeTbl[layers]
      wordSize = SELF.WordSizeTbl[layers]
      DO StuffIt
    END
    usable = totalBitsInLayers - SELF.Modulo(totalBitsInLayers, wordSize)
    IF compact = 1 AND SELF.NStuffed > wordSize*64
      ii += 1; CYCLE
    END
    IF SELF.NStuffed + eccBits > usable
      ii += 1; CYCLE
    END
    BREAK
  END
  ! ---- data check words (RS over GF(2^wordSize)) ----
  SELF.GfBuild(wordSize)
  messageWords = INT(SELF.NStuffed / wordSize)
  totalWords = INT(totalBitsInLayers / wordSize)
  ecLen = totalWords - messageWords
  LOOP i = 1 TO messageWords
    word = 0
    LOOP j = 0 TO wordSize-1
      IF SELF.Stuffed[(i-1)*wordSize + j + 1] = 1
        word = BOR(word, BSHIFT(1, wordSize-1-j))
      END
    END
    SELF.Words[i] = word
    SELF.RsIn[i] = word
  END
  SELF.RsEcc(messageWords, ecLen)
  LOOP i = 1 TO ecLen; SELF.Words[messageWords+i] = SELF.RsOut[i]; END
  ! ---- message bits = startPad zeros + all words ----
  startPad = SELF.Modulo(totalBitsInLayers, wordSize)
  SELF.NMsg = 0
  LOOP i = 1 TO startPad; SELF.NMsg += 1; SELF.MsgBits[SELF.NMsg] = 0; END
  LOOP i = 1 TO totalWords
    LOOP j = wordSize-1 TO 0 BY -1
      SELF.NMsg += 1
      SELF.MsgBits[SELF.NMsg] = BAND(BSHIFT(SELF.Words[i],-j), 1)
    END
  END
  ! ---- matrix geometry ----
  baseMatrixSize = CHOOSE(compact = 1, 11, 14) + layers*4
  IF compact = 1
    matrixSize = baseMatrixSize
    LOOP i = 0 TO baseMatrixSize-1; SELF.AlignMap[i+1] = i; END
  ELSE
    matrixSize = baseMatrixSize + 1 + 2*INT((INT(baseMatrixSize/2)-1)/15)
    origCenter = INT(baseMatrixSize/2)
    ctr = INT(matrixSize/2)
    LOOP i = 0 TO origCenter-1
      newOffset = i + INT(i/15)
      SELF.AlignMap[origCenter-i-1 + 1] = ctr - newOffset - 1
      SELF.AlignMap[origCenter+i + 1]   = ctr + newOffset + 1
    END
  END
  SELF.N = matrixSize
  IF matrixSize > 90 THEN RETURN 0.
  CLEAR(SELF.Cells)
  ! ---- data spiral ----
  rowOffset = 0
  LOOP i = 0 TO layers-1
    rowSize = (layers-i)*4 + CHOOSE(compact = 1, 9, 12)
    LOOP j = 0 TO rowSize-1
      columnOffset = j*2
      LOOP k = 0 TO 1
        IF SELF.MsgBits[rowOffset + columnOffset + k + 1] = 1
          SELF.SetCell(SELF.AlignMap[i*2+k + 1], SELF.AlignMap[i*2+j + 1])
        END
        IF SELF.MsgBits[rowOffset + rowSize*2 + columnOffset + k + 1] = 1
          SELF.SetCell(SELF.AlignMap[i*2+j + 1], SELF.AlignMap[baseMatrixSize-1-i*2-k + 1])
        END
        IF SELF.MsgBits[rowOffset + rowSize*4 + columnOffset + k + 1] = 1
          SELF.SetCell(SELF.AlignMap[baseMatrixSize-1-i*2-k + 1], SELF.AlignMap[baseMatrixSize-1-i*2-j + 1])
        END
        IF SELF.MsgBits[rowOffset + rowSize*6 + columnOffset + k + 1] = 1
          SELF.SetCell(SELF.AlignMap[baseMatrixSize-1-i*2-j + 1], SELF.AlignMap[i*2+k + 1])
        END
      END
    END
    rowOffset += rowSize*8
  END
  ! ---- mode message (RS over GF16) ----
  IF compact = 1
    mw = BOR(BSHIFT(layers-1, 6), messageWords-1)
    SELF.RsIn[1] = BAND(BSHIFT(mw,-4), 0Fh); SELF.RsIn[2] = BAND(mw, 0Fh)
    nmn = 2; ecm = 5
  ELSE
    mw = BOR(BSHIFT(layers-1, 11), messageWords-1)
    SELF.RsIn[1] = BAND(BSHIFT(mw,-12),0Fh); SELF.RsIn[2] = BAND(BSHIFT(mw,-8),0Fh)
    SELF.RsIn[3] = BAND(BSHIFT(mw,-4), 0Fh); SELF.RsIn[4] = BAND(mw, 0Fh)
    nmn = 4; ecm = 6
  END
  SELF.GfBuild(4)
  SELF.RsEcc(nmn, ecm)
  nmode = 0
  LOOP i = 1 TO nmn
    LOOP j = 3 TO 0 BY -1; nmode += 1; SELF.ModeBits[nmode] = BAND(BSHIFT(SELF.RsIn[i],-j),1); END
  END
  LOOP i = 1 TO ecm
    LOOP j = 3 TO 0 BY -1; nmode += 1; SELF.ModeBits[nmode] = BAND(BSHIFT(SELF.RsOut[i],-j),1); END
  END
  center = INT(matrixSize/2)
  IF compact = 1
    LOOP i = 0 TO 6
      off = center-3+i
      IF SELF.ModeBits[i + 1]    = 1 THEN SELF.SetCell(off, center-5).
      IF SELF.ModeBits[i+7 + 1]  = 1 THEN SELF.SetCell(center+5, off).
      IF SELF.ModeBits[20-i + 1] = 1 THEN SELF.SetCell(off, center+5).
      IF SELF.ModeBits[27-i + 1] = 1 THEN SELF.SetCell(center-5, off).
    END
  ELSE
    LOOP i = 0 TO 9
      off = center-5+i+INT(i/5)
      IF SELF.ModeBits[i + 1]    = 1 THEN SELF.SetCell(off, center-7).
      IF SELF.ModeBits[i+10 + 1] = 1 THEN SELF.SetCell(center+7, off).
      IF SELF.ModeBits[29-i + 1] = 1 THEN SELF.SetCell(off, center+7).
      IF SELF.ModeBits[39-i + 1] = 1 THEN SELF.SetCell(center-7, off).
    END
  END
  ! ---- bullseye + orientation marks ----
  sz = CHOOSE(compact = 1, 5, 7)
  i = 0
  LOOP WHILE i < sz
    LOOP j = center-i TO center+i
      SELF.SetCell(j, center-i); SELF.SetCell(j, center+i)
      SELF.SetCell(center-i, j); SELF.SetCell(center+i, j)
    END
    i += 2
  END
  SELF.SetCell(center-sz, center-sz); SELF.SetCell(center-sz+1, center-sz); SELF.SetCell(center-sz, center-sz+1)
  SELF.SetCell(center+sz, center-sz); SELF.SetCell(center+sz, center-sz+1)
  SELF.SetCell(center+sz, center+sz-1)
  ! ---- full-symbol reference grid ----
  IF compact = 0
    i = 0; j = 0
    LOOP WHILE i < INT(baseMatrixSize/2)-1
      k = BAND(INT(matrixSize/2), 1)
      LOOP WHILE k < matrixSize
        SELF.SetCell(center-j, k); SELF.SetCell(center+j, k)
        SELF.SetCell(k, center-j); SELF.SetCell(k, center+j)
        k += 2
      END
      i += 15; j += 16
    END
  END
  RETURN 1
!---------------------------------------------------------------------------
AppB ROUTINE
  DATA
ai LONG
  CODE
  LOOP ai = apN-1 TO 0 BY -1
    SELF.NBits += 1
    SELF.Bits[SELF.NBits] = BAND(BSHIFT(apV,-ai), 1)
  END
!---------------------------------------------------------------------------
StuffIt ROUTINE
  DATA
si    LONG
sj    LONG
sw    LONG
smask LONG
av    LONG
ak    LONG
  CODE
  SELF.NStuffed = 0
  smask = BSHIFT(1, wordSize) - 2
  si = 0
  LOOP WHILE si < SELF.NBits
    sw = 0
    LOOP sj = 0 TO wordSize-1
      IF si+sj >= SELF.NBits OR SELF.Bits[si+sj+1] = 1
        sw = BOR(sw, BSHIFT(1, wordSize-1-sj))
      END
    END
    IF BAND(sw,smask) = smask
      av = BAND(sw,smask); si += wordSize-1
    ELSIF BAND(sw,smask) = 0
      av = BOR(sw,1); si += wordSize-1
    ELSE
      av = sw; si += wordSize
    END
    LOOP ak = wordSize-1 TO 0 BY -1
      SELF.NStuffed += 1
      SELF.Stuffed[SELF.NStuffed] = BAND(BSHIFT(av,-ak), 1)
    END
  END

!=== drawing (square module grid, same as QRCodeClass) =======================
AztecClass.Paint PROCEDURE(SIGNED pImageFeq,LONG pDark,LONG pLight,LONG pQuiet)
ImgX  LONG
ImgY  LONG
imgW  LONG
imgH  LONG
nn    LONG
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
  nn = SELF.N; side = nn + 2*q
  GETPOSITION(pImageFeq, ImgX, ImgY, imgW, imgH)
  cell = INT(imgW/side); IF INT(imgH/side) < cell THEN cell = INT(imgH/side).
  IF cell < 1 THEN cell = 1.
  qpix = cell*side
  offX = ImgX + INT((imgW-qpix)/2); offY = ImgY + INT((imgH-qpix)/2)
  SETPENCOLOR(pLight)
  BOX(ImgX, ImgY, imgW, imgH, pLight)
  SETPENCOLOR(pDark)
  LOOP r = 0 TO nn-1
    LOOP c = 0 TO nn-1
      IF SELF.Cells[r+1, c+1] = 1
        BOX(offX+(c+q)*cell, offY+(r+q)*cell, cell, cell, pDark)
      END
    END
  END

AztecClass.Draw PROCEDURE(SIGNED pImageFeq,*CSTRING pValue,LONG pDark,LONG pLight,LONG pQuiet)
  CODE
  IF SELF.Build(pValue) = 0 THEN RETURN.
  SETTARGET(,pImageFeq)
  BLANK
  SELF.Paint(pImageFeq, pDark, pLight, pQuiet)
  SETTARGET()
