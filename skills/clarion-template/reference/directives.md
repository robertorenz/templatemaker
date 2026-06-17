# Clarion Template Language — Directive Reference

Every example below is drawn from real shipped templates in `C:\clarion12\template\win\` and
`C:\clarion12\accessory\template\win\`. Directives start with `#`; everything else is emitted as
literal Clarion source. `#!` is a template comment (discarded); `!` inside output is a Clarion comment.

---

## 1. Registration headers (column 1, the units the IDE shows)

### `#TEMPLATE` — chain root, one per `.TPL`
```
#TEMPLATE(ABC,'Application Builder Class Templates'),FAMILY('ABC')
#HELP('ClarionHelp.chm')
```
`FAMILY('x')` (repeatable) ties the set together; procedures can inherit cross-template via `PARENT(...)`.

### `#APPLICATION` / `#PROGRAM` / `#MODULE`
```
#APPLICATION('CW Default Application'),HLP('~TPLApplication.htm')
```
Program-level scaffolding (global prompts, the program skeleton, module file splitting). Rarely
hand-authored; study `CW.TPL` and `ABFILE.TPW`.

### `#PROCEDURE` — a generatable procedure
```
#PROCEDURE(Window,'Generic Window Handler'),WINDOW,REPORT,HLP('~tplprocwindow.htm')
#PROCEDURE(Browse,'Browse Fields in a List Box'),WINDOW,REPORT,PARENT(Window(ABC)),HLP('~...')
```
Attributes: `WINDOW`, `REPORT` (what UI it owns), `PARENT(Proc(Family))` (inherit), `HLP()`, `WIZARD`.

### `#CONTROL` — a control dropped on a window
```
#CONTROL(BrowseBox,'File-Browsing List Box'),PRIMARY(...,OPTKEY),DESCRIPTION('Browse on '&%Primary),MULTI,WINDOW,WRAP(List),HLP('~...')
#CONTROL(CalendarButton,'Call a Calendar Lookup'),WINDOW,MULTI,HLP('~...')
```
Attributes: `PRIMARY(prompt,OPTKEY)` (require/optionally a file+key), `MULTI` (allow many instances),
`WRAP(List)` (wrap an existing control), `DESCRIPTION(expr)` (dynamic tree label), `WINDOW`.

### `#EXTENSION` — behavior with no control of its own
```
#EXTENSION(RecordValidation,'Validate a record against the dictionary'),PROCEDURE,HLP('~...')
#EXTENSION(ActivateMyTool,'Activate My Tool'),APPLICATION
```
Scope attribute is required: `PROCEDURE` (attaches to one procedure) or `APPLICATION` (global, once per app).

### `#CODE` — generate a snippet where the developer asks
```
#CODE(BrowseSelect,'Call a Browse Procedure to select a record'),PRESERVE,HLP('~...')
```
Generates inline at an embed point chosen in the IDE. `PRESERVE` keeps prior state.

### `#GROUP` — reusable subroutine (no UI)
```
#GROUP(%StripQFromControl)
  #IF(SLICE(%Control,1,1)='?')
    #RETURN(SUB(%Control,2,LEN(CLIP(%Control))))
  #ELSE
    #RETURN(%Control)
  #ENDIF

#GROUP(%WriteFDModules,%lLink=''),AUTO,PRESERVE      #! params with defaults; AUTO=run during gen
```
Call with `#CALL(%Group,args)` (side effects) or `#INSERT(%Group,args)` (emit its output), or in an
expression `%StripQFromControl()` when it `#RETURN`s a value.

**Placement gotcha:** a `#GROUP` has **no end-marker** — its body runs until the next *section* directive
(`#GROUP`, `#PROCEDURE`, `#CONTROL`, `#EXTENSION`, `#CODE`, `#APPLICATION`, `#MODULE`, `#SYSTEM`) or EOF.
`#AT`/`#EMBED` do NOT end a group and are not allowed inside one, so a `#GROUP` placed *before* an `#AT`
swallows it → `Error: #AT not valid in a #GROUP`. **Define your `#GROUP`s after all `#AT` blocks (commonly
at the very end of the file/extension).** Calls resolve by forward reference, so using a group earlier than
it is defined is fine.

---

## 2. Prompt / UI directives (build the configuration dialog)

### `#PROMPT('label',TYPE),%Symbol,attrs`
```
#PROMPT('Show &VIRTUAL Keyword',CHECK),%ShowVIRTUAL,DEFAULT(%True),AT(10)
#PROMPT('&Locator:',DROP('None|Step|Entry|Incremental|Filtered')),%LocatorType,DEFAULT('Step')
#PROMPT('Program &Author:',@s40),%ProgramAuthor
#PROMPT('&Seconds for RECOVER:',SPIN(@N3,1,120,1)),%LockRecoverTime,DEFAULT(10)
#PROMPT('&DATA Sections',COLOR),%ColorDataSection,DEFAULT(00000FFH)
#PROMPT('Default &Icon:',ICON),%ProgramIcon
#PROMPT('Field:',FIELD),%SortField,REQ
#PROMPT('Key to Use:',KEY(%Primary)),%SortKey
#PROMPT('&Related File:',FILE),%SortRangeFile
#PROMPT('&New Locator Control:',CONTROL),%OverrideLocator,REQ
#PROMPT('Storage Variable:',FROM(%GlobalData)),%RuntimeVar
#PROMPT('Condition:',EXPR),%SortCondition,REQ,WHENACCEPTED(%SVExpresionEditor(%SortCondition))
```
**Prompt types:** `CHECK`, `OPTION`+`RADIO`, `DROP('a|b|c')`, `SPIN(picture,lo,hi,step)`, `COLOR`,
`ICON`, `FILE`, `FIELD`, `KEY(%file)`, `CONTROL`, `COMPONENT`, `PROCEDURE`, `KEYCODE`, `EXPR`
(expression editor), `FROM(%collection)`, or a Clarion picture (`@s40`, `@S255`, `@N3`) for typed input.
**Common attrs:** `%Symbol` (where the value lands), `DEFAULT(v)`, `REQ` (required), `AT(x,y,w,h)`,
`PROMPTAT(...)`, `WHERE(expr)` (conditional show), `WHENACCEPTED(%group(...))` (run on change),
`PROP(PROP:Disable,1)` (read-only).

### Containers & layout
```
#SHEET,ADJUST                 #! tabbed dialog; ADJUST auto-sizes
  #TAB('&General'),HLP('~...')
    #BOXED('&Options'),AT(12,,216)
      #PROMPT(...)
    #ENDBOXED
    #BOXED('&Colors'),WHERE(%ColorEntries)   #! whole box hidden when WHERE is false
      #PROMPT(...)
    #ENDBOXED
  #ENDTAB
#ENDSHEET
```
- `#BUTTON('text'),...` … `#ENDBUTTON` — an expandable sub-dialog. With `MULTI(%list,%descexpr)` it
  manages a **list of instances** (add/remove rows), each row holding the prompts inside.
  `FROM(%Control,%expr)` ties the button list to an AppGen collection. `INLINE` shows it inline.
- `#ENABLE(expr)` … `#ENDENABLE` — enable/disable (grey out) the contained prompts; `CLEAR` blanks them when disabled.
- `#DISPLAY('text')` / `#DISPLAY(expr)` — read-only label or computed text.
- `#IMAGE('file.png'),AT(...)` — picture in the dialog.

### Validation
`#VALIDATE(expr,'message')` rejects bad input before generation; `REQ` enforces non-blank;
`WHENACCEPTED(%group)` lets a group post-process or launch a sub-editor.

---

## 3. Symbols & state

`%Name` is a template symbol. Convention: `%MixedCase`. Substituted into output lines literally.

```
#DECLARE(%MyVar)                          #! simple, parse-time
#DECLARE(%ByteCount,LONG)                 #! typed
#DECLARE(%GlobalIncludeList),UNIQUE       #! collection, de-duplicated
#DECLARE(%ClassDeclarations),MULTI        #! ordered multi-value collection
#DECLARE(%HotField),MULTI,DEPEND(%HotFields)   #! child rows tied to a parent multi
#EQUATE(%FilesPerBCModule,20)             #! compile-time constant
#SET(%FDCount,1)                          #! assign / overwrite
#ADD(%GlobalIncludeList,%RemovePath(%file))    #! append to UNIQUE/MULTI
#FREE(%UsedDriverDLLs)                     #! empty a collection
```
Modifiers on `#DECLARE`: `UNIQUE` (no dups), `MULTI` (indexed list), `SAVE` (persist across loads),
`DEPEND(%parent)` (child of a multi), plus types `LONG`/`CSTRING`/`STRING`/`REAL`.

**Read multi-values** with `#FOR`; `ITEMS(%multi)` = count, `INSTANCE(%multi)` = current index.

### Built-in / context symbols (populated by AppGen)
`%Application`, `%Program`, `%Procedure`, `%Module`, `%File`, `%Field`, `%Key`, `%Control`,
`%ControlType`, `%FieldType`, `%Primary`, `%Secondary`, `%Relation`, `%Window`, `%True`/`%False`,
`%ActiveTemplateInstance` (numeric id of the current instance — use it to make per-instance globals
unique), `%MultiDLL`/`%RootDLL`/`%ProgramExtension` (DLL build context), `%GlobalData`.

### Useful built-in functions
`VAREXISTS(%x)`, `ITEMS(%multi)`, `INSTANCE(%multi)`, `LEN(s)`, `CLIP(s)`, `SUB(s,start,len)`,
`SLICE(s,a,b)`, `INSTRING(sub,s,step,start)`, `UPPER(s)`, `LOWER(s)`, `CALL(%group)`, `EXTRACT(...)`.

---

## 4. Control flow

```
#IF(~%ConditionalGenerate OR %DictionaryChanged)
  ...
#ELSIF(%x='ENG')
  ...
#ELSE
  ...
#ENDIF                       #! or #END

#CASE(%INIProgramIniLocation)
#OF('APPDIR')
  #SET(%INIFileName,'.\'&%Application&'.INI')
#OROF('CSIDLDIR')
  ...
#ELSE
  ...
#ENDCASE

#FOR(%Control),WHERE(%ControlType='LIST' OR %ControlType='DROP')
%Control{PROP:LineHeight} = %GlobalInterLine
#ENDFOR                      #! #BREAK exits early; #CYCLE skips to next

#LOOP / #WHILE(expr) ... #ENDLOOP
#WITH(%ClassItem,'Triggers:'&%File)        #! temporarily rebind context
  #INSERT(%GlobalClassPrompts(ABC))
#ENDWITH
#CONTEXT(%Application,%applicationTemplateInstance)   #! enter an instance scope
  #INSERT(%ReadClassesPR,'MyClass.inc',%pa,%force)
#ENDCONTEXT
#RETURN(value)               #! return from a #GROUP
```

---

## 5. Embed / injection directives

```
#AT(%ProgramSetup),PRIORITY(5000),WHERE(%MyToolDisable=0),DESCRIPTION('Init My Tool')
%MyToolObject.Init()
#ENDAT
```
`#AT(%EmbedPoint[,'sub','signature'])` injects template+literal code at a named generation point.
Attributes: `PRIORITY(n)` (order at the same point, lower=earlier), `WHERE(expr)` (skip if false),
`DESCRIPTION('...')` (label in embed tree).

```
#ATSTART
#CALL(%ProcedureAutoBindClean)             #! runs at parse/prepare time (setup), not output time
#ENDAT
#ATEND ... #ENDAT                          #! cleanup pass
```

```
#EMBED(%BeforeProcedureCall,'Before calling procedure'),%ProcsCalled,TREE('MyTool|Send|1-Init'),HIDE
```
`#EMBED(%Name,'desc')` *declares a developer embed point* inside your generated code (where they can add
their own source). Attributes: a context symbol to make it per-instance, `TREE('a|b|c')` (placement in
the embed tree), `LEGACY` (preserve old hand code), `DATA`/`LABEL`/`HIDE`.

**Common embed points:** `%AfterGlobalIncludes`, `%GlobalData`, `%CustomGlobalDeclarations`,
`%ProgramSetup`, `%ProgramEnd`, `%ProcedureInitialize`, `%DataSection`, `%BeforeAccept`,
`%ProcedureRoutines`, `%WindowManagerMethodCodeSection` (with `'Init','(),BYTE'` etc.),
`%DllExportList`, `%BeforeGlobalIncludes`.

---

## 6. Code-generation & file directives

```
#GENERATE(%Procedure)                      #! emit a procedure's code
#GENERATE(%Program)
#CREATE('FD.$$$')                          #! open a temp module file for writing
   MEMBER
#INSERT(%GenerateFileDeclaration,%False)   #! emit a group's output here
#CLOSE('FD.$$$')
#REPLACE(%FDFilename,'FD.$$$')             #! overwrite target only if changed (preserves timestamps)
#REMOVE('FD.$$$')
#PROJECT(%FDFilename)                      #! add a file to the .cwproj
#PROJECT('None(MyHelper.exe), CopyToOutputDirectory=Always')
#MESSAGE('Generating Module: '&%Module,1)  #! progress text; level 1/2/3
#COMMENT(60)                               #! align trailing ! comments to column 60
#FIX(%Procedure,%ModuleProcedure)          #! set the current context record
#SUSPEND / #RESUME                         #! emit a block literally without template processing
```

---

## 7. Literal-output subtleties

- A line not starting with a `#` directive is **emitted verbatim, leading whitespace included**.
  Clarion is column-sensitive: labels in column 1, statements indented. Indent output lines exactly
  as the generated source must appear.
- `%Symbol` inside an output line is replaced by its value: `%Obj.Init()` → `MyTool.Init()`.
- Inside template **string attributes**, `<39>` produces a literal single quote; `''` (doubled) also
  escapes a quote in some contexts (e.g. `DEFAULT('Don''t')`).
- Directive lines may be indented for readability, but keep registration headers and `#AT`/`#SYSTEM`
  at column 1 to match the corpus and avoid edge-case parser issues.
