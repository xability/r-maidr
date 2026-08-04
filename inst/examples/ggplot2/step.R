# MAIDR Example: Step Plot / Hypnogram (ggplot2)
# Demonstrates an accessible step plot with keyboard navigation.
#
# A step plot is the right chart for a value that is piecewise constant: it is
# held across an interval and then jumps, rather than drifting between samples
# the way a line implies. The canonical case is a hypnogram — the sleep stage
# a sleep study scores for each 30-second epoch of the night.
#
# Because the y aesthetic is an ordinal factor, MAIDR announces the level name
# ("REM", "N2", "Awake") while still sonifying the underlying numeric level, so
# the shape of the night is audible and the stage is speakable.

library(maidr)
library(ggplot2)

# One scored stage per half-hour of an eight-hour night (16 epochs).
hypnogram <- data.frame(
  hour = seq(0, 7.5, by = 0.5),
  stage = c(
    "Awake", "N1", "N2", "N3", "N3", "N2", "REM", "N2",
    "N3", "N3", "N2", "REM", "N2", "N1", "REM", "Awake"
  )
)

# Order the levels from deepest sleep to fully awake so the vertical axis —
# and the sonified pitch — rises with arousal, the convention a hypnogram uses.
hypnogram$stage <- factor(
  hypnogram$stage,
  levels = c("N3", "N2", "N1", "REM", "Awake")
)

# geom_step(direction = "hv") — the default — holds each stage until the next
# scored epoch and then jumps, which is exactly how a hypnogram is read.
p <- ggplot(hypnogram, aes(x = hour, y = stage, group = 1)) +
  geom_step(direction = "hv", color = "steelblue", linewidth = 1) +
  scale_x_continuous(breaks = 0:8) +
  labs(
    title = "Overnight Hypnogram",
    subtitle = "Sleep stage across an eight-hour night",
    x = "Hours after lights out",
    y = "Sleep stage"
  ) +
  theme_minimal()

# Display with MAIDR accessibility features
show(p)
