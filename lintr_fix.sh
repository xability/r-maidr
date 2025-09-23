#!/bin/bash
# Simple R linting fix command
# Usage: ./rfix.sh

echo "🔧 Fixing R linting issues..."

# Change to maidr package directory
cd maidr

# Run styler to fix formatting issues
echo "📝 Running styler..."
Rscript -e "styler::style_pkg()"

# Check remaining issues
echo "🔍 Checking remaining issues..."
Rscript -e "issues <- lintr::lint_package(); cat('Total issues remaining:', length(issues), '\n')"

echo "✅ Done!"
