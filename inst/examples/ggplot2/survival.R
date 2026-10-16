# MAIDR Example: Kaplan-Meier Survival Curves (ggplot2) [experimental]
# Demonstrates accessible survival curves.
#
# A Kaplan-Meier curve is a step chart -- the survival estimate holds until
# an event drops it -- but read as a step chart it announces the levels and
# withholds what the figure is read for: who was censored, which says how
# much of the curve the data still supports, and the confidence band around
# the estimate. Read as a survival curve, MAIDR announces each time with its
# estimate and interval, marks the censored times so a reader can step
# between them with the rotor, and gives each curve's median survival in the
# description.
#
# maidr_survival() draws the curves of a survival::survfit() object, or
# curves from data with `censored`, `ymin` and `ymax` aesthetics, and
# declares them as Kaplan-Meier curves.

library(maidr)
library(ggplot2)
library(survival)

# From a survfit object: one curve per stratum, from the origin, with the
# stepped confidence band and a mark at each censored time.
fit <- survfit(Surv(time, status) ~ sex, data = lung)

km <- ggplot() +
  maidr_survival(fit, conf.int = TRUE) +
  labs(
    title = "Survival in Advanced Lung Cancer by Sex",
    x = "Days"
  ) +
  theme_minimal()

show(km)

# From data: the fit's summary as an author might keep it. `censored` is a
# logical or a count; it marks the time without splitting the curve.
s <- summary(fit, censored = TRUE)
rows <- data.frame(
  days = s$time,
  survival = s$surv,
  lower = s$lower,
  upper = s$upper,
  censored = s$n.censor > 0,
  group = sub("sex=", "Sex ", s$strata)
)

km_rows <- ggplot(rows, aes(x = days, y = survival, colour = group)) +
  maidr_survival(
    aes(censored = censored, ymin = lower, ymax = upper),
    conf.int = TRUE
  ) +
  # The median line is a reference, not data; MAIDR leaves it out.
  geom_hline(yintercept = 0.5, linetype = "dashed") +
  labs(
    title = "Survival by Sex",
    x = "Days",
    y = "Survival probability",
    colour = "Group"
  ) +
  theme_minimal()

show(km_rows)

# A survminer figure is read as it stands: its curve, band and censoring
# marks are redrawn as one maidr_survival() layer. The risk table is not
# read.
if (requireNamespace("survminer", quietly = TRUE)) {
  figure <- survminer::ggsurvplot(fit, data = lung, conf.int = TRUE)
  show(figure)
}
