# Group Device Calls into Plot Units

Groups the calls a device shows into logical plot units: those drawn on
its last page, with every layout call (`last_page_calls()`). R's device
shows only the page drawn last, so a plot that started a page of its own
– the second of `hist(a); hist(b)` – leaves the plots before it out.
Each group contains one HIGH-level call, or a LOW-level one that started
a plot of its own (`starts_base_r_plot()`), and the LOW-level calls
drawn on its plot. A LOW-level call drawn on a plot no recorded call
started – a panel [`plot.new()`](https://rdrr.io/r/graphics/frame.html)
or [`frame()`](https://rdrr.io/r/graphics/frame.html) took, as for a
legend of its own, or a plot maidr does not record, such as
[`smoothScatter()`](https://rdrr.io/r/graphics/smoothScatter.html) – is
not one of them: it is kept, to be drawn where R drew it, with the group
drawn after it (`before_calls`), or, after the last, with the last
(`after_calls`). One drawn on a plot started over the group's own, in
its panel, after `par(new = TRUE)`, is one of them, marked `overlay`: it
is drawn on that plot, in the coordinates it was drawn in
(`drawn_over_group_plot()`). One drawn on a plot started over an earlier
group's, in its cell or screen, after `par(mfg = )` or
[`screen()`](https://rdrr.io/r/graphics/screen.html) sent R back there,
is read with that group, marked `overlay` and `read_only`, and drawn
with the calls on plots no recorded call started, in its place among
them (`drawn_over_earlier_plot()`). One drawn after `par(mfg = )` or
[`screen()`](https://rdrr.io/r/graphics/screen.html) sent R back to the
cell or screen of an earlier group's plot, without starting a plot, is
one of that group's, marked `sent_back`: R draws it there, on that plot,
in the coordinates R had (`sent_back_to()`). One R clipped away, as it
does what [`screen()`](https://rdrr.io/r/graphics/screen.html) sends it
back to draw before anything works its clip out again, is in no group
(`clipped_away_calls()`).

## Usage

``` r
group_device_calls(device_id = grDevices::dev.cur())
```

## Arguments

- device_id:

  Graphics device ID

## Value

List of plot groups, each containing HIGH and LOW calls
