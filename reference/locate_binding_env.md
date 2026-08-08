# Find the environment a name is bound in

Walks the enclosing chain from `env` the way R's own lookup does,
stopping once the global environment has been checked: names that
resolve beyond it live in attached packages, which no plotting loop
rebinds.

## Usage

``` r
locate_binding_env(name, env)
```

## Arguments

- name:

  Name to look up

- env:

  Environment to start from

## Value

The environment holding `name`, or NULL when unbound
