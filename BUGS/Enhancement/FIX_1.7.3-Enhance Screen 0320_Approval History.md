# Enhancement 1.7.3 — Screen 0320 & 0330: Plant 0001 Exclusion + Re-entry Reset

**Program :** ZFG_WO_APPROVAL (Function Group)
**Screens  :** 0320 — Approval History | 0330 — Manual Email Send
**Date     :** 2026-05-04
**Status   :** Completed

---

## Summary of Issues Fixed

| # | Screen | Issue | Root Cause | Fix |
|---|--------|-------|-----------|-----|
| 1 | 0320 | Plant `0001` appears in filter (with exclude sign) | Post-loop `E EQ 0001` append creates a visible exclusion entry in `s_w320` | Replace with inline `CHECK ls_r-low <> '0001'` — skips at loop level |
| 2 | 0320 | Re-entry shows stale filter + may duplicate ALV objects | `&BACK` only cleared `gv_0320_initialized`; left `s_w320[]`, `s_a320[]`, and ALV objects live | Add `PERFORM free_alv_0320` + `CLEAR s_w320[] s_a320[]` on all exit commands |
| 3 | 0330 | Re-entry shows stale filter — `s_w330[]` IS NOT INITIAL so `default_filter_0330` returns immediately | `&BACK` only cleared `gv_0330_initialized`; left `s_w330[]`, `s_a330[]`, `gv_send_mode`, ALV objects live | Add `PERFORM free_alv_0330` + `CLEAR s_w330[] s_a330[] gv_send_mode` on all exit commands |

---

## Debugger Evidence (Screen 0330)

From the ABAP Debugger session, `SY-TABIX = 1` and the breakpoint was on line 407 (`CLEAR ls_w`) inside `default_filter_0330` — meaning the `CHECK ls_r-low <> '0001'` passed correctly. However, `S_W330[]` already contained data (`2000300020003002000...`) because the previous session's `s_w330` was never cleared on `&BACK`. The `IF s_w330[] IS NOT INITIAL. RETURN.` guard at line 401 caused the form to exit immediately on re-entry, leaving the **old stale plant range** in place. The fix is in the `&BACK`/`&EXIT` handlers, not the `CHECK` logic.

---

## Background

- **Screen 0320** (Approval History): Read-only ALV showing component approval records. Plant filter `s_w320` is pre-filled from `r_swerk` on first entry.
- **Screen 0330** (Manual Email Send): Selectable ALV of approval-ready WOs. Plant filter `s_w330` is pre-filled from `r_swerk` excluding `0001`. Send direction is set by `resolve_send_mode`.
- Both screens now perform a **full reset on exit**: ALV objects freed, filter ranges cleared, initialized flag cleared — so the next entry is always fresh and `default_filter_*` re-runs correctly.

---

## Files Changed

### 1. `LZFG_WO_APPROVALF07.abap` — `default_filter_0320`

**What changed:** Replaced the post-loop exclusion append with an inline `CHECK`.

**Before:**
```abap
LOOP AT r_swerk INTO DATA(ls_r).
  CLEAR ls_w.
  ls_w-sign   = ls_r-sign.
  ls_w-option = ls_r-option.
  ls_w-low    = ls_r-low.
  ls_w-high   = ls_r-high.
  APPEND ls_w TO s_w320.
ENDLOOP.
" Exclude plant 0001 from the default range
CLEAR ls_w.
ls_w-sign = 'E'. ls_w-option = 'EQ'. ls_w-low = '0001'.
APPEND ls_w TO s_w320.
```

**After:**
```abap
LOOP AT r_swerk INTO DATA(ls_r).
  CHECK ls_r-low <> '0001'.  " v1.7.3: skip HO admin plant
  CLEAR ls_w.
  ls_w-sign   = ls_r-sign.
  ls_w-option = ls_r-option.
  ls_w-low    = ls_r-low.
  ls_w-high   = ls_r-high.
  APPEND ls_w TO s_w320.
ENDLOOP.
```

**Why:** The previous approach rendered `0001` visibly in the select-option box with an exclusion sign (`E EQ 0001`), which was confusing. The `CHECK` approach silently skips it — plant `0001` never appears in `s_w320` at all.

---

### 2. `USER_COMMAND_0320.abap` — `&BACK` / `&EXIT` / `&CANCEL`

**Before:**
```abap
WHEN '&BACK'.
  CLEAR gv_0320_initialized.
  SET SCREEN 0100. LEAVE SCREEN.
WHEN '&EXIT' OR '&CANCEL'.
  CLEAR gv_0320_initialized.
  LEAVE PROGRAM.
```

**After:**
```abap
WHEN '&BACK'.
  " v1.7.3: Full reset — free objects + clear filters so re-entry is clean
  PERFORM free_alv_0320.
  CLEAR: gv_0320_initialized, s_w320[], s_a320[].
  SET SCREEN 0100. LEAVE SCREEN.
WHEN '&EXIT' OR '&CANCEL'.
  PERFORM free_alv_0320.
  CLEAR: gv_0320_initialized, s_w320[], s_a320[].
  LEAVE PROGRAM.
```

---

### 3. `USER_COMMAND_0330.abap` — `&BACK` / `&EXIT` / `&CANC`

**Before:**
```abap
WHEN '&BACK'.
  CLEAR gv_0330_initialized.
  SET SCREEN 0100. LEAVE SCREEN.
WHEN '&EXIT' OR '&CANC'.
  CLEAR gv_0330_initialized.
  LEAVE PROGRAM.
```

**After:**
```abap
WHEN '&BACK'.
  " v1.7.3: Full reset — free objects + clear filters so re-entry is clean
  PERFORM free_alv_0330.
  CLEAR: gv_0330_initialized, gv_send_mode, s_w330[], s_a330[].
  SET SCREEN 0100. LEAVE SCREEN.
WHEN '&EXIT' OR '&CANC'.
  PERFORM free_alv_0330.
  CLEAR: gv_0330_initialized, gv_send_mode, s_w330[], s_a330[].
  LEAVE PROGRAM.
```

**Why `gv_send_mode` is also cleared:** `resolve_send_mode` only runs inside the `gv_0330_initialized IS INITIAL` block in `STATUS_0330`. Without clearing `gv_send_mode`, the previous user session's send direction would persist and potentially allow sending in the wrong direction.

---

### 4. `STATUS_0320.abap` / `STATUS_0330.abap`

Version comment bumped to `v1.7.3`. No logic changes.

---

## Behaviour After Fix

| Scenario | Screen | Before | After |
|----------|--------|--------|-------|
| First entry (L1 HO) | 0320 | Plant shows `0001 E` + all auth plants | Auth plants only — no `0001` row |
| First entry (any) | 0330 | Same issue if r_swerk had 0001 | Auth plants only — no `0001` |
| BACK → re-enter | 0320 | Stale filter persists; ALV may duplicate | Fresh state; `default_filter_0320` re-runs |
| BACK → re-enter | 0330 | `s_w330[] IS NOT INITIAL` → filter skipped | Fresh state; `default_filter_0330` re-runs correctly |
| EXIT / CANCEL | Both | Objects leak | Clean free + clear |

---

## No Impact On

- `load_appr_history` (0320) — logic unchanged
- `load_appr_ready_list` (0330) — logic unchanged
- `resolve_send_mode` (0330) — re-runs correctly on next entry
- Screen 0310 — untouched
- `build_fcat_0320` / `build_fcat_0330` — unchanged
- `default_filter_0330` — its own `CHECK ls_r-low <> '0001'` was already correct (v1.7.2)
