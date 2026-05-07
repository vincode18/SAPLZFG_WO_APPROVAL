# Bug Fix: Authorization & Empty ALV Loading

**Date**: 2026-05-01  
**Issue**: GV_USER_LEVEL uninitialized (20002000 hex), R_SWERK empty → ALV loads nothing  
**Screens**: 0310 (Pending), 0320 (History)

---

## Root Cause

1. **GV_USER_LEVEL = 20002000** — Raw hex value, not L1/L3/L4/L5
   - CASE gv_user_level in load_pending_wo_list matches no WHEN branch
   - SELECT never executes → gt_pending_wo stays empty

2. **R_SWERK = Initial (0 entries)** — Plant authorization never populated
   - `AND werks IN @r_swerk` with empty range = match nothing
   - Even if SELECT ran, result would be empty

3. **Root**: `check_authorization` and `build_plant_range` FORMs never called before Screen 0310/0320 PBO

---

## Fixes Applied

### Screen 0310 (Pending Approval List)

**File**: `STATUS_0310.abap` (PBO Module)
- Added guard: IF gv_user_level IS INITIAL → PERFORM check_authorization
- Added guard: IF r_swerk IS INITIAL → PERFORM build_plant_range
- Ensures auth is initialized before default_filter_0310 runs

**File**: `LZFG_WO_APPROVALF07.abap` (Include)
- **default_filter_0310**: Added guard — if r_swerk empty, show warning + return
- **load_pending_tree_0310**: Added guard — if r_swerk empty, show warning + return
- **load_pending_wo_list**: Added guard — if r_swerk empty, show warning + return

### Screen 0320 (Approval History)

**File**: `STATUS_0320.abap` (PBO Module)
- Added guard: IF gv_user_level IS INITIAL → PERFORM check_authorization
- Added guard: IF r_swerk IS INITIAL → PERFORM build_plant_range
- Changed behavior: ALV now starts **empty** on entry (no auto-load)

**File**: `LZFG_WO_APPROVALF07.abap` (Include)
- **init_alv_0320**: Removed call to load_appr_history
  - ALV container created empty
  - Data loads **only** when user clicks FILTER button
  - User must enter range filters first, then click FILTER

---

## Test Checklist

- [ ] Open Screen 0310 → gv_user_level should be L1/L3/L4/L5 (not 20002000)
- [ ] Open Screen 0310 → r_swerk should have 1+ plant entries
- [ ] Open Screen 0310 → s_w310 pre-filled from r_swerk
- [ ] Open Screen 0310 → tree + ALV load with pending WOs
- [ ] Open Screen 0320 → ALV container empty on entry
- [ ] Screen 0320 → Enter range filters + click FILTER → data appears
- [ ] Screen 0320 → Click FILTER again with different range → ALV updates

---

## Messages Added

1. `default_filter_0310`: "No plant authorization. Contact admin."
2. `load_pending_tree_0310`: "No plant authorization. Cannot load tree."
3. `load_pending_wo_list`: "No plant authorization. Cannot load data."

All messages TYPE 'W' (warning) — non-blocking, user can still navigate.

---

## Files Modified

1. `d:\ABAP\SAP_Appr_WO_V2\2. Function_Group\2. PBO Modules\STATUS_0310.abap`
2. `d:\ABAP\SAP_Appr_WO_V2\2. Function_Group\2. PBO Modules\STATUS_0320.abap`
3. `d:\ABAP\SAP_Appr_WO_V2\2. Function_Group\7. includes\LZFG_WO_APPROVALF07.abap`

---

**Status**: COMPLETE — Ready for testing
