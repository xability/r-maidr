# MAIDR Example: Step Plot (Base R)
# Demonstrates an accessible step plot with keyboard navigation.
#
# A step plot suits a value that is piecewise constant — held across an
# interval, then jumped. Here it is the sleep stage scored for each half-hour
# of an overnight sleep study, the Base R counterpart of the ggplot2
# hypnogram example.
#
# plot(type = "s") draws the horizontal segment first, which MAIDR reports as
# stepDirection "hv". Use type = "S" for the vertical-first convention ("vh").

library(maidr)

hours <- seq(0, 7.5, by = 0.5)

# Stage names ordered from deepest sleep to fully awake, so the plotted level
# (and the sonified pitch) rises with arousal.
stage_names <- c("N3", "N2", "N1", "REM", "Awake")

# Numeric level per half-hour epoch (16 epochs across eight hours).
stage <- c(
  5, 3, 2, 1, 1, 2, 4, 2,
  1, 1, 2, 4, 2, 3, 4, 5
)

plot(hours, stage,
  type = "s",
  main = "Overnight Hypnogram",
  xlab = "Hours after lights out",
  ylab = "Sleep stage",
  col = "steelblue",
  lwd = 2,
  yaxt = "n"
)
axis(2, at = seq_along(stage_names), labels = stage_names, las = 1)

# Display with MAIDR accessibility features
show()
