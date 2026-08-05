# Evaluate an expression, muffling the retry's promise-restart warning

When a call fails part-way through forcing an argument, that argument's
promise is left interrupted. Forcing it again — which both the retry and
the argument recording do — makes R warn "restarting interrupted promise
evaluation". It is an artifact of retrying, not anything the user's call
did, so it is muffled; every other warning passes through untouched.

## Usage

``` r
muffle_promise_restart(expr)
```

## Arguments

- expr:

  Expression to evaluate (lazily, inside the handler)

## Value

The value of \`expr\`
