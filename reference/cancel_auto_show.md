# Cancel a pending auto-show callback

Removes by NAME rather than by the index
[`addTaskCallback()`](https://rdrr.io/r/base/taskCallback.html)
returned: that index is a position in R's callback list, and any other
package adding or removing a callback in the meantime shifts it.
Removing a stale index silently deletes an unrelated package's callback.

## Usage

``` r
cancel_auto_show()
```
