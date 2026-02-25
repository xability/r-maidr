# Schedule auto-show after the current top-level expression completes

Uses R's task callback mechanism. When a HIGH-level plot function is
called, this schedules \`show()\` to run after the expression finishes.
If another HIGH-level function is called in the same expression, the
previous callback is replaced (only one auto-show fires per expression).

## Usage

``` r
schedule_auto_show()
```
