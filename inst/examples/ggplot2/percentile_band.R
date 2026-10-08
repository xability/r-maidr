# MAIDR Example: Percentile Band (ggplot2 + ggdist) [experimental]
# Demonstrates an accessible fan chart of nested quantile intervals.
#
# ggdist's stat_lineribbon() draws, at each x, the median of a distribution
# and nested intervals around it -- the middle 50%, 80% and 95% here -- as a
# fan of ribbons. MAIDR reads it as a percentile band: Left and Right move
# along x, a reader enters each x on the median, and Up and Down walk through
# the quantiles, each announced with the band it bounds ("Middle 80% is 0.4
# to 1.61"), with that band outlined.
#
# Only a median with quantile intervals is read this way, which is
# stat_lineribbon()'s default; a mean or a highest-density interval is not a
# quantile.

library(maidr)
library(ggplot2)
library(ggdist)

set.seed(1)
draws <- data.frame(week = rep(1:8, each = 400))
draws$sales <- rnorm(nrow(draws), mean = 10 + 2 * draws$week, sd = draws$week)

p <- ggplot(draws, aes(x = week, y = sales)) +
  stat_lineribbon(.width = c(0.5, 0.8, 0.95)) +
  scale_fill_brewer() +
  labs(
    title = "Forecast Sales by Week",
    x = "Week",
    y = "Sales",
    fill = "Interval"
  ) +
  theme_minimal()

# Display with MAIDR accessibility features
show(p)
