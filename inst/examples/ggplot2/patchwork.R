# MAIDR Example: Patchwork 2x2 Layout (ggplot2)
# Demonstrates accessible multi-panel layout using patchwork package

library(maidr)
library(ggplot2)
library(patchwork)

# Build component plots
set.seed(99)

# Plot 1: Line plot
line_df <- data.frame(x = 1:8, y = c(2, 4, 1, 5, 3, 7, 6, 8))
p_line <- ggplot(line_df, aes(x, y)) +
  geom_line(color = "steelblue", linewidth = 1) +
  labs(title = "Line Plot", x = "X-axis", y = "Values") +
  theme_minimal()

# Plot 2: Bar plot
bar_df1 <- data.frame(
  categories = c("A", "B", "C", "D", "E"),
  values = runif(5, 0, 10)
)
p_bar1 <- ggplot(bar_df1, aes(categories, values)) +
  geom_bar(stat = "identity", fill = "forestgreen", alpha = 0.7) +
  labs(title = "Bar Plot 1", x = "Categories", y = "Values") +
  theme_minimal()

# Plot 3: Another bar plot
bar_df2 <- data.frame(
  categories = c("A", "B", "C", "D", "E"),
  values = rnorm(5, 50, 20)
)
p_bar2 <- ggplot(bar_df2, aes(categories, values)) +
  geom_bar(stat = "identity", fill = "royalblue", alpha = 0.7) +
  labs(title = "Bar Plot 2", x = "Categories", y = "Values") +
  theme_minimal()

# Plot 4: Extra line plot
set.seed(1234)
line_df_extra <- data.frame(x = 1:8, y = cumsum(rnorm(8)))
p_line_extra <- ggplot(line_df_extra, aes(x, y)) +
  geom_line(color = "tomato", linewidth = 1) +
  labs(title = "Line Plot 2", x = "X-axis", y = "Values") +
  theme_minimal()

# Compose 2x2 grid using patchwork
p_combined <- (p_line + p_bar1 + p_bar2 + p_line_extra) +
  plot_layout(ncol = 2)

# Display with MAIDR accessibility features
show(p_combined)
