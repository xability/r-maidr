# lattice Utilities

What the lattice system needs to know about a trellis object before and
after it is drawn: which high-level function and panel function made it,
how its packets are laid out on the page, how its labels read, and how
the grobs lattice draws are addressed in the exported SVG.

## Details

Everything here reads the trellis object's own fields or lattice's
exported API. lattice ships as byte code without its sources, and its
internals (`lattice:::compute.layout()`, `lattice:::getLabelList()`) are
re-implemented here rather than reached with `:::`, so a change to them
shows up as a failing test rather than as a silent change in reading.
The one internal touched is lattice's record of the chart it drew last,
which cannot be re-implemented:
[`lattice_draw_scene()`](https://r.maidr.ai/reference/lattice_draw_scene.md)
puts it back as it was after drawing, and does nothing should it move.
