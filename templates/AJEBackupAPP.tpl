#! *****************************************************************************************************
#!
#!            Made by ALEJANDRO J. ELIAS 
#!
#! *****************************************************************************************************
#Template(AJEBackupAPP,'Automatically Generate a Backup APP After Compile Legacy/ABC/IPServer/NT v6.0a '),FAMILY('CW20'),FAMILY('ABC'),Family('IPServer')
 #SYSTEM
 
#!=====================================================================================================
#EXTENSION(AJE_BACKUP,'AJE: Automatically Generate a Backup APP After Compile Legacy/ABC/IPServer/NT v6.0a  - Global Extension'),Application(AJEExtBackupAPP(AJEBackupAPP))
#DISPLAY('  Automatic Backup APP         v6.0a'),AT(3,1,320,16),PROP(PROP:FontColor,0794E1FH),PROP(PROP:FontSize,15),PROP(PROP:Font,'Segoe UI'),PROP(PROP:FontStyle,700)
#PREPARE
#CALL(%AJEReadVersion)
#ENDPREPARE
#SHEET,HSCROLL
#!===========================================================================
 #TAB('About')
   #DISPLAY('')
   #IMAGE('AJEico_about.png'),AT(,,24,24)
   #DISPLAY('Welcome'),PROP(PROP:FontColor,0794E1FH),PROP(PROP:FontStyle,700),PROP(PROP:FontSize,12),PROP(PROP:Font,'Segoe UI')
   #DISPLAY('Automatic, versioned backups every time you compile.'),PROP(PROP:FontColor,06E6E6EH),PROP(PROP:FontSize,8),PROP(PROP:Font,'Segoe UI')
   #DISPLAY('')
   #BOXED('Automatic Backup for Clarion'),SECTION
   #IMAGE('Box Automatic Backup APP.png'),AT(9,0)
   #DISPLAY('    Automatic Backup for Clarion'),AT(65,28),PROP(PROP:FontColor,0794E1FH),PROP(PROP:FontStyle,700),PROP(PROP:FontSize,11),PROP(PROP:Font,'Segoe UI')
   #DISPLAY('    Version 6.0a'),AT(65,43),PROP(PROP:FontStyle,700),PROP(PROP:Font,'Segoe UI')
   #DISPLAY('    Copyright 2022'),AT(65,54),PROP(PROP:FontColor,0808080H),PROP(PROP:Font,'Segoe UI')
   #DISPLAY('    www.DeveloperTeam.com.ar'),AT(65,64),PROP(PROP:FontColor,0808080H),PROP(PROP:Font,'Segoe UI')
   #DISPLAY(''),AT(65,76)
   #ENDBOXED
   #DISPLAY('Tip: open the Instructions tab to get started.'),PROP(PROP:FontColor,0808080H),PROP(PROP:Font,'Segoe UI'),PROP(PROP:FontSize,8)
   #ENDTAB
  #TAB('Configuration')
    #DISPLAY('')
    #IMAGE('AJEico_config.png'),AT(,,24,24)
    #DISPLAY('Configuration'),PROP(PROP:FontColor,0794E1FH),PROP(PROP:FontStyle,700),PROP(PROP:FontSize,12),PROP(PROP:Font,'Segoe UI')
    #DISPLAY('Choose where and what to back up after each compile.'),PROP(PROP:FontColor,06E6E6EH),PROP(PROP:FontSize,8),PROP(PROP:Font,'Segoe UI')
    #DISPLAY('')
    #BOXED('Activation'),SECTION
      #PROMPT('Enable Backup APP',CHECK),%AJEActivaBA,AT(10),DEFAULT(%TRUE)
      #ENABLE(%AJEActivaBA)
        #PROMPT('General Path Backup',OPENDIALOG('Pick the General PATH','All the files|*.*')),%AJEGeneralPathBackup,DEFAULT('C:\AUBackupApp'),REQ
        #PROMPT('Application Path Files',OPENDIALOG('Pick the PATH For APP & DCT Files...','All the files|*.*')),%AJEPathFiles,DEFAULT(LONGPATH()),PROP(PROP:READONLY,1)
        #DISPLAY('Example - C:\Softwares\Folder Application'),PROP(PROP:FontColor,0808080H),PROP(PROP:FontSize,8),PROP(PROP:Font,'Segoe UI')
        #DISPLAY('')
        #BUTTON('Path For Backups: ' & %AJEPathBackups),MULTI(%AJEPathBackups,FORMAT(%AJEPathBackupsName,@S255)),INLINE
            #BOXED('Path For Backups'),SECTION
                #PROMPT('File Name:',OPENDIALOG('Pick the PATH to Backup...','All the files|*.*')),%AJEPathBackupsName,DEFAULT(LONGPATH()),REQ
                #PROMPT('App Folder:',@s255),%AJEPathBackupsAppFolder,DEFAULT('APP'),REQ
                #PROMPT('Dct Folder:',@s255),%AJEPathBackupsDctFolder,DEFAULT('DCT'),REQ
                #PROMPT('Dctx Folder:',@s255),%AJEPathBackupsDctxFolder,DEFAULT('DCTX'),REQ
                #PROMPT('Txa Folder:',@s255),%AJEPathBackupsTxaFolder,DEFAULT('TXA'),REQ
                #PROMPT('Delete older than ('&%AJEDeleteBeforeDays&') days ',CHECK),%AJELocalDeleteBeforeDays,AT(10),DEFAULT(%TRUE)
                #DISPLAY('Example - C:\DROPBOX\Softwares\Folder Application'),PROP(PROP:FontColor,0808080H),PROP(PROP:FontSize,8),PROP(PROP:Font,'Segoe UI')
            #ENDBOXED
        #DISPLAY
        #ENDBUTTON
        #BOXED('Exports')
            #DISPLAY('What to include in each backup:'),PROP(PROP:FontColor,0327D2EH),PROP(PROP:FontStyle,700),PROP(PROP:FontSize,8),PROP(PROP:Font,'Segoe UI')
            #PROMPT('Export Txa'     ,CHECK),%AJEActivaExportTXA,AT(10),DEFAULT(%TRUE)
            #PROMPT('Export Dctx'    ,CHECK),%AJEActivaExportDCTX,AT(10),DEFAULT(%TRUE)
            #PROMPT('Copy Dct'       ,CHECK),%AJEActivaCopyDct,AT(10),DEFAULT(%TRUE)
            #PROMPT('Zip Files'      ,CHECK),%AJEActivaZipFiles,AT(10),DEFAULT(%FALSE)
            #PROMPT('Include PC Name',CHECK),%AJEIncludePCName,AT(10),DEFAULT(%FALSE)
            #PROMPT('Delete older than (#) days',SPIN(@n2,0,10)),%AJEDeleteBeforeDays,DEFAULT(5)
            #DISPLAY('Note: It always keeps the last ten versions, regardless of the days above.'),PROP(PROP:FontColor,00078C8H),PROP(PROP:FontStyle,700),PROP(PROP:FontSize,8),PROP(PROP:Font,'Segoe UI')
        #ENDBOXED
        #BOXED('Google Analytics')
            #PROMPT('Tracking Code:',@S100),%AJETrackingCodeGA
            #PROMPT('Enable Tracking',CHECK),%AJEActiveTrackingGA,DEFAULT(%TRUE)
        #ENDBOXED
        #ENDENABLE
        #DISPLAY('')
        #ENDBOXED
        #DISPLAY('From Alejandro J. Elias    -    www.DeveloperTeam.com.ar'),PROP(PROP:FontColor,0808080H),PROP(PROP:Font,'Segoe UI'),PROP(PROP:FontSize,8)
        #ENDTAB
  #TAB('Other Files')
    #DISPLAY('')
    #IMAGE('AJEico_files.png'),AT(,,24,24)
    #DISPLAY('Other Files'),PROP(PROP:FontColor,0794E1FH),PROP(PROP:FontStyle,700),PROP(PROP:FontSize,12),PROP(PROP:Font,'Segoe UI')
    #DISPLAY('Extra files to include in every backup (icons, configs, ...).'),PROP(PROP:FontColor,06E6E6EH),PROP(PROP:FontSize,8),PROP(PROP:Font,'Segoe UI')
    #DISPLAY('')
    #BOXED('Extra Files to Back Up'),SECTION
      #ENABLE(%AJEActivaBA)
        #BUTTON('Others Files: ' & %AJEOtherFilesName),MULTI(%AJEOtherFiles,%AJEOtherFiles&'<9>'&%AJEPathBackupsFolder&'<9>'&%AJEOtherFilesName),INLINE,PROP(PROP:Hscroll),PROP(PROP:Format,'10L(1)|M~Order~30L(1)|M~Folder~200L(1)|M~FileName~')
            #BOXED('File')
                #PROMPT('File Name:',OPENDIALOG('Pick the PATH to Backup...','All the files|*.*')),%AJEOtherFilesName
                #PROMPT('Folder:',@s255),%AJEPathBackupsFolder,DEFAULT('Other'),REQ
                #DISPLAY('Use *. or ?. to match multiple files - e.g. *.ico'),PROP(PROP:FontColor,0808080H),PROP(PROP:FontSize,8),PROP(PROP:Font,'Segoe UI')
            #ENDBOXED
        #DISPLAY
        #ENDBUTTON
        #PROMPT('Product Build Number: ',@n4),%AJEVersion,PROP(PROP:READONLY,1)
        #DISPLAY()
      #ENDENABLE
    #ENDBOXED
    #DISPLAY('From Alejandro J. Elias    -    www.DeveloperTeam.com.ar'),PROP(PROP:FontColor,0808080H),PROP(PROP:Font,'Segoe UI'),PROP(PROP:FontSize,8)
  #ENDTAB
  #TAB('Settings')
    #DISPLAY('')
    #IMAGE('AJEico_settings.png'),AT(,,24,24)
    #DISPLAY('Settings'),PROP(PROP:FontColor,0794E1FH),PROP(PROP:FontStyle,700),PROP(PROP:FontSize,12),PROP(PROP:Font,'Segoe UI')
    #DISPLAY('History window, database type and an optional REST API.'),PROP(PROP:FontColor,06E6E6EH),PROP(PROP:FontSize,8),PROP(PROP:Font,'Segoe UI')
    #DISPLAY('')
    #BOXED('General'),SECTION
      #PROMPT('Show History Window',CHECK),%AJEHistoryWindow,DEFAULT(%TRUE)
      #PROMPT('DataBase Type:',OPTION),%AJEDataBaseType
      #PROMPT('TopSpeed',RADIO)
      #PROMPT('ODBC',RADIO)
      #ENABLE(%AJEDataBaseType='ODBC')
        #PROMPT('ODBC String Connection ',EXPR),%AJEODBCStringConnection
      #ENDENABLE
    #ENDBOXED
    #BOXED('Send to a REST API')
      #PROMPT('API URL: ',EXPR),%AJEAPIUrl
    #ENDBOXED
    #DISPLAY('From Alejandro J. Elias    -    www.DeveloperTeam.com.ar'),PROP(PROP:FontColor,0808080H),PROP(PROP:Font,'Segoe UI'),PROP(PROP:FontSize,8)
  #ENDTAB
  #TAB('License')
    #DISPLAY('')
    #IMAGE('AJEico_license.png'),AT(,,24,24)
    #DISPLAY('License'),PROP(PROP:FontColor,0794E1FH),PROP(PROP:FontStyle,700),PROP(PROP:FontSize,12),PROP(PROP:Font,'Segoe UI')
    #DISPLAY('Enter your registration details.'),PROP(PROP:FontColor,06E6E6EH),PROP(PROP:FontSize,8),PROP(PROP:Font,'Segoe UI')
    #DISPLAY('')
    #BOXED('License'),SECTION
      #PROMPT('User Name:',EXPR),%AJEUserName
      #PROMPT('Serial Number:',EXPR),%AJESerialNumber
    #ENDBOXED
    #DISPLAY('From Alejandro J. Elias    -    www.DeveloperTeam.com.ar'),PROP(PROP:FontColor,0808080H),PROP(PROP:Font,'Segoe UI'),PROP(PROP:FontSize,8)
  #ENDTAB
  #TAB('Instructions')
    #DISPLAY('')
    #IMAGE('AJEico_help.png'),AT(,,24,24)
    #BOXED('How to use Automatic Backup APP'),SECTION
      #DISPLAY('What it does'),PROP(PROP:FontColor,0794E1FH),PROP(PROP:FontStyle,700),PROP(PROP:Font,'Segoe UI')
      #DISPLAY('After each successful compile it makes a versioned backup of your')
      #DISPLAY('APP, DCT, DCTX and TXA (plus any extra files) into your backup folders.')
      #DISPLAY('')
      #DISPLAY('Setup'),PROP(PROP:FontColor,0808000H),PROP(PROP:FontStyle,700),PROP(PROP:Font,'Segoe UI')
      #DISPLAY('1. Add this Global Extension to the application (once).')
      #DISPLAY('2. Configuration tab: tick Enable Backup APP, set the General Path,')
      #DISPLAY('   and add one or more destinations under Path For Backups.')
      #DISPLAY('3. Choose what to export: Txa, Dctx, Copy Dct, Zip, Include PC Name.')
      #DISPLAY('4. Other Files tab: add any extra files to back up (e.g. *.ico).')
      #DISPLAY('5. Settings tab: history window, database type, optional REST API URL.')
      #DISPLAY('6. License tab: enter your User Name and Serial Number.')
      #DISPLAY('')
      #DISPLAY('Notes'),PROP(PROP:FontColor,00078C8H),PROP(PROP:FontStyle,700),PROP(PROP:Font,'Segoe UI')
      #DISPLAY('- The build number increases automatically on every compile.')
      #DISPLAY('- It always keeps the last ten versions, regardless of the days setting.')
      #DISPLAY('- The backup runs after the application is generated and compiled.')
    #ENDBOXED
    #DISPLAY('From Alejandro J. Elias    -    www.DeveloperTeam.com.ar'),PROP(PROP:FontColor,0808080H),PROP(PROP:Font,'Segoe UI'),PROP(PROP:FontSize,8)
  #ENDTAB
#ENDSHEET
#!
#!===========================================================================
#ATSTART
#ENDAT
#AT(%AfterGeneratedApplication),WHERE(%AJEActivaBA = %TRUE)
  #SET(%AJEPathFiles,LONGPATH())
  #INSERT(%AJEMakeBackup)
#ENDAT
#!===========================================================================
#EXTENSION(AJEVersionControl,'AJE: Version Control - Local Extension'),PROCEDURE
#!===========================================================================
#ENABLE(%AJEActivaBA = %FALSE)
  #SHEET
    #TAB('Version Control (Local)')
      #PROMPT('Do not generate code for this procedure',CHECK),%AJEDesactivarLocal,AT(20),DEFAULT(%FALSE)
    #ENDTAB
  #ENDSHEET
#ENDENABLE

#AT(%DataSection),PRIORITY(2800)
!Include by AJEBackupAPP
AJEVersionEQ    EQUATE(%AJEVersion+1)
!End of Include
#ENDAT
#!===========================================================================
#GROUP(%AJEReadVersion)
#!#DECLARE(%AJEVersion)
#DECLARE(%AJENewVersion)
#DECLARE(%AJEFileINI)
#SET(%AJEFileINI, LONGPATH()&'\'&%Application&'.res')

    #IF (GETINI('Version','Build',0,%AJEFileINI) <> 0)
        #SET(%AJEVersion,GETINI('Version','Build','',%AJEFileINI))
        #SET(%AJEVersion,%AJEVersion)
    #ELSE
        #CREATE(%AJEFileINI)
[Version]
Build= 1
Create=1
        #CLOSE(%AJEFileINI)
   #ENDIF
#!===========================================================================   
#GROUP(%AJEPutVersion)
#DECLARE(%AJENewVersion)
#DECLARE(%AJEFileINI)

#SET(%AJEFileINI, LONGPATH()&'\'&%Application&'.Res')

    #IF (GETINI('Version','Build',0,%AJEFileINI) <> 0)
        #SET(%AJEVersion,GETINI('Version','Build','',%AJEFileINI))
        #SET(%AJENewVersion,(%AJEVersion+1))
        #SET(%AJEVersion,PUTINI('Version','Build',(%AJENewVersion),%AJEFileINI))
        #SET(%AJEVersion,%AJENewVersion)
    #ELSE
        #CREATE(%AJEFileINI)
[Version]
Build= 1
Create=1
        #CLOSE(%AJEFileINI)
   #ENDIF
#!===========================================================================
#GROUP(%AJEMakeBackup)

#DECLARE(%AJEFileAPP)
#DECLARE(%AJEFileDCT)
#DECLARE(%AJEFileDestAPP)
#DECLARE(%AJEFILEBAT)
#DECLARE(%AJENewDictionaryFile)
#DECLARE(%AJETempDictionaryFile)
#DECLARE(%AJETempFile)
#DECLARE(%AJENFileDCT)
#DECLARE(%AJEFileName)
#DECLARE(%DctCmdString)
#DECLARE(%TemplateRoot)
#DECLARE(%TemplateRootINI)
#DECLARE(%RUNDLL) 
#DECLARE(%FTPDLL) 
#DECLARE(%ClarionCL)
#DECLARE(%AJEVersionProduct)
#DECLARE(%AJEExist)
#DECLARE(%AJEDataTypeMixed)

#!#DECLARE(%AJEPathBackups),MULTI
#!#DECLARE(%AJEPathBackupsName, %AJEPathBackups)
         
#MESSAGE('Generating Module:' & %Application & '.APP', 1) #! Post generation message
#MESSAGE('Generating Backup', 2) #! Post generation message
 
#CALL(%AJEPutVersion)

#SET(%AJEVersionProduct ,'100')
#SET(%AJEFileAPP        ,(%Application &'.APP'))
#SET(%AJEFileDestAPP    ,(%Application &%AJEVersion&'.APP'))
#SET(%AJEFileDCT        ,%DictionaryFile)

#SET(%RUNDLL            ,'AJEBackupAPP.EXE')
#SET(%TemplateRoot      ,%CWRoot &'Accessory\template\win\AJEBackupAPP.EXE')
#SET(%TemplateRootINI   ,%CWRoot &'Accessory\template\win\')
#SET(%ClarionCL         ,%CWRoot &'bin')

#MESSAGE(%TemplateRoot,0)  

#SET(%AJETempFile           ,'VarTemp.TXT')
#SET(%AJENewDictionaryFile  ,CLIP(SUB(%DictionaryFile, 1, LEN(%DictionaryFile) - 4)&%AJEVersion))
#SET(%AJETempDictionaryFile ,CLIP(SUB(%DictionaryFile,1,LEN(%DictionaryFile) - 4)&'.tmp'))
#SET(%AJENFileDCT           ,CLIP(SUB(%AJENewDictionaryFile,INSTRING('\',%AJENewDictionaryFile,-1,LEN(%AJENewDictionaryFile))+1,LEN(%AJENewDictionaryFile))))
#!
#IF(%AJEUserName='')
  #IF(FILEEXISTS(%TemplateRootINI&'AJEBackupAPP.INI'))
     #SET(%AJEUserName      ,GETINI('CREDENTIALS','USERNAME','',%TemplateRootINI&'AJEBackupAPP.INI'))
     #SET(%AJESerialNumber  ,GETINI('CREDENTIALS','SERIALNUMBER','',%TemplateRootINI&'AJEBackupAPP.INI'))
  #ENDIF
#ELSE  

#ENDIF
#IF(%AJETrackingCodeGA='')
  #IF(FILEEXISTS(%TemplateRootINI&'AJEBackupAPP.INI'))
     #SET(%AJETrackingCodeGA,GETINI('CREDENTIALS','TRACKINGGACODE','',%TemplateRootINI&'AJEBackupAPP.INI'))
  #ENDIF
#ENDIF
#IF(FILEEXISTS('.\AJEBackupAPP.INI'))
    #SET(%AJEPathFiles          ,GETINI('BACKUPAPP','PathFiles'         ,%AJEPathFiles,'.\AJEBackupAPP.INI'))
    #SET(%AJEGeneralPathBackup  ,GETINI('BACKUPAPP','GeneralPathBackup' ,%AJEGeneralPathBackup,'.\AJEBackupAPP.INI'))
    #SET(%AJEActivaExportTXA    ,GETINI('BACKUPAPP','ActivaExportTXA'   ,%AJEActivaExportTXA,'.\AJEBackupAPP.INI'))
    #SET(%AJEActivaExportDCTX   ,GETINI('BACKUPAPP','ActivaExportDCTX'  ,%AJEActivaExportDCTX,'.\AJEBackupAPP.INI'))
    #SET(%AJEActivaCopyDct      ,GETINI('BACKUPAPP','ActivaCopyDct'     ,%AJEActivaCopyDct,'.\AJEBackupAPP.INI'))
    #SET(%AJEActivaZipFiles     ,GETINI('BACKUPAPP','ActivaZipFiles'    ,%AJEActivaZipFiles,'.\AJEBackupAPP.INI'))
    #SET(%AJEHistoryWindow      ,GETINI('BACKUPAPP','HistoryWindow'     ,%AJEHistoryWindow,'.\AJEBackupAPP.INI'))
    #SET(%AJEDataBaseType       ,GETINI('BACKUPAPP','DataBaseType'      ,%AJEDataBaseType,'.\AJEBackupAPP.INI'))
    #SET(%AJEIncludePCName      ,GETINI('BACKUPAPP','ActivaPCName'      ,%AJEIncludePCName,'.\AJEBackupAPP.INI'))
    #SET(%AJEODBCStringConnection   ,GETINI('BACKUPAPP','ODBCStringConnection'     ,%AJEODBCStringConnection,'.\AJEBackupAPP.INI'))
    #SET(%AJEAPIUrl             ,GETINI('BACKUPAPP','AJEAPIURL'         ,%AJEAPIUrl,'.\AJEBackupAPP.INI'))
    #IF(GETINI('BACKUPAPP','PathBackupsName','','.\AJEBackupAPP.INI')<>'')
        #FOR(%AJEPathBackups)
            #IF(%AJEPathBackupsName=GETINI('BACKUPAPP','PathBackupsName','','.\AJEBackupAPP.INI'))
                #SET(%AJEExist,1)
            #ELSE
                #SET(%AJEExist,0)
            #ENDIF
        #ENDFOR
        
        #IF(%AJEExist=0)
            #ADD(%AJEPathBackups,ITEMS(%AJEPathBackups)+1)
            #SET(%AJEPathBackupsName        ,GETINI('BACKUPAPP','PathBackupsName','','.\AJEBackupAPP.INI'))
            #SET(%AJEPathBackupsAppFolder   ,'APP')
            #SET(%AJEPathBackupsDctFolder   ,'DCT')
            #SET(%AJEPathBackupsDctxFolder  ,'DCTX')
            #SET(%AJEPathBackupsTxaFolder   ,'TXA')
        #ENDIF
    #ENDIF    
    #SET(%AJEHistoryWindow      ,GETINI('BACKUPAPP','HistoryWindow'     ,%AJEHistoryWindow,'.\AJEBackupAPP.INI'))
#ENDIF
#!

#IF(%AJEAPIUrl<>'')
   #SET(%AJEDataTypeMixed       ,%AJEDataBaseType & '+' & 'API' & '+' & %AJEAPIUrl)   
#ELSE
   #SET(%AJEDataTypeMixed       ,%AJEDataBaseType)
#ENDIF   
#RUN(%TemplateRoot&' Proc=INIT Parameters="'&%AJEUserName&'|'&%AJESerialNumber&'|'&%AJEVersionProduct&'|'&%AJEGeneralPathBackup&'|'&%Application&'|'&%AJEVersion&'|'&%AJETrackingCodeGA&'|'&%AJEActiveTrackingGA&'|'&%AJEHistoryWindow&'|'&%AJEDataTypeMixed&'|'&%AJEODBCStringConnection&'|'&%AJEDeleteBeforeDays&'|'&%DictionaryFile&'|'&%AJEIncludePCName&'"')
#!
#IF(%AJEActivaExportDCTX=%TRUE)
  #RUN(%TemplateRoot&' Proc=CE Parameters="'&%DictionaryFile& ',' &%AJETempDictionaryFile&','&%AJEVersion&','&%Application&','&%AJEActivaZipFiles&'"')
#ENDIF
#!
#CALL(%AddPathBackup)

#GROUP(%AJEPutINILicense)
#DECLARE(%AJEFileINI)
#DECLARE(%AJEPathSettingsINI)
#SET(%AJEFileINI,LONGPATH()&'\AJEBackupAPP.INI')
PUTINI('CREDENTIALS','USERNAME','%AJEUserName','%AJEFileINI')
PUTINI('CREDENTIALS','SERIALNUMBER','%AJESerialNumber','%AJEFileINI')
#!        
#GROUP(%AddPathBackup)  
#DECLARE(%AJEOldPath)
#DECLARE(%AJEPCName)
#DECLARE(%AJEFullPath)
#DECLARE(%AJETXAFile)
#DECLARE(%AJEDCTXFile)

#SET(%AJEOldPath,LONGPATH())
#SET(%AJEPCName,'PCName')

  #FOR(%AJEPathBackups)        
        SETPATH(%TemplateRootINI)
            #IF(%AJEIncludePCName=%TRUE)
        #SET(%AJEFullPath,%AJEPathBackupsName&'\'&%AJEPCName)
            #ELSE
        #SET(%AJEFullPath,%AJEPathBackupsName)
            #ENDIF
        
        
        #RUN(%TemplateRoot&' Proc=CY Parameters="'&%AJEFullPath&'"') 
        #IF(%AJEPathBackupsDctFolder<>'') 
            #RUN(%TemplateRoot&' Proc=CY Parameters="'&%AJEFullPath&'\'&%AJEPathBackupsDctFolder&'"')
        #ENDIF
        #IF(%AJEPathBackupsAppFolder<>'')
            #RUN(%TemplateRoot&' Proc=CY Parameters="'&%AJEFullPath&'\'&%AJEPathBackupsAppFolder&'"')
        #ENDIF
        #IF(%AJEPathBackupsDctxFolder<>'')
            #RUN(%TemplateRoot&' Proc=CY Parameters="'&%AJEFullPath&'\'&%AJEPathBackupsDctxFolder&'"')
        #ENDIF
        #IF(%AJEPathBackupsTxaFolder<>'')
            #RUN(%TemplateRoot&' Proc=CY Parameters="'&%AJEFullPath&'\'&%AJEPathBackupsTxaFolder&'"'),WAIT
        #ENDIF
                
         #IF(%AJEActivaCopyDct=%TRUE)
            #RUN(%TemplateRoot&' Proc=CE Parameters="'&%AJEFileDCT&','&%AJEFullPath&'\'&%AJEPathBackupsDctFolder&'\'&%AJENFileDCT&'.DCT'&','&%AJEVersion&','&%Application&','&%AJEActivaZipFiles&','&%AJEDeleteBeforeDays&','&%AJELocalDeleteBeforeDays&'"')
         #ENDIF
#!
         #IF(%AJEActivaExportTXA=%TRUE)
         #SET(%AJETXAFile,%Application&%AJEVersion&'.TXA')
         
            #CREATE(%AJETXAFile)
                #EXPORT #! Exports entire application
            #CLOSE(%AJETXAFile)
            #RUN(%TemplateRoot&' Proc=CE Parameters="'&%AJETXAFile&','&%AJEFullPath&'\'&%AJEPathBackupsTxaFolder&'\'&%AJETXAFile&','&%AJEVersion&','&%Application&','&%AJEActivaZipFiles&','&%AJEDeleteBeforeDays&','&%AJELocalDeleteBeforeDays&'"')
         #ENDIF
        
         #IF(%AJEActivaExportDCTX=%TRUE)
             #RUN(%TemplateRoot&' Proc=CL Parameters="'&%ClarionCL&','&%AJETempDictionaryFile&','&%AJEFullPath&'\'&%AJEPathBackupsDctxFolder&'\'&%AJENFileDCT&'"')
         #ENDIF

         #RUN(%TemplateRoot&' Proc=CE Parameters="'&%AJEPathFiles&'\'&%AJEFileAPP&','&%AJEFullPath&'\'&%AJEPathBackupsAppFolder&'\'&%AJEFileDestAPP&','&%AJEVersion&','&%Application&','&%AJEActivaZipFiles&','&%AJEDeleteBeforeDays&','&%AJELocalDeleteBeforeDays&'"')
#!
         #FOR(%AJEOtherFiles)
         #IF(%AJEPathBackupsFolder<>'') 
            #RUN(%TemplateRoot&' Proc=CY Parameters="'&%AJEFullPath&'\'&%AJEPathBackupsFolder&'"')
         #ENDIF
         
         #SET(%AJEFileName,CLIP(SUB(%AJEOtherFilesName,INSTRING('\',%AJEOtherFilesName,-1,LEN(%AJEOtherFilesName))+1,LEN(%AJEOtherFilesName))))        
            #RUN(%TemplateRoot&' Proc=CE Parameters="'&%AJEOtherFilesName& ',' &%AJEFullPath&'\'&%AJEPathBackupsFolder&'\'&%AJEFileName&','&%AJEVersion&','&%Application&','&%AJEActivaZipFiles&','&%AJEPathFiles&'"')
         #END
         SETPATH(%AJEOldPath)  
#!
#ENDFOR