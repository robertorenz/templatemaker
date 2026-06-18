# Clarion Template Designer (MVP)

A small **.NET 9 / WPF** visual designer for the *prompt UI* of a Clarion template (`.tpl`/`.tpw`).
Clarion gives you no WYSIWYG for template prompts — you hand‑code `AT(x,y,w,h)` and round‑trip through the
IDE. This tool reads the `#SHEET … #ENDSHEET` section, renders each `#TAB`'s controls at their `AT()`
positions, and lets you **drag them around** with **rulers, draggable guides, and snapping**, then writes
the new coordinates back — touching *only* the `AT()` values, never the generation code.

## Run

```sh
cd designer/ClarionTplDesigner
dotnet run
```

Then **Open .tpl…** and pick e.g. `..\..\templates\AJEBackupAPP.tpl`.

## What it does

- **Flow preview** — *View ▸ Flow preview* (or the **Preview** toolbar toggle) shows the part the way Clarion
  actually auto‑lays out a prompt window: real controls stacked top‑to‑bottom (ignoring `AT()`), in the
  caption / control / button columns — entries with a `…` button, `PROCEDURE`/`FILE`/`DROP` dropdowns, spins,
  checkboxes, option/radio groups, multiline text, tabs and group boxes auto‑sized. (Approach modelled on the
  CapeSoft *clavte* editor's previewer.) **Click a control in the preview to select it** (Ctrl‑click to
  multi‑select), then change its font/size/bold/colour/text from the Style bar or right‑click → *Font &
  Colour…* / *Delete* — the preview updates live. (Free XY dragging stays in the positioner; in a flow layout
  "move" means reordering, a separate operation.)
- **Live source** — tick **Live (pending)** in the Source panel to see the file *as it would be saved*,
  reflecting every unsaved edit (moves, styles, inserts, deletes, reparents) in real time — read‑only, nothing
  written to disk until you Save. Untick it to hand‑edit the on‑disk source again.
- **Whole template set** — opening a `.tpl` also follows its `#INCLUDE('…​.tpw')` files and parses **every
  component** (`#EXTENSION/#CONTROL/#PROCEDURE/#CODE/#GROUP/…`). A **Part** dropdown lists each component that
  has a prompt sheet (showing which file it's in); pick one to edit its tabs. **Save writes each file
  separately** — only files you actually changed are rewritten, so untouched `.tpw` includes are left alone.
- **Parses** `#SHEET/#TAB/#BOXED/#BUTTON/#ENABLE/#PROMPT/#DISPLAY/#IMAGE`, including each element's
  `AT()` and `PROP(PROP:Font/FontColor/FontSize/FontStyle)`.
- **Renders** the selected tab on a canvas: boxes as group frames, prompts/displays as chips with their
  real font/colour, and **`#IMAGE` controls as the actual PNG/ICO** (resolved next to the `.tpl`, then in
  `C:\clarion12\accessory\template\win` and `C:\clarion12\images`; missing files fall back to a 🖼 filename
  chip). Layout honours explicit `AT(x,y)`; everything else is stacked (approximate).
- **Prompt simulation** — each prompt renders like its real row: the caption, a faux entry field, and (for
  the auto-built types) a ▾ dropdown or `…` lookup button; `CHECK` shows a checkbox. So a tab reads close to
  the actual Clarion prompt window. A `KEYCODE` prompt's `default(...)` is decoded to its hotkey (e.g.
  `default(633)` → **CtrlF10**), shown in the field and in the Properties panel.
- **Prompt-type awareness** — prompts that Clarion auto-builds with extra UI (a `PROCEDURE`/`FILE` dropdown,
  or a `…` lookup button for `KEYCODE`/`EXPR`/`OPENDIALOG`/font/colour pickers) render with a ▾/… affordance
  on the canvas, and the Properties panel describes the type and warns that these flow automatically — giving
  them an explicit position can move or hide the auto-generated part. **"Add AT to all" skips these prompts**
  (and warns first), so the bulk action can't pin and misplace the auto-built dropdown/`…` — you can still
  position one deliberately by dragging it.
- **Add controls** — an *Add:* command bar inserts new controls into the current tab: **Label** (`#DISPLAY`),
  **String** (`#PROMPT @s255`), **Number** (`#PROMPT @n8`), **Spin**, **Check** (`#PROMPT CHECK`),
  **Image** (`#IMAGE`), and **Group box** (`#BOXED … #ENDBOXED`). New controls drop onto the canvas ready to
  drag; set their text/label/filename in the Properties panel. New prompts get a unique `%NewFieldN` symbol
  (rename it in the panel). On **Save** the directive line(s) are written just before the tab's `#ENDTAB`, and
  the file is re-read so the model stays in sync.
- **Drag to move** a control — live `AT()` shown in the status bar and the Properties panel.
- **Group containment** — drop a control inside a `#BOXED` group to make it a child of that group (its `AT`
  becomes frame‑relative); drag it out to move it back to the tab. **Moving a group box carries all its
  controls with it.** Selecting a group lists its contents in the Properties panel (click an entry to select
  that control). On Save the relocated control's source line moves into/out of the box's block — verbatim
  (styling preserved), only its `AT` updated.
- **Images** — when an `#IMAGE` is selected the Properties panel shows a **…** browse button (pick a file;
  a bare name is stored if it's in a known image folder, else the full path) and a **↻ Refresh** button to
  reload the file and re‑render after you change it or type a new name.
- **Resize handles** — select a control and drag any of the 8 handles (corners + edge midpoints) to set
  its width/height (and X/Y for top/left edges). Snaps to grid and guides just like moving.
- **Add AT to all** — one button stamps every control with an explicit `AT(x,y,w,h)` taken from the current
  layout, filling only the *missing* slots (existing coordinates are kept). Turns the approximate flow
  layout into concrete, draggable coordinates across every tab so you can position anything.
- **Z-order** — *Order: Front / ↑ / ↓ / Back* on the toolbar (or right-click a control) raises/lowers it so
  you can see and grab controls hidden underneath. This is a *view* aid in the designer; it does not reorder
  the generated source.
- **Delete** — select a control and press **Delete** (or right-click → *Delete*) to remove it. On **Save**
  the control's source line is dropped; deleting a `#BOXED` removes the whole block through its `#ENDBOXED`.
  Nothing is written until you Save, so re-opening the file undoes a delete.
- **Symbol‑reference safety** — if a control's `%symbol` is used elsewhere in the template (the generation
  /logic code, an `#ENABLE(%sym)`, a `#BUTTON` format…), the Properties panel shows a ⚠ banner naming the
  symbol and how many other lines use it, and deleting pops a confirmation listing those exact line numbers
  so you don't silently break code generation.
- **Rulers** (top + left) in dialog units, with a live cursor marker.
- **Guides** — drag *down* from the top ruler for a horizontal guide, *right* from the left ruler for a
  vertical guide (or use the *+ V/H guide* buttons). Hold **Ctrl** while dragging to snap the guide to the
  ruler's labelled segments. Drag a guide to reposition; **drag it back onto a ruler to delete it** (it turns
  red as you hover the ruler), or double‑click it.
- **Snapping** — to the grid (configurable size) and to guides; toggle each independently.
- **Source panel** — the *⌗ Source* toggle opens a resizable, syntax-coloured view of the current part's
  file (powered by **AvalonEdit**): directives, `%symbols`, `'strings'` and `!`/`#!` comments are coloured,
  with line numbers. **Clicking a control jumps the source to that control's line** (caret + highlight). It's
  **editable** — type changes and **Apply** writes them to the file and re-parses (refreshing the canvas);
  **Revert** reloads from disk. (Applying re-reads the file, so save canvas edits first.)
- **Dockable panels** — the **Source** and **Properties** panels are full **AvalonDock** panels: drag a panel's
  header to dock it on any edge of the designer, drop it onto another panel to tab them, or tear it off into a
  **floating window**; resize with the splitters. *View ▸ Source panel* shows/hides the Source panel. The
  layout is **remembered between sessions** (saved on close); *View ▸ Reset panel layout* restores the default.
- **Menus & toolbars** — a **File / Edit / Insert / Arrange / Style / Guides / Preferences / View** menu bar
  holds the one‑click actions. The toolbar has three rows: **live controls** (Part, Tab, Zoom, grid size); a
  **Style bar** (a **Text** box, **Font** dropdown, **size** box, **B**, **A▲/A▼**, **Colour…**, **Font…**)
  acting on the current selection; and an **Add bar** (Label/String/Number/Spin/Check/Image/Group box). **Preferences** has
  checkable toggles: **Show grid** (draws the snap grid on the canvas), **Snap to grid**, **Snap to guides**,
  and **Show minimap**. These (plus zoom and grid size) are **remembered between sessions**.
- **Minimap** — a code‑overview strip beside the source (each line a coloured bar — comments/directives/symbols
  — with a viewport box); click or drag it to jump the editor. Toggle via *Preferences ▸ Show minimap*.
- **Selection ↔ source** — selecting one or several controls band‑highlights their lines in the Source panel
  (and scrolls to the primary), so a multi‑selection lights up every matching line at once.
- **Click vs. drag** — clicking a control only *selects* it; it moves only once you actually drag past a few
  pixels (so snap‑to‑grid no longer nudges a control on a plain click).
- **Multi‑select** — **Ctrl+click** toggles, **Shift+click** adds, or **drag a marquee** on empty canvas to
  rubber‑band several controls. Font / size / bold / colour, **delete**, and **drag‑move** then apply to the
  whole selection at once (a selected group box carries its contents).
- **Undo** — **Ctrl+Z** (or the *↶ Undo* button) reverts the last change, step by step, all the way back:
  moves, resizes, reparents, adds, deletes, z-order, text/coord edits, and guide changes. History is kept
  per editing session and cleared when you open a file or after a structural save.
- **Font / colour / size editing** — change a control's **font, size, bold and colour** and it updates on the
  canvas *and* in the source (the `PROP(PROP:Font/FontColor/FontSize/FontStyle)` clauses are rewritten on
  save; existing clauses are replaced in place, new ones appended, and a removed colour is deleted). Three
  ways: the **STYLE** section in the Properties panel (font dropdown, size, Bold, colour swatch + picker), the
  **Style:** command bar (Font &amp; Colour…, Colour…, **B**, A▲/A▼), or **right-click → Font &amp; Colour…** on
  any control (a full font+style+colour dialog).
- **Properties panel** — edit X/Y/W/H directly (arrow keys nudge, Shift = ×5); for prompts it names the
  type, and a read-only **Source** box shows the control's raw directive line so you can see its full
  definition (`default(...)`, `req`, `prop(...)`, `at(10)`, …).
- **Save** rewrites each moved control's `AT()` in place; every other byte (PROPs, symbols, and the whole
  `#AT/#GROUP/#RUN` generation half) is preserved.

## Known limits (MVP)

- The flow layout for controls *without* `AT()` is approximate — Clarion's exact auto‑stacking isn't
  replicated. Dragging such a control converts it to an explicit `AT()` (frame‑relative).
- DLU→pixel is a fixed scale (zoomable); the preview is *close*, not pixel‑identical to Clarion, so a final
  glance in the IDE is still wise — but with far less guess‑and‑check.
- Reads the **first** `#SHEET` of each component. `#BUTTON(MULTI)` row editors render as a single chip.

## Files

| File | Role |
|------|------|
| `Tpl.cs` | element model, parser, and the byte‑safe writer |
| `Layout.cs` | approximate prompt‑sheet layout (AT + flow stacking) |
| `Ruler.cs` | the DLU ruler control |
| `MainWindow.xaml(.cs)` | the designer canvas, drag, guides, snapping, properties |
