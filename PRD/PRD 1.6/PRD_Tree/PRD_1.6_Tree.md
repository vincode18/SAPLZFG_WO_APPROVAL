# Implementation Guide: Add CL_GUI_LIST_TREE to Screen 0320

**Program:** ZFG_WO_APPROVAL (Function Group)  
**Target Screen:** 0320 — WO Approval History  
**Version:** 2.0 (3-Panel Layout with Subscreen Filter)

---

## 1. Overview of What Will Change

Screen 0320 currently has a single custom control `CC_ALV_0320` filling the whole screen. After this change the screen has **three panels**:

```
┌──────────────────┬─────────────────────────────────────┐
│                  │  SS_0320 (Subscreen — Plant/Werks)   │
│  CC_TREE_0320    ├─────────────────────────────────────┤
│  (Tree — left    │                                      │
│   full height)   │  CC_ALV_0320 (ALV — bottom right)   │
│                  │                                      │
└──────────────────┴─────────────────────────────────────┘
```

- **Left panel** — `CC_TREE_0320`: `CL_GUI_LIST_TREE` showing **Pending Approval WOs** (`APPR_STATUS = '1'`) grouped into Monthly (created within the current calendar month from `SY-DATUM`) and Weekly (created within the last 7 days from `SY-DATUM`) buckets.
- **Top-right panel** — Subscreen area `SS_0320`: calls subscreen `0321` which hosts Plant (`P_WERKS_320`) and Werks (`P_SWERK_320`) input fields plus an **Execute** button (`EXEC_320`).
- **Bottom-right panel** — `CC_ALV_0320`: existing `CL_GUI_ALV_GRID` showing `ZTWOAPPRH` records. Clicking a tree node filters this ALV to the selected WO or date bucket.

The tree data source is **`ZTWOAPPRH`** filtered on `APPR_STATUS = '1'`. Monthly shows WOs where `ERDAT >= first day of current month`. Weekly shows WOs where `ERDAT >= SY-DATUM - 7`. The Plant/Werks subscreen adds an additional filter applied when the user presses Execute.

---

## 2. Files to Create or Modify

| File | Action | Change |
|---|---|---|
| `LZFG_WO_APPROVALTOP.abap` | Modify | Tree globals, subscreen input fields, event handler class definition, node-key constants |
| `LZFG_WO_APPROVALF07.abap` | Modify | New tree free/load/build/init/rebuild/filter FORMs, event handler class implementation |
| `LZFG_WO_APPROVALO01.abap` | Modify | Extend `STATUS_0320` to init tree |
| `LZFG_WO_APPROVALI01.abap` | Modify | Extend `USER_COMMAND_0320` to dispatch control events and handle `EXEC_320` |
| Screen `0320` (SE51) | Modify | Add `CC_TREE_0320`, add subscreen area `SS_0320`, resize `CC_ALV_0320`, update flow logic |
| Screen `0321` (SE51) | **Create** | New subscreen holding Plant/Werks input fields and Execute button |
| `0321.abap` | **Create** | Minimal flow logic for subscreen 0321 |

---

## 3. Step 1 — Global Declarations (`LZFG_WO_APPROVALTOP.abap`)

Add the block below **after** the existing `*--- ALV OBJECTS — Screen 0320` section.

```abap
*----------------------------------------------------------------------*
* TREE OBJECTS — Screen 0320 (Pending WO Tree Filter)
*----------------------------------------------------------------------*
CLASS lcl_tree_event_0320 DEFINITION DEFERRED.
CLASS CL_GUI_CFW DEFINITION LOAD.

TYPES: item_table_0320_type LIKE STANDARD TABLE OF MTREEITM
         WITH DEFAULT KEY.

DATA: gv_0320_tree_initialized TYPE abap_bool,
      gr_tree_0320              TYPE REF TO cl_gui_list_tree,
      gr_tree_cont_0320         TYPE REF TO cl_gui_custom_container,
      go_tree_evt_0320          TYPE REF TO lcl_tree_event_0320,
      gv_tree_selected_key      TYPE tv_nodekey,
      gt_pending_tree           TYPE STANDARD TABLE OF ztwoapprh.

*----------------------------------------------------------------------*
* Subscreen 0321 input fields — Plant / Werks filter on Screen 0320
*----------------------------------------------------------------------*
DATA: p_werks_320 TYPE werks_d,
      p_swerk_320 TYPE swerk.

*----------------------------------------------------------------------*
* Tree node key constants for Screen 0320
*----------------------------------------------------------------------*
CONSTANTS:
  BEGIN OF gc_tree_0320,
    root    TYPE tv_nodekey VALUE 'PEND_ROOT',
    monthly TYPE tv_nodekey VALUE 'MONTHLY',
    weekly  TYPE tv_nodekey VALUE 'WEEKLY',
  END OF gc_tree_0320.

*----------------------------------------------------------------------*
* Event handler class DEFINITION — tree node/item click for Screen 0320
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

---

## 4. Step 2 — Create Subscreen 0321 (SE51)

Subscreen `0321` provides the Plant and Werks filter fields shown in the **top-right panel** of Screen 0320.

### 4a. Create the screen

Open transaction `SE51`. Enter:
- Program: `SAPLZFG_WO_APPROVAL`
- Screen number: `0321`

Click **Create**. Set screen type to **Subscreen**. Set short description to `Plant/Werks Filter for Screen 0320`. Save.

### 4b. Layout elements

Add the following elements in the Layout Editor in a single row:

| Element Type | Name | Label / Text | Length | Function Code |
|---|---|---|---|---|
| Text field (label) | — | `Plant` | — | — |
| Input/output field | `P_WERKS_320` | — | 4 | — |
| Text field (label) | — | `Werks` | — | — |
| Input/output field | `P_SWERK_320` | — | 4 | — |
| Pushbutton | `BT_EXEC_320` | `Execute` | 10 | `EXEC_320` |

Save and activate Screen 0321.

### 4c. Flow logic (`0321.abap`)

```abap
*&---------------------------------------------------------------------*
*& Screen : 0321 — Subscreen: Plant/Werks Filter for Screen 0320
*&---------------------------------------------------------------------*
PROCESS BEFORE OUTPUT.
* No PBO module needed — fields are plain input/output fields.

PROCESS AFTER INPUT.
* PAI is handled entirely by the host screen 0320 USER_COMMAND_0320.
* The function code EXEC_320 raised by BT_EXEC_320 is passed to the host.
```

> **Rule:** A subscreen has no independent PAI module. The pushbutton function code `EXEC_320` is transported to the host screen's PAI module `USER_COMMAND_0320` automatically via the `CALL SUBSCREEN` mechanism.

---

## 5. Step 3 — Screen 0320 Layout and Flow Logic (SE51)

Open Screen 0320 in SE51 (program `SAPLZFG_WO_APPROVAL`, screen `0320`).

### 5a. Layout regions

Divide the screen into three regions. Typical character-grid dimensions for a 132 × 35 SAP screen:

| Element | SE51 Type | Name | Col | Row | Width | Height |
|---|---|---|---|---|---|---|
| Tree panel | Custom Control | `CC_TREE_0320` | 1 | 2 | 30 | 33 |
| Subscreen band | Subscreen | `SS_0320` | 32 | 2 | 99 | 4 |
| ALV panel | Custom Control | `CC_ALV_0320` | 32 | 7 | 99 | 28 |

Key layout constraints:
- `CC_TREE_0320` starts at column 1 and spans the **full screen height**.
- `SS_0320` sits directly **above** `CC_ALV_0320` in the right column.
- `CC_ALV_0320` is shorter than before to leave room for the subscreen band. Adjust row/height values to match your screen resolution.

### 5b. Updated flow logic (`0320.abap`)

Replace the existing flow logic with the version below, which adds the mandatory `CALL SUBSCREEN` statements for area `SS_0320`.

```abap
*&---------------------------------------------------------------------*
*& Screen : 0320 — 3-Panel (Tree + Subscreen + ALV)
*&---------------------------------------------------------------------*
PROCESS BEFORE OUTPUT.
  MODULE status_0320.
  CALL SUBSCREEN ss_0320 INCLUDING sy-repid '0321'.

PROCESS AFTER INPUT.
  CALL SUBSCREEN ss_0320.
  MODULE user_command_0320.
```

> **Rule:** `CALL SUBSCREEN ... INCLUDING` goes in PBO; `CALL SUBSCREEN` (without `INCLUDING`) goes in PAI. Both lines are mandatory whenever a subscreen area is defined on a screen.

---

## 6. Step 4 — Tree FORMs (`LZFG_WO_APPROVALF07.abap`)

Add all sections below at the **end** of `LZFG_WO_APPROVALF07.abap`, after the existing `refresh_alv_0330` FORM.

### 6a. Event Handler Class Implementation

```abap
*----------------------------------------------------------------------*
* EVENT HANDLER IMPLEMENTATION — tree node/item click for Screen 0320
*----------------------------------------------------------------------*
CLASS lcl_tree_event_0320 IMPLEMENTATION.

  METHOD handle_node_dblclick_0320.
    gv_tree_selected_key = node_key.
    PERFORM filter_alv_0320_by_tree.
  ENDMETHOD.

  METHOD handle_item_dblclick_0320.
    gv_tree_selected_key = node_key.
    PERFORM filter_alv_0320_by_tree.
  ENDMETHOD.

ENDCLASS.
```

### 6b. Free FORM

```abap
*&---------------------------------------------------------------------*
*& FORM: free_tree_0320
*& Destroys the tree container and hosted tree control.
*& Called on BACK/EXIT and before re-initialisation on re-entry.
*& Does NOT touch ALV objects or gt_pending_wo.
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
  CLEAR: go_tree_evt_0320, gv_tree_selected_key, gt_pending_tree.
ENDFORM.
```

### 6c. Data Load FORM

```abap
*&---------------------------------------------------------------------*
*& FORM: load_pending_tree_0320
*& Loads ZTWOAPPRH rows with APPR_STATUS = '1' into gt_pending_tree.
*& Date window: ERDAT >= SY-DATUM - 7 (covers both monthly and weekly
*& buckets — monthly is further filtered inside build_tree_nodes_0320).
*& Optional plant filter from subscreen fields p_werks_320 / p_swerk_320.
*&---------------------------------------------------------------------*
FORM load_pending_tree_0320.
  DATA lv_week_start TYPE d.
  lv_week_start = SY-DATUM - 7.

  CLEAR gt_pending_tree.

  IF p_werks_320 IS NOT INITIAL.
    SELECT * FROM ztwoapprh
      INTO TABLE @gt_pending_tree
      WHERE appr_status = @gc_appr_status-submitted
        AND erdat      >= @lv_week_start
        AND werks       = @p_werks_320.
  ELSEIF p_swerk_320 IS NOT INITIAL.
    SELECT * FROM ztwoapprh
      INTO TABLE @gt_pending_tree
      WHERE appr_status = @gc_appr_status-submitted
        AND erdat      >= @lv_week_start
        AND swerk       = @p_swerk_320.
  ELSE.
    SELECT * FROM ztwoapprh
      INTO TABLE @gt_pending_tree
      WHERE appr_status = @gc_appr_status-submitted
        AND erdat      >= @lv_week_start.
  ENDIF.

ENDFORM.
```

### 6d. Build Node/Item Table FORM

```abap
*&---------------------------------------------------------------------*
*& FORM: build_tree_nodes_0320
*& Builds the node and item tables from gt_pending_tree.
*&
*& Tree structure:
*&   PEND_ROOT  "Pending Approval WO"
*&     MONTHLY  "Monthly (YYYY-MM)"   — ERDAT >= 1st of current month
*&       M_<AUFNR>  leaf per WO
*&     WEEKLY   "Weekly (from YYYY-MM-DD)" — ERDAT >= SY-DATUM - 7
*&       W_<AUFNR>  leaf per WO
*&
*& A WO appearing in both windows gets a leaf in both folders.
*& Node key rule: prefix M_ or W_ + AUFNR (max 12 chars = 14 total,
*& within the TV_NODEKEY 20-char limit).
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

  lv_month_start    = SY-DATUM.
  lv_month_start+6(2) = '01'.
  lv_week_start     = SY-DATUM - 7.

  " ── Root ────────────────────────────────────────────────────────────
  CLEAR ls_node.
  ls_node-node_key = gc_tree_0320-root.
  ls_node-isfolder = 'X'.
  CLEAR: ls_node-relatkey, ls_node-relatship.
  APPEND ls_node TO node_table.

  CLEAR ls_item.
  ls_item-node_key  = gc_tree_0320-root.
  ls_item-item_name = '1'.
  ls_item-class     = cl_gui_list_tree=>item_class_text.
  ls_item-alignment = cl_gui_list_tree=>align_auto.
  ls_item-font      = cl_gui_list_tree=>item_font_prop.
  ls_item-text      = 'Pending Approval WO'.
  APPEND ls_item TO item_table.

  " ── MONTHLY folder ──────────────────────────────────────────────────
  CLEAR ls_node.
  ls_node-node_key  = gc_tree_0320-monthly.
  ls_node-relatkey  = gc_tree_0320-root.
  ls_node-relatship = cl_gui_list_tree=>relat_last_child.
  ls_node-isfolder  = 'X'.
  APPEND ls_node TO node_table.

  CLEAR ls_item.
  ls_item-node_key  = gc_tree_0320-monthly.
  ls_item-item_name = '1'.
  ls_item-class     = cl_gui_list_tree=>item_class_text.
  ls_item-alignment = cl_gui_list_tree=>align_auto.
  ls_item-font      = cl_gui_list_tree=>item_font_prop.
  lv_label = 'Monthly (' && SY-DATUM(4) && '-' && SY-DATUM+4(2) && ')'.
  ls_item-text = lv_label.
  APPEND ls_item TO item_table.

  " Monthly leaf nodes
  LOOP AT gt_pending_tree INTO DATA(ls_wo).
    CHECK ls_wo-erdat >= lv_month_start.
    lv_node_key = 'M_' && ls_wo-aufnr.

    CLEAR ls_node.
    ls_node-node_key  = lv_node_key.
    ls_node-relatkey  = gc_tree_0320-monthly.
    ls_node-relatship = cl_gui_list_tree=>relat_last_child.
    APPEND ls_node TO node_table.

    CLEAR ls_item.
    ls_item-node_key  = lv_node_key.
    ls_item-item_name = '1'.
    ls_item-class     = cl_gui_list_tree=>item_class_text.
    ls_item-alignment = cl_gui_list_tree=>align_auto.
    ls_item-font      = cl_gui_list_tree=>item_font_prop.
    ls_item-text = ls_wo-aufnr && '  ' && ls_wo-werks.
    APPEND ls_item TO item_table.
  ENDLOOP.

  " ── WEEKLY folder ───────────────────────────────────────────────────
  CLEAR ls_node.
  ls_node-node_key  = gc_tree_0320-weekly.
  ls_node-relatkey  = gc_tree_0320-root.
  ls_node-relatship = cl_gui_list_tree=>relat_last_child.
  ls_node-isfolder  = 'X'.
  APPEND ls_node TO node_table.

  CLEAR ls_item.
  ls_item-node_key  = gc_tree_0320-weekly.
  ls_item-item_name = '1'.
  ls_item-class     = cl_gui_list_tree=>item_class_text.
  ls_item-alignment = cl_gui_list_tree=>align_auto.
  ls_item-font      = cl_gui_list_tree=>item_font_prop.
  lv_label = 'Weekly (dari ' && lv_week_start(4) && '-'
                             && lv_week_start+4(2) && '-'
                             && lv_week_start+6(2) && ')'.
  ls_item-text = lv_label.
  APPEND ls_item TO item_table.

  " Weekly leaf nodes
  LOOP AT gt_pending_tree INTO ls_wo.
    CHECK ls_wo-erdat >= lv_week_start.
    lv_node_key = 'W_' && ls_wo-aufnr.

    CLEAR ls_node.
    ls_node-node_key  = lv_node_key.
    ls_node-relatkey  = gc_tree_0320-weekly.
    ls_node-relatship = cl_gui_list_tree=>relat_last_child.
    APPEND ls_node TO node_table.

    CLEAR ls_item.
    ls_item-node_key  = lv_node_key.
    ls_item-item_name = '1'.
    ls_item-class     = cl_gui_list_tree=>item_class_text.
    ls_item-alignment = cl_gui_list_tree=>align_auto.
    ls_item-font      = cl_gui_list_tree=>item_font_prop.
    ls_item-text = ls_wo-aufnr && '  ' && ls_wo-werks.
    APPEND ls_item TO item_table.
  ENDLOOP.

ENDFORM.
```

### 6e. Init FORM

```abap
*&---------------------------------------------------------------------*
*& FORM: init_tree_0320
*& Creates CC_TREE_0320 container and CL_GUI_LIST_TREE on Screen 0320.
*& Call AFTER init_alv_0320 so the ALV container already exists.
*&---------------------------------------------------------------------*
FORM init_tree_0320.
  DATA: node_table TYPE treev_ntab,
        item_table TYPE item_table_0320_type,
        events     TYPE cntl_simple_events,
        ls_event   TYPE cntl_simple_event.

  " Load pending WOs for tree buckets
  PERFORM load_pending_tree_0320.

  " Create the custom container on the screen
  CREATE OBJECT gr_tree_cont_0320
    EXPORTING
      container_name = 'CC_TREE_0320'
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

  " Create list tree — single-selection, item selection on, no column headers
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

  " Register node_double_click and item_double_click as application events
  " APPL_EVENT = 'X' routes the event through PAI where DISPATCH handles it
  ls_event-eventid    = cl_gui_list_tree=>eventid_node_double_click.
  ls_event-appl_event = 'X'.
  APPEND ls_event TO events.

  ls_event-eventid    = cl_gui_list_tree=>eventid_item_double_click.
  ls_event-appl_event = 'X'.
  APPEND ls_event TO events.

  CALL METHOD gr_tree_0320->set_registered_events
    EXPORTING
      events = events
    EXCEPTIONS
      cntl_error                = 1
      cntl_system_error         = 2
      illegal_event_combination = 3.
  IF sy-subrc <> 0.
    MESSAGE 'Cannot register tree events for Screen 0320' TYPE 'E'.
    RETURN.
  ENDIF.

  " Wire event handler methods
  CREATE OBJECT go_tree_evt_0320.
  SET HANDLER go_tree_evt_0320->handle_node_dblclick_0320 FOR gr_tree_0320.
  SET HANDLER go_tree_evt_0320->handle_item_dblclick_0320 FOR gr_tree_0320.

  " Build node/item data and insert into tree
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
```

### 6f. Rebuild FORM

```abap
*&---------------------------------------------------------------------*
*& FORM: rebuild_tree_0320
*& Called when the user presses Execute (EXEC_320) in subscreen 0321.
*& Frees the existing tree, reloads data with the current plant/werks
*& filter values, and recreates the tree from scratch.
*&---------------------------------------------------------------------*
FORM rebuild_tree_0320.
  PERFORM free_tree_0320.
  PERFORM init_tree_0320.
ENDFORM.
```

### 6g. ALV Filter FORM

```abap
*&---------------------------------------------------------------------*
*& FORM: filter_alv_0320_by_tree
*& Called by the event handler after a tree node is double-clicked.
*& Filters gt_pending_wo (the ALV data table for Screen 0320) to the
*& WOs matching the selected node, then refreshes the ALV display.
*&
*& Node key mapping:
*&   PEND_ROOT  — reset ALV to full gt_pending_tree
*&   MONTHLY    — ALV shows WOs from current calendar month
*&   WEEKLY     — ALV shows WOs from last 7 days
*&   M_<AUFNR>  — ALV shows that single WO (monthly context)
*&   W_<AUFNR>  — ALV shows that single WO (weekly context)
*&
*& gt_pending_wo is the internal table passed to the ALV via
*& set_table_for_first_display in init_alv_0320. Writing to it and
*& calling refresh_table_display is the correct update pattern —
*& do NOT call set_table_for_first_display again.
*&---------------------------------------------------------------------*
FORM filter_alv_0320_by_tree.
  DATA: lt_filtered    TYPE STANDARD TABLE OF ztwoapprh,
        lv_aufnr       TYPE aufnr,
        lv_month_start TYPE d,
        lv_week_start  TYPE d.

  CHECK gr_alv_0320 IS BOUND.

  lv_month_start    = SY-DATUM.
  lv_month_start+6(2) = '01'.
  lv_week_start     = SY-DATUM - 7.

  CASE gv_tree_selected_key.

    WHEN gc_tree_0320-root.
      " Show all pending WOs loaded into the tree
      gt_pending_wo = gt_pending_tree.

    WHEN gc_tree_0320-monthly.
      " Show all WOs from current calendar month
      LOOP AT gt_pending_tree INTO DATA(ls_wo).
        CHECK ls_wo-erdat >= lv_month_start.
        APPEND ls_wo TO lt_filtered.
      ENDLOOP.
      gt_pending_wo = lt_filtered.

    WHEN gc_tree_0320-weekly.
      " Show all WOs from last 7 days
      LOOP AT gt_pending_tree INTO ls_wo.
        CHECK ls_wo-erdat >= lv_week_start.
        APPEND ls_wo TO lt_filtered.
      ENDLOOP.
      gt_pending_wo = lt_filtered.

    WHEN OTHERS.
      " Leaf node: M_<AUFNR> or W_<AUFNR>
      IF gv_tree_selected_key(2) = 'M_' OR gv_tree_selected_key(2) = 'W_'.
        lv_aufnr = gv_tree_selected_key+2.
        LOOP AT gt_pending_tree INTO ls_wo
          WHERE aufnr = lv_aufnr.
          APPEND ls_wo TO lt_filtered.
        ENDLOOP.
        gt_pending_wo = lt_filtered.
      ENDIF.

  ENDCASE.

  gr_alv_0320->refresh_table_display( ).

ENDFORM.
```

---

## 7. Step 5 — PBO Module (`STATUS_0320` in `LZFG_WO_APPROVALO01.abap`)

Replace the existing `STATUS_0320 OUTPUT` module with the version below.

```abap
*&---------------------------------------------------------------------*
*& PBO Module : STATUS_0320
*& Screen     : 0320 — 3-Panel (Tree + Subscreen + ALV)
*& Pattern    : Initialization Flag (ABAP_Free_Screen_Objects_Skills.md)
*&---------------------------------------------------------------------*
MODULE status_0320 OUTPUT.
  SET PF-STATUS gc_status-history.
  SET TITLEBAR 'T320' WITH gc_title-history.

  IF gv_0320_initialized IS INITIAL.
    " Free any stale objects from a previous visit
    PERFORM free_alv_0320.
    PERFORM free_tree_0320.

    " ALV initialised first — creates CC_ALV_0320 container and loads
    " gt_pending_wo which is also used by the filter FORM
    PERFORM init_alv_0320.

    " Tree initialised second — loads gt_pending_tree independently
    " from ZTWOAPPRH and builds the node buckets
    PERFORM init_tree_0320.

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

## 8. Step 6 — PAI Module (`USER_COMMAND_0320` in `LZFG_WO_APPROVALI01.abap`)

Replace the existing `USER_COMMAND_0320 INPUT` module with the version below.

Three additions compared to the previous version:
1. `CL_GUI_CFW=>DISPATCH` at the very top — mandatory for tree application events to fire.
2. `EXEC_320` WHEN case — handles the Execute pushbutton from subscreen 0321.
3. `free_tree_0320` calls in BACK/EXIT — clean destruction of the tree container on exit.

```abap
*&---------------------------------------------------------------------*
*& PAI Module : USER_COMMAND_0320
*& Screen     : 0320 — 3-Panel (Tree + Subscreen + ALV)
*&---------------------------------------------------------------------*
MODULE user_command_0320 INPUT.
  DATA: lv_return_code TYPE i.

  " ── Step 1: Dispatch control events first ───────────────────────────
  " Tree node/item double-click is an application event — DISPATCH routes
  " it to the ABAP handler method. If an event fired, skip ok-code logic.
  CALL METHOD cl_gui_cfw=>dispatch
    IMPORTING return_code = lv_return_code.
  IF lv_return_code <> cl_gui_cfw=>rc_noevent.
    CLEAR ok_code.
    EXIT.
  ENDIF.

  " ── Step 2: Normal ok-code processing ───────────────────────────────
  save_ok = ok_code.
  CLEAR ok_code.

  CASE save_ok.

    WHEN 'EXEC_320'.
      " Execute pressed in subscreen 0321 — apply plant/werks filter
      " Rebuild tree with new filter; reload and refresh ALV
      PERFORM rebuild_tree_0320.
      PERFORM load_appr_history.
      IF gr_alv_0320 IS BOUND.
        gr_alv_0320->refresh_table_display( ).
      ENDIF.

    WHEN '&BACK'.
      CLEAR gv_0320_initialized.
      CLEAR gv_0320_tree_initialized.
      PERFORM free_tree_0320.
      SET SCREEN 0100. LEAVE SCREEN.

    WHEN '&EXIT' OR '&CANC'.
      CLEAR gv_0320_initialized.
      CLEAR gv_0320_tree_initialized.
      PERFORM free_tree_0320.
      LEAVE PROGRAM.

  ENDCASE.
ENDMODULE.
```

---

## 9. Activation Order

Activate objects in this sequence to avoid forward-reference errors:

1. `LZFG_WO_APPROVALTOP` — new globals and class definition must exist first
2. `LZFG_WO_APPROVALF07` — new FORMs and event handler class implementation
3. `LZFG_WO_APPROVALO01` — updated PBO module
4. `LZFG_WO_APPROVALI01` — updated PAI module
5. Screen `0321` — new subscreen must exist before Screen 0320 references it
6. Screen `0320` — updated layout (`CC_TREE_0320`, `SS_0320`, resized `CC_ALV_0320`) and updated flow logic
7. Function Group `ZFG_WO_APPROVAL` — master re-activation

---

## 10. Runtime Behavior After Implementation

| User Action | Result |
|---|---|
| Navigate to Screen 0320 | Tree loads all pending WOs (`APPR_STATUS = '1'`, `ERDAT >= SY-DATUM - 7`). Monthly folder shows WOs from current calendar month. Weekly folder shows WOs from last 7 days. Plant and Werks fields in subscreen are blank. ALV shows full `ZTWOAPPRH` history. |
| Double-click **Monthly** folder | ALV filters to pending WOs with `ERDAT >= 1st of current month`. |
| Double-click **Weekly** folder | ALV filters to pending WOs with `ERDAT >= SY-DATUM - 7`. |
| Double-click a WO leaf node (e.g. `M_000050717449`) | ALV filters to that single WO's record. |
| Double-click **Root** node | ALV resets to show all rows in `gt_pending_tree`. |
| Enter Plant in `P_WERKS_320`, press **Execute** | Tree rebuilds using only WOs for that plant. ALV reloads full history filtered by plant. |
| Enter Werks in `P_SWERK_320`, press **Execute** | Same as above but filtered by Werks. |
| Press **Back** | `free_tree_0320` destroys tree container. Both init flags cleared. Next visit to Screen 0320 rebuilds everything cleanly. |

---

## 11. Key Implementation Rules

Derived from the `SAPTLIST_TREE_CONTROL_DEMO` reference pattern and the existing screen patterns in this program:

- **Create the event handler object before wiring handlers.** `CREATE OBJECT go_tree_evt_0320` must come before `SET HANDLER` — both are inside `init_tree_0320`.
- **Create the tree only once per screen visit.** The `gv_0320_initialized` flag prevents re-creation on every PBO roundtrip, identical to the pattern on Screens 0310 and 0330.
- **`CL_GUI_CFW=>DISPATCH` must be the first statement in PAI.** Placing it after `save_ok = ok_code` means the event arrives as a blank ok-code and is silently ignored — the handler never fires.
- **Parent nodes must appear before child nodes in the node table.** `build_tree_nodes_0320` inserts Root → Monthly → Monthly leaves → Weekly → Weekly leaves in strict top-down order.
- **Free the container, not just the tree.** `gr_tree_cont_0320->free( )` cascades to destroy the hosted tree. Freeing only the tree object leaves an orphaned container on the screen.
- **`ITEM_TABLE_STRUCTURE_NAME = 'MTREEITM'` is mandatory.** This is a hard requirement of `CL_GUI_LIST_TREE=>ADD_NODES_AND_ITEMS` regardless of the ABAP type name used locally.
- **Register events with `APPL_EVENT = 'X'`.** Without this flag, double-click fires only in the frontend and DISPATCH in PAI never sees it.
- **`CALL SUBSCREEN ... INCLUDING` in PBO; `CALL SUBSCREEN` in PAI.** Both lines are required whenever a subscreen area is present on the host screen. Missing the PAI line causes a syntax error at screen activation.
- **Do not call `set_table_for_first_display` again after initial ALV setup.** Write to `gt_pending_wo` directly and call `refresh_table_display( )`. Calling `set_table_for_first_display` a second time creates a duplicate ALV instance.
- **`free_tree_0320` must NOT clear `gt_pending_wo`.** That table belongs to the ALV lifecycle, not the tree lifecycle. Clearing it in `free_tree_0320` would blank the ALV unexpectedly when the tree is rebuilt by Execute.

---

## 12. Quick Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| Tree shows no nodes / blank | `gt_pending_tree` is empty — no WOs with `APPR_STATUS = '1'` in last 7 days | Check `ZTWOAPPRH` data; verify `gc_appr_status-submitted = '1'`; widen date range for testing by changing `SY-DATUM - 7` to a fixed past date |
| Double-click on tree node does nothing | `CL_GUI_CFW=>DISPATCH` is not the first statement in `USER_COMMAND_0320` | Move DISPATCH to the very first line before `save_ok = ok_code` |
| `TABLE_STRUCTURE_NAME_NOT_FOUND` short dump | Wrong value in `ITEM_TABLE_STRUCTURE_NAME` | Confirm `ITEM_TABLE_STRUCTURE_NAME = 'MTREEITM'` (uppercase, no spaces) in `ADD_NODES_AND_ITEMS` |
| `CC_TREE_0320` `CREATE_ERROR` at runtime | Custom Control element missing or misnamed on Screen 0320 | In SE51 layout, confirm element type is **Custom Control** and name is exactly `CC_TREE_0320` |
| `SS_0320` subscreen area not found | Area name in SE51 does not match `CALL SUBSCREEN ss_0320` | Verify the subscreen area element in SE51 is named `SS_0320` |
| Execute button does nothing | Function code mismatch — button FctCode is not `EXEC_320` | In SE51 Screen 0321, set the pushbutton's Function Code field to exactly `EXEC_320` |
| ALV goes blank after tree double-click | `filter_alv_0320_by_tree` clears `gt_pending_wo` before assigning | Confirm the FORM assigns `lt_filtered` to `gt_pending_wo` and then calls `refresh_table_display`, not `set_table_for_first_display` |
| Tree disappears after Execute but ALV stays | `rebuild_tree_0320` > `free_tree_0320` clears `gt_pending_wo` inadvertently | Ensure `free_tree_0320` only clears `gr_tree_0320`, `gr_tree_cont_0320`, `go_tree_evt_0320`, and `gt_pending_tree` — not `gt_pending_wo` |