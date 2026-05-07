# ABAP Free Screen Objects Skills - Reusable Implementation Guide

## Purpose

This document provides a comprehensive reference for **properly freeing and reinitializing screen objects** in ABAP Function Group programs. It covers the lifecycle management of ALV grids, containers, and other GUI objects to prevent memory leaks and ensure clean state when re-entering screens.

---

## Table of Contents

1. [Overview & Problem](#overview--problem)
2. [Object Lifecycle Management](#object-lifecycle-management)
3. [Free Screen Objects Pattern](#free-screen-objects-pattern)
4. [Implementation Strategies](#implementation-strategies)
5. [Common Scenarios](#common-scenarios)
6. [Best Practices](#best-practices)
7. [Troubleshooting](#troubleshooting)

---

## Overview & Problem

### The Problem

When a user navigates away from a screen and returns to it, the global object references (ALV grids, containers, etc.) may still exist in memory. If you try to create new objects without freeing the old ones:

- **Memory leaks** accumulate
- **Duplicate controls** appear on screen
- **Event handlers** fire multiple times
- **Performance degrades** with each re-entry

### The Solution

Implement a **free-and-reinitialize pattern** that:
1. Detects when objects already exist
2. Properly frees them before creating new ones
3. Clears associated data structures
4. Reinitializes fresh objects

---

## Object Lifecycle Management

### Object Types to Manage

| Object Type | Variable Pattern | Free Method | Notes |
|---|---|---|---|
| ALV Grid | `gr_alv_[screen]` | `->free()` | Main data display control |
| Container | `gr_cont_[screen]` | `->free()` | Parent for ALV grid |
| Field Catalog | `gt_fcat_[screen]` | `CLEAR` | Table of field definitions |
| Layout | `gs_layout_[screen]` | `CLEAR` | ALV layout settings |
| Data Table | `gt_[data]` | `CLEAR` | Main data table |
| Initialization Flag | `gv_[screen]_initialized` | `CLEAR` | Tracks first-time setup |

### Object Binding States

```abap
" Object is NOT bound (doesn't exist)
IF gr_alv_0800 IS NOT BOUND.
  " Safe to create new object
  CREATE OBJECT gr_alv_0800 ...
ENDIF.

" Object IS bound (exists in memory)
IF gr_alv_0800 IS BOUND.
  " Must free before creating new one
  gr_alv_0800->free( ).
  CLEAR gr_alv_0800.
ENDIF.
```

---

## Free Screen Objects Pattern

### Pattern 1: Basic Free & Reinitialize (Recommended)

**Use Case**: Simple screens with one ALV grid and container.

```abap
MODULE init_0800 OUTPUT.

  " Step 1: Check if already initialized
  IF gv_0800_initialized IS INITIAL.

    " Step 2: Free existing objects (in case of re-entry)
    IF gr_alv_0800 IS BOUND.
      gr_alv_0800->free( ).
      CLEAR gr_alv_0800.
    ENDIF.
    
    IF gr_cont_0800 IS BOUND.
      gr_cont_0800->free( ).
      CLEAR gr_cont_0800.
    ENDIF.

    " Step 3: Clear data structures
    CLEAR: gt_fcat_0800, gs_layout_0800, gt_budget.

    " Step 4: Create fresh container
    CREATE OBJECT gr_cont_0800
      EXPORTING
        container_name = 'CC_ALV_0800'.

    " Step 5: Create fresh ALV grid
    CREATE OBJECT gr_alv_0800
      EXPORTING
        i_parent = gr_cont_0800.

    " Step 6: Mark as initialized
    gv_0800_initialized = abap_true.

  ENDIF.

  " Step 7: Refresh display if data exists
  IF gt_budget IS NOT INITIAL AND gr_alv_0800 IS BOUND.
    gr_alv_0800->refresh_table_display( ).
  ENDIF.

ENDMODULE.
```

### Pattern 2: Complete Free with Event Handlers

**Use Case**: Screens with ALV event handlers (double-click, toolbar, user commands).

```abap
MODULE init_0800 OUTPUT.

  DATA: lo_handler TYPE REF TO lcl_alv_handler.

  IF gv_0800_initialized IS INITIAL.

    " Free existing objects
    PERFORM free_alv_0800.

    " Create fresh container and grid
    CREATE OBJECT gr_cont_0800
      EXPORTING
        container_name = 'CC_ALV_0800'.

    CREATE OBJECT gr_alv_0800
      EXPORTING
        i_parent = gr_cont_0800.

    " Attach event handlers
    CREATE OBJECT lo_handler.
    SET HANDLER lo_handler->handle_double_click_0800 FOR gr_alv_0800.
    SET HANDLER lo_handler->handle_toolbar_0800 FOR gr_alv_0800.
    SET HANDLER lo_handler->handle_user_command_0800 FOR gr_alv_0800.

    gv_0800_initialized = abap_true.

  ENDIF.

  IF gt_budget IS NOT INITIAL AND gr_alv_0800 IS BOUND.
    gr_alv_0800->refresh_table_display( ).
  ENDIF.

ENDMODULE.

FORM free_alv_0800.
  IF gr_alv_0800 IS BOUND.
    gr_alv_0800->free( ).
    CLEAR gr_alv_0800.
  ENDIF.
  IF gr_cont_0800 IS BOUND.
    gr_cont_0800->free( ).
    CLEAR gr_cont_0800.
  ENDIF.
  CLEAR: gt_fcat_0800, gs_layout_0800, gt_budget.
ENDFORM.
```

### Pattern 3: Multi-Screen Free (Complex Navigation)

**Use Case**: Multiple screens with different ALV grids that need independent cleanup.

```abap
MODULE init_0800 OUTPUT.
  IF gv_0800_initialized IS INITIAL.
    PERFORM free_all_screens.
    PERFORM init_alv_0800.
    gv_0800_initialized = abap_true.
  ENDIF.
ENDMODULE.

MODULE init_0810 OUTPUT.
  IF gv_0810_initialized IS INITIAL.
    PERFORM free_all_screens.
    PERFORM init_alv_0810.
    gv_0810_initialized = abap_true.
  ENDIF.
ENDMODULE.

FORM free_all_screens.
  PERFORM free_alv_0800.
  PERFORM free_alv_0810.
  PERFORM free_alv_0820.
ENDFORM.

FORM free_alv_0800.
  IF gr_alv_0800 IS BOUND.
    gr_alv_0800->free( ).
    CLEAR gr_alv_0800.
  ENDIF.
  IF gr_cont_0800 IS BOUND.
    gr_cont_0800->free( ).
    CLEAR gr_cont_0800.
  ENDIF.
  CLEAR: gt_fcat_0800, gs_layout_0800, gt_budget.
ENDFORM.

FORM free_alv_0810.
  IF gr_alv_0810 IS BOUND.
    gr_alv_0810->free( ).
    CLEAR gr_alv_0810.
  ENDIF.
  IF gr_cont_0810 IS BOUND.
    gr_cont_0810->free( ).
    CLEAR gr_cont_0810.
  ENDIF.
  CLEAR: gt_fcat_0810, gs_layout_0810, gt_wo_cost.
ENDFORM.

FORM free_alv_0820.
  IF gr_alv_0820 IS BOUND.
    gr_alv_0820->free( ).
    CLEAR gr_alv_0820.
  ENDIF.
  IF gr_cont_0820 IS BOUND.
    gr_cont_0820->free( ).
    CLEAR gr_cont_0820.
  ENDIF.
  CLEAR: gt_fcat_0820, gs_layout_0820, gt_transfer_log.
ENDFORM.
```

---

## Implementation Strategies

### Strategy 1: Initialization Flag (Recommended)

**Concept**: Use a boolean flag to track first-time initialization.

```abap
" Global variable
DATA: gv_0800_initialized TYPE abap_bool.

" In PBO module
MODULE init_0800 OUTPUT.
  IF gv_0800_initialized IS INITIAL.
    " First time: free old objects, create new ones
    PERFORM free_alv_0800.
    PERFORM create_alv_0800.
    gv_0800_initialized = abap_true.
  ENDIF.
ENDMODULE.

" When navigating away
WHEN '&BACK'.
  CLEAR gv_0800_initialized.  " Reset flag for next entry
  LEAVE TO SCREEN 0100.
```

**Pros**:
- Simple and efficient
- Minimal performance impact
- Clear intent

**Cons**:
- Flag must be manually cleared when leaving screen
- Doesn't work if screen is revisited without leaving

### Strategy 2: Unconditional Free (Safest)

**Concept**: Always free objects before creating, regardless of state.

```abap
MODULE init_0800 OUTPUT.
  " Always free first
  PERFORM free_alv_0800.
  
  " Then create fresh objects
  PERFORM create_alv_0800.
ENDMODULE.
```

**Pros**:
- Guaranteed clean state
- No flag management needed
- Safe for all scenarios

**Cons**:
- Slight performance overhead (frees even if not needed)
- May cause flicker if called every PBO cycle

### Strategy 3: Conditional Free (Hybrid)

**Concept**: Free only if objects exist, create if needed.

```abap
MODULE init_0800 OUTPUT.
  " Free if bound
  IF gr_alv_0800 IS BOUND.
    gr_alv_0800->free( ).
    CLEAR gr_alv_0800.
  ENDIF.
  
  " Create if not bound
  IF gr_alv_0800 IS NOT BOUND.
    CREATE OBJECT gr_alv_0800 ...
  ENDIF.
ENDMODULE.
```

**Pros**:
- Efficient
- Works for all scenarios
- No flag management

**Cons**:
- More verbose
- Requires checking binding state

---

## Common Scenarios

### Scenario 1: Back Button Navigation

**Flow**: Screen 0100 → Screen 0800 → Back to 0100 → Screen 0800 again

```abap
" In Screen 0100 PAI
WHEN '&WBSAMT'.
  CLEAR gv_0800_initialized.  " Reset flag
  LEAVE TO SCREEN 0800.

" In Screen 0800 PBO
MODULE init_0800 OUTPUT.
  IF gv_0800_initialized IS INITIAL.
    PERFORM free_alv_0800.
    PERFORM create_alv_0800.
    gv_0800_initialized = abap_true.
  ENDIF.
ENDMODULE.

" In Screen 0800 PAI
WHEN '&BACK'.
  CLEAR gv_0800_initialized.  " Reset for next entry
  LEAVE TO SCREEN 0100.
```

### Scenario 2: Detail Navigation (0800 → 0810)

**Flow**: Screen 0800 → Detail to 0810 → Back to 0800

```abap
" In Screen 0800 PAI (when user clicks Detail)
WHEN '&DETAIL'.
  CLEAR gv_0810_initialized.  " Reset flag for 0810
  gv_sel_posid_0800 = ls_selected_row-posid.
  gv_from_0800 = abap_true.
  LEAVE TO SCREEN 0810.

" In Screen 0810 PBO
MODULE init_0810 OUTPUT.
  IF gv_0810_initialized IS INITIAL.
    PERFORM free_alv_0810.
    PERFORM create_alv_0810.
    gv_0810_initialized = abap_true.
  ENDIF.
ENDMODULE.

" In Screen 0810 PAI (when user clicks Back)
WHEN '&BACK'.
  IF gv_from_0800 = abap_true.
    CLEAR: gv_0810_initialized, gv_from_0800.
    LEAVE TO SCREEN 0800.
  ELSE.
    CLEAR gv_0810_initialized.
    LEAVE TO SCREEN 0100.
  ENDIF.
```

### Scenario 3: Refresh Button (Stay on Same Screen)

**Flow**: User clicks Refresh while on Screen 0800

```abap
" In Screen 0800 PAI
WHEN '&REFRESH'.
  " Clear data but keep ALV object
  CLEAR gt_budget.
  
  " Re-fetch data
  PERFORM get_budget_data USING p_posid p_period.
  
  " Refresh display without recreating ALV
  IF gr_alv_0800 IS BOUND.
    gr_alv_0800->refresh_table_display( ).
  ENDIF.
```

### Scenario 4: Execute Button (New Data, Same Screen)

**Flow**: User enters new search criteria and clicks Execute

```abap
" In Screen 0800 PAI
WHEN '&EXEC'.
  " Clear old data
  CLEAR gt_budget.
  
  " Fetch new data
  PERFORM get_budget_data USING p_posid p_period.
  
  " Display in ALV (ALV already exists from init_0800)
  IF gr_alv_0800 IS BOUND.
    gr_alv_0800->set_table_for_first_display(
      EXPORTING
        is_layout = gs_layout_0800
        i_default = abap_true
        i_save = 'A'
      CHANGING
        it_fieldcatalog = gt_fcat_0800
        it_outtab = gt_budget ).
  ENDIF.
```

---

## Best Practices

### 1. **Always Free Before Create**

```abap
" WRONG - Creates duplicate objects
IF gr_alv_0800 IS NOT BOUND.
  CREATE OBJECT gr_alv_0800 ...
ENDIF.

" CORRECT - Frees old, creates new
IF gr_alv_0800 IS BOUND.
  gr_alv_0800->free( ).
  CLEAR gr_alv_0800.
ENDIF.
CREATE OBJECT gr_alv_0800 ...
```

### 2. **Clear All Associated Data**

```abap
" WRONG - Leaves orphaned data
IF gr_alv_0800 IS BOUND.
  gr_alv_0800->free( ).
ENDIF.

" CORRECT - Clears everything
IF gr_alv_0800 IS BOUND.
  gr_alv_0800->free( ).
  CLEAR gr_alv_0800.
ENDIF.
CLEAR: gt_fcat_0800, gs_layout_0800, gt_budget.
```

### 3. **Use Separate Forms for Free Operations**

```abap
" GOOD - Organized and reusable
FORM free_alv_0800.
  IF gr_alv_0800 IS BOUND.
    gr_alv_0800->free( ).
    CLEAR gr_alv_0800.
  ENDIF.
  IF gr_cont_0800 IS BOUND.
    gr_cont_0800->free( ).
    CLEAR gr_cont_0800.
  ENDIF.
  CLEAR: gt_fcat_0800, gs_layout_0800, gt_budget.
ENDFORM.

" In module
MODULE init_0800 OUTPUT.
  PERFORM free_alv_0800.
  PERFORM create_alv_0800.
ENDMODULE.
```

### 4. **Reset Flags When Leaving Screen**

```abap
" In PAI when user navigates away
WHEN '&BACK'.
  CLEAR gv_0800_initialized.  " Important!
  LEAVE TO SCREEN 0100.

WHEN '&EXIT'.
  CLEAR gv_0800_initialized.
  LEAVE PROGRAM.
```

### 5. **Handle Event Handlers Properly**

```abap
" When creating ALV with event handlers
MODULE init_0800 OUTPUT.
  DATA: lo_handler TYPE REF TO lcl_alv_handler.

  IF gv_0800_initialized IS INITIAL.
    PERFORM free_alv_0800.

    CREATE OBJECT gr_cont_0800
      EXPORTING container_name = 'CC_ALV_0800'.

    CREATE OBJECT gr_alv_0800
      EXPORTING i_parent = gr_cont_0800.

    " Attach handlers AFTER creating ALV
    CREATE OBJECT lo_handler.
    SET HANDLER lo_handler->handle_double_click_0800 FOR gr_alv_0800.
    SET HANDLER lo_handler->handle_toolbar_0800 FOR gr_alv_0800.

    gv_0800_initialized = abap_true.
  ENDIF.
ENDMODULE.
```

### 6. **Distinguish Between Free and Refresh**

```abap
" FREE: Remove objects completely
PERFORM free_alv_0800.  " Frees ALV, container, clears data

" REFRESH: Update display with existing ALV
gr_alv_0800->refresh_table_display( ).  " Updates display, keeps ALV

" SET_TABLE: Replace data in existing ALV
gr_alv_0800->set_table_for_first_display(
  CHANGING it_outtab = gt_budget ).
```

### 7. **Document State Transitions**

```abap
" Global variables with clear purpose
DATA: gv_0800_initialized TYPE abap_bool.  " First-time init flag
DATA: gv_from_0800 TYPE abap_bool.         " Navigation source flag
DATA: gr_alv_0800 TYPE REF TO cl_gui_alv_grid.  " ALV grid reference
DATA: gr_cont_0800 TYPE REF TO cl_gui_custom_container.  " Container
```

---

## Troubleshooting

### Issue 1: Duplicate ALV Grids Appear

**Symptom**: Multiple ALV grids stacked on top of each other.

**Cause**: Objects not freed before creating new ones.

**Solution**:
```abap
" Add this before CREATE OBJECT
IF gr_alv_0800 IS BOUND.
  gr_alv_0800->free( ).
  CLEAR gr_alv_0800.
ENDIF.
```

### Issue 2: Event Handlers Fire Multiple Times

**Symptom**: Double-click handler called multiple times for single click.

**Cause**: Multiple handler instances attached to same ALV.

**Solution**:
```abap
" Free ALV completely (which removes handlers)
IF gr_alv_0800 IS BOUND.
  gr_alv_0800->free( ).
  CLEAR gr_alv_0800.
ENDIF.

" Then create fresh and attach handlers once
CREATE OBJECT gr_alv_0800 ...
CREATE OBJECT lo_handler.
SET HANDLER lo_handler->handle_double_click_0800 FOR gr_alv_0800.
```

### Issue 3: Memory Leaks Over Time

**Symptom**: Program gets slower with each screen navigation.

**Cause**: Objects not properly freed on navigation.

**Solution**:
```abap
" Always clear flag when leaving screen
WHEN '&BACK'.
  CLEAR gv_0800_initialized.
  LEAVE TO SCREEN 0100.

" Or use unconditional free strategy
MODULE init_0800 OUTPUT.
  PERFORM free_alv_0800.  " Always free first
  PERFORM create_alv_0800.
ENDMODULE.
```

### Issue 4: "Container Already Exists" Error

**Symptom**: Runtime error when creating container.

**Cause**: Container name already in use on screen.

**Solution**:
```abap
" Free container before creating new one
IF gr_cont_0800 IS BOUND.
  gr_cont_0800->free( ).
  CLEAR gr_cont_0800.
ENDIF.

CREATE OBJECT gr_cont_0800
  EXPORTING
    container_name = 'CC_ALV_0800'.
```

### Issue 5: ALV Data Persists After Clear

**Symptom**: Old data still visible after CLEAR statement.

**Cause**: ALV display not refreshed after data clear.

**Solution**:
```abap
" Clear data
CLEAR gt_budget.

" Refresh ALV display
IF gr_alv_0800 IS BOUND.
  gr_alv_0800->refresh_table_display( ).
ENDIF.
```

---

## Global Variables Template

Add these to your `LZSVC_WBS_MENUTOP` include:

```abap
" ===== Screen 0800 Objects =====
DATA: gv_0800_initialized TYPE abap_bool.
DATA: gr_alv_0800 TYPE REF TO cl_gui_alv_grid.
DATA: gr_cont_0800 TYPE REF TO cl_gui_custom_container.
DATA: gt_fcat_0800 TYPE lvc_t_fcat.
DATA: gs_layout_0800 TYPE lvc_s_layo.
DATA: gt_budget TYPE TABLE OF ty_budget.

" ===== Screen 0810 Objects =====
DATA: gv_0810_initialized TYPE abap_bool.
DATA: gr_alv_0810 TYPE REF TO cl_gui_alv_grid.
DATA: gr_cont_0810 TYPE REF TO cl_gui_custom_container.
DATA: gt_fcat_0810 TYPE lvc_t_fcat.
DATA: gs_layout_0810 TYPE lvc_s_layo.
DATA: gt_wo_cost TYPE TABLE OF ty_wo_cost.

" ===== Screen 0820 Objects =====
DATA: gv_0820_initialized TYPE abap_bool.
DATA: gr_alv_0820 TYPE REF TO cl_gui_alv_grid.
DATA: gr_cont_0820 TYPE REF TO cl_gui_custom_container.
DATA: gt_fcat_0820 TYPE lvc_t_fcat.
DATA: gs_layout_0820 TYPE lvc_s_layo.
DATA: gt_transfer_log TYPE TABLE OF ty_transfer_log.

" ===== Navigation Flags =====
DATA: gv_from_0800 TYPE abap_bool.
DATA: gv_from_0810 TYPE abap_bool.
```

---

## Forms Template

Create a dedicated include for free operations:

```abap
*&---------------------------------------------------------------------*
*& Include LZSVC_WBS_MENUF03 - Free Screen Objects
*&---------------------------------------------------------------------*

FORM free_alv_0800.
  IF gr_alv_0800 IS BOUND.
    gr_alv_0800->free( ).
    CLEAR gr_alv_0800.
  ENDIF.
  IF gr_cont_0800 IS BOUND.
    gr_cont_0800->free( ).
    CLEAR gr_cont_0800.
  ENDIF.
  CLEAR: gt_fcat_0800, gs_layout_0800, gt_budget.
ENDFORM.

FORM free_alv_0810.
  IF gr_alv_0810 IS BOUND.
    gr_alv_0810->free( ).
    CLEAR gr_alv_0810.
  ENDIF.
  IF gr_cont_0810 IS BOUND.
    gr_cont_0810->free( ).
    CLEAR gr_cont_0810.
  ENDIF.
  CLEAR: gt_fcat_0810, gs_layout_0810, gt_wo_cost.
ENDFORM.

FORM free_alv_0820.
  IF gr_alv_0820 IS BOUND.
    gr_alv_0820->free( ).
    CLEAR gr_alv_0820.
  ENDIF.
  IF gr_cont_0820 IS BOUND.
    gr_cont_0820->free( ).
    CLEAR gr_cont_0820.
  ENDIF.
  CLEAR: gt_fcat_0820, gs_layout_0820, gt_transfer_log.
ENDFORM.

FORM free_all_screens.
  PERFORM free_alv_0800.
  PERFORM free_alv_0810.
  PERFORM free_alv_0820.
ENDFORM.
```

---

## Implementation Checklist

- [ ] Define initialization flags for each screen
- [ ] Define ALV grid and container references for each screen
- [ ] Define field catalog and layout variables for each screen
- [ ] Create free forms for each screen's objects
- [ ] Implement free-and-reinitialize pattern in PBO modules
- [ ] Clear flags when navigating away from screen
- [ ] Test navigation back to same screen
- [ ] Test detail navigation (0800 → 0810 → back)
- [ ] Test refresh button (stays on same screen)
- [ ] Test execute button (new data, same screen)
- [ ] Verify no duplicate ALV grids appear
- [ ] Verify event handlers fire only once
- [ ] Monitor memory usage over multiple navigations
- [ ] Test error scenarios (invalid input, no data)

---

## Key Takeaways

1. **Always free objects before creating new ones** to prevent duplicates and memory leaks
2. **Use initialization flags** to track first-time setup and avoid unnecessary recreation
3. **Clear all associated data** (field catalog, layout, data tables) when freeing objects
4. **Reset flags when leaving screen** to ensure clean state on re-entry
5. **Use separate forms** for free operations to keep code organized and reusable
6. **Distinguish between free and refresh** - free removes objects, refresh updates display
7. **Attach event handlers after creating ALV** to avoid multiple handler instances
8. **Test navigation scenarios** thoroughly to catch memory leaks and duplicate objects

This pattern ensures your screens remain responsive and memory-efficient even after multiple navigations.
