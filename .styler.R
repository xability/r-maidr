# styler configuration file
# This file configures styler for consistent code formatting

# Use tidyverse style (most popular)
styler::style_dir(
  path = ".",
  style = styler::tidyverse_style,
  indent_by = 2,
  start_comments_with_one_space = TRUE,
  reindention = styler::tidyverse_reindention(),
  math_token_spacing = styler::tidyverse_math_token_spacing(),
  line_break_fun = styler::tidyverse_line_break()
) 