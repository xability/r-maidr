# Keep the points curve() itself evaluated

curve() returns, invisibly, the exact x/y vectors it just drew. Keeping
them means the accessible data is read back from the user's own call –
evaluated once, at the moment it was made, in the frame that made it.

## Usage

``` r
curve_recorded_values(recorded_args, result)
```

## Arguments

- recorded_args:

  Recorded (unevaluated) argument list of the call

- result:

  The value curve() returned

## Value

A list with `x`, `y` and `labels`, or NULL when the returned value is
not a usable pair of coordinate vectors

## Details

The alternative – re-deriving the points when the figure is emitted –
means running user code a second time, later, in a rebuilt frame. That
is the failure mode \#59 fixed for `for` loops, where every panel
replayed the last iteration's bindings; snapshot_call_env() narrows the
window but cannot close it, and the recorded call alone is not enough
anyway: `from`/`to` arrive unevaluated too (`to = 2 * pi` is recorded as
a call), so emit time would have to redo curve()'s own seq/log/xname
handling on top of evaluating the expression. Reading back what was
drawn is neither. The SVG still comes from replaying the call, so a
deliberately non-deterministic expression can draw a second, different
curve – that is true of every recorded call and is not made worse here.

The values are stored under a `.maidr_` name, so clean_maidr_args()
drops them before the call is replayed.
