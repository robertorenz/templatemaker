#TEMPLATE(myCompress,'Pure-Clarion compression - DEFLATE / zlib / gzip (memory + files)'),FAMILY('ABC')
#!#############################################################################
#!  myCompress - a self-contained compression library for Clarion.
#!
#!  Adds ONE global CompressClass object to the application; reach it from any
#!  procedure or embed to compress / decompress memory buffers and files in the
#!  standard DEFLATE / zlib / gzip formats (interoperates with gzip, 7-Zip,
#!  browsers, .NET GZipStream). Pure Clarion - no DLL, no external library.
#!
#!  IMPORTANT: copy CompressClass.inc AND CompressClass.clw to a folder on the
#!  Clarion redirection path (the app folder, or \clarion12\libsrc\win). They
#!  are ANSI. The class's LINK attribute pulls CompressClass.clw into the build.
#!
#!  Only registration needed: ONE global extension. There is no per-window or
#!  per-report wiring - compression is driven entirely from your own code, e.g.
#!      n = Zip.Compress(rawStr, rawLen, packedStr)      ! memory
#!      IF Zip.CompressFile('a.txt','a.txt.gz')          ! files
#!#############################################################################
#EXTENSION(myCompressGlobal,'myCompress - Global Compressor (DEFLATE / zlib / gzip)'),APPLICATION
#SHEET
  #TAB('&General')
    #BOXED('Global compressor object')
      #PROMPT('&Disable this template',CHECK),%myCompressDisable,DEFAULT(0),AT(10)
      #PROMPT('Global &object name:',@s64),%myCompressObject,DEFAULT('Compressor'),REQ
      #DISPLAY('(Pick a name that is NOT a file field — e.g. avoid Zip, which clashes')
      #DISPLAY(' with a Zip column. A clash shows as "Illegal data type: COMPRESSCLASS".)')
      #DISPLAY('')
      #PROMPT('Default &format:',DROP('gzip (.gz)[2]|zlib[1]|raw DEFLATE[0]')),%myCompressFormat,DEFAULT('2')
      #PROMPT('Default &level (0 = store, 1 = fast .. 9 = best):',SPIN(@n1,0,9,1)),%myCompressLevel,DEFAULT(6)
      #DISPLAY('')
      #PROMPT('Compression &engine:',DROP('Pure Clarion - no extra files (default)[0]|C fast-path - ~4x faster compress, needs mc.c[1]')),%myCompressEngine,DEFAULT('0')
    #ENDBOXED
    #DISPLAY('The object is GLOBAL data - reach it from any procedure or embed.')
    #DISPLAY('Format and Level are just defaults; change them in code anytime.')
    #DISPLAY('Engine = C fast-path also needs CompressClassC.inc/.clw + mc.c on')
    #DISPLAY('the redirection path; the API is identical either way.')
  #ENDTAB
  #TAB('&Instructions')
    #BOXED('How to use myCompress')
      #DISPLAY('1. Copy CompressClass.inc + CompressClass.clw to the Clarion')
      #DISPLAY('   redirection path (app folder, or \clarion12\libsrc\win). ANSI.')
      #DISPLAY('2. Add THIS extension once, at the Application level.')
      #DISPLAY('3. From any embed, use the global object (named above, e.g. Zip):')
      #DISPLAY('')
      #DISPLAY('   Memory (always pass the length - a STRING is space-padded):')
      #DISPLAY('     packed  &STRING')
      #DISPLAY('     n       LONG')
      #DISPLAY('     packed &= NEW STRING(Zip.MaxCompressed(rawLen))')
      #DISPLAY('     n = Zip.Compress(raw, rawLen, packed)      ! n = packed bytes')
      #DISPLAY('     orig = Zip.Decompress(packed, n, raw)      ! back to raw')
      #DISPLAY('')
      #DISPLAY('   Files:')
      #DISPLAY('     IF Zip.CompressFile(''report.txt'',''report.txt.gz'')')
      #DISPLAY('     IF Zip.DecompressFile(''report.txt.gz'',''report.txt'')')
      #DISPLAY('')
      #DISPLAY('   Tune: Zip.Level = 0..9   Zip.Format = 0 raw / 1 zlib / 2 gzip')
      #DISPLAY('   On any failure a method returns -1 / 0 and sets Zip.ErrText.')
      #DISPLAY('')
      #DISPLAY('   Sanity check at startup: IF ~Zip.SelfTest() ... (1 = pass)')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#! Pull the class into the program. ONCE keeps it single-included even if some
#! other template (or a second copy of this one) also includes it.
#!-----------------------------------------------------------------------------
#AT(%AfterGlobalIncludes),WHERE(%myCompressDisable=0)
#IF(%myCompressEngine = 1)
INCLUDE('CompressClassC.INC'),ONCE                          ! C fast-path (also pulls in the base)
#ELSE
INCLUDE('CompressClass.INC'),ONCE                           ! pure Clarion
#ENDIF
#ENDAT
#!
#! The compressor instance is GLOBAL DATA, so it must be multi-DLL aware (ABC's
#! %DefaultExternal / %DefaultExport / %ProgramExtension symbols): DEFINED in a
#! single-EXE or the root DLL, declared EXTERNAL (imported) in every other
#! DLL/EXE that uses it, and EXPORTED from the root DLL so those imports
#! resolve. The CLASS carries an unconditional LINK, so each target links its
#! own copy of the .clw - only the shared instance needs exporting. (Same
#! handling as myQRDraw.) The engine prompt picks CompressClass (pure Clarion)
#! or CompressClassC (the C fast-path subclass).
#AT(%GlobalData),WHERE(%myCompressDisable=0)
  #IF(%DefaultExternal = 'None External')
    #IF(%myCompressEngine = 1)
%myCompressObject  CompressClassC                            ! C fast-path (single-EXE or the root DLL)
    #ELSE
%myCompressObject  CompressClass                             ! pure Clarion (single-EXE or the root DLL)
    #ENDIF
  #ELSE
    #IF(%myCompressEngine = 1)
%myCompressObject  CompressClassC,EXTERNAL,DLL(dll_mode)     ! imported from the root DLL
    #ELSE
%myCompressObject  CompressClass,EXTERNAL,DLL(dll_mode)      ! imported from the root DLL
    #ENDIF
  #ENDIF
#ENDAT
#!
#AT(%DLLExportList),WHERE(%myCompressDisable=0)
  #IF(%DefaultExternal = 'None External' AND %ProgramExtension='DLL' AND %DefaultExport)
$%myCompressObject  @?                                       ! export the shared instance from the root DLL
  #ENDIF
#ENDAT
#!
#! Apply the configured defaults once, at startup, where the object is defined
#! (Construct already sets gzip / level 6; this just honours the prompts).
#AT(%ProgramSetup),WHERE(%myCompressDisable=0)
  #IF(%DefaultExternal = 'None External')
%myCompressObject.Format = %myCompressFormat                 ! 0 raw / 1 zlib / 2 gzip
%myCompressObject.Level  = %myCompressLevel                  ! 0 store .. 9 best
  #ENDIF
#ENDAT
#!-----------------------------------------------------------------------------
#! End of myCompress template
#!-----------------------------------------------------------------------------
