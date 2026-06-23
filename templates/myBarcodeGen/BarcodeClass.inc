!ABCIncludeFile
! ============================================================================
!  BarcodeClass - self-contained LINEAR (1D) barcode encoder for Clarion.
!
!  Symbologies: Code 39, Code 128 (auto Code B / Code C), Interleaved 2 of 5,
!  EAN-13, UPC-A. A port of the ZXing-validated C# reference (BarcodeCore); each
!  encoder builds a bar pattern (Bars[], 1 = dark module at narrowest-element
!  resolution) which Draw() renders as full-height BOX bars, with an optional
!  human-readable line. 2D codes (QR, ...) are handled by their own classes.
!
!  USAGE (handled by the myBarcodeGen template):
!    INCLUDE('BarcodeClass.INC'),ONCE   and declare one instance: BarcodeObj BarcodeClass
!    BarcodeObj.Draw(?Image, BC:Code128, loc:Value, COLOR:Black, COLOR:White, 10, 1)
!
!  This file MUST be stored in ANSI (not UTF-8).
! ============================================================================

BC:Code39          EQUATE(1)
BC:Code128         EQUATE(2)
BC:ITF             EQUATE(3)
BC:EAN13           EQUATE(4)
BC:UPCA            EQUATE(5)
BC:QR              EQUATE(6)                                  ! drawn by QRCodeClass, not this class
BC:DataMatrix      EQUATE(7)                                  ! drawn by DataMatrixClass, not this class
BC:PDF417          EQUATE(8)                                  ! drawn by Pdf417Class, not this class

BarcodeClass CLASS,TYPE,MODULE('BarcodeClass.CLW'),LINK('BarcodeClass.CLW')
Ready              BYTE                                       ! 1 once the lookup tables are built
Wide               LONG                                      ! wide:narrow ratio (default 3)
Bars               BYTE,DIM(4000)                            ! the bar pattern (1 = dark module)
NBars              LONG                                      ! number of modules in Bars
HumanText          CSTRING(256)                              ! value shown under the bars (incl. check digit)
C39Set             CSTRING(48)                               ! Code 39 character set (index -> pattern)
C39All             STRING(396)                               ! Code 39 patterns, 9 chars each (n/w)
ItfAll             STRING(50)                                ! ITF digit patterns, 5 chars each
C128All            STRING(643)                               ! Code 128 patterns, 6 chars each (+7 stop)
EanL               STRING(70)                                ! EAN/UPC L codes, 7 bits each
EanG               STRING(70)                                ! EAN G codes
EanR               STRING(70)                                ! EAN R codes
EanPar             STRING(60)                                ! EAN first-digit parity, 6 chars each (L/G)
! ---- construct / destruct --------------------------------------------------
Construct          PROCEDURE
Destruct           PROCEDURE
! ---- public methods --------------------------------------------------------
Draw               PROCEDURE(SIGNED pImageFeq,LONG pType,*CSTRING pValue,LONG pDark,LONG pLight,LONG pQuiet,LONG pShowText)
Build              PROCEDURE(LONG pType,*CSTRING pValue),BYTE
PaintBars          PROCEDURE(SIGNED pImageFeq,LONG pDark,LONG pLight,LONG pQuiet,LONG pShowText)
! ---- internal --------------------------------------------------------------
Init               PROCEDURE
Modulo             PROCEDURE(LONG a,LONG b),LONG
AddRun             PROCEDURE(LONG dark,LONG n)
AddBitStr          PROCEDURE(STRING s,LONG cnt)
AddSym39           PROCEDURE(LONG idx)
Code39             PROCEDURE(*CSTRING data),BYTE
Itf                PROCEDURE(*CSTRING digits),BYTE
Code128            PROCEDURE(*CSTRING data),BYTE
Ean13              PROCEDURE(*CSTRING digits),BYTE
UpcA               PROCEDURE(*CSTRING digits),BYTE
EanCheckDigit      PROCEDURE(*CSTRING d12),STRING
UpcCheckDigit      PROCEDURE(*CSTRING d11),STRING
                   END
