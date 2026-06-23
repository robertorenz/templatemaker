! ============================================================================
!  CompressClassC - implementation (the C-backed fast engine).
!
!  Overrides Wrap (compress) and Unwrap (decompress) to call our own C engine
!  mc.c, compiled in by PRAGMA('compile(mc.c)'). Everything else is inherited
!  from CompressClass, so the inherited Compress/Decompress/CompressFile/
!  DecompressFile - which call SELF.Wrap/SELF.Unwrap (VIRTUAL) - automatically
!  route through C. mc_compress/mc_decompress are bounds-checked (return -1 on
!  output overflow), so we size the buffer and grow + retry on decompress.
!
!  This file MUST be stored in ANSI (not UTF-8).
! ============================================================================
  MEMBER

  INCLUDE('CompressClassC.INC'),ONCE        ! must precede the PRAGMA / mc.c prototypes

  PRAGMA('compile(mc.c)')                   ! Clarion's own C compiler builds our C engine

  MAP                                       ! module-level MAP (folds BUILTINS.CLW + hosts mc.c)
    MODULE('mc.c')
mc_compress        PROCEDURE(*STRING,LONG,*STRING,LONG,LONG,LONG),LONG,RAW,NAME('_mc_compress')
mc_decompress      PROCEDURE(*STRING,LONG,*STRING,LONG),LONG,RAW,NAME('_mc_decompress')
    END
  END

!=== compress (override) =====================================================
CompressClassC.Wrap PROCEDURE(*STRING pIn,LONG pInLen)
  CODE
  IF NOT SELF.Ready THEN SELF.Init().
  SELF.ErrCode = 0; SELF.ErrText = ''
  SELF.ResetOut()
  SELF.EnsureOut(SELF.MaxCompressed(pInLen))               ! pre-size: the C engine writes OutBuf directly
  SELF.OutLen = mc_compress(SELF.OutBuf, SELF.OutCap, pIn, pInLen, SELF.Level, SELF.Format)
  IF SELF.OutLen < 0
    SELF.ErrCode = -30; SELF.ErrText = 'C engine: compress overflow'; RETURN -1
  END
  RETURN SELF.OutLen

!=== decompress (override) ===================================================
CompressClassC.Unwrap PROCEDURE(*STRING pIn,LONG pInLen)
cap LONG
n   LONG
  CODE
  IF NOT SELF.Ready THEN SELF.Init().
  SELF.ErrCode = 0; SELF.ErrText = ''
  SELF.ResetOut()
  IF pInLen >= 18 AND VAL(pIn[1]) = 01Fh AND VAL(pIn[2]) = 08Bh    ! gzip ISIZE = exact original size
    cap = VAL(pIn[pInLen-3]) + BSHIFT(VAL(pIn[pInLen-2]),8) + BSHIFT(VAL(pIn[pInLen-1]),16) + BSHIFT(VAL(pIn[pInLen]),24)
    IF cap < 1 THEN cap = pInLen * 8 + 65536.
  ELSE
    cap = pInLen * 8 + 65536                               ! zlib/raw: estimate, grow if needed
  END
  LOOP
    SELF.EnsureOut(cap)
    n = mc_decompress(SELF.OutBuf, SELF.OutCap, pIn, pInLen)
    IF n >= 0 THEN BREAK.
    IF cap > 200000000
      SELF.ErrCode = -31; SELF.ErrText = 'C engine: decompress failed'; RETURN -1
    END
    cap = cap * 2
  END
  SELF.OutLen = n
  RETURN SELF.OutLen
