!ABCIncludeFile
! ============================================================================
!  PdfSignClass - read a digitally-signed PDF and report WHO signed it.
!
!  Pure Clarion - no DLL, no external library. Given a signed PDF it surfaces
!  the authoritative signer identity that lives in the embedded PKCS#7 / CMS
!  signature, plus the human-readable signing intent and an integrity hint:
!
!    * SubjectCN / SubjectO / SubjectOU / SubjectEmail
!                                  - the signer certificate's Subject (who).
!    * IssuerCN                    - the certificate authority that issued it.
!    * SignTime                    - the signing time (ISO-8601 UTC) taken from
!                                    the signed attributes, not the spoofable /M.
!    * SignerName / Reason / Location / SubFilter
!                                  - the signature dictionary's own fields.
!    * CoversWholeFile             - 1 when /ByteRange spans the entire file;
!                                    0 means bytes were appended after signing
!                                    (a tamper / incremental-update hint).
!
!  HOW IT WORKS (no crypto math - identity + integrity only):
!    1. Find the signature dictionary: /ByteRange [...] and /Contents <hex>.
!    2. Hex-decode /Contents to the DER PKCS#7 SignedData blob.
!    3. Walk the DER (a tiny tag/length reader) to the signer certificate's
!       tbsCertificate, then read the Subject and Issuer RDNs by OID, and the
!       signingTime from the authenticated attributes.
!    4. Confirm /ByteRange covers the whole file.
!
!  It does NOT cryptographically verify the signature (no RSA/ECDSA hash check);
!  it answers "who is named as the signer, and was anything appended after?".
!
!  USAGE (handled for you by the myPdfSign template - one global instance):
!    1. Put PdfSignClass.inc + PdfSignClass.clw on the Clarion redirection path
!       (the app folder, or \clarion12\libsrc\win). They are ANSI.
!    2. INCLUDE('PdfSignClass.INC'),ONCE  and declare ONE global instance:
!         PdfSig  PdfSignClass
!    3. Read a file (or a memory buffer) then read the result properties:
!         IF PdfSig.ReadFile('contract.pdf')
!            IF PdfSig.Signed
!               MESSAGE('Signed by ' & CLIP(PdfSig.SubjectCN) & |
!                       ' (' & CLIP(PdfSig.SubjectEmail) & ')' & |
!                       '|Issued by ' & CLIP(PdfSig.IssuerCN) & |
!                       '|Signed at ' & CLIP(PdfSig.SignTime) & |
!                       '|Intact: ' & CHOOSE(PdfSig.CoversWholeFile=1,'yes','NO'))
!            END
!         END
!
!  This file MUST be stored in ANSI (not UTF-8).
! ============================================================================

PdfSignClass CLASS,TYPE,MODULE('PdfSignClass.CLW'),LINK('PdfSignClass.CLW')
! ---- results (filled by ReadFile / Read) ----------------------------------
Signed             BYTE                                       ! 1 = a signature was found and parsed
SigCount           LONG                                       ! number of signature dictionaries present
SubjectCN          CSTRING(256)                               ! signer: Common Name
SubjectO           CSTRING(256)                               ! signer: Organization
SubjectOU          CSTRING(256)                               ! signer: Organizational Unit
SubjectEmail       CSTRING(256)                               ! signer: e-mail (emailAddress RDN)
IssuerCN           CSTRING(256)                               ! issuing CA: Common Name
SignTime           CSTRING(32)                                ! signing time, ISO-8601 UTC (from signed attrs)
SignerName         CSTRING(256)                               ! /Name   (self-asserted typed name)
Reason             CSTRING(256)                               ! /Reason
Location           CSTRING(256)                               ! /Location
SubFilter          CSTRING(64)                                ! /SubFilter (e.g. adbe.pkcs7.detached)
CoversWholeFile    BYTE                                       ! 1 = /ByteRange spans the whole file
ErrCode            LONG                                       ! 0 = ok, <0 = the error from the last call
ErrText            CSTRING(128)                               ! human-readable companion to ErrCode
! ---- working buffers (class-owned) ----------------------------------------
Pdf                &STRING                                    ! the PDF bytes (owned when loaded by ReadFile)
PdfLen             LONG
PdfOwned           BYTE                                       ! 1 when SELF allocated Pdf (ReadFile)
Der                &STRING                                    ! decoded PKCS#7 DER blob
DerLen             LONG                                       ! true length of the DER object (trailing pad trimmed)
! ---- public methods -------------------------------------------------------
ReadFile           PROCEDURE(STRING pPath),BYTE               ! load + parse; 1 = parsed (see Signed/ErrText)
Read               PROCEDURE(*STRING pPdf,LONG pLen),BYTE     ! parse a PDF already in memory; 1 = parsed
Report             PROCEDURE(),STRING                         ! key=value identity block (matches PdfSignCore)
SelfTest           PROCEDURE(),BYTE                           ! parse a tiny built-in signed PDF; 1 = pass
! ---- lifecycle ------------------------------------------------------------
Construct          PROCEDURE
Destruct           PROCEDURE
! ---- internal : PDF structure ---------------------------------------------
Reset              PROCEDURE                                  ! clear all result fields
FindContents       PROCEDURE(*STRING pPdf,LONG pLen,*LONG oStart,*LONG oLen),BYTE   ! locate /Contents <hex>
HexToDer           PROCEDURE(*STRING pPdf,LONG hStart,LONG hLen),BYTE               ! decode hex -> SELF.Der
GetParen           PROCEDURE(*STRING pPdf,LONG pLen,STRING pKey,*CSTRING oVal)       ! read "/Key(....)"
GetName            PROCEDURE(*STRING pPdf,LONG pLen,STRING pKey,*CSTRING oVal)       ! read "/Key/value"
ByteRangeCovers    PROCEDURE(*STRING pPdf,LONG pLen),BYTE                            ! 1 = spans whole file
IsHex              PROCEDURE(LONG pB),BYTE
! ---- internal : DER (ASN.1) reader ----------------------------------------
DerHdr             PROCEDURE(LONG p,*LONG oContent,*LONG oLen)  ! parse tag+length at p (1-based)
DerNext            PROCEDURE(LONG p),LONG                       ! position just past the TLV at p
DerInto            PROCEDURE(LONG p),LONG                       ! content start of the (constructed) TLV at p
ParseSigner        PROCEDURE(),BYTE                             ! walk SELF.Der -> Subject / Issuer / SignTime
GetAttr            PROCEDURE(LONG rStart,LONG rEnd,*CSTRING pPat,*CSTRING oVal) ! read an RDN value by OID pattern
GetSignTime        PROCEDURE()                                  ! signingTime signed-attr -> SELF.SignTime
                   END
