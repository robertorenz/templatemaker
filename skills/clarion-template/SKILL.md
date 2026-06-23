---
name: clarion-template
description: Author and modify Clarion 12 templates (.TPL/.TPW) — the code-generation language behind Clarion's AppGen. Covers template kinds (#TEMPLATE/#PROCEDURE/#CONTROL/#EXTENSION/#CODE/#GROUP), the prompt UI (#PROMPT/#BOXED/#SHEET/#TAB), symbols (%Symbol/#DECLARE/#SET/#FOR), embed points (#AT/#EMBED), and code generation (#GENERATE/#CREATE/#INSERT). Use when creating, editing, or debugging any Clarion .tpl/.tpw file.
---

# Clarion Template Authoring

Clarion's Application Generator (AppGen) builds source code by running **templates** against an
application's dictionary, windows, and the developer's prompt choices. A template is a text program
written in the **Template Language** (directives prefixed with `#`) interleaved with literal Clarion
source that is emitted verbatim. Mastering it means you can generate any boilerplate the developer
would otherwise hand-write, with a configurable UI in front of it.

This skill teaches you to **write correct, idiomatic templates**. Reference files (read them when the
task touches their area — don't load all of them up front):

- `reference/directives.md` — the full directive vocabulary with real signatures and examples.
- `reference/patterns.md` — battle-tested authoring patterns (multi-DLL, class registration, embeds, reuse).
- `reference/examples.md` — three complete, annotated templates dissected line-by-line.

The canonical PDFs ship at `C:\clarion12\docs\TemplateLanguageReference.pdf` and `TemplateGuide.pdf`.
Real shipped templates live in `C:\clarion12\template\win\` (ABC = `AB*.TPW`, classic = the rest) and
third-party examples in `C:\clarion12\accessory\template\win\`. **When unsure of exact syntax, read a
shipped template that already does the thing you need** — the corpus is the ground truth.

## File types

| Ext | Role |
|-----|------|
| `.TPL` | Root **chain** file. Holds the `#TEMPLATE(...)` registration and `#INCLUDE`s the `.TPW` parts. This is what the developer registers in the IDE. |
| `.TPW` | Template **part** — the bulk of the code: procedure/control/extension/group definitions. Pulled in via `#INCLUDE`. |
| `.TPX` | Encrypted/compiled template (third-party shipping format). Not hand-edited. |

A template set is a **family** (`FAMILY('ABC')`). Procedures from one family can declare
`PARENT(Window(ABC))` to inherit another template's behavior. The two shipped families are `Clarion`
(classic, `CW.TPL`) and `ABC` (`ABCHAIN.TPL`).

## The five things a template can register

Every block below starts at **column 1** and is the unit the developer picks in the IDE:

1. **`#TEMPLATE(Name,'desc'),FAMILY('x')`** — one per chain; the registration header.
2. **`#PROCEDURE(Name,'desc'),WINDOW,REPORT,...`** — a generatable procedure (Browse, Form, Report…).
3. **`#CONTROL(Name,'desc'),...,MULTI,WRAP(List)`** — a control template dropped onto a window.
4. **`#EXTENSION(Name,'desc'),PROCEDURE`** — adds behavior to a procedure or the whole app without owning a control.
5. **`#CODE(Name,'desc')`** — generates a snippet at an embed point the developer chooses.
6. **`#GROUP(%Name,%arg)`** — a reusable subroutine (no UI); called with `#CALL`/`#INSERT`, can `#RETURN` a value.

`#APPLICATION`, `#PROGRAM`, `#MODULE` are the program-level scaffolding (you rarely write new ones —
study `CW.TPL`/`ABFILE.TPW` if you must).

## Mental model — three rules that prevent most mistakes

1. **`#` directive vs. literal output.** A line whose first non-blank token is a `#` directive is
   *executed*. Any other line is *emitted* into the generated source **verbatim, including its leading
   whitespace**. Clarion source is column-sensitive (labels in column 1, code indented ≥ column 2), so
   the indentation of your output lines is meaningful — get it right. Directives themselves may be
   indented for readability (shipped templates indent `#PROMPT`s inside `#BOXED`), but the registration
   headers (`#TEMPLATE`, `#PROCEDURE`, `#CONTROL`, `#EXTENSION`, `#GROUP`, `#AT`, `#SYSTEM`) conventionally
   sit at column 1.

2. **`#!` is a template comment; `!` is a Clarion comment.** `#!` lines vanish at generation time —
   use them for banners and notes. A bare `!` inside an `#AT` block is emitted as a real Clarion comment.

3. **Two phases: parse-time and generate-time.** `#PREPARE`/`#ATSTART`/`#DECLARE`/`#SET`/`#EQUATE` run
   while the template is *loaded and the UI is built*. `#AT(...)`/`#GENERATE`/literal output run while
   *code is written*. Reading a value in the wrong phase is the classic bug — set state at parse time,
   consume it at generate time.

## Anatomy of a typical extension (the 80% case)

Most real work is a self-contained `#EXTENSION` that prompts for options, includes a class, declares a
global instance, and injects init/shutdown code. Skeleton:

```
#TEMPLATE(MyTools,'My Tools - v1.0'),FAMILY('ABC')
#!----------------------------------------------------------------------
#!  Banner / copyright
#!----------------------------------------------------------------------
#EXTENSION(ActivateMyTool,'Activate My Tool'),APPLICATION,HLP('~MyTool.htm')
#SHEET
  #TAB('General')
    #PROMPT('&Disable this template',CHECK),%MyToolDisable,DEFAULT(0),AT(10)
    #PROMPT('Global &class name:',@s40),%MyToolObject,DEFAULT('MyTool'),REQ
  #ENDTAB
#ENDSHEET
#!
#AT(%AfterGlobalIncludes),WHERE(%MyToolDisable=0)
INCLUDE('MyTool.INC'),ONCE
#ENDAT
#!
#AT(%GlobalData),WHERE(%MyToolDisable=0)
  #IF(%MultiDLL=0 OR %RootDLL=1)
%MyToolObject  MyToolClass
  #ELSE
%MyToolObject  MyToolClass,EXTERNAL,DLL(dll_mode)
  #ENDIF
#ENDAT
#!
#AT(%ProgramSetup),PRIORITY(5000),WHERE(%MyToolDisable=0)
%MyToolObject.Init()
#ENDAT
#!
#AT(%ProgramEnd),WHERE(%MyToolDisable=0)
%MyToolObject.Kill()
#ENDAT
```

This single pattern — *prompt → include → declare (multi-DLL aware) → init/kill at embed points* —
covers the majority of template work. See `reference/patterns.md` for the variations (multi-instance,
per-procedure, project files, export lists, custom embeds).

## Workflow when asked to build or change a template

1. **Find the closest shipped/accessory template that already does something similar** and read it.
   Glob `C:\clarion12\template\win\*.TPW` and `C:\clarion12\accessory\template\win\*.tpl`. Imitation of a
   working template beats invention.
2. **Decide the kind** — extension (most common), control, procedure, or just a group.
3. **Design the prompts** before the code: what does the developer configure? Use `#SHEET`/`#TAB`/`#BOXED`
   and `WHERE()` to show/hide. Give every prompt a `%Symbol`, sensible `DEFAULT()`, and `REQ` where needed.
4. **Pick embed points** for your `#AT` blocks. Common ones: `%AfterGlobalIncludes`, `%GlobalData`,
   `%ProgramSetup`, `%ProgramEnd`, `%ProcedureInitialize`, `%BeforeAccept`, `%ProcedureRoutines`,
   `%WindowManagerMethodCodeSection`, `%DataSection`, `%CustomGlobalDeclarations`, `%DllExportList`.
5. **Handle multi-DLL** from the start (`#IF(%MultiDLL=0 OR %RootDLL=1)`) — retrofitting is painful.
6. **Guard re-declares** with `#IF(VAREXISTS(%x)=0)` / `#DECLARE` in groups that may run more than once.
7. **Verify**: register the `.tpl` in the IDE (Setup ▸ Template Registry), regenerate an app, and check
   the produced source compiles. You cannot run AppGen yourself — tell the developer the exact register/
   regenerate steps and what the generated code should look like.

## Hard-won correctness rules

- **Output-line indentation is literal Clarion** — a label must be column 1, executable code column ≥ 2.
  A stray leading space on a label line breaks compilation.
- **`%Symbol` substitution happens inside output lines** — `%MyObject.Init()` emits the symbol's value.
  Inside string attributes, `<39>` emits a single quote `'`.
- **Escape a literal `%` as `%%` in EVERY emitted line (code AND comments).** The template parser reads
  `%` as the start of a symbol name, so a Clarion modulus like `x % 7` — and especially `x%7` (no space)
  — makes it expect an identifier. Symptom: the template **won't register**, with `Expected an identifier`
  at the offending line. Write `x %% 7` (emits `x % 7`); the corpus does this for the modulus operator
  (`ABUPDATE.TPW:866`: `SELF.RecordsProcessed %% %RecordsToCheckpoint`). Simplest for comments: avoid `%`
  (write "MOD") rather than escaping. Beware trailing notes like `(... literal %)` — that bare `%` also trips it.
- **Porting numeric code? Clarion ROUNDS on integer assignment** (`n=7/2` → 4), bit ops are functions
  (`BSHIFT`/`BAND`/`BOR`/`BXOR`, not `<< >> & | ^`), and arrays are 1-based. Wrap every truncating divide in
  `INT()`, do modulus via a `QRMod()`-style helper (so no literal `%` to escape), and validate the un-runnable
  port against a tested oracle + a golden vector + an in-template self-test. See **patterns.md P14**.
- **`#AT` blocks need `WHERE()` guards** so disabled templates emit nothing. Always honor your own
  `%...Disable` prompt on every `#AT`.
- **`PRIORITY(n)` orders multiple `#AT`s at the same embed** (lower runs earlier; ABC uses ~2000–8000).
- **A self-contained `CASE EVENT()` at `TakeWindowEvent` MUST use `PRIORITY(2000)`, not 2500** — the ABC
  framework's own `LOOP`/`CASE EVENT()` scaffolding is registered at 2500 (`ABWINDOW.TPW:563`), so 2500
  interleaves and produces a duplicate `CASE EVENT()` that won't compile. See patterns.md (drawing section).
- **`ONCE` on `INCLUDE()`** prevents duplicate-symbol errors when an extension is used many times.
- **`#FOR(%File)`/`#FOR(%Control)` etc. iterate AppGen context** — filter with `WHERE()`, exit with `#BREAK`.
- **Match block terminators**: `#ENDIF`/`#END`, `#ENDFOR`/`#END`, `#ENDAT`, `#ENDTAB`, `#ENDSHEET`,
  `#ENDBOXED`, `#ENDBUTTON`, `#ENDENABLE`, `#ENDWITH`, `#ENDCONTEXT`. (`#END` closes most blocks; be consistent.)

### Generating Clarion source — pitfalls that compile-fail (learned the hard way)

- **A `MODULE('dll')` external prototype MUST live in the GLOBAL map, never a local (procedure) `MAP`.**
  A local `MAP` inside a procedure body (e.g. emitted into `%ProgramProcedures`) does **not** accept a
  `MODULE('kernel32') … END` external declaration — the compiler stops recognizing it as a prototype and
  reads the parameter types as attributes. Symptom: `Unknown attribute: LONG` / `Unknown attribute: CSTRING`
  on the prototype line, plus `Expected: <ID> … END INCLUDE OMIT …`. Put Windows/DLL API prototypes in
  `#AT(%GlobalMap)`.
- **A `MAP` prototype takes parameter TYPES, not names.** `MyApi(LONG hWnd, *CSTRING text)` fails with
  `Unknown attribute: text`; write `MyApi(LONG,*CSTRING)`. Keep each prototype on **one line** — very long
  prototypes also mis-parse. (Names are only valid in the procedure *definition*, not the prototype.)
- **Declaring an API the ABC runtime already declares (e.g. `CloseHandle`, `WaitForSingleObject`)** → give it
  a **unique Clarion label + `NAME('RealExport')`**: `myX_CloseHandle(LONG),BOOL,PASCAL,PROC,NAME('CloseHandle')`.
  Avoids a duplicate-label clash while still binding to the real export. For pointers, the simplest portable
  mapping is **all-`LONG` params and pass `ADDRESS(x)` / strings by `ADDRESS()`** at the call — no `*type`, no `RAW`.
- **Load an image file into an IMAGE control at run time with `feq{PROP:Text} = filename`** (clear with `= ''`).
  `PROP:Picture` is the LISTBOX-column picture token, **not** the image-file property — don't use it here.
- **Building a command line / quoted string in emitted code:** `<34>` is a double quote `"`, `<39>` is a
  single quote `'`. Windows argument quoting needs **double** quotes → `<34>`. (`<39>` would pass literal apostrophes.)
- **A developer-entered value emitted verbatim is fragile.** If a prompt feeds straight into code
  (`x = %MyValue`), a plain string like `https://a.com/b` comes out unquoted and the `.`/`/` parse as
  field-access/operators (`Unknown identifier: …`, `Field not found: …`). Give the developer an explicit
  **literal-vs-expression** toggle: literal → emit auto-quoted `'%MyValue'`; variable/expression → emit
  `%MyValue` verbatim. See `reference/patterns.md` P12–P13.
- **A `PROCEDURE`/`CONTROL` extension that emits global helpers (`%GlobalMap`/`%ProgramProcedures`) duplicates
  them for every instance** — add it to two procedures and you get `Procedure … duplicated`. Put shared
  helpers in a separate `APPLICATION`-scope extension (the `myPie`/`myPieGlobal` split, `REQ()`-linked) so
  they emit once. Self-contained helpers in the procedure extension are fine **only** for single-use templates.

When in doubt about a directive, attribute, or built-in symbol, open `reference/directives.md`, or grep
the shipped corpus for a real use before writing it.
