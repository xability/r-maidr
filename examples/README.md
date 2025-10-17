# Maidr Package Examples

This directory contains example scripts demonstrating how to use the maidr package to create interactive HTML visualizations from ggplot2 plots.

## Running the Examples

### Prerequisites
- R with ggplot2 and devtools packages installed
- The maidr package loaded (using `devtools::load_all(".")` from the maidr directory)

### All Plot Types Example

Run the comprehensive example that demonstrates all supported plot types:

```r
# From the maidr/examples directory
source("all_plot_types_example.R")
```

Or from the command line:
```bash
# From the maidr/examples directory
Rscript all_plot_types_example.R
```

Or from the project root:
```bash
# From the project root directory
Rscript maidr/examples/all_plot_types_example.R
```

This script will:
1. Generate examples of all supported plot types:
   - Simple bar plots
   - Dodged bar plots  
   - Stacked bar plots
   - Histograms
   - Smooth/density plots
   - Line plots
   - Histogram with density curves

2. Save all interactive HTML files to the `../../output/` directory (project root/output/) with descriptive names:
   - `example_bar_plot.html`
   - `example_dodged_bar_plot.html`
   - `example_stacked_bar_plot.html`
   - `example_histogram.html`
   - `example_smooth_plot.html`
   - `example_line_plot.html`
   - `example_histogram_density.html`

## Output Directory

All generated HTML files are saved to the `output/` directory in the project root. This directory is created automatically if it doesn't exist.