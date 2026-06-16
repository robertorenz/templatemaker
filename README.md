# Clarion Template Maker

Tooling to make Claude a **Clarion 12 template authoring professional** — for creating and editing the
`.tpl`/`.tpw` files that drive Clarion's Application Generator (AppGen).

This was built by studying the installed Clarion 12 template corpus:
- Shipped ABC + classic templates — `C:\clarion12\template\win\` (160 `.tpl`, 626 `.tpw`)
- Third-party / accessory templates — `C:\clarion12\accessory\template\win\` (AJE*, CapeSoft AnyFont/
  AnyText, ChromeExplorer, HotDates, KeepingTabs, Cryptonite, …)
- Official docs — `C:\clarion12\docs\TemplateLanguageReference.pdf`, `TemplateGuide.pdf`

## What was created

### 1. Skill — `clarion-template`
Location: `~/.claude/skills/clarion-template/`

A reusable knowledge pack Claude loads when working on any `.tpl`/`.tpw` file:
- `SKILL.md` — file types, the three-rule mental model (directive vs. literal, `#!` vs `!`,
  parse-time vs generate-time), the 80%-case extension skeleton, authoring workflow, correctness rules.
- `reference/directives.md` — full directive vocabulary (`#TEMPLATE`/`#PROCEDURE`/`#CONTROL`/
  `#EXTENSION`/`#CODE`/`#GROUP`, the `#PROMPT`/`#SHEET`/`#TAB`/`#BOXED` UI set, `%Symbol` state,
  control flow, `#AT`/`#EMBED` injection, `#GENERATE`/`#CREATE`/`#INSERT`) with real signatures.
- `reference/patterns.md` — the playbook: disable switch, multi-DLL externals + export lists, `ONCE`
  includes, Init/Kill lifecycle, multi-instance naming, `#GROUP` reuse, project files, custom embeds.
- `reference/examples.md` — three complete annotated templates (a procedure extension, an application
  extension, a value-returning group) plus a verification checklist.

### 2. Agent — `clarion-template-pro`
Location: `~/.claude/agents/clarion-template-pro.md`

A specialist subagent trained on the above. Use it for any template task — writing a new
procedure/control/extension/code/group template, modifying or debugging an existing one, explaining
directives, or designing the AppGen prompt UI and embed wiring. It reads the skill references and the
shipped corpus before writing, respects the parse-time/generate-time model, and predicts the generated
Clarion source so you know exactly what to verify.

## Repo layout

```
skills/clarion-template/        # the skill (SKILL.md + reference/)
agents/clarion-template-pro.md  # the specialist subagent
templates/                      # ready-to-register Clarion templates
  myPixel.tpl                   #   per-window diagnostic pixel (see below)
  showLine.tpl                  #   Ctrl+Shift+P "where am I" hotkey (see below)
  myFuncs/                      #   global function library (see below)
    myFuncs.tpl                 #     self-contained: prototypes + bodies in one template
  myPie/                        #   pie chart for a window (see below)
    myPie.tpl                   #     global helper + procedure extension
README.md
```

## Included templates

### `templates/myPixel.tpl` — per-window diagnostic pixel
A global (APPLICATION-scope) ABC extension that needs no per-procedure setup. On **every** procedure
that owns a window it drops a tiny configurable REGION "pixel" in the top-left corner. Hovering it shows
a tooltip with the **procedure name**, the current **thread number**, and the **binary** the procedure
lives in (app/EXE or DLL). Pressing **Ctrl+Shift+I** pops a message box with the same information.

- Prompts: master disable, pixel fill color, pixel size, and a Ctrl+Shift+I hotkey toggle.
- Implementation: a self-contained `CASE EVENT()` injected at the top of `WindowManager.TakeWindowEvent`
  (PRIORITY 2000, before the framework's CYCLE/BREAK loop), creating the control on `EVENT:OpenWindow`
  and answering `EVENT:AlertKey`. Local-only code — no globals, so no multi-DLL handling needed.
- Register it like any template (see below), then add **myPixel - Diagnostic Pixel (Global)** under
  Global → Extensions.

### `templates/showLine.tpl` — Ctrl+Shift+P "where am I" hotkey
A global (APPLICATION-scope) ABC extension that needs no per-procedure setup. On **every** windowed
procedure it alerts **Ctrl+Shift+P**; pressing it pops a message telling you where you are: the
**procedure** (the code you're in), the **control with focus** (its field number and USE variable), the
**thread number**, and the host **binary** (EXE/DLL).

- Prompts: master disable, a toggle to include the focused-control details, and a custom message title.
- Implementation: a self-contained `CASE EVENT()` injected at the top of `WindowManager.TakeWindowEvent`
  (PRIORITY 2000); `ALERT(CtrlShiftP)` on `EVENT:OpenWindow`, and on `EVENT:AlertKey` it reads `FOCUS()`
  and `feq{PROP:Use}` to report the live focus. Local-only code — no globals, so no multi-DLL handling.
- Register it, then add **showLine - Where-Am-I Hotkey (Global)** under Global → Extensions.

### `templates/myFuncs/` — global function library
A global (APPLICATION-scope) ABC extension that makes a growing set of utility **functions** callable
from anywhere in the app, with no per-procedure setup and **no external source files**. The template
is self-contained: it adds each prototype **bare** to the program's global `MAP` (`#AT(%GlobalMap)`)
and writes each function **body into the program module itself** (`#AT(%ProgramProcedures)`). Prototype
and body in the same module is the simplest, always-valid Clarion structure. Grow the library by adding
one prototype line and one body to `myFuncs.tpl` — nothing else to wire.

**Functions provided** (both take an omittable date that defaults to today):
- **`weekNumber(<date>),LONG`** — **ISO‑8601 (European)** week number. Weeks start Monday; week 1 is the
  week containing the year's first Thursday (the week with Jan 4). Early‑January dates can fall in week
  52/53 of the *prior* year.
- **`weekNumberUS(<date>),LONG`** — **US / North‑American** week number. Weeks start Sunday; week 1 is the
  week containing January 1st, so Jan 1 is always in week 1.

```clarion
wk  = weekNumber()              ! this week's ISO number
wk2 = weekNumber(myOrder:Date)  ! ISO week of a specific date
us  = weekNumberUS(myOrder:Date)! US week of the same date (can differ by one)
```

Install: register `myFuncs.tpl`, then add **myFuncs - Global Function Library (Global)** under
Global → Extensions, generate, and build. (No source files to copy — everything is generated.)

### `templates/myPie/` — pie chart on a window
Two ABC extensions that render a pie chart into an IMAGE control using Clarion's built-in `PIE` graphics
primitive (no external files):
- **`myPieGlobal`** (APPLICATION) — adds a global helper `myPieDraw(imageFeq, slices[], colors[], depth)`
  to the program module that does `SETTARGET(,image)` + `PIE(...)`. Add once, globally.
- **`myPie`** (PROCEDURE) — drop on a window procedure; pick a sized **IMAGE control**, set an optional 3D
  depth, and define 4–5+ segments (label / relative **value** / **color**). On window open it builds the
  slice and color arrays and calls the helper, drawing the pie into the control.

`PIE` (`builtins.clw:1402`) takes a SIGNED array of relative slice sizes and a LONG array of colors and
draws the whole chart in one call; `SETTARGET(window, ?image)` aims the graphics at the IMAGE control.

Install: register `myPie.tpl`; add **myPie - Global Helper** under Global → Extensions; drop a sized
IMAGE control (e.g. `?PieImage`) on a window; add the **myPie** procedure extension to that procedure,
pick the image, define segments; generate and build.

## Install

Copy the two folders into your Claude Code config (`~/.claude` on macOS/Linux,
`C:\Users\<you>\.claude` on Windows):

```sh
cp -r skills/clarion-template ~/.claude/skills/
cp agents/clarion-template-pro.md ~/.claude/agents/
```

Restart Claude Code (or start a new session) so the skill and agent are picked up.

## How to use

- Ask Claude to build/edit a Clarion template and it will pick up the `clarion-template` skill
  automatically (or invoke `/clarion-template`).
- For a focused deep task, delegate to the `clarion-template-pro` agent.

## Verifying a generated template

Claude cannot run AppGen. After it writes a template:
1. Copy the `.tpl` (+ `.tpw`/`.inc`/`.clw`) into the app's template/source path.
2. IDE → **Setup ▸ Template Registry ▸ Register** the `.tpl`.
3. Add the extension/control to a test procedure (or the app, for `APPLICATION` scope).
4. Fill prompts, **Generate**, and confirm the produced `.clw` compiles.
