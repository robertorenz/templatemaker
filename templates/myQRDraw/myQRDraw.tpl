#TEMPLATE(myQRDraw,'myQRDraw - Draw a QR Code into a Window (offline, no internet) - v1.0'),FAMILY('ABC')
#!-----------------------------------------------------------------------------
#!  myQRDraw template set  -  OFFLINE QR codes drawn with BOX primitives.
#!
#!  Unlike templates/myQR (which fetches a PNG from api.qrserver.com via curl),
#!  this set ENCODES the QR symbol itself at run time and draws every module as
#!  a filled BOX into an IMAGE control - exactly like myPie draws a pie. No
#!  internet, no curl, no temp files.
#!
#!  myQRDrawGlobal (APPLICATION extension) - adds the self-contained encoder
#!               (byte mode, versions 1-10, ECC L/M/Q/H, automatic version +
#!               mask) and the QRDraw() helper. Add once, globally.
#!
#!  myQRDraw     (PROCEDURE extension) - dropped on a WINDOW. Encodes a value
#!               (literal or code-driven) and draws it into a chosen IMAGE
#!               control, redrawing on OpenWindow / resize. Exposes a
#!               myQRDrawRepaint ROUTINE so you can change the value at run time.
#!
#!  myQRDrawReport (PROCEDURE extension) - dropped on a REPORT. Draws the code
#!               into an IMAGE control in a band as each record prints. Reports
#!               do NOT use window events: drawing happens in the Before-Print
#!               embed with SETTARGET(Report) (the band's own target), not on
#!               OpenWindow. Use THIS extension on reports, myQRDraw on windows.
#!
#!  This is a line-for-line port of the C# reference encoder in
#!  designer/QrCodeCore (validated by decoding with ZXing). Its module output
#!  is pinned by GoldenMatrixTests: "HELLO WORLD" at ECC M -> the 21x21 symbol
#!  the Self-test option draws, so a phone scan that reads "HELLO WORLD" proves
#!  this port matches the tested encoder.
#!
#!  VERIFIED corpus facts (shared with myPie):
#!    BOX(x,y,w,h,fill)                      builtins.clw:467   - dialog units
#!    SETTARGET(window,?image)                                   - draw into IMAGE
#!    GETPOSITION(?image,x,y)                                    - control X,Y in window
#!    SETPENCOLOR(color) / BLANK / SETTARGET()
#!  Bit ops: BSHIFT(v,n) (+left/-right), BAND, BOR, BXOR.  Integer truncation:
#!  Clarion ROUNDS on assignment, so every truncating divide uses INT(); modulus
#!  is QRMod() (= a - INT(a/b)*b) so NO literal '%' appears in emitted code.
#!
#!  Issue #5 (myPie): SETTARGET(,?image) is WINDOW-relative, so we GETPOSITION
#!  the image and draw at its X,Y.
#!-----------------------------------------------------------------------------
#!#############################################################################
#!  GLOBAL EXTENSION - myQRDrawGlobal
#!#############################################################################
#EXTENSION(myQRDrawGlobal,'myQRDraw - Global Encoder + Helper (add once per application)'),APPLICATION
#SHEET
  #TAB('&General')
    #BOXED('myQRDraw')
      #DISPLAY('myQRDraw Global Encoder + Helper - Version 1.0')
      #DISPLAY('Adds a self-contained QR encoder and the QRDraw() helper.')
      #DISPLAY('No internet / curl needed - the symbol is drawn with BOXes.')
      #DISPLAY('Add this extension once, at the Application (global) level.')
    #ENDBOXED
    #BOXED('Options')
      #PROMPT('&Disable this template',CHECK),%myQRDrawDisable,DEFAULT(0),AT(10)
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#! Global working data for the encoder (declared once). Prefix QR: avoids
#! clashes. Sized for the largest supported symbol (version 10 = 57x57).
#!-----------------------------------------------------------------------------
#AT(%GlobalData),WHERE(%myQRDrawDisable=0)
QR:Ready             BYTE                                     ! 1 once tables are built
QR:Exp               LONG,DIM(512)                            ! GF(256) antilog
QR:Log               LONG,DIM(256)                            ! GF(256) log  (Log[value+1])
QR:FinderA           BYTE,DIM(11)                             ! 1:1:3:1:1 finder-like patterns (penalty rule 3)
QR:FinderB           BYTE,DIM(11)
QR:T_Ec              LONG,DIM(10,4)                           ! capacity table [version,ecc(1=L..4=H)]
QR:T_G1B             LONG,DIM(10,4)                           !   EC-per-block, group-1 blocks/data,
QR:T_G1D             LONG,DIM(10,4)                           !   group-2 blocks/data
QR:T_G2B             LONG,DIM(10,4)
QR:T_G2D             LONG,DIM(10,4)
QR:Mod               BYTE,DIM(57,57)                          ! module matrix (1=dark), [row+1,col+1]
QR:Fnc               BYTE,DIM(57,57)                          ! function-module map (1=reserved)
QR:N                 LONG                                     ! current dimension (17+4*version)
QR:Ver               LONG                                     ! chosen version 1-10
QR:Ecc               LONG                                     ! 1=L 2=M 3=Q 4=H
QR:DLen              LONG                                     ! data byte count
QR:TotalData         LONG                                     ! data codewords for version+ecc
QR:CCBits            LONG                                     ! char-count field width (8 or 16)
QR:NBits             LONG                                     ! bits appended so far
QR:Bits              BYTE,DIM(3000)                           ! one byte per appended bit (0/1)
QR:Data              BYTE,DIM(400)                            ! packed data codewords
QR:DataLen           LONG
QR:CW                BYTE,DIM(400)                            ! interleaved data+EC codewords
QR:CWLen             LONG
QR:EcLen             LONG                                     ! EC codewords per block
QR:BestMask          LONG                                     ! chosen mask 0-7
QR:BlkData           BYTE,DIM(130)                            ! one data block (RS input)
QR:BlkEcc            BYTE,DIM(31)                             ! one block's EC (RS output)
QR:DataBlk           BYTE,DIM(8,130)                          ! all data blocks
QR:EccBlk            BYTE,DIM(8,31)                           ! all EC blocks
QR:BlkLenArr         LONG,DIM(8)                              ! data length of each block
QR:NumBlocks         LONG
QR:Align             LONG,DIM(3)                              ! alignment-pattern centres
QR:NAlign            LONG
#ENDAT
#!-----------------------------------------------------------------------------
#! Short-form prototypes in the global map (survive auto-indent).
#!-----------------------------------------------------------------------------
#AT(%GlobalMap),WHERE(%myQRDrawDisable=0)
QRDraw(SIGNED,*CSTRING,LONG,LONG,LONG,LONG)
QRPaint(SIGNED,LONG,LONG,LONG)
QRBuildMatrix(*CSTRING,LONG),BYTE
QRInit()
QRtbl(LONG,LONG,LONG,LONG,LONG,LONG,LONG)
QRGfMul(LONG,LONG),LONG
QRMod(LONG,LONG),LONG
QRMaskBit(LONG,LONG,LONG),BYTE
QRApplyMask(LONG)
QRFinder(LONG,LONG)
QRAlignment(LONG,LONG)
QRSet(LONG,LONG,LONG)
QRGetM(LONG,LONG),BYTE
QRGetF(LONG,LONG),BYTE
QRAppendBits(LONG,LONG)
QRReedSolomon(LONG,LONG)
QRFormatInfo(LONG)
QRPenalty(),LONG
QRLineRuns(LONG,LONG),LONG
QRMatchFinder(LONG,LONG,LONG),BYTE
#ENDAT
#!-----------------------------------------------------------------------------
#! Encoder + helper bodies (%ProgramProcedures is NOT auto-indented - labels in
#! column 1, code indented). EXE-only region; for multi-DLL move to the root.
#!-----------------------------------------------------------------------------
#AT(%ProgramProcedures),WHERE(%myQRDrawDisable=0)
#!=== one-time tables: GF(256), finder patterns, capacity table ===============
QRInit  PROCEDURE()
x  LONG
i  LONG
  CODE
  IF QR:Ready = 1 THEN RETURN.
  x = 1
  LOOP i = 0 TO 254
    QR:Exp[i+1] = x
    QR:Log[x+1] = i
    x = BSHIFT(x,1)
    IF BAND(x,0100h) THEN x = BXOR(x,011Dh).
  END
  LOOP i = 255 TO 511
    QR:Exp[i+1] = QR:Exp[i-255+1]
  END
  QR:FinderA[1]=1; QR:FinderA[2]=0; QR:FinderA[3]=1; QR:FinderA[4]=1; QR:FinderA[5]=1; QR:FinderA[6]=0
  QR:FinderA[7]=1; QR:FinderA[8]=0; QR:FinderA[9]=0; QR:FinderA[10]=0; QR:FinderA[11]=0
  QR:FinderB[1]=0; QR:FinderB[2]=0; QR:FinderB[3]=0; QR:FinderB[4]=0; QR:FinderB[5]=1; QR:FinderB[6]=0
  QR:FinderB[7]=1; QR:FinderB[8]=1; QR:FinderB[9]=1; QR:FinderB[10]=0; QR:FinderB[11]=1
  ! capacity table [version,ecc]  ecc: 1=L 2=M 3=Q 4=H  (EC/block, G1 blocks/data, G2 blocks/data)
  QRtbl(1,1, 7,1,19,0,0);  QRtbl(1,2,10,1,16,0,0);  QRtbl(1,3,13,1,13,0,0);  QRtbl(1,4,17,1, 9,0,0)
  QRtbl(2,1,10,1,34,0,0);  QRtbl(2,2,16,1,28,0,0);  QRtbl(2,3,22,1,22,0,0);  QRtbl(2,4,28,1,16,0,0)
  QRtbl(3,1,15,1,55,0,0);  QRtbl(3,2,26,1,44,0,0);  QRtbl(3,3,18,2,17,0,0);  QRtbl(3,4,22,2,13,0,0)
  QRtbl(4,1,20,1,80,0,0);  QRtbl(4,2,18,2,32,0,0);  QRtbl(4,3,26,2,24,0,0);  QRtbl(4,4,16,4, 9,0,0)
  QRtbl(5,1,26,1,108,0,0); QRtbl(5,2,24,2,43,0,0);  QRtbl(5,3,18,2,15,2,16); QRtbl(5,4,22,2,11,2,12)
  QRtbl(6,1,18,2,68,0,0);  QRtbl(6,2,16,4,27,0,0);  QRtbl(6,3,24,4,19,0,0);  QRtbl(6,4,28,4,15,0,0)
  QRtbl(7,1,20,2,78,0,0);  QRtbl(7,2,18,4,31,0,0);  QRtbl(7,3,18,2,14,4,15); QRtbl(7,4,26,4,13,1,14)
  QRtbl(8,1,24,2,97,0,0);  QRtbl(8,2,22,2,38,2,39); QRtbl(8,3,22,4,18,2,19); QRtbl(8,4,26,4,14,2,15)
  QRtbl(9,1,30,2,116,0,0); QRtbl(9,2,22,3,36,2,37); QRtbl(9,3,20,4,16,4,17); QRtbl(9,4,24,4,12,4,13)
  QRtbl(10,1,18,2,68,2,69);QRtbl(10,2,26,4,43,1,44);QRtbl(10,3,24,6,19,2,20);QRtbl(10,4,28,6,15,2,16)
  QR:Ready = 1
#!
QRtbl  PROCEDURE(LONG v,LONG e,LONG ec,LONG g1b,LONG g1d,LONG g2b,LONG g2d)
  CODE
  QR:T_Ec[v,e]=ec; QR:T_G1B[v,e]=g1b; QR:T_G1D[v,e]=g1d; QR:T_G2B[v,e]=g2b; QR:T_G2D[v,e]=g2d
#!
#!=== GF(256) multiply, integer modulus =======================================
QRGfMul  PROCEDURE(LONG a,LONG b)
  CODE
  IF a = 0 OR b = 0 THEN RETURN 0.
  RETURN QR:Exp[ QR:Log[a+1] + QR:Log[b+1] + 1 ]
#!
QRMod  PROCEDURE(LONG a,LONG b)
  CODE
  RETURN a - INT(a/b)*b
#!
#!=== module accessors (matrix is 0-based in the maths, +1 for Clarion) ========
QRSet  PROCEDURE(LONG r,LONG c,LONG v)
  CODE
  QR:Mod[r+1,c+1] = v
  QR:Fnc[r+1,c+1] = 1
#!
QRGetM  PROCEDURE(LONG r,LONG c)
  CODE
  RETURN QR:Mod[r+1,c+1]
#!
QRGetF  PROCEDURE(LONG r,LONG c)
  CODE
  RETURN QR:Fnc[r+1,c+1]
#!
#!=== bit buffer (one byte per bit, MSB-first) ================================
QRAppendBits  PROCEDURE(LONG val,LONG n)
i  LONG
  CODE
  LOOP i = n-1 TO 0 BY -1
    QR:NBits += 1
    QR:Bits[QR:NBits] = BAND(BSHIFT(val,-i),1)
  END
#!
#!=== Reed-Solomon: QR:BlkData[1..dataLen] -> QR:BlkEcc[1..ecLen] =============
QRReedSolomon  PROCEDURE(LONG dataLen,LONG ecLen)
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
      ng[j+1] = BXOR(ng[j+1], QRGfMul(g[j], QR:Exp[i+1]))
    END
    glen += 1
    LOOP j = 1 TO glen; g[j] = ng[j]; END
  END
  LOOP i = 1 TO ecLen; gen[i] = g[i+1]; END                  ! drop the leading 1
  LOOP i = 1 TO ecLen; res[i] = 0; END                       ! polynomial division
  LOOP d = 1 TO dataLen
    factor = BXOR(QR:BlkData[d], res[1])
    LOOP i = 1 TO ecLen-1; res[i] = res[i+1]; END
    res[ecLen] = 0
    LOOP i = 1 TO ecLen; res[i] = BXOR(res[i], QRGfMul(gen[i], factor)); END
  END
  LOOP i = 1 TO ecLen; QR:BlkEcc[i] = BAND(res[i],0FFh); END
#!
#!=== data masking ============================================================
QRMaskBit  PROCEDURE(LONG mask,LONG r,LONG c)
  CODE
  CASE mask
  OF 0; RETURN CHOOSE(QRMod(r+c,2)=0,1,0)
  OF 1; RETURN CHOOSE(QRMod(r,2)=0,1,0)
  OF 2; RETURN CHOOSE(QRMod(c,3)=0,1,0)
  OF 3; RETURN CHOOSE(QRMod(r+c,3)=0,1,0)
  OF 4; RETURN CHOOSE(QRMod(INT(r/2)+INT(c/3),2)=0,1,0)
  OF 5; RETURN CHOOSE(QRMod(r*c,2)+QRMod(r*c,3)=0,1,0)
  OF 6; RETURN CHOOSE(QRMod(QRMod(r*c,2)+QRMod(r*c,3),2)=0,1,0)
  ELSE; RETURN CHOOSE(QRMod(QRMod(r+c,2)+QRMod(r*c,3),2)=0,1,0)
  END
#!
QRApplyMask  PROCEDURE(LONG mask)
r  LONG
c  LONG
  CODE
  LOOP r = 0 TO QR:N-1
    LOOP c = 0 TO QR:N-1
      IF QR:Fnc[r+1,c+1] = 1 THEN CYCLE.
      IF QRMaskBit(mask,r,c) = 1
        QR:Mod[r+1,c+1] = CHOOSE(QR:Mod[r+1,c+1]=0,1,0)
      END
    END
  END
#!
#!=== function patterns =======================================================
QRFinder  PROCEDURE(LONG r,LONG c)
dr  LONG
dc  LONG
rr  LONG
cc  LONG
dark BYTE
  CODE
  LOOP dr = -1 TO 7
    LOOP dc = -1 TO 7
      rr = r+dr; cc = c+dc
      IF rr<0 OR rr>=QR:N OR cc<0 OR cc>=QR:N THEN CYCLE.
      IF dr>=0 AND dr<=6 AND dc>=0 AND dc<=6 AND |
         (dr=0 OR dr=6 OR dc=0 OR dc=6 OR (dr>=2 AND dr<=4 AND dc>=2 AND dc<=4))
        dark = 1
      ELSE
        dark = 0
      END
      QRSet(rr,cc,dark)
    END
  END
#!
QRAlignment  PROCEDURE(LONG r,LONG c)
dr  LONG
dc  LONG
mx  LONG
  CODE
  LOOP dr = -2 TO 2
    LOOP dc = -2 TO 2
      mx = ABS(dr); IF ABS(dc) > mx THEN mx = ABS(dc).
      QRSet(r+dr,c+dc, CHOOSE(mx<>1,1,0))                     ! 5x5 ring with a centre dot
    END
  END
#!
QRFormatInfo  PROCEDURE(LONG mask)
ecBits LONG
data   LONG
rem    LONG
bits   LONG
i      LONG
n      LONG
  CODE
  n = QR:N
  CASE QR:Ecc                                                ! format ECC bits: L=01 M=00 Q=11 H=10
  OF 1; ecBits = 1
  OF 2; ecBits = 0
  OF 3; ecBits = 3
  ELSE; ecBits = 2
  END
  data = BOR(BSHIFT(ecBits,3), mask)
  rem = data
  LOOP i = 0 TO 9
    rem = BXOR(BSHIFT(rem,1), BSHIFT(rem,-9)*0537h)
  END
  bits = BXOR( BOR(BSHIFT(data,10), rem), 05412h)
  LOOP i = 0 TO 5
    QR:Mod[i+1,9] = BAND(BSHIFT(bits,-i),1)
  END
  QR:Mod[8,9] = BAND(BSHIFT(bits,-6),1)
  QR:Mod[9,9] = BAND(BSHIFT(bits,-7),1)
  QR:Mod[9,8] = BAND(BSHIFT(bits,-8),1)
  LOOP i = 9 TO 14
    QR:Mod[9,(14-i)+1] = BAND(BSHIFT(bits,-i),1)
  END
  LOOP i = 0 TO 7
    QR:Mod[9,n-1-i+1] = BAND(BSHIFT(bits,-i),1)
  END
  LOOP i = 8 TO 14
    QR:Mod[n-15+i+1,9] = BAND(BSHIFT(bits,-i),1)
  END
  QR:Mod[n-8+1,9] = 1                                         ! the always-dark module
#!
#!=== penalty scoring (mask selection) ========================================
QRLineRuns  PROCEDURE(LONG idx,LONG isRow)
p    LONG
run  LONG
k    LONG
prev BYTE
cur  BYTE
  CODE
  p = 0; run = 1
  prev = CHOOSE(isRow=1, QR:Mod[idx+1,1], QR:Mod[1,idx+1])
  LOOP k = 1 TO QR:N-1
    cur = CHOOSE(isRow=1, QR:Mod[idx+1,k+1], QR:Mod[k+1,idx+1])
    IF cur = prev
      run += 1
    ELSE
      IF run >= 5 THEN p += 3 + (run-5).
      run = 1; prev = cur
    END
  END
  IF run >= 5 THEN p += 3 + (run-5).
  RETURN p
#!
QRMatchFinder  PROCEDURE(LONG a,LONG b,LONG isRow)
i   LONG
v   BYTE
okA BYTE
okB BYTE
  CODE
  okA = 1; okB = 1
  LOOP i = 0 TO 10
    IF isRow = 1
      v = QRGetM(a, b+i)
    ELSE
      v = QRGetM(b+i, a)
    END
    IF v <> QR:FinderA[i+1] THEN okA = 0.
    IF v <> QR:FinderB[i+1] THEN okB = 0.
  END
  RETURN CHOOSE(okA=1 OR okB=1, 1, 0)
#!
QRPenalty  PROCEDURE()
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
  n = QR:N; p = 0
  LOOP r = 0 TO n-1; p += QRLineRuns(r,1); END               ! rule 1: runs of 5+
  LOOP c = 0 TO n-1; p += QRLineRuns(c,0); END
  LOOP r = 0 TO n-2                                           ! rule 2: 2x2 blocks
    LOOP c = 0 TO n-2
      IF QR:Mod[r+1,c+1]=QR:Mod[r+1,c+2] AND QR:Mod[r+1,c+1]=QR:Mod[r+2,c+1] AND QR:Mod[r+1,c+1]=QR:Mod[r+2,c+2]
        p += 3
      END
    END
  END
  LOOP r = 0 TO n-1                                           ! rule 3: finder-like, horizontal
    LOOP c = 0 TO n-11
      IF QRMatchFinder(r,c,1) THEN p += 40.
    END
  END
  LOOP c = 0 TO n-1                                           ! rule 3: finder-like, vertical
    LOOP r = 0 TO n-11
      IF QRMatchFinder(c,r,0) THEN p += 40.
    END
  END
  dark = 0                                                    ! rule 4: dark-module proportion
  LOOP r = 0 TO n-1
    LOOP c = 0 TO n-1
      IF QR:Mod[r+1,c+1] = 1 THEN dark += 1.
    END
  END
  pct = INT(dark*100/(n*n))
  prev = INT(pct/5)*5
  a = ABS(prev-50); bb = ABS(prev+5-50)
  IF bb < a THEN a = bb.
  p += INT(a/5)*10
  RETURN p
#!
#!=== the encoder: value -> QR:Mod / QR:N  (returns 1 ok, 0 = too large) ======
QRBuildMatrix  PROCEDURE(*CSTRING pValue,LONG pEcc)
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
  QRInit()
  QR:Ecc = pEcc
  QR:DLen = LEN(pValue)
  QR:Ver = 0                                                 ! ---- choose the smallest version that fits
  LOOP v = 1 TO 10
    QR:TotalData = QR:T_G1B[v,QR:Ecc]*QR:T_G1D[v,QR:Ecc] + QR:T_G2B[v,QR:Ecc]*QR:T_G2D[v,QR:Ecc]
    QR:CCBits = CHOOSE(v<=9, 8, 16)
    cap = INT( (QR:TotalData*8 - 4 - QR:CCBits) / 8 )
    IF cap < 0 THEN cap = 0.
    IF QR:DLen <= cap
      QR:Ver = v; BREAK
    END
  END
  IF QR:Ver = 0 THEN RETURN 0.                               ! data too large for v1-10 at this ECC
  QR:TotalData = QR:T_G1B[QR:Ver,QR:Ecc]*QR:T_G1D[QR:Ver,QR:Ecc] + QR:T_G2B[QR:Ver,QR:Ecc]*QR:T_G2D[QR:Ver,QR:Ecc]
  QR:CCBits = CHOOSE(QR:Ver<=9, 8, 16)
  QR:N = 17 + 4*QR:Ver
  CLEAR(QR:Mod); CLEAR(QR:Fnc)
  ! ---- data codewords: mode + count + bytes + terminator + pad ----
  QR:NBits = 0
  QRAppendBits(4, 4)                                          ! byte mode indicator
  QRAppendBits(QR:DLen, QR:CCBits)                            ! character count
  LOOP i = 1 TO QR:DLen
    QRAppendBits(VAL(pValue[i]), 8)
  END
  capBits = QR:TotalData*8
  term = capBits - QR:NBits
  IF term > 4 THEN term = 4.
  IF term < 0 THEN term = 0.
  QRAppendBits(0, term)
  padb = QRMod(QR:NBits,8); IF padb <> 0 THEN QRAppendBits(0, 8-padb).
  QR:DataLen = 0                                             ! pack the bit buffer into bytes
  LOOP i = 1 TO QR:NBits BY 8
    b = 0
    LOOP j = 0 TO 7
      IF i+j <= QR:NBits AND QR:Bits[i+j] = 1
        b = BOR(b, BSHIFT(1, 7-j))
      END
    END
    QR:DataLen += 1; QR:Data[QR:DataLen] = b
  END
  padTog = 0                                                 ! alternating pad bytes EC / 11
  LOOP WHILE QR:DataLen < QR:TotalData
    QR:DataLen += 1
    QR:Data[QR:DataLen] = CHOOSE(QRMod(padTog,2)=0, 0ECh, 011h)
    padTog += 1
  END
  ! ---- error correction + interleaving ----
  ec = QR:T_Ec[QR:Ver,QR:Ecc]; QR:EcLen = ec
  pos = 0; bcount = 0
  LOOP gb = 1 TO QR:T_G1B[QR:Ver,QR:Ecc]                      ! group 1 blocks
    bcount += 1; blkLen = QR:T_G1D[QR:Ver,QR:Ecc]
    QR:BlkLenArr[bcount] = blkLen
    LOOP i = 1 TO blkLen; QR:BlkData[i] = QR:Data[pos+i]; END
    pos += blkLen
    QRReedSolomon(blkLen, ec)
    LOOP i = 1 TO blkLen; QR:DataBlk[bcount,i] = QR:BlkData[i]; END
    LOOP i = 1 TO ec; QR:EccBlk[bcount,i] = QR:BlkEcc[i]; END
  END
  LOOP gb = 1 TO QR:T_G2B[QR:Ver,QR:Ecc]                      ! group 2 blocks
    bcount += 1; blkLen = QR:T_G2D[QR:Ver,QR:Ecc]
    QR:BlkLenArr[bcount] = blkLen
    LOOP i = 1 TO blkLen; QR:BlkData[i] = QR:Data[pos+i]; END
    pos += blkLen
    QRReedSolomon(blkLen, ec)
    LOOP i = 1 TO blkLen; QR:DataBlk[bcount,i] = QR:BlkData[i]; END
    LOOP i = 1 TO ec; QR:EccBlk[bcount,i] = QR:BlkEcc[i]; END
  END
  QR:NumBlocks = bcount
  maxData = QR:T_G1D[QR:Ver,QR:Ecc]
  IF QR:T_G2D[QR:Ver,QR:Ecc] > maxData THEN maxData = QR:T_G2D[QR:Ver,QR:Ecc].
  QR:CWLen = 0
  LOOP i = 1 TO maxData                                       ! interleave data codewords
    LOOP b = 1 TO bcount
      IF i <= QR:BlkLenArr[b]
        QR:CWLen += 1; QR:CW[QR:CWLen] = QR:DataBlk[b,i]
      END
    END
  END
  LOOP i = 1 TO ec                                            ! then interleave EC codewords
    LOOP b = 1 TO bcount
      QR:CWLen += 1; QR:CW[QR:CWLen] = QR:EccBlk[b,i]
    END
  END
  ! ---- function patterns ----
  LOOP i = 0 TO QR:N-1                                        ! timing patterns
    QRSet(6,i, CHOOSE(QRMod(i,2)=0,1,0))
    QRSet(i,6, CHOOSE(QRMod(i,2)=0,1,0))
  END
  QRFinder(0,0); QRFinder(0,QR:N-7); QRFinder(QR:N-7,0)       ! finder patterns
  CASE QR:Ver                                                ! alignment-pattern centres
  OF 1; QR:NAlign = 0
  OF 2; QR:NAlign = 2; QR:Align[1]=6; QR:Align[2]=18
  OF 3; QR:NAlign = 2; QR:Align[1]=6; QR:Align[2]=22
  OF 4; QR:NAlign = 2; QR:Align[1]=6; QR:Align[2]=26
  OF 5; QR:NAlign = 2; QR:Align[1]=6; QR:Align[2]=30
  OF 6; QR:NAlign = 2; QR:Align[1]=6; QR:Align[2]=34
  OF 7; QR:NAlign = 3; QR:Align[1]=6; QR:Align[2]=22; QR:Align[3]=38
  OF 8; QR:NAlign = 3; QR:Align[1]=6; QR:Align[2]=24; QR:Align[3]=42
  OF 9; QR:NAlign = 3; QR:Align[1]=6; QR:Align[2]=26; QR:Align[3]=46
  ELSE; QR:NAlign = 3; QR:Align[1]=6; QR:Align[2]=28; QR:Align[3]=50
  END
  LOOP ai = 1 TO QR:NAlign
    LOOP aj = 1 TO QR:NAlign
      ar = QR:Align[ai]; ac = QR:Align[aj]
      IF (ar<=7 AND ac<=7) OR (ar<=7 AND ac>=QR:N-8) OR (ar>=QR:N-8 AND ac<=7) THEN CYCLE.
      QRAlignment(ar,ac)
    END
  END
  QRSet(QR:N-8,8,1)                                           ! dark module
  LOOP i = 0 TO 8                                             ! reserve format-info area
    QR:Fnc[8+1,i+1] = 1; QR:Fnc[i+1,8+1] = 1
  END
  LOOP i = 0 TO 7
    QR:Fnc[8+1,QR:N-1-i+1] = 1; QR:Fnc[QR:N-1-i+1,8+1] = 1
  END
  IF QR:Ver >= 7                                              ! version info (v7+), 18-bit BCH
    rem = QR:Ver
    LOOP i = 0 TO 11
      rem = BXOR(BSHIFT(rem,1), BSHIFT(rem,-11)*01F25h)
    END
    fbits = BOR(BSHIFT(QR:Ver,12), rem)
    LOOP i = 0 TO 17
      QRSet(QR:N-11+QRMod(i,3), INT(i/3), BAND(BSHIFT(fbits,-i),1))
      QRSet(INT(i/3), QR:N-11+QRMod(i,3), BAND(BSHIFT(fbits,-i),1))
    END
  END
  ! ---- place the codeword bits (zig-zag, skipping function modules) ----
  bit = 0; total = QR:CWLen*8
  col = QR:N-1
  LOOP WHILE col > 0
    IF col = 6 THEN col -= 1.                                 ! skip the vertical timing column
    LOOP t = 0 TO QR:N-1
      upward = CHOOSE( QRMod(INT((QR:N-1-col)/2),2)=0, 1, 0)
      row = CHOOSE(upward=1, QR:N-1-t, t)
      LOOP cc2 = 0 TO 1
        cc = col - cc2
        IF QR:Fnc[row+1,cc+1] = 1 THEN CYCLE.
        IF bit < total
          byteIdx = INT(bit/8)+1
          shift = -(7 - QRMod(bit,8))
          dark = BAND(BSHIFT(QR:CW[byteIdx], shift),1)
        ELSE
          dark = 0
        END
        QR:Mod[row+1,cc+1] = dark
        bit += 1
      END
    END
    col -= 2
  END
  ! ---- choose the mask with the lowest penalty ----
  QR:BestMask = 0; bestP = 2147483647
  LOOP mask = 0 TO 7
    QRApplyMask(mask)
    QRFormatInfo(mask)                                        ! rule 3 looks at the whole symbol
    pp = QRPenalty()
    IF pp < bestP
      bestP = pp; QR:BestMask = mask
    END
    QRApplyMask(mask)                                         ! XOR again to revert
  END
  QRApplyMask(QR:BestMask)                                    ! leave the winner applied
  QRFormatInfo(QR:BestMask)                                   ! final format info
  RETURN 1
#!
#!=== paint the ALREADY-BUILT matrix into a control, in the CURRENT target =====
#! Target-agnostic: the caller does the SETTARGET (a window IMAGE control, or a
#! REPORT band). Reads the control's position+size with one GETPOSITION, centres
#! the symbol, fills a light field then draws each dark module as a BOX. Shared
#! by the window helper (QRDraw) and the report extension.
QRPaint  PROCEDURE(SIGNED pImageFeq,LONG pDark,LONG pLight,LONG pQuiet)
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
  n = QR:N; side = n + 2*q
  GETPOSITION(pImageFeq,ImgX,ImgY,imgW,imgH)                  ! position AND size, target-relative
  cell = INT(imgW/side); IF INT(imgH/side) < cell THEN cell = INT(imgH/side).
  IF cell < 1 THEN cell = 1.                                  ! at least 1 unit per module
  qpix = cell*side
  offX = ImgX + INT((imgW-qpix)/2); offY = ImgY + INT((imgH-qpix)/2)   ! centre in the control
  SETPENCOLOR(pLight)
  BOX(ImgX,ImgY,imgW,imgH,pLight)                             ! light field (quiet zone is light too)
  SETPENCOLOR(pDark)
  LOOP r = 0 TO n-1
    LOOP c = 0 TO n-1
      IF QR:Mod[r+1,c+1] = 1
        BOX(offX+(c+q)*cell, offY+(r+q)*cell, cell, cell, pDark)
      END
    END
  END
#!
#!=== the window helper: encode + draw into a window IMAGE control =============
QRDraw  PROCEDURE(SIGNED pImageFeq,*CSTRING pValue,LONG pEcc,LONG pDark,LONG pLight,LONG pQuiet)
  CODE
  IF QRBuildMatrix(pValue,pEcc) = 0 THEN RETURN.             ! too large - leave the control unchanged
  SETTARGET(,pImageFeq)                                       ! draw into the IMAGE control (window-relative, issue #5)
  BLANK                                                       ! wipe prior graphics (no resize artifacts)
  QRPaint(pImageFeq,pDark,pLight,pQuiet)
  SETTARGET()                                                 ! restore previous target
#ENDAT
#!#############################################################################
#!  PROCEDURE EXTENSION - myQRDraw
#!#############################################################################
#EXTENSION(myQRDraw,'myQRDraw - Draw a QR Code on this window'),PROCEDURE,REQ(myQRDrawGlobal)
#SHEET
  #TAB('&General')
    #BOXED('Options')
      #PROMPT('&Disable this template',CHECK),%myQRDrawDisableThis,DEFAULT(0),AT(10)
      #PROMPT('&Image control to draw into:',CONTROL),%myQRDrawImage,REQ
      #PROMPT('&Value:',@s255),%myQRDrawValue,DEFAULT('https://www.softvelocity.com')
      #PROMPT('Value is a &variable / expression (not literal text)',CHECK),%myQRDrawValueIsVar,DEFAULT(0),AT(10)
      #PROMPT('&Error correction level:',DROP('L - Low (most data)[1]|M - Medium[2]|Q - Quartile[3]|H - High (most robust)[4]')),%myQRDrawEcc,DEFAULT('2')
      #PROMPT('&Dark (foreground) color:',COLOR),%myQRDrawDark,DEFAULT(00000000H)
      #PROMPT('&Light (background) color:',COLOR),%myQRDrawLight,DEFAULT(00FFFFFFH)
      #PROMPT('&Quiet-zone modules (border):',SPIN(@n1,0,8,1)),%myQRDrawQuiet,DEFAULT(4)
      #PROMPT('Draw &self-test ("HELLO WORLD", ECC M)',CHECK),%myQRDrawSelfTest,DEFAULT(0),AT(10)
    #ENDBOXED
  #ENDTAB
  #TAB('&Instructions')
    #BOXED('How to use myQRDraw')
      #DISPLAY('1. Add the global "myQRDraw - Global Encoder + Helper"')
      #DISPLAY('   extension once at the Application level.')
      #DISPLAY('2. Add an IMAGE control to the window (an Image - a Region')
      #DISPLAY('   will not receive the drawing). Make it square-ish.')
      #DISPLAY('3. On the General tab, select that control in "Image control')
      #DISPLAY('   to draw into".')
      #DISPLAY('4. Type the Value. Leave "Value is a variable" UNticked for')
      #DISPLAY('   literal text (e.g. a URL); tick it to use a Clarion')
      #DISPLAY('   variable/expression (e.g. CUS:WebSite) drawn at run time.')
      #DISPLAY('   NOTE: if the literal text contains an apostrophe ('') use')
      #DISPLAY('   the "variable" path instead, or it will break the source.')
      #DISPLAY('5. Pick the ECC level, the Dark/Light colors and the')
      #DISPLAY('   quiet-zone width. Higher ECC = more robust, less capacity.')
      #DISPLAY('6. For a resizable window, set the Image to resize/anchor so')
      #DISPLAY('   the code follows the window.')
      #DISPLAY('7. Generate, compile, run - then scan with a phone.')
      #DISPLAY('')
      #DISPLAY('Self-test: tick it to draw "HELLO WORLD" at ECC M (a fixed')
      #DISPLAY('21x21 symbol). Scanning it must read "HELLO WORLD" - this')
      #DISPLAY('proves the offline encoder works on your machine.')
    #ENDBOXED
  #ENDTAB
  #TAB('&Runtime')
    #BOXED('Changing the value at run time')
      #DISPLAY('Tick "Value is a variable" and name a variable. Change it,')
      #DISPLAY('then repaint:')
      #DISPLAY('   MyWebVar = ''https://newsite.example''')
      #DISPLAY('   DO myQRDrawRepaint')
      #DISPLAY('The code re-encodes and redraws automatically.')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#! Local data + repaint routine + the draw handler (mirrors myPie's pattern).
#!-----------------------------------------------------------------------------
#AT(%DataSection),WHERE(%myQRDrawDisableThis=0 AND %myQRDrawImage)
myQRDraw:Redraw      EQUATE(EVENT:User+114)                  ! private "repaint" event
myQRDraw:Value       CSTRING(512)                            ! the value to encode (headroom for version-10 capacity)
#ENDAT
#!
#AT(%ProcedureRoutines),WHERE(%myQRDrawDisableThis=0 AND %myQRDrawImage)
myQRDrawRepaint ROUTINE
  POST(myQRDraw:Redraw)
#ENDAT
#!
#AT(%WindowManagerMethodCodeSection,'TakeWindowEvent','(),BYTE'),PRIORITY(2000),WHERE(%myQRDrawDisableThis=0 AND %myQRDrawImage)
  CASE EVENT()
  OF EVENT:OpenWindow
    POST(myQRDraw:Redraw)                                     ! first draw, after the window opens
  OF EVENT:Sized
    POST(myQRDraw:Redraw)                                     ! redraw after the resize settles
  OF myQRDraw:Redraw
#IF(%myQRDrawSelfTest)
    myQRDraw:Value = 'HELLO WORLD'                            ! fixed, known-good 21x21 symbol
    QRDraw(%myQRDrawImage, myQRDraw:Value, 2, %myQRDrawDark, %myQRDrawLight, %myQRDrawQuiet)
#ELSE
#IF(%myQRDrawValueIsVar)
    myQRDraw:Value = %myQRDrawValue                           ! code-driven value
#ELSE
    myQRDraw:Value = '%myQRDrawValue'                         ! literal text
#ENDIF
    QRDraw(%myQRDrawImage, myQRDraw:Value, %myQRDrawEcc, %myQRDrawDark, %myQRDrawLight, %myQRDrawQuiet)
#ENDIF
  END
#ENDAT
#!#############################################################################
#!  PROCEDURE EXTENSION - myQRDrawReport  (for REPORT procedures)
#!#############################################################################
#!  Reports render bands through the print engine, not a window event loop, so
#!  this draws in the %BeforePrint embed (fires before each DETAIL band prints)
#!  with SETTARGET(%Report) - the report itself is the draw target, and the
#!  band/page is current. Put an IMAGE control in the band where you want the
#!  code (give it a USE/field-equate so GETPOSITION can find it). A code is
#!  drawn per printed record - point Value at a per-record field (literal or
#!  variable) for one-QR-per-row, e.g. an order/customer URL.
#!#############################################################################
#EXTENSION(myQRDrawReport,'myQRDraw - Draw a QR Code on this REPORT'),PROCEDURE,REQ(myQRDrawGlobal)
#SHEET
  #TAB('&General')
    #BOXED('Options')
      #PROMPT('&Disable this template',CHECK),%myQRDrawRptDisable,DEFAULT(0),AT(10)
      #! CONTROL lists WINDOW controls only; a report proc also has a progress window, so we must list
      #! the REPORT's controls instead - FROM(%ReportControl,...) (corpus: blobsrv.tpw:20). Yields the
      #! ?-prefixed field equate, same as a window CONTROL prompt, usable in GETPOSITION after SETTARGET(Report).
      #PROMPT('&Image control (in a report band) to draw into:',FROM(%ReportControl,%ReportControlType = 'IMAGE')),%myQRDrawRptImage,REQ,DEFAULT('')
      #PROMPT('&Value:',@s255),%myQRDrawRptValue,DEFAULT('https://www.softvelocity.com')
      #PROMPT('Value is a &variable / expression (not literal text)',CHECK),%myQRDrawRptValueIsVar,DEFAULT(0),AT(10)
      #PROMPT('&Error correction level:',DROP('L - Low (most data)[1]|M - Medium[2]|Q - Quartile[3]|H - High (most robust)[4]')),%myQRDrawRptEcc,DEFAULT('2')
      #PROMPT('&Dark (foreground) color:',COLOR),%myQRDrawRptDark,DEFAULT(00000000H)
      #PROMPT('&Light (background) color:',COLOR),%myQRDrawRptLight,DEFAULT(00FFFFFFH)
      #PROMPT('&Quiet-zone modules (border):',SPIN(@n1,0,8,1)),%myQRDrawRptQuiet,DEFAULT(4)
      #PROMPT('Draw &self-test ("HELLO WORLD", ECC M)',CHECK),%myQRDrawRptSelfTest,DEFAULT(0),AT(10)
    #ENDBOXED
  #ENDTAB
  #TAB('&Instructions')
    #BOXED('How to use myQRDrawReport')
      #DISPLAY('1. Add the global "myQRDraw - Global Encoder + Helper"')
      #DISPLAY('   extension once at the Application level.')
      #DISPLAY('2. In the Report formatter, drop an IMAGE control into the')
      #DISPLAY('   DETAIL band (or a band that prints per record) and give it')
      #DISPLAY('   a USE / field-equate so it can be selected below.')
      #DISPLAY('3. Add THIS extension (for reports). On a window, use the')
      #DISPLAY('   plain "myQRDraw" extension instead.')
      #DISPLAY('4. Pick the image control, set the Value (tick "variable" to')
      #DISPLAY('   use a per-record field like ORD:URL), ECC, colors, quiet.')
      #DISPLAY('5. Generate, compile, print/preview - one QR is drawn per')
      #DISPLAY('   record in the detail band. Scan to verify.')
      #DISPLAY('')
      #DISPLAY('Drawing uses SETTARGET(Report) in the Before-Print-Detail')
      #DISPLAY('embed. If the code lands in the wrong spot, ensure the image')
      #DISPLAY('is in the detail band; for page-level placement (one QR per')
      #DISPLAY('page) ask for the page-header variant.')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#! Local value buffer (no repaint routine - reports have no event loop; the code
#! re-encodes from the current field value each time the detail band prints).
#!-----------------------------------------------------------------------------
#AT(%DataSection),WHERE(%myQRDrawRptDisable=0 AND %myQRDrawRptImage)
myQRDrawRpt:Value    CSTRING(512)                            ! the value to encode for this row
#ENDAT
#!-----------------------------------------------------------------------------
#! Draw before each detail band prints. SETTARGET(Report) makes the report the
#! graphics target; GETPOSITION finds the band image; QRPaint draws into it.
#!-----------------------------------------------------------------------------
#AT(%BeforePrint),WHERE(%myQRDrawRptDisable=0 AND %myQRDrawRptImage)
#IF(%myQRDrawRptSelfTest)
  myQRDrawRpt:Value = 'HELLO WORLD'                           ! fixed, known-good 21x21 symbol
  IF QRBuildMatrix(myQRDrawRpt:Value, 2)
    SETTARGET(%Report)
    QRPaint(%myQRDrawRptImage, %myQRDrawRptDark, %myQRDrawRptLight, %myQRDrawRptQuiet)
    SETTARGET()
  END
#ELSE
#IF(%myQRDrawRptValueIsVar)
  myQRDrawRpt:Value = %myQRDrawRptValue                       ! per-record value (e.g. ORD:URL)
#ELSE
  myQRDrawRpt:Value = '%myQRDrawRptValue'                     ! literal text
#ENDIF
  IF QRBuildMatrix(myQRDrawRpt:Value, %myQRDrawRptEcc)
    SETTARGET(%Report)                                       ! the report (band) is the draw target
    QRPaint(%myQRDrawRptImage, %myQRDrawRptDark, %myQRDrawRptLight, %myQRDrawRptQuiet)
    SETTARGET()                                              ! restore
  END
#ENDIF
#ENDAT
#!-----------------------------------------------------------------------------
#! End of myQRDraw template set
#!-----------------------------------------------------------------------------
