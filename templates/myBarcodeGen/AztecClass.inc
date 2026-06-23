!ABCIncludeFile
! ============================================================================
!  AztecClass - self-contained Aztec Code encoder for Clarion.
!
!  Binary high-level encoding, compact + full symbols, Reed-Solomon over the
!  variable Galois field GF(2^wordSize) (6/8/10/12 bits by layer count), the
!  central bullseye + mode message, and the spiral data placement (with the
!  full-symbol reference grid). A port of the ZXing-validated C# reference
!  (designer/BarcodeCore/Aztec.cs). Build()/Paint()/Draw() render Cells[] as a
!  square BOX grid, like QRCodeClass.
!
!  This file MUST be stored in ANSI (not UTF-8).
! ============================================================================

Aztec:Cap          EQUATE(8000)                              ! bit-array cap (covers practical sizes)

AztecClass CLASS,TYPE,MODULE('AztecClass.CLW'),LINK('AztecClass.CLW')
Ready              BYTE
WordSizeTbl        LONG,DIM(33)                              ! word size by layer count
GFExp              LONG,DIM(8192)                            ! GF(2^wordSize) antilog (rebuilt per field)
GFLog              LONG,DIM(4096)
GFSize             LONG
Bits               BYTE,DIM(Aztec:Cap)                       ! high-level bits
NBits              LONG
Stuffed            BYTE,DIM(Aztec:Cap)                       ! bit-stuffed words
NStuffed           LONG
MsgBits            BYTE,DIM(Aztec:Cap)                       ! data + check words as bits
NMsg               LONG
ModeBits           BYTE,DIM(48)                              ! mode message bits
RsIn               LONG,DIM(1400)                            ! RS input words
RsOut              LONG,DIM(400)                             ! RS output (EC) words
Words              LONG,DIM(1400)                            ! all message words (data + EC)
AlignMap           LONG,DIM(160)                             ! base coord -> matrix coord
Cells              BYTE,DIM(90,90)                           ! the symbol (1 = dark), [row,col]
N                  LONG                                      ! matrix dimension
! ---- construct / destruct --------------------------------------------------
Construct          PROCEDURE
Destruct           PROCEDURE
! ---- public ----------------------------------------------------------------
Draw               PROCEDURE(SIGNED pImageFeq,*CSTRING pValue,LONG pDark,LONG pLight,LONG pQuiet)
Build              PROCEDURE(*CSTRING pValue),BYTE
Paint              PROCEDURE(SIGNED pImageFeq,LONG pDark,LONG pLight,LONG pQuiet)
! ---- internal --------------------------------------------------------------
Init               PROCEDURE
Modulo             PROCEDURE(LONG a,LONG b),LONG
GfBuild            PROCEDURE(LONG wordSize)
GfMul              PROCEDURE(LONG a,LONG b),LONG
RsEcc              PROCEDURE(LONG dataLen,LONG ecLen)        ! SELF.RsIn -> SELF.RsOut, current GF
SetCell            PROCEDURE(LONG x,LONG y)
                   END
