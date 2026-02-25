# MAIDR Package Options

Configure MAIDR interception and display behavior using R's options
system.

## Available Options

- `maidr.enabled`:

  Logical. Master switch for all MAIDR interception. When FALSE, all
  plotting functions behave as standard R. Default: TRUE.

- `maidr.base_r`:

  Logical. Enable Base R plot interception. When TRUE, Base R plots are
  captured and displayed in the MAIDR viewer. Default: TRUE.

- `maidr.ggplot2`:

  Logical. Enable ggplot2 auto-display. When TRUE, ggplot2 objects are
  automatically rendered in the MAIDR viewer instead of the standard
  graphics device. Default: TRUE.

- `maidr.startup_message`:

  Logical. Show startup message when package is loaded. Default: TRUE.

## Setting Options

Options can be set in your `.Rprofile` to persist across sessions:

    # Disable ggplot2 interception by default
    options(maidr.ggplot2 = FALSE)

    # Disable all interception
    options(maidr.enabled = FALSE)

    # Suppress startup message
    options(maidr.startup_message = FALSE)
