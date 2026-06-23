! ============================================================================
!  CompressClass - implementation.  Pure-Clarion DEFLATE/zlib/gzip (see .inc).
!
!  Clarion port notes:
!   - Clarion ROUNDS on integer assignment, so every truncating divide uses INT().
!   - Bit ops are functions: BSHIFT(v,n) (+n = left, -n = right), BAND, BOR, BXOR.
!   - Accumulators are ULONG so right-shifts are logical (no sign bit drag-in).
!   - Strings are 1-based; a single byte is OutBuf[i] = CHR(v) / VAL(s[i]).
!   - DEFLATE packs bits LSB-first; Huffman codes are MSB-first, so PutHuff
!     reverses a code's bits before LSB-first packing (RevBits).
!
!  This file MUST be stored in ANSI (not UTF-8).
! ============================================================================
  MEMBER

  MAP                                       ! module-level MAP is REQUIRED (folds BUILTINS.CLW
    MODULE('kernel32')                      ! prototypes in) - and hosts the Win32 file calls.
kCreateFile        PROCEDURE(*CSTRING,ULONG,ULONG,LONG,ULONG,ULONG,LONG),LONG,RAW,PASCAL,NAME('CreateFileA')
kReadFile          PROCEDURE(LONG,LONG,ULONG,*ULONG,LONG),LONG,RAW,PASCAL,PROC,NAME('ReadFile')
kWriteFile         PROCEDURE(LONG,LONG,ULONG,*ULONG,LONG),LONG,RAW,PASCAL,PROC,NAME('WriteFile')
kGetFileSize       PROCEDURE(LONG,LONG),ULONG,PASCAL,NAME('GetFileSize')
kCloseHandle       PROCEDURE(LONG),LONG,PASCAL,PROC,NAME('CloseHandle')
    END
  END

  INCLUDE('CompressClass.INC'),ONCE

!=== construct / destruct ====================================================
CompressClass.Construct PROCEDURE()
  CODE
  SELF.Level  = 6
  SELF.Format = Cmp:Gzip
  SELF.OutBuf &= NULL
  SELF.InBuf  &= NULL
  SELF.Init()

CompressClass.Destruct PROCEDURE()
  CODE
  IF NOT SELF.OutBuf &= NULL THEN DISPOSE(SELF.OutBuf).

!=== one-time tables =========================================================
CompressClass.Init PROCEDURE
n   ULONG
k   ULONG
c   ULONG
sym LONG
  CODE
  ! ---- CRC32 table (gzip) ----
  LOOP n = 0 TO 255
    c = n
    LOOP k = 1 TO 8
      IF BAND(c,1)
        c = BXOR(0EDB88320h, BSHIFT(c,-1))
      ELSE
        c = BSHIFT(c,-1)
      END
    END
    SELF.CrcTab[n+1] = c
  END
  ! ---- length codes 257..285 : extra bits + base length ----
  SELF.LenXtra[1]=0;SELF.LenXtra[2]=0;SELF.LenXtra[3]=0;SELF.LenXtra[4]=0
  SELF.LenXtra[5]=0;SELF.LenXtra[6]=0;SELF.LenXtra[7]=0;SELF.LenXtra[8]=0
  SELF.LenXtra[9]=1;SELF.LenXtra[10]=1;SELF.LenXtra[11]=1;SELF.LenXtra[12]=1
  SELF.LenXtra[13]=2;SELF.LenXtra[14]=2;SELF.LenXtra[15]=2;SELF.LenXtra[16]=2
  SELF.LenXtra[17]=3;SELF.LenXtra[18]=3;SELF.LenXtra[19]=3;SELF.LenXtra[20]=3
  SELF.LenXtra[21]=4;SELF.LenXtra[22]=4;SELF.LenXtra[23]=4;SELF.LenXtra[24]=4
  SELF.LenXtra[25]=5;SELF.LenXtra[26]=5;SELF.LenXtra[27]=5;SELF.LenXtra[28]=5
  SELF.LenXtra[29]=0
  SELF.LenBase[1]=3;SELF.LenBase[2]=4;SELF.LenBase[3]=5;SELF.LenBase[4]=6
  SELF.LenBase[5]=7;SELF.LenBase[6]=8;SELF.LenBase[7]=9;SELF.LenBase[8]=10
  SELF.LenBase[9]=11;SELF.LenBase[10]=13;SELF.LenBase[11]=15;SELF.LenBase[12]=17
  SELF.LenBase[13]=19;SELF.LenBase[14]=23;SELF.LenBase[15]=27;SELF.LenBase[16]=31
  SELF.LenBase[17]=35;SELF.LenBase[18]=43;SELF.LenBase[19]=51;SELF.LenBase[20]=59
  SELF.LenBase[21]=67;SELF.LenBase[22]=83;SELF.LenBase[23]=99;SELF.LenBase[24]=115
  SELF.LenBase[25]=131;SELF.LenBase[26]=163;SELF.LenBase[27]=195;SELF.LenBase[28]=227
  SELF.LenBase[29]=258
  ! ---- distance codes 0..29 : extra bits + base distance ----
  SELF.DstXtra[1]=0;SELF.DstXtra[2]=0;SELF.DstXtra[3]=0;SELF.DstXtra[4]=0
  SELF.DstXtra[5]=1;SELF.DstXtra[6]=1;SELF.DstXtra[7]=2;SELF.DstXtra[8]=2
  SELF.DstXtra[9]=3;SELF.DstXtra[10]=3;SELF.DstXtra[11]=4;SELF.DstXtra[12]=4
  SELF.DstXtra[13]=5;SELF.DstXtra[14]=5;SELF.DstXtra[15]=6;SELF.DstXtra[16]=6
  SELF.DstXtra[17]=7;SELF.DstXtra[18]=7;SELF.DstXtra[19]=8;SELF.DstXtra[20]=8
  SELF.DstXtra[21]=9;SELF.DstXtra[22]=9;SELF.DstXtra[23]=10;SELF.DstXtra[24]=10
  SELF.DstXtra[25]=11;SELF.DstXtra[26]=11;SELF.DstXtra[27]=12;SELF.DstXtra[28]=12
  SELF.DstXtra[29]=13;SELF.DstXtra[30]=13
  SELF.DstBase[1]=1;SELF.DstBase[2]=2;SELF.DstBase[3]=3;SELF.DstBase[4]=4
  SELF.DstBase[5]=5;SELF.DstBase[6]=7;SELF.DstBase[7]=9;SELF.DstBase[8]=13
  SELF.DstBase[9]=17;SELF.DstBase[10]=25;SELF.DstBase[11]=33;SELF.DstBase[12]=49
  SELF.DstBase[13]=65;SELF.DstBase[14]=97;SELF.DstBase[15]=129;SELF.DstBase[16]=193
  SELF.DstBase[17]=257;SELF.DstBase[18]=385;SELF.DstBase[19]=513;SELF.DstBase[20]=769
  SELF.DstBase[21]=1025;SELF.DstBase[22]=1537;SELF.DstBase[23]=2049;SELF.DstBase[24]=3073
  SELF.DstBase[25]=4097;SELF.DstBase[26]=6145;SELF.DstBase[27]=8193;SELF.DstBase[28]=12289
  SELF.DstBase[29]=16385;SELF.DstBase[30]=24577
  ! ---- code-length code order (RFC1951 3.2.7) ----
  SELF.CLOrder[1]=16;SELF.CLOrder[2]=17;SELF.CLOrder[3]=18;SELF.CLOrder[4]=0
  SELF.CLOrder[5]=8;SELF.CLOrder[6]=7;SELF.CLOrder[7]=9;SELF.CLOrder[8]=6
  SELF.CLOrder[9]=10;SELF.CLOrder[10]=5;SELF.CLOrder[11]=11;SELF.CLOrder[12]=4
  SELF.CLOrder[13]=12;SELF.CLOrder[14]=3;SELF.CLOrder[15]=13;SELF.CLOrder[16]=2
  SELF.CLOrder[17]=14;SELF.CLOrder[18]=1;SELF.CLOrder[19]=15
  ! ---- fixed-Huffman literal/length code table (MSB-first values) ----
  LOOP sym = 0 TO 287
    CASE sym
    OF 0 TO 143
      SELF.FixLitCode[sym+1] = 030h + sym         ; SELF.FixLitLen[sym+1] = 8
    OF 144 TO 255
      SELF.FixLitCode[sym+1] = 190h + (sym-144)   ; SELF.FixLitLen[sym+1] = 9
    OF 256 TO 279
      SELF.FixLitCode[sym+1] = sym-256            ; SELF.FixLitLen[sym+1] = 7
    ELSE
      SELF.FixLitCode[sym+1] = 0C0h + (sym-280)   ; SELF.FixLitLen[sym+1] = 8
    END
  END
  SELF.Ready = 1

!=== checksums ===============================================================
CompressClass.CRC32 PROCEDURE(*STRING p,LONG pLen)
crc ULONG
i   LONG
  CODE
  crc = 0FFFFFFFFh
  LOOP i = 1 TO pLen
    crc = BXOR(BSHIFT(crc,-8), SELF.CrcTab[ BAND(BXOR(crc,VAL(p[i])),0FFh) + 1 ])
  END
  RETURN BXOR(crc,0FFFFFFFFh)

CompressClass.Adler32 PROCEDURE(*STRING p,LONG pLen)
a ULONG
b ULONG
i LONG
  CODE
  a = 1; b = 0
  LOOP i = 1 TO pLen
    a += VAL(p[i]); IF a >= 65521 THEN a -= 65521.
    b += a       ; IF b >= 65521 THEN b -= 65521.
  END
  RETURN BOR(BSHIFT(b,16), a)

!=== output buffer + bit writer ==============================================
CompressClass.ResetOut PROCEDURE
  CODE
  IF SELF.OutBuf &= NULL
    SELF.OutBuf &= NEW STRING(4096)
    SELF.OutCap = 4096
  END
  SELF.OutLen = 0
  SELF.BWAcc  = 0
  SELF.BWN    = 0

CompressClass.EnsureOut PROCEDURE(LONG pNeed)
tmp    &STRING
newcap LONG
  CODE
  IF SELF.OutBuf &= NULL
    SELF.OutBuf &= NEW STRING(4096); SELF.OutCap = 4096
  END
  IF SELF.OutLen + pNeed <= SELF.OutCap THEN RETURN.
  newcap = SELF.OutCap * 2
  IF newcap < SELF.OutLen + pNeed THEN newcap = SELF.OutLen + pNeed + 4096.
  tmp &= NEW STRING(newcap)
  IF SELF.OutLen > 0 THEN tmp[1 : SELF.OutLen] = SELF.OutBuf[1 : SELF.OutLen].
  DISPOSE(SELF.OutBuf)
  SELF.OutBuf &= tmp
  SELF.OutCap = newcap

CompressClass.PutByte PROCEDURE(LONG pVal)
  CODE
  SELF.EnsureOut(1)
  SELF.OutLen += 1
  SELF.OutBuf[SELF.OutLen] = CHR(BAND(pVal,0FFh))

CompressClass.PutBits PROCEDURE(LONG pVal,LONG pN)
  CODE
  SELF.BWAcc = BOR(SELF.BWAcc, BSHIFT(BAND(pVal, BSHIFT(1,pN)-1), SELF.BWN))
  SELF.BWN += pN
  LOOP WHILE SELF.BWN >= 8
    SELF.PutByte(BAND(SELF.BWAcc,0FFh))
    SELF.BWAcc = BSHIFT(SELF.BWAcc,-8)
    SELF.BWN  -= 8
  END

CompressClass.RevBits PROCEDURE(LONG pVal,LONG pN)
r LONG
i LONG
v LONG
  CODE
  r = 0; v = pVal
  LOOP i = 1 TO pN
    r = BOR(BSHIFT(r,1), BAND(v,1))
    v = BSHIFT(v,-1)
  END
  RETURN r

CompressClass.PutHuff PROCEDURE(LONG pCode,LONG pN)
  CODE
  SELF.PutBits(SELF.RevBits(pCode,pN), pN)

CompressClass.FlushBits PROCEDURE
  CODE
  IF SELF.BWN > 0
    SELF.PutByte(BAND(SELF.BWAcc,0FFh))
    SELF.BWAcc = 0
    SELF.BWN   = 0
  END

!=== bit reader ==============================================================
CompressClass.ByteIn PROCEDURE()
v LONG
  CODE
  IF SELF.InPos > SELF.InLen
    IF SELF.ErrCode = 0
      SELF.ErrCode = -1; SELF.ErrText = 'Unexpected end of compressed data'
    END
    RETURN 0
  END
  v = VAL(SELF.InBuf[SELF.InPos])
  SELF.InPos += 1
  RETURN v

CompressClass.GetBits PROCEDURE(LONG pN)
v LONG
  CODE
  LOOP WHILE SELF.BRN < pN
    SELF.BRAcc = BOR(SELF.BRAcc, BSHIFT(SELF.ByteIn(), SELF.BRN))
    SELF.BRN += 8
  END
  v = BAND(SELF.BRAcc, BSHIFT(1,pN)-1)
  SELF.BRAcc = BSHIFT(SELF.BRAcc,-pN)
  SELF.BRN  -= pN
  RETURN v

CompressClass.AlignByte PROCEDURE
drop LONG
  CODE
  drop = BAND(SELF.BRN,7)
  SELF.BRAcc = BSHIFT(SELF.BRAcc,-drop)
  SELF.BRN  -= drop

CompressClass.NextStoredByte PROCEDURE()
v LONG
  CODE
  IF SELF.BRN >= 8
    v = BAND(SELF.BRAcc,0FFh)
    SELF.BRAcc = BSHIFT(SELF.BRAcc,-8)
    SELF.BRN  -= 8
    RETURN v
  END
  RETURN SELF.ByteIn()

!=== Huffman build + decode ==================================================
CompressClass.BuildHuff PROCEDURE(*LONG[] pLen,LONG pN,*LONG[] pCnt,*LONG[] pSym)
i    LONG
L    LONG
offs LONG,DIM(16)
  CODE
  LOOP i = 1 TO 15; pCnt[i] = 0.
  LOOP i = 1 TO pN
    L = pLen[i]
    IF L > 0 THEN pCnt[L] += 1.
  END
  offs[1] = 0
  LOOP L = 1 TO 14
    offs[L+1] = offs[L] + pCnt[L]
  END
  LOOP i = 1 TO pN
    L = pLen[i]
    IF L > 0
      pSym[ offs[L] + 1 ] = i - 1                 ! store the 0-based symbol
      offs[L] += 1
    END
  END

CompressClass.DecodeSym PROCEDURE(*LONG[] pCnt,*LONG[] pSym)
code  LONG
first LONG
index LONG
len   LONG
cnt   LONG
  CODE
  code = 0; first = 0; index = 0
  LOOP len = 1 TO 15
    code = BOR(BSHIFT(code,1), SELF.GetBits(1))
    cnt  = pCnt[len]
    IF code - first < cnt
      RETURN pSym[ index + (code - first) + 1 ]
    END
    index += cnt
    first  = BSHIFT(first + cnt, 1)
  END
  SELF.ErrCode = -2; SELF.ErrText = 'Bad Huffman code in stream'
  RETURN -1

!=== DEFLATE (compress) ======================================================
CompressClass.DeflateStored PROCEDURE(*STRING pSrc,LONG pLen)
pos   LONG
blk   LONG
final LONG
nl    LONG
k     LONG
  CODE
  pos = 1
  LOOP
    blk = pLen - pos + 1
    IF blk > 65535 THEN blk = 65535.
    IF blk < 0 THEN blk = 0.
    IF pos + blk - 1 >= pLen THEN final = 1 ELSE final = 0.
    SELF.PutBits(final,1)                          ! BFINAL
    SELF.PutBits(0,2)                              ! BTYPE = 00 (stored)
    SELF.FlushBits()                               ! align to a byte boundary
    SELF.PutByte(BAND(blk,0FFh))
    SELF.PutByte(BAND(BSHIFT(blk,-8),0FFh))
    nl = BXOR(blk,0FFFFh)
    SELF.PutByte(BAND(nl,0FFh))
    SELF.PutByte(BAND(BSHIFT(nl,-8),0FFh))
    LOOP k = 0 TO blk-1
      SELF.PutByte(VAL(pSrc[pos+k]))
    END
    pos += blk
    IF final THEN BREAK.
  END

CompressClass.Deflate PROCEDURE(*STRING pSrc,LONG pLen)
i        LONG
maxchain LONG
chain    LONG
cur      LONG
bestlen  LONG
bestdist LONG
k        LONG
p        LONG
loc:hp   LONG                                      ! position to hash
loc:h    LONG                                      ! hash result
loc:ma   LONG                                      ! match: candidate (older) position
loc:mb   LONG                                      ! match: current position
loc:ml   LONG                                      ! match: length found
loc:ls   LONG                                      ! length symbol (0..28)
loc:ds   LONG                                      ! distance symbol (0..29)
loc:t    LONG
  CODE
  IF SELF.Level <= 0
    SELF.DeflateStored(pSrc,pLen); RETURN
  END
  CASE SELF.Level
  OF 1; maxchain = 4
  OF 2; maxchain = 8
  OF 3; maxchain = 16
  OF 4; maxchain = 32
  OF 5; maxchain = 64
  OF 7; maxchain = 256
  OF 8; maxchain = 1024
  OF 9; maxchain = 4096
  ELSE; maxchain = 128                             ! level 6 (default)
  END
  LOOP i = 1 TO Cmp:HashSize; SELF.HashHead[i] = 0.   ! 0 = empty (positions are 1-based)
  SELF.PutBits(1,1)                                 ! BFINAL = 1 (single block)
  SELF.PutBits(1,2)                                 ! BTYPE  = 01 (fixed Huffman)
  i = 1
  LOOP WHILE i <= pLen
    bestlen = 0; bestdist = 0
    IF i + Cmp:MinMatch - 1 <= pLen
      loc:hp = i; DO HashAt
      cur   = SELF.HashHead[loc:h+1]
      chain = maxchain
      LOOP WHILE cur > 0 AND chain > 0
        IF i - cur > Cmp:WSize THEN BREAK.          ! out of the 32K window
        loc:ma = cur; loc:mb = i; DO MatchLen
        IF loc:ml > bestlen
          bestlen = loc:ml; bestdist = i - cur
          IF loc:ml >= Cmp:MaxMatch THEN BREAK.
        END
        cur   = SELF.HashPrev[ BAND(cur-1,Cmp:WMask) + 1 ]
        chain -= 1
      END
      SELF.HashPrev[ BAND(i-1,Cmp:WMask) + 1 ] = SELF.HashHead[loc:h+1]
      SELF.HashHead[loc:h+1] = i
    END
    IF bestlen >= Cmp:MinMatch
      DO EmitMatch
      LOOP k = 1 TO bestlen-1                       ! register the bytes the match covers
        p = i + k
        IF p + Cmp:MinMatch - 1 <= pLen
          loc:hp = p; DO HashAt
          SELF.HashPrev[ BAND(p-1,Cmp:WMask) + 1 ] = SELF.HashHead[loc:h+1]
          SELF.HashHead[loc:h+1] = p
        END
      END
      i += bestlen
    ELSE
      SELF.PutHuff(SELF.FixLitCode[ VAL(pSrc[i])+1 ], SELF.FixLitLen[ VAL(pSrc[i])+1 ])
      i += 1
    END
  END
  SELF.PutHuff(SELF.FixLitCode[257], SELF.FixLitLen[257])   ! symbol 256 (end of block) -> index 256+1
  SELF.FlushBits()
  RETURN
!----
HashAt ROUTINE
  loc:h = BAND(BXOR(BXOR(BSHIFT(VAL(pSrc[loc:hp]),10), BSHIFT(VAL(pSrc[loc:hp+1]),5)), VAL(pSrc[loc:hp+2])), Cmp:HashMask)
!----
MatchLen ROUTINE
  loc:ml = 0
  LOOP WHILE loc:ml < Cmp:MaxMatch AND loc:mb + loc:ml <= pLen
    IF pSrc[loc:ma+loc:ml] <> pSrc[loc:mb+loc:ml] THEN BREAK.
    loc:ml += 1
  END
!----
EmitMatch ROUTINE
  loc:ls = 0
  LOOP loc:t = 28 TO 0 BY -1
    IF SELF.LenBase[loc:t+1] <= bestlen THEN loc:ls = loc:t; BREAK.
  END
  SELF.PutHuff(SELF.FixLitCode[257+loc:ls+1], SELF.FixLitLen[257+loc:ls+1])
  IF SELF.LenXtra[loc:ls+1] > 0
    SELF.PutBits(bestlen - SELF.LenBase[loc:ls+1], SELF.LenXtra[loc:ls+1])
  END
  loc:ds = 0
  LOOP loc:t = 29 TO 0 BY -1
    IF SELF.DstBase[loc:t+1] <= bestdist THEN loc:ds = loc:t; BREAK.
  END
  SELF.PutHuff(loc:ds, 5)                            ! fixed distance codes are 5-bit (value = symbol)
  IF SELF.DstXtra[loc:ds+1] > 0
    SELF.PutBits(bestdist - SELF.DstBase[loc:ds+1], SELF.DstXtra[loc:ds+1])
  END

!=== INFLATE (decompress) ====================================================
CompressClass.BuildFixed PROCEDURE
sym LONG
  CODE
  LOOP sym = 0 TO 287
    CASE sym
    OF 0 TO 143  ; SELF.CodeLen[sym+1] = 8
    OF 144 TO 255; SELF.CodeLen[sym+1] = 9
    OF 256 TO 279; SELF.CodeLen[sym+1] = 7
    ELSE         ; SELF.CodeLen[sym+1] = 8
    END
  END
  SELF.BuildHuff(SELF.CodeLen, 288, SELF.LLCnt, SELF.LLSym)
  LOOP sym = 0 TO 29; SELF.CodeLen[sym+1] = 5.
  SELF.BuildHuff(SELF.CodeLen, 30, SELF.DCnt, SELF.DSym)

CompressClass.ReadDynamic PROCEDURE()
hlit  LONG
hdist LONG
hclen LONG
i     LONG
j     LONG
s     LONG
rep   LONG
prev  LONG
  CODE
  hlit  = SELF.GetBits(5) + 257
  hdist = SELF.GetBits(5) + 1
  hclen = SELF.GetBits(4) + 4
  LOOP i = 1 TO 19; SELF.CodeLen[i] = 0.
  LOOP i = 1 TO hclen
    SELF.CodeLen[ SELF.CLOrder[i] + 1 ] = SELF.GetBits(3)
  END
  SELF.BuildHuff(SELF.CodeLen, 19, SELF.CLCnt, SELF.CLSym)
  i = 1
  LOOP WHILE i <= hlit + hdist
    s = SELF.DecodeSym(SELF.CLCnt, SELF.CLSym)
    IF s < 0 THEN RETURN 0.
    CASE s
    OF 0 TO 15
      SELF.CodeLen[i] = s; i += 1
    OF 16
      rep = SELF.GetBits(2) + 3
      IF i <= 1 THEN SELF.ErrCode=-10; SELF.ErrText='Bad code-length repeat'; RETURN 0.
      prev = SELF.CodeLen[i-1]
      LOOP j = 1 TO rep; SELF.CodeLen[i] = prev; i += 1.
    OF 17
      rep = SELF.GetBits(3) + 3
      LOOP j = 1 TO rep; SELF.CodeLen[i] = 0; i += 1.
    OF 18
      rep = SELF.GetBits(7) + 11
      LOOP j = 1 TO rep; SELF.CodeLen[i] = 0; i += 1.
    END
    IF SELF.ErrCode < 0 THEN RETURN 0.
  END
  SELF.BuildHuff(SELF.CodeLen, hlit, SELF.LLCnt, SELF.LLSym)
  LOOP j = 1 TO hdist; SELF.DLen[j] = SELF.CodeLen[hlit+j].
  SELF.BuildHuff(SELF.DLen, hdist, SELF.DCnt, SELF.DSym)
  RETURN 1

CompressClass.InflateBlock PROCEDURE()
s      LONG
ds     LONG
length LONG
dist   LONG
src    LONG
k      LONG
  CODE
  LOOP
    s = SELF.DecodeSym(SELF.LLCnt, SELF.LLSym)
    IF s < 0 THEN RETURN 0.
    IF s < 256
      SELF.PutByte(s)
    ELSIF s = 256
      RETURN 1                                       ! end of block
    ELSE
      s -= 257
      IF s > 28 THEN SELF.ErrCode=-5; SELF.ErrText='Bad length symbol'; RETURN 0.
      length = SELF.LenBase[s+1] + SELF.GetBits(SELF.LenXtra[s+1])
      ds = SELF.DecodeSym(SELF.DCnt, SELF.DSym)
      IF ds < 0 THEN RETURN 0.
      IF ds > 29 THEN SELF.ErrCode=-6; SELF.ErrText='Bad distance symbol'; RETURN 0.
      dist = SELF.DstBase[ds+1] + SELF.GetBits(SELF.DstXtra[ds+1])
      IF dist > SELF.OutLen THEN SELF.ErrCode=-7; SELF.ErrText='Distance too far back'; RETURN 0.
      SELF.EnsureOut(length)                          ! reserve up front so OutBuf cannot move mid-copy
      src = SELF.OutLen - dist
      LOOP k = 1 TO length
        SELF.OutLen += 1
        SELF.OutBuf[SELF.OutLen] = SELF.OutBuf[src+k] ! byte-by-byte: handles overlapping runs
      END
    END
    IF SELF.ErrCode < 0 THEN RETURN 0.
  END

CompressClass.Inflate PROCEDURE()
bfinal LONG
btype  LONG
lenv   LONG
nlen   LONG
i      LONG
  CODE
  bfinal = 0
  LOOP UNTIL bfinal
    bfinal = SELF.GetBits(1)
    btype  = SELF.GetBits(2)
    IF SELF.ErrCode < 0 THEN RETURN 0.
    CASE btype
    OF 0                                              ! stored
      SELF.AlignByte()
      lenv = BOR(SELF.NextStoredByte(), BSHIFT(SELF.NextStoredByte(),8))
      nlen = BOR(SELF.NextStoredByte(), BSHIFT(SELF.NextStoredByte(),8))
      IF lenv <> BAND(BXOR(nlen,0FFFFh),0FFFFh)
        SELF.ErrCode=-3; SELF.ErrText='Stored block length check failed'; RETURN 0
      END
      LOOP i = 1 TO lenv; SELF.PutByte(SELF.NextStoredByte()).
    OF 1                                              ! fixed Huffman
      SELF.BuildFixed()
      IF NOT SELF.InflateBlock() THEN RETURN 0.
    OF 2                                              ! dynamic Huffman
      IF NOT SELF.ReadDynamic()  THEN RETURN 0.
      IF NOT SELF.InflateBlock() THEN RETURN 0.
    ELSE
      SELF.ErrCode=-4; SELF.ErrText='Invalid DEFLATE block type'; RETURN 0
    END
    IF SELF.ErrCode < 0 THEN RETURN 0.
  END
  RETURN 1

!=== containers ==============================================================
CompressClass.Wrap PROCEDURE(*STRING pIn,LONG pInLen)
crc ULONG
ad  ULONG
  CODE
  IF NOT SELF.Ready THEN SELF.Init().
  SELF.ErrCode = 0; SELF.ErrText = ''
  SELF.ResetOut()
  CASE SELF.Format
  OF Cmp:Gzip
    SELF.PutByte(01Fh); SELF.PutByte(08Bh); SELF.PutByte(8); SELF.PutByte(0)
    SELF.PutByte(0); SELF.PutByte(0); SELF.PutByte(0); SELF.PutByte(0)   ! MTIME = 0
    SELF.PutByte(0); SELF.PutByte(0FFh)                                  ! XFL=0, OS=unknown
  OF Cmp:Zlib
    SELF.PutByte(078h); SELF.PutByte(001h)                              ! CMF=0x78, FLG=0x01 (check %% 31 == 0)
  END
  SELF.Deflate(pIn, pInLen)
  IF SELF.ErrCode < 0 THEN RETURN -1.
  CASE SELF.Format
  OF Cmp:Gzip
    crc = SELF.CRC32(pIn, pInLen)
    SELF.PutByte(BAND(crc,0FFh));            SELF.PutByte(BAND(BSHIFT(crc,-8),0FFh))
    SELF.PutByte(BAND(BSHIFT(crc,-16),0FFh));SELF.PutByte(BAND(BSHIFT(crc,-24),0FFh))
    SELF.PutByte(BAND(pInLen,0FFh));            SELF.PutByte(BAND(BSHIFT(pInLen,-8),0FFh))
    SELF.PutByte(BAND(BSHIFT(pInLen,-16),0FFh));SELF.PutByte(BAND(BSHIFT(pInLen,-24),0FFh))
  OF Cmp:Zlib
    ad = SELF.Adler32(pIn, pInLen)                                       ! zlib trailer is big-endian
    SELF.PutByte(BAND(BSHIFT(ad,-24),0FFh)); SELF.PutByte(BAND(BSHIFT(ad,-16),0FFh))
    SELF.PutByte(BAND(BSHIFT(ad,-8),0FFh));  SELF.PutByte(BAND(ad,0FFh))
  END
  RETURN SELF.OutLen

CompressClass.Unwrap PROCEDURE(*STRING pIn,LONG pInLen)
flg LONG
xl  LONG
hdr LONG
  CODE
  IF NOT SELF.Ready THEN SELF.Init().
  SELF.ErrCode = 0; SELF.ErrText = ''
  SELF.InBuf &= pIn
  SELF.InLen = pInLen
  SELF.InPos = 1
  SELF.BRAcc = 0; SELF.BRN = 0
  SELF.ResetOut()
  IF pInLen >= 2 AND VAL(pIn[1]) = 01Fh AND VAL(pIn[2]) = 08Bh
    SELF.InPos = 4                                    ! past magic + CM
    flg = VAL(pIn[4])
    SELF.InPos = 11                                   ! past the 10-byte fixed header
    IF BAND(flg,4)                                    ! FEXTRA
      xl = SELF.ByteIn(); xl = BOR(xl, BSHIFT(SELF.ByteIn(),8)); SELF.InPos += xl
    END
    IF BAND(flg,8)                                    ! FNAME (NUL-terminated)
      LOOP
        IF SELF.ByteIn() = 0 OR SELF.ErrCode < 0 THEN BREAK.
      END
    END
    IF BAND(flg,16)                                   ! FCOMMENT (NUL-terminated)
      LOOP
        IF SELF.ByteIn() = 0 OR SELF.ErrCode < 0 THEN BREAK.
      END
    END
    IF BAND(flg,2) THEN SELF.InPos += 2.              ! FHCRC
    SELF.BRAcc = 0; SELF.BRN = 0
  ELSE
    hdr = VAL(pIn[1]) * 256 + VAL(pIn[2])
    IF pInLen >= 2 AND BAND(VAL(pIn[1]),0Fh) = 8 AND hdr - INT(hdr/31)*31 = 0
      SELF.InPos = 3                                  ! zlib 2-byte header
      SELF.BRAcc = 0; SELF.BRN = 0
    ELSE
      SELF.InPos = 1                                  ! assume raw DEFLATE
    END
  END
  IF NOT SELF.Inflate() THEN RETURN -1.
  RETURN SELF.OutLen

!=== public : memory =========================================================
CompressClass.MaxCompressed PROCEDURE(LONG pInLen)
  CODE
  RETURN pInLen + INT(pInLen/8) + 128 + 5 * (INT(pInLen/65535) + 1)

CompressClass.Compress PROCEDURE(*STRING pIn,LONG pInLen,*STRING pOut)
n LONG
  CODE
  n = SELF.Wrap(pIn, pInLen)
  IF n < 0 THEN RETURN -1.
  IF SIZE(pOut) < n
    SELF.ErrCode = -8; SELF.ErrText = 'Output buffer too small'; RETURN -1
  END
  pOut[1 : n] = SELF.OutBuf[1 : n]
  RETURN n

CompressClass.Decompress PROCEDURE(*STRING pIn,LONG pInLen,*STRING pOut)
n LONG
  CODE
  n = SELF.Unwrap(pIn, pInLen)
  IF n < 0 THEN RETURN -1.
  IF SIZE(pOut) < n
    SELF.ErrCode = -9; SELF.ErrText = 'Output buffer too small'; RETURN -1
  END
  IF n > 0 THEN pOut[1 : n] = SELF.OutBuf[1 : n].
  RETURN n

!=== public : files ==========================================================
CompressClass.CompressFile PROCEDURE(STRING pSrc,STRING pDst)
hr   LONG
hw   LONG
sz   ULONG
rd   ULONG
wr   ULONG
inb  &STRING
n    LONG
src  CSTRING(File:MaxFilePath+1)
dst  CSTRING(File:MaxFilePath+1)
  CODE
  SELF.ErrCode = 0; SELF.ErrText = ''
  src = CLIP(pSrc); dst = CLIP(pDst)
  hr = kCreateFile(src, 080000000h, 1, 0, 3, 080h, 0)            ! GENERIC_READ, share-read, OPEN_EXISTING
  IF hr = -1 THEN SELF.ErrCode=-20; SELF.ErrText='Cannot open source file'; RETURN 0.
  sz = kGetFileSize(hr, 0)
  inb &= NEW STRING(CHOOSE(sz > 0, sz, 1))
  IF sz > 0 THEN kReadFile(hr, ADDRESS(inb), sz, rd, 0).
  kCloseHandle(hr)
  n = SELF.Wrap(inb, sz)                                         ! compress -> SELF.OutBuf
  IF n < 0 THEN DISPOSE(inb); RETURN 0.
  hw = kCreateFile(dst, 040000000h, 0, 0, 2, 080h, 0)           ! GENERIC_WRITE, CREATE_ALWAYS
  IF hw = -1 THEN SELF.ErrCode=-21; SELF.ErrText='Cannot create target file'; DISPOSE(inb); RETURN 0.
  kWriteFile(hw, ADDRESS(SELF.OutBuf), n, wr, 0)
  kCloseHandle(hw)
  DISPOSE(inb)
  IF wr <> n THEN SELF.ErrCode=-22; SELF.ErrText='Short write to target file'; RETURN 0.
  RETURN 1

CompressClass.DecompressFile PROCEDURE(STRING pSrc,STRING pDst)
hr   LONG
hw   LONG
sz   ULONG
rd   ULONG
wr   ULONG
inb  &STRING
n    LONG
src  CSTRING(File:MaxFilePath+1)
dst  CSTRING(File:MaxFilePath+1)
  CODE
  SELF.ErrCode = 0; SELF.ErrText = ''
  src = CLIP(pSrc); dst = CLIP(pDst)
  hr = kCreateFile(src, 080000000h, 1, 0, 3, 080h, 0)
  IF hr = -1 THEN SELF.ErrCode=-20; SELF.ErrText='Cannot open source file'; RETURN 0.
  sz = kGetFileSize(hr, 0)
  inb &= NEW STRING(CHOOSE(sz > 0, sz, 1))
  IF sz > 0 THEN kReadFile(hr, ADDRESS(inb), sz, rd, 0).
  kCloseHandle(hr)
  n = SELF.Unwrap(inb, sz)                                       ! decompress -> SELF.OutBuf
  DISPOSE(inb)
  IF n < 0 THEN RETURN 0.
  hw = kCreateFile(dst, 040000000h, 0, 0, 2, 080h, 0)
  IF hw = -1 THEN SELF.ErrCode=-21; SELF.ErrText='Cannot create target file'; RETURN 0.
  IF n > 0 THEN kWriteFile(hw, ADDRESS(SELF.OutBuf), n, wr, 0) ELSE wr = 0.
  kCloseHandle(hw)
  IF wr <> n THEN SELF.ErrCode=-22; SELF.ErrText='Short write to target file'; RETURN 0.
  RETURN 1

!=== self-test ===============================================================
CompressClass.SelfTest PROCEDURE()
raw   STRING(512)
comp  &STRING
back  STRING(512)
rlen  LONG
clen  LONG
blen  LONG
i     LONG
savef BYTE
  CODE
  ! Round-trip a known buffer (with repetition, so LZ77 actually fires) through
  ! every container and confirm the bytes come back identical.
  raw  = 'The quick brown fox jumps over the lazy dog. ' &|
         'The quick brown fox jumps over the lazy dog. ' &|
         'PACK ME PACK ME PACK ME PACK ME 1234567890 1234567890'
  rlen = 143                                             ! fixed length (binary-safe; do not use LEN on a STRING)
  savef = SELF.Format
  comp &= NEW STRING(SELF.MaxCompressed(rlen))
  LOOP i = 0 TO 2                                        ! 0=raw, 1=zlib, 2=gzip
    SELF.Format = i
    clen = SELF.Compress(raw, rlen, comp)
    IF clen < 0 THEN SELF.Format = savef; DISPOSE(comp); RETURN 0.
    blen = SELF.Decompress(comp, clen, back)
    IF blen <> rlen THEN SELF.Format = savef; DISPOSE(comp); RETURN 0.
    IF back[1 : rlen] <> raw[1 : rlen]
      SELF.Format = savef; DISPOSE(comp); RETURN 0
    END
  END
  SELF.Format = savef
  DISPOSE(comp)
  RETURN 1
