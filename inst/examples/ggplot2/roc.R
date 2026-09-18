# MAIDR Example: ROC Curve (ggplot2)
# Demonstrates an accessible receiver operating characteristic curve.
#
# A ROC curve is a classifier's true positive rate against its false positive
# rate, one point per decision threshold. Read as a plain line it answers the
# wrong questions: the min and max are 0 and 1 on every curve, and the area
# under the curve -- the number the chart is quoted by -- is never said. Read
# as a ROC curve, MAIDR pitches the true positive rate on the unit interval,
# pans by the false positive rate, announces each point's threshold and its
# height above the chance diagonal, and gives the area under each curve and
# the best operating point in the description.
#
# ggplot2 has no ROC geom, so a curve is drawn with geom_path() -- and a path
# carries no evidence of what it means. maidr_roc() is geom_path() with the
# declaration attached, a `threshold` aesthetic for the cutoff each point was
# scored at, and an `auc` argument for the area as you computed it. Curves
# drawn by pROC::ggroc() or by autoplot() of a yardstick::roc_curve() are
# read as they stand, because they name their axes after the rates.

library(maidr)
library(ggplot2)

# Two classifiers scored on the same test set: the operating points of each,
# with the decision threshold that produced them.
curves <- rbind(
  data.frame(
    model = "logistic",
    fpr = c(0, 0.05, 0.1, 0.2, 0.35, 0.6, 1),
    tpr = c(0, 0.55, 0.75, 0.86, 0.93, 0.98, 1),
    cutoff = c(1, 0.8, 0.6, 0.45, 0.3, 0.15, 0)
  ),
  data.frame(
    model = "forest",
    fpr = c(0, 0.1, 0.25, 0.45, 0.7, 1),
    tpr = c(0, 0.4, 0.6, 0.78, 0.9, 1),
    cutoff = c(1, 0.7, 0.5, 0.35, 0.2, 0)
  )
)

# maidr_roc() takes the aesthetics geom_path() takes, plus `threshold`. The
# areas are named by the groups' names; leave `auc` out and MAIDR measures
# them from the points by the trapezoid rule.
p <- ggplot(curves) +
  maidr_roc(
    aes(x = fpr, y = tpr, colour = model, threshold = cutoff),
    auc = c(logistic = 0.896, forest = 0.728),
    linewidth = 1
  ) +
  # The chance diagonal is a reference, not a curve; MAIDR leaves it out.
  geom_abline(linetype = "dashed", colour = "grey50") +
  coord_equal() +
  labs(
    title = "ROC Curves of Two Classifiers",
    x = "False positive rate",
    y = "True positive rate",
    colour = "Model"
  ) +
  theme_minimal()

# Display with MAIDR accessibility features
show(p)
