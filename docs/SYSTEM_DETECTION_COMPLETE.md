# MAIDR System Detection Complete Guide

## Overview

The MAIDR package uses a **Registry Pattern with Adapter Pattern** to automatically detect which plotting system (ggplot2 or Base R) should handle a given plot. This document provides a complete technical explanation of the detection architecture.

**Note:** This document focuses on explanations. Refer to the actual code files for implementation details.

## Table of Contents

1. [Architecture Components](#architecture-components)
2. [Initialization Flow](#initialization-flow)
3. [Detection Flow](#detection-flow)
4. [Adapter Implementations](#adapter-implementations)
5. [Isolation Mechanism](#isolation-mechanism)

---

## Architecture Components

### 1. PlotSystemRegistry (Central Hub)

**File:** `R/plot_system_registry.R`

The registry manages all plotting systems and their components. It uses a singleton pattern to provide a single global instance.

**Key Responsibilities:**
- Maintain single registry for all systems
- Enumerate registered systems and ask each to check
- Return adapter and factory for the chosen system
- Provide centralized system registry

**Core Methods:**
- `register_system(system_name, adapter, processor_factory)` - Registers a new plotting system with validation
- `detect_system(plot_object)` - Iterates through registered systems asking each `can_handle()`
- `get_adapter(system_name)` - Returns adapter for a specific system
- `get_processor_factory(system_name)` - Returns factory for a specific system

**Singleton Pattern:**
- Uses global variable `global_registry` to maintain single instance
- `get_global_registry()` creates instance on first call, returns existing instance on subsequent calls

---

### 2. SystemAdapter (Abstract Base Class)

**File:** `R/system_adapter.R`

Abstract base class defining the interface all adapters must implement.

**Required Interface:**
- `can_handle(plot_object)` - Returns TRUE if this adapter can handle the plot
- `create_orchestrator(plot_object)` - Creates the system-specific orchestrator

**Design Principles:**
- **Single Responsibility:** Each adapter handles one system
- **Polymorphism:** Same interface, system-specific logic
- **Extensibility:** Simple to add new systems

---

### 3. Adapter Implementations

#### Ggplot2Adapter

**File:** `R/ggplot2_adapter.R`

Handles ggplot2 plot objects using object inspection.

**Detection Method:**
- Uses `inherits(plot_object, "ggplot")` for fast class checking
- Works at any point in the session
- No session dependencies

**Layer Type Detection:**
- Inspects `layer$geom`, `layer$stat`, and `layer$position` classes
- Maps geom classes to layer types (e.g., `GeomBar` → "bar")
- Handles special cases like dodged/stacked bars by checking position classes and fill mappings
- Returns layer types: "bar", "dodged_bar", "stacked_bar", "line", "smooth", "point", "box", "hist", "heat", "skip", "unknown"

**Orchestrator Creation:**
- Creates `Ggplot2PlotOrchestrator` with the plot object
- Validates plot is actually a ggplot before proceeding

---

#### BaseRAdapter

**File:** `R/base_r_adapter.R`

Uses patching status and device storage for detection.

**Detection Method:**
- Checks two conditions: `is_patching_active()` AND `has_device_calls()`
- First checks if functions are wrapped (patching active)
- Second checks if current device has recorded calls
- Both must be TRUE for Base R to handle

**Layer Type Detection:**
- Uses function name and arguments from logged calls
- Distinguishes HIGH-level functions (barplot, hist, plot, etc.) from LOW-level (lines, points, abline, etc.)
- Special handling for `lines(density())` → "smooth"
- Special handling for barplot variants (dodged vs stacked vs regular)

**Orchestrator Creation:**
- Creates `BaseRPlotOrchestrator` with device ID (not plot object)
- Device ID is where calls were recorded

---

## Initialization Flow

### Package Load Sequence

When the package loads, `.onLoad` is called (from `R/ggplot2_system_init.R`):

1. Initialize ggplot2 system registration
2. Initialize Base R system registration
3. Start Base R function patching

### System Registration

**Ggplot2 System (`R/ggplot2_system_init.R`):**
- Creates `Ggplot2Adapter` instance
- Creates `Ggplot2ProcessorFactory` instance
- Registers both with the global registry under name "ggplot2"

**Base R System (`R/base_r_system_init.R`):**
- Creates `BaseRAdapter` instance
- Creates `BaseRProcessorFactory` instance
- Registers both with the global registry under name "base_r"

### Function Patching

**Initialization (`R/base_r_function_patching.R`):**
- Gets functions to wrap by classification (HIGH, LOW, LAYOUT)
- Wraps each function to intercept calls
- Stores original functions
- Creates wrappers that log calls to device storage

**Wrapping Process:**
- Finds original function in namespace
- Stores original in `._saved_graphics_fns`
- Creates wrapper that calls original, then logs call
- Replaces function in global environment

**After Initialization:**
- Both systems registered in global registry
- Base R functions wrapped and logging calls
- System detection ready to use

---

## Detection Flow

### Entry Point

**File:** `R/maidr.R` - `show()` function

**Process:**
1. Checks if Base R mode (when `plot` is NULL)
2. Validates patching is active and device has calls
3. Calls `create_maidr_html(plot, ...)`
4. Clears device storage after processing (isolation)
5. Displays HTML

### Detection Process

**File:** `R/maidr.R` - `create_maidr_html()` function

**Steps:**
1. Get registry singleton via `get_global_registry()`
2. Detect system via `registry$detect_system(plot)`
3. Get adapter via `registry$get_adapter(system_name)`
4. Create orchestrator via `adapter$create_orchestrator(plot)`
5. Process through orchestrator (get grob, layout, maidr data)
6. Generate SVG content
7. Return HTML document

### Registry Detection Logic

**Method:** `PlotSystemRegistry$detect_system()`

**Process:**
- Iterates through registered systems in order
- For each system, calls `adapter$can_handle(plot_object)`
- Returns first system where `can_handle()` returns TRUE
- Returns NULL if no system can handle

**Detection Order:**
1. Ggplot2Adapter checked first (fast class check)
2. BaseRAdapter checked second (patching + storage check)

**Order matters:** ggplot2 takes precedence over Base R

---

## Adapter Implementations

### Detection Methods Comparison

| Aspect | ggplot2 | Base R |
|--------|---------|--------|
| **Detection Key** | `inherits(plot, "ggplot")` | `is_patching_active() && has_device_calls()` |
| **plot_object** | Valid ggplot object | NULL |
| **Inspection Type** | Class inheritance | Patching status and device storage |
| **Speed** | Immediate | Immediate |
| **Session Dependence** | None | Requires patching |
| **Method** | Object inspection | Call logging inspection |

### Detection Flow (High Level)

**Ggplot2 Detection:**
1. User creates ggplot object
2. User calls `maidr::show(plot)`
3. Registry iterates adapters
4. `Ggplot2Adapter$can_handle()` checks `inherits(plot, "ggplot")` → TRUE
5. Returns "ggplot2"
6. Gets adapter and creates orchestrator

**Base R Detection:**
1. User calls Base R plotting function (wrapped)
2. Wrapper logs call to device storage
3. User calls `maidr::show()` (no plot argument)
4. Registry iterates adapters
5. `Ggplot2Adapter$can_handle(NULL)` → FALSE
6. `BaseRAdapter$can_handle(NULL)` checks both conditions → TRUE
7. Returns "base_r"
8. Gets adapter and creates orchestrator with device ID

---

## Isolation Mechanism

### Problem Solved

Without isolation, calls would accumulate across multiple `show()` calls, causing unrelated plot calls to be processed together.

### Solution: Clear After Processing

**Location:** `R/maidr.R` - `show()` function

**Process:**
- After generating HTML, clear device storage
- Only clears if `plot` is NULL (Base R mode)
- Gets device ID at start of function
- Clears that specific device's storage

### Clearing Implementation

**File:** `R/base_r_device_storage.R` - `clear_device_storage()`

**Process:**
- Takes device ID
- Finds storage entry by device key
- Sets storage to NULL
- Calls `reset_device_state()` to clear state

**State Reset:**
- Clears device state (plot index, panel config, etc.)
- Ensures next plot starts with fresh state

### Device Storage Structure

**File:** `R/base_r_device_storage.R`

**Structure:**
- Session-level storage in `.maidr_base_r_session` environment
- `devices` list keyed by device ID (string)
- Each device entry contains:
  - `device_id`: Integer device ID
  - `calls`: List of logged plot calls
  - `metadata`: Call count and creation timestamp
  - `state`: Plot index, panel config, layout info

**Isolation:**
- Each device has separate storage
- Multiple devices can exist simultaneously
- Clearing one device doesn't affect others

### Isolation Timeline

**First Plot:**
1. User creates plot → calls logged to device storage
2. User calls `maidr::show()` → processes calls
3. Storage cleared → ready for next plot

**Second Plot (Clean Slate):**
1. User creates new plot → calls logged to empty/fresh storage
2. Only new calls present, no old calls
3. Process and clear again

**Key Point:** Each `show()` call starts with clean storage because previous calls were cleared

---

## Summary

### Detection Architecture Flow

1. **Entry:** `maidr::show(plot)`
2. **Registry:** Get global registry singleton
3. **Detection:** Iterate adapters, ask `can_handle()`
4. **Decision:** First match returns system name
5. **Adapter:** Get adapter for detected system
6. **Orchestrator:** Create system-specific orchestrator
7. **Processing:** System-specific processing begins

### Detection Rules

- **Ggplot2:** Uses `inherits(plot, "ggplot")` class check
- **Base R:** Requires `is_patching_active() && has_device_calls()`
- **Order:** ggplot2 checked first, then Base R
- **Result:** Returns first system that can handle

### Isolation Rules

- **Clear after processing:** Device storage cleared after each `show()`
- **Device isolation:** Each device maintains separate storage
- **State reset:** State cleared with storage
- **Clean slate:** Each plot session starts empty

### Registry Pattern Benefits

- **Extensible:** Add new systems without modifying detection logic
- **Testable:** Mock adapters for testing
- **Maintainable:** Clear responsibilities and interfaces
- **Pluggable:** Swap implementations easily

---

## Related Files

**Core Components:**
- `R/plot_system_registry.R` - Registry implementation
- `R/system_adapter.R` - Abstract base class
- `R/ggplot2_adapter.R` - Ggplot2 adapter
- `R/base_r_adapter.R` - Base R adapter
- `R/maidr.R` - Entry point
- `R/base_r_device_storage.R` - Storage management
- `R/base_r_function_patching.R` - Function wrapping

**Initialization:**
- `R/ggplot2_system_init.R` - Ggplot2 registration
- `R/base_r_system_init.R` - Base R registration
- `R/base_r_function_classification.R` - Function classification

**Supporting:**
- `R/base_r_state_tracking.R` - State management
- `R/base_r_plot_grouping.R` - Call grouping

