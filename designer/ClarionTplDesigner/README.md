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
- **Renders** the selected tab on a canvas: boxes as group frames, prompts/displays/images as chips with
  their real font/colour. Layout honours explicit `AT(x,y)`; everything else is stacked (approximate).
- **Drag to move** a control — live `AT()` shown in the status bar and the Properties panel.
- **Rulers** (top + left) in dialog units, with a live cursor marker.
- **Guides** — drag from a ruler (top ruler → vertical guide, left ruler → horizontal guide), or use the
  *+ V/H guide* buttons. Drag a guide to reposition; double‑click to delete.
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
