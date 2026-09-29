# Draw natively, remembering the device R opens when none is open

With no device open, drawing opens R's default device, which stays
current: [`pdf()`](https://rdrr.io/r/grDevices/pdf.html) on `Rplots.pdf`
in a session with no display, or an IDE's own `pdf(NULL)`. The reader
chose no file, so it is remembered as their screen
([`remember_default_device()`](https://r.maidr.ai/reference/remember_default_device.md)).

## Usage

``` r
draw_on_default_device(drawing)
```

## Arguments

- drawing:

  The drawing, evaluated here.

## Value

What `drawing` evaluates to, with its visibility
