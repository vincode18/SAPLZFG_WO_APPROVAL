# Enhancement 1.7.1 — Screen 0310: Blank Inputs, Auth-Driven Auto-Load

**Program :** ZFG_WO_APPROVAL (Function Group)
**Screen   :** 0310 — WO Approval: Pending List
**Date     :** 2026-05-04
**Status   :** Completed

---

## Background

Screen 0310 previously pre-filled the **Plant** input field (`s_w310`) with the user's authorized plants on every PBO cycle via `PERFORM default_filter_0310`. While this scoped the data correctly, it created a poor UX: the user arrived at the screen with plant values already typed in the filter bar, which was visually confusing and inconsistent with other screens.

---

## Requirements

| # | Requirement |
|---|-------------|
| 1 | Plant (`s_w310`) and Work Order (`s_a310`) input fields must be **blank** when the screen is first entered. |
| 2 | The Tree container and ALV list must be **auto-populated** on entry using the user's authorized plants from `r_swerk` — without writing anything to the screen fields. |
| 3 | **L1** (Head Office / BCSPPD) and **L5** (Helpdesk) may see pending approvals across all plants they hold `I_SWERK / IW33` authority for. |
| 4 | **L3** (SDH) and **L4** (Branch) are restricted to their own plant(s) only — no cross-plant search. |
| 5 | When the user types values into Plant / Work Order and presses **Execute**, the result must be filtered by those typed values (intersected with `r_swerk` as a hard auth guard). |

---

## Root Cause of Old Behaviour

`build_plant_range` in `LZFG_WO_APPROVALF01` queried T001W with:

```abap
SELECT * FROM t001w INTO TABLE lt_t001w
  WHERE werks IN s_werks.
```

`s_werks` belongs to Screen 0300's subscreen (0301). When entering Screen 0310 directly, `s_werks` is blank → T001W returns nothing → `r_swerk` stays empty → `default_filter_0310` triggered a warning and the screen was blank anyway. This pre-filter was never intentional for Screen 0310.

---

## Solution Design

```
PBO of 0310
  ├─ check_authorization        (unchanged)
  ├─ build_plant_range          (FIXED — no s_werks pre-filter)
  ├─ auto_load_0310             (NEW — replaces default_filter_0310)
  │    └─ load_pending_wo_list  (UPDATED — lr_plant logic)
  └─ init_alv_0310 / init_tree_0310
```

**Key principle:** `r_swerk` is built purely from `I_SWERK / IW33` authority and is the single source of truth for what plants a user may see. Screen field `s_w310` is a *narrowing* filter the user may optionally apply — it is never pre-filled by the system.

---

## Files Changed

### 1. `STATUS_0310.abap` — PBO Module

**What changed:**
- Removed `PERFORM default_filter_0310`
- Added `PERFORM auto_load_0310` in its place (called before ALV/Tree init)

**Before:**
```abap
PERFORM default_filter_0310.   " v1.8 — pre-fill s_w310 from r_swerk
```

**After:**
```abap
" v1.7.1: Do NOT pre-fill s_w310 / s_a310 — leave them blank on entry.
" The tree and ALV are loaded directly from r_swerk (see auto_load_0310).
PERFORM auto_load_0310.
```

---

### 2. `LZFG_WO_APPROVALF07.abap` — Main Logic Include

#### 2a. `FORM default_filter_0310` → replaced by `FORM auto_load_0310`

**Old form** wrote authorized plants into `s_w310` screen field.

**New form** leaves `s_w310` untouched and simply delegates to `load_pending_wo_list`:

```abap
FORM auto_load_0310.
  IF r_swerk IS INITIAL.
    MESSAGE 'No plant authorization. Contact system administrator.' TYPE 'W'.
    RETURN.
  ENDIF.
  " s_w310 / s_a310 intentionally left blank.
  " load_pending_wo_list treats blank s_w310 as "use r_swerk only".
  PERFORM load_pending_wo_list.
ENDFORM.
```

#### 2b. `FORM load_pending_wo_list` — `lr_plant` logic

Added a local range variable `lr_plant` to choose between `r_swerk` (blank field, first entry) and `s_w310` (user typed value, Execute path):

```abap
DATA: lr_plant LIKE r_swerk.

IF s_w310[] IS INITIAL.
  lr_plant = r_swerk.   " auto-load path
ELSE.
  lr_plant = s_w310.    " Execute path
ENDIF.

" Both SELECT branches use @lr_plant AND @r_swerk (hard guard):
WHERE werks IN @lr_plant
  AND werks IN @r_swerk
```

#### 2c. `FORM load_pending_tree_0310` — same `lr_plant` logic

Identical `lr_plant` pattern applied so the Tree container is also auto-loaded from `r_swerk` when `s_w310` is blank.

---

### 3. `LZFG_WO_APPROVALF01.abap` — Authorization / Plant Range Include

#### `FORM build_plant_range` — removed `s_werks` pre-filter

**Before:**
```abap
SELECT * FROM t001w INTO TABLE lt_t001w
  WHERE werks IN s_werks.
```

**After:**
```abap
" Select all plants — I_SWERK authority check is the sole filter.
SELECT * FROM t001w INTO TABLE lt_t001w.
```

**Effect by role:**

| Role | `r_swerk` result |
|------|-----------------|
| L1 — Head Office (BCSPPD) | All plants with `I_SWERK / IW33` authority (company-wide) |
| L5 — Helpdesk | All plants with `I_SWERK / IW33` authority |
| L3 — SDH | Own plant(s) only (I_SWERK restricts to assigned plant) |
| L4 — Branch | Own plant(s) only (I_SWERK restricts to assigned plant) |

---

## Behaviour After Enhancement

| Scenario | Plant field | Work Order field | Container loads? |
|----------|-------------|------------------|-----------------|
| L1/L5 first entry | Blank | Blank | ✅ All authorized plants |
| L3/L4 first entry | Blank | Blank | ✅ Own plant only |
| Any user presses Execute (no input) | Blank | Blank | ✅ Same as first entry |
| Any user types Plant + Execute | Typed value | Any | ✅ Filtered, intersected with r_swerk |
| User with no I_SWERK auth | Blank | Blank | ⚠️ Warning, empty container |

---

## No Impact On

- Screen 0300 (WO Entry) — `s_werks` on subscreen 0301 is unaffected; `build_plant_range` is called lazily and `s_werks` still works as a narrowing filter there if populated.
- Screens 0320, 0330 — use `s_w320` / `s_w330` with their own `default_filter_0320` / `default_filter_0330` forms, which are unchanged.
- Execute path (USER_COMMAND_0310 `WHEN 'EXEC_310'`) — unchanged; still calls `rebuild_tree_0310` + `load_pending_wo_list` + ALV refresh.
- Double-click / Open WO — unchanged.