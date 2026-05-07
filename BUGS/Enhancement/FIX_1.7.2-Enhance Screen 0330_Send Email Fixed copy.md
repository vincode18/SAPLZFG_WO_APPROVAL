# Enhancement 1.7.2 — Screen 0330: Send Email Fixes

**Program :** ZFG_WO_APPROVAL (Function Group)
**Screen   :** 0330 — WO Approval: Manual Email Send
**Date     :** 2026-05-04
**Status   :** Completed

---

## Summary of Issues Fixed

| # | Issue | Root Cause | Fix |
|---|-------|-----------|-----|
| 1 | Plant filter pre-filled with all plants including `0001` | `default_filter_0330` copied all of `r_swerk` including the HO admin plant | Added `CHECK ls_r-low <> '0001'` exclusion |
| 2 | Entire ALV table was open/editable | `gs_layout_0330-edit = abap_true` made every cell editable | Set layout `edit = false`; only `MARK` column kept editable via field catalog |
| 3 | Select All (SALL) did not mark all rows reliably | `check_changed_data` was not called before the loop; in-flight edits overwrote the mark after refresh | Added `gr_alv_0330->check_changed_data()` before SALL and DSEL loops |
| 4 | No authorization check on Send — L3/L5 could send emails | `WHEN 'SEND'` only checked `gv_send_mode IS INITIAL` | Added explicit `gv_user_level` check: only L1 or L4 may proceed |
| 5 | Wrong HTML email template used for all send directions | `process_send_email_grouped` always called `build_email_html` regardless of direction | Added template dispatch: L1→Branch uses `build_email_html_plant`; L4→HO uses `build_email_html` |

---

## Background

Screen 0330 (Manual Email Send) allows authorized users to send WO approval notification emails in two directions:

- **L4 Branch → L1 Head Office (`HO` mode):** Branch requests HO review using `build_email_html` — *"Dear BCSPPD HO Team, please review..."*
- **L1 Head Office → Branch (`BR` mode):** HO sends approval result to Branch using `build_email_html_plant` — *"Dear Tim Cabang, hasil review..."*

The `gv_send_mode` variable (set by `resolve_send_mode`) controls the direction. L3 (SDH) and L5 (Helpdesk) have `gv_send_mode = initial` and must not be able to send.

---

## Files Changed

### 1. `STATUS_0330.abap` — PBO Module

**What changed:** Added explicit `check_authorization` / `build_plant_range` guards before the init block, matching the pattern used in Screen 0310 (v1.7.1). Added version comments for all four fixes.

**Before:**
```abap
MODULE status_0330 OUTPUT.
  ...
  IF gv_0330_initialized IS INITIAL.
    PERFORM free_alv_0330.
    PERFORM default_filter_0330.   " v1.6
    PERFORM resolve_send_mode.
    PERFORM init_alv_0330.
```

**After:**
```abap
MODULE status_0330 OUTPUT.
  ...
  " Guard: ensure authorization + plant range are ready
  IF gv_user_level IS INITIAL.
    PERFORM check_authorization.
  ENDIF.
  IF r_swerk IS INITIAL.
    PERFORM build_plant_range.
  ENDIF.

  IF gv_0330_initialized IS INITIAL.
    PERFORM free_alv_0330.
    PERFORM default_filter_0330.   " v1.7.2 — pre-fill plant excl. 0001
    PERFORM resolve_send_mode.
    PERFORM init_alv_0330.
```

---

### 2. `USER_COMMAND_0330.abap` — PAI Module

#### Fix 1 — SALL / DSEL: flush edits before toggling marks

**Before:**
```abap
WHEN 'SALL'.
  LOOP AT gt_appr_ready ASSIGNING FIELD-SYMBOL(<fs_sa>).
    <fs_sa>-mark = 'X'.
  ENDLOOP.
  PERFORM refresh_alv_0330.
```

**After:**
```abap
WHEN 'SALL'.
  " v1.7.2: flush any pending cell edits before bulk-marking
  IF gr_alv_0330 IS BOUND.
    gr_alv_0330->check_changed_data( ).
  ENDIF.
  LOOP AT gt_appr_ready ASSIGNING FIELD-SYMBOL(<fs_sa>).
    <fs_sa>-mark = 'X'.
  ENDLOOP.
  PERFORM refresh_alv_0330.
```

Same pattern applied to `WHEN 'DSEL'`.

#### Fix 2 — SEND: authorization guard for L1 / L4 only

**Before:**
```abap
WHEN 'SEND'.
  IF gv_send_mode IS INITIAL.
    MESSAGE 'Your role does not allow...' TYPE 'E'.
  ELSE.
    PERFORM process_send_email_grouped USING gv_send_mode.
  ENDIF.
```

**After:**
```abap
WHEN 'SEND'.
  " v1.7.2 — Authorization guard: only L1 (Head Office) and L4 (Branch)
  IF gv_user_level <> gc_user_lvl-l1 AND gv_user_level <> gc_user_lvl-l4.
    MESSAGE 'Only L1 (Head Office) or L4 (Branch) users may send emails from this screen.'
            TYPE 'E'.
    RETURN.
  ENDIF.

  IF gv_send_mode IS INITIAL.
    MESSAGE 'Send mode not resolved. Contact system administrator.' TYPE 'E'.
  ELSE.
    " Flush any in-flight checkbox edits before reading marks
    IF gr_alv_0330 IS BOUND.
      gr_alv_0330->check_changed_data( ).
    ENDIF.
    PERFORM process_send_email_grouped USING gv_send_mode.
  ENDIF.
```

**Why double guard?** `gv_user_level` is the hard security check. `gv_send_mode` is the
operational check — it should never be initial for L1/L4 after `resolve_send_mode`, but
the second check gives a clear diagnostic message if something is misconfigured.

---

### 3. `LZFG_WO_APPROVALF07.abap` — Main Logic Include

#### Fix 1 — `default_filter_0330`: exclude plant `0001`

**Before:**
```abap
FORM default_filter_0330.
  ...
  LOOP AT r_swerk INTO DATA(ls_r).
    CLEAR ls_w.
    ls_w-sign   = ls_r-sign.
    ls_w-option = ls_r-option.
    ls_w-low    = ls_r-low.
    ls_w-high   = ls_r-high.
    APPEND ls_w TO s_w330.
  ENDLOOP.
ENDFORM.
```

**After:**
```abap
FORM default_filter_0330.
  ...
  LOOP AT r_swerk INTO DATA(ls_r).
    " v1.7.2: Exclude the HO admin plant '0001' from the default range.
    CHECK ls_r-low <> '0001'.
    CLEAR ls_w.
    ...
    APPEND ls_w TO s_w330.
  ENDLOOP.
ENDFORM.
```

#### Fix 2 — `build_fcat_0330`: only MARK column editable

**Before:** All fields had no explicit `edit` flag; `gs_layout_0330-edit = abap_true` made every cell editable, so users could accidentally alter Work Order, Plant, Status, counts, etc.

**After:**
```abap
" MARK — only editable column
ls_fcat-fieldname = 'MARK'.
ls_fcat-checkbox  = abap_true.
ls_fcat-edit      = abap_true.   ← editable
...

" All other columns: explicitly read-only
ls_fcat-fieldname = 'AUFNR'.
ls_fcat-edit      = abap_false.  ← locked
...
```

#### Fix 3 — `init_alv_0330`: layout-level `edit = false`

**Before:**
```abap
gs_layout_0330-edit = abap_true.
```

**After:**
```abap
gs_layout_0330-edit = abap_false.  " v1.7.2: display-only; MARK col editable via fcat
```

The combination of `gs_layout_0330-edit = false` + `ls_fcat-edit = true` on MARK is the correct pattern in `CL_GUI_ALV_GRID` for a "checkbox-only" editable grid. Without this, the entire grid opens in edit mode.

---

### 4. `LZFG_WO_APPROVALF05.abap` — Email Driver Include

#### Fix — `process_send_email_grouped`: correct HTML template per direction

**Before:** Always called `build_email_html` regardless of `pv_email_type`.

**After:**
```abap
IF pv_email_type = gc_send_mode-br.
  " L1 → Branch: approval result notification
  PERFORM build_email_html_plant USING 'FIRST' ...
  PERFORM build_email_html_plant USING 'BODY'  ...
  PERFORM build_email_html_plant USING 'LAST'  ...
ELSE.
  " L4 → HO: review request
  PERFORM build_email_html USING 'FIRST' ... pv_email_type ls_group-werks ...
  PERFORM build_email_html USING 'BODY'  ... pv_email_type ls_group-werks ...
  PERFORM build_email_html USING 'LAST'  ... pv_email_type ls_group-werks ...
ENDIF.
```

---

### 5. `LZFG_WO_APPROVALF06.abap` — HTML Builder Include

#### New — `FORM build_email_html_plant` added

Ported from `ZR_SVC_WO_APPROVAL_v8_5.abap` and adapted to use `ty_items_tc` (the Function Group's component type) instead of the report's `ty_alv_output`.

| Aspect | `build_email_html` (L4→HO) | `build_email_html_plant` (L1→Branch) |
|--------|---------------------------|--------------------------------------|
| Greeting | `Dear BCSPPD HO Team` | `Dear Tim Cabang` |
| Intro | *"...require your review"* | *"...hasil review dan Approval PN..."* |
| Footer | `Action: review in ZWOAPP` | *"Silahkan dilanjutkan..."* + `BCSPPD HO Team` |
| Header color | `#003399` (blue) | `#009933` (green) |
| Table header BG | `#003399` white text | `#FFD700` (gold) black text |
| Row highlight | mismatch/match CSS classes | mismatch/match CSS classes |
| Reads from | `gt_selected` (ty_items_tc) | `gt_selected` (ty_items_tc) |

---

## Authorization Matrix — Screen 0330

| Role | Can Open Screen | Plant Pre-fill | Can Send Email | Send Direction |
|------|----------------|----------------|----------------|----------------|
| L1 — Head Office (BCSPPD) | ✅ | All auth plants excl. 0001 | ✅ | HO → Branch (`BR` mode, `build_email_html_plant`) |
| L3 — SDH | ✅ | Own plant(s) excl. 0001 | ❌ Error message | — |
| L4 — Branch | ✅ | Own plant excl. 0001 | ✅ | Branch → HO (`HO` mode, `build_email_html`) |
| L5 — Helpdesk | ✅ | All auth plants excl. 0001 | ❌ Error message | — |

---

## No Impact On

- Screens 0310, 0320 — no changes to their PBO/PAI or filter forms.
- `build_email_html` signature — unchanged; existing calls from Screen 0300 flow unaffected.
- `resolve_send_mode` — unchanged; L4→HO, L1→BR, L5→HO, others→initial.
- DLI naming convention — unchanged: `APPR_<WERKS>_HO` / `APPR_<WERKS>_BR`.