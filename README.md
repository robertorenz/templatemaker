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
  identifier.tpl                #   Ctrl+Shift+I shows the procedure name
  myFuncs/                      #   global function library (see below)
    myFuncs.tpl                 #     self-contained: prototypes + bodies in one template
  myPie/                        #   pie chart for a window (see below)
    myPie.tpl                   #     global helper + procedure extension
  myFontChanger/                #   global + per-list font picker (see below)
    myFontChanger.tpl
  myBackground/                 #   global default + per-window background color/image (see below)
    myBackground.tpl
  myQR/                         #   QR code into an image control, auto-refresh (see below)
    myQR.tpl
  myGauge/                      #   analog gauge/dial on windows and reports (see below)
    GaugeClass.inc              #     the gauge class (config + method prototypes)
    GaugeClass.clw              #     the implementation (geometry + native drawing)
    myGauge.tpl                 #     global include + window + report extensions
designer/ClarionTplDesigner/    # WPF visual designer for the prompt UI (see below)
installer/                      # builds the installer + a portable single-file exe
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

### `templates/identifier.tpl` — Ctrl+Shift+I shows the procedure name
A global (APPLICATION-scope) ABC extension, no per-procedure setup. It alerts **Ctrl+Shift+I** on every
windowed procedure; pressing it pops a message box with the current **procedure name** (baked in at
generation time via `%Procedure`). Same proven injection as the other hotkey templates (self-contained
`CASE EVENT()` at the top of `WindowManager.TakeWindowEvent`). Register it and add **identifier - Show
Procedure Name (Ctrl+Shift+I)** under Global → Extensions.

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
  depth and background, and define 4–5+ segments (label / relative **value** / **color**). It draws the pie
  plus a **legend** (color swatch + label + **percentage**), redraws automatically on **window resize**, and
  exposes a **`myPieRepaint`** routine — change `myPie:Slices[n]` at run time and `DO myPieRepaint` to
  repaint (percentages recompute automatically).

`PIE` (`builtins.clw:1402`) takes a SIGNED array of relative slice sizes and a LONG array of colors and
draws the whole chart in one call; `SETTARGET(window, ?image)` aims the graphics at the IMAGE control.

Install: register `myPie.tpl`; add **myPie - Global Helper** under Global → Extensions; drop a sized
IMAGE control (e.g. `?PieImage`) on a window; add the **myPie** procedure extension to that procedure,
pick the image, define segments; generate and build.

### `templates/myFontChanger/` — global + per-list font picker
A single global (APPLICATION-scope) ABC extension, no per-procedure setup:
- Applies a **default font** (name + size) to every browse/`LIST` control at window open.
- **Right-click any list** at run time for a popup menu (**Change Font…** → the Windows font dialog, or
  **Reset to Default Font**).
- With a list focused, **Ctrl+Plus / Ctrl+Minus** change its font size up/down by **1 point** and save it.
- Saves each list's choice in **its own INI section** (`[Procedure_Control]`, with Name/Size/Color/Style)
  and re-applies it on reopen — a stored per-list font overrides the global default; reset reverts to it.

It adds two helpers to the program module (`myFontApply`, `myFontChange`) and injects into
`WindowManager.TakeWindowEvent` (apply fonts + arm the right-click on `EVENT:OpenWindow`) and
`TakeFieldEvent` (list events arrive there with `FIELD()` = the list). Uses `SETFONT`, `FONTDIALOG`,
`GETINI`/`PUTINI`, and armed-key alerts (`MouseRightUp` for the menu, `CtrlPlus`/`CtrlMinus` for sizing).
The extension has a **General** tab (default font, size, INI name) and an **Instructions** tab.
Register it, add **myFontChanger - global per-list font picker** under Global → Extensions, set the
default font + INI name, generate and build.

### `templates/myBackground/` — global default + per-window background color / image
A single global (APPLICATION-scope) ABC extension, no per-procedure setup:
- Gives **every window** a **global default background** — a solid **color** and/or an **image** — applied
  automatically at window open.
- Press **Ctrl+Shift+B** on any window for a small chooser: **Background Color…** (color dialog),
  **Background Image…** (file dialog, stretched to fill), or **Use Default** (drop this window's
  personal setting and revert to the global default).
- Saves each window's choice in **its own INI section** (`[Procedure]`, with `Mode`/`Color`/`Image`) and
  re-applies it on reopen — a stored personal background **overrides** the global default.

It adds two helpers to the program module (`myBackApply`, `myBackChoose`) and injects into
`WindowManager.TakeWindowEvent` (apply the background + arm the hotkey on `EVENT:OpenWindow`; pop the
chooser on `EVENT:AlertKey`). At run time a solid color is set with `0{PROP:Color}` and an image with
`0{PROP:WallPaper}` (with `PROP:Tiled`/`PROP:Centered` off so it stretches to fill); uses `COLORDIALOG`,
`FILEDIALOG`, `GETINI`/`PUTINI`, and an armed `Ctrl+Shift+B` alert. The extension has a **General** tab
(default color, default image, INI name, hotkey toggle) and an **Instructions** tab. Register it, add
**myBackground - per-window background color / image** under Global → Extensions, set your defaults +
INI name, generate and build. Full programmer's documentation (prompts, generated code, embed points,
the `myBackApply`/`myBackChoose` helper API, and the runtime properties it uses) is in
[`docs/myBackground-template.html`](docs/myBackground-template.html).

### `templates/myQR/` — QR code into an image control
A self-contained ABC **procedure** extension that renders a **QR code** into an `IMAGE` control on a window.
The QR **value** can be a design-time **literal** (a quoted string) **or any Clarion variable/expression** you
change in code (e.g. `Cus:Email`, `loc:URL`) — it's emitted verbatim, so it's read at run time. With
**auto-refresh** on, a window timer watches the value and reloads the QR whenever it changes; you can also
force a redraw anytime with `DO myQRRefresh`. Prompts: image control, value, size, error-correction (L/M/Q/H),
quiet-zone margin, and the auto-refresh toggle/poll.

Since Clarion has no built-in QR encoder, the PNG is fetched from the free public web service
**`api.qrserver.com`** (goqr.me) and loaded into the image with `feq{PROP:Text}=file`. The download uses
**`curl.exe`** (ships with Windows 10/11), launched **hidden and synchronously** via `CreateProcessA` +
`WaitForSingleObject` (no console flash; the PNG is on disk before the image loads). It's self-contained (a
URL-encoder + a download/load helper in the program module; no external `.inc`/`.clw`). **Privacy/internet
caveat:** the value is sent over HTTPS to that third-party service every render and an internet connection is
required — don't encode secrets, or repoint the helper at your own QR endpoint / a local library for
offline use. Register it, add **myQR - QR code into an image control** to a window procedure's Extensions,
pick a sized IMAGE control, set the value, generate and build. Full programmer's documentation (prompts,
the literal-vs-code value, generated code, the `myQRLoad`/`myQRUrlEncode`/`myQRRefresh` API, the curl/
CreateProcess download, and the privacy caveat) is in [`docs/myQR-template.html`](docs/myQR-template.html).

### `templates/myQRDraw/` — offline QR code drawn with BOX primitives
The **offline** companion to myQR: instead of downloading a PNG, it carries a complete **QR encoder** and
draws every module as a filled `BOX` into an `IMAGE` control — exactly the way myPie draws a pie. **No
internet, no `curl`, no temp files.** A **global** extension adds the encoder + the `QRDraw()` helper (add
once per app); a **procedure** extension wires it to a window, redrawing on open/resize. The value can be a
design-time **literal** or any **Clarion variable/expression** (change it and `DO myQRDrawRepaint`). Prompts:
image control, value, ECC level (L/M/Q/H), dark/light colors, quiet-zone width, and a **self-test** that
draws a fixed `HELLO WORLD` symbol so you can confirm the encoder works by scanning it.

**Reports** render bands through the print engine, not window events, so a separate **myQRDrawReport**
extension handles them: drop an IMAGE control in the detail band, add the extension, and a code is drawn
**per record** in the *Before-Print-Detail* embed via `SETTARGET(Report)` (the window extension and the
report extension share the same encoder and `QRPaint()` drawing — only the draw target and timing differ).

The encoder (byte mode, **versions 1–10**, automatic version + mask) is a line-for-line port of the
ZXing-validated C# reference in [`designer/QrCodeCore/`](designer/QrCodeCore/); its exact `HELLO WORLD`/ECC-M
matrix is pinned by a golden test, and that is the same symbol the self-test draws. The encoder ships as a
self-contained Clarion **class** — `QRCodeClass.inc` + `QRCodeClass.clw` (stored in **ANSI**) — so it compiles
in its own module instead of filling the program's global procedure area; the global extension just
`INCLUDE`s it and declares one `QRCodeObj` instance. Copy the two class files to a folder on the Clarion
redirection path (your app folder or `\clarion12\libsrc\win`). Choose myQRDraw for kiosks, point-of-sale,
field laptops, air-gapped networks, and reports that must render with zero external dependencies; choose myQR
when an internet round-trip is acceptable. Full programmer's documentation is in
[`docs/myQRDraw-template.html`](docs/myQRDraw-template.html).

### `templates/myBarcodeGen/` — nine barcode types, offline, drawn with BOX primitives
A generalization of myQRDraw to **nine symbologies**: the **linear (1D)** codes **Code 39, Code 128**
(auto Code B / Code C), **Interleaved 2 of 5, EAN-13, UPC-A**, and the **2D** codes **QR, Data Matrix,
PDF417, Aztec**. Same offline approach — encode at run time, draw with `BOX`es (1D = full-height bars +
optional human-readable text; 2D = a module/stacked grid). Pick the **Barcode type** from a drop-list; the
rest is like myQRDraw (value literal-or-variable, colors, quiet zone), with **window** and **report**
extensions. Each encoder is a self-contained ANSI Clarion class, ported from the ZXing-validated C# reference
[`designer/BarcodeCore/`](designer/BarcodeCore/) (**42 round-trip tests**): `BarcodeClass` (1D),
`QRCodeClass`, `DataMatrixClass` (ECC200), `Pdf417Class` (GF(929) + a packed pattern table), and `AztecClass`
(variable Galois field, bullseye + spiral). Copy the five encoder classes (ten `.inc`/`.clw` files) to the
Clarion redirection path. Reed–Solomon spans four different fields across the set (GF(256) poly 0x11D/0x12D,
the prime field GF(929), and GF(2^n) for Aztec). Full **developer's manual** (install, the class APIs, per-
symbology rules, drawing model, multi-DLL, troubleshooting) is in
[`docs/myBarcodeGen-template.html`](docs/myBarcodeGen-template.html).

### `templates/myGauge/` — analog gauges/dials on windows and reports
A configurable **analog gauge** drawn entirely with native Clarion graphics (`ARC`, `ELLIPSE`, `LINE`,
`POLYGON`, `SHOW`) into an `IMAGE` control — the same offline, no-dependency approach as myPie and myQRDraw.
A single self-contained ANSI class, **`GaugeClass`**, holds the configuration (range, span, colors, ticks,
zones) and renders itself; each gauge on a window is its **own local object**, so multiple dials per window
or report just work. Pick an **arc style** — 45°, 90°, 180°, 270° (speedometer), 360°, or a **custom** start
+ signed sweep — set the **min/max range**, then drive the needle from a **literal** or any **variable/field**.
Configurable everything: major/minor **ticks** with numeric labels, a digital **value readout**, **title/units**
text, a **triangle or line needle**, face/rim/track/tick/text colors, up to 16 colored **zones** (e.g. green
0–60 / amber 60–85 / red 85–100), and **smooth needle animation** via the window timer (`AnimateTo` +
`AnimStep`). Three extensions: **myGaugeGlobal** (include the class once), **myGauge** for **windows** (redraw
on open/resize, optional animation, a generated `Refresh:<Object>` routine), and **myGaugeReport** for
**reports** (a gauge per record, drawn at `%BeforePrint` under `SETTARGET(Report)`). Copy `GaugeClass.inc` +
`GaugeClass.clw` (ANSI) to the redirection path. Full programmer's documentation — shapes, prompts, the class
API, run-time control, and troubleshooting — is in [`docs/myGauge-template.html`](docs/myGauge-template.html).

## Install

Copy the two folders into your Claude Code config (`~/.claude` on macOS/Linux,
`C:\Users\<you>\.claude` on Windows):

```sh
cp -r skills/clarion-template ~/.claude/skills/
cp agents/clarion-template-pro.md ~/.claude/agents/
```

Restart Claude Code (or start a new session) so the skill and agent are picked up.

## Visual designer & installer

`designer/ClarionTplDesigner/` is a **.NET 9 / WPF** visual designer for a template's *prompt UI*:
open a `.tpl`, see each `#TAB`'s controls at their real `AT()` positions (icons render as the actual
PNGs), then **drag, resize, snap to a grid/guides, re-order, add, delete, and group** controls — and save,
rewriting only the `AT()` values (plus dropping deleted lines and relocating reparented ones). An *Add:*
command bar inserts new Label/String/Number/Spin/Check/Image/Group controls — and a whole new `#TAB`;
in the flow preview you can **drag a tab's header onto another to reorder the tabs** (a caret shows where it
will land), and the whole `#TAB`…`#ENDTAB` block moves with it;
dropping a control into a group box makes it a child (and moving the box carries its contents); guides pull from the rulers and are
removed by dragging them back onto a ruler; deleting a control whose `%symbol` is still referenced
elsewhere pops a warning so you don't break code generation. Selecting a control surfaces its **`%symbol`**
in the Properties pad with a navigable **Uses** list (every place across all files the symbol appears — click
to jump to that line) and a **Rename** button that renames it *everywhere at once* (prompt **+** every
reference) so the field stays joined; newly added controls can be named the same way. Select several
controls and **align / distribute / size them together** (Arrange menu or right-click), or **group them
into a box** (`Ctrl+G`) / **ungroup** (`Ctrl+Shift+G`). Dragging shows **smart alignment guides** that snap
to other controls' edges with a live spacing readout. An **Outline** panel shows the whole
`#SHEET`/`#TAB`/`#BOXED`/control tree with a find box; a **Symbols** panel lists every `%symbol` with its
use count and click-to-jump; a tab's **`WHERE(...)` visibility condition** is editable from its right-click
menu; a **Problems** panel flags
unbalanced blocks, duplicate/unused symbols, off-canvas or overlapping controls and risky auto-built
prompts (click to jump). Added `#PROMPT` controls get a friendly **type / REQ / DEFAULT** editor, and tabs
can be **renamed or deleted** (right-click a tab header). Controls can be **copied/cut/pasted/duplicated**
(`Ctrl+C/X/V/D`, with fresh `%symbols`), **snippets** drop in ready-made groups (Insert ▸ Snippets), and
**File ▸ Preview changes** shows a colour-coded per-file diff of exactly what a save will write. The source
panel has **find/replace** (`Ctrl+F`) and **`%symbol` / `#directive` autocomplete**. A fixed **icon command
bar** (Open, Recent, Save, Preview changes, Undo, Copy/Paste, Check problems, Find, Preview) sits under the
menu, and **recent templates** are remembered (toolbar dropdown and File ▸ Open Recent). The **Help** menu opens a built-in **User Manual**
(press `F1`) and **Programmer's Reference** — beautifully formatted HTML guides bundled into the app
(sources in `docs/`). See `designer/ClarionTplDesigner/README.md`.

**Clarion-accurate prompt fidelity (v2.8).** The canvas now renders prompt text in Clarion's actual
**AppGen Dialogs font**, auto-detected from `ClarionProperties.xml` (Options ▸ IDE ▸ Fonts), and sizes it
to the zoom so what you lay out matches what AppGen draws. A `#PROMPT`'s **label (`PROMPTAT`) and entry
(`AT`) are modelled separately** — drag the entry and the label follows, or drag the label on its own — and
**visibility guides** highlight (in red/amber) any control off the window, spilling outside its group box, or
whose label is too wide for the gap to its entry. **`#BOXED` children auto-get `SECTION`** so box-relative
coordinates land where the designer shows them, and **True layout** mirrors the canvas exactly. The Style
controls cover what AppGen honours per control — **bold / italic / underline / colour** (written as the
correct `PROP:FontStyle` flags + `PROP:FontName`/`PROP:FontColor`) — while the IDE dialog font is shown
**read-only** (Clarion governs the prompt-sheet face). Switching between open documents restores each one's
part **and** tab.

**Reusable prompt groups & UX (v2.9).** A `#SHEET` that pulls in shared prompts with **`#INSERT(%group)`**
now **resolves the `#GROUP(%group)`** (even when it lives in another `#INCLUDE`d file) and lays its prompts
out inline, so you see the complete sheet. Inlined controls are **read-only** (never written back — they
belong to the group's source) and **click-to-navigate** to the host `#INSERT` line. The **template/document
tabs sit above the toolbars** for a cleaner top strip, and **opening a template refreshes** the canvas
immediately.

**Auto-flow accuracy (v2.11).** When controls have no explicit `AT`, the canvas now lays them out the way
AppGen will: a side-label prompt **reserves its label column** (so the label no longer underflows off the
left into the margin), and an `#IMAGE` **reserves its real footprint** (its intrinsic pixel size, scaled to
fit) so following controls flow *below* it instead of being drawn underneath.

**Offline QR codes, on windows *and* reports (v2.12).** New [`templates/myQRDraw/`](templates/myQRDraw/)
draws a QR code with `BOX` primitives — **no internet, no `curl`, no temp files** — from a complete,
self-contained Clarion **encoder** (byte mode, versions 1–10, ECC L/M/Q/H) ported line-for-line from the
ZXing-validated [`designer/QrCodeCore/`](designer/QrCodeCore/) and pinned by a golden-matrix test. It ships
**two extensions**: `myQRDraw` for **windows** (redraw on open/resize) and `myQRDrawReport` for **reports**
(drawn per record in the *Before-Print-Detail* embed via `SETTARGET(Report)` — reports have no window event
loop, and the report control picker lists the report's own controls). The `clarion-template` skill gained
the hard-won lessons behind it (Clarion integer-rounding, `%`-free modulus, window-vs-report drawing).

**myQRDraw as a class + a beta test plan (v2.13).** The encoder moved into a self-contained Clarion **class**,
`QRCodeClass.inc`/`.clw` (stored in **ANSI**), so it compiles in its own module instead of filling the
program's global procedure area — the template just `INCLUDE`s it and declares one `QRCodeObj` instance,
made **multi-DLL aware** (defined in the root DLL, `EXTERNAL` elsewhere, exported — ABC's `%DefaultExternal`
pattern). The class carries a module-level `MAP` (required, else `BUILTINS.CLW` calls like `LEN`/`BOX`/
`SETTARGET` fail), `Construct`/`Destruct`, and `CLIP`s the value so a space-padded fixed-length field no
longer inflates into a giant dense symbol. The `clarion-template` skill captured the whole self-contained-CLASS
recipe. Also new: a multi-sheet **beta test plan** at
[`testing/Clarion-Template-Maker-Beta-Test-Plan.xlsx`](testing/Clarion-Template-Maker-Beta-Test-Plan.xlsx)
(53 test cases + roster + bug log) for handing the toolkit to testers.

**myBarcodeGen — nine barcode symbologies (v2.14).** A new offline barcode template covering the **1D** codes
**Code 39, Code 128** (auto B/C), **Interleaved 2 of 5, EAN-13, UPC-A** and the **2D** codes **QR, Data Matrix,
PDF417, Aztec** — all encoded at run time and drawn with `BOX`es (no internet/curl), on **windows and reports**,
chosen from one drop-list. Five self-contained ANSI Clarion classes (`BarcodeClass`, `QRCodeClass`,
`DataMatrixClass`, `Pdf417Class`, `AztecClass`) port a ZXing-validated C# reference,
[`designer/BarcodeCore/`](designer/BarcodeCore/) with **42 round-trip tests**. Reed–Solomon spans four fields
(GF(256) 0x11D/0x12D, the prime field GF(929), and GF(2ⁿ) for Aztec); PDF417's 3×929 pattern table is packed
into the class. Full developer's manual in
[`docs/myBarcodeGen-template.html`](docs/myBarcodeGen-template.html).

**myGauge — analog gauges on windows and reports (v2.15).** A new [`templates/myGauge/`](templates/myGauge/) draws a
configurable **speedometer-style dial** entirely with native Clarion graphics (`ARC`/`ELLIPSE`/`LINE`/
`POLYGON`/`SHOW`) into an `IMAGE` control — same offline, no-dependency approach as myPie/myQRDraw, but pure
drawing (no encoder, so no C# oracle needed). One self-contained ANSI class, **`GaugeClass`** (`.inc`/`.clw`),
holds the configuration and renders itself; each gauge is a **local object**, so multiple dials per window/report
just work. Arc **styles** 45°/90°/180°/270°/360° or **custom** start + signed sweep; min/max **range** driven by
a literal or any **field**; major/minor **ticks** + labels, a **value readout**, **title/units**, a triangle or
line **needle**, full **color** control, up to 16 colored **zones**, and **smooth animation** via the window
timer (`AnimateTo` + `AnimStep`). Three extensions — **myGaugeGlobal** (include once), **myGauge** for windows
(redraw on open/resize, optional animation, a generated `Refresh:<Object>` routine) and **myGaugeReport** for
reports (per record at `%BeforePrint` under `SETTARGET(Report)`). The geometry keeps angles un-normalized to
avoid the 0/360 wrap and maps screen-Y downward (`cy − r·sin θ`). Two compile fixes shipped after first
field use: the internal `Band` helper was renamed **`ArcBand`** (`BAND` is the Clarion report-band reserved
word), and the window event handler moved to **`PRIORITY(2000)`** so its self-contained `CASE EVENT()` sits
above ABC's own `TakeWindowEvent` scaffolding (2500) instead of duplicating it — a lesson now baked into the
`clarion-template` skill. Full programmer's manual in [`docs/myGauge-template.html`](docs/myGauge-template.html).

To package everything (designer **+** templates **+** skill **+** agent) into one deliverable — .NET is
bundled in, so nothing needs pre-installing on the target:

```powershell
pwsh installer\build-installer.ps1   # -> installer\Output\ClarionTemplateToolsSetup.exe (full installer)
pwsh installer\build-portable.ps1    # -> run\ClarionTemplateDesigner.exe (portable single-file exe)
```

See `installer/README.md` for what each option installs.

### QR encoder core (`designer/QrCodeCore/`)

`designer/QrCodeCore/` is a small, dependency-free **.NET 9** QR-code encoder (versions 1–10, all four
error-correction levels) written as the portable reference for the *offline* [`templates/myQRDraw/`](templates/myQRDraw/)
template, which draws the symbol module-by-module with `BOX` primitives — the same approach as `myPie/` — so no
internet round-trip is needed (unlike `templates/myQR/`, which fetches a PNG via `curl`). The encoder is developed test-first:
`designer/QrCodeCore.Tests/` round-trips every encode through an independent decoder (ZXing.Net) across all
versions and ECC levels and pins the Reed–Solomon stage to the ISO/IEC 18004 worked example. Run the tests
with `dotnet test designer/QrCodeCore.Tests`.

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

## Beta testing

A ready-to-use **beta test plan** for the whole toolkit lives in
[`testing/Clarion-Template-Maker-Beta-Test-Plan.xlsx`](testing/Clarion-Template-Maker-Beta-Test-Plan.xlsx) —
a multi-sheet workbook (Read Me, Beta Testers roster, 53 **Test Cases** with Pass/Fail/Severity drop-downs and
colour coding, a Bug Log, and an auto-tallying Summary) covering install, the visual designer, every shipped
template, and the QR self-tests. Hand it to testers as their script. Regenerate or extend it with
`python testing/build_beta_test_plan.py` (requires `openpyxl`).

## License

Released under the [MIT License](LICENSE) — © 2026 Reddin Assessments. Free to use, modify, and
distribute; provided "as is" without warranty.
