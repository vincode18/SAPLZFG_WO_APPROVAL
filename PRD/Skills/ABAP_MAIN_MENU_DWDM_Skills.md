# ABAP Main Menu Skills - Reusable Implementation Guide

## Purpose

This document provides a comprehensive reference for implementing a **Main Menu screen** in an ABAP Function Group program. It serves as a knowledge base for ABAPER Agents to quickly understand and implement the core patterns, structures, and techniques used in the WBS Menu Function Group.

---

## Table of Contents

1. [Core Architecture](#core-architecture)
2. [Screen Design Patterns](#screen-design-patterns)
3. [Global Variables & Data Types](#global-variables--data-types)
4. [Module Structure](#module-structure)
5. [ALV Event Handling](#alv-event-handling)
6. [Navigation Patterns](#navigation-patterns)
7. [Common Implementation Patterns](#common-implementation-patterns)
8. [Best Practices](#best-practices)

---

## Core Architecture

### Function Group Structure

A Main Menu function group typically consists of:

```
SAPLZSVC_WBS_MENU/
├── 1. Master Program/
│   └── ZSVC_WBS_MENU.abap          (Main entry point)
├── 2. PBO Modules/
│   ├── LZSVC_WBS_MENUO00.abap      (Screen 0100 OUTPUT)
│   ├── LZSVC_WBS_MENUO01.abap      (Screen 0800 OUTPUT)
│   └── LZSVC_WBS_MENUO02.abap      (Screen 0810 OUTPUT)
├── 3. PAI Modules/
│   ├── LZSVC_WBS_MENUI00.abap      (Screen 0100 INPUT)
│   ├── LZSVC_WBS_MENUI01.abap      (Screen 0800 INPUT)
│   └── LZSVC_WBS_MENUI02.abap      (Screen 0810 INPUT)
├── 4. Forms/
│   ├── LZSVC_WBS_MENUF01.abap      (Data retrieval forms)
│   └── LZSVC_WBS_MENUF02.abap      (ALV display forms)
├── 5. Types/
│   └── LZSVC_WBS_MENUTOP.abap      (Global types & variables)
├── 6. Classes/
│   └── LZSVC_WBS_MENUE01.abap      (ALV event handler class)
└── 7. Includes/
    └── (Additional includes as needed)
```

### Naming Convention

- **Screens**: `0100` (Main Menu), `0800` (Detail 1), `0810` (Detail 2), etc.
- **Modules**: `LZSVC_WBS_MENU[O|I][screen_number].abap`
  - `O` = OUTPUT (PBO)
  - `I` = INPUT (PAI)
- **Forms**: `LZSVC_WBS_MENUF[number].abap`
- **Types**: `LZSVC_WBS_MENUTOP.abap`
- **Classes**: `LZSVC_WBS_MENUE[number].abap`

---

## Screen Design Patterns

### Screen 0100 - Main Menu

**Purpose**: Entry point with navigation buttons to different functional areas.

**Layout Pattern**:
```
╔════════════════════════════════════════════════════════════════╗
║                    Main Menu Title                             ║
╠════════════════════════════════════════════════════════════════╣
║  [Toolbar with buttons]                                        ║
╠════════════════════════════════════════════════════════════════╣
║                                                                ║
║  ┌─ Functional Area 1 ──────────────────────────────────────┐ ║
║  │  [Button 1] Description                                  │ ║
║  │  [Button 2] Description                                  │ ║
║  └────────────────────────────────────────────────────────┘ ║
║                                                                ║
║  ┌─ Functional Area 2 ──────────────────────────────────────┐ ║
║  │  [Button 3] Description                                  │ ║
║  │  [Button 4] Description                                  │ ║
║  └────────────────────────────────────────────────────────┘ ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
```

**Key Elements**:
- **Title**: Static text describing the menu
- **Function Codes**: Each button has a unique function code (e.g., `&WBSAMT`, `&WBSREM`)
- **Toolbar**: Standard toolbar with `&BACK`, `&EXIT`, `&HELP`
- **Navigation**: Each button leads to a detail screen (0800, 0810, etc.)

### Detail Screens (0800, 0810, etc.)

**Purpose**: Display data with ALV grid and filters.

**Layout Pattern**:
```
╔════════════════════════════════════════════════════════════════╗
║  [Toolbar: Execution, Refresh, Back, Exit]                    ║
╠════════════════════════════════════════════════════════════════╣
║  Screen Title                                                  ║
║                                                                ║
║  Filter Section (if applicable):                              ║
║  [Input Field 1] [Input Field 2] [Input Field 3]             ║
║                                                                ║
║  ┌────────────────────────────────────────────────────────┐  ║
║  │                    ALV Grid                            │  ║
║  │  (Custom Control: CC_ALV_0800)                         │  ║
║  │                                                        │  ║
║  └────────────────────────────────────────────────────────┘  ║
╚════════════════════════════════════════════════════════════════╝
```

**Key Elements**:
- **Filter Fields**: Input fields for user to specify search criteria
- **ALV Container**: Custom control for displaying tabular data
- **Toolbar**: Standard toolbar + custom buttons (e.g., `GOTO_CJ33`, `EXPORT_XLS`)

---

## Global Variables & Data Types

### Types Definition (LZSVC_WBS_MENUTOP)

**Structure for Budget Data**:
```abap
TYPES: BEGIN OF ty_budget,
         posid TYPE prps-posid,       " WBS Element (External)
         poski TYPE prps-poski,       " Parent WBS internal number
         stufe TYPE prps-stufe,       " Hierarchy Level
         post1 TYPE prps-post1,       " WBS Description
         twaer TYPE bpge-twaer,       " Currency
         wtgev TYPE bpge-wtgev,       " Current Budget (KBFC-WTGEV)
         wtver TYPE wrbtr,            " Distributed (KBUD-WTGES)
         wtvtb TYPE wrbtr,            " Distributable (WTGEV - WTVER)
         wtzuw TYPE wrbtr,            " Assigned (KBFC-WTGES)
         wtrem TYPE wrbtr,            " Remaining Budget (WTGEV - WTGES from KBFC)
       END OF ty_budget.
```

**Global Variables Pattern**:
```abap
" Screen navigation & state
DATA: gv_from_0800 TYPE abap_bool.
DATA: gv_sel_posid_0800 TYPE prps-posid.
DATA: gv_sel_post1_0800 TYPE prps-post1.

" ALV references
DATA: gr_alv_0800 TYPE REF TO cl_gui_alv_grid.
DATA: gr_alv_0810 TYPE REF TO cl_gui_alv_grid.
DATA: gr_container_0800 TYPE REF TO cl_gui_custom_container.
DATA: gr_container_0810 TYPE REF TO cl_gui_custom_container.

" Data tables
DATA: gt_budget TYPE TABLE OF ty_budget.
DATA: gt_wo_cost TYPE TABLE OF ty_wo_cost.

" ALV field catalog
DATA: gt_fieldcat TYPE lvc_t_fcat.
DATA: gs_layout TYPE lvc_s_layo.
```

---

## Module Structure

### PBO Module Pattern (OUTPUT)

**Purpose**: Prepare screen data before display.

```abap
MODULE status_0100 OUTPUT.
  SET PF-STATUS 'ZSTAT_0100'.
  SET TITLEBAR 'ZTITLE_0100'.
  " Initialize screen fields if needed
ENDMODULE.

MODULE status_0800 OUTPUT.
  SET PF-STATUS 'ZSTAT_0800'.
  SET TITLEBAR 'ZTITLE_0800'.
  
  " Populate header fields (if coming from another screen)
  p_wbs_hdr = gv_sel_posid_0800.
  p_dsc_hdr = gv_sel_post1_0800.
ENDMODULE.
```

**Key Points**:
- Set GUI status and title bar
- Populate output fields from global variables
- Initialize ALV grid if first time
- Avoid heavy processing (use PAI for that)

### PAI Module Pattern (INPUT)

**Purpose**: Handle user input and navigation.

```abap
MODULE user_command_0100 INPUT.
  CASE sy-ucomm.
    WHEN '&WBSAMT'.
      CLEAR: gv_from_0800, gv_sel_posid_0800.
      LEAVE TO SCREEN 0800.
    WHEN '&WBSREM'.
      CLEAR: gv_from_0800, gv_sel_posid_0800.
      LEAVE TO SCREEN 0810.
    WHEN '&BACK' OR '&EXIT'.
      LEAVE PROGRAM.
  ENDCASE.
  CLEAR sy-ucomm.
ENDMODULE.
```

**Key Points**:
- Use `CASE sy-ucomm` to handle function codes
- Clear global state when navigating to avoid stale data
- Always `CLEAR sy-ucomm` at the end
- Use `LEAVE TO SCREEN` for navigation
- Use `LEAVE PROGRAM` for exit

---

## ALV Event Handling

### ALV Handler Class Pattern

**Definition**:
```abap
CLASS lcl_alv_handler DEFINITION.
  PUBLIC SECTION.
    METHODS handle_double_click_0800
      FOR EVENT double_click OF cl_gui_alv_grid
      IMPORTING e_row e_column es_row_no.
    
    METHODS handle_toolbar_0800
      FOR EVENT toolbar OF cl_gui_alv_grid
      IMPORTING e_object e_interactive.
    
    METHODS handle_user_command_0800
      FOR EVENT user_command OF cl_gui_alv_grid
      IMPORTING e_ucomm.
ENDCLASS.
```

### Double-Click Handler Pattern

**Purpose**: Navigate to external transaction (e.g., CJ33) when user double-clicks a row.

```abap
METHOD handle_double_click_0800.
  DATA: ls_budget TYPE ty_budget.
  DATA: lv_pspid TYPE proj-pspid.
  DATA: lv_pspnr TYPE prps-pspnr.

  " Step 1: Read the clicked row from the data table
  READ TABLE gt_budget INTO ls_budget INDEX es_row_no-row_id.
  IF sy-subrc = 0.
    
    " Step 2: Get internal WBS number (PSPNR) from POSID
    CLEAR: lv_pspnr, lv_pspid.
    SELECT SINGLE pspnr INTO lv_pspnr
      FROM prps
      WHERE posid = ls_budget-posid.

    " Step 3: Walk up PRHI hierarchy to find project definition (PSPID)
    IF lv_pspnr IS NOT INITIAL.
      SELECT SINGLE p~pspid INTO lv_pspid
        FROM prhi AS h
        INNER JOIN proj AS p ON p~pspnr = h~psphi
        WHERE h~posnr = lv_pspnr.
    ENDIF.

    " Step 4: Set parameter IDs and call transaction
    SET PARAMETER ID 'PRO' FIELD ls_budget-posid.
    SET PARAMETER ID 'PSP' FIELD lv_pspid.
    CALL TRANSACTION 'CJ33' AND SKIP FIRST SCREEN.
  ENDIF.
ENDMETHOD.
```

### Toolbar Handler Pattern

**Purpose**: Add custom buttons to ALV toolbar.

```abap
METHOD handle_toolbar_0800.
  DATA: ls_button TYPE stb_button.

  " Add separator
  CLEAR ls_button.
  ls_button-butn_type = 3.  " Separator
  APPEND ls_button TO e_object->mt_toolbar.

  " Add custom button
  CLEAR ls_button.
  ls_button-function  = 'GOTO_CJ33'.
  ls_button-icon      = icon_display.
  ls_button-text      = 'Display in CJ33'.
  ls_button-quickinfo = 'Open selected WBS in transaction CJ33'.
  APPEND ls_button TO e_object->mt_toolbar.
ENDMETHOD.
```

### User Command Handler Pattern

**Purpose**: Handle custom button clicks in ALV.

```abap
METHOD handle_user_command_0800.
  DATA: ls_budget TYPE ty_budget.
  DATA: lt_rows TYPE lvc_t_row.
  DATA: ls_row TYPE lvc_s_row.

  CASE e_ucomm.
    WHEN 'GOTO_CJ33'.
      " Get selected rows
      gr_alv_0800->get_selected_rows( IMPORTING et_index_rows = lt_rows ).
      READ TABLE lt_rows INTO ls_row INDEX 1.
      
      IF sy-subrc = 0.
        READ TABLE gt_budget INTO ls_budget INDEX ls_row-index.
        IF sy-subrc = 0.
          " Process selected row
          " ... (similar to double-click handler)
        ENDIF.
      ELSE.
        MESSAGE i398(00) WITH 'Please select a row first' '' '' ''.
      ENDIF.

    WHEN 'EXPORT_XLS'.
      MESSAGE i398(00) WITH 'Use standard ALV export (Ctrl+Shift+F7)' '' '' ''.
  ENDCASE.
ENDMETHOD.
```

---

## Navigation Patterns

### Screen Navigation Flow

**Pattern 1: Linear Navigation**
```
Screen 0100 (Main Menu)
   │
   ├─ Button 1 ──► Screen 0800 (Detail 1)
   │                  │
   │                  └─ Back ──► Screen 0100
   │
   └─ Button 2 ──► Screen 0810 (Detail 2)
                      │
                      └─ Back ──► Screen 0100
```

**Pattern 2: Hierarchical Navigation**
```
Screen 0100 (Main Menu)
   │
   └─ Button ──► Screen 0800 (Detail 1)
                    │
                    └─ Detail Button ──► Screen 0810 (Detail 2)
                                           │
                                           └─ Back ──► Screen 0800
```

### Pass-Through Variables Pattern

**When navigating from Screen A to Screen B with context**:

```abap
" In Screen A PAI (before LEAVE TO SCREEN B):
gv_sel_posid_0800 = ls_selected_row-posid.
gv_sel_post1_0800 = ls_selected_row-post1.
gv_from_0800 = abap_true.
LEAVE TO SCREEN 0810.

" In Screen B PBO:
MODULE status_0810 OUTPUT.
  p_wbs_hdr = gv_sel_posid_0800.
  p_dsc_hdr = gv_sel_post1_0800.
ENDMODULE.

" In Screen B PAI (when user clicks Back):
WHEN '&BACK'.
  IF gv_from_0800 = abap_true.
    CLEAR: gv_from_0800, gv_sel_posid_0800.
    LEAVE TO SCREEN 0800.   " Return to Screen 0800
  ELSE.
    LEAVE TO SCREEN 0100.   " Return to Main Menu
  ENDIF.
```

---

## Common Implementation Patterns

### Data Retrieval Pattern

**Form Structure**:
```abap
FORM get_budget_data USING iv_posid TYPE prps-posid
                           iv_period TYPE char3.
  DATA: lv_posid_norm TYPE prps-posid.
  DATA: ls_prps TYPE prps.
  DATA: lv_poski TYPE prps-poski.
  DATA: lt_prps TYPE TABLE OF prps.
  DATA: ls_budget TYPE ty_budget.

  " Step 1: Normalize input (strip separators, uppercase)
  lv_posid_norm = iv_posid.
  TRANSLATE lv_posid_norm TO UPPER CASE.
  " Remove non-alphanumeric characters...

  " Step 2: Get the input WBS and its parent
  SELECT SINGLE * INTO ls_prps
    FROM prps
    WHERE posid = lv_posid_norm.
  
  IF sy-subrc = 0.
    lv_poski = ls_prps-poski.
    
    " Step 3: Guard check for Level-1 WBS (no parent)
    IF lv_poski IS INITIAL.
      APPEND ls_prps TO lt_prps.
    ELSE.
      " Get all siblings under same parent
      SELECT * INTO TABLE lt_prps
        FROM prps
        WHERE poski = lv_poski
        ORDER BY posid.
    ENDIF.

    " Step 4: Loop through WBS elements and fetch budget data
    LOOP AT lt_prps INTO ls_prps.
      CLEAR ls_budget.
      ls_budget-posid = ls_prps-posid.
      ls_budget-poski = ls_prps-poski.
      ls_budget-stufe = ls_prps-stufe.
      ls_budget-post1 = ls_prps-post1.

      " Fetch budget from BPGE
      SELECT SINGLE twaer wtgev wtges
        INTO (ls_budget-twaer, ls_budget-wtgev, ls_budget-wtzuw)
        FROM bpge
        WHERE objnr = ls_prps-objnr
          AND versn = '000'
          AND vorga = 'KBFC'.

      " Fetch distributed amount
      SELECT SINGLE wtges INTO ls_budget-wtver
        FROM bpge
        WHERE objnr = ls_prps-objnr
          AND versn = '000'
          AND vorga = 'KBUD'.

      " Calculate derived fields
      ls_budget-wtvtb = ls_budget-wtgev - ls_budget-wtver.
      ls_budget-wtrem = ls_budget-wtgev - ls_budget-wtzuw.

      APPEND ls_budget TO gt_budget.
    ENDLOOP.
  ENDIF.
ENDFORM.
```

### ALV Display Pattern

**Form Structure**:
```abap
FORM display_budget_alv.
  DATA: ls_fieldcat TYPE lvc_s_fcat.
  DATA: ls_layout TYPE lvc_s_layo.

  " Step 1: Build field catalog
  CLEAR gt_fieldcat.
  
  CLEAR ls_fieldcat.
  ls_fieldcat-fieldname = 'POSID'.
  ls_fieldcat-coltext = 'WBS Element'.
  ls_fieldcat-col_pos = 1.
  APPEND ls_fieldcat TO gt_fieldcat.

  CLEAR ls_fieldcat.
  ls_fieldcat-fieldname = 'STUFE'.
  ls_fieldcat-coltext = 'Lev'.
  ls_fieldcat-col_pos = 2.
  APPEND ls_fieldcat TO gt_fieldcat.

  " ... (add more columns)

  " Step 2: Configure layout
  CLEAR ls_layout.
  ls_layout-zebra = abap_true.
  ls_layout-sel_mode = 'D'.  " Single row selection
  ls_layout-cwidth_opt = abap_true.

  " Step 3: Create ALV grid (if first time)
  IF gr_alv_0800 IS INITIAL.
    CREATE OBJECT gr_container_0800
      EXPORTING container_name = 'CC_ALV_0800'.
    
    CREATE OBJECT gr_alv_0800
      EXPORTING i_parent = gr_container_0800.
    
    DATA: lo_handler TYPE REF TO lcl_alv_handler.
    CREATE OBJECT lo_handler.
    
    SET HANDLER lo_handler->handle_double_click_0800 FOR gr_alv_0800.
    SET HANDLER lo_handler->handle_toolbar_0800 FOR gr_alv_0800.
    SET HANDLER lo_handler->handle_user_command_0800 FOR gr_alv_0800.
  ENDIF.

  " Step 4: Display data
  gr_alv_0800->set_table_for_first_display(
    EXPORTING
      is_layout = ls_layout
      i_default = abap_true
      i_save = 'A'
    CHANGING
      it_fieldcatalog = gt_fieldcat
      it_outtab = gt_budget ).
ENDFORM.
```

### Input Validation Pattern

```abap
FORM validate_input USING iv_input TYPE any
                    RETURNING rv_valid TYPE abap_bool.
  DATA: lv_input TYPE string.
  
  lv_input = iv_input.
  
  " Check if input is empty
  IF lv_input IS INITIAL.
    MESSAGE e001(00) WITH 'Input field cannot be empty'.
    rv_valid = abap_false.
    RETURN.
  ENDIF.
  
  " Check if input exists in database
  SELECT COUNT(*) INTO sy-dbcnt
    FROM prps
    WHERE posid = lv_input.
  
  IF sy-dbcnt = 0.
    MESSAGE e001(00) WITH 'WBS element not found:' lv_input.
    rv_valid = abap_false.
    RETURN.
  ENDIF.
  
  rv_valid = abap_true.
ENDFORM.
```

---

## Best Practices

### 1. **Screen Design**
- Keep Main Menu simple and uncluttered
- Use clear, descriptive button labels
- Group related functions together
- Provide visual hierarchy with sections

### 2. **Navigation**
- Always provide a `&BACK` button to return to previous screen
- Use global variables to pass context between screens
- Clear state when navigating to avoid data leakage
- Document navigation flow in comments

### 3. **ALV Grid**
- Always check `sy-subrc` after database operations
- Use field catalog to control column order and formatting
- Implement double-click handlers for drill-down functionality
- Add custom toolbar buttons for common operations
- Use `get_selected_rows()` to get user selection

### 4. **Data Retrieval**
- Normalize user input before database queries
- Use `SELECT SINGLE` for single records, `SELECT ... INTO TABLE` for multiple
- Always check `sy-subrc` after SELECT
- Use `CLEAR` to initialize variables before SELECT
- Document complex SQL logic with comments

### 5. **Error Handling**
- Use `MESSAGE` statements with appropriate severity (E, W, I)
- Validate user input before processing
- Provide meaningful error messages
- Use message classes for consistency

### 6. **Code Organization**
- Separate concerns: modules for screens, forms for logic, classes for events
- Use consistent naming conventions
- Keep forms focused on single responsibility
- Document complex algorithms with comments

### 7. **Performance**
- Use `SELECT SINGLE` instead of `SELECT ... UP TO 1 ROW`
- Avoid nested loops when possible
- Use `INDEX` for table lookups when available
- Consider using `HASHED` or `SORTED` tables for large datasets

### 8. **Maintainability**
- Use meaningful variable names
- Add comments for non-obvious logic
- Keep methods/forms under 50 lines when possible
- Use constants for magic numbers
- Document assumptions and constraints

---

## Quick Reference: Function Codes

| Function Code | Standard Meaning | Usage |
|---|---|---|
| `&EXEC` | Execute | Run data retrieval |
| `&REFRESH` | Refresh | Reload current data |
| `&BACK` | Back | Return to previous screen |
| `&EXIT` | Exit | Leave program |
| `&HELP` | Help | Show help text |

---

## Quick Reference: Common Tables

| Table | Purpose | Key Fields |
|---|---|---|
| `PRPS` | WBS Element | POSID (external), PSPNR (internal), POSKI (parent), STUFE (level), POST1 (description) |
| `PRHI` | WBS Hierarchy | POSNR (child), POSPHI (parent), PSPHI (project) |
| `PROJ` | Project Definition | PSPID (external), PSPNR (internal) |
| `BPGE` | Budget | OBJNR (object), VORGA (category), WTGEV (current), WTGES (assigned) |

---

## Implementation Checklist

- [ ] Create function group structure with proper naming
- [ ] Define global types in LZSVC_WBS_MENUTOP
- [ ] Create Main Menu screen (0100) with buttons
- [ ] Create detail screens (0800, 0810, etc.)
- [ ] Implement PBO modules for each screen
- [ ] Implement PAI modules for navigation
- [ ] Create data retrieval forms
- [ ] Create ALV display forms
- [ ] Implement ALV event handler class
- [ ] Test navigation flow
- [ ] Test data retrieval and validation
- [ ] Test ALV interactions (double-click, toolbar buttons)
- [ ] Document screen layouts and field mappings
- [ ] Test error handling and edge cases

---

## Example: Complete Navigation Cycle

```abap
" User clicks &WBSAMT on Screen 0100
WHEN '&WBSAMT'.
  CLEAR: gv_from_0800, gv_sel_posid_0800.
  LEAVE TO SCREEN 0800.

" Screen 0800 PBO initializes
MODULE status_0800 OUTPUT.
  SET PF-STATUS 'ZSTAT_0800'.
  SET TITLEBAR 'ZTITLE_0800'.
ENDMODULE.

" User enters WBS and clicks &EXEC on Screen 0800
WHEN '&EXEC'.
  PERFORM get_budget_data USING p_posid p_period.
  PERFORM display_budget_alv.

" User double-clicks a row in ALV
" ALV handler reads row and calls CJ33

" User clicks &DETAIL on Screen 0800
WHEN '&DETAIL'.
  gv_sel_posid_0800 = ls_selected_row-posid.
  gv_sel_post1_0800 = ls_selected_row-post1.
  gv_from_0800 = abap_true.
  LEAVE TO SCREEN 0810.

" Screen 0810 PBO populates header from global variables
MODULE status_0810 OUTPUT.
  p_wbs_hdr = gv_sel_posid_0800.
  p_dsc_hdr = gv_sel_post1_0800.
ENDMODULE.

" User clicks &BACK on Screen 0810
WHEN '&BACK'.
  IF gv_from_0800 = abap_true.
    CLEAR: gv_from_0800, gv_sel_posid_0800.
    LEAVE TO SCREEN 0800.
  ELSE.
    LEAVE TO SCREEN 0100.
  ENDIF.
```

---

## Notes for ABAPER Agent

When implementing a Main Menu function group:

1. **Start with structure**: Create the folder hierarchy and include files first
2. **Define types early**: All data structures should be in LZSVC_WBS_MENUTOP
3. **Screen design**: Keep screens simple and focused on single task
4. **Navigation**: Use global variables to pass context, always clear state
5. **ALV**: Implement event handlers for interactivity
6. **Testing**: Test each screen independently, then test navigation flow
7. **Documentation**: Document screen layouts, field mappings, and complex logic

This guide provides the foundation. Adapt patterns to your specific requirements while maintaining consistency with these principles.
