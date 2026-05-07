# Bug Fix — Screen 0310: Stale Filter on Re-Entry

**Program :** ZFG_WO_APPROVAL (Function Group)
**Screen   :** 0310 — WO Approval: Pending List
**Date     :** 2026-05-04
**Status   :** Fixed

---

## Symptom

After navigating away from Screen 0310 (pressing Back to Screen 0100) and then
re-entering Screen 0310, the **Work Order** field (`s_a310`) still shows the last
Work Order number that was populated by clicking a tree node. The Plant field
(`s_w310`) also retains any previously typed value.

This caused the ALV to auto-load filtered to the stale WO on re-entry instead
of showing all pending WOs for the user's authorized plants.

---

## Root Cause

`USER_COMMAND_0310` `WHEN '&BACK'` only called:

```abap
CLEAR gv_0310_initialized.
CLEAR gv_0310_tree_initialized.
PERFORM free_tree_0310.
```

Neither `s_a310` nor `s_w310` were cleared. Since these are global SELECT-OPTIONS
defined in `LZFG_WO_APPROVALTOP`, their values persist across screen navigations
within the same function group session.

Additionally, `free_alv_0310` was not called on Back, leaving the ALV container
object bound — causing a stale object reference on re-entry.

---

## Fix Applied

**File:** `USER_COMMAND_0310.abap`

```abap
WHEN '&BACK'.
  CLEAR: gv_0310_initialized, gv_0310_tree_initialized.
  CLEAR: s_w310, s_a310.          " Reset filter fields for clean re-entry
  PERFORM free_alv_0310.
  PERFORM free_tree_0310.
  SET SCREEN 0100. LEAVE SCREEN.

WHEN '&EXIT' OR '&CANC'.
  CLEAR: gv_0310_initialized, gv_0310_tree_initialized.
  CLEAR: s_w310, s_a310.
  PERFORM free_alv_0310.
  PERFORM free_tree_0310.
  LEAVE PROGRAM.
```

---

## Related Fixes (same session)

| Fix | Description |
|-----|-------------|
| Tree node key truncation | Node key stored AUFNR directly (no M/W prefix) to avoid tv_nodekey truncation |
| Tree label leading zeros | CONVERSION_EXIT_ALPHA_OUTPUT applied to display label only |
| auto_load_0310 | Replaced default_filter_0310 — s_w310 left blank, r_swerk used directly |
| build_plant_range | Removed s_werks pre-filter, all plants checked via I_SWERK authority |

---

## Test Checklist

- [ ] Enter Screen 0310 — tree and ALV load all authorized plants, filter fields blank
- [ ] Double-click a WO node — Work Order field fills, ALV filters to that WO
- [ ] Press Back — return to Screen 0100
- [ ] Re-enter Screen 0310 — filter fields are blank, tree/ALV reload all WOs cleanly
- [ ] Type Plant + Execute — ALV filters correctly
- [ ] Press Back, re-enter — fields blank again
