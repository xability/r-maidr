# End-to-end test for maidr save_html and maidr()
library(ggplot2)
devtools::load_all('maidr')

# 1. Create a ggplot2 bar plot
p <- ggplot(mtcars, aes(factor(cyl))) + geom_bar()

# 3. Open in viewer/browser
file_path <- maidr(p)
cat("maidr() opened file:", file_path, "\n") 