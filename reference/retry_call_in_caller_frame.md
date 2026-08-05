# Retry a failed plot call from the caller's own frame

The formula methods resolve non-standard arguments relative to
\`parent.frame()\`: \`plot.formula()\` evaluates \`subset =\` there, and
\`boxplot.formula()\` reaches into the caller's \`...\`. A wrapper puts
its own frame in that position, so calls that work in plain R fail
through maidr:

## Usage

``` r
retry_call_in_caller_frame(
  original_function,
  recorded_call,
  caller_env,
  original_error
)
```

## Arguments

- original_function:

  The unwrapped plotting function

- recorded_call:

  \`match.call()\` captured by the wrapper

- caller_env:

  The wrapper's calling frame

- original_error:

  The error condition the direct call raised

## Value

Result of the retried call

## Details


    plot(y ~ x, data = d, subset = g == 1)   # object 'g' not found
    boxplot(y ~ g, data = d, subset = x > 5) # ..3 used in an incorrect context

Rebuilding the call and evaluating it in the caller's frame gives those
methods the frame they expect. This runs only after the direct call has
already failed, so working calls keep the single-evaluation fast path
and a genuinely invalid call still reports its original error.

Known trade-off: on this retry path an argument can be evaluated more
than once. The failed first attempt already forced some promises, the
rebuilt call evaluates the argument expressions afresh, and the argument
recording that follows forces the interrupted promise again. An argument
carrying a side effect therefore runs it more than once here. The
alternative is the pre-existing behaviour, where the whole call simply
errored, so the retry is the better trade – but it is a trade.
