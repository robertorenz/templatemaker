!ABCIncludeFile
! ============================================================================
!  Pdf417Class - self-contained PDF417 encoder for Clarion.
!
!  Byte compaction, Reed-Solomon over the prime field GF(929) (generator computed
!  at run time), automatic columns/rows + EC level, and the 17-module codeword
!  patterns (packed table, unpacked at startup). A port of the ZXing-validated
!  C# reference (designer/BarcodeCore/Pdf417.cs). Build()/Paint()/Draw() render a
!  stacked matrix (Cells[row,col]) as BOX modules; PDF417 rows are drawn taller.
!
!  This file MUST be stored in ANSI (not UTF-8).
! ============================================================================

PDF:Start          EQUATE(130728)                            ! 17-module start pattern
PDF:Stop           EQUATE(260649)                            ! 18-module stop pattern

Pdf417Class CLASS,TYPE,MODULE('Pdf417Class.CLW'),LINK('Pdf417Class.CLW')
Ready              BYTE
PackTbl            STRING(8400)                              ! packed 17-bit patterns (3 base-75 chars each)
CwTbl              LONG,DIM(3,929)                           ! unpacked [cluster, codeword] -> 17-bit pattern
Cells              BYTE,DIM(90,600)                          ! stacked symbol (1 = dark), [row,col]
NRows              LONG                                      ! barcode rows
NCols              LONG                                      ! module columns (full row width)
CW                 LONG,DIM(1400)                            ! all codewords (data region + EC)
Comp               LONG,DIM(1400)                            ! byte-compaction codewords (pre-sizing)
NCW                LONG
BinB               BYTE,DIM(2200)                            ! input bytes
NBin               LONG
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
Pat                PROCEDURE(LONG cluster,LONG codeword),LONG ! pattern lookup
EmitPat            PROCEDURE(LONG row,LONG x,LONG pattern,LONG bits),LONG
                   END
