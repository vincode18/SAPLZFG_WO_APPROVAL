# Tree Leaf Node Counter Pattern

**Purpose:** Prevent duplicate `node_key` errors in `cl_gui_list_tree` when the same business key (e.g. `AUFNR`) appears under multiple parent folders.

**Style:** Classic ABAP using `OCCURS 0` (no header line).

**Applied to:** Function Group `ZFG_WO_APPROVAL`, Screen 0310 — Pending Approval Tree (Monthly + Weekly folders).

---

## 1. The Problem

`cl_gui_list_tree` requires every `node_key` to be **globally unique** within the tree. If you assign the same key twice, `add_nodes_and_items` raises an error and the tree fails to render.

In Screen 0310, the tree has two parent folders that can both contain the same Work Order:

```
Pending Approval WO  (root)
├── Monthly (current calendar month)
│   ├── 1700000123  (AUFNR, requested 06.05.2026)
│   └── 1700000456  (AUFNR, requested 02.05.2026)
└── Weekly (last 7 days)
    └── 1700000123  (AUFNR, requested 06.05.2026)  ← DUPLICATE!
```

A WO requested today (06.05.2026) falls into **both** windows:
- `>= 01.05.2026` → monthly
- `>= 30.04.2026` → weekly

If the original code uses the AUFNR directly as the node_key, the second `APPEND` produces a duplicate, the tree breaks, and on click the handler can't tell which folder the user clicked.

### Original (buggy) code

```abap
LOOP AT gt_pending_tree INTO ls_wo.
  CHECK ls_wo-requested_date >= lv_month_start.
  lv_node_key = ls_wo-aufnr.    " <-- AUFNR as key (collides!)
  ...
ENDLOOP.

LOOP AT gt_pending_tree INTO ls_wo.
  CHECK ls_wo-requested_date >= lv_week_start.
  lv_node_key = ls_wo-aufnr.    " <-- same AUFNR = duplicate key!
  ...
ENDLOOP.
```

---

## 2. The Solution: Running Counter + Lookup Table

Replace `aufnr` as the node_key with an **artificial running counter** that never resets between loops. Store the mapping `node_key → aufnr` in a separate lookup table so the click handler can recover the AUFNR later.

### Generated keys

```
N000000001 → AUFNR 1700000456 (monthly)
N000000002 → AUFNR 1700000123 (monthly)
N000000003 → AUFNR 1700000123 (weekly)   ← same AUFNR, different key
N000000004 → AUFNR 1700000789 (weekly)
```

The counter `N000000001`, `N000000002`, … is unique by construction. The 9-digit width gives you up to 999,999,999 leaf nodes — far more than any realistic tree.

The `'N'` prefix prevents accidental collision with the alphabetic folder keys (`PEND_ROOT`, `MONTHLY`, `WEEKLY`).

---

## 3. Declarations (LZFG_WO_APPROVALTOP)

Add these to your TOP include using the classic `OCCURS 0` style.

### 3.1 Row type

```abap
TYPES: BEGIN OF ty_tree_key,
         node_key TYPE tv_nodekey,
         aufnr    TYPE aufnr,
       END OF ty_tree_key.
```

### 3.2 Lookup table — `OCCURS 0` without header line

```abap
DATA: gt_tree_keys TYPE ty_tree_key OCCURS 0,
      ls_tree_key  TYPE ty_tree_key.
```

| Element | Purpose |
|---|---|
| `gt_tree_keys` | Body of the lookup table — no header line |
| `ls_tree_key`  | Explicit work area used for `APPEND` and `READ` |

> **Why `TYPE` and not `LIKE`?**
> `LIKE ty OCCURS 0` always creates a header line. `TYPE ty OCCURS 0` does not. We want no header line so the table is OO-safe and behaves predictably (`CLEAR` empties the body, no ambiguity between header and body).

---

## 4. Building the Tree (LZFG_WO_APPROVALF07)

### 4.1 Add counter variables to `build_tree_nodes_0310`

```abap
DATA: ls_node        TYPE treev_node,
      ls_item        TYPE mtreeitm,
      ls_wo          TYPE ztwoapprh,
      lv_node_key    TYPE tv_nodekey,
      lv_counter     TYPE i,                  " running counter
      lv_counter_c   TYPE n LENGTH 9,         " zero-padded char form
      lv_month_start TYPE d,
      lv_week_start  TYPE d,
      lv_label       TYPE char60,
      lv_aufnr_disp  TYPE char12.
```

### 4.2 Reset the lookup at the start of the form

```abap
CLEAR gt_tree_keys.        " no header line → CLEAR empties the body
```

### 4.3 Monthly leaf loop

```abap
LOOP AT gt_pending_tree INTO ls_wo.
  CHECK ls_wo-requested_date >= lv_month_start.

  " 1. Build unique node key
  lv_counter   = lv_counter + 1.
  lv_counter_c = lv_counter.                          " auto zero-pad
  CONCATENATE 'N' lv_counter_c INTO lv_node_key.      " e.g. 'N000000001'

  " 2. Register node_key → AUFNR in the lookup
  CLEAR ls_tree_key.
  ls_tree_key-node_key = lv_node_key.
  ls_tree_key-aufnr    = ls_wo-aufnr.
  APPEND ls_tree_key TO gt_tree_keys.

  " 3. Add the tree node
  CLEAR ls_node.
  ls_node-node_key  = lv_node_key.
  ls_node-relatkey  = gc_tree_0310-monthly.
  ls_node-relatship = cl_gui_list_tree=>relat_last_child.
  APPEND ls_node TO node_table.

  " 4. Add the display item (AUFNR + plant)
  CLEAR ls_item.
  ls_item-node_key  = lv_node_key.
  ls_item-item_name = '1'.
  ls_item-class     = cl_gui_list_tree=>item_class_text.
  ls_item-alignment = cl_gui_list_tree=>align_auto.
  ls_item-font      = cl_gui_list_tree=>item_font_prop.
  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_OUTPUT'
    EXPORTING
      input  = ls_wo-aufnr
    IMPORTING
      output = lv_aufnr_disp.
  CONCATENATE lv_aufnr_disp '  ' ls_wo-werks INTO ls_item-text.
  APPEND ls_item TO item_table.
ENDLOOP.
```

### 4.4 Weekly leaf loop

Identical structure — the **counter keeps running** from where the monthly loop left off, so weekly keys never collide with monthly ones:

```abap
LOOP AT gt_pending_tree INTO ls_wo.
  CHECK ls_wo-requested_date >= lv_week_start.

  " Counter does NOT reset — picks up after monthly's last key
  lv_counter   = lv_counter + 1.
  lv_counter_c = lv_counter.
  CONCATENATE 'N' lv_counter_c INTO lv_node_key.

  CLEAR ls_tree_key.
  ls_tree_key-node_key = lv_node_key.
  ls_tree_key-aufnr    = ls_wo-aufnr.
  APPEND ls_tree_key TO gt_tree_keys.

  CLEAR ls_node.
  ls_node-node_key  = lv_node_key.
  ls_node-relatkey  = gc_tree_0310-weekly.
  ls_node-relatship = cl_gui_list_tree=>relat_last_child.
  APPEND ls_node TO node_table.

  CLEAR ls_item.
  ls_item-node_key  = lv_node_key.
  ls_item-item_name = '1'.
  ls_item-class     = cl_gui_list_tree=>item_class_text.
  ls_item-alignment = cl_gui_list_tree=>align_auto.
  ls_item-font      = cl_gui_list_tree=>item_font_prop.
  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_OUTPUT'
    EXPORTING
      input  = ls_wo-aufnr
    IMPORTING
      output = lv_aufnr_disp.
  CONCATENATE lv_aufnr_disp '  ' ls_wo-werks INTO ls_item-text.
  APPEND ls_item TO item_table.
ENDLOOP.
```

---

## 5. Click Handler — Recovering the AUFNR

In `filter_alv_0310_by_tree`, the `WHEN OTHERS` branch must read the AUFNR from the lookup instead of using the node_key directly:

```abap
WHEN OTHERS.
  " Leaf node — recover AUFNR from gt_tree_keys
  READ TABLE gt_tree_keys INTO ls_tree_key
    WITH KEY node_key = gv_tree_selected_key.
  IF sy-subrc <> 0.
    " Click landed on something not in the lookup — ignore safely
    RETURN.
  ENDIF.
  lv_aufnr = ls_tree_key-aufnr.

  " Set s_a310 to the clicked WO so the filter bar reflects the selection
  CLEAR s_a310.
  APPEND VALUE #( sign = 'I' option = 'EQ' low = lv_aufnr ) TO s_a310.

  LOOP AT gt_pending_tree INTO ls_wo
    WHERE aufnr = lv_aufnr.
    APPEND ls_wo TO lt_filtered.
  ENDLOOP.
  gt_pending_wo = lt_filtered.
```

> **Why `INTO ls_tree_key` is mandatory:** because `gt_tree_keys` was declared with `TYPE ... OCCURS 0` (no header line), `READ TABLE` cannot store the result anywhere implicitly. The work area `ls_tree_key` must be specified explicitly.

---

## 6. Cleanup — `free_tree_0310`

When the screen is freed/reinitialized, empty the lookup table together with the other tree globals:

```abap
FORM free_tree_0310.
  IF gr_tree_0310 IS BOUND.
    gr_tree_0310->free( ).
    CLEAR gr_tree_0310.
  ENDIF.
  IF gr_tree_cont_0310 IS BOUND.
    gr_tree_cont_0310->free( ).
    CLEAR gr_tree_cont_0310.
  ENDIF.
  CLEAR: go_tree_evt_0310,
         gv_tree_selected_key,
         gt_pending_tree,
         gt_tree_keys.        " no header line → CLEAR empties body
ENDFORM.
```

> **Note on `CLEAR` vs `REFRESH`:** for tables **without** header line, `CLEAR itab` empties all rows (same as `REFRESH itab`). The legacy "CLEAR only clears the header" trap only applies to tables declared `WITH HEADER LINE` or `LIKE ... OCCURS 0`. Since we used `TYPE ty OCCURS 0`, `CLEAR` is safe here.

---

## 7. Why This Works

| Concern | How the pattern handles it |
|---|---|
| Same AUFNR in monthly + weekly | Counter increments globally → distinct keys |
| User clicks a leaf node | Lookup `gt_tree_keys` returns the original AUFNR |
| User clicks root/Monthly/Weekly folder | `WHEN gc_tree_0310-root/-monthly/-weekly` branches handle it; lookup never consulted |
| User clicks something unexpected | `READ TABLE ... sy-subrc <> 0` → `RETURN`, no crash |
| Tree is rebuilt | `CLEAR gt_tree_keys` resets the lookup; counter starts over from 1 |
| Tree has thousands of WOs | 9-digit counter supports 999,999,999 nodes |

---

## 8. Counter Format Reference

| Counter value | `lv_counter_c` (TYPE N LENGTH 9) | `lv_node_key` after CONCATENATE |
|---|---|---|
| 1 | `'000000001'` | `'N000000001'` |
| 42 | `'000000042'` | `'N000000042'` |
| 12345 | `'000012345'` | `'N000012345'` |
| 999999999 | `'999999999'` | `'N999999999'` |

The auto-zero-padding happens because `TYPE N` (numeric character) right-aligns and pads with `'0'` on assignment from an integer.

---

## 9. Why Not Use `sy-tabix`?

A reasonable first instinct is:

```abap
LOOP AT gt_pending_tree INTO ls_wo.
  lv_counter_c = sy-tabix.       " ❌ resets every loop
  ...
```

But `sy-tabix` resets to 1 at the start of each `LOOP`. The monthly loop and the weekly loop both start counting from 1 → same collision problem you started with.

A **standalone running counter** (`lv_counter = lv_counter + 1`) declared once outside any loop solves this cleanly — it never resets until the form ends.

---

## 10. Summary Checklist

When applying this pattern to any tree with potentially overlapping leaf data:

- [ ] Define a `ty_tree_key` type with `node_key` + business key
- [ ] Declare lookup table: `DATA: gt_xxx TYPE ty_xxx OCCURS 0.`
- [ ] Declare work area: `DATA: ls_xxx TYPE ty_xxx.`
- [ ] Declare counter outside loops: `DATA: lv_counter TYPE i, lv_counter_c TYPE n LENGTH 9.`
- [ ] `CLEAR gt_xxx.` at the start of the build form
- [ ] `lv_counter = lv_counter + 1.` before generating each leaf node_key
- [ ] `CONCATENATE 'N' lv_counter_c INTO lv_node_key.`
- [ ] `APPEND ls_xxx TO gt_xxx.` after every leaf, registering the mapping
- [ ] In the click handler: `READ TABLE gt_xxx INTO ls_xxx WITH KEY node_key = ...`
- [ ] In `free_xxx`: include `gt_xxx` in the `CLEAR:` chain

Pattern is reusable for any multi-folder tree where leaves can repeat across parents.