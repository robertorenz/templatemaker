!ABCIncludeFile
! ============================================================================
!  CompressClass - self-contained DEFLATE / zlib / gzip codec for Clarion.
!
!  Pure Clarion - no DLL, no external library. Implements RFC 1951 (DEFLATE),
!  RFC 1950 (zlib) and RFC 1952 (gzip) so its output round-trips with gzip,
!  7-Zip, browsers and .NET's GZipStream / DeflateStream, and it can read any
!  stream those tools produce.
!
!    * Decompress (INFLATE): stored + fixed + dynamic Huffman - reads anything.
!    * Compress   (DEFLATE): LZ77 (hash-chain matcher) + fixed Huffman.
!                  Level 0 emits stored blocks; 1..9 tune the match search.
!    * Works on memory buffers AND files; carries CRC32 (gzip) + Adler32 (zlib).
!
!  USAGE (handled for you by the myCompress template - one global instance):
!    1. Put CompressClass.inc + CompressClass.clw on the Clarion redirection
!       path (the app folder, or \clarion12\libsrc\win). They are ANSI.
!    2. INCLUDE('CompressClass.INC'),ONCE   and declare ONE global instance:
!         Zip  CompressClass
!       The LINK attribute pulls CompressClass.CLW into the build automatically.
!    3. Memory (length-explicit; pOut must be at least Zip.MaxCompressed(len)):
!         outLen = Zip.Compress(rawStr, rawLen, outStr)
!         orgLen = Zip.Decompress(outStr, outLen, rawStr)
!       Files:
!         IF Zip.CompressFile('big.txt','big.txt.gz')   ...
!         IF Zip.DecompressFile('big.txt.gz','big.txt') ...
!
!  Binary note: a Clarion STRING is fixed-length and space-padded, so binary
!  data must always travel WITH its length - every method here is
!  length-explicit (a LONG length in, a LONG length returned). Never rely on
!  LEN() or trailing-space trimming for compressed bytes.
!
!  This file MUST be stored in ANSI (not UTF-8).
! ============================================================================

Cmp:Raw            EQUATE(0)                                  ! raw DEFLATE (RFC1951): no header / trailer
Cmp:Zlib           EQUATE(1)                                  ! zlib  (RFC1950): 2-byte header + Adler32 trailer
Cmp:Gzip           EQUATE(2)                                  ! gzip  (RFC1952): 10-byte header + CRC32 + ISIZE

Cmp:WBits          EQUATE(13)                                 ! window = 2^13 = 8192. Clarion caps ONE array at
Cmp:WSize          EQUATE(8192)                               ! 65535 bytes, so a LONG,DIM() must be <=16383;
Cmp:WMask          EQUATE(8191)                               ! 8192 LONGs = 32768 bytes (cf. AztecClass GFExp).
Cmp:MinMatch       EQUATE(3)                                  ! shortest back-reference DEFLATE can encode
Cmp:MaxMatch       EQUATE(258)                                ! longest
Cmp:HashBits       EQUATE(13)
Cmp:HashSize       EQUATE(8192)                               ! 2^HashBits
Cmp:HashMask       EQUATE(8191)

CompressClass CLASS,TYPE,MODULE('CompressClass.CLW'),LINK('CompressClass.CLW')
! ---- public configuration -------------------------------------------------
Level              BYTE                                       ! 0 = stored, 1..9 = compress (effort). Default 6.
Format             BYTE                                       ! Cmp:Raw / Cmp:Zlib / Cmp:Gzip. Default Cmp:Gzip.
ErrCode            LONG                                       ! 0 = ok, <0 = the error from the last call
ErrText            CSTRING(81)                                ! human-readable companion to ErrCode
! ---- one-time tables (built by Init in Construct) -------------------------
Ready              BYTE
CrcTab             ULONG,DIM(256)                             ! CRC32 (gzip) lookup table
LenBase            LONG,DIM(29)                               ! length symbol 257..285 -> base length   (1-based)
LenXtra            LONG,DIM(29)                               !                          -> extra bits
DstBase            LONG,DIM(30)                               ! distance symbol 0..29   -> base distance (1-based)
DstXtra            LONG,DIM(30)                               !                          -> extra bits
FixLitCode         LONG,DIM(288)                              ! fixed-Huffman literal/length codes (MSB-first value)
FixLitLen          LONG,DIM(288)                              !                                    bit-lengths
! ---- output buffer (class-owned, grows as needed) -------------------------
OutBuf             &STRING
OutCap             LONG
OutLen             LONG                                       ! bytes used in OutBuf
BWAcc              ULONG                                      ! DEFLATE bit-writer accumulator (LSB-first packing)
BWN                LONG                                       ! bits currently held in BWAcc
! ---- input bit-reader -----------------------------------------------------
InBuf              &STRING                                    ! bound (not copied) to the caller's input
InLen              LONG
InPos              LONG                                       ! next unread byte, 1-based
BRAcc              ULONG                                      ! INFLATE bit-reader accumulator
BRN                LONG
! ---- LZ77 match finder ----------------------------------------------------
HashHead           LONG,DIM(8192)                             ! Cmp:HashSize - most recent position for a hash
HashPrev           LONG,DIM(8192)                             ! Cmp:WSize     - previous position in the chain
! ---- Huffman decode tables (built per dynamic block) ----------------------
LLCnt              LONG,DIM(16)                               ! lit/len: codes-per-bitlength (index 1..15)
LLSym              LONG,DIM(288)                              !          symbols in canonical order (1-based)
DCnt               LONG,DIM(16)                               ! distance
DSym               LONG,DIM(30)
CLCnt              LONG,DIM(16)                               ! code-length code alphabet (19 symbols)
CLSym              LONG,DIM(19)
CodeLen            LONG,DIM(320)                              ! scratch: decoded code lengths (HLIT+HDIST)
DLen               LONG,DIM(32)                               ! scratch: distance code lengths (contiguous from 1)
CLOrder            LONG,DIM(19)                               ! the RFC1951 code-length code order (built in Init)
! ---- methods : memory (length-explicit) -----------------------------------
Compress           PROCEDURE(*STRING pIn,LONG pInLen,*STRING pOut),LONG   ! -> compressed length, or -1 (see ErrText)
Decompress         PROCEDURE(*STRING pIn,LONG pInLen,*STRING pOut),LONG   ! -> original length,   or -1
MaxCompressed      PROCEDURE(LONG pInLen),LONG                            ! safe size to allocate for pOut
! ---- methods : files ------------------------------------------------------
CompressFile       PROCEDURE(STRING pSrc,STRING pDst),BYTE                ! 1 = ok, 0 = fail (see ErrText)
DecompressFile     PROCEDURE(STRING pSrc,STRING pDst),BYTE
! ---- lifecycle / diagnostics ----------------------------------------------
Construct          PROCEDURE
Destruct           PROCEDURE
SelfTest           PROCEDURE(),BYTE                                       ! round-trips a known string; 1 = pass
! ---- internal : engine ----------------------------------------------------
Init               PROCEDURE                                             ! build CRC + length/distance + fixed tables
Wrap               PROCEDURE(*STRING pIn,LONG pInLen),LONG,VIRTUAL      ! header+deflate+trailer -> OutBuf; ret OutLen or -1
Unwrap             PROCEDURE(*STRING pIn,LONG pInLen),LONG,VIRTUAL      ! detect container + inflate -> OutBuf; ret len or -1
                                                                       !   (VIRTUAL so CompressClassC can swap in the C engine)
Deflate            PROCEDURE(*STRING pSrc,LONG pLen)                     ! raw DEFLATE of pSrc[1..pLen] -> OutBuf
DeflateStored      PROCEDURE(*STRING pSrc,LONG pLen)                     ! stored blocks only (Level 0)
Inflate            PROCEDURE(),BYTE                                      ! raw INFLATE from InBuf -> OutBuf; 1 = ok
BuildFixed         PROCEDURE                                            ! fixed-Huffman lit/len + dist decode tables
ReadDynamic        PROCEDURE(),BYTE                                     ! parse a dynamic-Huffman block header
InflateBlock       PROCEDURE(),BYTE                                     ! decode symbols of the current block to EOB
CRC32              PROCEDURE(*STRING p,LONG pLen),ULONG
Adler32            PROCEDURE(*STRING p,LONG pLen),ULONG
! ---- internal : output / bit writer ---------------------------------------
ResetOut           PROCEDURE
EnsureOut          PROCEDURE(LONG pNeed)
PutByte            PROCEDURE(LONG pVal)                                  ! append one byte to OutBuf
PutBits            PROCEDURE(LONG pVal,LONG pN)                          ! append pN bits, LSB-first
PutHuff            PROCEDURE(LONG pCode,LONG pN)                         ! append an MSB-first Huffman code (bit-reversed)
FlushBits          PROCEDURE                                            ! pad the bit-writer to a byte boundary
RevBits            PROCEDURE(LONG pVal,LONG pN),LONG                     ! reverse the low pN bits of pVal
! ---- internal : bit reader ------------------------------------------------
ByteIn             PROCEDURE(),LONG                                      ! next raw input byte (0 + ErrCode at EOF)
GetBits            PROCEDURE(LONG pN),LONG                               ! read pN bits, LSB-first
AlignByte          PROCEDURE                                            ! drop to the next byte boundary (stored blocks)
NextStoredByte     PROCEDURE(),LONG                                      ! next byte, draining whole bytes from BRAcc
! ---- internal : Huffman ---------------------------------------------------
BuildHuff          PROCEDURE(*LONG[] pLen,LONG pN,*LONG[] pCnt,*LONG[] pSym)
DecodeSym          PROCEDURE(*LONG[] pCnt,*LONG[] pSym),LONG
                   END
