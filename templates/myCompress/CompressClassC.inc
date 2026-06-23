!ABCIncludeFile
! ============================================================================
!  CompressClassC - the C-backed fast engine for myCompress.
!
!  A thin subclass of CompressClass (the pure-Clarion codec) that overrides the
!  Wrap/Unwrap engine entry points to call our own C implementation, mc.c,
!  compiled by Clarion's own C compiler (Clacpp). Everything else - the public
!  Compress/Decompress/CompressFile/DecompressFile API, the configuration, the
!  checksums - is inherited unchanged, so the two engines are drop-in
!  interchangeable and produce byte-compatible output.
!
!  Pick the engine in the myCompress extension ("Compression engine"); the
!  template then declares the global object as CompressClass (pure Clarion) or
!  CompressClassC (this one). Use this class only when you want the C fast-path
!  - it is ~4x faster at compression and needs mc.c on the redirection path.
!
!  Single-threaded: mc.c uses file-scope work tables. For concurrent
!  compression use the pure-Clarion CompressClass instead.
!
!  USAGE (handled for you by the myCompress template):
!    Copy CompressClass.inc/.clw + CompressClassC.inc/.clw + mc.c (ANSI, CRLF)
!    to the Clarion redirection path, then declare ONE global instance:
!      Compressor  CompressClassC
!    The API is identical to CompressClass.
!
!  This file MUST be stored in ANSI (not UTF-8).
! ============================================================================

  INCLUDE('CompressClass.INC'),ONCE                          ! the pure-Clarion base class

CompressClassC CLASS(CompressClass),TYPE,MODULE('CompressClassC.CLW'),LINK('CompressClassC.CLW')
Wrap               PROCEDURE(*STRING pIn,LONG pInLen),LONG,DERIVED   ! override -> C compress  (mc_compress)
Unwrap             PROCEDURE(*STRING pIn,LONG pInLen),LONG,DERIVED   ! override -> C inflate   (mc_decompress)
                   END
