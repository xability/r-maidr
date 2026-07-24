# Canonical Axes Schema Helpers

Utilities for constructing and validating the canonical per-axis `axes`
object emitted by the MAIDR payload. Only `x`, `y`, and `z` keys are
permitted at the top level of `axes`; each maps to an `AxisConfig` list
with optional `label` (string), `min`, `max`, `tickStep` (numbers), and
`format` (an `AxisFormat` list). The legacy flat form (bare string
labels and top-level format/min/max/tickStep/fill/level) has been
removed with no deprecation path.
