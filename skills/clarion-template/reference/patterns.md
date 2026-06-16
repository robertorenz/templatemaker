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

- **Target a control as the canvas:** `SETTARGET(<window>, ?imageControl)` aims primitives at an IMAGE
  control (the `band` param). Coordinates are relative to the control; `SETTARGET()` with no args restores.
  (`svgraph.clw` creates an image and draws into it this way.)
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

## Gotchas checklist

- [ ] Every `#AT` honors the disable prompt via `WHERE()`.
- [ ] Globals are `EXTERNAL,DLL(dll_mode)` when `%MultiDLL=1 AND %RootDLL=0`; exported from root.
- [ ] `INCLUDE(...),ONCE` on every class header.
- [ ] Output-line indentation matches required Clarion columns (labels col 1).
- [ ] Multi-instance symbols carry `%ActiveTemplateInstance`.
- [ ] `PRIORITY()` set where multiple `#AT`s share an embed point.
- [ ] `<39>` (not a bare `'`) for quotes inside string attributes/defaults.
- [ ] Literal `%` in emitted lines (modulus `x % 7`, etc.) escaped as `%%` — otherwise the template
      won't register (`Expected an identifier`). Avoid `%` in comments (write "MOD"). Watch for bare `%`
      in trailing parentheticals. Corpus: `ABUPDATE.TPW:866` (`SELF.RecordsProcessed %% %RecordsToCheckpoint`).
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
