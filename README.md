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
  myImage/                     #   12 image formats in, 9 out, every colour format (see below)
  allImageRead/                 #   any picture, from anywhere, on a window or a report (see below)
    allImageRead.tpl            #     global + drag-on canvas + window/report extensions + code template
    d2dcanvas.c                 #     the GPU canvas: Direct2D, bound at run time, no import library
  myGauge/                      #   analog gauge/dial on windows and reports (see below)
    GaugeClass.inc              #     the gauge class (config + method prototypes)
    GaugeClass.clw              #     the implementation (geometry + native drawing)
    myGauge.tpl                 #     global include + window + report extensions
  graficaBarra/                 #   13 chart types on windows and reports, vector on PDF (see below)
    GraficaBarraClass.inc       #     the bar-graph class (config + method prototypes)
    GraficaBarraClass.clw       #     the implementation (scale + BOX/LINE/SHOW drawing)
    graficaBarra.tpl            #     global include + window + report extensions
    graficaBarra.zip            #     the three files above, zipped for easy distribution
  myGaugePlus/                  #   ANTIALIASED (GDI+) gauge/dial on windows (see below)
    gpcanvas.c                  #     GDI+ flat-API shim (bound at runtime, compiled by Clacpp)
    AaCanvasClass.inc/.clw      #     reusable antialiased 2D canvas over GDI+
    GaugePlusClass.inc/.clw     #     the pretty gauge, drawn on the canvas
    myGaugePlus.tpl             #     global include + window + control template
  myCompress/                   #   pure-Clarion compression: DEFLATE/zlib/gzip (see below)
    CompressClass.inc           #     the codec class (config + method prototypes)
    CompressClass.clw           #     the implementation (inflate/deflate/containers)
    CompressClassC.inc          #     optional C-backed subclass (the fast engine)
    CompressClassC.clw          #     overrides Wrap/Unwrap to call mc.c
    mc.c                        #     our own DEFLATE in C (compiled by Clarion's Clacpp)
    myCompress.tpl              #     one global extension (engine prompt: Clarion / C)
  myPdfSign/                    #   pure-Clarion signed-PDF reader: who signed it (see below)
    PdfSignClass.inc            #     the reader class (config + method prototypes)
    PdfSignClass.clw            #     the implementation (PDF parse + PKCS#7/DER walk)
    myPdfSign.tpl               #     one global extension (the shared object)
  myCalc/                       #   pop-up calculator beside a numeric field (see below)
    CalcClass.inc               #     the calculator (4 modes, tape, EN/ES strings)
    CalcClass.clw               #     the implementation (keypad, arithmetic, window)
    calc16.ico                  #     the little calculator on the button
    myCalc.tpl                  #     global extension + button control + code template
    myCalc.zip                  #     the four files above, zipped for easy distribution
  myFilter/                     #   build filters for any browse (see below)
    MyFilterClass.inc           #     the filter builder (fields, operators, EN/ES)
    MyFilterClass.clw           #     the implementation (expressions + the window)
    myFilter.tpl                #     global extension + browse button + code template
    FilterTables.txt            #     table structures, if saved filters are shared
  myCalendar/                   #   pop-up date picker beside a date field (see below)
    MyCalendarClass.inc         #     the calendar (views, range, EN/ES strings)
    MyCalendarClass.clw         #     the implementation (date maths, drawing, window)
    cal16.ico                   #     the little calendar on the button
    myCalendar.tpl              #     global extension + button control + code template
    myCalendar.zip              #     the four files above, zipped for easy distribution
  myExport/                     #   export any browse/list to 7 file formats (see below)
    ExportClass.inc             #     the export engine (config + method prototypes)
    ExportClass.clw             #     the implementation (dialog + 7 writers + ZIP + UTF-8)
    ExportClass.exp             #     export list, for a hand-coded multi-DLL build only
    myExport.tpl                #     global extension + Export-button control + code template
    myExport.zip                #     the four files above, zipped for easy distribution
  myHook/                       #   intercept MESSAGE / STOP / HALT / errors (see below)
    MsgHookClass.inc            #     the interceptor (rules, log, the seven RTL hooks)
    MsgHookClass.clw            #     the implementation (hook thunks + append-only logger)
    myHook.tpl                  #     global extension + per-procedure pause + code template
    myHook.zip                  #     the three files above, zipped for easy distribution
  BrowseGrid/                   #   take over any ABC browse and draw it with Direct2D (see below)
    BrowseGrid.tpl              #     the extension: one prompt sheet, no class to ship
    d2grid.c                    #     the grid: Direct2D + DirectWrite, bound at run time
  BrowseGridLeg/                #   the same grid for the Legacy (CW20) chain (see below)
    BrowseGridLeg.tpl           #     global + procedure extensions, search box, filter bar
    d2gridleg.c                 #     the grid, plus filter buttons and drag-reorder
    README.md                   #     what the port adds over the ABC original
  SDAspecto/                    #   one look for every window: rules, type, rescaling
                                #     (see below)
    SDAspecto.inc               #     the class: rule queue, per-window state, prototypes
    SDAspecto.clw               #     the engine: matching, painting, rescaling, the INI
    SDAspecto.tpl               #     the chain file
    SDAspecto.tpw               #     1 app extension + 2 procedure extensions
    VentanaConfigAspecto.txa    #     a ready-made settings window to IMPORT (optional)
  weatherWidget/                #   a weather card when your program starts (see below)
    MyWeatherClass.inc          #     the widget (settings, the reading, EN/ES strings)
    MyWeatherClass.clw          #     the implementation (curl + JSON + the drawn card)
    weatherWidget.tpl           #     global extension + code template
    weatherWidget.zip           #     the three files above, zipped for easy distribution
  emailTo/                      #   send e-mail and manage the account: SMTP/TLS, OAuth2,
                                #     nine provider APIs (see below)
    EmailNetClass.inc/.clw      #     transport: sockets, TLS, HTTPS, DPAPI (wraps emailc.c)
    EmailMsgClass.inc/.clw      #     the message: MIME, base64, quoted-printable, UTF-8
    EmailToClass.inc/.clw       #     the sender: accounts, SMTP, OAuth2, REST, the windows
    EmailJsonClass.inc/.clw     #     reading the reply: a JSON parser in pure Clarion
    EmailApiClass.inc/.clw      #     the management API: blocked, stats, campaigns, the window
    emailc.c                    #     Winsock + SCHANNEL + WinHTTP + SHA-256 (Clacpp-compiled)
    emailTo.tpl                 #     3 app extensions + 3 buttons + 4 code templates
    emailTo10.tpl               #     the same, prompts re-laid out for Clarion 10's
                                #       480 px AppGen dialog - GENERATED, do not edit
    Build-NarrowTpl.ps1         #     generates it, and fails if anything stops fitting
    EmailTables.txt             #     the settings-table structure, written out by hand
    emailToTables.dctx          #     the dictionary to IMPORT: 7 tables (Dictionary
                                #       Editor > File > Import > DCTX/XML)
    emailToTables.dct           #     the same, prebuilt, if you would rather copy tables across
    emailToTables.txd           #     Report Writer's format - for ClarionCL /di only
    emailTo.zip                 #     all of the above, zipped for easy distribution
designer/ClarionTplDesigner/    # WPF visual designer for the prompt UI (see below)
installer/                      # builds the installer + a portable single-file exe
  emailTo/                      #   and a stand-alone one for emailTo alone, Clarion 10+
README.md
```

## Included templates

**Jump to a template.** 29 of them; each links to its own section below.

| | |
|---|---|
| **Mail** | [**emailTo**](#t-emailto) &nbsp;<sub>send e-mail, and manage the account: SMTP/TLS, OAuth2 and nine provider APIs</sub> |
| **Charts & gauges** | [**graficaBarra**](#t-graficabarra) &nbsp;<sub>thirteen chart types on windows and reports (vector on PDF)</sub><br>[**myPie**](#t-mypie) &nbsp;<sub>pie chart on a window</sub><br>[**myGauge**](#t-mygauge) &nbsp;<sub>analog gauges/dials on windows and reports</sub><br>[**myGaugePlus**](#t-mygaugeplus) &nbsp;<sub>antialiased (GDI+) gauges/dials on windows</sub> |
| **Images & codes** | [**myImage**](#t-myimage) &nbsp;<sub>twelve image formats in, nine out, every colour format</sub><br>[**allImageRead**](#t-allimageread) &nbsp;<sub>any picture, from anywhere, on a window or a report</sub><br>[**myQR**](#t-myqr) &nbsp;<sub>QR code into an image control</sub><br>[**myQRDraw**](#t-myqrdraw) &nbsp;<sub>offline QR code drawn with BOX primitives</sub><br>[**myBarcodeGen**](#t-mybarcodegen) &nbsp;<sub>nine barcode types, offline, drawn with BOX primitives</sub> |
| **Browses & lists** | [**BrowseGrid**](#t-browsegrid) &nbsp;<sub>take over any ABC browse and draw it with Direct2D</sub><br>[**BrowseGridLeg**](#t-browsegridleg) &nbsp;<sub>the same grid for the Legacy (CW20) chain</sub><br>[**myFilter**](#t-myfilter) &nbsp;<sub>build filters for any browse</sub><br>[**myExport**](#t-myexport) &nbsp;<sub>export any browse or list to seven file formats</sub> |
| **Beside a field** | [**myCalc**](#t-mycalc) &nbsp;<sub>a pop-up calculator beside any numeric field</sub><br>[**myCalendar**](#t-mycalendar) &nbsp;<sub>a pop-up date picker beside any date field</sub> |
| **Files & data** | [**myCompress**](#t-mycompress) &nbsp;<sub>pure-Clarion compression (memory + files)</sub><br>[**myPdfSign**](#t-mypdfsign) &nbsp;<sub>read a signed PDF and see who signed it</sub> |
| **Look & feel** | [**SDAspecto**](#t-sdaspecto) &nbsp;<sub>one look for every window: rules, typography and rescaling</sub><br>[**myFontChanger**](#t-myfontchanger) &nbsp;<sub>global + per-list font picker</sub><br>[**myBackground**](#t-mybackground) &nbsp;<sub>global default + per-window background color / image</sub><br>[**weatherWidget**](#t-weatherwidget) &nbsp;<sub>the weather, on a card at start-up</sub><br>[**my3D**](#t-my3d) &nbsp;<sub>real WebGL2 3D scenes driven from Clarion</sub><br>[**myYuru**](#t-myyuru) &nbsp;<sub>yuruyurau animated flow-field art on a window</sub> |
| **Plumbing** | [**myFuncs**](#t-myfuncs) &nbsp;<sub>global function library</sub><br>[**myHook**](#t-myhook) &nbsp;<sub>intercept MESSAGE, STOP, HALT and run-time errors</sub> |
| **Diagnostics** | [**myPixel**](#t-mypixel) &nbsp;<sub>per-window diagnostic pixel</sub><br>[**showLine**](#t-showline) &nbsp;<sub>Ctrl+Shift+P "where am I" hotkey</sub><br>[**identifier**](#t-identifier) &nbsp;<sub>Ctrl+Shift+I shows the procedure name</sub> |

<a id="t-mypixel"></a>
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

<a id="t-showline"></a>
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

<a id="t-identifier"></a>
### `templates/identifier.tpl` — Ctrl+Shift+I shows the procedure name
A global (APPLICATION-scope) ABC extension, no per-procedure setup. It alerts **Ctrl+Shift+I** on every
windowed procedure; pressing it pops a message box with the current **procedure name** (baked in at
generation time via `%Procedure`). Same proven injection as the other hotkey templates (self-contained
`CASE EVENT()` at the top of `WindowManager.TakeWindowEvent`). Register it and add **identifier - Show
Procedure Name (Ctrl+Shift+I)** under Global → Extensions.

<a id="t-myfuncs"></a>
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

<a id="t-mypie"></a>
### `templates/myPie/` — pie chart on a window
Renders a pie chart into an IMAGE control using Clarion's built-in `PIE` graphics primitive (no external
files). **Easiest path: a control template** — drag **myPie - Pie Chart** straight onto a window and it
drops the IMAGE *and* wires the pie + legend in one go, fully self-contained (no global/procedure extension
needed). Drop several on one window. Or use the two-extension route for an existing IMAGE control. Four
registrations in all:
- **`myPieControl`** (CONTROL) — the drag-on pie. Set the 3D depth, background, legend/percentages, and the
  segments (label / relative **value** / **color**); each control owns its own data (keyed off its **Image
  control**, so there are no names to keep in sync) and redraws on open/resize. The segments **seed a runtime
  `QUEUE`** (`<Image>:Q`, fields `QLabel`/`QValue`/`QColor`) — so the slice count is **unbounded** at run
  time, not fixed at generation. The redraw rebuilds the `PIE()` arrays (fixed `DIM(64)` buffers; a 0-value
  slice is an invisible 0° wedge) and walks the queue for the legend. Depth / legend / percentages are
  **run-time variables** so a panel can change them live.
- **`myPiePanel`** (CONTROL, **MULTI**) — a drag-on **live control panel**: a 3D-depth field, show-legend and
  show-percentages **toggle buttons**, and an **editable slice list with Add / Edit / Delete**. Link it by
  **picking the pie's Image control** (a drop-list — no typed names). The list shows every slice; **Add**,
  **Edit** (or **double-click** a row), and **Delete** edit them through a small **modal popup** (Label /
  Value / **Color** via the color dialog) — so you are no longer capped at a handful of slices. Every change
  repaints the pie **live**. **Drop one panel per pie** on the same window — it's multi-instance: the on-window
  controls are field-equates (auto-uniqued, captured in `#ATSTART`) and the per-instance data (the modal +
  its fields) is keyed by `%ActiveTemplateInstance`, so panels never collide. (Editing is plain queue + modal
  Clarion — no `QEIPManager`/EIP classes, which proved unstable as a standalone in-cell editor.)
- **`myPieGlobal`** (APPLICATION) — adds the global helper `myPieDraw(window, imageFeq, slices[], colors[],
  …)` to the program module. Add once, globally (only needed for the procedure-extension route).
- **`myPie`** (PROCEDURE) — drop on a window procedure; pick a sized **IMAGE control**, set 3D depth /
  background, and define the segments. Draws the pie plus a **legend** (swatch + label + **percentage**),
  redraws on **resize**, and exposes a **`myPieRepaint`** routine.

`PIE` (`builtins.clw:1402`) takes a SIGNED array of relative slice sizes and a LONG array of colors and
draws the whole chart in one call. The drawing uses **`SETTARGET(window, ?image)`** so the IMAGE itself is
the target (origin `0,0`, the graphics belong to the control and survive a repaint/resize, and a `BLANK`
clears only that image) — the same model as myGauge, so multiple pies never erase each other.

Install: register `myPie.tpl`, then either drop **myPie - Pie Chart** from the control toolbox, or add
**myPie - Global Helper** (Global → Extensions) + the **myPie** procedure extension on a window. **Upgrade
note:** the `myPieDraw` helper gained a leading `WINDOW` parameter, so **regenerate** any app built against
the older one (a stale call shows as "No matching prototype available").

<a id="t-myfontchanger"></a>
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

<a id="t-mybackground"></a>
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

<a id="t-myqr"></a>
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

<a id="t-myqrdraw"></a>
### `templates/myQRDraw/` — offline QR code drawn with BOX primitives
The **offline** companion to myQR: instead of downloading a PNG, it carries a complete **QR encoder** and
draws every module as a filled `BOX` into an `IMAGE` control — exactly the way myPie draws a pie. **No
internet, no `curl`, no temp files.** The window `Draw` renders in **pixel units** (`0{PROP:Pixels}`), so
adjacent module boxes abut on exact pixel boundaries — no dialog-unit rounding leaves thin white seams
between modules (and it stays crisp across repaints; the report path keeps report units). The window
`Draw` targets the image with the **two-argument `SETTARGET(Window, ?Image)`**, so its `BLANK` is clipped to
the image rectangle and the modules paint from a `0,0` origin — several QR codes on one window no longer erase
each other, and `Draw` also accepts a plain `STRING` value, not only a `CSTRING`. A **global** extension adds the encoder + the `QRDraw()` helper (add
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

<a id="t-mybarcodegen"></a>
### `templates/myBarcodeGen/` — nine barcode types, offline, drawn with BOX primitives
A generalization of myQRDraw to **nine symbologies**: the **linear (1D)** codes **Code 39, Code 128**
(auto Code B / Code C), **Interleaved 2 of 5, EAN-13, UPC-A**, and the **2D** codes **QR, Data Matrix,
PDF417, Aztec**. Same offline approach — encode at run time, draw with `BOX`es (1D = full-height bars +
optional human-readable text; 2D = a module/stacked grid). As in myQRDraw, every window `Draw` renders in
**pixel units** (`0{PROP:Pixels}`) so modules/bars abut on exact pixel boundaries — no dialog-unit rounding
leaves thin white seams (the report path keeps report units). Pick the **Barcode type** from a drop-list; the
rest is like myQRDraw (value literal-or-variable, colors, quiet zone), with **window** and **report**
extensions. Each encoder is a self-contained ANSI Clarion class, ported from the ZXing-validated C# reference
[`designer/BarcodeCore/`](designer/BarcodeCore/) (**42 round-trip tests**): `BarcodeClass` (1D),
`QRCodeClass`, `DataMatrixClass` (ECC200), `Pdf417Class` (GF(929) + a packed pattern table), and `AztecClass`
(variable Galois field, bullseye + spiral). Copy the five encoder classes (ten `.inc`/`.clw` files) to the
Clarion redirection path. Reed–Solomon spans four different fields across the set (GF(256) poly 0x11D/0x12D,
the prime field GF(929), and GF(2^n) for Aztec). Full **developer's manual** (install, the class APIs, per-
symbology rules, drawing model, multi-DLL, troubleshooting) is in
[`docs/myBarcodeGen-template.html`](docs/myBarcodeGen-template.html).

<a id="t-myimage"></a>
### `templates/myImage/` — **twelve image formats in, nine out**, every colour format
Read **BMP, GIF, JPEG, PNG, TIFF, ICO, EMF, WMF, TGA, PCX, PNM and QOI**; write **BMP, GIF, JPEG, PNG,
TIFF, TGA, PCX, PNM and QOI**. Convert between **every colour format** — 32-bit ARGB, 24-bit RGB,
16-bit 5-6-5, 15-bit 5-5-5, 256 and 16 colours (median-cut palette, optional Floyd–Steinberg dither),
256 / 16 / 4 greys, 1-bit black & white and the web-safe 216. Transform on the way through: rotate
90/180/270 or **any angle**, mirror, flip, crop, extend the canvas, resize (nearest / bilinear /
area-average) and fit — stretch, proportional, cover, centred, contain. Adjust brightness, contrast,
saturation, gamma, levels, blur, sharpen, invert, sepia, posterise, alpha flatten, opacity; read a luma
histogram and the generated palette.

![the myImage demo](docs/myImage-demo.png)

**It is fast because the pixel work is C.** `imgcore.c` is compiled straight into your exe by Clarion's
own C compiler (`PRAGMA('compile(imgcore.c)')`) — there is no DLL to ship and nothing to install. The
formats Windows already owns are decoded through **GDI+** (part of Windows, bound at run time, so no
import library either); everything else — the TGA/PCX/PNM/QOI/BMP codecs, the quantiser, the dithering,
every resample and every adjustment — is plain C in that one file. The engine deliberately uses **no C
runtime and no libm**: memory comes from `LocalAlloc`, files from `CreateFileA`, and anything needing
`sin`/`cos`/`pow` is worked out on the Clarion side and handed over (free rotation takes a cosine and a
sine; gamma and levels arrive as a 256-entry lookup table). That is why it compiles with Clacpp
everywhere, unchanged.

Every colour format, converted from the built-in test card — note the dithering doing its work at 16
colours and at 1 bit, and the banding you would expect at 16- and 15-bit:

![every colour format](docs/myImage-colormodes.png)

**Two drop-on controls, if you would rather not touch the extension at all.** Drop **myImage - Image view**
on a window and you have a working image; drop **myImage - Image tools panel** beside it, point it at the
view's IMAGE control, and you get open / save / turn / mirror / flip / zoom / fit / reset, a colour-format
list and the effects — wired up, with nothing to type on both sides:

![the image view and tools control templates](docs/myImage-controls.png)

The two find each other through the view's **IMAGE control field equate** — the view names everything it
declares after it, and the panel derives the same names from the same control. Nothing to keep in step, and
several views on one window never collide. (Picking that control on the panel is required: it is the one
thing the panel cannot work out for itself, so leaving it blank stops generation with a message saying so.) The view keeps a **master** copy and a **working** copy, so
switching 256 colours → black & white → back to 24-bit costs nothing: each conversion starts again from the
master instead of eating into what is left.

Five registrations: **myImageGlobal** (include the class once), **myImageView** + **myImageTools** (the two
control templates above), **myImage** (a procedure extension —
an image object bound to an `IMAGE` control, with generated `Refresh:` and `Show:` routines, and prompts
for the whole recipe: load, rotate, resize, adjust, convert, save), and **myImageConvert** (a *code*
template — drop it in any embed to convert one file into another format, colour format and size in a
single statement). All of it is also just a class, so you can drive it from code:

```clarion
IF Pic.LoadFile('holiday.jpg')
  Pic.Fit(1024, 768, Img:Contain)      ! keep the ratio, no padding
  Pic.Convert(Img:Pal256, 1)           ! 256 colours, dithered
  Pic.SaveFile('holiday.gif')          ! or .png .bmp .tif .tga .pcx .ppm .qoi
  Pic.Draw(MyWindow, ?Preview)         ! and show it, fitted to the control
END
```

Copy `ImageClass.inc` + `ImageClass.clw` + `imgcore.c` to the redirection path —
[`myImage.zip`](templates/myImage/myImage.zip) bundles all four files. Full bilingual (English +
Spanish) documentation — prompts, the class API, every format and colour format, how the engine is put
together, and troubleshooting — is in
[`docs/myImage-template.html`](docs/myImage-template.html). `examples/myImage/` has
**ImageDemo** (open anything, push it through every conversion and transform, watch the histogram and
palette update, save it back out) and **ImgTest**, a headless harness that round-trips all nine writable
formats and all eleven colour formats and writes the results to an INI.

<a id="t-allimageread"></a>
### `templates/allImageRead/` — **any picture, from anywhere**, on a window or a report
myImage is the engine; **allImageRead is the piece that puts a picture in front of the user**. One `.tpl`,
no new class — it sits on top of `ImageClass` and answers the two questions a template cannot: *where does
the picture come from*, and *what does it get painted on*. **Six sources**: a fixed file, a variable holding
a path, a **BLOB field**, a **STRING in memory**, a **base64 string** (`data:` URIs and the URL-safe
alphabet included), or an **http/https URL**. Anything that is not already a file is written to a working
file in `%TEMP%` — with the Windows file API, so the application is not obliged to carry the DOS driver
just to show a photograph — and read back from there; the names are fixed per canvas, so they are reused
rather than piled up. A URL is fetched with **curl.exe**, which ships with Windows 10 and 11 in System32,
run hidden and synchronously. The base64 decoder is pure Clarion, table-driven, and skips whitespace.
**The canvas.** On a window the `IMAGE` control is only the paint surface: the object owns the pixels and a
**REGION created over the image at run time** takes the mouse — the way Clarion's own `ActiveImage` class
does it (`libsrc\win\ActiveImage.clw:303`). So zooming does not stretch a control, it **re-renders** the
picture through the engine; panning moves the **viewport**, not the frame. The user gets **Ctrl + wheel
zoom** (about the centre of the view, and zooming all the way out lands back on "fit"; Ctrl is a prompt, so
the wheel can zoom on its own where nothing else wants it), **drag to pan**, a
**right-click menu** built at generate time out of the boxes you ticked (so its item numbers can never drift),
**double-click to open another picture**, **drag a file onto it from Explorer** (`DROPID('~FILE')`), and
**Save a copy** in any of the nine formats the engine writes. **Panning** is a left-button drag, or
**Ctrl+arrows** (with **Ctrl+Home** to refit) for anyone who would rather not hold the mouse down — both
are quiet while the picture is fitted, because there is nowhere to pan to. Optional status-bar line and tooltip.
**Easiest path: one control template that goes in both places.** Drag **allImageRead - Image canvas** onto a
**window** *or* into a **report band** — `#ATSTART` works out where it landed (`%ReportControl` first, then
`%Control`) and emits the right half: the live viewer on a window, or, in a band, a picture per record
fitted to a PNG and pointed at with `PROP:Text` under `SETTARGET(Report)`. Report working names **rotate**
(8 by default) so a page still being spooled cannot have its picture overwritten underneath it. Five
registrations: **allImageReadCanvas** (the drag-on canvas, window *or* report band), **allImageReadGlobal**
(the shared readers — add it once per application, and to **every** app of a multi-DLL set that carries a
canvas), **allImageRead** and **allImageReadRpt** for an `IMAGE` control you already have on a window or in
a band, and the **allImageReadLoad** code template for one statement at any embed. Per-picture touch-up
(rotate/mirror/flip/greyscale/cap the longest side) is a prompt, not an embed. **Pictures that hold more
than one frame** — a multi-page TIFF, an animated GIF — get the **allImageReadFrames** control template:
drag the bar onto the window, tell it which canvas object it drives, and it gives First / Prev / Next /
Last, a *Page 3 of 12* counter, and a **Play** button that animates on the window timer and puts the
timer back when it stops. It hides itself when the picture has only one frame. Requires the myImage files on the redirection path
(`ImageClass.inc`, `ImageClass.clw`, `imgcore.c`, ANSI) — myImage itself need not be registered.
**The wheel is not a Clarion event.** `EVENT:ScrollUp`/`ScrollDown` are LIST events ("the user pressed the
up arrow", `IMM` only) and never reach a window or an `IMAGE`, so the canvas takes the wheel off the
**window procedure** (`PROP:WndProc`) and turns `WM_MOUSEWHEEL` into an event the `ACCEPT` loop understands
— reading the distance and the Ctrl flag straight out of the message, the way Clarion's own
`smartzoom.clw` does. The window's original procedure is parked **on the window** with `SetProp`, so one
callback serves every window in the program with no bookkeeping; the first canvas on a window hooks it, the
last one puts it back, and each canvas zooms only when the pointer is over *it*.
**Zooming runs on the graphics card.** Resampling a whole picture for every wheel notch is what makes a
CPU viewer crawl — at 400% on a 12-megapixel photo that is 768 MB of work to fill a 600x400 frame, plus a
PNG round trip through disk. `d2dcanvas.c` hands the picture to **Direct2D** once; every zoom and pan after
that is a 3x2 matrix. Measured on a 2400x1800 photograph: **8.4 ms a frame against 675 ms a step, about
80x** — and the GPU figure does not move when the picture gets bigger. It works because a REGION created at
run time owns a **real HWND**, so Direct2D renders into the canvas control itself and never fights Clarion
for the window's `WM_PAINT`. `d2d1.dll` is bound with `LoadLibrary`, so there is no import library to link
and nothing to redistribute; a canvas that cannot get Direct2D falls back to the processor on its own, and
each canvas can be pinned to either engine on its Canvas tab. Report bands always use the processor — a
printer is not a window. **The processor path is no longer a cliff to fall off**: it crops the
source rectangle out before scaling, so its work depends on the size of the frame rather than the size
of the picture - measured at 8.9 seconds a zoom step before, 53 milliseconds after, showing pixel-for-
pixel the same view. Requires `d2dcanvas.c` on the redirection path beside the myImage files.
Verified end to end: registers, generates for all four placements, the generated source **compiles and
links** (a window app and a report, 32-bit MSBuild), and three things are **proved at run time** rather
than argued — the wheel (a harness sends real `WM_MOUSEWHEEL` messages and reads the counters back out of
the window title), the GPU canvas (it draws the test card into a run-time REGION, screenshot in
[`docs/allImageRead-d2dcanvas.png`](docs/allImageRead-d2dcanvas.png)), and the 80x figure above. See
[`examples/allImageRead/`](examples/allImageRead/).

<a id="t-browsegrid"></a>
### `templates/BrowseGrid/` — **take over any ABC browse** and draw it with Direct2D
A browse that does not look like 1995, **without touching the browse**. Drop the extension on a procedure,
point it at the `LIST`, and the grid draws the rows instead: antialiased text through DirectWrite, banded
rows, frozen columns, a header that sorts, and column widths you can drag. The `BrowseBox` keeps doing all
the work it always did — the VIEW, the queue, the locator, range limits, the popup, Insert/Change/Delete —
so **nothing about the browse's behaviour changes**, only what you look at. One `.tpl` plus `d2grid.c`,
which Clarion's own C compiler builds; no DLL, no OCX, nothing to redistribute. A procedure that cannot get
Direct2D leaves the `LIST` alone and carries on.
**How it takes over.** A `REGION` is created over the `LIST` at run time and the grid is attached to it. The
`LIST` is then made invisible **to Windows** — `WS_VISIBLE` stripped off the HWND — and *not* to Clarion:
`HIDE()` makes ABC decide it has no rows to load, but `PROP:Hide`, the queue and the visible-row count are
all untouched by clearing the style bit, so the browse goes on filling itself while Windows simply never
paints it. It also keeps the focus, which is what makes every key an ABC browse has always answered go on
working unwritten — arrows, PageUp/PageDown, Ctrl-PageUp/PageDown, the incremental locator, Insert, Delete,
Enter. The region only ever needed the mouse, and a `REGION` with `PROP:IMM` gets that with or without focus.
**Grouped and multi-line formats.** A browse whose format puts several fields on each record over more than
one line, under headings that span them, is read back out of the `LIST` — `PROPLIST:GroupNo`,
`PROPLIST:LastOnLine`, and `PROPLIST:Group` added to any other property for the group's own heading and
width — and drawn either way: **flattened** to one column per field on a single line, or **faithfully**, with
the spanning headings, the record as many lines tall as the format makes it, and the banding and selection
covering the whole record. Freezing then counts groups, and dragging a group edge scales the fields inside
it while every group to its right shifts along.
**Excel's drop-down on every heading.** A boxed glyph at the right of each heading — `˅` for a menu, `▲`/`▼`
for the sort direction, a **funnel** on a filled button when the column is filtered (U+E71C out of Windows'
own icon font; if it does not resolve, the fill still says it). The menu sorts either way, filters on the
value under the selection, and offers **Excel's checklist of every value in the column** — read with
`EVALUATE()`, since the field is known only by the name `WHO()` gives back. Filters are **per column and
added together**: filter three columns and all three are in force, all three say so, and each clears on
its own. **Columns…** shows and hides columns (a zero-width LIST column, so the grid needed no new
idea), and **column widths are remembered between runs** through the application's own `INIMgr`
(widths only — a stored filter is an expression, and one that will not parse is a run-time error at
window open, which is not a thing to keep in a settings file). Sorting goes through the browse exactly as a heading click does, and filtering
calls the browse object's own `SetFilter`, so range limits and locators keep working. The field name for the
filter is read at run time with **`WHO()`** — an ABC browse queue labels its fields with the file fields they
came from, so `WHO(Queue:Browse:1,n)` answers `STU:LastName` and nothing has to be mapped by hand.
**The rest of it.** Scrollbars come in three styles — **Windows**, **Slim** (both drawn, thin and flat)
and **Overlay** (drawn over the rows, only while the pointer is on the grid, so the data keeps the whole
width). Sideways is Windows' own in the first of those and **tracks live**, because scrolling sideways
needs nothing from the browse and can be done inside Windows' modal drag loop; downwards is **drawn by the
grid**, because moving the browse needs records, records need ABC, and ABC needs `ACCEPT`, which that loop is
holding up. Mouse wheel scrolls, **Ctrl+wheel resizes the type** (6 to 32 point, with the rows and the LIST's
line height following it), long text **wraps** onto up to four lines, and a diagnostics prompt puts what the
grid is working from into the window title, because a browse that draws nothing looks identical whether the
queue was empty, the rows were too tall, or the columns were never read.
**What v1.24 adds.** A **totals row** that sums *every record the browse shows* &mdash; filter and range
included, not the page on screen &mdash; with the columns to total proposed by their picture and corrected
by the user from the Columns dialog. **Find text…**: a string, matched case-insensitively across this
column or every column, numeric columns compared by value. A **check-box column**, drawn rather than
loaded, recognised with no prompt at all from an icon column whose set is the standard
`~BoxOff.ico`/`~BoxOn.ico` pair &mdash; so it scales with the row. **Conditional and fixed colours per
column**, over the BrowseBox's own. **Double-click opens the record**, and a **tooltip** shows a value that
does not fit its column. Typeface, size and the eight colours can each **come from a variable** so a global
theme drives the grid, or from **[SDAspecto](#t-sdaspecto)**, in which case they are read from its global
instance *at run time* &mdash; its prompts are only the factory default and its INI overrides them at
start-up. Texts the end user sees are **English or Spanish**, per application or per grid; the AppGen
prompts stay English either way. The queue and the browse object are now **deduced** rather than typed
(`?Browse:5` → `Queue:5` → `BRW5`), and a wrong guess is a compile error rather than a grid that quietly
fails to filter. Internals: static data down from **3.46 MB to 322 KB**, and the ceilings up to **64
columns** and **16 grids**.

**Auto-fit widths**, on the same menu: it sizes every visible column to the widest of its heading and
its values. The heading counts — a column sized to its values alone truncates its own title, the one
string on screen that never scrolls away. It measures in two passes and they are deliberately not the
same pass: the loaded page is already in memory so **every cell of it is measured exactly**, while past
the page there is no queue to read, only the view — and walking that means `EVALUATE` by field *name*
rather than `WHAT` by field number, because what moves is the record buffer. That is the expensive
call, so out there the longest text is kept **by character count** and only the winner is measured. The
approximation is worth naming: in a proportional font ten `i`s are narrower than four `W`s. **With the
look-ahead at 0 no file is touched.** A hidden column stays hidden, and widths are clamped to 16 and
600 pixels.

The prompts now live on **seven tabs** rather than four — the content had stopped fitting on screen —
split by what things share rather than by size: *Heading menu* holds filtering and auto-fit together
because both hang off the same tick.

**What v1.25 fixes.** The page size counted one row too many whenever the horizontal scrollbar was
showing. `d2g_PageSize` was the only one of the functions that measure the row area which did not take
the bar off it, and the Clarion side sizes the browse through exactly that call &mdash; `BG:Items` asks how
many rows fit and sets the `LIST` line height so ABC loads that many. One too many meant the last record
was loaded, drawn, and then clipped away behind the bar: selectable with the arrow key and impossible to
see. The **Overlay** style was never affected, because that bar floats over the rows and takes no height
from anything.

**What v1.28 fixed.** *Find text* across several columns built a filter that would not parse. The clause
was joined in two steps &mdash; `expr = CLIP(expr) & ' OR '` and then `expr = CLIP(expr) & CLIP(one)` &mdash;
and the second `CLIP` eats the space the first one had just added, so the expression came out as
`...1,1) ORINSTRING(...)`. The evaluator reads that run-together token as one identifier and the view
opens with *BIND has not been called for ORINSTRING (1011)*, filters and ranges ignored. It is built as a
single expression now. Only *In all columns* reproduced it &mdash; with one column there is no `OR` to run
together, which is why the same field of a related table searched fine on its own.

**What v1.36 adds and fixes.** Three fixes first, because they are defects rather than features. The
**selected row landed in the two-pixel sliver**: `BG:Fill` mixed the count of rows that fit *entirely*
with the count it *draws* — one more, painted deliberately so scrolling can be by pixel — and used the
drawing count for the scroll arithmetic, so arrowing past the last whole row put the selection somewhere
it could not be seen. The **grid read thinner than the LIST beside it** with the same typeface
configured, and that was neither contrast nor hinting: `"Roboto Medium"` is a *family* to GDI, which
resolves it to the Medium face, while DirectWrite hands that family its 400-weight member — two
different **faces**, not two renderings. The weight is now read from the last word of the family name.
And **saved column layouts were saved empty**: their loops sat inside the dialog's `ACCEPT`, where a
field equate resolves against *that* window, so `%bgList` read a control of the dialog and wrote nothing
— without erroring.

Then the features. **Settings shared by every browse**: three groups — the heading menu, the look
(Look + Colours + Variables, inherited together because Variables overrides the other two), and the
mouse — set once on the global extension and inherited with one tick each. Column numbers that also get
the click are deliberately excluded: they belong to *that* browse. **Column layouts**, saved under a
name and recalled, storing widths, which columns are visible and which carry a total — no filters (an
expression that will not parse is a run-time error at window open) and no order (the grid does not
reorder). Drivable from an embed (`Grid1:SchName` + `DO BG:SchLoad:Grid1`) and from a **code template**,
for the layout that follows from who opened the window rather than from a button. Plus **GDI text
rendering**, a **font weight** prompt, and each heading-menu option can be switched off individually.

Measured on a real application: a fill costs **under 200 µs** — 1.2 % of a 60 Hz frame — and the generated
code makes **three file accesses**, none of them on the drawing path. The one to know about is *Filter by
value*, which scans the file sequentially in the foreground; it can be taken off the menu from the prompts.
Full programmer's documentation — the four prompt tabs, the heading menu, the hooks your code may need, the
measured limits and the diagnostics — is in
[`docs/BrowseGrid-template.html`](docs/BrowseGrid-template.html).

Requires `d2grid.c` on the redirection path. Verified: registers, generates **with every optional path
switched on** — a generate only covers the prompts that are ticked, which is how a `CODE` without a `DATA`
once shipped — and the generated source compiles and links against a copy of `School`. Behaviour is proved
at run time by harnesses rather than argued: column-edge hit testing (`edgetest`, 15 assertions),
concealment (`novis` — `winvis 1>0 | PROP:Hide 0>0 | recs 20`), group resizing being reversible
(`proptest` — `PROP-PASS was 200,300,160,140 now 200,300,160,140`), and the row-height clamp
(`GridTest grew=33 shrank=19`). See [`examples/BrowseGrid/`](examples/BrowseGrid/).

<a id="t-browsegridleg"></a>
### `templates/BrowseGridLeg/` — the same grid for the **Legacy (CW20)** chain
BrowseGrid ported to the Legacy template family, and grown up on the way. The browse engine underneath is
untouched — file access, sort orders, range limits, locators and the update round-trip stay the generated
Legacy browse's own — while the `LIST` is concealed and the Direct2D grid draws in its place, exactly as the
ABC version does. It attaches with `FAMILY('CW20')`, and it is a `#CONTROL`-free extension suite, because the
Legacy chain has no ABC objects to hang one on.
**What the port adds over the original.** A **file-loaded mode** reads the whole view into the queue once
(5,000 SQLite records in ~10ms), which buys an exact scrollbar thumb, instant in-memory sorts and live
thumb-drag scrolling; page-loaded mode is still there, and the two are split by `#IF(%bglLoad = 'File loaded')`
throughout. A **live search box** narrows the list browser-style as you type, case-blind, with type-to-search
straight from the list. A **criteria filter bar** — a full-width, self-describing button — is driven by
[myFilter](templates/myFilter)'s `MyFilterClass` used unchanged (it is pure Clarion): build conditions per
field, save filters by name, apply them from the button's menu. It applies through `PROP:Filter` on the view,
so it filters on joined files' fields too.
**And the rest.** Excel-style value menus on the headings, case-blind header-click sorting
(decorate–sort–undecorate — the queue `SORT` string form is case-sensitive and the comparison-function form
is a silent no-op), column drag-resize, a right-click column chooser, and **drag-to-reorder** with a ghost
heading chip and an insertion marker — widths, visibility and order all remembered per user in an INI.
Double-click opens the Change form through the browse's own `AlertKey` machinery. **Word wrap gives
variable-height rows**: each row is measured with `CreateTextLayout` + `GetMetrics` and takes only the lines
its own text needs, paging works from a conservative page size while fills push the measured optimum, and the last
screen bottom-anchors at the final record the way a stock browse does.
Needs `d2gridleg.c` on the redirection path, and `MyFilterClass.inc`/`.clw` from
[`templates/myFilter/`](templates/myFilter) if you use the filter bar. Tested against Clarion 12 with the
TopSpeed and SQLite drivers on browses of 5,000 and 10,000 records; the SQLite conversion notes (padded CHAR
storage, the optimistic-concurrency WHERE clause, POSITION drift after a Change, error 37 from CLOSE on a
never-opened view) live as comments at the relevant spots in the template. See
[`templates/BrowseGridLeg/README.md`](templates/BrowseGridLeg/README.md), and
[the Legacy chain reference](skills/clarion-template/reference/legacy-cw20.md) for the porting rules it
demonstrates.

<a id="t-mygauge"></a>
### `templates/myGauge/` — analog gauges/dials on windows and reports
A configurable **analog gauge** drawn entirely with native Clarion graphics (`ARC`, `ELLIPSE`, `LINE`,
`POLYGON`, `SHOW`) into an `IMAGE` control — the same offline, no-dependency approach as myPie and myQRDraw.
A single self-contained ANSI class, **`GaugeClass`**, holds the configuration (range, span, colors, ticks,
zones) and renders itself; each gauge on a window is its **own local object**, so multiple dials per window
or report just work. **Easiest path: a control template** — drag **myGauge - Analog Gauge** straight onto a
window and it drops the IMAGE *and* wires the gauge in one go, fully self-contained (it `INCLUDE`s the class
itself, so no global extension is needed). Pick an **arc style** — 45°, 90°, 180°, 270° (speedometer), 360°,
or a **custom** start + signed sweep — set the **min/max range**, then drive the needle from a **literal** or
any **variable/field**.
Configurable everything: major/minor **ticks** with numeric labels, a digital **value readout**, **title/units**
text, a **triangle or line needle**, face/rim/track/tick/text colors, up to 16 colored **zones** (e.g. green
0–60 / amber 60–85 / red 85–100), and **smooth needle animation** via the window timer (`AnimateTo` +
`AnimStep`). Four registrations: the **myGaugeControl** control template (drag-on, self-contained) plus three
extensions — **myGaugeGlobal** (include the class once), **myGauge** for **windows** (redraw
on open/resize, optional animation, a generated `Refresh:<Object>` routine), and **myGaugeReport** for
**reports** (a gauge per record, drawn at `%BeforePrint` under `SETTARGET(Report)`). Copy `GaugeClass.inc` +
`GaugeClass.clw` (ANSI) to the redirection path. Full programmer's documentation — shapes, prompts, the class
API, run-time control, and troubleshooting — is in [`docs/myGauge-template.html`](docs/myGauge-template.html).

<a id="t-graficabarra"></a>
### `templates/graficaBarra/` — **thirteen chart types** on windows and reports (vector on PDF)
**Column, horizontal Bar, Stacked column, Stacked bar, Stacked percent, Line, Area, Stacked area, Scatter,
Pie, Pie 3D, Donut and Radar** — all drawn with native Clarion primitives (`BOX`, `LINE`, `POLYGON`,
`ELLIPSE`, `PIE`, `SHOW`), no DLL and no encoder, the same offline family as myGauge. One self-contained
ANSI class, **`GraficaBarraClass`**, holds the data (up to 48 categories × 8 series: label, value, color)
and the look, and renders itself; every chart is its **own local object**, so several per window or report
just work. Pick the shape with one property — `Obj.ChartType = Chart:Donut`.

![ChartDemo: pick a type from the list and watch it draw](docs/graficaBarra-demo.png)

Highlights: automatic **"nice" scale** — the gap between two gridlines is sized to the data (1/2/2.5/5/10×10ᵏ)
and the axis runs to the first whole step past it, so a maximum of 113,376,143 gets an axis of 125,000,000
rather than 200,000,000, and **zero always lands on a gridline** — or a fixed `SetRange`; **negative values** hang below
the baseline; **up to 4 series from the prompts** (8 from code) grouped, stacked or stacked-to-100; a
**legend** bottom/top/right that wraps; markers (circle/square/diamond); **smooth** Catmull-Rom lines;
values shown as numbers or **percentages**; category labels that thin themselves out rather than collide;
a 12-color professional palette or explicit colors; optional painted background, plot area and bar/slice
outlines. An empty data list draws **sample data suited to the chart type** — a built-in self-test.

**All thirteen, six to a page.** The `ChartShots` demo paints six charts on one window — `ChartShots 1|2|3`
— which is what the whole family looks like drawn by the same class, from the same data, with nothing but
Clarion primitives. Every shot below is re-taken under v2.1, so the axes are the ones the current scale
picks:

![Column, horizontal bar, stacked column, stacked bar, 100% stacked and line](docs/graficaBarra-types1.png)

*Page 1 — the bar family and the line.* **Column** and **Bar (horizontal)** off the same six values;
**Stacked column** and **Stacked bar** with three series summing into one; **100% stacked**, where the same
three series are re-cast as percentages and the axis is always 0–100; and **Line** with circle markers and
its values called out.

![Area, stacked area, scatter, pie, 3D pie and donut](docs/graficaBarra-types2.png)

*Page 2 — areas and the round ones.* **Area** and **Stacked area** filled with `POLYGON`; **Scatter**, the
line's markers with the line taken away; and **Pie**, **3D pie** and **Donut**, all three on Clarion's own
`PIE` statement — the donut's hole carrying the total, and the slice name outside the ring with its value or
percentage inside.

![Radar, grouped columns with the legend at the right, negative values, smooth lines, two decimals and forty bars](docs/graficaBarra-types3.png)

*Page 3 — the awkward cases.* **Radar** on a six-spoke web; **grouped columns** with the legend moved to the
right; **negative values** hanging below a baseline that stays on a gridline; **smooth** two-series
Catmull-Rom lines; a picture with **two decimals and no gridlines**; and **forty bars**, where the category
labels thin themselves out to every third one rather than collide.

**v2.1 adds the combo: bars and a line on the one chart.** A series can be told its own shape, whatever
the chart type says — `Obj.SetSeriesPlot(2, Plot:Line)`, or the **Draw as** prompt on the Series tab —
and the line is drawn **over** the bars, off the same value axis. Sales as columns, the trend as a line,
which is the shape a Clarion `LIST` has never been able to give you. The line series **takes no room in
the category slot**, so one bar series beside one line still draws full-width bars rather than squeezing
them into half a slot for a series that is not drawn there, and the legend keys it with a line and its
marker instead of a block. `Column`, `Line` and `Scatter` only — a stack has nothing to overlay, a
horizontal bar chart has no vertical line painter, and a pie is not a cartesian chart at all. A chart
that never sets it takes exactly the code path it took before, so every existing application is
untouched. The chart also gets **its own type** — `FontName`, `FontSize`, `FontStyle`, or the Typeface /
Size / Bold / Italic prompts — and a **size scales the layout with it**, so labels keep their spacing and
thin themselves out instead of colliding. **Show values** can be switched per series too (`SetSeriesNumbers`), which is what keeps the numbers on
the bars and off the trend line. A cell can also be told it has **no value** — `Obj.SetNoValue(2, Obj.NBars)` — and that series
draws no bar there and **breaks its line** rather than diving to zero: the shape you need for a row of
periods with an **average** bar on the end, which belongs on the chart but has no place on a trend. The prompts now live on **six tabs** rather than four: *Look* had grown to thirty prompts in
five groups and had stopped fitting on screen, so it splits into what is **shown**, the **shapes** that
draw it, and the **colors**.

![bars and a line on one chart](docs/graficaBarra-combo.png)

The report path is still the point: **graficaBarraReport** draws **straight into the band as vector
primitives** under `SETTARGET(Report)` at `%BeforePrint` — never a bitmap — so a **PDF export stays as
small as possible**. Pie/3D pie/donut ride on Clarion's own `PIE` statement and areas and radar webs on
`POLYGON`, both of which are valid on a REPORT, so *every* type stays vector:

![the same charts, printed into a report band as vectors](docs/graficaBarra-report.png)

A control in the band (IMAGE/BOX/REGION) is used *only* as the position/size placeholder and is hidden at
print time. **Reusing one object for chart after chart works**: a report band keeps every primitive ever
drawn into it, so painting a second chart over the same placeholder used to land *on top* of the first —
`ClearAll()` throws the data away but can never un-draw ink. Painting now `BLANK`s the placeholder's own
rectangle first (`EraseFirst`, on by default, "Erase the placeholder before drawing" in the prompts). It
is a real erase, not a box painted over the top: the old primitives leave the band, so the **PDF gets
smaller**, and neighbouring charts and the band's own controls are untouched. Set it off for a deliberate
overlay:

![clear and redraw into the same placeholder: EraseFirst off, then on](docs/graficaBarra-report-clear.png)

Each chart is aimed at **its own band** with `SETTARGET(report, band)` — the template works out
which band holds the placeholder from the report structure (indent level), so it handles a DETAIL, a group
HEADER/FOOTER or a FORM without being told. Both procedure extensions are **MULTI**, so you can put
**several charts on one report or one window** — each is its own local object, and on a report they follow
the band down the page as it repeats, each with its own data and its own auto-scale. On windows, **graficaBarra** draws into an `IMAGE` control
(redraw on open/resize, plus a generated `DO Refresh:<Object>` routine that re-reads variable/expression
values). Three registrations:
**graficaBarraGlobal** (include the class once), **graficaBarra** (window), **graficaBarraReport** (report).
Copy `GraficaBarraClass.inc` + `.clw` (ANSI) to the redirection path —
[`graficaBarra.zip`](templates/graficaBarra/graficaBarra.zip) bundles all three files for easy
distribution. `examples/graficaBarra/` has four runnable demos: **ChartDemo** (pick a type, watch it draw),
**ChartShots** (six charts per page, `ChartShots 1|2|3`), **ComboChart** (the bars-plus-line combo, three
ways) and **ReportClear** — a headless report that writes
its pages out as metafiles: `ReportClear` paints, clears and repaints into one placeholder page by page,
`ReportClear 2` compares the candidate fixes, and `ReportClear 3` walks the report with `PROP:NextField`
and logs a control census (the count never moves — a chart is ink, not controls). Full docs — prompts, class API, run-time
control — in [`docs/graficaBarra-template.html`](docs/graficaBarra-template.html); a bilingual (English +
Spanish) developer's reference with worked example code is in
[`docs/graficaBarra-reference.html`](docs/graficaBarra-reference.html). For driving the class from your own
code there is a full **class guide** in [`docs/graficaBarra-classes.html`](docs/graficaBarra-classes.html) —
bilingual, written from the source: every property and every method (including the internal painters and
primitives) with signatures and line references, the 48 × 8 data grid field by field, the ordering rules that
fail silently, `Paint` traced step by step, the scale/pie/legend algorithms, the colour rules, hand-coded
examples for windows, reports, multi-chart bands and dashboards, and a table of known quirks with workarounds.

*Upgrading from v1?* Nothing to redo: `Chart:Column` is the default and the v1 API (`AddBar`, `ClearBars`,
`SetRange`, `Draw`, `Paint`) and prompts are unchanged, so existing charts generate and draw as before —
except that `TextColor` now actually works (`SHOW` takes its color from the target's *font*, not the pen,
so v1 silently drew all text in black; set `ColorText = 0` for the old behaviour).

<a id="t-mygaugeplus"></a>
### `templates/myGaugePlus/` — **antialiased** (GDI+) gauges/dials on windows
The pretty sibling of myGauge. Native Clarion `ARC`/`ELLIPSE`/`LINE` have **no antialiasing**, so round
gauges drawn with them look jagged — myGaugePlus draws every pixel with **GDI+** instead: smooth arcs with
rounded caps, a **glossy radial-gradient face**, an antialiased needle and crisp text, rendered to a PNG and
shown in an `IMAGE` control. It carries **no redistributable** — `gdiplus.dll` ships with Windows, and the
bridge to its flat C API is a tiny shim (`gpcanvas.c`) bound at runtime (`LoadLibrary`/`GetProcAddress`) and
compiled automatically by Clarion's own compiler (`PRAGMA('compile')` inside `AaCanvasClass.clw`) — so there
is **no manual project step**. Three layers ship together: **`gpcanvas.c`** (the GDI+ shim),
**`AaCanvasClass`** (a reusable antialiased 2D canvas — `Arc`/`Line`/`FillCircleGrad`/`Polygon`/`Text`/
`SavePng`, useful for any drawing), and **`GaugePlusClass`** (the gauge, with the *same* API shape as
`GaugeClass`: `SetRange`/`Preset`/`AddZone`/`SetValue`/`AnimateTo`/`Draw`). Same prompts and presets as
myGauge — arc styles, range, literal-or-variable value, ticks/labels, title/units, up to 16 colored zones,
and **eased needle animation** — plus a glossy **value/accent fill**, face-gloss and rim toggles, an
optional **face image** drawn as the dial's base layer (a photo/texture/logo dial, disc-clipped: set
`Gauge.FaceImage = 'path'`), and automatic **centring for every span** (90/45/180/custom sit centred in the
control, not just the full 270/360 dials). Three
registrations: the **myGaugePlusControl** control template (drag-on, self-contained) and the
**myGaugePlusGlobal** + **myGaugePlus** (window) extensions. The transparent PNG composites cleanly onto any
window; it is **window-only** (use myGauge for report-band gauges). Copy the five files
(`GaugePlusClass.inc/.clw`, `AaCanvasClass.inc/.clw`, `gpcanvas.c`, all ANSI) to the redirection path. Full
docs — how it works, prompts, the `GaugePlusClass` + `AaCanvasClass` API, and gotchas — are in
[`docs/myGaugePlus-template.html`](docs/myGaugePlus-template.html). A hand-coded, ready-to-compile
**live property playground** — [`examples/myGaugePlus/GaugePlusPlayground.clw`](examples/myGaugePlus/GaugePlusPlayground.clw)
(build `GaugePlusPlayground.cwproj`) — drives *every* property in real time from a tabbed panel of sliders,
radios, check boxes and colour pickers beside a big live gauge, so you can see exactly what each option does
before wiring the template.

<a id="t-mycompress"></a>
### `templates/myCompress/` — pure-Clarion compression (memory + files)
A self-contained **compression library** written entirely in **pure Clarion** — no DLL, no external
library. One self-contained ANSI class, **`CompressClass`**, implements **DEFLATE (RFC 1951)** with the
**zlib (RFC 1950)** and **gzip (RFC 1952)** wrappers, so a `.gz` it writes opens in gzip / 7-Zip /
browsers / .NET `GZipStream`, and it reads any DEFLATE-family stream those tools produce. Decompression
(INFLATE) is complete — stored + fixed + dynamic Huffman; compression is **LZ77** (a hash-chain match
finder) + fixed Huffman, with Level 0 emitting stored blocks. Add **one global extension** —
**myCompress - Global Compressor** — and reach the shared object from any embed; there is **no per-window
or per-report wiring** (compression is all code-driven). It works on **memory buffers** (length-explicit
`Compress`/`Decompress(*STRING,LONG,*STRING)`) **and files** (`CompressFile`/`DecompressFile`), carries
**CRC32** (gzip) and **Adler32** (zlib) checksums, and ships a `SelfTest()` smoke test. Pick the format
(`Cmp:Raw`/`Cmp:Zlib`/`Cmp:Gzip`) and level (0–9) at run time; decompression **auto-detects** the
container. The codec is validated by a .NET golden-vector oracle, [`designer/CompressCore/`](designer/CompressCore/),
that round-trips a corpus both ways (Clarion ↔ `GZipStream`/`ZLibStream`/`DeflateStream`). Copy
`CompressClass.inc` + `CompressClass.clw` (**ANSI, CRLF**) to the redirection path.

**Optional C fast-path (~4× faster).** For big files or high throughput, pick the **C engine** in the
extension's *Compression engine* prompt. It's `CompressClassC` — a thin subclass that overrides the virtual
`Wrap`/`Unwrap` to call **`mc.c`**, our own clean-room DEFLATE port (not miniz/zlib/StringTheory) compiled by
**Clarion's own C compiler** via `PRAGMA('compile(mc.c)')`. Compression of a 4 MB buffer drops from ~844 ms
to ~200 ms (and a slightly better ratio, since C has no 64 KB-array limit so it uses the full 32 KB window).
It's the same algorithm, so the two engines produce byte-compatible output and interoperate freely. The
switch is the **template prompt** (it declares the global object as `CompressClass` or `CompressClassC`), so
a pure-Clarion app needs **no `mc.c` and no subclass** — copy the C files only when you choose that engine.

Full programmer's documentation — the API, formats, run-time control, the C fast-path, error codes, and
troubleshooting — is in [`docs/myCompress-template.html`](docs/myCompress-template.html).

<a id="t-mypdfsign"></a>
### `templates/myPdfSign/` — read a signed PDF and see who signed it
A self-contained **signed-PDF identity reader** written entirely in **pure Clarion** — no DLL, no external
library, no network. One ANSI class, **`PdfSignClass`**, opens a digitally-signed PDF and surfaces the
**authoritative signer identity** that lives in the embedded **PKCS#7 / CMS** signature: the signer
certificate's **Subject** (`SubjectCN` / `SubjectO` / `SubjectOU` / `SubjectEmail`), the issuing CA
(`IssuerCN`), the **signing time** (`SignTime`, ISO-8601 UTC, read from the signed attributes — not the
spoofable `/M`), plus the signature dictionary's own `/Name` (`SignerName`), `/Reason`, `/Location`,
`/SubFilter`, and a `SigCount`. It also reports **`CoversWholeFile`** — 1 when `/ByteRange` spans the whole
file, 0 when bytes were appended after signing (a tamper / incremental-update hint). It works on **files**
(`ReadFile`) or a **memory buffer** (`Read(*STRING,LONG)`), exposes a `Report()` block and a `SelfTest()`.
Internally it finds the `/ByteRange` + `/Contents <hex>` signature dictionary, hex-decodes the DER blob, and
a tiny **ASN.1 tag/length reader** walks `ContentInfo → SignedData → certificates[0] → tbsCertificate` to
read the Subject/Issuer RDNs by OID and the `signingTime` attribute. **Scope (be honest):** it extracts the
*named* signer + an integrity hint — it does **not** cryptographically verify the RSA/ECDSA signature or
validate the certificate trust chain. Add **one global extension** — **myPdfSign - Global signed-PDF reader**
— and reach the shared object (default `PdfSig`) from any embed; there is **no per-window or per-report
wiring**. Validated end-to-end against the real Clarion compiler and a .NET golden-fixture oracle
([`designer/PdfSignCore/`](designer/PdfSignCore/)) that **manufactures real signed PDFs** (CA-signed leaf
certs, detached PKCS#7 over a proper `/ByteRange`, `signingTime` in the signed attributes) and publishes the
ground-truth identity each one must yield — the Clarion `Report()` output matches **byte-for-byte across all
three fixtures**, including a deliberately tampered case that correctly reports `CoversWholeFile=0`. Copy
`PdfSignClass.inc` + `PdfSignClass.clw` (**ANSI, CRLF**) to the redirection path. Full programmer's
documentation is in [`docs/myPdfSign-template.html`](docs/myPdfSign-template.html).

Simplest possible use — declare the object, read a PDF, show the result (the `myPdfSign` global extension
declares `PdfSig` for you; in a hand-coded program just `INCLUDE('PdfSignClass.INC'),ONCE` and declare it):

```clarion
PdfSig  PdfSignClass                    ! one object is all you declare

  CODE
  IF PdfSig.ReadFile('contract.pdf')    ! open + parse the PDF
    IF PdfSig.Signed                    ! did it carry a signature?
      MESSAGE('Signed by : ' & CLIP(PdfSig.SubjectCN)    & |
              '|e-mail    : ' & CLIP(PdfSig.SubjectEmail) & |
              '|Issued by : ' & CLIP(PdfSig.IssuerCN)     & |
              '|Signed at : ' & CLIP(PdfSig.SignTime)     & |
              '|Intact?   : ' & CHOOSE(PdfSig.CoversWholeFile=1,'YES','NO — bytes added after signing'),|
              'Signature')
    ELSE
      MESSAGE('That PDF is not digitally signed.','Signature')
    END
  ELSE
    MESSAGE('Could not read the file: ' & CLIP(PdfSig.ErrText),'Error')
  END
```

In an AppGen app, add the **myPdfSign - Global signed-PDF reader** extension once, then drop the
`IF PdfSig.ReadFile(...) ... END` body into any embed (e.g. a button's **Accepted** embed). Parsing a PDF
already in memory? Use `PdfSig.Read(buffer, length)` instead of `ReadFile`.

<a id="t-my3d"></a>
### `templates/my3D/` — real WebGL2 3D scenes driven from Clarion
A **3D scene manager** that lets a Clarion app build and display **hardware-accelerated WebGL2** scenes with
**no JavaScript**. One ANSI class, **`WebGL2Class`**, exposes a rich object-oriented 3D API — **camera**
(`SetCamera`/`LookAt`/`SetFOV`/`OrbitCamera`), **lighting** (ambient, a directional key light, and up to 8
coloured **point lights**), **materials** (colour, metalness, roughness, opacity, emissive glow, wireframe),
**20+ mesh primitives** (`AddCube`, `AddSphere`, `AddCylinder`, `AddCone`, `AddPlane`, `AddTorus`,
`AddTorusKnot`, and the five Platonic solids `AddTetra`/`AddOcta`/`AddIcosa`/`AddDodeca`), **per-mesh
transforms** (`SetPos`/`SetRot`/`SetScale`/`SpinMesh`), plus **fog**, a ground **grid** and **axes**. It also
ships genuine **3D maths that run in Clarion** — a `Vec3` set (`Vec3Length`/`Distance`/`Dot`/`Cross`/
`Normalize`/`Lerp`) and a `Mat4` set (`Mat4Identity`/`Translate`/`Scale`/`RotateX/Y/Z`/`Perspective`/
`Multiply`) — so positions can be computed Clarion-side. `Show()` writes a **single self-contained `.html`**
(the scene data **plus** the verified `my3D.engine.js` renderer, inlined) and opens it in the default
browser; **drag to orbit, wheel to zoom, R to reset**. It can also render **inside a Clarion window** —
`ShowEmbedded()` positions a borderless Edge window (real WebGL2, its own process so it can't destabilise
Clarion) as an **owned overlay** over your window or a control in it; being a top-level window keeps it fully
interactive (drag/wheel/keys). The control template's **Show in** dropdown picks External browser or
Embedded. Pure Clarion: no DLL, no COM, no package — file IO via the ASCII driver, launch via
`rundll32 …FileProtocolHandler`.

Add the control template **my3D - 3D Scene Viewer button** to any window and configure the whole scene from
the AppGen prompts (canvas, camera, background, grid/axes/fog, lights, and a **MULTI** list of meshes), or
drive the class directly:

```clarion
Scene  WebGL2Class                              ! one object = one 3D scene

  CODE
  Scene.SetCamera(7, 6, 11);  Scene.LookAt(0, 0.5, 0)
  Scene.SetDirLight(-1,-2,-1.3, 1,0.97,0.9, 1.1)
  Scene.AddPointLight(4,3,4, 1,0.4,0.2, 1.2, 18) ! a warm point light
  Scene.SetColor(0.20,0.55,0.95);  Scene.SetSpin(0,0.6,0)
  Scene.AddCube(1.4)                             ! a spinning blue cube
  Scene.SetColor(0.2,0.85,0.85);  Scene.SetMaterial(0.7,0.2)
  Scene.SetPos(Scene.AddTorusKnot(0.7,0.2,2,3), 3, 0.9, 0)
  Scene.Show()                                   ! writes .html and launches the browser
```

Two example programs live in [`examples/my3D/`](examples/my3D/): **`My3DModels`** — a gallery of **10
real-world objects modelled from primitives** (a car, an airplane, a rocket, a wind turbine, a robot, a
table &amp; chairs, a house, a building foundation, a skyscraper and a park of trees) — and **`My3DDemo`**, a
**proof-of-concept app with 20 fixture scenes** (spinning primitives, a 7×7 sphere grid, the Platonic
solids, a 120-cube random field, a material matrix, point-light and fog demos, a solar system whose planet
orbits are placed with the class's own `Vec3` maths, a Fibonacci sphere, a "mega" scene, and a
**Vec3/Mat4 self-test**). Both build with their shipped `.cwproj`. Copy `WebGL2Class.inc` + `WebGL2Class.clw` (**ANSI, CRLF**) to the redirection path, and
ship **`my3D.engine.js`** beside the compiled `.exe` (it is read at run time and inlined into each page).
Full programmer's documentation — a guided tour in [`docs/my3D-template.html`](docs/my3D-template.html), and
the **exhaustive per‑method/per‑property API reference with example code for each** in
[`docs/my3D-reference.html`](docs/my3D-reference.html).

<a id="t-myyuru"></a>
### `templates/myYuru/` — yuruyurau animated flow-field art on a window
Live **generative "flow-field" animation** — the pure-trigonometry particle sketches of the artist
[@yuruyurau](https://twitter.com/yuruyurau) — playing on a Clarion **`IMAGE` control**, offline and with **no
dependencies**. Clarion has no per-pixel canvas, so one self-contained ANSI class, **`YuruClass`**, plots
~10,000 particles (30,000 for *Lattice*) **additively** into an in-memory **24-bit BMP** each frame — so
overlapping points glow the way the semi-transparent p5.js originals do — writes it to a temp file and
reloads the control (two temp files are alternated per object so the control never locks the frame being
written). A window **`TIMER`** drives the loop. Six presets ship: **Ribbon, Seashell, Nebula, Lattice,
Reeds** and **Plume**, each with its own natural time step; pick any **ink color** (a 10-swatch professional
palette, no purple), the background grey, the per-point **glow**, and a **speed** multiplier. Each animation
on a window is its **own local object**, so several can run at once.

**Optional GPU backend (`Flow.Backend = Yuru:Direct2D`).** The BMP-file round-trip was never the real
cost — computing 10–30k particles and plotting them additively through Clarion string indexing is. So the
Direct2D backend does two things: it builds the **whole frame in native C** (`yuru_native_frame`, the six
sketches ported 1:1, skipping the Clarion loop) and blits it **straight to a GPU-composited child window**
over the IMAGE control — no temp file, no reload. On the heaviest preset (Lattice, 30k particles) that's
**~7 → ~59 fps (8.5×)**; the lighter presets faster again. The C shim **`yurucanvas.c`** binds `d2d1.dll`
through hand-declared COM vtables and implements `sin/cos/sqrt/atan2` in pure C, so there is still **no
redistributable** (Direct2D ships with Windows 7+); it's compiled in automatically by a `PRAGMA` in the
class. If the target can't be created it silently falls back to the BMP path, so the default (`Yuru:BmpFile`)
stays pure Clarion. `SetBackend()` switches at runtime. The GPU host **follows the IMAGE control** — when the
window (and an anchored control) is resized, each frame re-reads the control's pixel rect and moves/resizes the
child host **and** its render target to match, so the art fills the grown control instead of staying boxed in
its original size.

**Easiest path: a control template** — drag **myYuru - Yuruyurau animation** onto a window and it drops the
IMAGE *and* wires the animation in one go, fully self-contained (it `INCLUDE`s the class itself, so no global
extension is needed). Three registrations: the **myYuruControl** control template (drag-on, self-contained)
plus the **myYuruGlobal** (include the class once) and **myYuru** (window) extensions, which wire the object
at `EVENT:OpenWindow`, repaint on a private per-instance `Redraw` event, step on `EVENT:Timer`, and generate
`Start:`/`Stop:`/`Restart:` routines you can `DO` from any embed — and both templates expose a
**Rendering → Backend** choice (BMP file or Direct2D GPU). Copy `YuruClass.inc`, `YuruClass.clw` and
`yurucanvas.c` (**ANSI, CRLF**) to the redirection path; the app needs the **DOS file driver**. A hand-coded,
ready-to-compile demo — [`examples/myYuru/YuruDemo.clw`](examples/myYuru/YuruDemo.clw) (build
`YuruDemo.cwproj`) — mirrors the web app at `c:\ai\yuruyurau\index.html`: a live canvas with preset / ink /
speed pickers, a **GPU (Direct2D)** toggle, and Start / Stop / Reset / Save buttons. The six presets, rendered
by the class itself:

![myYuru presets](docs/myYuru-presets.png)

<a id="t-mycalc"></a>
### `templates/myCalc/` — a pop-up calculator beside any numeric field
> **Renamed in this version:** the class's string equates are now `CalcTxt:Cancel`, `CalcTxt:Accept` …
> rather than `Txt:Cancel`, `Txt:Accept` …. `Txt:Cancel` was declared by **both** CalcClass (12) and
> ExportClass (26), so an application carrying myCalc *and* myExport compiled with `Label duplicated,
> second used: TXT:CANCEL` — and one of the two classes then indexed its string table with the other's
> number, showing the wrong caption. The prefix follows the one xsExport already uses (`xsTxt:`). If you
> have embed code calling `Calc1.Txt(Txt:Something)`, add the `Calc` prefix.
Drag **myCalc - Calculator button** next to a numeric entry and point it at that entry. A small calculator
icon appears; pressing it opens a modal calculator already holding whatever the field contains, and **Accept
puts the answer back into the field**.

**Four calculators in one window**, chosen from a drop list: **Standard** (four functions, memory, percent),
**Scientific** (trig, logs, powers, roots, factorial, parentheses, DEG/RAD), **Programmer** (HEX / DEC / OCT /
BIN with the out-of-range digits greyed out, AND OR XOR NOT, Lsh/Rsh, MOD, 8/16/32-bit word size) and
**Accountant** — a real adding-machine tape where `+` and `-` post the entry to the roll and SUBT / TOTAL / GT
print the running figures, with TAX+ / TAX- keys at a configurable rate. A **paper roll** runs down the side:
the tape in accountant mode, the history of finished calculations in the others, copyable to the clipboard.

**It remembers where you left it.** Which calculator you were last on comes back the next time the *program*
runs, along with DEG/RAD, the number base, the word size, the decimals and the tax rate — each profile saved
under its own INI section. **And it speaks Spanish**: the **language setting on the global extension** is what every
calculator in the application follows — mode names, window labels and the word keys (Borr, SUBT, TG,
IVA+/IVA-, Aceptar, Cancelar) — with an optional per-button override. The language is deliberately *not*
remembered between runs: there is no language picker in the calculator, so it is the template's call, and
saving it would let an old value shadow whatever you set today. Digits, operators and the maths names read the same
either way.

The keypad is a 7×7 grid re-labelled per mode, driven through a single `Press(action, text)` entry point — so
the whole calculator can be exercised from code or from a test without opening a window, which is exactly how
its 24-case arithmetic suite runs. Three registrations: **myCalcButton** (the drag-on control template, MULTI),
**myCalcHere** (a code template for an existing button, menu item or hot key) and **myCalcGlobal** (the class
plus the application language). Copy `CalcClass.inc`, `CalcClass.clw` (**ANSI, CRLF**) and `calc16.ico` to the
redirection path — the icon is compiled into the exe's resources, so there is nothing extra to deploy. A
runnable demo is [`examples/myCalc/CalcDemo.clw`](examples/myCalc/CalcDemo.clw), and the full
programmer's documentation — **bilingual English/Spanish** — is
[`docs/myCalc-template.html`](docs/myCalc-template.html).

![The myCalc demo](docs/myCalc-demo.png)

![The scientific calculator, and the accountant tape in Spanish](docs/myCalc-scientific.png)

![Contable (cinta)](docs/myCalc-accountant-es.png)

<a id="t-mycalendar"></a>
### `templates/myCalendar/` — a pop-up date picker beside any date field
Drag **myCalendar - Calendar button** next to a date entry and point it at that entry. A small calendar icon
appears; pressing it opens a modal calendar already sitting on whatever the field holds, and **Accept puts the
date back into the field**.

**One button can fill in two fields.** Set *Pick* to *a from-and-to range* and the user **drags across the
days** — over as many months as are on screen — to sweep out a period; the first day goes into the FROM field
and the last into the TO field, sorted whichever way they dragged. The selection follows the mouse live, and
**every press starts a fresh range** — putting the mouse down on a day clears whatever was marked before and
anchors there, so you never have to untangle a new sweep from the last one.

**How much is on screen is up to you and the user**: one month, two, three, six, or a **full year** — and two
and three can be stacked **across** (side by side) or **down** (one under the other), with six going 3×2 or
2×3 and a year 4×3 or 3×4. Both the view and the stacking are drop lists in the window itself, and **the
window is only ever as wide as the calendar** — when the months are narrower than the navigation strip needs
on one row, the strip wraps onto two rows rather than dragging the window out with it, so one month opens at
345 px instead of 811 and three months stacked down is a genuinely narrow column. **Both choices come back
the next time the program runs** (per profile, in the
app's own INI) along with the first day of the week, the week-number gutter and the today ring. Navigation is
`<<` year, `<` month, a month drop and a year spin, `>` month, `>>` year, plus **Today**. Options cover
**ISO-8601 week numbers**, Sunday or Monday first, today ringed in amber, **weekends blocked**, and earliest /
latest date allowed — blocked days are simply deaf to the mouse, so there is no error box to dismiss.

**And it speaks Spanish**: the **language setting on the global extension** is what every calendar in the
application follows — month names, day headings, the view and stacking lists, Today / Clear / Accept / Cancel
and the footer that counts the days — with an optional per-button override. Like myCalc, the language is
deliberately *not* remembered between runs, so changing the setting takes effect immediately.

The months are painted with native `BOX` / `LINE` / `SHOW` into an IMAGE (the two-argument
`SETTARGET(window, ?image)`, so 0,0 is the image's own top-left) with a transparent `REGION` + `IMM` over the
top to collect the mouse — which is what makes a whole year cheap enough to draw, and makes the hit test plain
arithmetic. `Layout()`, `Draw()` and `DateAt()` are public, so the same class will paint an always-visible
calendar into an IMAGE on a window of your own; the date maths (`AddMonths` with the short-month clamp,
`DaysInMonth`, ISO `WeekNumber`, `DayOfWeek`) stands alone as well. A 62-assertion headless suite covers all of
it. Three registrations: **myCalendarButton** (the drag-on control template, MULTI, single-date or from/to),
**myCalendarHere** (a code template for an existing button, menu item or hot key) and **myCalendarGlobal**
(the class plus the application-wide language, first day, view and stacking). Copy `MyCalendarClass.inc`,
`MyCalendarClass.clw` (**ANSI, CRLF**) and `cal16.ico` to the redirection path — the icon is compiled into the
exe's resources, so there is nothing extra to deploy. **The class is `MyCalendarClass`, not `CalendarClass`** —
ABC already ships a `CalendarClass` in `ABUTIL`, and the two link into the same program as
`Duplicate symbol: TYPE$CALENDARCLASS`. A runnable demo is
[`examples/myCalendar/CalendarDemo.clw`](examples/myCalendar/CalendarDemo.clw), and the full programmer's
documentation — **bilingual English/Spanish** — is
[`docs/myCalendar-template.html`](docs/myCalendar-template.html).

![The myCalendar demo](docs/myCalendar-demo.png)

![Three months across, and one month with a dragged range](docs/myCalendar-three-across.png)

![A full year on one canvas](docs/myCalendar-year.png)

<a id="t-myfilter"></a>
### `templates/myFilter/` — build filters for any browse
Drop **myFilter - Filters button** on a browse window and name the browse object. Pressing the button opens a
window listing **the browse's own fields**: pick one, say how to test it, press Add, repeat. **Apply** hands
the browse a real filter.

The field list is not typed by hand — the template walks the browse's queue back to the dictionary fields at
generate time, the same way the shipped QBE does (`#FOR(%QueueField)` → strip any `[subscript]` →
`#FIX(%Field,…)`), then the joined files, with a fall-back to every field if the view is entirely PROJECTED.
Each field's type comes from its picture first and its storage second, so a date held in a LONG is still
offered date tests.

**23 tests, offered by type.** Text: equals, not equals, begins with, ends with, contains, doesn't contain, is
empty, is not empty, matches a `*`/`?` pattern. Numbers: the six comparisons, between, not between. Dates: all
of those plus **is today, was yesterday, in the last N days, in the next N days, in month, in year**. Flags:
is yes / is no. Conditions join with **AND or OR**, the built expression is on screen as you go, and filters
can be **saved by name** and picked again later.

**The filter is ANDed, not substituted.** It goes in through `BRW1.SetFilter(expr,'7 myFilter')` — ABC keeps
filters in a named, conjunctive list, so a range limit, a locator or a QBE still apply alongside it, and
applying an empty filter deletes the slot rather than leaving a stale one behind.

**One prerequisite: tick Bindable on the file in the dictionary.** A filter is evaluated by field name at run
time and the runtime refuses a field it was never told about — `BIND has not been called for CUS:Name`. ABC
calls `BIND` on every file open, but only for a file carrying `BINDABLE`.

Every operator was **measured, not assumed**: a probe builds a real TPS file and runs each candidate
expression against a VIEW. That caught two things that would otherwise have shipped broken — slicing a field
inside a filter (`UPPER(f)[1 : 5] = 'SMITH'`) **silently matches every record**, so "begins with" uses `SUB()`;
and the BIND requirement above. A 102-assertion suite applies every generated expression to a real file and
counts the surviving rows, apostrophes in values and decimal points included. Saved filters reload by **field
name, not position**, so adding a column to the browse cannot silently repoint an old filter at another field.

Saved filters live in the application's own INI by default — no setup, per user. For filters shared between
users, [`templates/myFilter/FilterTables.txt`](templates/myFilter/FilterTables.txt) has the `FilterHdr` /
`FilterLine` structures and the operator numbers; derive the class and fill in the four table hooks. Three
registrations: **myFilterButton** (the drag-on control template, MULTI), **myFilterHere** (a code template for
a button or menu you already have) and **myFilterGlobal** (the class, the language and the storage choice).
Copy `MyFilterClass.inc` and `MyFilterClass.clw` (**ANSI, CRLF** — they are pure ASCII) to the redirection path.

<a id="t-myexport"></a>
### `templates/myExport/` — export any browse or list to seven file formats
Drag **myExport - Export button** onto a browse window and you get a wired-up **Export…** button. Pressing it
opens a modal dialog that asks for the **format**, the **folder and file name** (through the standard Windows
Save-As browser) and **which columns to send** — then writes **CSV**, **CSV UTF-8** (with the BOM Excel needs
before it trusts accents), **TSV**, **XML**, **JSON**, **HTML** or a real **Excel `.xlsx`** workbook.

**The column picker.** Every data column is listed with a tick box, so the user can leave columns out,
**rename** one for the file, or give it a **different picture** — with the list's own heading shown alongside
so nothing gets lost. A blank picture writes the **raw** value (handy for JSON and Excel, where an
unformatted number beats a formatted string), and renaming also renames the XML element and the JSON key.
**All / None / Defaults** act on the lot. The choices **survive between exports**: the generated code
re-`Init`s before each one, so the scan fingerprints the list's layout (column count, field numbers, widths)
and only rebuilds when that actually changes. One prompt (`AllowColumns`) hides the whole picker and shrinks
the dialog back to format + file name if you'd rather lock it down, and every button it offers is also a
public method — `ColumnUse`, `ColumnRename`, `ColumnPicture`, `SelectAll`, `ResetColumns` — so you can preset
the columns from code.

**It remembers how you left it.** With `Persist` on (the default), a successful export writes the format,
the folder, the three tick boxes and the entire column list — which are on, every rename, every picture
override — into an INI section, and the dialog restores them the next time the *program* runs, not just
the next time the window opens. The section is named from a **profile** (the procedure name by default),
so two browses never overwrite each other, and a short fingerprint of the list's layout guards the column
half: add or resize a column and the stale column settings are discarded rather than landing on the wrong
column, while the format and folder still come back. `LoadSettings` / `SaveSettings` / `ForgetSettings`
are public, so an unattended nightly export can restore a saved profile and run with no dialog at all.

**No external program is needed for the Excel format.** An `.xlsx` is a ZIP of XML parts, and `ExportClass`
writes both — the six OOXML parts *and* the ZIP container (local headers, CRC-32, central directory, EOCD) —
so there is no helper `.exe`, no Python, no COM automation, no Excel installation and nothing to redistribute.
The workbook is not a renamed CSV: **numeric columns become real numeric cells** (`<v>1234.56</v>`, so SUM,
sorting, filtering and charts work), with a **bold heading row**, a **frozen pane**, an **auto-filter** and the
**column widths carried over from the screen**. Validated end-to-end against `openpyxl`.

**You never describe your columns to it.** At click time it reads the LIST control's own `FORMAT` —
`PROPLIST:Exists` / `FieldNo` / `Header` / `Picture` — and pulls values with `WHAT(Queue,FieldNo)`, the same
recipe the shipped `brwext.clw` uses. So the file matches the screen exactly, including columns the *user*
re-ordered, resized or hid after the window opened. The **queue is discovered at generate time** from the
LIST's own `FROM()` attribute (`EXTRACT(%ControlStatement,'FROM',1)` — what the shipped BrowseBox does), so
there is nothing to type. By default it walks the **whole browse view** (`BRW1.Reset()` → `Next()` →
`SetQueueRecord()`), honouring the current sort order, range limits and filters — not just the page of rows
the ABC queue happens to hold; a queue-only mode is one prompt away for hand-coded lists.

**English or Spanish, everywhere the user looks.** The dialog, the column popup, the column-list headings, the
tool tips, the Save-As file types and every message come from one virtual method, `Txt(id)` — 81 strings, both
languages, verified complete in both. Pick it per application (*myExport - Global* → *Export language*, which
emits the global `myExportLanguage`) or per button (*Language*: English, Español, or *Use the application
setting*). Only that last choice touches the global, so **the button stays self-contained** — no `REQ()` on the
control template. From code it is one line: `Exporter1.Language = Exp:Spanish`. A third language is one
`DERIVED` override of `Txt()`, with anything you skip falling through to English. Two details worth stealing:
the window structures keep the English text as the *designer's* placeholder while every caption is assigned
from `Txt()` at run time, so the languages cannot drift; and **the button row measures itself** — "Defaults" is
8 characters, "Predeterminados" is 15, so those five buttons are sized from their own captions and packed left
to right rather than clipped by fixed widths. Accents are Clarion `<nnn>` escapes so the `.clw` stays 7-bit
ASCII and can't be mangled by a UTF-8 editor.

**Multi-DLL suites share one copy of the class.** `ExportClass.inc` is tagged `!ABCIncludeFile(MYEXPORT)`, and
**myExportGlobal** registers that category with the ABC chain (`%AddCategory` + `%SetCategoryLocationFromPrompts`).
That hands the whole job to the shipped machinery: `ABPROGRM.TPW` writes the `_myExportLinkMode_` /
`_myExportDllMode_` project defines the class's `LINK()` and `DLL()` attributes read, and `ABBLDEXP.TPW` — while
building a DLL's `.EXP` — walks the class registry and emits `VMT$`, `TYPE$` and all 71 methods, name-mangled by
`LINKNAME()`. **Nothing to configure:** it follows each application's own *External* setting, so the app that
owns the data compiles the class in and exports it, and every app set to *External → DLL* imports it instead of
carrying its own copy. Add the global extension to **every app in the suite** — placing a class is a
per-application decision, so the button and code templates cannot make it. An *Override defaults* box
(LINK / DLL / LIB / None) is there if you want to place it by hand, and `ExportClass.exp` ships the same export
list for hand-coded projects that have no AppGen to generate one. **Upgrading from v1.0: replace the
`ExportClass.inc` on your redirection path** — the class registry reads *that* copy, and a leftover v1.0 one
(no `(MYEXPORT)` on its tag) files the class under the ABC category instead, which only misbehaves once the two
locations disagree. With neither define present — a single EXE, or
the demo — the class is simply linked in, exactly as before. Verified both ways: a generated ABC DLL app really
does emit the 73 export lines, and an EXE built with `_myExportDllMode_=>1` imports the class from a DLL and
writes a valid `.xlsx` with none of the class's code in it.

Three registrations: **myExportButton** (the drag-on control template, `MULTI`, self-contained),
**myExportHere** (a code template for an existing button, menu item or toolbar entry) and **myExportGlobal**
(optional in a single EXE — only if you want the class in procedures with no button; **required in a multi-DLL
application**). Copy `ExportClass.inc` and `ExportClass.clw` (**ANSI, CRLF**) to the redirection path. `.xlsx` parts are **stored** by default so the
class has zero dependencies; if you also have **myCompress**, setting `_ExportDeflate_` to 1 in
`ExportClass.inc` switches them to real DEFLATE and shrinks a big workbook by roughly 10×. A runnable demo —
[`examples/myExport/ExportDemo.clw`](examples/myExport/ExportDemo.clw) — is a plain list with one Export
button plus a "write all seven" self-test. Full programmer's documentation:
[`docs/myExport-template.html`](docs/myExport-template.html).

![The myExport dialog, with two columns left out, one renamed and one re-pictured](docs/myExport-dialog.png)

<a id="t-myhook"></a>
### `templates/myHook/` — intercept MESSAGE, STOP, HALT and run-time errors
Add **myHook - Global message/stop/halt interceptor** once to the application and the Clarion run-time
library's own dialogs stop being the run-time library's business. `MESSAGE`, `STOP`, `HALT`, a failed
`ASSERT`, a run-time error and a GPF each get a default action — **show it as usual**, **ignore it**,
**answer it for the user**, **show it as a plain message**, **hand it to a procedure of yours**, or
**write it to the log and swallow it**.

This is built on the run-time library's own extension points — `SYSTEM{PROP:MessageHook}`,
`{PROP:StopHook}`, `{PROP:HaltHook}`, `{PROP:AssertHook}` / `{PROP:AssertHook2}`, `{PROP:FatalErrorHook}`
and `{PROP:LastChanceHook}`. The exact hook prototypes are taken from the shipped WebBuilder layer,
`\clarion12\libsrc\win\WBHOOK.CLW`, which uses the same seven to move a desktop `MESSAGE` onto a web page.

**The rules tab** is where it earns its keep. Test the message text — *contains* / *starts with* /
*is exactly* / *matches a `*` `?` pattern* — against the text, the caption or either, and give the ones
that match their own treatment. Rules are checked in order, the first match wins, and anything matching
nothing falls back to the default for its kind of event. So a stray *"Record Not Found"* can be answered
`Ok` and logged while every other message still reaches the user untouched.

**The log** is a plain text file, CSV (with a heading row) or tab separated. It is opened for append and
closed again on every line, so threads can share it, two copies of the program can share it, and a line
written immediately before a `HALT` is still on disk afterwards. Each line carries the date and time, the
kind of event, the thread, the window that was on screen, the caption, the text flattened to one line,
what was done about it, and for an `ASSERT` the source file and line. Give it a size limit and it rolls
over to a `.bak` on its own.

**One honest limitation, established by test, not assumption: a `HALT` cannot be called off.** The
run-time library ends the program as soon as the halt hook returns, whichever action you pick — so for a
`HALT` the choices change what is *said* on the way out and what lands in the log, not whether it happens.
A `STOP`, by contrast, really can be ignored: the line after it runs. The prompts and the class header say
so plainly, and `HALT` defaults to *write it to the log, then halt*.

Three registrations: **myHookGlobal** (`APPLICATION` — the whole thing, added once), **myHookPause**
(a procedure extension that lets one procedure's messages through untouched, on that thread only) and
**myHookHere** (a code template to install, remove, suspend, resume, or write your own line to the log from
any embed). Copy `MsgHookClass.inc` and `MsgHookClass.clw` (**ANSI, CRLF** — they are pure ASCII) to the
redirection path.

Verified by building a standalone program against the class and running it: a message with no matching rule
answered with the configured button, a `*wildcard*` rule answering `Retry`, a rule handing off to derived
code that answered `Cancel`, a `STOP` ignored with execution continuing past it, the counters, the CSV
quote-doubling, and the roll-over to `.bak`.

Full programmer's documentation, English and Spanish in one page with a language toggle:
[`docs/myHook-template.html`](docs/myHook-template.html).

<a id="t-sdaspecto"></a>
### `templates/SDAspecto/` — **one look for every window**: rules, typography and rescaling
One APPLICATION extension and two procedure extensions. The global one restyles **every window in the
program** with no per-window work; the other two are escape hatches for the windows that need one.

- **Typography.** One typeface, size, colour, style and charset for the whole program — applied to the
  window, to its controls, or to both. Each parameter is a literal or a program variable, and `-1` /
  empty means *leave this one alone*.
- **Rescaling.** Changing the font makes every control the wrong size, so the engine puts them back: it
  saves each control's geometry **in dialog units**, applies the font with `SETFONT`, forces Clarion to
  recompute the dialog unit, then writes the same numbers back. Every control starts from its
  **original** geometry, never its current one, so reapplying is idempotent instead of cumulative.
  `LIST` and `COMBO` line height and column widths come along — read as indexed properties
  (`PROPLIST:width`, `PROPLIST:group`), so no `PROP:Format` string has to be parsed.
- **Recentring.** A window that grows keeps its top-left corner fixed and therefore drifts down and to
  the right. It gets moved back half of what it grew, so the centre stays put.
- **Fixed settings.** A minimum height for `ENTRY`/`SPIN`/`CHECK`/`COMBO`/`LIST`/`BUTTON`, and a
  background colour per control type. `GROUP` is deliberately absent — it is not a fillable surface;
  put a `PANEL` or `REGION` behind it instead.
- **A rule engine.** A rule is *match criteria + actions*. It can match on the control type, on its text
  (exact / contains / starts-with), on a wildcard over `PROP:Text`, and on whether the control is
  required, read-only or disabled. It can then set the background, the font colour and style, flatten a
  button, set a tip, or set a cursor.

Rules **cascade like CSS**: they are evaluated in order, every rule that matches applies, and the last
one wins per property — so a broad rule can set the ground and a narrow one can override a single
property of it. A rule marked *Cortar* stops the cascade for that control, which is the `ELSIF`
semantics when you want it.

Two details worth knowing, because they are the kind that bite silently:

- **"Required" is a bitmask, not a flag.** The `REQ` attribute is the clean answer, but plenty of
  applications never used it and instead mark required fields by giving them a background colour in the
  designer. The engine can test either, or both.
- **The actions are a bitmask too** — because `COLOR:NONE` is `-1`, which is a *valid* colour and
  therefore useless as a "not set" sentinel. The bitmask says which fields of the rule are defined.
  Font colour also accepts `sdColor:Auto`, which derives black or white from the background's
  luminance; its value (`7FFFFFFFh`) dodges both real colours (`00BBGGRRh`) and system colours
  (`80000000h`–`8000001Eh`).

**Rules are data, not code.** They live in the INI as one `[Regla:n]` section each; the factory scheme
(required, read-only, normal, confirm button, cancel button, browse buttons) is built in code and
written out the first time, when the INI has none. The INI is read **after** the template's own
settings and overrides them: the template is the factory default, the INI is the customisation. Three
global functions — `SDAspectoCargar()`, `SDAspectoGuardar()` and `SDAspectoApply()` — let a settings
window reread, save and reapply at run time, editing the parameters straight on the global instance
(`GLO_SDAspecto.FuenteNombre = 'Segoe UI'`). `VentanaConfigAspecto.txa` is such a window, ready to
IMPORT.

Painting is injected into `WindowManager.Init` at **`PRIORITY(8600)`** — deliberately late, so any
other template that reapplies fonts or moves controls has already finished. The two procedure
extensions cover the exceptions: **`SDAspecto - Excluir esta ventana`** leaves one window alone, and
**`SDAspecto - Ventana redimensionable o maximizada`** is needed when a window uses the ABC resizer or
starts maximised, because the resizer belongs to the window rather than to the application.

Multi-DLL is handled the way `cleansdw.tpw` does it: `MEMBER` modules never see the `SDAspectoClass`
type at all, they only call the global functions, so the class instance is declared in the app that
owns the globals and the satellites import five prototypes. The global instance is shared across
threads, so the rule queue carries a lock and the per-window state queue is declared `,THREAD`.

Copy `SDAspecto.clw` and `SDAspecto.inc` to `libsrc\win`, register `SDAspecto.tpl`, then add
**SDAspecto - Personalizacion visual de controles** under Global → Extensions. Full programmer's
documentation — the four prompt tabs, the rule model, the INI format, the class API and the multi-DLL
skeleton — is in [`docs/SDAspecto-template.html`](docs/SDAspecto-template.html).

> **Note:** this template's prompt UI, its INI keys and its source comments are in **Spanish**, as
> written. The documentation above and in `docs/` is in English.

<a id="t-weatherwidget"></a>
### `templates/weatherWidget/` — the weather, on a card at start-up
Add **weatherWidget - The weather at start-up** to the application (once, not per procedure), generate, and
your program opens with the weather: where the user is, the temperature now, what it feels like, humidity,
wind with its compass point, rain, sunrise and sunset, and up to seven days ahead. It closes itself after a
countdown you choose, or waits for the user.

![The card, at start-up](docs/weatherWidget-card.png)

**Free data, no API key, no registration.** The forecast is `api.open-meteo.com`; the place is either looked
up from the machine's public address (`ipwho.is`) or geocoded from a city name (Open-Meteo's own geocoder),
and both answers are kept for a day so a normal start-up costs **one** request. The download is `curl.exe`,
which ships with Windows 10 and 11, launched **hidden and synchronously** — the same proven launcher myQR
uses. There is no JSON library: the answers are flat and machine-written, so a bounded `INSTRING` reader and
a hand-rolled number scanner are enough, and the class carries no dependency at all.

**Every pixel is drawn.** The sky gradient, the sun and its rays, the crescent moon (a disc with the sky
colour punched out of it), the clouds, the raindrops, the snow and the lightning bolt are native `BOX`,
`LINE`, `ELLIPSE` and `POLYGON` into one `IMAGE` — no icons, no PNGs, nothing to ship but your executable.
Day or night is whatever the service says it is where the weather is, not what your clock says.

![Spanish, Fahrenheit, a named city](docs/weatherWidget-es.png)

![Night: a crescent, and a darker sky](docs/weatherWidget-night.png)

Two registrations: **weatherWidget** (`APPLICATION` — declares the object, writes the settings, shows the
card) and **weatherWidgetHere** (a code template to show it from a menu item, a button or a hot key). English
or Spanish throughout — labels, conditions, day names, compass points, buttons — and metric or imperial asked
for **at the source**, so the numbers are the service's, not a conversion. Copy `MyWeatherClass.inc` and
`MyWeatherClass.clw` (**ANSI, CRLF** — they are pure ASCII, with the Spanish accents as `<nnn>` escapes) to
the redirection path.

**It is honest about the network.** The fetch is synchronous, so *Give up after* (6 s) bounds what a dead
connection can cost your start-up, a reading younger than *Re-use a reading younger than* (30 min) is served
from the INI with no request at all, and a failed fetch can show nothing, show the last reading kept, or show
the fault — the default for an offline laptop is a program that starts exactly as it always did. The card
carries Open-Meteo's attribution, and the documentation spells out which third party sees what.

Verified end to end, not just registered: `ClarionCL -tr` registers it, a grafted TXA generates a real ABC
application, and that generated application **compiles and runs** — the card in the screenshots above is a
generated program's, with the template's own prompts in it. The class was also driven headlessly through both
location modes, both unit systems and both languages against the live services.

![The demo](docs/weatherWidget-demo.png)

Full programmer's documentation, English and Spanish in one page with a language toggle:
[`docs/weatherWidget-template.html`](docs/weatherWidget-template.html) — including a *Clarion notes* chapter
on the two things that made this template hard: **a dialog unit is a fraction of the current font**, so
mixing font sizes moves the drawing grid (measured, and solved by scaling through `GETPOSITION`), and a
hand-coded project that omits the `_myWeatherLinkMode_` / `_myWeatherDllMode_` pragmas links the class as an
import and faults in the constructor. A runnable demo is
[`examples/weatherWidget/WeatherDemo.clw`](examples/weatherWidget/WeatherDemo.clw); its `/shots` switch and
`shoot.ps1` regenerate every image above.

<a id="t-emailto"></a>
### `templates/emailTo/` — send e-mail, and manage the account: SMTP/TLS, OAuth2 and nine provider APIs
Add **emailTo - Global** to an application and every procedure in it can send mail. Drag **emailTo - E-mail
button** onto a window for a wired-up button, or drop the **Send an e-mail here** code template into any embed
— the end of a report, a menu item, a batch process. One line does it from hand-written code:

```clarion
IF NOT Mailer.SendSimple('bob@acme.com', 'Your invoice', 'It is attached.', 'INV-1042.pdf')
   MESSAGE(Mailer.LastErrorText)
END
```

**Four ways to send, one message.** `EmailMsgClass` builds the MIME once and each transport delivers those
same bytes its own way: **SMTP** (plain, STARTTLS or implicit TLS, signing in with `AUTH LOGIN`, `AUTH PLAIN`
or **OAuth2 `XOAUTH2`**); the **Gmail API**; **Microsoft Graph** — the only route many locked-down Microsoft
365 tenants still permit; and a **provider API key** for SendGrid, Mailgun, Resend, Brevo, Postmark,
Mailjet, SparkPost, MailerSend or **Amazon SES**, which needs no OAuth and no consent screen at all. Sixteen provider presets
fill in host, port, security and sign-in method, so the only things left to type are the address and the
credential.

**And it asks them questions too.** Sending is half of what a mail provider does. The other half is knowing
which of your addresses it will not deliver to — the hard bounces, the spam complaints, the unsubscribes —
and `EmailApiClass` reads that, through **one set of methods for all nine providers**:

```clarion
MailApi.Init(Mailer)                                  ! borrows the account you already set up
IF MailApi.GetSuppressions(ETSup:All) >= 0
   LOOP i = 1 TO RECORDS(MailApi.SuppQ)
      GET(MailApi.SuppQ, i)
      !  .Address  .KindName  .Reason  .WhenDate  —  the same six columns, whoever answered
   END
END
MailApi.DeleteSuppression('bob@acme.com', ETSup:Bounce)   ! let one back in
MailApi.DeleteAllSuppressions(ETSup:All)                  ! or all of them
MailApi.Manage()                                          ! or just show them the window
```

That program is unchanged across providers that agree about almost nothing. SendGrid keeps **five** separate
lists and pages with an offset; Brevo keeps **one** and labels each row with a reason code; Mailgun is
per-domain and pages with a **cursor**; Postmark capitalises everything and deletes a bounce by *its own id*;
Mailjet buries the lot in `Data`; Amazon SES wants every request **signed**, and pages with a token.
The differences live in a **matrix** — one row per operation per provider,
saying which verb, which address, where the array is in the reply, and which JSON member fills which column —
so adding a provider is adding rows, and `BuildMap` is VIRTUAL if the one you want is not there yet.

Beyond the block lists, the same object reads **statistics** per day, the **activity** feed (delivered,
opened, clicked, bounced — with the reason), **contacts** and **lists**, **campaigns** (create, and send),
**templates**, **senders**, **domains** and **webhooks**. No provider offers all of it, and `Supports()` says
which — so `Manage()`, the ready-made tabbed window, *disables* what an account genuinely cannot do rather
than showing an empty list. `IsBlocked()` is the one worth calling in a mailing loop: never send again to an
address the provider is going to refuse.

**And it can land all of that in your own tables.** The management window asks the provider live and keeps
nothing, which is fine for looking but no use for a browse, a report, or a join to your customer table. So
there is a dictionary and a sync:

* **`emailToTables.dctx`** — a ready-made dictionary: `MailBlocked`, `MailStat`, `MailEvent`, `MailContact`,
  `MailList`, `MailCampaign` and the account table. *Dictionary Editor → File → Import*, and pick the
  **DCTX / XML** entry. (Not the `.txd` — that is Report Writer's format and the Dictionary Editor refuses it
  outright. It ships only for `ClarionCL /di`.)
* **`emailTo - Sync provider data into your tables`** — a *separate* application extension. Nominate the
  tables and their keys and it generates a small object with one method, `Run`, that fills them.
* **`emailTo - Sync mail data into your tables`** — a control template that drops a wired *Sync* button, and
  a *Sync it all into my tables* entry on the code template for a menu item or a batch run.

Columns are matched **by name**, so a table imported from the dictionary needs no mapping at all — and a
column of your own that the template does not recognise is left alone, surviving every sync. Each row is
looked up by its key before it is written, so running the sync twice updates rather than duplicates: the
same eleven rows come back as eleven, not twenty-two.

**No DLL, no .NET, no OpenSSL.** Everything is pure Clarion except one bundled C file, `emailc.c`, compiled
into your `.EXE` by Clarion's own C compiler through `PRAGMA('compile(emailc.c)')`. It exists because Clarion
cannot do four things for itself: **TCP sockets**, the **SCHANNEL TLS handshake**, **WinHTTP** and **DPAPI**.
MIME, base64, quoted-printable, the SMTP conversation, OAuth2 with PKCE, JSON and every provider preset are
Clarion source you can read and step through. `ws2_32`, `secur32`, `winhttp` and `crypt32` are all parts of
Windows and are bound at **run time**, so there is no import library, nothing to redistribute, and a machine
missing one gives a clean error code instead of failing to start.

**OAuth2 that a desktop app can actually use.** Press **Sign in…** in the setup window and emailTo invents a
PKCE verifier, hashes it (SHA-256, ours), opens the user's own browser at the provider's consent screen and
listens on `http://127.0.0.1:<a free port>/` for the redirect — then swaps the returned code for an access
and refresh token. It checks the `state` value before trusting the reply, and only a **desktop client ID** is
needed, which is not a secret: nothing confidential is compiled into your program. Microsoft public clients
correctly send **no** client secret; Google gets `access_type=offline&prompt=consent` so a refresh token
actually comes back. After that, sending refreshes the token silently — the user never sees the browser again.

**Accents survive.** A Clarion `STRING` holds Windows-1252 bytes, so left alone `Factura Número` arrives as
mojibake. The subject, the display names, the bodies and the attachment file names are transcoded to **UTF-8**
and labelled as such, with headers wrapped in **RFC 2047** encoded words split on character boundaries — never
mid-character — and bodies in quoted-printable. A plain English note still goes out as readable `7bit` text,
because the encoder only reaches for quoted-printable when the content, or a 998-byte line, actually needs it.
`CharSet = ETChs:Ansi` sends the raw bytes labelled `windows-1252` instead.

**It builds the smallest MIME that carries what you gave it.** Text only is `text/plain`; text and HTML is
`multipart/alternative`; add an inline image (`<img src="cid:logo">`) and it becomes
`multipart/related( alternative, image )`; add a file and the lot is wrapped in `multipart/mixed`. A plain
note does not arrive as a four-part tree. Attachments stream through a doubling buffer, so a 10 MB PDF is
base64-ed in linear time rather than the quadratic crawl `s = s & more` would give you.

**Where the settings live is your decision.** `LoadAccount` and `SaveAccount` are `VIRTUAL`. Out of the box
they read and write an INI beside the `.EXE`. Nominate a **table** on the global extension's Table tab — pick
the key, map a column onto each account field — and the template **generates** the code that reads it at
start-up and writes it back when the setup window saves, so accounts live in your own data with your own
backup and security around them. `EmailTables.txt` ships the structure ready to paste into a dictionary.

**The four secrets are encrypted at rest.** Password, client secret, refresh token and API key go through
`Seal()`: **DPAPI** encrypts them for the current Windows user, then base64 makes the result safe for a text
column. A settings row copied to another machine, or read by another Windows user, decrypts to nothing. A
value typed into the column by hand in plain text still works — `Unseal()` recognises it is not one of its own
and hands it back unchanged.

**A setup window your end users can drive.** Provider, server, port, security, user name and password on one
tab; **Sign in…** and the API key on another; a **Test account** button that connects, negotiates TLS and
authenticates **without sending anything to anybody**; and a **Log** tab showing the entire conversation —
with passwords and tokens masked, so a customer can e-mail you the log of a failed send without e-mailing you
their password. Everything the user reads comes from one virtual `Txt(id)` method, in **English and Spanish**.

**How it was verified.** The network layer was proved against the live servers before anything was built on
it: an implicit-TLS handshake to `smtp.gmail.com:465`, a `STARTTLS` upgrade on `:587`, HTTPS to Google's and
Microsoft's token endpoints, SHA-256 against the RFC test vector and a DPAPI round trip. That flushed out a
real defect — Google's SMTP asks for an *optional client certificate*, and SCHANNEL answers
`SEC_I_INCOMPLETE_CREDENTIALS`; the fix is to re-issue the same token so the handshake completes anonymously,
and without it every Gmail connection dies at `0x00090320`. A complete send — EHLO, AUTH LOGIN, envelope,
DATA, dot-stuffing, QUIT — was then run against a local SMTP sink and the delivered message compared byte for
byte: **Bcc in the envelope but not in the headers**, a body line consisting of a single full stop correctly
doubled on the wire, UTF-8 headers intact and the attachment decoding back to its original bytes. Finally a
real ABC application was generated from the templates with `ClarionCL` and **compiled and linked**, which also
confirmed the multi-DLL category writes `_emailToLinkMode_` / `_emailToDllMode_` exactly as the classes expect.

**Files** (copy to the redirection path, all ANSI): `EmailNetClass.inc/.clw`, `EmailMsgClass.inc/.clw`,
`EmailToClass.inc/.clw`, `emailc.c`. The `.clw` files pull themselves into the build through their `LINK`
attribute, and `EmailNetClass.clw` pulls in the C through its `PRAGMA`. A hand-coded project with no template
must define `_emailToLinkMode_=>1;_emailToDllMode_=>0` itself — `examples/emailTo/emailToDemo.cwproj` shows how.

**The manual** is four linked volumes in English and Spanish — eight pages — built by `docs/emailTo/build-docs.py`. The reference volume is
generated from the `.inc` files, so its signatures cannot drift from the build, and the build fails if a
nav entry lands on no heading, a heading sits in no nav, or any of the 288 public members lacks a worked
line of code, or an English one-liner has gained no Spanish twin.

| Volume | English | Español |
|---|---|---|
| 1 — install, the smallest thing that sends, OAuth2 setup, the demo | [Getting Started](https://claude.ai/code/artifact/9a35a14f-4479-46c6-b03d-66da4186438c) | [Primeros pasos](https://claude.ai/code/artifact/f96f229b-5344-499a-a9a7-f070e3d4343c) |
| 2 — the object model, MIME, OAuth2, and a Clarion notes chapter | [Programmer's Guide](https://claude.ai/code/artifact/b00929bb-198c-4afb-b303-22bbfdfd06b0) | [Guía del programador](https://claude.ai/code/artifact/f3e1c134-eca6-4292-9831-bf57d763f05f) |
| 3 — every template, tab and prompt, and the code it writes | [Template Guide](https://claude.ai/code/artifact/d8272efa-aa88-4ab6-a61d-79d147907f01) | [Guía de plantillas](https://claude.ai/code/artifact/07f9ecdf-232b-4cbd-8d20-f423561f3ba0) |
| 4 — every class, method, property and equate | [Reference](https://claude.ai/code/artifact/c98d7cfa-04e7-45ab-9054-9186cc2fbba5) | [Referencia](https://claude.ai/code/artifact/108af66d-ecbe-4a5b-bada-cb3500c741b6) |

**The ten templates.** Three application extensions — `emailToGlobal` (required once per app),
`emailToProviderApi` (the management object) and `emailToSync` (the tables to fill); three control templates —
`emailToButton` (compose, send, or open setup), `emailToApiButton` (opens the management window on whichever
tab you name, and hides itself when the account has no API) and `emailToSyncButton`; and four code templates —
`emailToSend`, `emailToCompose`, `emailToSetup` and `emailToApi` — for any embed.

**Installing it, Clarion 10 forward.** [`installer/emailTo/`](installer/emailTo/) builds a stand-alone
`emailToSetup.exe`: tick the Clarion installations you want, and each one gets the templates, the classes and
`emailc.c` in its `accessory\` folders and is registered with its own `ClarionCL /tr`. It finds them two ways
(the IDE's `ClarionProperties.xml`, and `Clarion*` on the fixed drives), reads each version off
`ClarionCL.exe`, and warns if the IDE is open — the IDE holds the template registry and writes it back on
close, which can quietly undo a registration made behind it.

**Two builds of the template, because the prompt sheet is not the same width.** AppGen draws prompts in a
dialog the IDE owns: **480 px up to Clarion 10, 960 px from Clarion 11** (`WideAppgenDialogs` in
`ClarionProperties.xml`). Nothing in the template language can ask which it is being drawn in — a prompt sheet
is parsed once, at registration — so [`Build-NarrowTpl.ps1`](templates/emailTo/Build-NarrowTpl.ps1) generates
`emailTo10.tpl` from `emailTo.tpl`: prose re-flowed to 340 px and eleven captions shortened to fit the 200 px
label column, every string **measured** in the system font rather than counted in characters. The installer
deploys whichever fits, always as `emailTo.tpl`. Both declare `#TEMPLATE(emailTo,...)`, and the generator
proves they are otherwise the same file — it strips both of exactly their `#DISPLAY` text and `#PROMPT`
captions and requires the remainder to be byte-identical, so no symbol, embed or generated line can drift
between them, and it exits non-zero (failing the installer build) if a future prompt stops fitting 480 px.
Tab height is deliberately *not* budgeted: Clarion 10's own `ABBROWSE.TPW` carries 91 prompts inside 35 boxes
on one tab, six times emailTo's heaviest, so the sheet plainly scrolls.

**v1.13 (2026-08-25).** emailTo compiles on Clarion 10 and 11. It never did: `'{"personalizations":['` and
619 other string literals hold a brace, and **`{` opens Clarion's repeat-count escape** — `'ab{3}'` is
`'abbb'`. Clarion 12 lets a `{` that no digits follow pass as text; 10 and 11 reject the literal outright with
*Invalid string (misused &lt;...&gt; or {...}, or literal is too long)*, and `EmailToClass.clw` alone failed on
34 lines. The portable spelling is `{{`, which is one `{` in every version — verified by compiling the same
program under all three and comparing the bytes it wrote, not by reading the manual. `EmailApiClass.clw` (590
of them, the whole provider matrix), `EmailToClass.clw` and `EmailJsonClass.clw` now say `{{`, and both demos
build clean under Clarion 10.0.12799, 11.0.13401 and 12.0.13941 — six builds, no errors.

**v1.12 (2026-08-24).** The account row from v1.11, drawn where it was meant to go. A control inside a `TAB`
is positioned against the **window**, not the sheet - so moving the `SHEET` down 40 units to make room moved
the frame and left all 49 controls exactly where they were, still drawing over the header that had just been
put above them. They move with it now.

Checked by walking the window structure and comparing rectangles - header ends at 40, sheet spans 44 to 258,
tab content 62 to 244, footer 262 to 278, window 284 - because this sandbox has no desktop and that arithmetic
is the only reviewer available. Two more from the same screenshot: the account drop list showed the bare name,
since a `LIST` with `FROM(queue)` displays the queue's **first** field whatever the FORMAT is named after; and
nothing repainted it after filling, so it opened blank. It selects the account actually loaded now, and
`DISPLAY`s.

**v1.11 (2026-08-24).** Reported as "the setup window saves to the wrong record" - and it never did. Both rows
were correct in the table; what was wrong is that the program **always reopened the first one**, because the
generated start-up line named it outright: `LoadAccount('default')`. Create a second account, restart, and you
are looking at the first one again, which reads exactly like the save went astray.

`RememberAccount` / `PreferredAccount` fix it. Saving an account or loading one from the picker remembers the
name, and start-up becomes `LoadAccount(PreferredAccount('default'))` - last chosen, falling back to the name
on the extension for a fresh installation, and falling back again if that account has since been deleted so a
remembered name can never strand a program on something that is not there. The name is a preference about this
machine rather than anything secret, so it lives in the INI even when the accounts live in a table.

The account row also moved **above the sheet**, where the report started: the name was on the *Advanced* tab,
which is the last place anyone looks for "which account am I editing". The window is now headed by
**Account:** with the drop list, **Load** and **Delete**, and **Save as:** underneath - visible from every tab
rather than filed under one.

Also a lesson about testing INI code: **Windows keeps written sections in a profile cache**, so `REMOVE()` on
the file leaves the previous run's values still answering `GETINI`. The account test was reading its own last
run and failing on the order; it clears the index through `PUTINI` now and passes twice running.

**v1.10 (2026-08-24).** Several providers configured at once. The store always allowed it - accounts are
named, and `LoadAccount('brevo')` reads INI section `[emailTo_brevo]` or the table row whose Name column says
`brevo`, each with its own provider, key, region and domain, nothing shared. What was missing was any way to
*find* them: typing a different name on the Setup window changed where it **saved**, never what it **loaded**,
so a second account could be created and then never reached again.

`ListAccounts()` and `DeleteAccount()` are both **VIRTUAL**, because the two stores answer the question in
completely different ways. An INI cannot be asked which sections it has, so the named ones keep an index of
their own in the base section, maintained by `SaveAccount`. A table just gets walked - and only the generated
code knows the table, so the template writes that override beside the `LoadAccount`/`SaveAccount` ones it
already generated. Without it the picker would have come up empty in exactly the applications that have a
settings table, which is most of them.

On the **Advanced** tab of the Setup window there is now a drop list of everything stored - `brevo - Brevo -
bulk@acme.com` - with **Load** and **Delete** beside it. Load switches the whole form to that account; the
name field above still creates one, by typing a new name and saving. The unnamed default is always row 1 and
cannot be deleted. Fourteen new assertions cover it, the sharpest being that a key belonging to one account is
not inherited by another.

**v1.09 (2026-08-24).** Amazon SES proved, without an Amazon account. `botocore` - the signing half of the AWS
SDK, written by Amazon - is not a dependency of anything shipped here; it is the **oracle**. A stand-in SES
re-signs every request that arrives with it and refuses the request unless our `Authorization` header matches
byte for byte. A wrong canonical request, signed-header list, payload hash, credential scope or derived key
all change the signature completely, so anything answered 200 was signed correctly. **Thirteen requests,
thirteen verified** - GET with a query string, GET with a continuation token, DELETE with `%2B` and `%40` in
the path (the double-encoded canonical path, the line I had flagged as most likely to be wrong), PUT with a
JSON body, POST with base64 MIME. 29 assertions, 0 failed.

It found two real defects that no unit test could have. **`DeleteContact` sent the address where the list
belonged**: most providers delete a contact by one value, so `{id}` and `{email}` were both filled with it,
and SES is the first provider that needs *both* - the list in one, the address in the other. Deleting a
contact from the management window would have hit
`/contact-lists/ann%40example.com/contacts/ann%40example.com` against the real service. It now takes an
optional list id, and the window passes the list you are looking at.

**And no send path honoured `ApiBase`** - not SES's, not any of the nine. The management half has always been
testable against a stand-in; the sending half never was, for anybody, which is why the REST transports have
sat at "unproven end to end" since v1.00. `EmailToClass.ApiUrl` now rewrites scheme and host for every
provider, and for SES it runs **before** the signature, because the host is signed. That is the change that
makes the send side testable at all - and the SES send is the first one actually proved.

**v1.08 (2026-08-24).** The management window, run in Spanish, translated everything except the one thing a
`FORMAT()` string owns. Title, all ten tabs, every button and prompt, the kind names (`Rebote`) and the row
count (`1207 filas`) came through - and then nine lists went on saying **Address, Kind, Reason, When**. A
list's headings are fixed at design time, so `NameEverything` had never been able to reach them; the strings
for all of them had existed since v1.03 and were simply never applied.

`NameColumns` now sets them by column number from the same table as everything else, across all nine lists -
blocked, statistics, activity, contacts, lists, campaigns, templates, senders and domains, webhooks. Found by
looking at a screenshot of the real thing: this window had never been *seen* until now, because the sandbox
that builds it runs on a window station with no desktop.

**v1.07 (2026-08-24).** A generate-time check, from a real report: an application with the **Mail account
button** on a window but no **Provider API** extension generated happily and then failed to compile with eight
errors - `Unknown function label`, `Field not found: SUPPORTS` - all of them on lines the developer never
wrote. The button writes `MailApi.Manage(1)`; only the extension declares `MailApi`; nothing connected the
two. This is v1.05's fix leaving a hole: moving the API onto its own extension stopped the *generator* error
for apps built before v1.03, but any app that had used the API **button** in the v1.03 era still generated
calls to an object that no longer had a declaration.

The check has to be built backwards, because a window generates **before** the global module does. At the
moment the button writes the call it cannot know whether anything will declare what it is calling - so it does
not guess. It records what it needs (`#ADD(%ETApiWanted, %Procedure)`), the Provider API extension records
that it exists, and **emailTo - Global** - the one extension every emailTo application carries - reports at
`PRIORITY(9000)` on `%AfterGlobalIncludes`, by which time the whole application is known. Now a missing
extension is one plain line naming the procedure and telling you where the Insert button is. Proved both ways
against generated applications: the app that has the extension builds its exe with no false alarm, the app
that lacks it stops with exactly one message. The same guard covers the API code template and the Sync
extension.

Two template-language facts fell out of it, both general. `#DECLARE` has **no `GLOBAL` attribute** and cannot
sit at file scope either - a symbol shared across sections belongs in `#SYSTEM`. And `%ProgramProcedures` is
**not** generated with the global module: like a window, it comes out in the procedure pass, so a check placed
there sees the global module's symbols still unset.

**v1.06 (2026-08-24).** **Amazon SES**, the ninth provider — and the first that will not answer a request just
because you attached a key. Every call has to be signed with **AWS Signature Version 4**, so the signing lives
on `EmailNetClass` (`SignAws`, over `Hmac256`, `Sha256Hex` and a derived key that walks date → region →
service → `aws4_request`) where both the sender and the management object can reach it. Sending posts the same
MIME the other transports build, base64'd into `/v2/email/outbound-emails`; the management side maps the
suppression list, contact lists and their members, identities and the account itself. SES pages with neither
an offset nor a cursor URL but a **continuation token**, which is a fourth paging style the engine now knows.

Two things worth remembering. The credential lands in a different place than everywhere else: **`ApiKey2` is
the access key id, `ApiKey` the secret, `ApiRegion` the region** — which leaves `UserName` and `Password` free
for the quite separate SMTP credentials SES also issues, so one account row can do both. And an empty HMAC key
is not an empty Clarion `STRING`: assigning `''` pads with **spaces**, which signs correctly-shaped garbage.
The zero-fill is explicit. The signer is checked against the RFC 4231 vectors and against Amazon's own worked
example, and the suite is 140 assertions green — but with no AWS account here, **SES has never been run
against the live service**; the canonical path's double-encoding is the line most likely to want a real reply.

**v1.05 (2026-08-24).** The upgrade friction from v1.03, fixed properly. The Provider API was a *tab* on the
global extension, and that broke every application built before v1.03: an app stores the set of prompts it was
built with, AppGen does not backfill one added later, and generation stopped with `Unknown Variable %ETgApi` on
a symbol nobody typed. It is now **`emailTo - Provider API`**, an extension of its own — an app that does not
add it never names its symbols, so anything older generates untouched. Verified both ways: a v1.02-era app
generates clean, and an app still carrying the v1.03 prompt values generates clean too (a stored value the
template no longer declares is simply ignored). The three account columns v1.03 added lose their prompts
entirely and are matched **by name** instead — call a column `ApiKey2`, `ApiRegion` or `ApiBase` and it is
filled, in both directions; `SaveAccount` never wrote them back before, and now does.

**v1.04 (2026-08-24).** The data half: a shipped dictionary and a sync into it. Also two template defects
this uncovered, both of which would have bitten any template that needs a table of its own:
`#ADD(%UsedFile, …)` fills a list nothing reads — what actually makes ABC declare the table and its
`Access:` FileManager is `#FIX(%File, …)` then `#SET(%CacheFileUsed, %True)`, and it has to happen at
`%BeforeFileDeclarations`, a DATA embed, because by `%ProgramSetup` the declarations are already written.
Without both, every `Access:<table>` line the template writes came back as *Unknown procedure label* on a
line nobody typed — which is exactly what the **account** settings-table binding had been doing since v1.00,
silently, for anyone whose table was not already in a browse.

Third, and the reason the sync is its own extension rather than two more tabs on the global one: **an
application stores the set of prompts it was built with, and AppGen does not backfill a prompt added later** —
generation stops with `Unknown Variable` on a symbol the developer never typed. An app that never adds the new
extension never names the new symbols, so every existing application keeps generating untouched. The
**Provider API** tab added in v1.03 had the same flaw, and v1.05 fixes it by moving it to an extension too. Verified by a harness that imports the shipped
`.dctx`, generates an application against it, compiles it, and runs the generated sync twice against a
stand-in provider: eleven rows into six tables, and eleven again the second time.

**v1.03 (2026-08-24).** The management half. Two new classes — `EmailJsonClass`, a real JSON reader in pure
Clarion (a sorted path index, so a 5,000-node reply answers a lookup in a dozen comparisons), and
`EmailApiClass`, the provider matrix — plus SparkPost and MailerSend as senders, three new account fields
(`ApiKey2` for Postmark's account token, `ApiRegion` for the European endpoints, `ApiBase` for a relay of
your own), a **Provider API** tab on the global extension, the `emailToApiButton` control template and the
`emailToApi` code template. Verified by 110 assertions in `apitest` — the parser, the four date shapes, URL
and body expansion, the matrix — of which 22 run the whole engine, paging and all, against a stand-in
provider on a local socket; by an AppGen-generated application that compiles; and by `emailBounceSync`, which
really does read a block list and mark the matching customers in a TPS table.

**v1.01 (2026-08-23).** The eighteen column prompts on the **Table** and **Table columns** tabs asked for
`COMPONENT(%ETgFile)`. `COMPONENT()` lists the component fields of a *key*, so the `...` lookup offered
nothing and typing a column by hand was rejected with *"Could not find mai:UserName in key 'mailAcct'"* &mdash;
AppGen was validating against the key on the tab above. Listing a table's columns is `FIELD(%ETgFile)`, which
is what all five templates now use. Every prompt sheet also carries a version and build stamp on its first
tab, so the registered copy identifies itself.

**v1.02 (2026-08-23).** Prompt clarity, after a report that two buttons on one window gave no clue which
one carried the sender's details. The answer is neither &mdash; the account belongs to the whole application &mdash;
but nothing said so. The control template now has an **Account** tab whose only job is to point at
*Global Properties &rarr; Extensions &rarr; emailTo - Global &rarr; Account*; the **Message** tab greys out entirely when the
action is *open the account setup window*, where none of it applied; the *After it runs* box greys unless the
action is *send straight away*, the only action that used it; and the three code templates carry the same
one-line signpost. The AppGen list also read `E-mail (1)` / `E-mail (3)` &mdash; the raw prompt number &mdash; and now
reads `E-mail button - opens ACCOUNT SETUP`, built with `CHOOSE()` in the `DESCRIPTION` so no stored value
moved. The code-generating half of the template is byte-identical: this release changes prompts only.

The manual was rebuilt and the four affected volumes republished. Volume 3 gains an **Account** and a
**Message** section under the e-mail button, and a note that answers the question the prompts had left open:
*which button holds the sender's address? Neither.* Volume 1 gains the same point where it first tells you to
add the extension and drop a button. Rebuilding also surfaced a latent generator bug: `secnav()` prints the
heading text back into the sidebar and `headings()` scrapes it out of already-escaped HTML, so `esc()` ran a
second time and a deliberate `&mdash;` reached the page as four literal characters &mdash; in the heading as well,
since `h2()`/`h3()` escaped their text where `p()` does not. Headings now take HTML like every other helper.

## Install

Copy the two folders into your Claude Code config (`~/.claude` on macOS/Linux,
`C:\Users\<you>\.claude` on Windows):

```sh
cp -r skills/clarion-template ~/.claude/skills/
cp agents/clarion-template-pro.md ~/.claude/agents/
```

Restart Claude Code (or start a new session) so the skill and agent are picked up.

### Every shipped class sits in its own `!ABCIncludeFile` category

Each class `.inc` in `templates/` carries its own category tag on line 1 — `!ABCIncludeFile(MYIMAGE)`,
`!ABCIncludeFile(MYCALC)`, and so on. This is not cosmetic. The ABC chain builds a data DLL's `.EXP` by
walking the IDE's **class registry** and exporting every registered class whose category is link-mode, with
**no check that your application actually uses the class** (`ABBLDEXP.TPW`). A bare `!ABCIncludeFile` puts a
class in the `ABC` category, which *is* link-mode in a data DLL — so every such class on your redirection
path gets exported from that DLL, and any whose `.clw` was never compiled in fails the build with

```
ADDMONTHS@F13CALENDARCLASSll is unresolved for export - data.exp:396,3
```

A private category is registered by nobody unless that template asks for it, so the class simply drops out of
the generated export list and links per-app as before. Only **myExport** registers its category today
(`MYEXPORT`), which is what lets one copy of `ExportClass` serve a whole multi-DLL suite.

Three consequences worth knowing:

- **When you upgrade, replace the `.inc` on your redirection path**, not just the one in your project — the
  registry reads *that* copy. A leftover bare-tagged one keeps the old behaviour.
- **A renamed or superseded class left on the redirection path will break a data DLL** even though no
  template references it any more, because the registry still finds it. Delete stale copies.
- **These files belong in `Accessory\libsrc\win` and nowhere else.** `CLARION120.RED` searches `.` (the app
  folder), then `%ROOT%\libsrc\win`, and only then `%ROOT%\Accessory\libsrc\win` — so a duplicate in an
  earlier folder *wins*, and updating the right copy fixes nothing. And because the class registry reads
  **every** copy while the compiler obeys precedence, a method whose signature changed between two copies is
  registered twice: the `.EXP` exports both spellings and the half that the compiled `.clw` doesn't implement
  comes out unresolved. **A class failing on only some of its methods is the signature of a duplicate `.inc`.**

Run [`installer/Check-InstalledClasses.ps1`](installer/Check-InstalledClasses.ps1) to audit all of that in one
command — it reports anything installed that is out of date, in the wrong folder, or still bare-tagged:

```powershell
.\installer\Check-InstalledClasses.ps1                      # report
.\installer\Check-InstalledClasses.ps1 -Fix                 # refresh stale copies from the repo
.\installer\Check-InstalledClasses.ps1 -RemoveMisplaced     # delete copies outside Accessory\libsrc\win
```

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

**myGauge gains a drag-on control template (v2.16).** Beyond the three extensions, myGauge now ships a **control
template** — **myGauge - Analog Gauge** — so you can drag a ready-made gauge straight onto a window from the
Window Designer's control toolbox: it drops the `IMAGE` *and* wires the gauge in one go. It's **fully
self-contained** — it emits `INCLUDE('GaugeClass.INC'),ONCE` at `%CustomGlobalDeclarations` (the per-module
compile-global embed, corpus `ABDROPS.TPW:65`), declares its own object, and draws on open/resize — so no
separate global extension is required, and `ONCE` keeps the class single-included even if you add one anyway.
The control's own field equate is captured with the proven `#FOR(%Control),WHERE(%ControlInstance=%ActiveTemplateInstance)`
idiom (corpus `CONTROL.TPW` *CloseButton*), so it tracks AppGen's auto-uniqued feq when several are dropped on
one window.

**myGauge rock-solid resize & multi-gauge redraw (v2.16).** The gauge now draws **into the IMAGE
control itself** rather than onto the window layer: `Draw(window, ?image)` uses the **two-argument
`SETTARGET(window, ?image)`**, so the graphics *belong to the image* and survive a `WM_PAINT`/resize
(a bare window-layer draw was getting wiped). With the image as the target, the origin is `0,0` and a
scoped **`BLANK`** clears **only that gauge's image** — so multiple dials on one window no longer erase
each other, and a gauge whose IMAGE sits away from the window's left edge is no longer clipped. Redraw is
driven by a **private per-instance `Redraw:<Object>` event** posted on `EVENT:OpenWindow` and after
`EVENT:Sized` (the resizer has settled, so the fresh size is read), and **`AnimStep` no longer self-draws**
— it just eases the needle one step and returns *moved*, leaving the caller (which holds the window handle)
to repaint. The `GaugeClass` `Draw` prototype is now `Draw(WINDOW pWin, SIGNED pImageFeq)`; **regenerate
any app** built against the older one-argument `Draw`.

**myCompress — a pure-Clarion compression library (v2.17).** A new [`templates/myCompress/`](templates/myCompress/)
adds DEFLATE / zlib / gzip **compression** to Clarion in pure Clarion — no DLL. One global object
(`CompressClass`) compresses and decompresses **memory buffers and files** in formats that interoperate
with gzip / 7-Zip / .NET; INFLATE is complete (stored + fixed + dynamic Huffman) and DEFLATE is LZ77 +
fixed Huffman, with CRC32/Adler32 checksums and a `SelfTest()`. Verified end-to-end against the real
Clarion compiler and a .NET golden-vector oracle ([`designer/CompressCore/`](designer/CompressCore/)) —
a string round-trips and the self-test passes. Three hard-won Clarion lessons came out of it and are now
baked into the `clarion-template` skill/notes: **a single array can't exceed 64 KB**, **class source must
be stored CRLF** (LF-only includes mis-compile as "Illegal data type"), and a **global object must not be
named after a file field** (e.g. `Zip`) or it collides. A `.gitattributes` rule now keeps all Clarion
source (`.tpl`/`.tpw`/`.inc`/`.clw`) CRLF.

**myPdfSign — read a signed PDF and see who signed it (v2.18).** A new [`templates/myPdfSign/`](templates/myPdfSign/)
adds a pure-Clarion **signed-PDF identity reader** — no DLL, no network. One global object (`PdfSignClass`,
default `PdfSig`) opens a digitally-signed PDF and reads the **authoritative signer identity** out of the
embedded **PKCS#7 / CMS** signature: the certificate Subject (`SubjectCN`/`SubjectO`/`SubjectOU`/
`SubjectEmail`), the issuing CA (`IssuerCN`), the `signingTime` (ISO-8601 UTC, from the signed attributes),
the dictionary's `/Name`/`/Reason`/`/Location`/`/SubFilter`, and **`CoversWholeFile`** (0 = bytes appended
after signing). It finds the `/ByteRange` + `/Contents <hex>` dictionary, hex-decodes the DER, and a small
**ASN.1 reader** walks to the signer cert's RDNs by OID — **identity + integrity only**, no RSA/ECDSA verify
or trust-chain validation. Verified against the real Clarion compiler and a .NET golden-fixture oracle
([`designer/PdfSignCore/`](designer/PdfSignCore/)) that **manufactures real signed PDFs** and publishes the
expected identity; the Clarion `Report()` matches **byte-for-byte across all three fixtures**, including a
tampered one that correctly reports `CoversWholeFile=0`. Programmer's manual in
[`docs/myPdfSign-template.html`](docs/myPdfSign-template.html).

**myCompress gains an optional C fast-path (~4× faster) (v2.19).** The compression template now ships an
optional **C engine**, [`templates/myCompress/mc.c`](templates/myCompress/mc.c) — our own clean-room DEFLATE
port (**not** miniz/zlib/StringTheory) compiled by **Clarion's own C compiler** (`Clacpp`) via
`PRAGMA('compile(mc.c)')`. Set `CmpUseC EQUATE(1)` and copy `mc.c`, and `CompressClass` routes through it:
a 4 MB buffer compresses in **~200 ms instead of ~844 ms** (and a touch smaller, since C has no Clarion
64 KB-array limit so it uses the full 32 KB window). It's the same algorithm, so both engines produce
byte-compatible output and interoperate freely. When `CmpUseC=0` (the default) every line of the C path is
`OMIT`ted — **no `mc.c` needed**, pure Clarion unaffected. Verified end-to-end against the real Clarion
compiler: the wired class round-trips, `SelfTest()` passes in both modes, and C inflate decodes .NET's
dynamic-Huffman gzip. Established a reusable lesson — **Clarion compiles bundled C** (`extern "C"` +
`PRAGMA('compile(x.c)')` + a `MODULE('x.c')` prototype block) — so future templates can drop to C for
hot paths without any external dependency.

**myCompress C fast-path becomes a template choice (v2.20).** The C engine switch moved from a hand-edited
equate into the **extension's prompt**. The C path is now a clean **subclass**, `CompressClassC` — it
overrides the (now `VIRTUAL`) `Wrap`/`Unwrap` to call `mc.c`, inherits the rest of the API unchanged, and is
selected by a *Compression engine: Pure Clarion / C (fast)* drop-list that simply declares the global object
as `CompressClass` or `CompressClassC`. So the choice lives in the template (no library edits), and a
pure-Clarion app pulls in **no `mc.c` and no subclass at all** — verified against the real Clarion compiler:
the C engine is 3.8× faster, both engines interoperate (compress with one, decompress with the other) and
pass `SelfTest()`, and a pure-Clarion build links clean with the C files entirely absent. The reusable
lesson — a **C fast-path as a `VIRTUAL`-override subclass** that the template selects — is captured for the
next template that wants one.

**myPie gains a drag-on control template + a drawing fix (v2.21).** myPie now ships a **control template**,
**myPie - Pie Chart**, so you can drag a ready-made chart straight onto a window from the control toolbox —
it drops the IMAGE *and* wires the pie + legend in one go, fully self-contained (no global/procedure
extension), with many per window. The drawing also moved to myGauge's **2-arg `SETTARGET(%Window,?image)`**
model: the IMAGE is the target (origin `0,0`), so the chart belongs to the control (survives a
repaint/resize) and a `BLANK` clears **only that image** instead of wiping the whole window — fixing
multiple pies (or other controls) erasing each other. The `myPieDraw` helper gained a leading `WINDOW`
parameter to match, so **regenerate** any app built against the old one. Validated against the real Clarion
compiler: the template registers cleanly (`ClarionCL -tr`) and the generated helper code compiles.

**myPie gains a live control-panel control template (v2.22).** A second pie control template, **myPie - Pie
Controls panel**, drops a ready-made panel of inputs — a 3D-depth **spinner**, show-legend / show-percentages
**checkboxes**, and up to six **slice-value spinners** — that drive a pie on the same window. Point it at the
pie by its **Name**; changing any input pushes the value into that pie's data and **POSTs its redraw**, so the
chart updates live. To make that possible, `myPieControl` now exposes depth / legend / percentages as
**run-time variables** (they were baked in at generation). The panel is `WINDOW` (one per window) so its
controls bind to fixed data labels, and it reads the pie's current values on open via a deferred sync event
(so it runs after the pie's `OpenWindow`). Validated against the real Clarion compiler: the template registers
(`ClarionCL -tr`) and the generated pie-draw + panel↔pie wiring compiles. Captures the reusable pattern —
**one control template that live-drives another via its Name + a private redraw event**.

**myPie panel ↔ pie link made robust + two bug fixes (v2.23).** The first cut of the live panel linked to a
pie by a typed **Name** — fragile (the pie auto-named itself `Pie7` while the panel defaulted to `Pie1`, so
they didn't connect) and it didn't compile. Reworked: the pie now **keys its data off its Image control's
field-equate** (no name prompt), and the panel links by **picking that Image** from a drop-list — both derive
the *same* data prefix from the *same* control (`SUB`/`INSTRING` strip the `?`/`:`), so they always match.
Two real Clarion bugs fixed in the process: the panel's input controls now declare their USE variables at
**`%DataSectionBeforeWindow`** (window controls can't forward-reference data declared after the window → it
was "Unknown identifier"), and the handler moved from `PRIORITY(2500)` to **`PRIORITY(2000)`** (2500 collides
with ABC's `TakeWindowEvent` scaffolding, mangling the generated `CASE`). Validated against the real Clarion
compiler: the template registers (`ClarionCL -tr`) and the reworked generated code compiles.

**my3D — drive real WebGL2 3D scenes from Clarion (v2.26).** A new template set: `WebGL2Class` (pure
Clarion) exposes a rich OOP 3D API — camera, ambient + directional + 8 point lights, materials, **20+ mesh
primitives**, per-mesh transforms, fog, grid, axes, and genuine `Vec3`/`Mat4` maths that run in Clarion —
and emits a **single self-contained `.html`** (scene data + the inlined `my3D.engine.js` WebGL2 renderer)
shown in the browser. A control template wires a whole scene from AppGen prompts. Verified end-to-end
against the real Clarion 12 compiler and headless-rendered to confirm it actually draws. See
[`docs/my3D-template.html`](docs/my3D-template.html).

**my3D — composite "special meshes" + WebGL2 *inside* a Clarion window (v2.27).** Ten real-world models
(car, airplane, rocket, wind turbine, robot, table, house, building foundation, skyscraper, trees) are now
one-call class methods — `AddCar(x,y,z,scale)` etc. — and appear in the template's Shape dropdown alongside
the primitives. And the scene can render **embedded in a Clarion window**: `ShowEmbedded()` docks a
borderless Edge `--app` window (real WebGL2, 120 fps) into the host with the Win32 `SetParent`. Edge runs in
its **own process**, which sidesteps the `ClaRUN` reentrancy crash an in-process WebView2 control causes — so
it needs **no DLL and no import lib**, only `user32`. The control template's **Show in** dropdown picks
External browser or Embedded; Edge's title bar is tucked out of view. Examples: a 20-fixture demo (with a
browser/embed toggle), a 10-model gallery, and a dedicated embedded viewer in [`examples/my3D/`](examples/my3D/).

**my3D — dock the WebGL2 view into a control, not just the whole window (v2.28).** `SetEmbedControl(?View)`
confines the docked Edge view to an **IMAGE/REGION** control's rectangle, so the rest of the window holds
ordinary Clarion buttons, lists, etc. The control is a layout placeholder with no HWND of its own, so the
class reads its **pixel rect** (`PROP:Pixels` + `PROP:Xpos/Ypos/Width/Height`) and hosts the view in a small
`WS_CLIPCHILDREN` child window at that rect — which also clips Edge's title bar even when the control isn't at
the top of the window, and re-fits as the control resizes. The control template's embedded option gains a
**Dock into this control** prompt; example [`examples/my3D/My3DInControl.clw`](examples/my3D/My3DInControl.clw)
renders the 3D in an IMAGE control with buttons beside it.

**my3D — interactive frameless overlay + HUD/FPS view options (v2.29).** The embedded view changed from a
*re-parented child* to an **owned overlay**: a re-parented cross-process Edge window can't receive input
(Chromium isn't built to be a foreign-process child), so the embed now keeps Edge a **top-level window**, set
as the Clarion window's **owner** (`GWL_HWNDPARENT`) and positioned over the host/control in screen
coordinates — which preserves **full native mouse + keyboard** (drag-orbit, wheel, R/space). It is stripped
to a **frameless, non-resizable** `WS_POPUP` sized to exactly the target, with `SetWindowRgn` clipping Edge's
title bar; call `EmbedFit()` on **EVENT:Sized and EVENT:Moved** so it tracks the window. New **view options**
`SetHud(on)`/`SetFps(on)` (and **Show info overlay** / **Show FPS** template checkboxes) toggle the on-screen
info box and the fps counter. Note: `my3D.engine.js` is read at run time — ship the matching version beside
the `.exe`.

**my3D — complete API reference (v2.29.1).** Added [`docs/my3D-reference.html`](docs/my3D-reference.html): an
exhaustive per-method/per-property reference for `WebGL2Class` — all 108 methods, each with **example code**,
grouped (lifecycle, page/canvas/view, background/fog, camera, lighting, chrome, material, meshes, composite
models, transforms, Vec3/Mat4, output, embedded display, internal), plus a constants table, a full properties
table with defaults, and recipes. The existing [`docs/my3D-template.html`](docs/my3D-template.html) remains
the guided tour and links to it.

**my3D — reliable cleanup of the embedded Edge view (v2.30.2).** The docked WebGL2 view is a separate
`msedge.exe` process tree; closing it with only `PostMessage(WM_CLOSE)` could leave **orphaned `msedge.exe`
processes** behind (Edge defers/ignores the message during shutdown, and it never reached the GPU/renderer/
network/crashpad child processes). `EmbedClose` now captures the Edge **browser PID** at embed time
(`GetWindowThreadProcessId`), still asks it to close gracefully first, then **guarantees** teardown of the
whole tree via a hidden `taskkill /F /T /PID` (launched with `CREATE_NO_WINDOW`, no console flash). A new
**`Destruct`** calls `EmbedClose` as a safety net, so the view is reaped even when the host forgets the
`EVENT:CloseWindow` handler or the app exits abnormally. Verified end-to-end: 7 Edge processes spawned, all
reaped within ~0.5 s of closing the window, zero leftovers.

**myQRDraw — clipped window Draw + a test program (v2.30.3, PR #19).** The window `QRCodeClass.Draw` now uses
the **two-argument `SETTARGET(Window, ?Image)`** (like myGauge) so the `BLANK` is **clipped to the image
rectangle** instead of the whole window — **multiple QR codes on one window no longer blank each other**, and
an image sitting away from the window's left edge is no longer clipped. With a real window target the paint
runs from a `0,0` origin, so `Paint` gained a `ZeroXY` flag, and `Draw` gained a `STRING` overload (it used to
take only `CSTRING`). A hand-driven test app, [`templates/myQRDraw/TestQRWnd_Renz.clw`](templates/myQRDraw/TestQRWnd_Renz.clw),
exercises every setting live with **two QR codes on one window** (proving one doesn't erase the other) and a
checkerboard for min/max module sizing. Thanks to **Carl T. Barnes** for the fix and test program.

**myQRDraw & myBarcodeGen — `STRING` parameters, failure-aware `Draw`, overridable methods (v2.30.4, PRs #20 & #21).**
The class method parameters moved from `(*CSTRING)` to standard Clarion `(STRING)` (PR #20 for `QRCodeClass`,
PR #21 for `BarcodeClass`/`AztecClass`/`DataMatrixClass`/`Pdf417Class`) — more idiomatic for Clarion developers
and non-breaking, since the RTL still converts a passed `CSTRING` to `STRING`. Every `Draw` now returns a
**`BOOL`** — `False` when it can't paint (typically an invalid value for the type, e.g. a non-numeric UPC-A), so
the caller can surface the error — and many methods became **`VIRTUAL`** so the classes can be derived and
overridden. `EanCheckDigit`/`UpcCheckDigit` now bound their loop to the passed string's `SIZE()` to avoid an
invalid `[slice]`. Both sets of changes were verified to compile clean against Clarion 12. Thanks again to
**Carl T. Barnes**.

**myYuru — Direct2D backend now follows window resizes (v2.30.5).** The GPU direct-to-window host was sized
**once**, lazily, on the first Direct2D frame and then frozen: when the window (and an anchored `IMAGE`
control) grew, the child host window and its render target kept their original size, so the animation stayed
boxed in the old rectangle. The class now re-reads the control's pixel rect each Direct2D frame and, only when
it actually changed, moves/resizes the child host (`yuru_d2d_move_child`) **and** resizes the GPU back buffer
(new `yuru_d2d_resize` → `ID2D1HwndRenderTarget::Resize`, bound at vtable index 58 and called outside the
`BeginDraw`/`EndDraw` pair). The template also repaints on `EVENT:Sized` so a paused animation re-syncs at
once. The BMP-file backend was never affected (the `IMAGE` control scales itself).

To package everything (designer **+** templates **+** skill **+** agent) into one deliverable — .NET is
bundled in, so nothing needs pre-installing on the target:

```powershell
pwsh installer\build-installer.ps1   # -> installer\Output\ClarionTemplateToolsSetup.exe (full installer)
pwsh installer\build-portable.ps1    # -> run\ClarionTemplateDesigner.exe (portable single-file exe)
```

See `installer/README.md` for what each option installs.

One template can also ship on its own. [`installer/emailTo/`](installer/emailTo/) builds
**`emailToSetup.exe`**, which finds every Clarion **10 or later** on the machine — from the IDE's own
`ClarionProperties.xml` and from a sweep of the fixed drives — and installs emailTo into the ones you tick,
registering each with that installation's own `ClarionCL`:

```powershell
pwsh installer\emailTo\build-emailTo.ps1     # -> installer\emailTo\Output\emailToSetup.exe
```

Clarion 10 gets a different build of the template — see below — and uninstalling unregisters it again.

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

## Acknowledgements

A good part of what is here arrived as a pull request from someone else, and several of the sharpest bugs
were found by people running these templates in real applications rather than in a demo. Named below, with
the numbers, so the work can be read in full.

| | |
|---|---|
| **[Mark Sarson](https://github.com/msarson)** | The **visual designer**, largely rebuilt from the inside: several templates open at once with a tab each, external edits to an open `.tpl` detected and offered for reload, the source editor scrolled to whatever part is selected, and the part/tab, undo/redo and panel view-sync bugs cleared out. Then the layout engine — `#BOXED,SECTION` honoured as the origin for `AT`, `#INSERT(%group)` resolved in the prompt tree *and* in the flow preview, auto-flow reserving the label column and an `#IMAGE`'s real footprint so nothing lands off-canvas or underneath, no reparenting on a plain click, `#ENABLE` membership never silently stripped — and characterization tests to keep it that way.<br><sub>[#2](https://github.com/robertorenz/templatemaker/pull/2) · [#3](https://github.com/robertorenz/templatemaker/pull/3) · [#4](https://github.com/robertorenz/templatemaker/pull/4) · [#6](https://github.com/robertorenz/templatemaker/pull/6) · [#7](https://github.com/robertorenz/templatemaker/pull/7) · [#8](https://github.com/robertorenz/templatemaker/pull/8) · [#9](https://github.com/robertorenz/templatemaker/pull/9) · [#11](https://github.com/robertorenz/templatemaker/pull/11) · [#12](https://github.com/robertorenz/templatemaker/pull/12) · [#13](https://github.com/robertorenz/templatemaker/pull/13) · [#14](https://github.com/robertorenz/templatemaker/pull/14) · [#15](https://github.com/robertorenz/templatemaker/pull/15)</sub> |
| **[Dinko Bačun](https://github.com/bdinko)** <sub>(Indicio d.o.o.)</sub> | Made the toolkit work on **somebody else's machine**: the Clarion install auto-detected instead of hardcoded to `C:\clarion12`, `<CLARION_ROOT>` placeholders through the skill and agent docs so the corpus paths survive a different version, an installer that ships *every* template together with the classes they need to compile, and the `d2gridleg.c` rename that let the installer stage both grids at once.<br><sub>[#1](https://github.com/robertorenz/templatemaker/pull/1) · [#22](https://github.com/robertorenz/templatemaker/pull/22) · [#28](https://github.com/robertorenz/templatemaker/pull/28) · [#31](https://github.com/robertorenz/templatemaker/pull/31)</sub> |
| **[Carl T. Barnes](https://github.com/CarlTBarnes)** <sub>([carlbarnes.com](https://www.carlbarnes.com))</sub> | Read the Clarion source the way only long practice lets you: `SetTarget(Window, Image)` in **myQRDraw** so the symbol lands on the control instead of at the window origin — with a test program to prove it — and `STRING` in place of `*CSTRING` through the class and the barcode method parameters. Plus the **myGauge** and **myPie** reports below.<br><sub>[#19](https://github.com/robertorenz/templatemaker/pull/19) · [#20](https://github.com/robertorenz/templatemaker/pull/20) · [#21](https://github.com/robertorenz/templatemaker/pull/21)</sub> |
| **[John Hickey](https://github.com/ClarionLive)** <sub>(ClarionLive)</sub> | The **Legacy (CW20) chain**: `BrowseGridLeg`, the Direct2D grid carried over to a chain that has no ABC objects to hang it on, with word wrap and rows that grow only as far as their text needs — and the corrections and Legacy/CW20 chapter that the port turned up in the `clarion-template` skill. Also the **myFilter** bug where a filter whose name contained `=` could never be loaded back.<br><sub>[#26](https://github.com/robertorenz/templatemaker/pull/26) · [#27](https://github.com/robertorenz/templatemaker/pull/27) · [#29](https://github.com/robertorenz/templatemaker/pull/29)</sub> |
| **[Adrian E. Santarelli](https://github.com/asantarelli)** <sub>([SDigitales](https://www.sdigitales.com.ar))</sub> | **SDAspecto** — one look for every window in a program, from a cascading rule engine whose rules live in an INI rather than in code. **BrowseGrid v1.24**: totals, text search, check-box columns, auto-fit widths and the help page the template had been missing — then **v1.25**, where `d2g_PageSize` was the one row-area measurement that did not take the horizontal scrollbar off, so the browse loaded a last record it then drew behind the bar. And **graficaBarra v2.1**, the **combo chart**: a series told to draw as a **line** over the bars off the same value axis, taking no room in the category slot and keyed in the legend with a line rather than a block; a cell that can hold **no value**, so a trend breaks instead of diving to zero next to an average bar; the chart carrying **its own type**, with the layout scaling to the size so labels thin out rather than collide; and the *Look* tab split in three once thirty prompts had run off the screen.<br><sub>[#32](https://github.com/robertorenz/templatemaker/pull/32) · [#33](https://github.com/robertorenz/templatemaker/pull/33) · [#34](https://github.com/robertorenz/templatemaker/pull/34) · [#35](https://github.com/robertorenz/templatemaker/pull/35)</sub> |

**Bugs found and reported.** [Carl T. Barnes](https://github.com/CarlTBarnes) on `myPie` positioning the pie at
`(0,0)` instead of the image's own X,Y ([#5](https://github.com/robertorenz/templatemaker/issues/5)), and on
`myGauge` three times over — custom angles refusing a negative under `@n7.1`
([#16](https://github.com/robertorenz/templatemaker/issues/16)), `.TextColor` doing nothing for `SHOW()` of the
title or units ([#17](https://github.com/robertorenz/templatemaker/issues/17)), and `Preset` writing bad values
for 90° ([#18](https://github.com/robertorenz/templatemaker/issues/18)).
[Mark Sarson](https://github.com/msarson) on the designer destructively rewriting valid templates on save
([#10](https://github.com/robertorenz/templatemaker/issues/10)), described precisely enough to be fixed from the
report alone. [Dinko Bačun](https://github.com/bdinko) on the installer failing because two templates each
shipped a different `d2grid.c` ([#30](https://github.com/robertorenz/templatemaker/issues/30)).
[antonnagel](https://github.com/antonnagel) on `ExportClass.inc`
([#23](https://github.com/robertorenz/templatemaker/issues/23)) and on BrowseGrid
([#25](https://github.com/robertorenz/templatemaker/issues/25)).
[golmedo](https://github.com/golmedo) proposed the `graficaBarra` per-category legend detail, percent-of-total
and left-aligned labels ([#24](https://github.com/robertorenz/templatemaker/pull/24)).

Everything above is MIT-licensed along with the rest of the repo; the copyright in each contribution stays with
whoever wrote it.

## License

Released under the [MIT License](LICENSE) — © 2026 Reddin Assessments. Free to use, modify, and
distribute; provided "as is" without warranty.
