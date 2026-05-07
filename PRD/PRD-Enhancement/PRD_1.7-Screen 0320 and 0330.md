# ZFG_WO_APPROVAL — Screens 0320 & 0330 Enhancement Spec

> **Function Group:** `ZFG_WO_APPROVAL`
> **Target Screens:** `0320` (Approval History) and `0330` (Manual Email Send)
> **Related Subscreens:** `SS_0320` (filter for 0320) and `SS_0330` (filter for 0330)
> **Reference Report:** `ZR_SVC_WO_APPROVAL` (used for email message conventions)
> **Goal:** Add range-filter subscreens, plant-based authorization, and multi-plant grouped email sending with role-aware messages (L4 Branch→HO, L1 HO→Branch).
>
> This spec is written so an AI coding agent can ingest it directly. Each section names the exact include / module to modify, gives the **full ABAP source** to drop in, and lists the SE51 screen/element work that the developer still has to do manually (since dynpros cannot be expressed as plain `.abap` source).

---

## 0. Scope summary (what changes vs. what is reused)

| Area | Status | Notes |
|---|---|---|
| `LZFG_WO_APPROVALTOP` | **Edit** | Add SELECT-OPTIONS for SS_0320 & SS_0330, ALV grouping types |
| Screen `0320` flow logic | **Edit** | Add `CALL SUBSCREEN ss_320` + ALV docking |
| Screen `0330` flow logic | **Edit** | Add `CALL SUBSCREEN ss_330` + ALV custom container |
| Subscreen dynpros `0322`/`0332` | **NEW (SE51)** | Generated subscreens for SELECT-OPTIONS blocks |
| `STATUS_0320` / `STATUS_0330` | **Edit** | Plant-aware default filter, free+init pattern |
| `USER_COMMAND_0320` / `USER_COMMAND_0330` | **Edit** | New fcodes: `FILTER`, `SEND_HO`, `SEND_BR` |
| `LZFG_WO_APPROVALF07` | **Edit** | Plant-filtered ALV load + read-only refresh for 0320; selectable ALV for 0330 |
| `LZFG_WO_APPROVALF05` | **Edit** | New `process_send_email_grouped` form (per-plant separate emails) |
| **Existing Approval load** (`load_items_for_email`) | **Reused as-is** | per the user request |

---

## 1. Authorization model recap

User levels are determined by `check_authorization` (FORM in `LZFG_WO_APPROVALF01`) using auth object `ZWO_APPR` with field `APPR_LEVEL`:

```text
L5 = HELPDESK   (Full / All Plants)
L4 = Branch     (Branch user — sees only own plants — sends Branch→HO)
L3 = SDH        (Service Dept Head — read-only history for own plants)
L1 = BCSPPD HO  (HO user — sees all plants — sends HO→Branch)
```

Plant scoping is built by `build_plant_range` into `r_swerk` using auth object `I_SWERK` with TCD `IW33`. **Both screens 0320 and 0330 must default-filter their ALV by `r_swerk`** so that, by default, a Branch user only sees their own plants in the docking ALV (Screen 0320) and the email-ready list (Screen 0330).

---

## 2. Selection-screen blocks for SS_0320 and SS_0330

The user's design says each new screen owns its own subscreen **for ranges of WO and Plant**. Following the existing pattern of subscreen `0301` declared inside `LZFG_WO_APPROVALTOP` via `SELECTION-SCREEN BEGIN OF SCREEN ... AS SUBSCREEN`, we add **two new selection-screen subscreens**: `0322` (drives Screen 0320) and `0332` (drives Screen 0330).

> **Why a new number for the subscreen?** SE51 forbids reusing screen numbers across roles; `0301` is already in use by Screen 0300. Naming the embedded selection-screens `0322` and `0332` keeps them adjacent to their host (`0320` / `0330`).

### 2.1 Replacement for `LZFG_WO_APPROVALTOP` — additions only

Add the following block at the **bottom** of `LZFG_WO_APPROVALTOP` (right after the existing `SELECTION-SCREEN END OF SCREEN 0301.` line). Do not delete anything that is already there.

```abap
*----------------------------------------------------------------------*
*  v1.6 — SCREEN 0320 (Approval History) filter subscreen 0322
*  Plant + WO range. Default plant is filled from r_swerk in PBO so a
*  Branch user only sees their own plants on entry.
*  Embedded into Screen 0320 via subscreen area SS_320.
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF SCREEN 0322 AS SUBSCREEN.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT (10) text-h01 FOR FIELD s_w320.
    SELECT-OPTIONS s_w320 FOR aufk-werks.       " Plant
  SELECTION-SCREEN END OF LINE.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT (10) text-h02 FOR FIELD s_a320.
    SELECT-OPTIONS s_a320 FOR aufk-aufnr.       " Work Order
  SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF SCREEN 0322.

*----------------------------------------------------------------------*
*  v1.6 — SCREEN 0330 (Manual Email Send) filter subscreen 0332
*  Plant + WO range. Branch (L4) user can pick "all" or specific plants;
*  process_send_email_grouped sends one email per plant.
*  Embedded into Screen 0330 via subscreen area SS_330.
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF SCREEN 0332 AS SUBSCREEN.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT (10) text-m01 FOR FIELD s_w330.
    SELECT-OPTIONS s_w330 FOR aufk-werks.       " Plant
  SELECTION-SCREEN END OF LINE.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT (10) text-m02 FOR FIELD s_a330.
    SELECT-OPTIONS s_a330 FOR aufk-aufnr.       " Work Order
  SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF SCREEN 0332.

*----------------------------------------------------------------------*
*  v1.6 — Send-mode constants for Screen 0330 (replaces p_email_type)
*  AUTO is set by USER_COMMAND_0330 based on user level (L1 -> BR, L4 -> HO).
*----------------------------------------------------------------------*
CONSTANTS:
  BEGIN OF gc_send_mode,
    ho TYPE char2 VALUE 'HO',     " Branch -> HO request for review
    br TYPE char2 VALUE 'BR',     " HO     -> Branch approval result
  END OF gc_send_mode.

*----------------------------------------------------------------------*
*  v1.6 — Helper type for "Approval Ready" rows (the ALV on Screen 0330)
*  Materialized from ZTWOAPPRH x ZTWOAPPR. Only WOs whose components are
*  fully approved or rejected are listed.
*----------------------------------------------------------------------*
TYPES: BEGIN OF ty_appr_ready,
         mark        TYPE char1,             " Selection checkbox
         aufnr       TYPE aufnr,             " Work Order
         werks       TYPE werks_d,           " Plant
         appr_status TYPE char1,             " ZTWOAPPRH-APPR_STATUS
         total_cmp   TYPE i,                 " Total components
         appr_cmp    TYPE i,                 " Approved (appr_valid='X')
         rejt_cmp    TYPE i,                 " Rejected
         pend_cmp    TYPE i,                 " Pending
         changed_by  TYPE syuname,
         changed_on  TYPE datum,
       END OF ty_appr_ready.

DATA: gt_appr_ready TYPE STANDARD TABLE OF ty_appr_ready,
      gs_appr_ready TYPE ty_appr_ready.

*----------------------------------------------------------------------*
*  v1.6 — Computed send mode for the active user (set in PBO of 0330)
*----------------------------------------------------------------------*
DATA: gv_send_mode TYPE char2.
```

### 2.2 Text symbols to maintain (SE38 → Goto → Text Elements)

```
H01  Plant
H02  Work Order
M01  Plant
M02  Work Order
```

---

## 3. SE51 work (cannot be expressed as `.abap` source)

The dynpros below must be edited inside SE51. Their **flow logic** is the only part that lives in `.abap` source — that flow logic is given in section 4.

### 3.1 Screen `0320` — Approval History

| Element | Type | Name | Purpose |
|---|---|---|---|
| Subscreen area | Subscreen | `SS_320` | Embed selection-screen 0322 (Plant + WO range) |
| Custom container | Custom Control | `CC_ALV_0320` | Hosts the read-only ALV grid |
| OK code field | Hidden | `OK_CODE` | Captures fcodes |

Layout: `SS_320` at top (~6 rows), `CC_ALV_0320` filling the rest. Width ≥ 200 chars.

### 3.2 Screen `0330` — Manual Email Send

| Element | Type | Name | Purpose |
|---|---|---|---|
| Subscreen area | Subscreen | `SS_330` | Embed selection-screen 0332 (Plant + WO range) |
| Custom container | Custom Control | `CC_ALV_0330` | Hosts the selectable "Approval Ready" ALV |
| OK code field | Hidden | `OK_CODE` | Captures fcodes |

Layout: `SS_330` at top (~6 rows), `CC_ALV_0330` filling the rest. Same proportions as 0320.

### 3.3 GUI status fcodes to maintain

`ZSTAT_0320`:

| Fcode | Function Text | Icon |
|---|---|---|
| `FILTER` | Apply Filter | `ICON_FILTER` |
| `&BACK` `&EXIT` `&CANC` | Standard | — |

`ZSTAT_0330`:

| Fcode | Function Text | Icon |
|---|---|---|
| `FILTER` | Apply Filter | `ICON_FILTER` |
| `LOAD` | Load Approval Ready | `ICON_REFRESH` |
| `SEND` | Send Email | `ICON_MAIL` |
| `SALL` | Select All | `ICON_SELECT_ALL` |
| `DSEL` | Deselect All | `ICON_DESELECT_ALL` |
| `&BACK` `&EXIT` `&CANC` | Standard | — |

> The single `SEND` button is intentional. Direction (HO→Branch vs Branch→HO) is **derived** from the user's role inside `USER_COMMAND_0330` so the operator never has to choose it manually. This matches the request "if L4, then Branch to HO, and if L1, then from HO to Branch".

---

## 4. Replacement source for the changed `.abap` files

Every code block below is the **complete, copy-paste replacement** for the named file. Any include / form / module not listed here is unchanged.

### 4.1 `4. Screens/0320.abap` — flow logic

```abap
*&---------------------------------------------------------------------*
*& Screen : 0320 — Approval History  (v1.6 — adds SS_320 filter + ALV)
*& Flow Logic
*&---------------------------------------------------------------------*
PROCESS BEFORE OUTPUT.
  MODULE status_0320.
  CALL SUBSCREEN ss_320 INCLUDING sy-repid '0322'.

PROCESS AFTER INPUT.
  CALL SUBSCREEN ss_320.
  MODULE user_command_0320.
```

### 4.2 `4. Screens/0330.abap` — flow logic

```abap
*&---------------------------------------------------------------------*
*& Screen : 0330 — Manual Email Send  (v1.6 — adds SS_330 filter + ALV)
*& Flow Logic
*&---------------------------------------------------------------------*
PROCESS BEFORE OUTPUT.
  MODULE status_0330.
  CALL SUBSCREEN ss_330 INCLUDING sy-repid '0332'.

PROCESS AFTER INPUT.
  CALL SUBSCREEN ss_330.
  MODULE user_command_0330.
```

### 4.3 `2. PBO Modules/STATUS_0320.abap`

```abap
*&---------------------------------------------------------------------*
*& PBO Module : STATUS_0320   (v1.6)
*& Screen     : 0320 — Approval History (Read-Only)
*& Plant default: pre-fills s_w320 from r_swerk so a Branch user only
*& sees his own plants without typing anything.
*&---------------------------------------------------------------------*
MODULE status_0320 OUTPUT.
  SET PF-STATUS gc_status-history.
  SET TITLEBAR  'T320' WITH gc_title-history.

  IF gv_0320_initialized IS INITIAL.
    PERFORM free_alv_0320.
    PERFORM default_filter_0320.   " v1.6 — pre-fill plant range
    PERFORM init_alv_0320.
    gv_0320_initialized = abap_true.
  ELSE.
    IF gr_alv_0320 IS BOUND.
      gr_alv_0320->refresh_table_display( ).
    ENDIF.
  ENDIF.
ENDMODULE.
```

### 4.4 `2. PBO Modules/STATUS_0330.abap`

```abap
*&---------------------------------------------------------------------*
*& PBO Module : STATUS_0330   (v1.6)
*& Screen     : 0330 — Manual Email Send
*& Plant default + send-mode resolution per current user level.
*&---------------------------------------------------------------------*
MODULE status_0330 OUTPUT.
  SET PF-STATUS gc_status-email.
  SET TITLEBAR  'T330' WITH gc_title-email.

  IF gv_0330_initialized IS INITIAL.
    PERFORM free_alv_0330.
    PERFORM default_filter_0330.   " v1.6 — pre-fill plant range
    PERFORM resolve_send_mode.     " v1.6 — set gv_send_mode from user level
    PERFORM init_alv_0330.
    gv_0330_initialized = abap_true.
  ELSE.
    PERFORM refresh_alv_0330.
  ENDIF.
ENDMODULE.
```

### 4.5 `3. PAI Modules/USER_COMMAND_0320.abap`

```abap
*&---------------------------------------------------------------------*
*& PAI Module : USER_COMMAND_0320   (v1.6)
*& Screen     : 0320 — Approval History (Read-Only)
*&   FILTER : reload ALV using current s_w320 / s_a320 ranges.
*&---------------------------------------------------------------------*
MODULE user_command_0320 INPUT.
  save_ok = ok_code.
  CLEAR ok_code.

  CASE save_ok.
    WHEN 'FILTER'.
      PERFORM load_appr_history.       " uses s_w320, s_a320, r_swerk
      IF gr_alv_0320 IS BOUND.
        gr_alv_0320->refresh_table_display( ).
      ENDIF.
    WHEN '&BACK'.
      CLEAR gv_0320_initialized.
      SET SCREEN 0100. LEAVE SCREEN.
    WHEN '&EXIT' OR '&CANCEL'.
      CLEAR gv_0320_initialized.
      LEAVE PROGRAM.
  ENDCASE.
ENDMODULE.
```

### 4.6 `3. PAI Modules/USER_COMMAND_0330.abap`

```abap
*&---------------------------------------------------------------------*
*& PAI Module : USER_COMMAND_0330   (v1.6)
*& Screen     : 0330 — Manual Email Send
*&   FILTER  : narrow the Approval-Ready ALV.
*&   LOAD    : reuses the existing load_items_for_email when a single
*&             WO is in p_wo_mail (kept for backward compatibility).
*&   SEND    : group selected ALV rows by plant, send one email per plant.
*&             Direction comes from gv_send_mode (set by resolve_send_mode).
*&   SALL/DSEL : toggle MARK on every visible row.
*&---------------------------------------------------------------------*
MODULE user_command_0330 INPUT.
  save_ok = ok_code.
  CLEAR ok_code.

  CASE save_ok.
    WHEN 'FILTER' OR 'LOAD'.
      PERFORM load_appr_ready_list.    " uses s_w330, s_a330, r_swerk
      PERFORM refresh_alv_0330.

    WHEN 'SALL'.
      LOOP AT gt_appr_ready ASSIGNING FIELD-SYMBOL(<fs_sa>).
        <fs_sa>-mark = 'X'.
      ENDLOOP.
      PERFORM refresh_alv_0330.

    WHEN 'DSEL'.
      LOOP AT gt_appr_ready ASSIGNING FIELD-SYMBOL(<fs_ds>).
        CLEAR <fs_ds>-mark.
      ENDLOOP.
      PERFORM refresh_alv_0330.

    WHEN 'SEND'.
      IF gv_send_mode IS INITIAL.
        MESSAGE 'Your role does not allow sending emails from this screen' TYPE 'E'.
      ELSE.
        PERFORM process_send_email_grouped USING gv_send_mode.
      ENDIF.

    WHEN '&BACK'.
      CLEAR gv_0330_initialized.
      SET SCREEN 0100. LEAVE SCREEN.

    WHEN '&EXIT' OR '&CANC'.
      CLEAR gv_0330_initialized.
      LEAVE PROGRAM.
  ENDCASE.
ENDMODULE.
```

### 4.7 `7. includes/LZFG_WO_APPROVALF07.abap` — replace blocks for 0320 & 0330

The two sections below replace the matching FORMs in `LZFG_WO_APPROVALF07`. Keep the file header and the Screen 0310 block exactly as they are.

```abap
*======================================================================*
* SCREEN 0320 — APPROVAL HISTORY  (v1.6 — Plant default + filter)
*======================================================================*

*&---------------------------------------------------------------------*
*& FORM: free_alv_0320
*&---------------------------------------------------------------------*
FORM free_alv_0320.
  IF gr_alv_0320 IS BOUND.
    gr_alv_0320->free( ).
    CLEAR gr_alv_0320.
  ENDIF.
  IF gr_cont_0320 IS BOUND.
    gr_cont_0320->free( ).
    CLEAR gr_cont_0320.
  ENDIF.
  CLEAR: gt_fcat_0320, gs_layout_0320, gt_appr_history.
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: default_filter_0320
*& Pre-fill s_w320 with r_swerk so the ALV opens scoped to the
*& current user's authorized plants. User can override the range
*& on screen and press FILTER.
*&---------------------------------------------------------------------*
FORM default_filter_0320.
  DATA ls_w LIKE LINE OF s_w320.

  IF s_w320[] IS NOT INITIAL.
    RETURN.   " User has typed something — respect it.
  ENDIF.

  LOOP AT r_swerk INTO DATA(ls_r).
    CLEAR ls_w.
    ls_w-sign   = ls_r-sign.
    ls_w-option = ls_r-option.
    ls_w-low    = ls_r-low.
    ls_w-high   = ls_r-high.
    APPEND ls_w TO s_w320.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: build_fcat_0320
*& Same field catalog as v1.5 — read-only history.
*&---------------------------------------------------------------------*
FORM build_fcat_0320.
  DATA ls_fcat TYPE lvc_s_fcat.
  CLEAR gt_fcat_0320.

  ls_fcat-fieldname = 'AUFNR'.          ls_fcat-coltext = 'Work Order'.
  ls_fcat-outputlen = 12.               APPEND ls_fcat TO gt_fcat_0320. CLEAR ls_fcat.

  ls_fcat-fieldname = 'WERKS'.          ls_fcat-coltext = 'Plant'.
  ls_fcat-outputlen = 6.                APPEND ls_fcat TO gt_fcat_0320. CLEAR ls_fcat.

  ls_fcat-fieldname = 'MATNR'.          ls_fcat-coltext = 'Material'.
  ls_fcat-outputlen = 18.               APPEND ls_fcat TO gt_fcat_0320. CLEAR ls_fcat.

  ls_fcat-fieldname = 'CHANGE_ID'.      ls_fcat-coltext = 'Change ID'.
  ls_fcat-outputlen = 20.               APPEND ls_fcat TO gt_fcat_0320. CLEAR ls_fcat.

  ls_fcat-fieldname = 'REASON_CHANGE'.  ls_fcat-coltext = 'Reason Change'.
  ls_fcat-outputlen = 40.               APPEND ls_fcat TO gt_fcat_0320. CLEAR ls_fcat.

  ls_fcat-fieldname = 'REASON_REJECT'.  ls_fcat-coltext = 'Reason Reject'.
  ls_fcat-outputlen = 40.               APPEND ls_fcat TO gt_fcat_0320. CLEAR ls_fcat.

  ls_fcat-fieldname = 'APPROVAL_STAT'.  ls_fcat-coltext = 'Approval Status'.
  ls_fcat-outputlen = 14.               APPEND ls_fcat TO gt_fcat_0320. CLEAR ls_fcat.

  ls_fcat-fieldname = 'APPROVAL_LVL1'.  ls_fcat-coltext = 'L1 Approved'.
  ls_fcat-checkbox  = abap_true.
  ls_fcat-outputlen = 8.                APPEND ls_fcat TO gt_fcat_0320. CLEAR ls_fcat.

  ls_fcat-fieldname = 'APPROVAL_LVL3'.  ls_fcat-coltext = 'L3 Approved'.
  ls_fcat-checkbox  = abap_true.
  ls_fcat-outputlen = 8.                APPEND ls_fcat TO gt_fcat_0320. CLEAR ls_fcat.

  ls_fcat-fieldname = 'APPR_BY_LVL1'.   ls_fcat-coltext = 'Appr By L1'.
  ls_fcat-outputlen = 12.               APPEND ls_fcat TO gt_fcat_0320. CLEAR ls_fcat.

  ls_fcat-fieldname = 'APPR_DATE_LVL1'. ls_fcat-coltext = 'Appr Date L1'.
  ls_fcat-outputlen = 10.               APPEND ls_fcat TO gt_fcat_0320. CLEAR ls_fcat.

  ls_fcat-fieldname = 'APPR_BY_LVL3'.   ls_fcat-coltext = 'Appr By L3'.
  ls_fcat-outputlen = 12.               APPEND ls_fcat TO gt_fcat_0320. CLEAR ls_fcat.

  ls_fcat-fieldname = 'APPR_DATE_LVL3'. ls_fcat-coltext = 'Appr Date L3'.
  ls_fcat-outputlen = 10.               APPEND ls_fcat TO gt_fcat_0320. CLEAR ls_fcat.
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: load_appr_history
*& v1.6 — driven by SS_320 ranges (s_w320, s_a320) AND r_swerk so the
*& user can never see plants outside their I_SWERK authorization,
*& regardless of what they type into the range.
*&---------------------------------------------------------------------*
FORM load_appr_history.
  CLEAR gt_appr_history.

  SELECT * FROM ztwoappr
    INTO TABLE @gt_appr_history
    WHERE aufnr IN @s_a320
    ORDER BY aufnr, matnr.

  IF gt_appr_history IS INITIAL.
    RETURN.
  ENDIF.

  " Plant filter via WO header (ZTWOAPPR has no WERKS column — get from header).
  DATA: lt_hdr TYPE STANDARD TABLE OF ztwoapprh.
  SELECT aufnr, werks
    FROM ztwoapprh
    INTO CORRESPONDING FIELDS OF TABLE @lt_hdr
    FOR ALL ENTRIES IN @gt_appr_history
    WHERE aufnr = @gt_appr_history-aufnr
      AND werks IN @s_w320
      AND werks IN @r_swerk.

  " Drop rows whose WO header was filtered out
  LOOP AT gt_appr_history ASSIGNING FIELD-SYMBOL(<fs_ah>).
    READ TABLE lt_hdr TRANSPORTING NO FIELDS
      WITH KEY aufnr = <fs_ah>-aufnr.
    IF sy-subrc <> 0.
      DELETE gt_appr_history.
    ENDIF.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: init_alv_0320
*&---------------------------------------------------------------------*
FORM init_alv_0320.
  PERFORM build_fcat_0320.
  PERFORM load_appr_history.

  gs_layout_0320-zebra      = abap_true.
  gs_layout_0320-cwidth_opt = abap_true.
  gs_layout_0320-no_toolbar = space.        " ALV toolbar shown — read-only

  CREATE OBJECT gr_cont_0320
    EXPORTING container_name = 'CC_ALV_0320'.

  CREATE OBJECT gr_alv_0320
    EXPORTING i_parent = gr_cont_0320.

  gr_alv_0320->set_table_for_first_display(
    EXPORTING
      is_layout       = gs_layout_0320
      i_default       = abap_true
      i_save          = 'A'
    CHANGING
      it_fieldcatalog = gt_fcat_0320
      it_outtab       = gt_appr_history ).
ENDFORM.


*======================================================================*
* SCREEN 0330 — MANUAL EMAIL SEND  (v1.6 — Plant default + selectable ALV)
*======================================================================*

*&---------------------------------------------------------------------*
*& FORM: free_alv_0330
*&---------------------------------------------------------------------*
FORM free_alv_0330.
  IF gr_alv_0330 IS BOUND.
    gr_alv_0330->free( ).
    CLEAR gr_alv_0330.
  ENDIF.
  IF gr_cont_0330 IS BOUND.
    gr_cont_0330->free( ).
    CLEAR gr_cont_0330.
  ENDIF.
  CLEAR: gt_fcat_0330, gs_layout_0330, gt_appr_ready, gv_send_mode.
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: default_filter_0330
*& Same idea as default_filter_0320 — pre-fill plant range from r_swerk.
*&---------------------------------------------------------------------*
FORM default_filter_0330.
  DATA ls_w LIKE LINE OF s_w330.

  IF s_w330[] IS NOT INITIAL.
    RETURN.
  ENDIF.

  LOOP AT r_swerk INTO DATA(ls_r).
    CLEAR ls_w.
    ls_w-sign   = ls_r-sign.
    ls_w-option = ls_r-option.
    ls_w-low    = ls_r-low.
    ls_w-high   = ls_r-high.
    APPEND ls_w TO s_w330.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: resolve_send_mode
*& Maps user level to a send direction:
*&   L4 (Branch)   -> 'HO'  (Branch sends to HO requesting review)
*&   L1 (BCSPPD HO)-> 'BR'  (HO sends to Branch announcing approval)
*&   L5 (HELPDESK) -> 'HO'  (default — HELPDESK can mimic Branch action)
*&   L3 (SDH)      -> ' '   (no send permission)
*&---------------------------------------------------------------------*
FORM resolve_send_mode.
  CLEAR gv_send_mode.
  CASE gv_user_level.
    WHEN gc_user_lvl-l4.   gv_send_mode = gc_send_mode-ho.
    WHEN gc_user_lvl-l1.   gv_send_mode = gc_send_mode-br.
    WHEN gc_user_lvl-l5.   gv_send_mode = gc_send_mode-ho.
    WHEN OTHERS.           CLEAR gv_send_mode.
  ENDCASE.
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: build_fcat_0330
*&---------------------------------------------------------------------*
FORM build_fcat_0330.
  DATA ls_fcat TYPE lvc_s_fcat.
  CLEAR gt_fcat_0330.

  ls_fcat-fieldname = 'MARK'.        ls_fcat-coltext = 'Send'.
  ls_fcat-checkbox  = abap_true.     ls_fcat-edit    = abap_true.
  ls_fcat-outputlen = 5.             APPEND ls_fcat TO gt_fcat_0330. CLEAR ls_fcat.

  ls_fcat-fieldname = 'AUFNR'.       ls_fcat-coltext = 'Work Order'.
  ls_fcat-outputlen = 12.            APPEND ls_fcat TO gt_fcat_0330. CLEAR ls_fcat.

  ls_fcat-fieldname = 'WERKS'.       ls_fcat-coltext = 'Plant'.
  ls_fcat-outputlen = 6.             APPEND ls_fcat TO gt_fcat_0330. CLEAR ls_fcat.

  ls_fcat-fieldname = 'APPR_STATUS'. ls_fcat-coltext = 'Hdr Status'.
  ls_fcat-outputlen = 8.             APPEND ls_fcat TO gt_fcat_0330. CLEAR ls_fcat.

  ls_fcat-fieldname = 'TOTAL_CMP'.   ls_fcat-coltext = 'Total Comp'.
  ls_fcat-outputlen = 6.             APPEND ls_fcat TO gt_fcat_0330. CLEAR ls_fcat.

  ls_fcat-fieldname = 'APPR_CMP'.    ls_fcat-coltext = 'Approved'.
  ls_fcat-outputlen = 6.             APPEND ls_fcat TO gt_fcat_0330. CLEAR ls_fcat.

  ls_fcat-fieldname = 'REJT_CMP'.    ls_fcat-coltext = 'Rejected'.
  ls_fcat-outputlen = 6.             APPEND ls_fcat TO gt_fcat_0330. CLEAR ls_fcat.

  ls_fcat-fieldname = 'PEND_CMP'.    ls_fcat-coltext = 'Pending'.
  ls_fcat-outputlen = 6.             APPEND ls_fcat TO gt_fcat_0330. CLEAR ls_fcat.

  ls_fcat-fieldname = 'CHANGED_BY'.  ls_fcat-coltext = 'Changed By'.
  ls_fcat-outputlen = 12.            APPEND ls_fcat TO gt_fcat_0330. CLEAR ls_fcat.

  ls_fcat-fieldname = 'CHANGED_ON'.  ls_fcat-coltext = 'Changed On'.
  ls_fcat-outputlen = 10.            APPEND ls_fcat TO gt_fcat_0330. CLEAR ls_fcat.
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: load_appr_ready_list
*& Materializes one row per WO header that already has component-level
*& approval activity (header status submitted or fully approved). The
*& counts come from ZTWOAPPR. Filtered by SS_330 ranges + r_swerk.
*&---------------------------------------------------------------------*
FORM load_appr_ready_list.

  CLEAR gt_appr_ready.

  DATA: lt_hdr TYPE STANDARD TABLE OF ztwoapprh.

  SELECT * FROM ztwoapprh
    INTO TABLE @lt_hdr
    WHERE aufnr IN @s_a330
      AND werks IN @s_w330
      AND werks IN @r_swerk
      AND appr_status IN ( @gc_appr_status-submitted, @gc_appr_status-approved ).

  IF lt_hdr IS INITIAL.
    RETURN.
  ENDIF.

  " Pull component rows in one shot
  DATA: lt_cmp TYPE STANDARD TABLE OF ztwoappr.
  SELECT * FROM ztwoappr
    INTO TABLE @lt_cmp
    FOR ALL ENTRIES IN @lt_hdr
    WHERE aufnr = @lt_hdr-aufnr.

  LOOP AT lt_hdr INTO DATA(ls_hdr).
    CLEAR gs_appr_ready.
    gs_appr_ready-aufnr       = ls_hdr-aufnr.
    gs_appr_ready-werks       = ls_hdr-werks.
    gs_appr_ready-appr_status = ls_hdr-appr_status.
    gs_appr_ready-changed_by  = ls_hdr-changed_by.
    gs_appr_ready-changed_on  = ls_hdr-changed_date.

    LOOP AT lt_cmp INTO DATA(ls_cmp) WHERE aufnr = ls_hdr-aufnr.
      gs_appr_ready-total_cmp = gs_appr_ready-total_cmp + 1.
      IF ls_cmp-appr_valid = 'X'.
        gs_appr_ready-appr_cmp = gs_appr_ready-appr_cmp + 1.
      ELSEIF ls_cmp-approval_stat = 'Reject Approval'.
        gs_appr_ready-rejt_cmp = gs_appr_ready-rejt_cmp + 1.
      ELSE.
        gs_appr_ready-pend_cmp = gs_appr_ready-pend_cmp + 1.
      ENDIF.
    ENDLOOP.

    APPEND gs_appr_ready TO gt_appr_ready.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: init_alv_0330
*&---------------------------------------------------------------------*
FORM init_alv_0330.
  PERFORM build_fcat_0330.
  PERFORM load_appr_ready_list.    " v1.6 — open the ALV pre-loaded

  gs_layout_0330-zebra      = abap_true.
  gs_layout_0330-cwidth_opt = abap_true.
  gs_layout_0330-edit       = abap_true.

  CREATE OBJECT gr_cont_0330
    EXPORTING container_name = 'CC_ALV_0330'.

  CREATE OBJECT gr_alv_0330
    EXPORTING i_parent = gr_cont_0330.

  gr_alv_0330->set_table_for_first_display(
    EXPORTING
      is_layout       = gs_layout_0330
      i_default       = abap_true
      i_save          = 'A'
    CHANGING
      it_fieldcatalog = gt_fcat_0330
      it_outtab       = gt_appr_ready ).
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: refresh_alv_0330
*&---------------------------------------------------------------------*
FORM refresh_alv_0330.
  IF gr_alv_0330 IS BOUND.
    " Force the grid to commit any in-place edits before we re-paint
    gr_alv_0330->check_changed_data( ).
    gr_alv_0330->refresh_table_display( ).
  ENDIF.
ENDFORM.
```

### 4.8 `7. includes/LZFG_WO_APPROVALF05.abap` — add `process_send_email_grouped`

Append the form below to `LZFG_WO_APPROVALF05`. Do not remove the existing `process_send_email` — it still drives the legacy single-WO path.

```abap
*&---------------------------------------------------------------------*
*& FORM: process_send_email_grouped   (v1.6)
*&
*& New driver for Screen 0330. Iterates the user's selection inside
*& gt_appr_ready, groups by plant, builds one HTML body per plant, and
*& sends one email per plant via the existing 4-layer pipeline.
*&
*& Subject lines (mirroring report ZR_SVC_WO_APPROVAL):
*&   HO mode -> "Service WO Approval - <n> Item(s) Plant <WERKS> Request for Review"
*&   BR mode -> "Service WO Approval - <n> Item(s) Plant <WERKS> Approved by HO"
*&
*& DLI naming convention:
*&   APPR_<WERKS>_HO  - HO recipients (Branch -> HO emails)
*&   APPR_<WERKS>_BR  - Branch recipients (HO -> Branch emails)
*&---------------------------------------------------------------------*
FORM process_send_email_grouped USING pv_email_type TYPE char2.

  TYPES: BEGIN OF lty_group,
           werks TYPE werks_d,
         END OF lty_group.

  DATA: lt_groups     TYPE STANDARD TABLE OF lty_group,
        ls_group      TYPE lty_group,
        lt_plant_wos  TYPE STANDARD TABLE OF ty_appr_ready,
        lt_html       TYPE bcsy_text,
        lv_subject    TYPE so_obj_des,
        lv_dli_name   TYPE so_recname,
        lv_date_str   TYPE char10,
        lv_item_count TYPE i,
        lv_total_sent TYPE i,
        lv_skip_count TYPE i,
        lv_save_aufnr TYPE aufnr.

  " 1. Sanity: any selected WOs?
  DATA(lt_marked) = VALUE STANDARD TABLE OF ty_appr_ready( ).
  LOOP AT gt_appr_ready INTO DATA(ls_row) WHERE mark = 'X'.
    APPEND ls_row TO lt_marked.
  ENDLOOP.

  IF lt_marked IS INITIAL.
    MESSAGE 'Please mark at least one WO row before pressing Send' TYPE 'E'.
    RETURN.
  ENDIF.

  " 2. Build distinct plant list
  LOOP AT lt_marked INTO ls_row.
    READ TABLE lt_groups WITH KEY werks = ls_row-werks TRANSPORTING NO FIELDS.
    IF sy-subrc <> 0.
      ls_group-werks = ls_row-werks.
      APPEND ls_group TO lt_groups.
    ENDIF.
  ENDLOOP.

  WRITE sy-datum TO lv_date_str DD/MM/YYYY.
  lv_save_aufnr = gv_aufnr.

  " 3. Send one email per plant
  LOOP AT lt_groups INTO ls_group.

    " 3a. Collect WOs for this plant
    CLEAR lt_plant_wos.
    LOOP AT lt_marked INTO ls_row WHERE werks = ls_group-werks.
      APPEND ls_row TO lt_plant_wos.
    ENDLOOP.
    DESCRIBE TABLE lt_plant_wos LINES lv_item_count.
    CHECK lv_item_count > 0.

    " 3b. Materialize per-component detail for ALL WOs of this plant
    "     into gt_selected. The HTML builder reads gt_selected.
    CLEAR gt_selected.
    LOOP AT lt_plant_wos INTO ls_row.
      gv_aufnr = ls_row-aufnr.
      PERFORM load_items_for_email.            " existing — reused as-is
      APPEND LINES OF gt_items_tc TO gt_selected.
    ENDLOOP.

    " 3c. Resolve recipients via shared SBWP DLI
    lv_dli_name = |APPR_{ ls_group-werks }_{ pv_email_type }|.
    PERFORM get_email_from_dli USING lv_dli_name.

    IF gt_recipients IS INITIAL.
      MESSAGE |No DLI { lv_dli_name } — plant { ls_group-werks } skipped|
              TYPE 'S' DISPLAY LIKE 'W'.
      lv_skip_count = lv_skip_count + 1.
      CONTINUE.
    ENDIF.

    " 3d. Subject — mirrors ZR_SVC_WO_APPROVAL conventions
    IF pv_email_type = gc_send_mode-ho.
      lv_subject = |Service WO Approval - { lv_item_count } Item(s) Plant { ls_group-werks } Request for Review|.
    ELSE.
      lv_subject = |Service WO Approval - { lv_item_count } Item(s) Plant { ls_group-werks } Approved by HO|.
    ENDIF.

    " 3e. Build HTML body
    CLEAR lt_html.
    PERFORM build_email_html USING 'FIRST' lv_date_str lv_item_count
                                   pv_email_type ls_group-werks
                            CHANGING lt_html.
    PERFORM build_email_html USING 'BODY'  lv_date_str lv_item_count
                                   pv_email_type ls_group-werks
                            CHANGING lt_html.
    PERFORM build_email_html USING 'LAST'  lv_date_str lv_item_count
                                   pv_email_type ls_group-werks
                            CHANGING lt_html.

    " 3f. Send
    TRY.
        PERFORM send_email_bcs TABLES gt_recipients
                               USING lv_subject lt_html.
        lv_total_sent = lv_total_sent + 1.
      CATCH cx_bcs INTO DATA(lx).
        MESSAGE |Send error for plant { ls_group-werks }: { lx->get_text( ) }|
                TYPE 'S' DISPLAY LIKE 'W'.
        lv_skip_count = lv_skip_count + 1.
    ENDTRY.

  ENDLOOP.

  gv_aufnr = lv_save_aufnr.

  IF lv_total_sent > 0.
    DATA(lv_msg) = |Email sent to { lv_total_sent } plant(s)|.
    IF lv_skip_count > 0.
      lv_msg = lv_msg && |, { lv_skip_count } skipped|.
    ENDIF.
    MESSAGE lv_msg TYPE 'S'.
  ELSE.
    MESSAGE 'No emails sent — verify SBWP Distribution Lists' TYPE 'W'.
  ENDIF.

ENDFORM.
```

---

## 5. End-to-end behavior matrix

| User level | Opens 0320 default scope | Opens 0330 default scope | SEND on 0330 sends to | Subject pattern |
|---|---|---|---|---|
| **L1 (BCSPPD HO)** | All plants user is authorized for (`r_swerk`) | Same | `APPR_<WERKS>_BR` (Branch) | `… Plant <W> Approved by HO` |
| **L4 (Branch)** | Only plants in `r_swerk` (typically 1) | Same | `APPR_<WERKS>_HO` (HO) | `… Plant <W> Request for Review` |
| **L3 (SDH)** | Read-only history of own plants | ALV visible, **SEND blocked** | — | — |
| **L5 (HELPDESK)** | All plants | All plants | Defaults to `APPR_<WERKS>_HO` (override possible) | `… Request for Review` |

Plant grouping rule (Branch user perspective): if the Branch user **selects rows from multiple plants** (e.g. selects all and the user has authorization across two plants), the form `process_send_email_grouped` will **send N separate emails**, one per plant, each addressed to that plant's own `APPR_<WERKS>_HO` distribution list.

---

## 6. Order of changes (developer checklist)

1. **SE51** — Edit Screen `0320`: place subscreen area `SS_320` and custom container `CC_ALV_0320` per section 3.1; replace flow logic with section 4.1.
2. **SE51** — Edit Screen `0330`: place subscreen area `SS_330` and custom container `CC_ALV_0330` per section 3.2; replace flow logic with section 4.2.
3. **SE80** — Edit `LZFG_WO_APPROVALTOP`: append the v1.6 block from section 2.1. Maintain text symbols H01/H02/M01/M02.
4. **SE80** — Replace `STATUS_0320` (section 4.3) and `STATUS_0330` (section 4.4).
5. **SE80** — Replace `USER_COMMAND_0320` (section 4.5) and `USER_COMMAND_0330` (section 4.6).
6. **SE80** — Replace the 0320 / 0330 sections inside `LZFG_WO_APPROVALF07` (section 4.7).
7. **SE80** — Append `process_send_email_grouped` to `LZFG_WO_APPROVALF05` (section 4.8).
8. **SE41** — Update GUI statuses `ZSTAT_0320` and `ZSTAT_0330` to add the fcodes listed in section 3.3.
9. **SBWP** — Maintain shared distribution lists named `APPR_<WERKS>_HO` and `APPR_<WERKS>_BR` for every plant in scope.
10. **SU24 / PFCG** — Re-check `ZWO_APPR` and `I_SWERK` role assignments so each user actually lands in the level they should.

---

## 7. Smoke-test cases

| # | Setup | Steps | Expected |
|---|---|---|---|
| 1 | Branch user (L4), authorized for plant `2210` | Open 0320 | `s_w320` is pre-filled with `2210`. ALV shows only history rows whose WO header `werks = 2210`. |
| 2 | Same user | Type plant `9999` and press FILTER | ALV is empty; user is silently restricted by `r_swerk`. No security breach. |
| 3 | HO user (L1) | Open 0330 | ALV pre-loads. `gv_send_mode = 'BR'`. Pressing SEND on 1 row → email goes to `APPR_<WERKS>_BR`. |
| 4 | Branch user (L4) authorized for plants `2210` and `2230` | Open 0330, select rows from both plants, press SEND | **Two emails** sent: one to `APPR_2210_HO`, one to `APPR_2230_HO`. Status bar shows `Email sent to 2 plant(s)`. |
| 5 | SDH user (L3) | Open 0330, mark a row, press SEND | Hard error `Your role does not allow sending emails from this screen`. |
| 6 | Any user | DLI `APPR_2230_HO` does not exist in SBWP, but that plant was selected | That plant is skipped with a warning; other plants still send. |
| 7 | Re-entry test | From any of the new screens, press BACK → re-enter | `gv_0320_initialized` / `gv_0330_initialized` cleared; PBO frees and rebuilds the ALV cleanly (no leak). |

---

## 8. Notes for the AI agent

- Do **not** reorder forms inside the existing includes. The append-only sections in this spec are designed so that adding code never breaks line numbers other developers rely on.
- The existing `load_items_for_email` form **must remain untouched**. Section 4.8 reuses it as-is — that is the single source of truth for hydrating per-component detail for one WO.
- The pre-existing `process_send_email` (single-WO send) keeps working for the Screen 0300 flow. The new `process_send_email_grouped` is only invoked from Screen 0330.
- All new SELECT-OPTIONS (`s_w320`, `s_a320`, `s_w330`, `s_a330`) live inside the dynpro selection-screens 0322/0332 and so they are **dynpro-private**. They do not pollute the program's main selection screen.