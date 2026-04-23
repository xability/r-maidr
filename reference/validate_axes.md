# Validate a canonical axes object (strict)

Enforces the canonical schema. On any violation, throws an error with a
descriptive message.

## Usage

``` r
validate_axes(axes, context = "")
```

## Arguments

- axes:

  Axes list to validate (or NULL)

- context:

  Optional string describing the call site (for errors)

## Value

Invisibly returns `axes` if valid

## Details

Rules:

- `axes` must be NULL or a list.

- Keys must be a subset of `{"x","y","z"}`.

- Each axis value must be a list (AxisConfig), never a string/
  number/array.

- No `format`, `min`, `max`, `tickStep`, `fill`, or `level` at the top
  level of `axes`.

- `min`, `max`, `tickStep` (when present inside an axis) must be numeric
  scalars.
