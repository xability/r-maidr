# r-maidr Package Summary

## Package Structure
```
r-maidr-prototype/
├── DESCRIPTION          # Package metadata and dependencies
├── NAMESPACE           # Function exports
├── README.md           # Documentation and usage examples
├── R/
│   ├── maidr.R        # Main package orchestration and user-facing functions
│   ├── registry.R     # Extractor registry logic and registration
│   ├── utils.R        # Utility functions
│   ├── extract_bar.R  # Bar plot extractor (can add more extractors here)
│   └── zzz.R          # .onLoad for automatic registration
├── tests/
│   └── test_bar_plot.R # Test script for bar plots
├── man/                # Documentation (auto-generated)
├── vignettes/          # Tutorials (empty for now)
```

## Key Features

- **Modular Design**: Each plot type has its own extractor file (e.g., `extract_bar.R`).
- **Central Registry**: Maps ggplot2 geom types to extractors in `registry.R`.
- **Automatic Registration**: Extractors are registered on package load via `.onLoad` in `zzz.R`.
- **Separation of Concerns**: Orchestration, registry, extractors, and utilities are in separate files.
- **Extensible**: Add new plot types by creating a new extractor and registering it.
- **ggplot2 Integration**: Uses `ggplot_build()` for robust data extraction.
- **Accessible Output**: Generates HTML with accessible SVG and metadata.

## How It Works

1. **Data Extraction**: Uses `ggplot_build()` to get processed plot data.
2. **Registry Lookup**: Looks up the appropriate extractor for each geom type.
3. **Layer Processing**: Processes each layer using its registered extractor.
4. **ID Generation**: Creates unique IDs for plot elements.
5. **HTML Generation**: Combines SVG with accessibility metadata and outputs HTML.

## Extending the Package

To add support for a new plot type:
1. Create a new extractor file in `R/` (e.g., `extract_line.R`).
2. Define the extractor function for that plot type.
3. Register the extractor in `register_default_extractors()` in `R/registry.R`.

## Example Test

- See `tests/test_bar_plot.R` for a simple test of bar plot extraction and HTML generation.

## Next Steps

- Add more plot type extractors (e.g., line, scatter).
- Add more unit tests and vignettes.
- Prepare for CRAN submission.

The package is ready for development and can be easily extended to support additional plot types! 