# Enhancement 1.8 — Screen 0300: Gate Approval Input by ZTWOAPPRH

**Program :** ZFG_WO_APPROVAL (Function Group)
**Screen  :** 0300 — Approval Input (Host) / 0301 — WO Range Subscreen
**Date    :** 2026-05-04
**Status  :** Completed

---

## Business Rule

Approval Input (Screen 0300) is the **post-release** stage of the WO approval
pipeline. A WO is only valid for processing here once it has been released
from IW32 — the IW32 user-exit flips `ZTWOAPPRH-APPR_STATUS` from `'0'` to
`'1'` (**submitted**) at that moment, and later to `'2'` (**approved**) once
all levels sign off.

Therefore Screen 0300 must accept **only** WOs whose ZTWOAPPRH row has:

| APPR_STATUS | Meaning    | Allowed on Screen 0300? |
|-------------|------------|-------------------------|
| `'0'`       | No Approval (not released) | No |
| `'1'`       | Submitted (IW32 Release clicked) | Yes |
| `'2'`       | Approved (all levels signed) | Yes |
| *(no row)*  | Never released | No |

Any other WO number typed by the user is treated as a mistake and must be
rejected with a friendly popup that tells the user exactly what to do next.

---

## Summary

| # | Area | Change |
|---|------|--------|
| 1 | `load_wo_range_for_approval` | Added ZTWOAPPRH pre-filter. Only WOs with `APPR_STATUS IN ('1','2')` are loaded. |
| 2 | `load_wo_range_for_approval` | For each explicit EQ WO typed in `s_aufnr`, validate against ZTWOAPPRH and raise a popup if not qualified. |
| 3 | `load_wo_range_for_approval` | Narrow `s_aufnr` to the qualified AUFNR set before the bulk pipeline runs, so downstream fetches (`fetch_component_data`) only scan WOs in the approval pipeline. |

---

## File Changed

### `LZFG_WO_APPROVALF04.abap` — `FORM load_wo_range_for_approval`

**Before (v1.5):**
```abap
FORM load_wo_range_for_approval.

  DATA: lv_mismatch_cnt TYPE i.

  IF s_aufnr[] IS INITIAL
    AND s_werks[] IS INITIAL
    AND s_erdat[] IS INITIAL
    AND s_aedat[] IS INITIAL.
    MESSAGE 'Enter at least a Work Order, Plant, Creation Date or Last Change Date' TYPE 'E'.
    RETURN.
  ENDIF.

  " Bulk pipeline (ported from report ZR_SVC_WO_APPROVAL_v8.5)
  PERFORM fetch_component_data.
  ...
```

**After (v1.8):**
```abap
FORM load_wo_range_for_approval.

  DATA: lv_mismatch_cnt TYPE i,
        lt_qualified    TYPE STANDARD TABLE OF aufnr,
        ls_qualified    TYPE aufnr,
        ls_aufnr_line   LIKE LINE OF s_aufnr,
        ls_aufnr_typed  LIKE LINE OF s_aufnr.

  IF s_aufnr[] IS INITIAL
    AND s_werks[] IS INITIAL
    AND s_erdat[] IS INITIAL
    AND s_aedat[] IS INITIAL.
    MESSAGE 'Enter at least a Work Order, Plant, Creation Date or Last Change Date' TYPE 'E'.
    RETURN.
  ENDIF.

  " v1.8: Pre-filter against ZTWOAPPRH — only process WOs already in the
  " approval pipeline (APPR_STATUS = submitted '1' or approved '2').
  IF r_swerk IS INITIAL.
    SELECT aufnr FROM ztwoapprh
      INTO TABLE @lt_qualified
      WHERE aufnr IN @s_aufnr
        AND werks IN @s_werks
        AND ( appr_status = @gc_appr_status-submitted
           OR appr_status = @gc_appr_status-approved ).
  ELSE.
    SELECT aufnr FROM ztwoapprh
      INTO TABLE @lt_qualified
      WHERE aufnr IN @s_aufnr
        AND werks IN @r_swerk
        AND werks IN @s_werks
        AND ( appr_status = @gc_appr_status-submitted
           OR appr_status = @gc_appr_status-approved ).
  ENDIF.

  " Typed single-WO validation — popup the first offender, then RETURN.
  LOOP AT s_aufnr INTO ls_aufnr_typed
    WHERE sign = 'I' AND option = 'EQ'.
    READ TABLE lt_qualified TRANSPORTING NO FIELDS
         WITH KEY table_line = ls_aufnr_typed-low.
    IF sy-subrc <> 0.
      MESSAGE |WO { ls_aufnr_typed-low }: Not yet submitted for approval. | &&
              |Please click Release in IW32 first.| TYPE 'I'.
      CLEAR gt_items_tc.
      RETURN.
    ENDIF.
  ENDLOOP.

  IF lt_qualified IS INITIAL.
    CLEAR gt_items_tc.
    MESSAGE 'No submitted or approved WOs found for this selection' TYPE 'S'
            DISPLAY LIKE 'W'.
    RETURN.
  ENDIF.

  " Narrow s_aufnr to ONLY the qualified WOs.
  CLEAR s_aufnr[].
  LOOP AT lt_qualified INTO ls_qualified.
    CLEAR ls_aufnr_line.
    ls_aufnr_line-sign   = 'I'.
    ls_aufnr_line-option = 'EQ'.
    ls_aufnr_line-low    = ls_qualified.
    APPEND ls_aufnr_line TO s_aufnr.
  ENDLOOP.

  " Bulk pipeline (ported from report ZR_SVC_WO_APPROVAL_v8.5)
  PERFORM fetch_component_data.
  ...
```

---

## Behaviour Matrix

| User Input on Subscreen 0301 | ZTWOAPPRH State | Before v1.8 | After v1.8 |
|------------------------------|-----------------|-------------|------------|
| Single WO typed, `APPR_STATUS = '1'` | submitted | Loads components | Loads components (unchanged) |
| Single WO typed, `APPR_STATUS = '2'` | approved | Loads components | Loads components (unchanged) |
| Single WO typed, `APPR_STATUS = '0'` | not released | Loads components anyway | **Popup:** *"WO 000123456: Not yet submitted for approval. Please click Release in IW32 first."* then RETURN |
| Single WO typed, no ZTWOAPPRH row | never released | Loads components anyway | Same popup as above |
| Range (BT) / Plant / Date filter | mix of statuses | Loads everything the joins return | Loads only the `'1'`/`'2'` subset. If nothing qualifies → soft warning *"No submitted or approved WOs found for this selection"* |

---

## Why the Popup Is `TYPE 'I'` (Information)

- `TYPE 'E'` only renders on the status bar — easy to miss.
- `TYPE 'I'` forces a **modal dialog** in SAPGUI, so the user clearly sees
  the corrective action ("click Release in IW32 first").
- After the user dismisses the popup, execution continues at the next
  statement, so the explicit `RETURN` that follows aborts the load cleanly.

---

## Why `s_aufnr[]` is Rewritten

- `fetch_component_data` joins `RESB × VIAUFKS × CAUFV × AFIH` purely on
  `s_aufnr / s_werks / s_erdat / s_aedat`. It has no awareness of
  ZTWOAPPRH.
- Rewriting `s_aufnr[]` to the qualified set is the least-invasive way to
  scope that join without touching `LZFG_WO_APPROVALF03.abap`.
- Consistent with the existing pattern in `compare_wo_vs_tasklist`
  (`LZFG_WO_APPROVALF03.abap`), which also rebuilds `s_aufnr` before
  invoking the bulk pipeline.

---

## No Impact On

- `STATUS_0300.abap` / `USER_COMMAND_0300.abap` — unchanged.
- Screen 0301 subscreen definition — unchanged.
- `fetch_component_data` / `build_comparison_items` — unchanged.
- `load_items_for_email` — it uses `gv_aufnr` (not `s_aufnr`) and is only
  reached from Screen 0330, which already filters by `appr_status` in
  `load_appr_ready_list`. Gating is enforced upstream.
- Save paths (`save_as_l1 / save_as_l3 / save_as_l5`) — unchanged; they
  already assume an existing ZTWOAPPRH row for the WO.

---

_End of Enhancement 1.8_
