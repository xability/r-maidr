# Snapshot the bindings a recorded NSE call will need at replay time

Recorded expressions are re-evaluated when the figure is rendered, long
after the caller has moved on – and R reuses ONE frame for every
iteration of a \`for\` loop. Storing that frame therefore makes every
iteration replay with the LAST iteration's values:

## Usage

``` r
snapshot_call_env(args, caller_env)
```

## Arguments

- args:

  Recorded argument list holding the unevaluated expressions

- caller_env:

  The frame the recorded call was made from

## Value

An environment whose parent is `caller_env`

## Details


    par(mfrow = c(1, 2))
    for (g in c("a", "b")) plot(y ~ x, data = d, subset = grp == g)

Both panels drew \`grp == "b"\`, silently and without an error. Copying
the whole frame would fix that but brings its own problems (large
objects, active bindings, unforced promises, frames that are shared and
mutated), so only the names the recorded expressions actually mention
are copied, into a CHILD of the caller's frame. Everything else –
including anything reached through the enclosing scopes – still resolves
exactly as before, and the copies are references, so R's copy-on-write
keeps them free.

Active bindings are deliberately left behind: reading one is a side
effect, and re-reading it at replay time is the whole point of declaring
it active. Names that cannot be read are skipped for the same reason –
the fall-through to the caller's frame preserves today's behaviour.
