! ============================================================================
!  QRCodeClass - implementation.  Offline QR-code encoder (see QRCodeClass.inc).
!  Line-for-line port of the ZXing-validated C# reference (QrCodeCore).
!
!  Clarion port notes:
!   - Clarion ROUNDS on integer assignment, so every truncating divide uses INT().
!   - Modulus is SELF.Modulo() (= a - INT(a/b)*b) so no literal '%' is emitted.
!   - Bit ops are functions: BSHIFT(v,n) (+left/-right), BAND, BOR, BXOR.
!   - The maths is 0-based; arrays are 1-based, so accessors add +1 (GetM/SetCell).
!
!  This file MUST be stored in ANSI (not UTF-8).
! ============================================================================
  MEMBER                                  ! bare MEMBER (no parens) so the compiler auto-includes BUILTINS.CLW
                                          ! (LEN, BOX, SETTARGET, GETPOSITION, SETPENCOLOR, BLANK, ...).
                                          ! MEMBER() with empty parens means "member of no program" and
                                          ! suppresses that include, making those library calls "Unknown".

  INCLUDE('QRCodeClass.INC'),ONCE

!=== one-time tables: GF(256), finder patterns, capacity table ===============
QRCodeClass.Init PROCEDURE()
x  LONG
i  LONG
  CODE
  IF SELF.Ready = 1 THEN RETURN.
  x = 1
  LOOP i = 0 TO 254
    SELF.GFExp[i+1] = x
    SELF.GFLog[x+1] = i
    x = BSHIFT(x,1)
    IF BAND(x,0100h) THEN x = BXOR(x,011Dh).
  END
  LOOP i = 255 TO 511
    SELF.GFExp[i+1] = SELF.GFExp[i-255+1]
  END
  SELF.FinderA[1]=1; SELF.FinderA[2]=0; SELF.FinderA[3]=1; SELF.FinderA[4]=1; SELF.FinderA[5]=1; SELF.FinderA[6]=0
  SELF.FinderA[7]=1; SELF.FinderA[8]=0; SELF.FinderA[9]=0; SELF.FinderA[10]=0; SELF.FinderA[11]=0
  SELF.FinderB[1]=0; SELF.FinderB[2]=0; SELF.FinderB[3]=0; SELF.FinderB[4]=0; SELF.FinderB[5]=1; SELF.FinderB[6]=0
  SELF.FinderB[7]=1; SELF.FinderB[8]=1; SELF.FinderB[9]=1; SELF.FinderB[10]=0; SELF.FinderB[11]=1
  ! capacity table [version,ecc]  ecc: 1=L 2=M 3=Q 4=H  (EC/block, G1 blocks/data, G2 blocks/data)
  SELF.Tbl(1,1, 7,1,19,0,0);  SELF.Tbl(1,2,10,1,16,0,0);  SELF.Tbl(1,3,13,1,13,0,0);  SELF.Tbl(1,4,17,1, 9,0,0)
  SELF.Tbl(2,1,10,1,34,0,0);  SELF.Tbl(2,2,16,1,28,0,0);  SELF.Tbl(2,3,22,1,22,0,0);  SELF.Tbl(2,4,28,1,16,0,0)
  SELF.Tbl(3,1,15,1,55,0,0);  SELF.Tbl(3,2,26,1,44,0,0);  SELF.Tbl(3,3,18,2,17,0,0);  SELF.Tbl(3,4,22,2,13,0,0)
  SELF.Tbl(4,1,20,1,80,0,0);  SELF.Tbl(4,2,18,2,32,0,0);  SELF.Tbl(4,3,26,2,24,0,0);  SELF.Tbl(4,4,16,4, 9,0,0)
  SELF.Tbl(5,1,26,1,108,0,0); SELF.Tbl(5,2,24,2,43,0,0);  SELF.Tbl(5,3,18,2,15,2,16); SELF.Tbl(5,4,22,2,11,2,12)
  SELF.Tbl(6,1,18,2,68,0,0);  SELF.Tbl(6,2,16,4,27,0,0);  SELF.Tbl(6,3,24,4,19,0,0);  SELF.Tbl(6,4,28,4,15,0,0)
  SELF.Tbl(7,1,20,2,78,0,0);  SELF.Tbl(7,2,18,4,31,0,0);  SELF.Tbl(7,3,18,2,14,4,15); SELF.Tbl(7,4,26,4,13,1,14)
  SELF.Tbl(8,1,24,2,97,0,0);  SELF.Tbl(8,2,22,2,38,2,39); SELF.Tbl(8,3,22,4,18,2,19); SELF.Tbl(8,4,26,4,14,2,15)
  SELF.Tbl(9,1,30,2,116,0,0); SELF.Tbl(9,2,22,3,36,2,37); SELF.Tbl(9,3,20,4,16,4,17); SELF.Tbl(9,4,24,4,12,4,13)
  SELF.Tbl(10,1,18,2,68,2,69);SELF.Tbl(10,2,26,4,43,1,44);SELF.Tbl(10,3,24,6,19,2,20);SELF.Tbl(10,4,28,6,15,2,16)
  SELF.Ready = 1

QRCodeClass.Tbl PROCEDURE(LONG v,LONG e,LONG ec,LONG g1b,LONG g1d,LONG g2b,LONG g2d)
  CODE
  SELF.TEc[v,e]=ec; SELF.TG1B[v,e]=g1b; SELF.TG1D[v,e]=g1d; SELF.TG2B[v,e]=g2b; SELF.TG2D[v,e]=g2d

!=== GF(256) multiply, integer modulus =======================================
QRCodeClass.GfMul PROCEDURE(LONG a,LONG b)
  CODE
  IF a = 0 OR b = 0 THEN RETURN 0.
  RETURN SELF.GFExp[ SELF.GFLog[a+1] + SELF.GFLog[b+1] + 1 ]

QRCodeClass.Modulo PROCEDURE(LONG a,LONG b)
  CODE
  RETURN a - INT(a/b)*b

!=== module accessors (matrix is 0-based in the maths, +1 for Clarion) ========
QRCodeClass.SetCell PROCEDURE(LONG r,LONG c,LONG v)
  CODE
  SELF.Cells[r+1,c+1] = v
  SELF.Func[r+1,c+1] = 1

QRCodeClass.GetM PROCEDURE(LONG r,LONG c)
  CODE
  RETURN SELF.Cells[r+1,c+1]

QRCodeClass.GetF PROCEDURE(LONG r,LONG c)
  CODE
  RETURN SELF.Func[r+1,c+1]

!=== bit buffer (one byte per bit, MSB-first) ================================
QRCodeClass.AppendBits PROCEDURE(LONG val,LONG n)
i  LONG
  CODE
  LOOP i = n-1 TO 0 BY -1
    SELF.NBits += 1
    SELF.Bits[SELF.NBits] = BAND(BSHIFT(val,-i),1)
  END

!=== Reed-Solomon: SELF.BlkData[1..dataLen] -> SELF.BlkEcc[1..ecLen] =========
QRCodeClass.ReedSolomon PROCEDURE(LONG dataLen,LONG ecLen)
g    LONG,DIM(35)
ng   LONG,DIM(35)
gen  LONG,DIM(35)
res  LONG,DIM(35)
glen LONG
i    LONG
j    LONG
d    LONG
factor LONG
  CODE
  g[1] = 1; glen = 1                                          ! build the generator polynomial
  LOOP i = 0 TO ecLen-1
    LOOP j = 1 TO glen+1; ng[j] = 0; END
    LOOP j = 1 TO glen
      ng[j]   = BXOR(ng[j],   g[j])
      ng[j+1] = BXOR(ng[j+1], SELF.GfMul(g[j], SELF.GFExp[i+1]))
    END
    glen += 1
    LOOP j = 1 TO glen; g[j] = ng[j]; END
  END
  LOOP i = 1 TO ecLen; gen[i] = g[i+1]; END                  ! drop the leading 1
  LOOP i = 1 TO ecLen; res[i] = 0; END                       ! polynomial division
  LOOP d = 1 TO dataLen
    factor = BXOR(SELF.BlkData[d], res[1])
    LOOP i = 1 TO ecLen-1; res[i] = res[i+1]; END
    res[ecLen] = 0
    LOOP i = 1 TO ecLen; res[i] = BXOR(res[i], SELF.GfMul(gen[i], factor)); END
  END
  LOOP i = 1 TO ecLen; SELF.BlkEcc[i] = BAND(res[i],0FFh); END

!=== data masking ============================================================
QRCodeClass.MaskBit PROCEDURE(LONG mask,LONG r,LONG c)
  CODE
  CASE mask
  OF 0; RETURN CHOOSE(SELF.Modulo(r+c,2)=0,1,0)
  OF 1; RETURN CHOOSE(SELF.Modulo(r,2)=0,1,0)
  OF 2; RETURN CHOOSE(SELF.Modulo(c,3)=0,1,0)
  OF 3; RETURN CHOOSE(SELF.Modulo(r+c,3)=0,1,0)
  OF 4; RETURN CHOOSE(SELF.Modulo(INT(r/2)+INT(c/3),2)=0,1,0)
  OF 5; RETURN CHOOSE(SELF.Modulo(r*c,2)+SELF.Modulo(r*c,3)=0,1,0)
  OF 6; RETURN CHOOSE(SELF.Modulo(SELF.Modulo(r*c,2)+SELF.Modulo(r*c,3),2)=0,1,0)
  ELSE; RETURN CHOOSE(SELF.Modulo(SELF.Modulo(r+c,2)+SELF.Modulo(r*c,3),2)=0,1,0)
  END

QRCodeClass.ApplyMask PROCEDURE(LONG mask)
r  LONG
c  LONG
  CODE
  LOOP r = 0 TO SELF.N-1
    LOOP c = 0 TO SELF.N-1
      IF SELF.Func[r+1,c+1] = 1 THEN CYCLE.
      IF SELF.MaskBit(mask,r,c) = 1
        SELF.Cells[r+1,c+1] = CHOOSE(SELF.Cells[r+1,c+1]=0,1,0)
      END
    END
  END

!=== function patterns =======================================================
QRCodeClass.Finder PROCEDURE(LONG r,LONG c)
dr   LONG
dc   LONG
rr   LONG
cc   LONG
dark BYTE
  CODE
  LOOP dr = -1 TO 7
    LOOP dc = -1 TO 7
      rr = r+dr; cc = c+dc
      IF rr<0 OR rr>=SELF.N OR cc<0 OR cc>=SELF.N THEN CYCLE.
      IF dr>=0 AND dr<=6 AND dc>=0 AND dc<=6 AND |
         (dr=0 OR dr=6 OR dc=0 OR dc=6 OR (dr>=2 AND dr<=4 AND dc>=2 AND dc<=4))
        dark = 1
      ELSE
        dark = 0
      END
      SELF.SetCell(rr,cc,dark)
    END
  END

QRCodeClass.Alignment PROCEDURE(LONG r,LONG c)
dr  LONG
dc  LONG
mx  LONG
  CODE
  LOOP dr = -2 TO 2
    LOOP dc = -2 TO 2
      mx = ABS(dr); IF ABS(dc) > mx THEN mx = ABS(dc).
      SELF.SetCell(r+dr,c+dc, CHOOSE(mx<>1,1,0))               ! 5x5 ring with a centre dot
    END
  END

QRCodeClass.FormatInfo PROCEDURE(LONG mask)
ecBits   LONG
dataBits LONG
rem      LONG
bch      LONG
i        LONG
n        LONG
  CODE
  n = SELF.N
  CASE SELF.Ecc                                              ! format ECC bits: L=01 M=00 Q=11 H=10
  OF 1; ecBits = 1
  OF 2; ecBits = 0
  OF 3; ecBits = 3
  ELSE; ecBits = 2
  END
  dataBits = BOR(BSHIFT(ecBits,3), mask)
  rem = dataBits
  LOOP i = 0 TO 9
    rem = BXOR(BSHIFT(rem,1), BSHIFT(rem,-9)*0537h)
  END
  bch = BXOR( BOR(BSHIFT(dataBits,10), rem), 05412h)
  LOOP i = 0 TO 5
    SELF.Cells[i+1,9] = BAND(BSHIFT(bch,-i),1)
  END
  SELF.Cells[8,9] = BAND(BSHIFT(bch,-6),1)
  SELF.Cells[9,9] = BAND(BSHIFT(bch,-7),1)
  SELF.Cells[9,8] = BAND(BSHIFT(bch,-8),1)
  LOOP i = 9 TO 14
    SELF.Cells[9,(14-i)+1] = BAND(BSHIFT(bch,-i),1)
  END
  LOOP i = 0 TO 7
    SELF.Cells[9,n-1-i+1] = BAND(BSHIFT(bch,-i),1)
  END
  LOOP i = 8 TO 14
    SELF.Cells[n-15+i+1,9] = BAND(BSHIFT(bch,-i),1)
  END
  SELF.Cells[n-8+1,9] = 1                                     ! the always-dark module

!=== penalty scoring (mask selection) ========================================
QRCodeClass.LineRuns PROCEDURE(LONG idx,LONG isRow)
p    LONG
run  LONG
k    LONG
prev BYTE
cur  BYTE
  CODE
  p = 0; run = 1
  prev = CHOOSE(isRow=1, SELF.Cells[idx+1,1], SELF.Cells[1,idx+1])
  LOOP k = 1 TO SELF.N-1
    cur = CHOOSE(isRow=1, SELF.Cells[idx+1,k+1], SELF.Cells[k+1,idx+1])
    IF cur = prev
      run += 1
    ELSE
      IF run >= 5 THEN p += 3 + (run-5).
      run = 1; prev = cur
    END
  END
  IF run >= 5 THEN p += 3 + (run-5).
  RETURN p

QRCodeClass.MatchFinder PROCEDURE(LONG a,LONG b,LONG isRow)
i   LONG
v   BYTE
okA BYTE
okB BYTE
  CODE
  okA = 1; okB = 1
  LOOP i = 0 TO 10
    IF isRow = 1
      v = SELF.GetM(a, b+i)
    ELSE
      v = SELF.GetM(b+i, a)
    END
    IF v <> SELF.FinderA[i+1] THEN okA = 0.
    IF v <> SELF.FinderB[i+1] THEN okB = 0.
  END
  RETURN CHOOSE(okA=1 OR okB=1, 1, 0)

QRCodeClass.Penalty PROCEDURE()
p    LONG
r    LONG
c    LONG
n    LONG
dark LONG
pct  LONG
prev LONG
a    LONG
bb   LONG
  CODE
  n = SELF.N; p = 0
  LOOP r = 0 TO n-1; p += SELF.LineRuns(r,1); END             ! rule 1: runs of 5+
  LOOP c = 0 TO n-1; p += SELF.LineRuns(c,0); END
  LOOP r = 0 TO n-2                                           ! rule 2: 2x2 blocks
    LOOP c = 0 TO n-2
      IF SELF.Cells[r+1,c+1]=SELF.Cells[r+1,c+2] AND SELF.Cells[r+1,c+1]=SELF.Cells[r+2,c+1] AND SELF.Cells[r+1,c+1]=SELF.Cells[r+2,c+2]
        p += 3
      END
    END
  END
  LOOP r = 0 TO n-1                                           ! rule 3: finder-like, horizontal
    LOOP c = 0 TO n-11
      IF SELF.MatchFinder(r,c,1) THEN p += 40.
    END
  END
  LOOP c = 0 TO n-1                                           ! rule 3: finder-like, vertical
    LOOP r = 0 TO n-11
      IF SELF.MatchFinder(c,r,0) THEN p += 40.
    END
  END
  dark = 0                                                    ! rule 4: dark-module proportion
  LOOP r = 0 TO n-1
    LOOP c = 0 TO n-1
      IF SELF.Cells[r+1,c+1] = 1 THEN dark += 1.
    END
  END
  pct = INT(dark*100/(n*n))
  prev = INT(pct/5)*5
  a = ABS(prev-50); bb = ABS(prev+5-50)
  IF bb < a THEN a = bb.
  p += INT(a/5)*10
  RETURN p

!=== the encoder: value -> SELF.Cells / SELF.N  (returns 1 ok, 0 = too large) =
QRCodeClass.BuildMatrix PROCEDURE(*CSTRING pValue,LONG pEcc)
v        LONG
cap      LONG
ec       LONG
pos      LONG
bcount   LONG
gb       LONG
blkLen   LONG
maxData  LONG
i        LONG
j        LONG
b        LONG
capBits  LONG
term     LONG
padb     LONG
padTog   LONG
bit      LONG
total    LONG
col      LONG
t        LONG
row      LONG
cc2      LONG
cc       LONG
byteIdx  LONG
shift    LONG
dark     BYTE
upward   BYTE
mask     LONG
pp       LONG
bestP    LONG
rem      LONG
fbits    LONG
ai       LONG
aj       LONG
ar       LONG
ac       LONG
  CODE
  SELF.Init()
  SELF.Ecc = pEcc
  SELF.DLen = LEN(pValue)
  SELF.Ver = 0                                               ! ---- choose the smallest version that fits
  LOOP v = 1 TO 10
    SELF.TotalData = SELF.TG1B[v,SELF.Ecc]*SELF.TG1D[v,SELF.Ecc] + SELF.TG2B[v,SELF.Ecc]*SELF.TG2D[v,SELF.Ecc]
    SELF.CCBits = CHOOSE(v<=9, 8, 16)
    cap = INT( (SELF.TotalData*8 - 4 - SELF.CCBits) / 8 )
    IF cap < 0 THEN cap = 0.
    IF SELF.DLen <= cap
      SELF.Ver = v; BREAK
    END
  END
  IF SELF.Ver = 0 THEN RETURN 0.                             ! data too large for v1-10 at this ECC
  SELF.TotalData = SELF.TG1B[SELF.Ver,SELF.Ecc]*SELF.TG1D[SELF.Ver,SELF.Ecc] + SELF.TG2B[SELF.Ver,SELF.Ecc]*SELF.TG2D[SELF.Ver,SELF.Ecc]
  SELF.CCBits = CHOOSE(SELF.Ver<=9, 8, 16)
  SELF.N = 17 + 4*SELF.Ver
  CLEAR(SELF.Cells); CLEAR(SELF.Func)
  ! ---- data codewords: mode + count + bytes + terminator + pad ----
  SELF.NBits = 0
  SELF.AppendBits(4, 4)                                      ! byte mode indicator
  SELF.AppendBits(SELF.DLen, SELF.CCBits)                    ! character count
  LOOP i = 1 TO SELF.DLen
    SELF.AppendBits(VAL(pValue[i]), 8)
  END
  capBits = SELF.TotalData*8
  term = capBits - SELF.NBits
  IF term > 4 THEN term = 4.
  IF term < 0 THEN term = 0.
  SELF.AppendBits(0, term)
  padb = SELF.Modulo(SELF.NBits,8); IF padb <> 0 THEN SELF.AppendBits(0, 8-padb).
  SELF.DataLen = 0                                           ! pack the bit buffer into bytes
  LOOP i = 1 TO SELF.NBits BY 8
    b = 0
    LOOP j = 0 TO 7
      IF i+j <= SELF.NBits AND SELF.Bits[i+j] = 1
        b = BOR(b, BSHIFT(1, 7-j))
      END
    END
    SELF.DataLen += 1; SELF.DataCW[SELF.DataLen] = b
  END
  padTog = 0                                                 ! alternating pad bytes EC / 11
  LOOP WHILE SELF.DataLen < SELF.TotalData
    SELF.DataLen += 1
    SELF.DataCW[SELF.DataLen] = CHOOSE(SELF.Modulo(padTog,2)=0, 0ECh, 011h)
    padTog += 1
  END
  ! ---- error correction + interleaving ----
  ec = SELF.TEc[SELF.Ver,SELF.Ecc]; SELF.EcLen = ec
  pos = 0; bcount = 0
  LOOP gb = 1 TO SELF.TG1B[SELF.Ver,SELF.Ecc]                ! group 1 blocks
    bcount += 1; blkLen = SELF.TG1D[SELF.Ver,SELF.Ecc]
    SELF.BlkLenArr[bcount] = blkLen
    LOOP i = 1 TO blkLen; SELF.BlkData[i] = SELF.DataCW[pos+i]; END
    pos += blkLen
    SELF.ReedSolomon(blkLen, ec)
    LOOP i = 1 TO blkLen; SELF.DataBlk[bcount,i] = SELF.BlkData[i]; END
    LOOP i = 1 TO ec; SELF.EccBlk[bcount,i] = SELF.BlkEcc[i]; END
  END
  LOOP gb = 1 TO SELF.TG2B[SELF.Ver,SELF.Ecc]                ! group 2 blocks
    bcount += 1; blkLen = SELF.TG2D[SELF.Ver,SELF.Ecc]
    SELF.BlkLenArr[bcount] = blkLen
    LOOP i = 1 TO blkLen; SELF.BlkData[i] = SELF.DataCW[pos+i]; END
    pos += blkLen
    SELF.ReedSolomon(blkLen, ec)
    LOOP i = 1 TO blkLen; SELF.DataBlk[bcount,i] = SELF.BlkData[i]; END
    LOOP i = 1 TO ec; SELF.EccBlk[bcount,i] = SELF.BlkEcc[i]; END
  END
  SELF.NumBlocks = bcount
  maxData = SELF.TG1D[SELF.Ver,SELF.Ecc]
  IF SELF.TG2D[SELF.Ver,SELF.Ecc] > maxData THEN maxData = SELF.TG2D[SELF.Ver,SELF.Ecc].
  SELF.CWLen = 0
  LOOP i = 1 TO maxData                                      ! interleave data codewords
    LOOP b = 1 TO bcount
      IF i <= SELF.BlkLenArr[b]
        SELF.CWLen += 1; SELF.CW[SELF.CWLen] = SELF.DataBlk[b,i]
      END
    END
  END
  LOOP i = 1 TO ec                                           ! then interleave EC codewords
    LOOP b = 1 TO bcount
      SELF.CWLen += 1; SELF.CW[SELF.CWLen] = SELF.EccBlk[b,i]
    END
  END
  ! ---- function patterns ----
  LOOP i = 0 TO SELF.N-1                                     ! timing patterns
    SELF.SetCell(6,i, CHOOSE(SELF.Modulo(i,2)=0,1,0))
    SELF.SetCell(i,6, CHOOSE(SELF.Modulo(i,2)=0,1,0))
  END
  SELF.Finder(0,0); SELF.Finder(0,SELF.N-7); SELF.Finder(SELF.N-7,0)   ! finder patterns
  CASE SELF.Ver                                              ! alignment-pattern centres
  OF 1; SELF.NAlign = 0
  OF 2; SELF.NAlign = 2; SELF.Align[1]=6; SELF.Align[2]=18
  OF 3; SELF.NAlign = 2; SELF.Align[1]=6; SELF.Align[2]=22
  OF 4; SELF.NAlign = 2; SELF.Align[1]=6; SELF.Align[2]=26
  OF 5; SELF.NAlign = 2; SELF.Align[1]=6; SELF.Align[2]=30
  OF 6; SELF.NAlign = 2; SELF.Align[1]=6; SELF.Align[2]=34
  OF 7; SELF.NAlign = 3; SELF.Align[1]=6; SELF.Align[2]=22; SELF.Align[3]=38
  OF 8; SELF.NAlign = 3; SELF.Align[1]=6; SELF.Align[2]=24; SELF.Align[3]=42
  OF 9; SELF.NAlign = 3; SELF.Align[1]=6; SELF.Align[2]=26; SELF.Align[3]=46
  ELSE; SELF.NAlign = 3; SELF.Align[1]=6; SELF.Align[2]=28; SELF.Align[3]=50
  END
  LOOP ai = 1 TO SELF.NAlign
    LOOP aj = 1 TO SELF.NAlign
      ar = SELF.Align[ai]; ac = SELF.Align[aj]
      IF (ar<=7 AND ac<=7) OR (ar<=7 AND ac>=SELF.N-8) OR (ar>=SELF.N-8 AND ac<=7) THEN CYCLE.
      SELF.Alignment(ar,ac)
    END
  END
  SELF.SetCell(SELF.N-8,8,1)                                 ! dark module
  LOOP i = 0 TO 8                                            ! reserve format-info area
    SELF.Func[8+1,i+1] = 1; SELF.Func[i+1,8+1] = 1
  END
  LOOP i = 0 TO 7
    SELF.Func[8+1,SELF.N-1-i+1] = 1; SELF.Func[SELF.N-1-i+1,8+1] = 1
  END
  IF SELF.Ver >= 7                                           ! version info (v7+), 18-bit BCH
    rem = SELF.Ver
    LOOP i = 0 TO 11
      rem = BXOR(BSHIFT(rem,1), BSHIFT(rem,-11)*01F25h)
    END
    fbits = BOR(BSHIFT(SELF.Ver,12), rem)
    LOOP i = 0 TO 17
      SELF.SetCell(SELF.N-11+SELF.Modulo(i,3), INT(i/3), BAND(BSHIFT(fbits,-i),1))
      SELF.SetCell(INT(i/3), SELF.N-11+SELF.Modulo(i,3), BAND(BSHIFT(fbits,-i),1))
    END
  END
  ! ---- place the codeword bits (zig-zag, skipping function modules) ----
  bit = 0; total = SELF.CWLen*8
  col = SELF.N-1
  LOOP WHILE col > 0
    IF col = 6 THEN col -= 1.                                ! skip the vertical timing column
    LOOP t = 0 TO SELF.N-1
      upward = CHOOSE( SELF.Modulo(INT((SELF.N-1-col)/2),2)=0, 1, 0)
      row = CHOOSE(upward=1, SELF.N-1-t, t)
      LOOP cc2 = 0 TO 1
        cc = col - cc2
        IF SELF.Func[row+1,cc+1] = 1 THEN CYCLE.
        IF bit < total
          byteIdx = INT(bit/8)+1
          shift = -(7 - SELF.Modulo(bit,8))
          dark = BAND(BSHIFT(SELF.CW[byteIdx], shift),1)
        ELSE
          dark = 0
        END
        SELF.Cells[row+1,cc+1] = dark
        bit += 1
      END
    END
    col -= 2
  END
  ! ---- choose the mask with the lowest penalty ----
  SELF.BestMask = 0; bestP = 2147483647
  LOOP mask = 0 TO 7
    SELF.ApplyMask(mask)
    SELF.FormatInfo(mask)                                    ! rule 3 looks at the whole symbol
    pp = SELF.Penalty()
    IF pp < bestP
      bestP = pp; SELF.BestMask = mask
    END
    SELF.ApplyMask(mask)                                     ! XOR again to revert
  END
  SELF.ApplyMask(SELF.BestMask)                              ! leave the winner applied
  SELF.FormatInfo(SELF.BestMask)                             ! final format info
  RETURN 1

!=== paint the already-built matrix into a control, in the CURRENT target =====
QRCodeClass.Paint PROCEDURE(SIGNED pImageFeq,LONG pDark,LONG pLight,LONG pQuiet)
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
  GETPOSITION(pImageFeq,ImgX,ImgY,imgW,imgH)                 ! position AND size, target-relative
  cell = INT(imgW/side); IF INT(imgH/side) < cell THEN cell = INT(imgH/side).
  IF cell < 1 THEN cell = 1.                                 ! at least 1 unit per module
  qpix = cell*side
  offX = ImgX + INT((imgW-qpix)/2); offY = ImgY + INT((imgH-qpix)/2)   ! centre in the control
  SETPENCOLOR(pLight)
  BOX(ImgX,ImgY,imgW,imgH,pLight)                            ! light field (quiet zone is light too)
  SETPENCOLOR(pDark)
  LOOP r = 0 TO n-1
    LOOP c = 0 TO n-1
      IF SELF.Cells[r+1,c+1] = 1
        BOX(offX+(c+q)*cell, offY+(r+q)*cell, cell, cell, pDark)
      END
    END
  END

!=== the window helper: encode + draw into a window IMAGE control =============
QRCodeClass.Draw PROCEDURE(SIGNED pImageFeq,*CSTRING pValue,LONG pEcc,LONG pDark,LONG pLight,LONG pQuiet)
  CODE
  IF SELF.BuildMatrix(pValue,pEcc) = 0 THEN RETURN.          ! too large - leave the control unchanged
  SETTARGET(,pImageFeq)                                       ! draw into the IMAGE control (window-relative, issue #5)
  BLANK                                                       ! wipe prior graphics (no resize artifacts)
  SELF.Paint(pImageFeq,pDark,pLight,pQuiet)
  SETTARGET()                                                 ! restore previous target
