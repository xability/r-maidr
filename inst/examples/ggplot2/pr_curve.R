# MAIDR Example: Precision-Recall Curve (ggplot2) [experimental]
# Demonstrates an accessible precision-recall curve.
#
# A precision-recall curve is a classifier's precision against its recall,
# one point per decision threshold. Read as a plain line it answers the wrong
# questions: whether the classifier beats guessing is how far its precision
# sits above the share of positives in the data, which differs for every
# dataset, and the average precision the chart is quoted by is never said.
# Read as a precision-recall curve, MAIDR announces each point's threshold
# and how far it sits above that baseline, and gives the average precision of
# each curve and the point with the best F1 score in the description.
#
# ggplot2 has no precision-recall geom, so a curve is drawn with geom_path().
# maidr_pr_curve() is geom_path() with the declaration attached, a
# `threshold` aesthetic for the cutoff each point was scored at, and
# `prevalence` and `ap` arguments for the share of positives and the average
# precision as you computed them. A curve drawn by autoplot() of a
# yardstick::pr_curve() is read as it stands, because it names its axes
# after the rates.

library(maidr)
library(ggplot2)

# Two classifiers scored on the same test set, 30% of it positive.
curves <- rbind(
  data.frame(
    model = "logistic",
    recall = c(0, 0.2, 0.4, 0.6, 0.8, 1),
    precision = c(1, 1, 0.89, 0.8, 0.62, 0.3),
    cutoff = c(1, 0.9, 0.75, 0.6, 0.4, 0)
  ),
  data.frame(
    model = "forest",
    recall = c(0, 0.25, 0.5, 0.75, 1),
    precision = c(1, 0.83, 0.71, 0.55, 0.3),
    cutoff = c(1, 0.8, 0.55, 0.3, 0)
  )
)

# maidr_pr_curve() takes the aesthetics geom_path() takes, plus `threshold`.
# One share of positives serves both curves, since they were scored on the
# same data; leave `ap` out and MAIDR measures it from the points.
p <- ggplot(curves) +
  maidr_pr_curve(
    aes(x = recall, y = precision, colour = model, threshold = cutoff),
    prevalence = 0.3,
    linewidth = 1
  ) +
  # The chance baseline is a reference, not a curve; MAIDR leaves it out.
  geom_hline(yintercept = 0.3, linetype = "dashed", colour = "grey50") +
  coord_equal() +
  labs(
    title = "Precision-Recall Curves of Two Classifiers",
    x = "Recall",
    y = "Precision",
    colour = "Model"
  ) +
  theme_minimal()

# Display with MAIDR accessibility features
show(p)
