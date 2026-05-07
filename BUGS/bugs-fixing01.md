# Error Analysis & Fix Report
## "Control Framework: Error Processing Control"

**Program:** ZFG_WO_APPROVAL  
**Affected Screens:** 0310 and 0320  
**Root Cause Category:** Multiple — wrong subscreen type, missing DISPATCH, missing tree for Screen 0310

---

## Summary of All Bugs Found

| # | File | Bug | Severity |
|---|---|---|---|
| 1 | `0311.abap` (Screen 0311 flow) | SELECTION-SCREEN subscreen used inside a dynpro `CALL SUBSCREEN` — incompatible types | **Critical — causes CF error** |
| 2 | `0310.abap` (Screen 0310 flow) | Missing `CALL SUBSCREEN ss_0310 INCLUDING` before tree/ALV are created | **Critical — causes CF error** |
| 3 | `LZFG_WO_APPROVALTOP` | `gv_0310_tree_initialized` declared but `gv_0320_tree_initialized` is missing | **High — syntax/runtime error** |
| 4 | `STATUS_0320` (O01) | `init_tree_0320` never called — tree for Screen 0320 was never built | **High — no tree on 0320** |
| 5 | `USER_COMMAND_0320` (I01) | `CL_GUI_CFW=>DISPATCH` missing — tree events on 0320 never fire | **High — tree click does nothing** |
| 6 | `Screen 0320` flow logic | No `CALL SUBSCREEN` lines — Screen 0320 has no subscreen wiring at all | **High — no filter subscreen** |
| 7 | `Screen 0321` flow logic | File says "NOT USED (reserved for future use)" — screen body is empty | **High — wrong screen used** |

---

## Bug 1 — CRITICAL: Wrong Subscreen Type in Screen 0311

### What happened
In `LZFG_WO_APPROVALTOP`, the filter screen was defined using `SELECTION-SCREEN BEGIN OF SCREEN 0311 AS SUBSCREEN`. This generates a **selection-screen**, not a dynpro subscreen. When Screen 0310's flow logic calls `CALL SUBSCREEN ss_0310 INCLUDING sy-repid '0311'`, SAP tries to embed it as a **dynpro subscreen** but finds a selection-screen object. This mismatch is what triggers `Control Framework: Error processing control`.

The generated flow logic for Screen 0311 (shown in `0311.abap`) confirms this — it contains internal SAP selection-screen modules (`%_INIT_PBO_J`, `%_PBO_REPORT`, etc.) which are incompatible with `CALL SUBSCREEN` from a dynpro.

### Fix

**Step 1 — Remove** the `SELECTION-SCREEN` block from `LZFG_WO_APPROVALTOP.abap`.

Delete these lines:
```abap
" DELETE THESE LINES FROM LZFG_WO_APPROVALTOP:
SELECTION-SCREEN BEGIN OF SCREEN 0311 AS SUBSCREEN.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT (15) TEXT-s11 FOR FIELD p_wk310.
    PARAMETERS p_wk310 TYPE werks_d.
  SELECTION-SCREEN END OF LINE.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT (15) TEXT-s12 FOR FIELD p_au310.
    PARAMETERS p_au310 TYPE aufnr.
  SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF SCREEN 0311.
```

Keep the DATA declarations for `p_wk310` and `p_au310` — just change them from `PARAMETERS` to plain `DATA`:

```abap
" REPLACE with plain DATA declarations:
DATA: p_wk310 TYPE werks_d,
      p_au310 TYPE aufnr.
```

**Step 2 — Recreate Screen 0311 in SE51 as a proper dynpro subscreen.**

Open SE51, program `SAPLZFG_WO_APPROVAL`, screen `0311`. Delete the existing screen and create a new one:

| Property | Value |
|---|---|
| Screen type | **Subscreen** |
| Short description | `Plant / WO Filter for Screen 0310` |

In the **Layout Editor** add these 5 elements in one row:

| Element Type | Name | Label | Length | FctCode |
|---|---|---|---|---|
| Text (label) | — | `Plant:` | — | — |
| Input/output field | `P_WK310` | — | 4 | — |
| Text (label) | — | `Work Order:` | — | — |
| Input/output field | `P_AU310` | — | 12 | — |
| Pushbutton | `BT_EXEC_310` | `Execute` | 8 | `EXEC_310` |

> Use **Dict./Program Fields** to drag `P_WK310` and `P_AU310` — they now exist as global DATA fields so the editor will find them.

**Step 3 — Replace the flow logic in `0311.abap`:**

```abap
*&---------------------------------------------------------------------*
*& Screen : 0311 — Subscreen: Plant / Work Order Filter for Screen 0310
*&---------------------------------------------------------------------*
PROCESS BEFORE OUTPUT.
* No PBO module needed — P_WK310 and P_AU310 are plain input fields.

PROCESS AFTER INPUT.
* PAI handled entirely by host screen 0310 USER_COMMAND_0310.
* Function code EXEC_310 raised by BT_EXEC_310 is transported to host.
```

---

## Bug 2 — CRITICAL: Screen 0310 Flow Logic Calls Subscreen Before Module

### What happened
The current `0310.abap` flow logic is:
```abap
PROCESS BEFORE OUTPUT.
  MODULE status_0310.                              ← creates tree INSIDE here
  CALL SUBSCREEN ss_0310 INCLUDING sy-repid '0311'.
```

`MODULE status_0310` calls `init_tree_0310` which does `CREATE OBJECT gr_tree_cont_0310`. At this point the subscreen area `ss_0310` has not yet been rendered — SAP has not processed the screen layout. The Control Framework receives a `CREATE OBJECT` command for a container that references an area that does not yet exist on screen. This causes the CF automation queue error.

### Fix

Swap the order — `CALL SUBSCREEN` must come **before** `MODULE status_0310` in PBO:

**Replace `0310.abap` with:**

```abap
*&---------------------------------------------------------------------*
*& Screen : 0310 — 3-Panel (Tree + Subscreen + ALV)
*& Flow Logic
*&---------------------------------------------------------------------*
PROCESS BEFORE OUTPUT.
  CALL SUBSCREEN ss_0310 INCLUDING sy-repid '0311'.
  MODULE status_0310.

PROCESS AFTER INPUT.
  CALL SUBSCREEN ss_0310.
  MODULE user_command_0310.
```

> **Rule:** `CALL SUBSCREEN INCLUDING` must always appear **before** any MODULE that creates frontend controls (containers, ALV, tree). The subscreen rendering must complete before any control tries to attach to the screen layout.

---

## Bug 3 — Missing `gv_0320_tree_initialized` Declaration

### What happened
`STATUS_0310` references `gv_0310_tree_initialized` which is declared, but `STATUS_0320` was meant to reference `gv_0320_tree_initialized` which was **never added** to `LZFG_WO_APPROVALTOP`. The include for Screen 0320 tree objects is completely missing from the TOP include.

### Fix

Add the following block to `LZFG_WO_APPROVALTOP.abap` **after** the existing Screen 0320 ALV objects block:

```abap
*----------------------------------------------------------------------*
* TREE OBJECTS — Screen 0320 (Pending WO Tree Filter)
*----------------------------------------------------------------------*
CLASS lcl_tree_event_0320 DEFINITION DEFERRED.

TYPES: item_table_0320_type LIKE STANDARD TABLE OF mtreeitm
         WITH DEFAULT KEY.

DATA: gv_0320_tree_initialized TYPE abap_bool,
      gr_tree_0320              TYPE REF TO cl_gui_list_tree,
      gr_tree_cont_0320         TYPE REF TO cl_gui_custom_container,
      go_tree_evt_0320          TYPE REF TO lcl_tree_event_0320,
      gv_tree_selected_key_320  TYPE tv_nodekey,
      gt_pending_tree_320       TYPE STANDARD TABLE OF ztwoapprh.

*----------------------------------------------------------------------*
* Subscreen 0321 input fields — Plant / Work Order filter for Screen 0320
*----------------------------------------------------------------------*
DATA: p_werks_320 TYPE werks_d,
      p_aufnr_320 TYPE aufnr.

*----------------------------------------------------------------------*
* Tree node key constants for Screen 0320
*----------------------------------------------------------------------*
CONSTANTS:
  BEGIN OF gc_tree_0320,
    root    TYPE tv_nodekey VALUE 'PEND_ROOT2',
    monthly TYPE tv_nodekey VALUE 'MONTHLY2',
    weekly  TYPE tv_nodekey VALUE 'WEEKLY2',
  END OF gc_tree_0320.

*----------------------------------------------------------------------*
* Event handler class DEFINITION for Screen 0320 tree
* IMPLEMENTATION lives in LZFG_WO_APPROVALF07
*----------------------------------------------------------------------*
CLASS lcl_tree_event_0320 DEFINITION.
  PUBLIC SECTION.
    METHODS handle_node_dblclick_0320
      FOR EVENT node_double_click
      OF cl_gui_list_tree
      IMPORTING node_key.
    METHODS handle_item_dblclick_0320
      FOR EVENT item_double_click
      OF cl_gui_list_tree
      IMPORTING node_key item_name.
ENDCLASS.
```

> **Important:** The constants `gc_tree_0320-root/monthly/weekly` use suffix `2` (`PEND_ROOT2`, `MONTHLY2`, `WEEKLY2`) to avoid a key collision with Screen 0310's constants (`PEND_ROOT`, `MONTHLY`, `WEEKLY`). Both trees share the same `CL_GUI_LIST_TREE` node key namespace so duplicate keys would cause tree rendering errors. The data variable names also use `_320` suffix to avoid collision with the 0310 tree variables.

---

## Bug 4 — `STATUS_0320` Never Calls `init_tree_0320`

### What happened
The current `STATUS_0320` in `LZFG_WO_APPROVALO01` only calls `init_alv_0320` — no tree is ever created for Screen 0320. The tree-related FORMs and class for Screen 0320 are also missing from `LZFG_WO_APPROVALF07`.

### Fix — Part A: Add tree FORMs to `LZFG_WO_APPROVALF07.abap`

Append these FORMs at the end of `LZFG_WO_APPROVALF07.abap`:

```abap
*======================================================================*
* SCREEN 0320 — TREE SECTION (CL_GUI_LIST_TREE — Pending WO Filter)
*======================================================================*

CLASS lcl_tree_event_0320 IMPLEMENTATION.
  METHOD handle_node_dblclick_0320.
    gv_tree_selected_key_320 = node_key.
    PERFORM filter_alv_0320_by_tree.
  ENDMETHOD.
  METHOD handle_item_dblclick_0320.
    gv_tree_selected_key_320 = node_key.
    PERFORM filter_alv_0320_by_tree.
  ENDMETHOD.
ENDCLASS.

*&---------------------------------------------------------------------*
*& FORM: free_tree_0320
*&---------------------------------------------------------------------*
FORM free_tree_0320.
  IF gr_tree_0320 IS BOUND.
    gr_tree_0320->free( ).
    CLEAR gr_tree_0320.
  ENDIF.
  IF gr_tree_cont_0320 IS BOUND.
    gr_tree_cont_0320->free( ).
    CLEAR gr_tree_cont_0320.
  ENDIF.
  CLEAR: go_tree_evt_0320, gv_tree_selected_key_320, gt_pending_tree_320.
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: load_pending_tree_0320
*& Loads ZTWOAPPRH (APPR_STATUS=1) into gt_pending_tree_320.
*& Applies p_werks_320 and/or p_aufnr_320 filter from subscreen 0321.
*&---------------------------------------------------------------------*
FORM load_pending_tree_0320.
  DATA lv_week_start TYPE d.
  lv_week_start = sy-datum - 7.
  CLEAR gt_pending_tree_320.

  IF p_aufnr_320 IS NOT INITIAL AND p_werks_320 IS NOT INITIAL.
    SELECT * FROM ztwoapprh INTO TABLE @gt_pending_tree_320
      WHERE appr_status    = @gc_appr_status-submitted
        AND aufnr           = @p_aufnr_320
        AND werks           = @p_werks_320.
  ELSEIF p_aufnr_320 IS NOT INITIAL.
    SELECT * FROM ztwoapprh INTO TABLE @gt_pending_tree_320
      WHERE appr_status    = @gc_appr_status-submitted
        AND aufnr           = @p_aufnr_320.
  ELSEIF p_werks_320 IS NOT INITIAL.
    SELECT * FROM ztwoapprh INTO TABLE @gt_pending_tree_320
      WHERE appr_status    = @gc_appr_status-submitted
        AND requested_date >= @lv_week_start
        AND werks           = @p_werks_320.
  ELSE.
    SELECT * FROM ztwoapprh INTO TABLE @gt_pending_tree_320
      WHERE appr_status    = @gc_appr_status-submitted
        AND requested_date >= @lv_week_start.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: build_tree_nodes_0320
*&---------------------------------------------------------------------*
FORM build_tree_nodes_0320
  USING
    node_table TYPE treev_ntab
    item_table TYPE item_table_0320_type.

  DATA: ls_node        TYPE treev_node,
        ls_item        TYPE mtreeitm,
        lv_node_key    TYPE tv_nodekey,
        lv_month_start TYPE d,
        lv_week_start  TYPE d,
        lv_label       TYPE char60.

  lv_month_start      = sy-datum.
  lv_month_start+6(2) = '01'.
  lv_week_start       = sy-datum - 7.

  " Root
  CLEAR ls_node.
  ls_node-node_key = gc_tree_0320-root.
  ls_node-isfolder = 'X'.
  APPEND ls_node TO node_table.
  CLEAR ls_item.
  ls_item-node_key = gc_tree_0320-root. ls_item-item_name = '1'.
  ls_item-class    = cl_gui_list_tree=>item_class_text.
  ls_item-alignment = cl_gui_list_tree=>align_auto.
  ls_item-font     = cl_gui_list_tree=>item_font_prop.
  ls_item-text     = 'Pending Approval WO'.
  APPEND ls_item TO item_table.

  " Monthly folder
  CLEAR ls_node.
  ls_node-node_key  = gc_tree_0320-monthly.
  ls_node-relatkey  = gc_tree_0320-root.
  ls_node-relatship = cl_gui_list_tree=>relat_last_child.
  ls_node-isfolder  = 'X'.
  APPEND ls_node TO node_table.
  CLEAR ls_item.
  ls_item-node_key  = gc_tree_0320-monthly. ls_item-item_name = '1'.
  ls_item-class     = cl_gui_list_tree=>item_class_text.
  ls_item-alignment = cl_gui_list_tree=>align_auto.
  ls_item-font      = cl_gui_list_tree=>item_font_prop.
  lv_label = 'Monthly (' && sy-datum(4) && '-' && sy-datum+4(2) && ')'.
  ls_item-text = lv_label.
  APPEND ls_item TO item_table.

  LOOP AT gt_pending_tree_320 INTO DATA(ls_wo).
    CHECK ls_wo-requested_date >= lv_month_start.
    lv_node_key = 'M2' && ls_wo-aufnr.
    CLEAR ls_node.
    ls_node-node_key  = lv_node_key.
    ls_node-relatkey  = gc_tree_0320-monthly.
    ls_node-relatship = cl_gui_list_tree=>relat_last_child.
    APPEND ls_node TO node_table.
    CLEAR ls_item.
    ls_item-node_key  = lv_node_key. ls_item-item_name = '1'.
    ls_item-class     = cl_gui_list_tree=>item_class_text.
    ls_item-alignment = cl_gui_list_tree=>align_auto.
    ls_item-font      = cl_gui_list_tree=>item_font_prop.
    ls_item-text = ls_wo-aufnr && '  ' && ls_wo-werks.
    APPEND ls_item TO item_table.
  ENDLOOP.

  " Weekly folder
  CLEAR ls_node.
  ls_node-node_key  = gc_tree_0320-weekly.
  ls_node-relatkey  = gc_tree_0320-root.
  ls_node-relatship = cl_gui_list_tree=>relat_last_child.
  ls_node-isfolder  = 'X'.
  APPEND ls_node TO node_table.
  CLEAR ls_item.
  ls_item-node_key  = gc_tree_0320-weekly. ls_item-item_name = '1'.
  ls_item-class     = cl_gui_list_tree=>item_class_text.
  ls_item-alignment = cl_gui_list_tree=>align_auto.
  ls_item-font      = cl_gui_list_tree=>item_font_prop.
  lv_label = 'Weekly (dari ' && lv_week_start+6(2) && '.' && lv_week_start+4(2) && ')'.
  ls_item-text = lv_label.
  APPEND ls_item TO item_table.

  LOOP AT gt_pending_tree_320 INTO ls_wo.
    CHECK ls_wo-requested_date >= lv_week_start.
    lv_node_key = 'W2' && ls_wo-aufnr.
    CLEAR ls_node.
    ls_node-node_key  = lv_node_key.
    ls_node-relatkey  = gc_tree_0320-weekly.
    ls_node-relatship = cl_gui_list_tree=>relat_last_child.
    APPEND ls_node TO node_table.
    CLEAR ls_item.
    ls_item-node_key  = lv_node_key. ls_item-item_name = '1'.
    ls_item-class     = cl_gui_list_tree=>item_class_text.
    ls_item-alignment = cl_gui_list_tree=>align_auto.
    ls_item-font      = cl_gui_list_tree=>item_font_prop.
    ls_item-text = ls_wo-aufnr && '  ' && ls_wo-werks.
    APPEND ls_item TO item_table.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: init_tree_0320
*&---------------------------------------------------------------------*
FORM init_tree_0320.
  DATA: node_table TYPE treev_ntab,
        item_table TYPE item_table_0320_type,
        events     TYPE cntl_simple_events,
        ls_event   TYPE cntl_simple_event.

  PERFORM load_pending_tree_0320.

  CREATE OBJECT gr_tree_cont_0320
    EXPORTING container_name = 'CC_TREE_0320'
    EXCEPTIONS
      cntl_error                  = 1
      cntl_system_error           = 2
      create_error                = 3
      lifetime_error              = 4
      lifetime_dynpro_dynpro_link = 5.
  IF sy-subrc <> 0.
    MESSAGE 'Cannot create tree container CC_TREE_0320' TYPE 'E'.
    RETURN.
  ENDIF.

  CREATE OBJECT gr_tree_0320
    EXPORTING
      parent              = gr_tree_cont_0320
      node_selection_mode = cl_gui_list_tree=>node_sel_mode_single
      item_selection      = 'X'
      with_headers        = ' '
    EXCEPTIONS
      cntl_system_error           = 1
      create_error                = 2
      failed                      = 3
      illegal_node_selection_mode = 4
      lifetime_error              = 5.
  IF sy-subrc <> 0.
    MESSAGE 'Cannot create list tree for Screen 0320' TYPE 'E'.
    RETURN.
  ENDIF.

  ls_event-eventid    = cl_gui_list_tree=>eventid_node_double_click.
  ls_event-appl_event = 'X'.
  APPEND ls_event TO events.
  ls_event-eventid    = cl_gui_list_tree=>eventid_item_double_click.
  ls_event-appl_event = 'X'.
  APPEND ls_event TO events.

  CALL METHOD gr_tree_0320->set_registered_events
    EXPORTING events = events
    EXCEPTIONS
      cntl_error                = 1
      cntl_system_error         = 2
      illegal_event_combination = 3.
  IF sy-subrc <> 0.
    MESSAGE 'Cannot register tree events for Screen 0320' TYPE 'E'.
    RETURN.
  ENDIF.

  CREATE OBJECT go_tree_evt_0320.
  SET HANDLER go_tree_evt_0320->handle_node_dblclick_0320 FOR gr_tree_0320.
  SET HANDLER go_tree_evt_0320->handle_item_dblclick_0320 FOR gr_tree_0320.

  PERFORM build_tree_nodes_0320 USING node_table item_table.

  CALL METHOD gr_tree_0320->add_nodes_and_items
    EXPORTING
      node_table                 = node_table
      item_table                 = item_table
      item_table_structure_name  = 'MTREEITM'
    EXCEPTIONS
      failed                         = 1
      cntl_system_error              = 3
      error_in_tables                = 4
      dp_error                       = 5
      table_structure_name_not_found = 6.
  IF sy-subrc <> 0.
    MESSAGE 'Cannot insert nodes into tree for Screen 0320' TYPE 'E'.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: rebuild_tree_0320
*&---------------------------------------------------------------------*
FORM rebuild_tree_0320.
  PERFORM free_tree_0320.
  PERFORM init_tree_0320.
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: filter_alv_0320_by_tree
*&---------------------------------------------------------------------*
FORM filter_alv_0320_by_tree.
  DATA: lt_filtered    TYPE STANDARD TABLE OF ztwoapprh,
        lv_aufnr       TYPE aufnr,
        lv_month_start TYPE d,
        lv_week_start  TYPE d.

  CHECK gr_alv_0320 IS BOUND.

  lv_month_start      = sy-datum.
  lv_month_start+6(2) = '01'.
  lv_week_start       = sy-datum - 7.

  CASE gv_tree_selected_key_320.
    WHEN gc_tree_0320-root.
      gt_pending_wo = gt_pending_tree_320.
    WHEN gc_tree_0320-monthly.
      LOOP AT gt_pending_tree_320 INTO DATA(ls_wo).
        CHECK ls_wo-requested_date >= lv_month_start.
        APPEND ls_wo TO lt_filtered.
      ENDLOOP.
      gt_pending_wo = lt_filtered.
    WHEN gc_tree_0320-weekly.
      LOOP AT gt_pending_tree_320 INTO ls_wo.
        CHECK ls_wo-requested_date >= lv_week_start.
        APPEND ls_wo TO lt_filtered.
      ENDLOOP.
      gt_pending_wo = lt_filtered.
    WHEN OTHERS.
      IF gv_tree_selected_key_320(2) = 'M2' OR gv_tree_selected_key_320(2) = 'W2'.
        lv_aufnr = gv_tree_selected_key_320+2.
        LOOP AT gt_pending_tree_320 INTO ls_wo WHERE aufnr = lv_aufnr.
          APPEND ls_wo TO lt_filtered.
        ENDLOOP.
        gt_pending_wo = lt_filtered.
      ENDIF.
  ENDCASE.

  gr_alv_0320->refresh_table_display( ).
ENDFORM.
```

### Fix — Part B: Replace `STATUS_0320` in `LZFG_WO_APPROVALO01.abap`

```abap
MODULE status_0320 OUTPUT.
  SET PF-STATUS gc_status-history.
  SET TITLEBAR 'T320' WITH gc_title-history.

  IF gv_0320_initialized IS INITIAL.
    PERFORM free_alv_0320.
    PERFORM free_tree_0320.
    PERFORM init_alv_0320.      " ALV first — creates CC_ALV_0320
    PERFORM init_tree_0320.     " Tree second — creates CC_TREE_0320
    gv_0320_initialized      = abap_true.
    gv_0320_tree_initialized = abap_true.
  ELSE.
    IF gr_alv_0320 IS BOUND.
      gr_alv_0320->refresh_table_display( ).
    ENDIF.
  ENDIF.
ENDMODULE.
```

---

## Bug 5 — Missing `DISPATCH` and `CALL SUBSCREEN` in Screen 0320

### What happened
`USER_COMMAND_0320` has no `CL_GUI_CFW=>DISPATCH` call, so tree double-click events are silently dropped. Screen 0320's flow logic has no `CALL SUBSCREEN` lines so the filter subscreen (0321) is never rendered.

### Fix A — Replace `USER_COMMAND_0320` in `LZFG_WO_APPROVALI01.abap`

```abap
MODULE user_command_0320 INPUT.
  DATA: lv_return_code TYPE i.

  " Dispatch tree events FIRST
  CALL METHOD cl_gui_cfw=>dispatch
    IMPORTING return_code = lv_return_code.
  IF lv_return_code <> cl_gui_cfw=>rc_noevent.
    CLEAR ok_code.
    EXIT.
  ENDIF.

  save_ok = ok_code.
  CLEAR ok_code.

  CASE save_ok.
    WHEN 'SEARCH_320'.
      PERFORM rebuild_tree_0320.
      gt_pending_wo = gt_pending_tree_320.
      IF gr_alv_0320 IS BOUND.
        gr_alv_0320->refresh_table_display( ).
      ENDIF.
    WHEN '&BACK'.
      CLEAR: gv_0320_initialized, gv_0320_tree_initialized.
      PERFORM free_tree_0320.
      SET SCREEN 0100. LEAVE SCREEN.
    WHEN '&EXIT' OR '&CANC'.
      CLEAR: gv_0320_initialized, gv_0320_tree_initialized.
      PERFORM free_tree_0320.
      LEAVE PROGRAM.
  ENDCASE.
ENDMODULE.
```

### Fix B — Replace `0320.abap` screen flow logic

```abap
*&---------------------------------------------------------------------*
*& Screen : 0320 — 3-Panel (Tree + Subscreen + ALV)
*&---------------------------------------------------------------------*
PROCESS BEFORE OUTPUT.
  CALL SUBSCREEN ss_0320 INCLUDING sy-repid '0321'.
  MODULE status_0320.

PROCESS AFTER INPUT.
  CALL SUBSCREEN ss_0320.
  MODULE user_command_0320.
```

### Fix C — Replace `0321.abap` screen flow logic

The current `0321.abap` says "NOT USED". It must be a real dynpro subscreen. Create Screen 0321 in SE51 (same steps as Screen 0311 above, but with fields `P_WERKS_320` and `P_AUFNR_320` and button fctcode `SEARCH_320`).

Replace `0321.abap` with:

```abap
*&---------------------------------------------------------------------*
*& Screen : 0321 — Subscreen: Plant / Work Order Filter for Screen 0320
*&---------------------------------------------------------------------*
PROCESS BEFORE OUTPUT.

PROCESS AFTER INPUT.
```

---

## Activation Order After All Fixes

1. `LZFG_WO_APPROVALTOP` — new Screen 0320 tree declarations
2. `LZFG_WO_APPROVALF07` — new Screen 0320 tree FORMs and class
3. `LZFG_WO_APPROVALO01` — updated `STATUS_0320`
4. `LZFG_WO_APPROVALI01` — updated `USER_COMMAND_0320`
5. Screen `0311` — **recreate as proper dynpro subscreen** in SE51
6. Screen `0321` — **create as proper dynpro subscreen** in SE51
7. Screen `0310` — updated flow logic (CALL SUBSCREEN before MODULE)
8. Screen `0320` — updated flow logic + add CALL SUBSCREEN lines
9. Function Group `ZFG_WO_APPROVAL` — master re-activation

---

## Root Cause Summary (One-liner per Bug)

| # | One-liner |
|---|---|
| 1 | `SELECTION-SCREEN AS SUBSCREEN` is incompatible with `CALL SUBSCREEN` from a dynpro — recreate 0311 as a proper SE51 dynpro subscreen |
| 2 | `MODULE status_0310` creates containers before `CALL SUBSCREEN INCLUDING` renders the screen area — swap the order in 0310 PBO |
| 3 | `gv_0320_tree_initialized` and all Screen 0320 tree objects are missing from TOP — add the declarations block |
| 4 | `STATUS_0320` never calls `init_tree_0320` and the tree FORMs are missing from F07 — add both |
| 5 | `USER_COMMAND_0320` has no `DISPATCH` call and Screen 0320 flow has no `CALL SUBSCREEN` — add both |