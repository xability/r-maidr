# Resolve the definition R dispatched a recorded call to

\`hist\` is the motivating case from \#98: the generic is \`hist(x,
...)\`, so matching against it leaves a positional \`breaks\` inside the
dots. The method carries the formals that matter, and picking it by the
first argument's class is the same choice \`UseMethod()\` made when the
call ran.

## Usage

``` r
dispatched_definition(function_name, definition, args)
```

## Arguments

- function_name:

  Name of the recorded function

- definition:

  The original (unwrapped) function that was called

- args:

  Recorded argument list of evaluated values

## Value

A function to match against, or NULL when none can be resolved
