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

- **Parses** `#SHEET/#TAB/#BOXED/#BUTTON/#ENABLE/#PROMPT/#DISPLAY/#IMAGE`, including each element's
  `AT()` and `PROP(PROP:Font/FontColor/FontSize/FontStyle)`.
- **Renders** the selected tab on a canvas: boxes as group frames, prompts/displays as chips with their
  real font/colour, and **`#IMAGE` controls as the actual PNG/ICO** (resolved next to the `.tpl`, then in
  `C:\clarion12\accessory\template\win` and `C:\clarion12\images`; missing files fall back to a 🖼 filename
  chip). Layout honours explicit `AT(x,y)`; everything else is stacked (approximate).
- **Drag to move** a control — live `AT()` shown in the status bar and the Properties panel.
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
  Nothing is written until you Save, so re-opening the file undoes a delete. (As with any edit, if the removed
  prompt's `%symbol` is referenced by the template's generation code you'll need to fix that up in the IDE.)
- **Rulers** (top + left) in dialog units, with a live cursor marker.
- **Guides** — drag *down* from the top ruler for a horizontal guide, *right* from the left ruler for a
  vertical guide (or use the *+ V/H guide* buttons). Hold **Ctrl** while dragging to snap the guide to the
  ruler's labelled segments. Drag a guide to reposition; **drag it back onto a ruler to delete it** (it turns
  red as you hover the ruler), or double‑click it.
- **Snapping** — to the grid (configurable size) and to guides; toggle each independently.
- **Properties panel** — edit X/Y/W/H directly; arrow keys nudge (Shift = ×5).
- **Save** rewrites each moved control's `AT()` in place; every other byte (PROPs, symbols, and the whole
  `#AT/#GROUP/#RUN` generation half) is preserved.

## Known limits (MVP)

- The flow layout for controls *without* `AT()` is approximate — Clarion's exact auto‑stacking isn't
  replicated. Dragging such a control converts it to an explicit `AT()` (frame‑relative).
- DLU→pixel is a fixed scale (zoomable); the preview is *close*, not pixel‑identical to Clarion, so a final
  glance in the IDE is still wise — but with far less guess‑and‑check.
- Reads the **first** `#SHEET` (the global extension). `#BUTTON(MULTI)` row editors render as a single chip.

## Files

| File | Role |
|------|------|
| `Tpl.cs` | element model, parser, and the byte‑safe writer |
| `Layout.cs` | approximate prompt‑sheet layout (AT + flow stacking) |
| `Ruler.cs` | the DLU ruler control |
| `MainWindow.xaml(.cs)` | the designer canvas, drag, guides, snapping, properties |
