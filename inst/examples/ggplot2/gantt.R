# MAIDR Example: Gantt Chart / Project Schedule (ggplot2)
# Demonstrates an accessible schedule drawn with rectangles.
#
# A gantt chart is a set of lanes, and in each lane a set of intervals: two
# positions on the same axis rather than a position and a height. MAIDR
# announces the lane, the start and the end, and highlights the one bar the
# reader is on.
#
# ggplot2 has no gantt geom, so a schedule is drawn with geom_rect() — and a
# rectangle layer carries no evidence of what it means. The same four numbers
# draw a heatmap cell, a highlighted region behind a chart, a waterfall step
# and a task. Five rules for telling them apart were measured against eight
# charts and every one of them claimed a chart that is not a schedule, so
# maidr asks the author instead: write maidr_gantt() where you would have
# written geom_rect() and nothing about the picture changes, but the layer is
# read. Left as geom_rect(), the chart falls back to a static image.

library(maidr)
library(ggplot2)

# Four tasks over fifteen weeks. Build is booked twice, so its lane holds two
# intervals — which is the thing a flat list of bars cannot say.
tasks <- data.frame(
  task = c("design", "build", "test", "build"),
  start = c(0, 3, 8, 12),
  end = c(3, 8, 11, 15)
)

# The lane is a position on a continuous axis, and the band is drawn around
# it: 0.8 of a lane's width, which leaves a visible gap between lanes.
lanes <- c("design", "build", "test")
tasks$lane <- match(tasks$task, lanes)

# maidr_gantt() takes exactly the aesthetics geom_rect() takes. Lanes run up
# the y axis and spans along x by default; lane_axis = "x" reads the mirror
# image.
p <- ggplot(tasks) +
  maidr_gantt(aes(
    xmin = start, xmax = end,
    ymin = lane - 0.4, ymax = lane + 0.4
  ), fill = "steelblue") +
  # The tick inside a band is what names that lane. Without these labels the
  # axis writes its own coordinates out — 1, 2, 3 — and a lane is announced by
  # its position instead, because a lane called "2" says less than a lane
  # called by the position 2 it sits at.
  scale_y_continuous(breaks = seq_along(lanes), labels = lanes) +
  scale_x_continuous(breaks = seq(0, 15, by = 3)) +
  labs(
    title = "Project Schedule",
    subtitle = "Four tasks across fifteen weeks",
    x = "Week",
    y = "Task"
  ) +
  theme_minimal()

# Display with MAIDR accessibility features
show(p)
