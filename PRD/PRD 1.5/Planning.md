# 📘 PRD 1.5 — WO Approval System (SAPMZWO_APPROVAL)
## Work Order Approval System — Full Specification v1.5

**Version:** 1.5  
**Date:** April 2026  
**Module:** PM (Plant Maintenance)  
**Program:** `SAPMZWO_APPROVAL` | Transaction: `ZWOAPP`  
**Based on:** PRD v2.0 — updated with confirmed enhancements  

---

## 🔄 CHANGES FROM v2.0

| Area | v2.0 | v1.5 |
|---|---|---|
| **Screen 0100 buttons** | 5 nav targets (0300/0310/0320/0330 + EXIT toolbar) | **4 application buttons** (0300/0310/0320/0330); EXIT stays as F3 in GUI Status |
| **Screen 0300 input** | Single AUFNR field | **Single + Range** (AUFNR From / AUFNR To) |
| **L1 view on 0300** | All items shown, mismatch rows highlighted red | **Only mismatch (red) rows displayed** to L1 user |
| **L3 role label** | SDH | **SDH HO** |
| **Email trigger** | Auto on L3 save (`trigger_auto_email_branch`) | **Manual** — user marks rows on Screen 0330, clicks Send button |
| **Screen 0330** | WO input + DLI preview + auto send | **Manual send screen** — row selection + Send button |

---

## 🎯 ROLE & AUTHORIZATION MATRIX

| Level | Role Name | Scope | LVL_STATUS Impact |
|---|---|---|---|
| **L1** | BCSPPD | Approves ONLY mismatch (red) parts — **only red rows visible** | Sets `LVL_STATUS` → `1` |
| **L3** | SDH HO | Final approval for ALL parts (red + normal rows visible) | Sets `LVL_STATUS` → `2` |
| **AD** | Admin | Full access + SBWP DLI management | Any |

### Authorization Object: `ZWO_APPR`

| Field | L1 (BCSPPD) | L3 (SDH HO) | AD |
|---|---|---|---|
| `ACTVT` | `03`, `43` | `03`, `43` | `*` |
| `ZAPPR_LVL` | `L1` | `L3` | `AD` |
| `WERKS` | Plant-specific | Plant-specific | `*` |

---

## 🖥️ SCREEN NAVIGATION MAP

```
╔══════════════════════════════════════════════════════════════════════╗
║                    TRANSACTION: /NZWOAPP                             ║
║                  [USER LOGIN + AUTH CHECK ZWO_APPR]                  ║
║                              │                                       ║
║                              ▼                                       ║
║            ┌─────────────────────────────────┐                       ║
║            │   SCREEN 0100 — MAIN MENU       │                       ║
║            │   GUI Status: F3=EXIT (toolbar) │                       ║
║            └──────────────┬──────────────────┘                       ║
║                           │                                          ║
║      ┌──────────┬─────────┼──────────┬──────────┐                    ║
║      ▼          ▼         ▼          ▼                               ║
║   [0300]     [0310]    [0320]     [0330]                             ║
║   Approval   Pending   History    Send Email                         ║
║   Input +    Date      Audit      Manual                             ║
║   TC View    Range     Trail      Trigger                            ║
╚══════════════════════════════════════════════════════════════════════╝
```

---

## 📋 SCREEN 0100 — MAIN MENU

### Layout

```
╔════════════════════════════════════════════════════════════════╗
║          Work Order Approval System — Main Menu                ║
╠════════════════════════════════════════════════════════════════╣
║  GUI Toolbar: [F3 = Exit]                                      ║
╠════════════════════════════════════════════════════════════════╣
║                                                                ║
║  ┌─ Approval ──────────────────────────────────────────────┐  ║
║  │  [APPR]  Open Approval Screen (Screen 0300)             │  ║
║  │  [PEND]  Pending Approval List (Screen 0310)            │  ║
║  └────────────────────────────────────────────────────────┘  ║
║                                                                ║
║  ┌─ Reports & Communication ───────────────────────────────┐  ║
║  │  [HIST]  Approval History (Screen 0320)                 │  ║
║  │  [MAIL]  Send Email Notification (Screen 0330)          │  ║
║  └────────────────────────────────────────────────────────┘  ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
```

### Function Codes

| Button | Function Code | Target Screen |
|---|---|---|
| Approval | `APPR` | `0300` |
| Pending | `PEND` | `0310` |
| History | `HIST` | `0320` |
| Send Email | `MAIL` | `0330` |
| Exit | `&EXIT` / F3 | `LEAVE PROGRAM` (GUI Status toolbar) |

### PBO Module

```abap
MODULE status_0100 OUTPUT.
  SET PF-STATUS 'STATUS_0100'.
  SET TITLEBAR 'TITLE_0100'.
ENDMODULE.
```

### PAI Module

```abap
MODULE user_command_0100 INPUT.
  CASE sy-ucomm.
    WHEN 'APPR'.
      CLEAR gv_aufnr.
      SET SCREEN 0300. LEAVE SCREEN.
    WHEN 'PEND'.
      SET SCREEN 0310. LEAVE SCREEN.
    WHEN 'HIST'.
      SET SCREEN 0320. LEAVE SCREEN.
    WHEN 'MAIL'.
      SET SCREEN 0330. LEAVE SCREEN.
    WHEN '&EXIT' OR '&BACK'.
      LEAVE PROGRAM.
  ENDCASE.
  CLEAR sy-ucomm.
ENDMODULE.
```

> **Note:** Use `SET SCREEN xxxx. LEAVE SCREEN.` — NOT `LEAVE TO SCREEN xxxx.`

---

## 📋 SCREEN 0300 — APPROVAL INPUT & TABLE CONTROL

### Purpose
Entry point for approval. User enters a single WO number or a range (From/To), clicks Execute. The program loads all WOs in range and displays their components in a Table Control. L1 (BCSPPD) sees **only mismatch (red) rows**.

### Input Form Layout

```
╔════════════════════════════════════════════════════════════════╗
║  Work Order Approval                        [Back] [Exit]      ║
╠════════════════════════════════════════════════════════════════╣
║  Work Order From: [__________]  To: [__________]  [Execute]   ║
╠════════════════════════════════════════════════════════════════╣
║  ┌──────────────────── Table Control ──────────────────────┐  ║
║  │ [✓] [Icon] MATNR | Description | WO Qty | TL Qty | ...  │  ║
║  │ L1 sees only RED rows; L3/AD see ALL rows               │  ║
║  └────────────────────────────────────────────────────────┘  ║
║  [Save Approval]                                              ║
╚════════════════════════════════════════════════════════════════╝
```

### Key Screen Fields

| Field | Type | Description |
|---|---|---|
| `p_aufnr_from` | `AUFNR` | Work Order — From |
| `p_aufnr_to` | `AUFNR` | Work Order — To (blank = single WO) |
| `tc_items` | Table Control | Components: RESB vs Task List comparison |

### L1 Filter Logic (NEW v1.5)

```abap
" After compare_wo_vs_tasklist, L1 sees only mismatch rows
IF gv_user_level = gc_user_lvl-l1.
  DELETE gt_items_tc WHERE is_mismatch = abap_false.
ENDIF.
```

### WO Range Load Form

```abap
FORM load_wo_range_for_approval.

  DATA: lv_mismatch_cnt TYPE i,
        lt_aufnr        TYPE RANGE OF aufnr,
        ls_aufnr        LIKE LINE OF lt_aufnr.

  IF p_aufnr_from IS INITIAL.
    MESSAGE e020(zwo_appr).
    RETURN.
  ENDIF.

  ls_aufnr-sign   = 'I'.
  ls_aufnr-option = 'BT'.
  ls_aufnr-low    = p_aufnr_from.
  ls_aufnr-high   = COND #( WHEN p_aufnr_to IS INITIAL
                             THEN p_aufnr_from
                             ELSE p_aufnr_to ).
  APPEND ls_aufnr TO lt_aufnr.

  CLEAR gt_items_tc.
  SELECT aufnr FROM viaufks
    INTO TABLE @DATA(lt_wo_list)
    WHERE aufnr IN @lt_aufnr.

  LOOP AT lt_wo_list INTO DATA(ls_wo).
    gv_aufnr = ls_wo-aufnr.
    PERFORM load_wo_for_approval.
    PERFORM compare_wo_vs_tasklist USING gv_aufnr
                                   CHANGING gt_items_tc lv_mismatch_cnt.
  ENDLOOP.

  " L1: keep only mismatch rows
  IF gv_user_level = gc_user_lvl-l1.
    DELETE gt_items_tc WHERE is_mismatch = abap_false.
  ENDIF.

ENDFORM.
```

### PBO / PAI (Screen 0300)

```abap
MODULE status_0300 OUTPUT.
  SET PF-STATUS 'STATUS_0300'.
  SET TITLEBAR 'TITLE_0300'.
  DESCRIBE TABLE gt_items_tc LINES tc_items-lines.
ENDMODULE.

MODULE user_command_0300 INPUT.
  CASE sy-ucomm.
    WHEN 'EXEC'.
      PERFORM load_wo_range_for_approval.
    WHEN 'SAVE'.
      PERFORM save_approval.
    WHEN '&BACK'.
      PERFORM unlock_wo.
      SET SCREEN 0100. LEAVE SCREEN.
    WHEN '&EXIT'.
      PERFORM unlock_wo.
      LEAVE PROGRAM.
  ENDCASE.
  CLEAR sy-ucomm.
ENDMODULE.
```

---

## 📋 SCREEN 0310 — PENDING APPROVAL LIST

Unchanged from v2.0. Shows WOs with `APPR_STATUS = 1`. Date range filter. Double-click a row → loads WO in Screen 0300 for approval.

---

## 📋 SCREEN 0320 — APPROVAL HISTORY

Unchanged from v2.0. Read-only audit trail from `ZTWOAPPRH` + `ZTWOAPPR`.

---

## 📋 SCREEN 0330 — MANUAL EMAIL SEND (v1.5 CHANGE)

### Purpose
**Manual trigger only.** User navigates here, loads items, marks rows (checkbox), selects email type (HO or BR), and clicks Send. No automatic email fires on L3 save.

The email body includes **Reason Rejection** and **Reason Change** columns for each item, sourced from `ZTWOAPPR-REASON_REJECT` and `ZTWOAPPR-REASON_CHANGE`. These are shown to both HO and Branch recipients so reviewers can see why each mismatch was rejected or adjusted.

### Layout

```
╔════════════════════════════════════════════════════════════════╗
║  Send Email Notification                   [Back] [Exit]       ║
╠════════════════════════════════════════════════════════════════╣
║  Work Order: [__________]   Plant: [____]  [Load Items]        ║
╠════════════════════════════════════════════════════════════════╣
║  ┌─────────────────── Item List ──────────────────────────┐   ║
║  │ [✓] WO | Material | Description | Status | Plant       │   ║
║  │      Reason Rejection | Reason Change (from ZTWOAPPR)  │   ║
║  └────────────────────────────────────────────────────────┘   ║
║                                                                ║
║  Email Type: ( ) HO Notification   ( ) Branch Notification    ║
║  DLI Preview: APPR_<WERKS3>_<HO|BR>                           ║
║                                                                ║
║  [Send Email]                                                  ║
╚════════════════════════════════════════════════════════════════╝
```

### v2.0 → v1.5 Change Summary

| v2.0 | v1.5 |
|---|---|
| `trigger_auto_email_branch` fires in `save_as_l3` | **Removed from `save_as_l3`** |
| Email type always `'BR'` (auto) | User selects `'HO'` or `'BR'` on Screen 0330 |
| No user interaction needed | User navigates to 0330, marks rows, clicks Send |
| HTML table had no reason columns | **Reason Rejection + Reason Change columns added** to HTML body for both HO and BR emails |

### PAI Module (Screen 0330)

```abap
MODULE user_command_0330 INPUT.
  CASE sy-ucomm.
    WHEN 'LOAD'.
      PERFORM load_items_for_email.
    WHEN 'SEND'.
      PERFORM process_send_email USING p_email_type.  "'HO' or 'BR'
    WHEN '&BACK'.
      SET SCREEN 0100. LEAVE SCREEN.
    WHEN '&EXIT'.
      LEAVE PROGRAM.
  ENDCASE.
  CLEAR sy-ucomm.
ENDMODULE.
```

---

## 📧 EMAIL — SBWP 4-LAYER PATTERN (minor change in Layer 3)

Same 4-layer pattern from the Skill applies. Only the trigger point and HTML body columns change.

| Layer | FORM | Responsibility |
|---|---|---|
| 1 | `process_send_email` | Orchestrator — collect, group by WERKS, confirm popup |
| 2 | `get_email_from_dli` | Read Shared DLI first → fallback to Personal DLI |
| 3 | `build_email_html` | FIRST / BODY / LAST HTML builder — **now includes Reason columns** |
| 4 | `send_email_bcs` | `CL_BCS` send + `COMMIT WORK` |

### Email Content by Recipient Type

| Column in HTML Table | HO Email | Branch Email |
|---|---|---|
| Work Order | ✓ | ✓ |
| Material + Description | ✓ | ✓ |
| WO Qty / TL Qty | ✓ | ✓ |
| Status (MATCH / MISMATCH) | ✓ | ✓ |
| **Reason Rejection** | ✓ | ✓ |
| **Reason Change** | ✓ | ✓ |
| Plant | ✓ | ✓ |

### HTML BODY — Reason Columns (Layer 3 change)

In `build_email_html` WHEN `'BODY'`, after the Status `<td>`, add:

```abap
" Reason Rejection column
IF ls_data-reason_reject IS NOT INITIAL.
  lv_reason_rej = ls_data-reason_reject.
ELSE.
  lv_reason_rej = '-'.
ENDIF.
CONCATENATE '<td>' lv_reason_rej '</td>' INTO htmltag.
APPEND htmltag TO pt_html.

" Reason Change column
IF ls_data-reason_change IS NOT INITIAL.
  lv_reason_chg = ls_data-reason_change.
ELSE.
  lv_reason_chg = '-'.
ENDIF.
CONCATENATE '<td>' lv_reason_chg '</td>' INTO htmltag.
APPEND htmltag TO pt_html.
```

In `build_email_html` WHEN `'FIRST'` (table header row), add two `<th>` after Status:

```abap
APPEND '<th>No</th><th>Work Order</th><th>Material</th>' TO pt_html.
APPEND '<th>Description</th><th>WO Qty</th><th>TL Qty</th>' TO pt_html.
APPEND '<th>Status</th><th>Reason Rejection</th><th>Reason Change</th></tr>' TO pt_html.
```

> **Data source:** `ls_data-reason_reject` = `ZTWOAPPR-REASON_REJECT`, `ls_data-reason_change` = `ZTWOAPPR-REASON_CHANGE` — already in `ty_items_tc` from v2.0 data load.

### DLI Naming Convention

```
APPR_<WERKS3>_HO   →  e.g. APPR_100_HO   (BCSPPD recipients)
APPR_<WERKS3>_BR   →  e.g. APPR_100_BR   (Branch recipients)
```

### DLI Lookup Order (Layer 2)

1. **Shared DLI** (`shared_dli = 'X'`) — tried first
2. **Personal DLI** (`shared_dli = ' '`) — fallback if shared not found
3. Both fail → skip plant group, show warning `TYPE 'S' DISPLAY LIKE 'W'`, continue

---

## 🔄 LVL_STATUS STATE MACHINE (unchanged)

```
APPR_STATUS   LVL_STATUS   State
    0              0        Draft
    1              0        Branch Submitted — waiting L1
    1              1        L1 (BCSPPD) Done — waiting L3
    2              2        L3 (SDH HO) Final Approved
                            → Email sent MANUALLY via Screen 0330
```

---

## 🗂️ INCLUDE CHANGES SUMMARY (v1.5 Delta)

| Include | Change |
|---|---|
| `ZFG_WO_APPROVAL_F02` | Remove `PERFORM trigger_auto_email_branch` from `save_as_l3` |
| `ZFG_WO_APPROVAL_F04` | Add `load_wo_range_for_approval` FORM |
| `ZFG_WO_APPROVAL_O01` | Add PBO `status_0330` module |
| `ZFG_WO_APPROVAL_I01` | Add PAI `user_command_0330` module |
| `ZFG_WO_APPROVAL_F06` | `process_send_email` invoked from 0330 (manual) |

---

## 📑 DDIC / CONFIGURATION (unchanged from v2.0)

- Tables: `ZTWOAPPRH`, `ZTWOAPPR` — no new fields
- Lock Object: `EZTWOAPPRH`
- Authorization Object: `ZWO_APPR` (`L1` / `L3` / `AD`)
- TVARVC: `ZWO_REJECT_REASON`, `ZWO_CHANGE_REASON`
- Message Class: `ZWO_APPR`
- SBWP DLIs: `APPR_<WERKS3>_HO`, `APPR_<WERKS3>_BR` — maintained by end users in SBWP

---

## ✅ IMPLEMENTATION CHECKLIST (v1.5 Delta)

- [ ] Screen 0100: GUI Status `STATUS_0100` — F3=EXIT in toolbar + 4 app buttons (APPR/PEND/HIST/MAIL)
- [ ] Screen 0100 PAI: Use `SET SCREEN + LEAVE SCREEN` (not `LEAVE TO SCREEN`)
- [ ] Screen 0300: Add `p_aufnr_from` / `p_aufnr_to` input fields
- [ ] Screen 0300: Implement `load_wo_range_for_approval` FORM with range logic
- [ ] Screen 0300: Add L1 filter after load (`DELETE gt_items_tc WHERE is_mismatch = abap_false`)
- [ ] Screen 0330: Design manual send layout (WO input, item list, email type selection, Send button)
- [ ] Screen 0330: Implement PBO `status_0330` + PAI `user_command_0330`
- [ ] `build_email_html` FIRST: Add `<th>Reason Rejection</th><th>Reason Change</th>` to header row
- [ ] `build_email_html` BODY: Add `reason_reject` and `reason_change` `<td>` cells after Status column (both HO and BR emails)
- [ ] `save_as_l3`: **Remove** `PERFORM trigger_auto_email_branch`
- [ ] Test: L1 login → only red (mismatch) rows visible on Screen 0300
- [ ] Test: L3 save → NO auto email fires
- [ ] Test: Navigate to 0330, mark rows, select type, click Send → verify email in SOST
- [ ] Test: WO range input (From ≠ To) → verify multiple WOs load in Table Control
