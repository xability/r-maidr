#!/bin/bash
# Simple R linting fix command
# Usage: ./lintr_fix.sh

echo "🔧 Fixing R linting issues..."

# Remove problematic .lintr file
rm -f .lintr

# Run styler to fix formatting issues
echo "📝 Running styler with tidyverse style..."
Rscript -e "styler::style_pkg(style = styler::tidyverse_style, indent_by = 2)"

# Check remaining issues
echo "🔍 Checking remaining issues..."
Rscript -e "issues <- lintr::lint_package(); cat('Total issues remaining:', length(issues), '\n')"

echo "✅ Done!"
