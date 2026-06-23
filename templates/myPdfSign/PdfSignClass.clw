! ============================================================================
!  PdfSignClass - implementation.  Pure-Clarion signed-PDF identity reader.
!
!  Two layers:
!    1. PDF structure (ASCII): find /ByteRange + /Contents <hex>, read the
!       self-asserted /Name /Reason /Location /SubFilter, check ByteRange.
!    2. PKCS#7 / CMS (binary DER): a minimal tag/length reader walks to the
!       signer certificate's Subject + Issuer RDNs and the signingTime.
!
!  Clarion port notes:
!   - Strings are 1-based; one byte is s[i] = CHR(v) / VAL(s[i]).
!   - Bit ops are functions: BAND(a,b) etc.  Integer assign ROUNDS, so divides
!     that must truncate use INT() (here hLen/2 is exact, n is integer math).
!   - DER lengths are big-endian; the high bit of the first length octet means
!     "the next (b AND 7Fh) octets are the length" (ASN.1 BER/DER long form).
!
!  This file MUST be stored in ANSI (not UTF-8).
! ============================================================================
  MEMBER

  MAP                                       ! module-level MAP (folds BUILTINS.CLW in) + Win32 file calls
    MODULE('kernel32')
kCreateFile        PROCEDURE(*CSTRING,ULONG,ULONG,LONG,ULONG,ULONG,LONG),LONG,RAW,PASCAL,NAME('CreateFileA')
kReadFile          PROCEDURE(LONG,LONG,ULONG,*ULONG,LONG),LONG,RAW,PASCAL,PROC,NAME('ReadFile')
kGetFileSize       PROCEDURE(LONG,LONG),ULONG,PASCAL,NAME('GetFileSize')
kCloseHandle       PROCEDURE(LONG),LONG,PASCAL,PROC,NAME('CloseHandle')
    END
  END

  INCLUDE('PdfSignClass.INC'),ONCE

!=== construct / destruct ====================================================
PdfSignClass.Construct PROCEDURE()
  CODE
  SELF.Pdf &= NULL
  SELF.Der &= NULL
  SELF.PdfOwned = 0
  SELF.Reset()

PdfSignClass.Destruct PROCEDURE()
  CODE
  IF SELF.PdfOwned = 1 AND NOT SELF.Pdf &= NULL THEN DISPOSE(SELF.Pdf).
  IF NOT SELF.Der &= NULL THEN DISPOSE(SELF.Der).

PdfSignClass.Reset PROCEDURE()
  CODE
  SELF.Signed = 0; SELF.SigCount = 0
  SELF.SubjectCN = ''; SELF.SubjectO = ''; SELF.SubjectOU = ''; SELF.SubjectEmail = ''
  SELF.IssuerCN = ''; SELF.SignTime = ''
  SELF.SignerName = ''; SELF.Reason = ''; SELF.Location = ''; SELF.SubFilter = ''
  SELF.CoversWholeFile = 0
  SELF.ErrCode = 0; SELF.ErrText = ''

!=== public : load a file, then parse ========================================
PdfSignClass.ReadFile PROCEDURE(STRING pPath)
hr   LONG
sz   ULONG
rd   ULONG
src  CSTRING(File:MaxFilePath+1)
  CODE
  SELF.Reset()
  IF SELF.PdfOwned = 1 AND NOT SELF.Pdf &= NULL THEN DISPOSE(SELF.Pdf).
  SELF.Pdf &= NULL; SELF.PdfOwned = 0; SELF.PdfLen = 0
  src = CLIP(pPath)
  hr = kCreateFile(src, 080000000h, 1, 0, 3, 080h, 0)        ! GENERIC_READ, share-read, OPEN_EXISTING
  IF hr = -1 THEN SELF.ErrCode=-20; SELF.ErrText='Cannot open PDF file'; RETURN 0.
  sz = kGetFileSize(hr, 0)
  SELF.Pdf &= NEW STRING(CHOOSE(sz > 0, sz, 1))
  SELF.PdfOwned = 1
  IF sz > 0 THEN kReadFile(hr, ADDRESS(SELF.Pdf), sz, rd, 0).
  kCloseHandle(hr)
  SELF.PdfLen = sz
  RETURN SELF.Read(SELF.Pdf, SELF.PdfLen)

!=== public : parse a PDF already in memory ==================================
PdfSignClass.Read PROCEDURE(*STRING pPdf,LONG pLen)
hs   LONG
hl   LONG
cp   LONG
n    LONG
  CODE
  SELF.Reset()
  IF pLen < 8 THEN SELF.ErrCode=-1; SELF.ErrText='Not a PDF (too small)'; RETURN 0.
  ! count signature dictionaries (each carries one /ByteRange)
  cp = 0; n = 0
  LOOP
    cp = INSTRING('/ByteRange', pPdf, 1, cp+1)
    IF cp = 0 THEN BREAK.
    n += 1
  END
  SELF.SigCount = n
  IF NOT SELF.FindContents(pPdf, pLen, hs, hl)
    SELF.ErrCode = -2; SELF.ErrText = 'No signature found in PDF'
    RETURN 1                                                 ! parsed OK; just not signed
  END
  SELF.HexToDer(pPdf, hs, hl)
  IF NOT SELF.ParseSigner()
    SELF.ErrCode = -3; SELF.ErrText = 'Could not parse PKCS#7 signature'
    RETURN 1
  END
  SELF.GetParen(pPdf, pLen, '/Name(',      SELF.SignerName)
  SELF.GetParen(pPdf, pLen, '/Reason(',    SELF.Reason)
  SELF.GetParen(pPdf, pLen, '/Location(',  SELF.Location)
  SELF.GetName (pPdf, pLen, '/SubFilter/', SELF.SubFilter)
  SELF.CoversWholeFile = SELF.ByteRangeCovers(pPdf, pLen)
  SELF.Signed = 1
  RETURN 1

!=== PDF structure ===========================================================
PdfSignClass.IsHex PROCEDURE(LONG pB)
  CODE
  RETURN CHOOSE((pB>=48 AND pB<=57) OR (pB>=65 AND pB<=70) OR (pB>=97 AND pB<=102), 1, 0)

PdfSignClass.FindContents PROCEDURE(*STRING pPdf,LONG pLen,*LONG oStart,*LONG oLen)
cp   LONG
i    LONG
j    LONG
ch   LONG
  CODE
  oStart = 0; oLen = 0
  cp = 1
  LOOP
    cp = INSTRING('/Contents', pPdf, 1, cp)
    IF cp = 0 THEN RETURN 0.
    i = cp + 9                                               ! first char after "/Contents"
    LOOP WHILE i <= pLen                                     ! skip whitespace
      ch = VAL(pPdf[i])
      IF ch=32 OR ch=13 OR ch=10 OR ch=9
        i += 1
      ELSE
        BREAK
      END
    END
    IF i <= pLen AND VAL(pPdf[i]) = 60                       ! '<' begins a hex string
      IF i+1 <= pLen AND SELF.IsHex(VAL(pPdf[i+1]))          ! ... and not a '<<' dictionary
        oStart = i + 1
        j = oStart
        LOOP WHILE j <= pLen AND VAL(pPdf[j]) <> 62          ! up to '>'
          j += 1
        END
        oLen = j - oStart
        RETURN 1
      END
    END
    cp = cp + 9
  END

PdfSignClass.HexToDer PROCEDURE(*STRING pPdf,LONG hStart,LONG hLen)
i    LONG
ch   LONG
b    LONG
hi   LONG
n    LONG
cap  LONG
e    LONG
  CODE
  cap = hLen/2 + 4
  IF NOT SELF.Der &= NULL THEN DISPOSE(SELF.Der).
  SELF.Der &= NEW STRING(cap)
  n = 0; hi = -1; i = hStart
  LOOP WHILE i < hStart + hLen
    ch = VAL(pPdf[i]); i += 1
    IF NOT SELF.IsHex(ch) THEN CYCLE.                        ! skip whitespace / newlines inside the hex
    IF ch <= 57
      b = ch - 48
    ELSIF ch <= 70
      b = ch - 55
    ELSE
      b = ch - 87
    END
    IF hi < 0
      hi = b
    ELSE
      n += 1
      SELF.Der[n] = CHR(hi*16 + b)
      hi = -1
    END
  END
  SELF.DerLen = n
  ! trim placeholder zero-padding: the real blob is one self-delimiting DER object
  IF n >= 2
    e = SELF.DerNext(1)
    IF e > 1 AND e-1 <= n THEN SELF.DerLen = e-1.
  END
  RETURN 1

PdfSignClass.GetParen PROCEDURE(*STRING pPdf,LONG pLen,STRING pKey,*CSTRING oVal)
p    LONG
i    LONG
ch   LONG
klen LONG
  CODE
  oVal = ''
  klen = LEN(CLIP(pKey))
  p = INSTRING(CLIP(pKey), pPdf, 1, 1)
  IF p = 0 THEN RETURN.
  i = p + klen                                               ! first char inside the parentheses
  LOOP WHILE i <= pLen
    ch = VAL(pPdf[i]); i += 1
    IF ch = 41 THEN BREAK.                                   ! ')'
    IF ch = 92                                               ! '\' -> next char is literal
      IF i <= pLen
        ch = VAL(pPdf[i]); i += 1
      ELSE
        BREAK
      END
    END
    oVal = oVal & CHR(ch)
  END

PdfSignClass.GetName PROCEDURE(*STRING pPdf,LONG pLen,STRING pKey,*CSTRING oVal)
p    LONG
i    LONG
ch   LONG
klen LONG
  CODE
  oVal = ''
  klen = LEN(CLIP(pKey))
  p = INSTRING(CLIP(pKey), pPdf, 1, 1)
  IF p = 0 THEN RETURN.
  i = p + klen
  LOOP WHILE i <= pLen
    ch = VAL(pPdf[i])
    CASE ch
    OF 47 OROF 62 OROF 32 OROF 13 OROF 10 OROF 9 OROF 91 OROF 40         ! / > sp CR LF tab [ (
      BREAK
    END
    oVal = oVal & CHR(ch)
    i += 1
  END

PdfSignClass.ByteRangeCovers PROCEDURE(*STRING pPdf,LONG pLen)
p     LONG
i     LONG
ch    LONG
nums  LONG
cur   LONG
inNum BYTE
v     LONG,DIM(4)
  CODE
  p = INSTRING('/ByteRange', pPdf, 1, 1)
  IF p = 0 THEN RETURN 0.
  i = p + 10
  LOOP WHILE i <= pLen AND VAL(pPdf[i]) <> 91               ! advance to '['
    i += 1
  END
  i += 1
  nums = 0; cur = 0; inNum = 0
  LOOP WHILE i <= pLen
    ch = VAL(pPdf[i]); i += 1
    IF ch >= 48 AND ch <= 57
      cur = cur*10 + (ch-48); inNum = 1
    ELSE
      IF inNum
        nums += 1
        IF nums <= 4 THEN v[nums] = cur.
        cur = 0; inNum = 0
      END
      IF ch = 93 THEN BREAK.                                 ! ']'
    END
  END
  IF nums < 4 THEN RETURN 0.
  ! whole-file coverage: first segment starts at 0 and the second ends at EOF
  IF v[1] = 0 AND (v[3] + v[4]) = pLen THEN RETURN 1.
  RETURN 0

!=== DER (ASN.1) reader ======================================================
PdfSignClass.DerHdr PROCEDURE(LONG p,*LONG oContent,*LONG oLen)
b    LONG
nn   LONG
k    LONG
ln   LONG
  CODE
  b = VAL(SELF.Der[p+1])
  IF b < 128
    oLen = b
    oContent = p + 2
  ELSE
    nn = BAND(b, 127)
    ln = 0
    LOOP k = 1 TO nn
      ln = ln*256 + VAL(SELF.Der[p+1+k])
    END
    oLen = ln
    oContent = p + 2 + nn
  END

PdfSignClass.DerNext PROCEDURE(LONG p)
c    LONG
l    LONG
  CODE
  SELF.DerHdr(p, c, l)
  RETURN c + l

PdfSignClass.DerInto PROCEDURE(LONG p)
c    LONG
l    LONG
  CODE
  SELF.DerHdr(p, c, l)
  RETURN c

PdfSignClass.GetAttr PROCEDURE(LONG rStart,LONG rEnd,*CSTRING pPat,*CSTRING oVal)
pos  LONG
vp   LONG
c    LONG
l    LONG
  CODE
  oVal = ''
  pos = INSTRING(pPat, SELF.Der, 1, rStart)                  ! find the attribute's OID TLV
  IF pos = 0 OR pos >= rEnd THEN RETURN.
  vp = SELF.DerNext(pos)                                     ! the value TLV sits right after the OID
  IF vp <= 0 OR vp > SELF.DerLen THEN RETURN.
  SELF.DerHdr(vp, c, l)
  IF l <= 0 THEN RETURN.
  IF l > 255 THEN l = 255.
  oVal = SUB(SELF.Der, c, l)

PdfSignClass.GetSignTime PROCEDURE()
pat  CSTRING(16)
pos  LONG
setP LONG
tp   LONG
c    LONG
l    LONG
tag  LONG
raw  STRING(24)
yy   LONG
yyyy LONG
  CODE
  SELF.SignTime = ''
  ! signingTime OID  1.2.840.113549.1.9.5  (full TLV: 06 09 2A 86 48 86 F7 0D 01 09 05)
  pat = CHR(6)&CHR(9)&CHR(42)&CHR(134)&CHR(72)&CHR(134)&CHR(247)&CHR(13)&CHR(1)&CHR(9)&CHR(5)
  pos = INSTRING(pat, SELF.Der, 1, 1)
  IF pos = 0 THEN RETURN.
  setP = SELF.DerNext(pos)                                   ! SET wrapping the time value
  tp   = SELF.DerInto(setP)                                  ! the time TLV
  tag  = VAL(SELF.Der[tp])
  SELF.DerHdr(tp, c, l)
  IF l < 11 THEN RETURN.
  raw = SUB(SELF.Der, c, l)
  IF tag = 17h                                               ! UTCTIME  YYMMDDHHMMSSZ
    yy = DEFORMAT(raw[1 : 2])
    IF yy < 50 THEN yyyy = 2000 + yy ELSE yyyy = 1900 + yy.
    SELF.SignTime = FORMAT(yyyy,@n4) & '-' & raw[3 : 4] & '-' & raw[5 : 6] & 'T' & |
                    raw[7 : 8] & ':' & raw[9 : 10] & ':' & raw[11 : 12] & 'Z'
  ELSIF tag = 18h                                            ! GeneralizedTime  YYYYMMDDHHMMSSZ
    SELF.SignTime = raw[1 : 4] & '-' & raw[5 : 6] & '-' & raw[7 : 8] & 'T' & |
                    raw[9 : 10] & ':' & raw[11 : 12] & ':' & raw[13 : 14] & 'Z'
  END

PdfSignClass.ParseSigner PROCEDURE()
c1   LONG
c2   LONG
c3   LONG
c4   LONG
c5   LONG
p    LONG
issS LONG
issE LONG
subS LONG
subE LONG
patCN CSTRING(8)
patO  CSTRING(8)
patOU CSTRING(8)
patE  CSTRING(16)
  CODE
  IF SELF.DerLen < 16 THEN RETURN 0.
  ! ContentInfo SEQUENCE -> OID signedData -> [0] -> SignedData SEQUENCE
  IF VAL(SELF.Der[1]) <> 30h THEN RETURN 0.
  c1 = SELF.DerInto(1)                                       ! -> OID (signedData)
  p  = SELF.DerNext(c1)                                      ! -> [0] content wrapper
  IF VAL(SELF.Der[p]) <> 0A0h THEN RETURN 0.
  c2 = SELF.DerInto(p)                                       ! -> SignedData SEQUENCE
  IF VAL(SELF.Der[c2]) <> 30h THEN RETURN 0.
  c3 = SELF.DerInto(c2)                                      ! -> version INTEGER
  p  = SELF.DerNext(c3)                                      ! skip version
  p  = SELF.DerNext(p)                                       ! skip digestAlgorithms SET
  p  = SELF.DerNext(p)                                       ! skip encapContentInfo SEQUENCE
  IF VAL(SELF.Der[p]) <> 0A0h THEN RETURN 0.                 ! certificates [0]
  c4 = SELF.DerInto(p)                                       ! -> first Certificate SEQUENCE
  c5 = SELF.DerInto(c4)                                      ! -> tbsCertificate SEQUENCE
  p  = SELF.DerInto(c5)                                      ! -> first tbs element
  IF VAL(SELF.Der[p]) = 0A0h THEN p = SELF.DerNext(p).       ! skip optional [0] version
  p  = SELF.DerNext(p)                                       ! skip serialNumber INTEGER
  p  = SELF.DerNext(p)                                       ! skip signature AlgId SEQUENCE
  issS = p                                                   ! issuer Name (RDNSequence)
  issE = SELF.DerNext(p)
  p    = issE
  p    = SELF.DerNext(p)                                     ! skip validity SEQUENCE
  subS = p                                                   ! subject Name (RDNSequence)
  subE = SELF.DerNext(p)
  ! RDN attribute OIDs (full TLV: 06 03 55 04 xx  /  emailAddress 06 09 ...)
  patCN = CHR(6)&CHR(3)&CHR(85)&CHR(4)&CHR(3)                ! 2.5.4.3  commonName
  patO  = CHR(6)&CHR(3)&CHR(85)&CHR(4)&CHR(10)               ! 2.5.4.10 organizationName
  patOU = CHR(6)&CHR(3)&CHR(85)&CHR(4)&CHR(11)               ! 2.5.4.11 organizationalUnitName
  patE  = CHR(6)&CHR(9)&CHR(42)&CHR(134)&CHR(72)&CHR(134)&CHR(247)&CHR(13)&CHR(1)&CHR(9)&CHR(1)
  SELF.GetAttr(subS, subE, patCN, SELF.SubjectCN)
  SELF.GetAttr(subS, subE, patO,  SELF.SubjectO)
  SELF.GetAttr(subS, subE, patOU, SELF.SubjectOU)
  SELF.GetAttr(subS, subE, patE,  SELF.SubjectEmail)
  SELF.GetAttr(issS, issE, patCN, SELF.IssuerCN)
  SELF.GetSignTime()
  RETURN 1

!=== identity report (matches PdfSignCore's expected.txt) =====================
PdfSignClass.Report PROCEDURE()
  CODE
  RETURN 'SubjectCN=' & CLIP(SELF.SubjectCN) & CHR(10) & |
         'SubjectO=' & CLIP(SELF.SubjectO) & CHR(10) & |
         'SubjectOU=' & CLIP(SELF.SubjectOU) & CHR(10) & |
         'SubjectEmail=' & CLIP(SELF.SubjectEmail) & CHR(10) & |
         'IssuerCN=' & CLIP(SELF.IssuerCN) & CHR(10) & |
         'SignTimeUtc=' & CLIP(SELF.SignTime) & CHR(10) & |
         'Name=' & CLIP(SELF.SignerName) & CHR(10) & |
         'Reason=' & CLIP(SELF.Reason) & CHR(10) & |
         'Location=' & CLIP(SELF.Location) & CHR(10) & |
         'SubFilter=' & CLIP(SELF.SubFilter) & CHR(10) & |
         'ByteRangeCoversFile=' & SELF.CoversWholeFile

!=== self-test ===============================================================
PdfSignClass.SelfTest PROCEDURE()
h    STRING(32)
pat  CSTRING(8)
got  CSTRING(64)
  CODE
  ! Exercise hex-decode + the DER reader + RDN extraction without any file:
  ! DER for  SEQUENCE { OID 2.5.4.3, PrintableString "Hi" } -> expect "Hi".
  h = '30090603550403130248 69'                             ! 30 09 06 03 55 04 03 13 02 48 69
  SELF.HexToDer(h, 1, LEN(CLIP(h)))
  pat = CHR(6)&CHR(3)&CHR(85)&CHR(4)&CHR(3)
  SELF.GetAttr(1, SELF.DerLen+1, pat, got)
  RETURN CHOOSE(got = 'Hi', 1, 0)
