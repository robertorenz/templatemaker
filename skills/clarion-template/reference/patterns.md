# Clarion Template — Authoring Patterns (the real-world playbook)

Patterns distilled from shipped ABC templates and third-party sets (AJE*, CapeSoft AnyFont/AnyText,
ChromeExplorer, HotDates, KeepingTabs, Cryptonite). Each is something you will reach for repeatedly.

---

## P1 — The disable switch (put it on every template)

Give the developer one checkbox that turns the whole template off, and guard **every** `#AT` with it.

```
#PROMPT('&Disable this template',CHECK),%MyToolDisable,DEFAULT(0),AT(10)
...
#AT(%AfterGlobalIncludes),WHERE(%MyToolDisable=0)
INCLUDE('MyTool.INC'),ONCE
#ENDAT
```

---

## P2 — Multi-DLL aware global declarations

A class instance or global variable must be declared `EXTERNAL,DLL(dll_mode)` in every DLL except the
one that actually owns it (the root). This is mandatory for any template used in multi-DLL apps.

```
#AT(%GlobalData),WHERE(%MyToolDisable=0)
  #IF(%MultiDLL=0 OR %RootDLL=1)
MyGlo:Caption        CSTRING(40)
%MyToolObject        MyToolClass
  #ELSE
MyGlo:Caption        CSTRING(40),EXTERNAL,DLL(dll_mode)
%MyToolObject        MyToolClass,EXTERNAL,DLL(dll_mode)
  #ENDIF
#ENDAT
```

And export the owned symbols from the root DLL:
```
#AT(%DllExportList),WHERE(%ProgramExtension='DLL' AND %RootDLL=1 AND %MultiDLL=1)
 #INSERT(%ExportClassesPR,'MyTool.Inc')
 #INSERT(%AddExpItem,'$MyGlo:Caption')
 $%MyToolObject     @?
#ENDAT
```

---

## P3 — Include the class header once

```
#AT(%AfterGlobalIncludes),WHERE(%MyToolDisable=0)
INCLUDE('MyTool.INC'),ONCE
INCLUDE('MyToolEx.INC'),ONCE
#ENDAT
```
`ONCE` is what makes it safe to drop the extension on many procedures without duplicate-symbol errors.

---

## P4 — Init / Kill lifecycle

```
#AT(%ProgramSetup),PRIORITY(5000),WHERE(%MyToolDisable=0)
%MyToolObject.Init()
  #IF(%MyConnString)
%MyToolObject.SetConnection(%MyConnString)
  #ENDIF
#ENDAT
#!
#AT(%ProgramEnd),WHERE(%MyToolDisable=0)
%MyToolObject.Kill()
#ENDAT
```
For a per-procedure extension use `%ProcedureInitialize` / `%ProcedureSetup` and the procedure's
WindowManager method embeds (`%WindowManagerMethodCodeSection,'Init','(),BYTE'`).

---

## P5 — Multi-instance controls/extensions

When `#CONTROL`/`#EXTENSION` is `MULTI`, every instance must produce uniquely named symbols. Append
`%ActiveTemplateInstance` (and the procedure/control) to generated labels:

```
ktSelectedTab%ActiveTemplateInstance_%Procedure_%ControlNameToUse   LONG
```
Manage the list of instances with a `#BUTTON('...'),MULTI(%list,%descExpr),INLINE` whose contained
prompts repeat per row. `%list` holds rows; iterate with `#FOR(%list)`.

---

## P6 — Reusable logic with `#GROUP` + `#INSERT`/`#CALL`/`#RETURN`

```
#GROUP(%StripQFromControl)
  #IF(SLICE(%Control,1,1)='?')
    #RETURN(SUB(%Control,2,LEN(CLIP(%Control))))
  #ELSE
    #RETURN(%Control)
  #ENDIF
...
#SET(%CtrlName,%StripQFromControl())          #! value-returning group used as a function
```
Groups can take parameters with defaults: `#GROUP(%ReadGlobal,%pa,%force)`. Use `#INSERT(%g,a,b)` to
emit its output at a point, `#CALL(%g,a,b)` for side-effects only.

---

## P7 — Conditional & looping generation

```
#IF(%MyLanguage='SPA')
Glo:InsertText = GETINI('BUTTONS','INSERT','Agregar','.\GLOBAL.INI')
#ELSIF(%MyLanguage='ENG')
Glo:InsertText = GETINI('BUTTONS','INSERT','Insert','.\GLOBAL.INI')
#ENDIF

#FOR(%Control),WHERE(%ControlType='LIST' OR %ControlType='DROP' OR %ControlType='COMBO')
%Control{PROP:LineHeight} = %GlobalInterLine
#ENDFOR
```
Detect whether a sibling template is present in the app:
```
#FOR(%ApplicationTemplate),WHERE(%ApplicationTemplate='AJE_StimulSoft(AJEStimulSoft)')
  #SET(%StimulSoftPresent,%True)
  #BREAK
#ENDFOR
```

---

## P8 — Add project files & libraries

```
#AT(%CustomGlobalDeclarations),WHERE(%MyToolDisable=0)
 #PROJECT('None(MyHelper.exe), CopyToOutputDirectory=Always')
 #PROJECT('None(icudtl.dat), CopyToOutputDirectory=Always')
  #IF(%SomeIcon)
 #PROJECT(%SomeIcon)
  #ENDIF
#ENDAT
```

---

## P9 — Expose custom embed points to the developer

Let users inject their own code inside your generated procedures/methods:
```
#EMBED(%MyToolBeforeSend,'Before Send'),TREE('MyTool|SendRequest|1-Before')
#EMBED(%MyToolAfterSend,'After Send'),TREE('MyTool|SendRequest|2-After')
```
Place these between your generated statements so developers can extend without editing the template.

---

## P10 — Safe (re)declaration

A group that may run for many instances should not re-`#DECLARE` the same symbol:
```
#IF(VAREXISTS(%MyState)=0)
  #DECLARE(%MyState)
#ENDIF
```
Use `#PREPARE` … `#ENDPREPARE` to do one-time setup when the procedure template loads, and
`#ATSTART`/`#ATEND` for parse-time init/cleanup that must bracket the whole generation.

---

## P11 — Reading classes / registering objects (ABC convention)

ABC templates call helper groups to read `.INC` class definitions and register instances in the embed
tree under a category:
```
#ATSTART
  #IF(%MyToolDisable=0)
    #INSERT(%ReadGlobal,2,0)
    #IF(%MultiDLL=0 OR %RootDLL=1)
      #INSERT(%AddObjectPR,%MyToolClass,%MyToolObject,'Global Objects')
    #ENDIF
  #ENDIF
#ENDAT
```
`#CONTEXT(%Application,%applicationTemplateInstance)` switches into the instance's scope before reading
its per-instance settings.

---

## Drawing graphics into a control, and redrawing on resize

Clarion has graphics primitives — `PIE`, `ELLIPSE`, `BOX`, `ROUNDBOX`, `ARC`, `CHORD`, `POLYGON`, `LINE`
(see `builtins.clw`) — plus `SETPENCOLOR`/`SETPENWIDTH`. `PIE(x,y,w,h, *SIGNED[] slices, *LONG[] colors,
depth=0, wholeValue=0, startAngle=0)` draws a whole pie from arrays of relative sizes + colors.

- **Target a control as the canvas — and you MUST pass the window.** The **two-argument** form
  `SETTARGET(<window>, ?imageControl)` aims primitives at an IMAGE control, with coordinates **relative to
  the control** (its top-left is `0,0`, so `PIE(0,0,w,h,…)` fills the image). The **one-argument** form
  **`SETTARGET(,?imageControl)` (window omitted) does NOT do this** — primitives then draw on the *window*
  at absolute coordinates, so `BOX(0,0,…)`/`PIE(0,0,…)` land at the **window's** top-left, not on the image.
  (Real bug — myPie GitHub issue #5: "MyPieDraw wrong to position Pie at (0,0), it needs to be at the Image
  X,Y".) Always supply the window:
    - In window/procedure-embed code the window is in scope — pass it: `SETTARGET(MyWindow, ?Image)`.
    - In a **standalone helper PROCEDURE** there is no implicit window. Give it a `WINDOW` parameter and pass
      it through: `MyPieDraw(WINDOW pWnd, SIGNED pImageFeq, …)` → `SETTARGET(pWnd, pImageFeq)`. You *can* use
      `System{PROP:Target}` for "the current window", but passing it is cleaner (and lets the same helper
      target a `REPORT, ?Band`).
    - **Fallback when you can't pass the window:** read the control's window position with
      `GETPOSITION(pImageFeq, ImgX, ImgY)` and draw window-relative at `BOX(ImgX,ImgY,…)` / `PIE(ImgX,ImgY,…)`.
  `SETTARGET()` with no args restores the previous target. (`svgraph.clw` draws into an image via the
  two-arg form.)
- **Image graphics PERSIST and accumulate** — they are NOT auto-cleared. Before redrawing, clear with
  **`BLANK`** (no args = wipe the whole current target's graphics; `svgraph.clw` calls `blank` at the top
  of every redraw). A filled `BOX` is NOT a real clear — it only paints over, so when the control shrinks
  the older/larger drawing survives underneath/around it and you get resize artifacts. Use `BLANK` first,
  then (optionally) a `BOX` to set a specific background color, then draw.
- **Redraw after a resize via a POSTED event, not directly in `EVENT:Sized`.** At the top of
  `TakeWindowEvent` (PRIORITY 2000) the ABC resizer has NOT yet repositioned/resized the child controls,
  so the control's `PROP:Width/Height` is still the old size. Instead `POST` a private event
  (`EQUATE(EVENT:User+nnn)`) on `EVENT:Sized` (and on `EVENT:OpenWindow` for the first draw), and do the
  actual draw when that posted event is handled — by then the window has finished opening / resizing and
  the control reports its new size. Re-read `PROP:Width/Height` inside the draw so it fits the new size.
- **Background + inset niceties (from the myPie fix):** let `COLOR:None` mean "no background box" so the
  caller can keep the image's own backdrop — `IF pBackColor <> COLOR:None THEN SETPENCOLOR(pBackColor);
  BOX(x,y,w,h,pBackColor) END`. And inset the drawing a little so it isn't flush on the box edge:
  `Indt = pPieW * .02; x += Indt; y += Indt; w -= Indt*2; h -= Indt*2` before `PIE(x,y,w,h,…)`.

## Drawing on a REPORT (not a window) — needs a SEPARATE extension

The same draw helper does NOT just work when an extension is dropped on a report. A report procedure has
**two** structures — the print **progress WINDOW** and the **REPORT** — and the window-oriented wiring grabs
the wrong one. Build a dedicated report extension (corpus: `myQRDraw` ships `myQRDraw` for windows +
`myQRDrawReport` for reports; `blobsrv.tpw` for blob-in-report-control). Two gotchas, both of which make it
silently target the window or draw nothing:

- **A `#PROMPT(...,CONTROL)` lists WINDOW controls only.** On a report it offers the progress window's
  controls (and their USE variables), never the report's — the developer picks a control that isn't on the
  report. List the **report's** controls instead with a `FROM()` over `%ReportControl`, filtered by type:
  ```
  #PROMPT('&Image control:',FROM(%ReportControl,%ReportControlType = 'IMAGE')),%MyRptImage,REQ,DEFAULT('')
  ```
  `%ReportControl` yields the same `?`-prefixed field equate a window `CONTROL` prompt gives, so it drops
  straight into `GETPOSITION(%MyRptImage,…)`. Corpus: `blobsrv.tpw:20`
  (`FROM(%ReportControl, %ReportControlType = 'IMAGE' OR …)`).

- **Reports render bands through the print engine, not a window event loop** — there is no
  `EVENT:OpenWindow`/`Sized`/`TakeWindowEvent` for the printed content. Draw in the **print-loop** embed
  **`%BeforePrint`** ('Before Printing Detail Section') — it fires before each DETAIL band prints, so a
  graphic is produced **per record**. Make the **report** the graphics target with **`SETTARGET(%Report)`**
  (`%Report` is the report-label symbol; `SETTARGET` accepts a `REPORT` target + band feq —
  `builtins.clw:1791`), NOT `SETTARGET(,?image)`:
  ```
  #AT(%BeforePrint),WHERE(%MyDisable=0 AND %MyRptImage)
    IF QRBuildMatrix(loc:Value, %MyEcc)        #! encode this row's value
      SETTARGET(%Report)                       #! the report/band is the target
      QRPaint(%MyRptImage, …)                  #! GETPOSITION the band image + draw
      SETTARGET()
    END
  #ENDAT
  ```
  An extension may legitimately fill `%BeforePrint` (corpus: accessory `mytable.tpl:665`, "Blobs on Report -
  Before Print Detail"). No repaint ROUTINE — there is no event loop; the code re-encodes from the live
  field value every time the band prints. Band-draw **placement** is timing-sensitive and not statically
  verifiable — give the report extension a fixed self-test value and confirm by scanning a printout. If a
  single graphic per *page* (not per record) is wanted, target a page-header band / a different embed.

## Gotchas checklist

- [ ] Every `#AT` honors the disable prompt via `WHERE()`.
- [ ] Globals are `EXTERNAL,DLL(dll_mode)` when `%MultiDLL=1 AND %RootDLL=0`; exported from root.
- [ ] `INCLUDE(...),ONCE` on every class header.
- [ ] Output-line indentation matches required Clarion columns (labels col 1).
- [ ] Multi-instance symbols carry `%ActiveTemplateInstance`.
- [ ] `PRIORITY()` set where multiple `#AT`s share an embed point.
- [ ] `<39>` (not a bare `'`) for quotes inside string attributes/defaults.
- [ ] `#GROUP` definitions placed AFTER all `#AT`/`#EMBED` blocks (a `#GROUP` has no end-marker and
      swallows following lines until the next section directive — an `#AT` after a `#GROUP` errors
      "#AT not valid in a #GROUP"). Put groups at the end; calls resolve by forward reference.
- [ ] Per-iteration values in per-procedure `#AT` output (e.g. an INI key from `%Procedure`+`%Control`)
      built by **direct symbol substitution** in the output line: `'%Procedure' & '_' & '%Control'`
      (each `%Sym` substitutes inside the quotes at gen time; `&` concatenates the literals at runtime).
      Two traps that both yield a BLANK/wrong value here:
        • an extension-level `#DECLARE`'d symbol + `#SET` → "GEN: Unknown Variable '%sym'" (the symbol is
          not in scope during per-procedure generation);
        • a `#GROUP` that reads *ambient* `%Control`/`%Procedure` called inline as `%(%MakeKey())` →
          returns EMPTY, because an inline group call does NOT inherit the caller's `#FOR` context.
      If you must use a group, PASS the values as parameters (corpus idiom: `%(%StripPling(%BrowseFile))`),
      don't rely on ambient context.
- [ ] Literal `%` in emitted lines (modulus `x % 7`, etc.) escaped as `%%` — otherwise the template
      won't register (`Expected an identifier`). Avoid `%` in comments (write "MOD"). Watch for bare `%`
      in trailing parentheticals. Corpus: `ABUPDATE.TPW:866` (`SELF.RecordsProcessed %% %RecordsToCheckpoint`).
- [ ] On a **REPORT**, use a SEPARATE extension: pick controls with `FROM(%ReportControl,…)` (a `,CONTROL`
      prompt lists WINDOW controls only), and draw in the `%BeforePrint` embed via `SETTARGET(%Report)` —
      reports have no window event loop. See "Drawing on a REPORT".
- [ ] Block terminators balanced (`#ENDAT`, `#ENDIF`/`#END`, `#ENDFOR`, `#ENDTAB`, `#ENDSHEET`, …).
- [ ] `.tpl` `#INCLUDE`s all its `.tpw` parts; `#TEMPLATE` header present and at column 1.
- [ ] Default parameter values (`=0`, `=1`) appear ONLY in the **prototype** (the MAP / `.inc`),
      never in a free-standing procedure's **implementation** header. Write the body as
      `weekNumber PROCEDURE(LONG pDate)` even though the prototype is `weekNumber PROCEDURE(LONG pDate=0),LONG`.
      (CLASS *methods* are the exception — their impl mirrors the CLASS prototype and keeps the default.)
      Getting this wrong yields "No matching prototype available", "Unknown identifier: <param>", and
      "Cannot RETURN value from procedure" all at once.

## Adding a global, callable utility function via template

The make-or-break rule: a module that **defines** a free procedure must see a **BARE** prototype for it
(no `MODULE()` wrapper) — that's what marks it "defined in THIS module" so the body matches. Other
modules (and the global map) must see it **wrapped** in `MODULE('thatfile.clw')` so the linker knows
where it lives. Proof: `wbstd.CLW`/`ICSTD.CLW` prototype their own procedures bare in their own MAP;
`MODULE('Windows')`/`MODULE('SCHOOLnnn.CLW')` wrappers are used only for *external* procedures. Putting a
`MODULE('self.clw')` wrapper in the defining module's own MAP yields "No matching prototype available",
"Unknown identifier: <param>", and "Cannot RETURN value" all at once.

**Best approach (self-contained, no external files, EXE targets):** define the function IN the program
module and prototype it BARE in the global map — same module, so the bare prototype matches the body.
This is the structure of the simplest single-file Clarion program and avoids all multi-module traps.
```
#AT(%GlobalMap),WHERE(...)                       #! prototype, bare = "in the program module"
Func                 PROCEDURE(LONG p=0),LONG
#ENDAT
#AT(%ProgramProcedures),WHERE(...)               #! body, in the program module (EXE targets)
Func  PROCEDURE(LONG p=0)
loc:x  LONG
  CODE
  RETURN loc:x
#ENDAT
```
The default in the prototype makes the parameter omittable at the call site (`Func()`). Note: the only
corpus examples of a procedure with a default param (ABC class methods, e.g. ABBROWSE.CLW:2265) keep the
`=0` in BOTH the prototype and the body header — mirror that (`=0` in both) for an exact match.
`%ProgramProcedures` is EXE-only; for multi-DLL, emit the body into the shared/root target and export it.

**Critical MAP-indentation gotcha:** `%GlobalMap` (and any embed inside a structure) auto-indents your
emitted lines. A **long-form** prototype `Func PROCEDURE(...)` needs its label in **column 1**, so the
auto-indent breaks it with bogus errors ("Redefining system intrinsic: LONG", "Illegal return type",
"Indistinguishable new prototype"). Use the **short prototype form** in a MAP embed — `Func(params),return`
(no `PROCEDURE` keyword, no label) — which has no column-1 requirement and survives indentation. This is
exactly what `ICSTD.CLW`'s MAP (`GetHexValue(BYTE),BYTE`, indented) and `anytext.tpl`'s `%GlobalMap`
(`AnyTextFreeCache()`) do. The body in `%ProgramProcedures` is a DATA region and is NOT auto-indented, so
write it long-form at column 1 as normal. Short-form proto and long-form body match fine.

**Alternative (separate shipped module):** if you must keep bodies in a hand-maintained `.clw`, the
defining module must see a BARE prototype (its own `MAP` `INCLUDE`s a bare `.inc`), and the global map
must reference it WRAPPED in `MODULE('myFuncs.clw')`, plus `#PROJECT('myFuncs.clw')` to compile it. This
works but is fiddly (MEMBER()/MODULE() matching) — prefer the program-module approach above unless you
have a reason not to.

## P12 — Calling a Windows / external DLL API (e.g. shelling a command hidden)

To call a DLL export (kernel32, urlmon, user32, …) the prototype goes in a `MODULE('dll')` block. Three rules,
each learned from a compile failure:

1. **The `MODULE('dll')` block MUST be in the GLOBAL map.** A local (procedure) `MAP` — e.g. one you emit
   inside a helper body in `%ProgramProcedures` — does NOT accept a `MODULE()` external declaration; the
   compiler reads the prototype's parameter types as attributes (`Unknown attribute: LONG`, `Unknown
   attribute: CSTRING`, `Expected: <ID> … END INCLUDE OMIT …`). Emit it via `#AT(%GlobalMap)`.
2. **Type-only parameters, one line each.** Names break it (`Unknown attribute: <name>`); so do over-long
   lines. The most portable mapping is **all `LONG`**, passing pointers as `ADDRESS(x)` at the call (no
   `*type`, no `RAW`).
3. **Unique label + `NAME()` to dodge runtime clashes.** The ABC runtime already prototypes common APIs
   (`CloseHandle`, `WaitForSingleObject`, …). Prefix yours and bind via `NAME()`.

```
#AT(%GlobalMap),WHERE(%MyDisable=0)
  MODULE('kernel32')
my_CreateProcess(LONG,LONG,LONG,LONG,LONG,ULONG,LONG,LONG,LONG,LONG),LONG,PASCAL,PROC,NAME('CreateProcessA')
my_WaitObject(LONG,ULONG),LONG,PASCAL,NAME('WaitForSingleObject')
my_CloseHandle(LONG),LONG,PASCAL,PROC,NAME('CloseHandle')
  END
#ENDAT
```
Call site (string + GROUPs passed by `ADDRESS()`): `my_CreateProcess(0, ADDRESS(loc:Cmd), 0,0,0, CREATE_NO_WINDOW, 0,0, ADDRESS(si), ADDRESS(pi))`.
**Simplest of all if a console flash is acceptable:** skip the API entirely and use built-in `RUN('cmd …', 1)`
(`1` = wait) — no prototypes, no structs, always compiles. Good fallback to offer in a comment.
Reference: this is the `myQR` template (curl download, hidden+synchronous via `CreateProcessA`).

## P13 — Emitting a developer-entered value (literal vs variable/expression)

When a prompt value is dropped straight into generated code (`x = %MyValue`), a plain literal is a trap: the
user types `https://a.com/b` and you emit `x = https://a.com/b`, where Clarion parses the `.`/`/` as
field-access/operators → `Unknown identifier: …`, `Field not found: …`. Don't rely on the user adding quotes.

Give an explicit mode with a `CHECK`, default to literal so the obvious case just works:
```
#PROMPT('&Value:',@s255),%MyValue,DEFAULT('https://example.com')
#PROMPT('Value is a varia&ble / expression (untick = literal text)',CHECK),%MyValueIsVar,DEFAULT(0)
…
#IF(%MyValueIsVar)
  loc:V = %MyValue                #! a variable/expression — emitted verbatim, read live
#ELSE
  loc:V = '%MyValue'              #! a literal — auto-quoted
#ENDIF
```
Caveat to document: a literal containing a `'` needs it doubled (`''`) or use variable mode — the template
can't safely escape arbitrary embedded quotes at generate time.

## P14 — Porting a numeric algorithm to runtime Clarion (the integer-math traps)

When you emit a non-trivial computation in Clarion (a hash, a CRC, an encoder — e.g. the `myQRDraw`
template's QR encoder ported from a C# reference), four language differences bite. Get them wrong and the
output is silently wrong, not a compile error.

1. **Clarion ROUNDS on assignment to an integer; it does not truncate.** `n = 7/2` gives **4**, not 3.
   Every place the source language did integer/floor division, wrap it: `n = INT(7/2)`. This includes
   right-shift-by-division, `bit/8`, `r/2`, percentage math — anywhere a fractional result is assigned to a
   LONG/BYTE.

2. **Modulus: avoid the literal `%`.** Clarion *has* a `%` modulus operator, but in a template every emitted
   `%` must be escaped `%%` (the parser reads `%` as a symbol start — unescaped, the template won't even
   register). Sidestep the whole trap with a one-line helper and call it everywhere:
   ```
   QRMod  PROCEDURE(LONG a,LONG b)        #! a MOD b, no '%' in the emitted source
     CODE
     RETURN a - INT(a/b)*b
   ```
   Now no emitted line contains `%`, so there is nothing to escape and nothing to forget.

3. **Bit operations are functions, not operators.** There is no `<<`, `>>`, `&`, `|`, `^`. Use
   `BSHIFT(v,n)` (n **positive = left**, **negative = right**), `BAND`, `BOR`, `BXOR`. They nest:
   `(x>>9)&1` → `BAND(BSHIFT(x,-9),1)`. Hex literals must start with a digit and end in `h`: `0x11D` →
   `011Dh`, `0xEC` → `0ECh`.

4. **0-based algorithm vs 1-based Clarion arrays.** Clarion `DIM(n)` is indexed `1..n`. Keep the
   algorithm's coordinates 0-based (so every modulus/shift formula is copied verbatim from the source) and
   isolate the offset in tiny accessors — `QRGetM(r,c) → RETURN QR:Mod[r+1,c+1]` / `QRSet(r,c,v)`. Mixing
   the two conventions inline is the #1 source of off-by-one corruption.

Verifying a port you **cannot run** (you can't drive AppGen): anchor it to a runnable oracle.
- Keep the reference implementation in a tested project (here, `designer/QrCodeCore` validated by ZXing).
- **Pin a golden vector** — the exact expected output for one fixed input — as an automated test.
- Build a **self-test option** into the template that produces that same fixed output, so the developer can
  *observe* correctness end-to-end (for myQRDraw: a "draw HELLO WORLD" toggle whose 21×21 symbol equals the
  golden matrix — scanning it confirms the whole pipeline on the target machine).

Also: a short-form `%GlobalMap` prototype carries the return type (`QRGfMul(LONG,LONG),LONG`); the matching
body **omits** it (`QRGfMul PROCEDURE(LONG a,LONG b)`) — confirmed against `libsrc\win\SystemString.clw`.

Reference: the `myQRDraw` template (offline QR encoder + `BOX` drawing; companion to the online `myQR`).
