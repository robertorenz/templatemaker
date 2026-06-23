!ABCIncludeFile
! ============================================================================
!  DataMatrixClass - self-contained Data Matrix (ECC200) encoder for Clarion.
!
!  ASCII encodation, square symbols 10x10..26x26 (single data region). A port of
!  the ZXing-validated C# reference (designer/BarcodeCore/DataMatrix.cs). Builds
!  a module matrix (Cells[], 1 = dark) which Paint()/Draw() render as a BOX grid,
!  exactly like QRCodeClass.
!
!  Reed-Solomon is over GF(256) with primitive polynomial 0x12D and generator
!  base 1 (the Data Matrix field - NOT the QR 0x11D / base 0).
!
!  USAGE (myBarcodeGen template):
!    INCLUDE('DataMatrixClass.INC'),ONCE   and declare: DataMatrixObj DataMatrixClass
!    DataMatrixObj.Draw(?Image, loc:Value, COLOR:Black, COLOR:White, 2)
!
!  This file MUST be stored in ANSI (not UTF-8).
! ============================================================================

DataMatrixClass CLASS,TYPE,MODULE('DataMatrixClass.CLW'),LINK('DataMatrixClass.CLW')
Ready              BYTE
GFExp              LONG,DIM(512)                              ! GF(256) antilog (0x12D)
GFLog              LONG,DIM(256)
Cells              BYTE,DIM(32,32)                            ! full symbol (1 = dark), [row+1,col+1]
N                  LONG                                       ! symbol dimension
PNrow              LONG                                       ! placement region rows
PNcol              LONG                                       ! placement region cols
Data               LONG,DIM(80)                               ! data codewords (pre-RS)
NData              LONG
CW                 LONG,DIM(80)                               ! data + EC codewords (placement reads these)
RBit               BYTE,DIM(24,24)                            ! data-region bits
RSet               BYTE,DIM(24,24)                            ! data-region placed map
SzDim              LONG,DIM(9)                                ! size table: symbol dim
SzReg              LONG,DIM(9)                                !   data-region dim
SzData             LONG,DIM(9)                                !   data codewords
SzEc               LONG,DIM(9)                                !   EC codewords
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
GfMul              PROCEDURE(LONG a,LONG b),LONG
ReedSolomon        PROCEDURE(LONG dataLen,LONG ecLen)         ! SELF.Data -> appends EC into SELF.CW
PModule            PROCEDURE(LONG row,LONG col,LONG pos,LONG b)
PUtah              PROCEDURE(LONG row,LONG col,LONG pos)
PCorner            PROCEDURE(LONG which,LONG pos)
Placement          PROCEDURE
                   END
