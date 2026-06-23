#TEMPLATE(myPdfSign,'Pure-Clarion signed-PDF reader - see WHO signed a PDF'),FAMILY('ABC')
#!#############################################################################
#!  myPdfSign - read a digitally-signed PDF and report WHO signed it.
#!
#!  Adds ONE global PdfSignClass object to the application; reach it from any
#!  procedure or embed to open a signed PDF and read the signer's identity
#!  straight out of the embedded PKCS#7 / CMS signature:
#!
#!      IF PdfSig.ReadFile('contract.pdf') AND PdfSig.Signed
#!         ! PdfSig.SubjectCN    - who signed (certificate Common Name)
#!         ! PdfSig.SubjectO     - their organization
#!         ! PdfSig.SubjectEmail - their e-mail
#!         ! PdfSig.IssuerCN     - the issuing certificate authority
#!         ! PdfSig.SignTime     - when (ISO-8601 UTC, from the signed attrs)
#!         ! PdfSig.Reason / .Location / .SignerName / .SubFilter
#!         ! PdfSig.CoversWholeFile - 0 = bytes were appended after signing
#!      END
#!
#!  Pure Clarion - no DLL, no external library, no network. It surfaces the
#!  named signer + an integrity hint; it does NOT cryptographically verify the
#!  RSA/ECDSA signature or validate the certificate trust chain.
#!
#!  IMPORTANT: copy PdfSignClass.inc AND PdfSignClass.clw to a folder on the
#!  Clarion redirection path (the app folder, or \clarion12\libsrc\win). They
#!  are ANSI. The class's LINK attribute pulls PdfSignClass.clw into the build.
#!
#!  Only registration needed: ONE global extension. There is no per-window or
#!  per-report wiring - reading is driven entirely from your own code.
#!#############################################################################
#EXTENSION(myPdfSignGlobal,'myPdfSign - Global signed-PDF reader (who signed it)'),APPLICATION
#SHEET
  #TAB('&General')
    #BOXED('Global PDF-signature reader object')
      #PROMPT('&Disable this template',CHECK),%myPdfSignDisable,DEFAULT(0),AT(10)
      #PROMPT('Global &object name:',@s64),%myPdfSignObject,DEFAULT('PdfSig'),REQ
      #DISPLAY('')
      #DISPLAY('The object is GLOBAL data - reach it from any procedure or embed.')
    #ENDBOXED
    #DISPLAY('It reads the signer identity out of a signed PDF (no crypto verify).')
  #ENDTAB
  #TAB('&Instructions')
    #BOXED('How to use myPdfSign')
      #DISPLAY('1. Copy PdfSignClass.inc + PdfSignClass.clw to the Clarion')
      #DISPLAY('   redirection path (app folder, or \clarion12\libsrc\win). ANSI.')
      #DISPLAY('2. Add THIS extension once, at the Application level.')
      #DISPLAY('3. From any embed, use the global object (named above, e.g. PdfSig):')
      #DISPLAY('')
      #DISPLAY('   IF PdfSig.ReadFile(''contract.pdf'')')
      #DISPLAY('     IF PdfSig.Signed')
      #DISPLAY('       MESSAGE(''Signed by '' & CLIP(PdfSig.SubjectCN) &|')
      #DISPLAY('         ''|e-mail : '' & CLIP(PdfSig.SubjectEmail) &|')
      #DISPLAY('         ''|issued by '' & CLIP(PdfSig.IssuerCN) &|')
      #DISPLAY('         ''|signed at '' & CLIP(PdfSig.SignTime) &|')
      #DISPLAY('         ''|intact : '' & CHOOSE(PdfSig.CoversWholeFile=1,''yes'',''NO''))')
      #DISPLAY('     ELSE')
      #DISPLAY('       MESSAGE(''This PDF is not signed.'')')
      #DISPLAY('     END')
      #DISPLAY('   END')
      #DISPLAY('')
      #DISPLAY('   Result fields: SubjectCN/O/OU/Email, IssuerCN, SignTime,')
      #DISPLAY('   SignerName(/Name), Reason, Location, SubFilter, SigCount,')
      #DISPLAY('   CoversWholeFile, Signed, ErrCode, ErrText.')
      #DISPLAY('')
      #DISPLAY('   You can also parse a PDF already in memory:')
      #DISPLAY('     IF PdfSig.Read(buf, bufLen) ...')
      #DISPLAY('')
      #DISPLAY('   Sanity check at startup: IF ~PdfSig.SelfTest() ... (1 = pass)')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#! Pull the class into the program. ONCE keeps it single-included even if some
#! other template (or a second copy of this one) also includes it.
#!-----------------------------------------------------------------------------
#AT(%AfterGlobalIncludes),WHERE(%myPdfSignDisable=0)
INCLUDE('PdfSignClass.INC'),ONCE
#ENDAT
#!
#! The reader instance is GLOBAL DATA, so it must be multi-DLL aware (ABC's
#! %DefaultExternal / %DefaultExport / %ProgramExtension symbols): DEFINED in a
#! single-EXE or the root DLL, declared EXTERNAL (imported) in every other
#! DLL/EXE that uses it, and EXPORTED from the root DLL so those imports
#! resolve. The class methods are non-VIRTUAL and the CLASS carries an
#! unconditional LINK, so each target links its own copy of PdfSignClass.clw -
#! only the shared instance needs exporting. (Same handling as myCompress.)
#AT(%GlobalData),WHERE(%myPdfSignDisable=0)
  #IF(%DefaultExternal = 'None External')
%myPdfSignObject  PdfSignClass                               ! defined here (single-EXE or the root DLL)
  #ELSE
%myPdfSignObject  PdfSignClass,EXTERNAL,DLL(dll_mode)        ! imported from the root DLL
  #ENDIF
#ENDAT
#!
#AT(%DLLExportList),WHERE(%myPdfSignDisable=0)
  #IF(%DefaultExternal = 'None External' AND %ProgramExtension='DLL' AND %DefaultExport)
$%myPdfSignObject  @?                                        ! export the shared instance from the root DLL
  #ENDIF
#ENDAT
