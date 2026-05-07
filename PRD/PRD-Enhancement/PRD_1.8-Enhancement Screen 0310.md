# PRD 1.8 — Enhancement Screen 0310

**Function Group:** `ZFG_WO_APPROVAL`
**Module:** Work Order Approval — Pending List
**Document Version:** 1.8
**Predecessor:** PRD 1.6 / PRD 1.7
**Status:** Enhancement — Filter Subscreen Refactor

---

## 1. Purpose

Enhance Screen **0310** (Pending Approval — 3-Panel: Tree + Subscreen + ALV) so that the embedded filter Subscreen **0311** accepts **range inputs** instead of single-value inputs for both **Work Order (AUFNR)** and **Plant (WERKS)**.

This aligns Screen 0310's filter behavior with Screen 0320 (Subscreen 0322) and Screen 0330 (Subscreen 0332), which already use `SELECT-OPTIONS` ranges, providing a consistent user experience across the function group.

---

## 2. Background — Current Behavior (PRD 1.6)

### 2.1 Current Subscreen 0311 Layout

Subscreen 0311 is a **dynpro subscreen** (created in SE51) embedded into Screen 0310 via subscreen area `SS_0310`. It currently exposes two **single-value** input fields plus an Execute button:

| Field        | Type      | Purpose                       |
|--------------|-----------|-------------------------------|
| `P_WK310`    | `WERKS_D` | Single Plant filter           |
| `P_AU310`    | `AUFNR`   | Single Work Order filter      |
| `BT_EXEC_310`| Button    | Function code `EXEC_310`      |

### 2.2 Current Filter Logic — `load_pending_tree_0310`

The current logic uses a `IF / ELSEIF` ladder that handles four cases (both filled, plant only, WO only, neither):

```abap
IF p_wk310 IS NOT INITIAL AND p_au310 IS NOT INITIAL.
  SELECT * FROM ztwoapprh ...
    WHERE appr_status    = @gc_appr_status-submitted
      AND requested_date >= @lv_week_start
      AND werks           = @p_wk310
      AND aufnr           = @p_au310.
ELSEIF p_wk310 IS NOT INITIAL.
  ...
ELSEIF p_au310 IS NOT INITIAL.
  ...
ELSE.
  ...
ENDIF.
```

### 2.3 Limitations

1. The user can only filter by **one** Work Order or **one** Plant at a time.
2. Inconsistent with Screens 0300/0320/0330, which use `SELECT-OPTIONS` ranges (`s_aufnr`, `s_w320`, `s_a320`, `s_w330`, `s_a330`).
3. Cannot leverage `SIGN`, `OPTION` (BT, NB, EQ, NE, etc.), or multi-line ranges.
4. Branch users (L4) whose authorization is multi-plant cannot pre-scope by all their plants in one shot.

---

## 3. Scope of Enhancement (v1.8)

### 3.1 In Scope

- Replace dynpro subscreen 0311 with a **selection-screen subscreen** (`SELECTION-SCREEN BEGIN OF SCREEN 0311 AS SUBSCREEN`) defined in include `LZFG_WO_APPROVALTOP`, mirroring the pattern already used by 0301 / 0322 / 0332.
- Introduce two new range tables:
  - `s_a310` — `SELECT-OPTIONS` `FOR aufk-aufnr` (Work Order range).
  - `s_w310` — `SELECT-OPTIONS` `FOR aufk-werks` (Plant range).
- Refactor `FORM load_pending_tree_0310` to use `IN s_a310` and `IN s_w310` instead of equality checks on `p_wk310` / `p_au310`.
- Pre-fill `s_w310` from `r_swerk` on first PBO so Branch users open the screen scoped to their authorized plants (mirrors `default_filter_0320`).
- Update Screen 0310 flow logic to embed the subscreen via `CALL SUBSCREEN ss_0310 INCLUDING sy-repid '0311'`.
- Retain the existing Execute button function code `EXEC_310` triggered from the subscreen.
- Retain the tree (CC_TREE_0310) and ALV (CC_ALV_0310) panels exactly as they are.

### 3.2 Out of Scope

- No changes to Screen 0310 GUI Status (`ZSTAT_0310`) or Title (`T310`).
- No changes to ALV field catalog (`build_fcat_0310`) or tree node structure (`build_tree_nodes_0310`).
- No changes to authorization logic (`r_swerk` continues to drive the hard authorization filter).
- No database/DDIC changes.
- No changes to Screens 0100, 0300, 0320, 0330.

---

## 4. Functional Requirements

### 4.1 New Subscreen 0311 Layout

The redesigned Subscreen 0311 contains two range lines and one Execute button:

```
┌──────────────────────────────────────────────────────────────────┐
│  Approval Data                                                   │
│                                                                  │
│  Plant      [____] to [____]  ⊕                                  │
│  Work Order [__________] to [__________]  ⊕      [⊕ Execute]    │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### 4.2 Field Specifications

| Field    | Type                           | DDIC Reference  | Range? | Default         |
|----------|--------------------------------|-----------------|--------|-----------------|
| `s_w310` | `SELECT-OPTIONS FOR aufk-werks`| `WERKS_D`       | Yes    | `r_swerk`       |
| `s_a310` | `SELECT-OPTIONS FOR aufk-aufnr`| `AUFNR`         | Yes    | (empty)         |

### 4.3 Behavior

| Scenario                                      | Expected Result                                                                 |
|-----------------------------------------------|---------------------------------------------------------------------------------|
| User opens Screen 0310 (first time)           | `s_w310` pre-filled with `r_swerk`; `s_a310` empty; tree shows all pending WOs within authorized plants. |
| User leaves both ranges empty and clicks Execute | Tree and ALV reload with all submitted WOs the user is authorized to see.   |
| User enters single plant in `s_w310-low`      | Tree and ALV restricted to that plant.                                          |
| User enters plant range (low–high)            | Tree and ALV show all plants in the range, intersected with `r_swerk`.          |
| User enters single WO in `s_a310-low`         | Tree and ALV show only that WO.                                                 |
| User enters WO range (low–high)               | Tree and ALV show all WOs in the range.                                         |
| User enters both ranges                       | Both filters applied (logical AND).                                             |
| User clicks Execute                            | Function code `EXEC_310` triggers `rebuild_tree_0310` + `load_pending_wo_list`. |

### 4.4 Authorization Rule (Unchanged)

`r_swerk` continues to be the authoritative plant authorization range. The user-typed `s_w310` is intersected with `r_swerk` so a user cannot bypass authorization by typing a plant outside their scope.

---

## 5. Technical Design

### 5.1 Changes to `LZFG_WO_APPROVALTOP`

**REMOVE:**

```abap
* Subscreen 0311 — Plant / Work Order filter input fields for Screen 0310
* Plain DATA — screen 0311 is a dynpro subscreen created in SE51.
DATA: p_wk310 TYPE werks_d,
      p_au310 TYPE aufnr.
```

**ADD** (after the existing 0301 / 0322 / 0332 selection-screen blocks, following the same pattern):

```abap
*----------------------------------------------------------------------*
*  v1.8 — SCREEN 0311 (Pending Approval) filter subscreen
*  Plant + WO range. Default plant is filled from r_swerk in PBO so a
*  Branch user only sees their own plants on entry.
*  Embedded into Screen 0310 via subscreen area SS_0310.
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF SCREEN 0311 AS SUBSCREEN.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT (10) text-p01 FOR FIELD s_w310.
    SELECT-OPTIONS s_w310 FOR aufk-werks.       " Plant
  SELECTION-SCREEN END OF LINE.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT (10) text-p02 FOR FIELD s_a310.
    SELECT-OPTIONS s_a310 FOR aufk-aufnr.       " Work Order
  SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF SCREEN 0311.
```

**ADD text symbols** (transaction SE32 → text-symbols of `LZFG_WO_APPROVAL`):

| Text Symbol | Value         |
|-------------|---------------|
| `P01`       | `Plant`       |
| `P02`       | `Work Order`  |

### 5.2 Changes to Screen 0310 Flow Logic

**Before:**

```abap
PROCESS BEFORE OUTPUT.
  MODULE status_0310.

PROCESS AFTER INPUT.
  MODULE user_command_0310.
```

**After (v1.8):**

```abap
PROCESS BEFORE OUTPUT.
  MODULE status_0310.
  CALL SUBSCREEN ss_0310 INCLUDING sy-repid '0311'.

PROCESS AFTER INPUT.
  CALL SUBSCREEN ss_0310.
  MODULE user_command_0310.
```

> **Note (SE51):** In Screen 0310 layout, ensure the existing subscreen area is named `SS_0310`. If the area in production is named differently (e.g. the literal `0311` placeholder), rename it to `SS_0310` for consistency with `SS_300`, `SS_320`, `SS_330`.

### 5.3 Changes to PBO `STATUS_0310`

Add a call to a new helper `default_filter_0310` that pre-fills `s_w310` from `r_swerk` on first entry (mirror of `default_filter_0320`):

```abap
MODULE status_0310 OUTPUT.
  SET PF-STATUS gc_status-pending.
  SET TITLEBAR 'T310' WITH gc_title-pending.

  PERFORM default_filter_0310.            " v1.8 — pre-fill s_w310 from r_swerk

  IF gv_0310_initialized IS INITIAL.
    PERFORM free_alv_0310.
    PERFORM free_tree_0310.
    PERFORM init_alv_0310.
    PERFORM init_tree_0310.
    gv_0310_initialized      = abap_true.
    gv_0310_tree_initialized = abap_true.
  ELSE.
    IF gr_alv_0310 IS BOUND.
      gr_alv_0310->refresh_table_display( ).
    ENDIF.
  ENDIF.
ENDMODULE.
```

### 5.4 New FORM `default_filter_0310` (in `LZFG_WO_APPROVALF07`)

```abap
*&---------------------------------------------------------------------*
*& FORM: default_filter_0310                                  (v1.8)
*& Pre-fill s_w310 with r_swerk so the screen opens scoped to the
*& current user's authorized plants. User can override the range
*& on screen and press Execute.
*&---------------------------------------------------------------------*
FORM default_filter_0310.
  DATA ls_w LIKE LINE OF s_w310.

  IF s_w310[] IS NOT INITIAL.
    RETURN.   " User has typed something — respect it.
  ENDIF.

  LOOP AT r_swerk INTO DATA(ls_r).
    CLEAR ls_w.
    ls_w-sign   = ls_r-sign.
    ls_w-option = ls_r-option.
    ls_w-low    = ls_r-low.
    ls_w-high   = ls_r-high.
    APPEND ls_w TO s_w310.
  ENDLOOP.
ENDFORM.
```

### 5.5 Refactor FORM `load_pending_tree_0310`

Replace the four-branch `IF / ELSEIF` ladder with a single range-based `SELECT`:

```abap
*&---------------------------------------------------------------------*
*& FORM: load_pending_tree_0310                                (v1.8)
*& Loads ZTWOAPPRH rows with APPR_STATUS = '1' into gt_pending_tree.
*& Date window: REQUESTED_DATE >= SY-DATUM - 7.
*& Filter from subscreen 0311 ranges:
*&   s_w310 (Plant range) — intersected with r_swerk for authorization
*&   s_a310 (Work Order range)
*&---------------------------------------------------------------------*
FORM load_pending_tree_0310.
  DATA lv_week_start TYPE d.
  lv_week_start = sy-datum - 7.

  CLEAR gt_pending_tree.

  SELECT * FROM ztwoapprh
    INTO TABLE @gt_pending_tree
    WHERE appr_status    = @gc_appr_status-submitted
      AND requested_date >= @lv_week_start
      AND werks          IN @s_w310
      AND werks          IN @r_swerk     " Hard authorization filter
      AND aufnr          IN @s_a310.
ENDFORM.
```

### 5.6 Refactor FORM `load_pending_wo_list`

Apply the same range filters to the ALV data load so the ALV stays in sync with the tree:

```abap
FORM load_pending_wo_list.
  CLEAR gt_pending_wo.

  CASE gv_user_level.
    WHEN gc_user_lvl-l1.
      SELECT * FROM ztwoapprh
        INTO TABLE @gt_pending_wo
        WHERE appr_status = @gc_appr_status-submitted
          AND werks      IN @s_w310
          AND werks      IN @r_swerk
          AND aufnr      IN @s_a310.
    WHEN gc_user_lvl-l3 OR gc_user_lvl-l4 OR gc_user_lvl-l5.
      SELECT * FROM ztwoapprh
        INTO TABLE @gt_pending_wo
        WHERE appr_status <> @gc_appr_status-approved
          AND werks       IN @s_w310
          AND werks       IN @r_swerk
          AND aufnr       IN @s_a310.
  ENDCASE.
ENDFORM.
```

### 5.7 PAI `USER_COMMAND_0310` (No Functional Change)

The `EXEC_310` branch still calls `rebuild_tree_0310` and `load_pending_wo_list`. Because both forms now read `s_w310` / `s_a310` directly, no signature change is needed:

```abap
WHEN 'EXEC_310'.
  PERFORM rebuild_tree_0310.
  PERFORM load_pending_wo_list.
  IF gr_alv_0310 IS BOUND.
    gr_alv_0310->refresh_table_display( ).
  ENDIF.
```

### 5.8 SE51 Subscreen 0311

Because subscreen 0311 is now generated from `SELECTION-SCREEN BEGIN OF SCREEN 0311 AS SUBSCREEN`, the manual SE51 dynpro for 0311 must be **deleted** before activation. SAP will auto-generate the subscreen on activation of `LZFG_WO_APPROVALTOP`.

The Execute button (`BT_EXEC_310`, function code `EXEC_310`) is no longer placed on the subscreen — it lives on Screen 0310's main GUI status (`ZSTAT_0310`) or on a pushbutton inside Screen 0310 outside the subscreen area, exactly the way `FILTER` works for Screen 0320. **Action item:** add function code `EXEC_310` to `ZSTAT_0310` if not already present (label: `Execute`, icon: `ICON_EXECUTE_OBJECT`).

---

## 6. Files Affected

| Layer        | Object                                | Action            |
|--------------|---------------------------------------|-------------------|
| Includes     | `LZFG_WO_APPROVALTOP`                 | Modify (replace `p_wk310`/`p_au310` with `s_w310`/`s_a310` selection-screen block) |
| Includes     | `LZFG_WO_APPROVALF07`                 | Modify (add `default_filter_0310`; refactor `load_pending_tree_0310` and `load_pending_wo_list`) |
| Screens      | `0310` flow logic                     | Modify (add `CALL SUBSCREEN ss_0310 INCLUDING sy-repid '0311'`) |
| Screens      | `0311` (dynpro)                       | Delete (replaced by auto-generated selection-screen subscreen) |
| PBO          | `STATUS_0310`                         | Modify (call `default_filter_0310`) |
| PAI          | `USER_COMMAND_0310`                   | No change (EXEC_310 branch already correct) |
| GUI Status   | `ZSTAT_0310`                          | Verify `EXEC_310` function code exists |
| Text Symbols | `LZFG_WO_APPROVAL` text pool          | Add `P01 = Plant`, `P02 = Work Order` |

---

## 7. Test Cases

| # | Pre-condition                  | Action                                             | Expected Result                                         |
|---|--------------------------------|----------------------------------------------------|---------------------------------------------------------|
| 1 | L4 user, plants A, B authorized | Open Screen 0310                                  | `s_w310` pre-filled with A, B; tree shows pending WOs from A and B only. |
| 2 | Same                            | Clear `s_w310`, click Execute                     | Tree still limited to A, B (because `r_swerk` enforces authorization). |
| 3 | Same                            | Type plant C (not authorized) in `s_w310`, Execute | Tree empty (intersection of `s_w310={C}` and `r_swerk={A,B}` is empty). |
| 4 | L1 user                         | Enter range `s_a310 = 1000–1999`, Execute         | Tree shows submitted WOs whose AUFNR is in 1000–1999. |
| 5 | L1 user                         | Enter `s_a310-low = 1000` only (single value)     | Tree shows only WO 1000.                                |
| 6 | L1 user                         | Multi-line range: `s_a310 = (EQ 1000) + (EQ 2000)`| Tree shows WOs 1000 and 2000.                           |
| 7 | Any                             | Press &BACK                                       | Returns to 0100; init flags cleared.                    |
| 8 | Any                             | Press &EXIT                                       | Program exits cleanly.                                  |
| 9 | Any                             | Double-click ALV row                              | Opens 0300 for the selected WO.                         |
| 10| Any                             | Double-click tree node                            | ALV filtered per node (Monthly / Weekly / leaf), unchanged from v1.6. |

---

## 8. Migration & Backward Compatibility

- The variables `p_wk310` and `p_au310` are **removed**. Any code outside the function group referencing them must be updated. A workspace-wide search confirmed they are only referenced inside `LZFG_WO_APPROVALF07` — no external callers.
- Existing transport packaging: include `LZFG_WO_APPROVALTOP`, `LZFG_WO_APPROVALF07`, screen 0310, deletion of dynpro 0311, status `ZSTAT_0310`, and updated text pool in the same transport.

---

## 9. Risks & Mitigations

| Risk                                                                                | Mitigation                                                                          |
|-------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------|
| Existing dynpro 0311 (with `p_wk310` / `p_au310` / `BT_EXEC_310`) conflicts with auto-generated selection-screen 0311 | Delete the dynpro version of 0311 in SE51 before activating the include.            |
| Screen 0310 subscreen area name mismatch                                            | Standardize on `SS_0310`; verify in SE51 layout.                                    |
| L4 users with very wide `r_swerk` may trigger slow `SELECT` on `ZTWOAPPRH`          | Index on `WERKS + APPR_STATUS` (already present). Date filter (`requested_date >= sy-datum - 7`) bounds the result set. |
| Removal of `p_wk310` / `p_au310` breaks unit tests (if any)                         | Refactor unit tests to populate `s_w310` / `s_a310` ranges instead.                 |

---

## 10. References

- PRD 1.5 — Initial 3-Panel design for Screen 0310 (Tree + Subscreen + ALV).
- PRD 1.6 — `SELECT-OPTIONS` range pattern introduced for Screens 0320 / 0330.
- Function Group `ZFG_WO_APPROVAL`, includes `LZFG_WO_APPROVALTOP` and `LZFG_WO_APPROVALF07`.
- SAP Help — `SELECTION-SCREEN BEGIN OF SCREEN ... AS SUBSCREEN`.

---

**End of PRD 1.8**