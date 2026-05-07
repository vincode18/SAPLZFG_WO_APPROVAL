# SAP CL_GUI_LIST_TREE — Reference Guide

**Class**: `CL_GUI_LIST_TREE`  
**Superclass**: `CL_GUI_TREE`  
**Package**: `SLIS`  
**Used in**: `ZFG_WO_APPROVAL` Screen 0320 (Pending WO Tree Filter)

---

## 1. Overview

`CL_GUI_LIST_TREE` is a SAP GUI control that renders a collapsible tree inside a `CL_GUI_CUSTOM_CONTAINER`. It supports single- or multi-selection of nodes, item-level text display, and application-event routing through the PAI mechanism via `CL_GUI_CFW=>DISPATCH`.

A **List Tree** differs from a **Column Tree** (`CL_GUI_COLUMN_TREE`) in that it has no column headers — each node is identified only by its item text. This makes it ideal for navigation/filter panels.

---

## 2. Key Types

| ABAP Type | Description |
|---|---|
| `TREEV_NTAB` | Standard table of `TREEV_NODE` — the node definition table |
| `TREEV_NODE` | Structure for one node: `NODE_KEY`, `RELATKEY`, `RELATSHIP`, `ISFOLDER` |
| `MTREEITM` | Structure for one item: `NODE_KEY`, `ITEM_NAME`, `CLASS`, `TEXT`, `FONT`, `ALIGNMENT` |
| `TV_NODEKEY` | CHAR20 — unique key for each node |
| `CNTL_SIMPLE_EVENTS` | Table of `CNTL_SIMPLE_EVENT` — used to register events |
| `CNTL_SIMPLE_EVENT` | Structure: `EVENTID`, `APPL_EVENT` |

---

## 3. Constructor Parameters

```abap
CREATE OBJECT gr_tree_0320
  EXPORTING
    parent              = gr_tree_cont_0320      " CL_GUI_CUSTOM_CONTAINER
    node_selection_mode = cl_gui_list_tree=>node_sel_mode_single
    item_selection      = 'X'                    " Enable item-level selection
    with_headers        = ' '                    " No column headers (List Tree)
  EXCEPTIONS
    cntl_system_error           = 1
    create_error                = 2
    failed                      = 3
    illegal_node_selection_mode = 4
    lifetime_error              = 5.
```

### Node Selection Mode Constants

| Constant | Value | Meaning |
|---|---|---|
| `node_sel_mode_single` | `'S'` | Only one node selectable at a time |
| `node_sel_mode_multi`  | `'M'` | Multiple nodes selectable |
| `node_sel_mode_none`   | `'N'` | No node selection |

---

## 4. ADD_NODES_AND_ITEMS

The primary method to populate the tree. Must be called **after** `set_registered_events`.

```abap
CALL METHOD gr_tree_0320->add_nodes_and_items
  EXPORTING
    node_table                 = node_table       " TYPE treev_ntab
    item_table                 = item_table       " local table LIKE mtreeitm[]
    item_table_structure_name  = 'MTREEITM'       " MANDATORY — always uppercase
  EXCEPTIONS
    failed                         = 1
    cntl_system_error              = 3
    error_in_tables                = 4
    dp_error                       = 5
    table_structure_name_not_found = 6.
```

> **Critical**: `ITEM_TABLE_STRUCTURE_NAME` must be the literal string `'MTREEITM'` (uppercase, no spaces). Using a wrong value causes `TABLE_STRUCTURE_NAME_NOT_FOUND` short dump.

---

## 5. Node Structure Rules

```abap
" Root node — no RELATKEY / RELATSHIP
ls_node-node_key = 'PEND_ROOT'.
ls_node-isfolder = 'X'.
CLEAR: ls_node-relatkey, ls_node-relatship.

" Child node — references parent via RELATKEY + RELATSHIP
ls_node-node_key  = 'MONTHLY'.
ls_node-relatkey  = 'PEND_ROOT'.
ls_node-relatship = cl_gui_list_tree=>relat_last_child.
ls_node-isfolder  = 'X'.

" Leaf node — same as child but ISFOLDER = space
ls_node-node_key  = 'M_000050717449'.
ls_node-relatkey  = 'MONTHLY'.
ls_node-relatship = cl_gui_list_tree=>relat_last_child.
ls_node-isfolder  = space.
```

**Parent-before-child rule**: Nodes must be appended to `node_table` in top-down order. A child appended before its parent causes `ERROR_IN_TABLES`.

### RELATSHIP Constants

| Constant | Meaning |
|---|---|
| `relat_last_child`  | Insert as last child of RELATKEY node |
| `relat_first_child` | Insert as first child of RELATKEY node |
| `relat_next_sibling`| Insert as next sibling of RELATKEY node |

---

## 6. Item Structure

Each node must have at least one item (`ITEM_NAME = '1'`) with `CLASS = item_class_text` to display its label.

```abap
ls_item-node_key  = 'PEND_ROOT'.
ls_item-item_name = '1'.                                 " Unique per node
ls_item-class     = cl_gui_list_tree=>item_class_text.  " Text item
ls_item-alignment = cl_gui_list_tree=>align_auto.
ls_item-font      = cl_gui_list_tree=>item_font_prop.   " Proportional font
ls_item-text      = 'Pending Approval WO'.
```

### Item Class Constants

| Constant | Description |
|---|---|
| `item_class_text`     | Standard text label |
| `item_class_checkbox` | Checkbox item |
| `item_class_button`   | Button item |
| `item_class_link`     | Hyperlink item |

---

## 7. Event Registration and Dispatch

### Register Events

Events must be registered with `APPL_EVENT = 'X'` to route through PAI. Without this, the event fires only in the frontend and `CL_GUI_CFW=>DISPATCH` never sees it.

```abap
DATA: events   TYPE cntl_simple_events,
      ls_event TYPE cntl_simple_event.

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
```

### Wire Handler Methods

```abap
CREATE OBJECT go_tree_evt_0320.
SET HANDLER go_tree_evt_0320->handle_node_dblclick_0320 FOR gr_tree_0320.
SET HANDLER go_tree_evt_0320->handle_item_dblclick_0320 FOR gr_tree_0320.
```

> `CREATE OBJECT` must come **before** `SET HANDLER`.

### Dispatch in PAI

`CL_GUI_CFW=>DISPATCH` must be the **first** statement in the PAI module, before `save_ok = ok_code`. A tree double-click arrives as a blank ok-code; if DISPATCH is called after the ok-code is consumed, the handler never fires.

```abap
MODULE user_command_0320 INPUT.
  DATA lv_return_code TYPE i.

  CALL METHOD cl_gui_cfw=>dispatch
    IMPORTING return_code = lv_return_code.
  IF lv_return_code <> cl_gui_cfw=>rc_noevent.
    CLEAR ok_code.
    EXIT.
  ENDIF.

  save_ok = ok_code.
  CLEAR ok_code.
  " ... CASE save_ok ...
ENDMODULE.
```

### Event ID Constants

| Constant | Event |
|---|---|
| `eventid_node_double_click` | User double-clicks a node |
| `eventid_item_double_click` | User double-clicks an item within a node |
| `eventid_node_context_menu_req` | Right-click on node (context menu) |
| `eventid_expand_no_children`    | Expand of node with no pre-loaded children |

---

## 8. Event Handler Class Pattern

```abap
" DEFINITION (in TOP include)
CLASS lcl_tree_event_0320 DEFINITION DEFERRED.
CLASS cl_gui_cfw DEFINITION LOAD.

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

" IMPLEMENTATION (in F07 include)
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

> `CLASS cl_gui_cfw DEFINITION LOAD` forces the framework class to be loaded at startup — required when using `cl_gui_cfw=>dispatch` in a function group.

---

## 9. Lifecycle: Free Pattern

Always free the **container** (not just the tree), as `free()` on the container cascades to destroy the hosted control.

```abap
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

---

## 10. Subscreen Integration (Screen 0321)

Screen 0320 hosts a subscreen area `SS_0320` in the top-right panel. The flow logic rules are:

```abap
" PBO (host screen 0320)
PROCESS BEFORE OUTPUT.
  MODULE status_0320.
  CALL SUBSCREEN ss_0320 INCLUDING sy-repid '0321'.

" PAI (host screen 0320)
PROCESS AFTER INPUT.
  CALL SUBSCREEN ss_0320.
  MODULE user_command_0320.
```

- `CALL SUBSCREEN ... INCLUDING` in PBO sets the program and screen to embed.
- `CALL SUBSCREEN` (no `INCLUDING`) in PAI is **mandatory** when a subscreen area is defined — omitting it causes a syntax error at screen activation.
- The subscreen's pushbutton function code (`EXEC_320`) is automatically passed to the host PAI module.

---

## 11. Demo Program Reference

SAP standard demo: **`SAPTLIST_TREE_CONTROL_DEMO`** (transaction `SE38`)  
Use this as a reference for advanced tree features: lazy-load children, context menus, drag-and-drop, and column headers (Column Tree variant).

---

## 12. Implementation in This Project

| Element | Value |
|---|---|
| Custom Container | `CC_TREE_0320` (SE51 Screen 0320, Col 1, Row 2, W 30, H 33) |
| Tree Object | `gr_tree_0320` TYPE REF TO `cl_gui_list_tree` |
| Container Object | `gr_tree_cont_0320` TYPE REF TO `cl_gui_custom_container` |
| Event Handler | `go_tree_evt_0320` TYPE REF TO `lcl_tree_event_0320` |
| Selected Key | `gv_tree_selected_key` TYPE `tv_nodekey` |
| Tree Data Table | `gt_pending_tree` TYPE STANDARD TABLE OF `ztwoapprh` |
| Root Node Key | `gc_tree_0320-root` = `'PEND_ROOT'` |
| Monthly Folder Key | `gc_tree_0320-monthly` = `'MONTHLY'` |
| Weekly Folder Key | `gc_tree_0320-weekly` = `'WEEKLY'` |
| Monthly Leaf Prefix | `'M_'` + AUFNR |
| Weekly Leaf Prefix | `'W_'` + AUFNR |
| Subscreen Area | `SS_0320` on Screen 0320, calls Screen `0321` |
| Subscreen Fields | `P_WERKS_320` (WERKS_D), `P_SWERK_320` (SWERK) |
| Execute Button FCode | `EXEC_320` |
