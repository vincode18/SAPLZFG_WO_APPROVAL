# ZFG_WO_APPROVAL — Developer Implementation Guide
**Version:** 1.5 | **Transaction:** ZWOAPP | **Program:** SAPMZWO_APPROVAL

---

## 📋 Table of Contents

1. [SE80 Creation Sequence](#1-se80-creation-sequence)
2. [Table Control — Screen 0300](#2-table-control--screen-0300)
3. [ALV Custom Container — Screens 0310 / 0320 / 0330](#3-alv-custom-container--screens-0310--0320--0330)
4. [Free Screen Objects Pattern (Re-entry)](#4-free-screen-objects-pattern-re-entry)
5. [Include File Map](#5-include-file-map)
6. [GUI Status Setup (SE41)](#6-gui-status-setup-se41)
7. [SBWP DLI Setup](#7-sbwp-dli-setup)
8. [Authorization Object Setup](#8-authorization-object-setup)
9. [TVARVC Reason Code Setup](#9-tvarvc-reason-code-setup)
10. [Testing Checklist](#10-testing-checklist)
11. [Function Module Implementation Guide](#11-function-module-implementation-guide)

---

## 1. SE80 Creation Sequence

Create objects **in this exact order** to avoid forward reference errors.

### Step 1 — Create Function Group
- SE80 → Function Group → `ZFG_WO_APPROVAL`
- Description: `Work Order Approval System v1.5`
- The system auto-creates: `ZFG_WO_APPROVALTOP`, `ZFG_WO_APPROVALUXX`

### Step 2 — DDIC Objects (SE11)
Create these first — FMs reference them:

| Object | Type | Name |
|---|---|---|
| Database Table | Transparent | `ZTWOAPPRH` |
| Database Table | Transparent | `ZTWOAPPR` |
| Lock Object | Enqueue | `EZTWOAPPRH` |
| Auth Object | Auth Object | `ZWO_APPR` |
| Message Class | Messages | `ZWO_APPR` |

### Step 3 — Add Includes to Function Group
In SE80, right-click Function Group → **Create Include**:

| Include Name | Purpose |
|---|---|
| `ZFG_WO_APPROVALF01` | Authorization & Init |
| `ZFG_WO_APPROVALF02` | Save Logic |
| `ZFG_WO_APPROVALF03` | Data Retrieval & Compare |
| `ZFG_WO_APPROVALF04` | WO Range Load |
| `ZFG_WO_APPROVALF05` | Email Orchestration (Layer 1+2) |
| `ZFG_WO_APPROVALF06` | HTML Builder + BCS Sender (Layer 3+4) |
| `ZFG_WO_APPROVALF07` | ALV Free/Init FORMs |

Then register all of them in `ZFG_WO_APPROVAL` master include block.

### Step 4 — Create Screens (SE80 → Screens)
Create screens in this order:

| Screen | Type | Description |
|---|---|---|
| `0100` | Normal | Main Menu — 4 application buttons |
| `0300` | Normal | Approval Input + **Table Control** |
| `0310` | Normal | Pending List — **Custom Container** `CC_ALV_0310` |
| `0320` | Normal | History — **Custom Container** `CC_ALV_0320` |
| `0330` | Normal | Email Send — **Custom Container** `CC_ALV_0330` |

### Step 5 — GUI Statuses (SE41)
Use `ZSTAT_0100` … `ZSTAT_0330` — see [Section 6](#6-gui-status-setup-se41).

### Step 6 — GUI Titles
Create `T100`, `T300`, `T310`, `T320`, `T330` in SE41.

### Step 7 — Function Module Entry Point
In `ZFG_WO_APPROVALUXX`: implement `ZFG_WO_APPROVAL_MAIN` — calls `check_authorization` then `CALL SCREEN 0100`.

### Step 8 — Transaction (SE93)
- Code: `ZWOAPP`
- Type: *Function module transaction*
- FM: `ZFG_WO_APPROVAL_MAIN`

---

## 2. Table Control — Screen 0300

Screen 0300 uses a **Module Pool Table Control** (not ALV). This section explains layout and flow logic.

### Screen Layout (SE51 — Screen Painter)

```
┌────────────────────────────────────────────────────────────┐
│  Work Order From: [P_AUFNR_FROM  ] To: [P_AUFNR_TO  ]     │
│  Plant:           [GV_WERKS      ]    [Execute]  [Save]    │
├────────────────────────────────────────────────────────────┤
│ TABLE CONTROL: TC_ITEMS  (scrollable, lines=15)            │
│ ┌──┬────────────┬──────────┬──────────────┬──────┬───────┐ │
│ │✓ │ Work Order │ Material │ Description  │WO Qty│TL Qty │ │
│ ├──┼────────────┼──────────┼──────────────┼──────┼───────┤ │
│ │  │ GS..AUFNR  │ GS..MATN │ GS..MAKTX    │GS..BD│GS..TL │ │
│ ├──┼────────────┼──────────┼──────────────┼──────┼───────┤ │
│ │  │            │          │              │      │       │ │
│ └──┴────────────┴──────────┴──────────────┴──────┴───────┘ │
│  Approve: [GS_ITEMS_TC-APPR_FLAG]  Reason: [GS..REASON]   │
└────────────────────────────────────────────────────────────┘
```

### Creating the Table Control in SE51

1. Open Screen 0300 in SE51 → **Layout** tab
2. Menu: **Edit → Create Element → Table Control**
3. Draw rectangle for the table area
4. Name it: `TC_ITEMS`
5. Set **Lines** = 15, check **Horizontal scrolling**
6. Add column fields mapped to `GS_ITEMS_TC-*` fields

### Table Control Column Field Names in Screen

| Column | Screen Field Name | ABAP Field |
|---|---|---|
| Mark | `GS_ITEMS_TC-MARK` | `ty_items_tc-mark` |
| Work Order | `GS_ITEMS_TC-AUFNR` | `ty_items_tc-aufnr` |
| Material | `GS_ITEMS_TC-MATNR` | `ty_items_tc-matnr` |
| Description | `GS_ITEMS_TC-MAKTX` | `ty_items_tc-maktx` |
| WO Qty | `GS_ITEMS_TC-BDMNG` | `ty_items_tc-bdmng` |
| TL Qty | `GS_ITEMS_TC-MENGE_TL` | `ty_items_tc-menge_tl` |
| Status | `GS_ITEMS_TC-IS_MISMATCH` | displayed as MATCH/MISMATCH |
| Approve | `GS_ITEMS_TC-APPR_FLAG` | checkbox — input-sensitive |
| Reason | `GS_ITEMS_TC-REASON_CODE` | dropdown via VRM_SET_VALUES |

### Flow Logic for Screen 0300 (full)

```abap
PROCESS BEFORE OUTPUT.
  MODULE status_0300.
  MODULE load_reasons.
  LOOP AT gt_items_tc INTO gs_items_tc
       WITH CONTROL tc_items CURSOR tc_items-current_line.
    MODULE read_tc_line.
    MODULE set_row_color.
    MODULE set_reason_dropdown.
    MODULE control_field_attributes.
  ENDLOOP.

PROCESS AFTER INPUT.
  LOOP AT gt_items_tc.
    CHAIN.
      FIELD gs_items_tc-mark.
      FIELD gs_items_tc-appr_flag.
      FIELD gs_items_tc-reason_code.
      MODULE modify_tc_line.
      MODULE validate_reason ON CHAIN-REQUEST.
    ENDCHAIN.
  ENDLOOP.
  MODULE user_command_0300.
```

### Row Coloring Rule

| Condition | Color |
|---|---|
| `is_mismatch = abap_true` | Red — `screen-intensified = '1'` |
| `is_mismatch = abap_false` | Normal |

### L1 Visibility Rule (v1.5)

After `compare_wo_vs_tasklist`, in `load_wo_range_for_approval`:
```abap
IF gv_user_level = gc_user_lvl-l1.
  DELETE gt_items_tc WHERE is_mismatch = abap_false.
ENDIF.
```
L1 (BCSPPD) sees **only mismatch rows**. L3/AD see all rows.

---

## 3. ALV Custom Container — Screens 0310 / 0320 / 0330

Screens 0310, 0320, 0330 use **CL_GUI_ALV_GRID inside CL_GUI_CUSTOM_CONTAINER** — no Table Control.

### Screen Layout in SE51

For each screen, place a **Custom Control** element:

| Screen | Container Name | Purpose |
|---|---|---|
| 0310 | `CC_ALV_0310` | Pending WO list (ALV, double-click to open) |
| 0320 | `CC_ALV_0320` | Approval history (read-only ALV) |
| 0330 | `CC_ALV_0330` | Email item list (ALV with mark column + Send) |

Steps in SE51:
1. Open screen layout
2. **Edit → Create Element → Custom Control**
3. Draw rectangle (fill most of screen)
4. Name it exactly `CC_ALV_0310` (or 0320 / 0330)

### Global Variables (in TOP include)

```abap
" Screen 0310 — Pending List
DATA: gv_0310_initialized TYPE abap_bool,
      gr_alv_0310         TYPE REF TO cl_gui_alv_grid,
      gr_cont_0310        TYPE REF TO cl_gui_custom_container,
      gt_fcat_0310        TYPE lvc_t_fcat,
      gs_layout_0310      TYPE lvc_s_layo,
      gt_pending_wo       TYPE STANDARD TABLE OF ztwoapprh.

" Screen 0320 — History
DATA: gv_0320_initialized TYPE abap_bool,
      gr_alv_0320         TYPE REF TO cl_gui_alv_grid,
      gr_cont_0320        TYPE REF TO cl_gui_custom_container,
      gt_fcat_0320        TYPE lvc_t_fcat,
      gs_layout_0320      TYPE lvc_s_layo,
      gt_appr_history     TYPE STANDARD TABLE OF ztwoappr.

" Screen 0330 — Email Send
DATA: gv_0330_initialized TYPE abap_bool,
      gr_alv_0330         TYPE REF TO cl_gui_alv_grid,
      gr_cont_0330        TYPE REF TO cl_gui_custom_container,
      gt_fcat_0330        TYPE lvc_t_fcat,
      gs_layout_0330      TYPE lvc_s_layo.
```

### ALV Field Catalog — Screen 0310 (Pending)

```abap
FORM build_fcat_0310.
  DATA ls_fcat TYPE lvc_s_fcat.
  CLEAR gt_fcat_0310.

  ls_fcat-fieldname = 'AUFNR'.   ls_fcat-coltext = 'Work Order'.
  ls_fcat-outputlen = 12.        APPEND ls_fcat TO gt_fcat_0310. CLEAR ls_fcat.

  ls_fcat-fieldname = 'WERKS'.   ls_fcat-coltext = 'Plant'.
  ls_fcat-outputlen = 6.         APPEND ls_fcat TO gt_fcat_0310. CLEAR ls_fcat.

  ls_fcat-fieldname = 'APPR_STATUS'. ls_fcat-coltext = 'Status'.
  ls_fcat-outputlen = 8.             APPEND ls_fcat TO gt_fcat_0310. CLEAR ls_fcat.

  ls_fcat-fieldname = 'LVL_STATUS'.  ls_fcat-coltext = 'Level'.
  ls_fcat-outputlen = 6.             APPEND ls_fcat TO gt_fcat_0310. CLEAR ls_fcat.

  ls_fcat-fieldname = 'L1_APPR_BY'. ls_fcat-coltext = 'L1 User'.
  ls_fcat-outputlen = 12.            APPEND ls_fcat TO gt_fcat_0310. CLEAR ls_fcat.

  ls_fcat-fieldname = 'L1_APPR_ON'. ls_fcat-coltext = 'L1 Date'.
  ls_fcat-outputlen = 10.            APPEND ls_fcat TO gt_fcat_0310. CLEAR ls_fcat.
ENDFORM.
```

### ALV Field Catalog — Screen 0330 (Email Send)

```abap
FORM build_fcat_0330.
  DATA ls_fcat TYPE lvc_s_fcat.
  CLEAR gt_fcat_0330.

  ls_fcat-fieldname = 'MARK'.          ls_fcat-coltext = 'Send'.
  ls_fcat-checkbox = abap_true.        ls_fcat-edit = abap_true.
  ls_fcat-outputlen = 5.               APPEND ls_fcat TO gt_fcat_0330. CLEAR ls_fcat.

  ls_fcat-fieldname = 'AUFNR'.         ls_fcat-coltext = 'Work Order'.
  ls_fcat-outputlen = 12.              APPEND ls_fcat TO gt_fcat_0330. CLEAR ls_fcat.

  ls_fcat-fieldname = 'MATNR'.         ls_fcat-coltext = 'Material'.
  ls_fcat-outputlen = 18.              APPEND ls_fcat TO gt_fcat_0330. CLEAR ls_fcat.

  ls_fcat-fieldname = 'MAKTX'.         ls_fcat-coltext = 'Description'.
  ls_fcat-outputlen = 30.              APPEND ls_fcat TO gt_fcat_0330. CLEAR ls_fcat.

  ls_fcat-fieldname = 'BDMNG'.         ls_fcat-coltext = 'WO Qty'.
  ls_fcat-outputlen = 10.              APPEND ls_fcat TO gt_fcat_0330. CLEAR ls_fcat.

  ls_fcat-fieldname = 'MENGE_TL'.      ls_fcat-coltext = 'TL Qty'.
  ls_fcat-outputlen = 10.              APPEND ls_fcat TO gt_fcat_0330. CLEAR ls_fcat.

  ls_fcat-fieldname = 'IS_MISMATCH'.   ls_fcat-coltext = 'Mismatch'.
  ls_fcat-outputlen = 8.               APPEND ls_fcat TO gt_fcat_0330. CLEAR ls_fcat.

  ls_fcat-fieldname = 'REASON_REJECT'. ls_fcat-coltext = 'Reason Rejection'.
  ls_fcat-outputlen = 40.              APPEND ls_fcat TO gt_fcat_0330. CLEAR ls_fcat.

  ls_fcat-fieldname = 'REASON_CHANGE'. ls_fcat-coltext = 'Reason Change'.
  ls_fcat-outputlen = 40.              APPEND ls_fcat TO gt_fcat_0330. CLEAR ls_fcat.

  ls_fcat-fieldname = 'WERKS'.         ls_fcat-coltext = 'Plant'.
  ls_fcat-outputlen = 6.               APPEND ls_fcat TO gt_fcat_0330. CLEAR ls_fcat.
ENDFORM.
```

---

## 4. Free Screen Objects Pattern (Re-entry)

> Based on `ABAP_Free_Screen_Objects_Skills.md` — **Pattern 1: Initialization Flag** (Recommended).

### The Problem

When a user goes: `0100 → 0310 → 0100 → 0310` again, the old `gr_alv_0310` and `gr_cont_0310` are still bound in memory. Creating new ones without freeing causes:
- Duplicate ALV grids stacked on screen
- Event handlers firing multiple times
- Memory leaks

### The Solution Applied to This Program

#### Rule: Clear the init flag when leaving a screen

In every PAI `WHEN '&BACK'` and `WHEN '&EXIT'`:
```abap
" Screen 0310 PAI
WHEN '&BACK'.
  CLEAR gv_0310_initialized.   " ← KEY: reset so PBO frees + rebuilds on next entry
  SET SCREEN 0100. LEAVE SCREEN.
```

#### Rule: PBO checks flag before creating objects

```abap
MODULE status_0310 OUTPUT.
  SET PF-STATUS 'ZSTAT_0310'.
  SET TITLEBAR 'T310'.

  IF gv_0310_initialized IS INITIAL.
    PERFORM free_alv_0310.       " free old objects if bound
    PERFORM init_alv_0310.       " create fresh container + ALV
    gv_0310_initialized = abap_true.
  ENDIF.

  IF gt_pending_wo IS NOT INITIAL AND gr_alv_0310 IS BOUND.
    gr_alv_0310->refresh_table_display( ).
  ENDIF.
ENDMODULE.
```

#### Free FORM pattern (from Skill)

```abap
FORM free_alv_0310.
  IF gr_alv_0310 IS BOUND.
    gr_alv_0310->free( ).
    CLEAR gr_alv_0310.
  ENDIF.
  IF gr_cont_0310 IS BOUND.
    gr_cont_0310->free( ).
    CLEAR gr_cont_0310.
  ENDIF.
  CLEAR: gt_fcat_0310, gs_layout_0310, gt_pending_wo.
ENDFORM.
```

#### Init FORM pattern

```abap
FORM init_alv_0310.
  PERFORM build_fcat_0310.

  gs_layout_0310-zebra      = abap_true.
  gs_layout_0310-cwidth_opt = abap_true.
  gs_layout_0310-no_toolbar = space.

  CREATE OBJECT gr_cont_0310
    EXPORTING container_name = 'CC_ALV_0310'.

  CREATE OBJECT gr_alv_0310
    EXPORTING i_parent = gr_cont_0310.

  " Attach double-click handler for opening WO in screen 0300
  SET HANDLER handle_dblclick_0310 FOR gr_alv_0310.

  PERFORM load_pending_wo_list.

  gr_alv_0310->set_table_for_first_display(
    EXPORTING
      is_layout       = gs_layout_0310
      i_default       = abap_true
      i_save          = 'A'
    CHANGING
      it_fieldcatalog = gt_fcat_0310
      it_outtab       = gt_pending_wo ).
ENDFORM.
```

### Screens 0320 and 0330 — Same Pattern

Apply the identical free/init pattern for:

| Screen | Flag | Free FORM | Init FORM | Container |
|---|---|---|---|---|
| 0310 | `gv_0310_initialized` | `free_alv_0310` | `init_alv_0310` | `CC_ALV_0310` |
| 0320 | `gv_0320_initialized` | `free_alv_0320` | `init_alv_0320` | `CC_ALV_0320` |
| 0330 | `gv_0330_initialized` | `free_alv_0330` | `init_alv_0330` | `CC_ALV_0330` |

All free/init FORMs live in **`ZFG_WO_APPROVALF07.abap`**.

---

## 5. Include File Map

| Include | Location | Contains |
|---|---|---|
| `ZFG_WO_APPROVALTOP` | `7. includes` | TYPES, DATA, CONSTANTS, CONTROLS |
| `ZFG_WO_APPROVALUXX` | `7. includes` | FM `ZFG_WO_APPROVAL_MAIN` entry |
| `ZFG_WO_APPROVALF01` | `7. includes` | Auth check, TVARVC reason load |
| `ZFG_WO_APPROVALF02` | `7. includes` | `save_as_l1`, `save_as_l3`, `unlock_wo` |
| `ZFG_WO_APPROVALF03` | `7. includes` | `load_wo_for_approval`, `compare_wo_vs_tasklist` |
| `ZFG_WO_APPROVALF04` | `7. includes` | `load_wo_range_for_approval`, `load_items_for_email` |
| `ZFG_WO_APPROVALF05` | `7. includes` | `process_send_email`, `get_email_from_dli` |
| `ZFG_WO_APPROVALF06` | `7. includes` | `build_email_html`, `send_email_bcs` |
| `ZFG_WO_APPROVALF07` | `7. includes` | ALV free/init for 0310, 0320, 0330 |
| `ZFG_WO_APPROVALО01` | PBO modules file | All PBO MODULE … OUTPUT blocks |
| `ZFG_WO_APPROVALІ01` | PAI modules file | All MODULE … INPUT blocks |

---

## 6. GUI Status Setup (SE41)

Call transaction **SE41**, enter the Function Group `ZFG_WO_APPROVAL`.

### ZSTAT_0100 — Main Menu

| Toolbar Area | Code | Text | F-Key |
|---|---|---|---|
| Application | `APPR` | Approval | F5 |
| Application | `PEND` | Pending | F6 |
| Application | `HIST` | History | F7 |
| Application | `MAIL` | Send Email | F8 |
| Standard (auto) | `&BACK` | Back | F3 |
| Standard (auto) | `&EXIT` | Exit | Shift+F3 |

### ZSTAT_0300 — Approval Screen

| Code | Text | F-Key |
|---|---|---|
| `EXEC` | Execute | F5 |
| `SAVE` | Save | Ctrl+S |
| `&BACK` | Back | F3 |

### ZSTAT_0310 — Pending List

| Code | Text | F-Key |
|---|---|---|
| `SELECT` | Open WO | F5 |
| `&BACK` | Back | F3 |

### ZSTAT_0320 — History (read-only, no app toolbar needed)

| Code | Text | F-Key |
|---|---|---|
| `&BACK` | Back | F3 |

### ZSTAT_0330 — Email Send

| Code | Text | F-Key |
|---|---|---|
| `LOAD` | Load Items | F5 |
| `SEND` | Send Email | F6 |
| `&BACK` | Back | F3 |

---

## 7. SBWP DLI Setup

Transaction: **SBWP** → Distribution Lists

Create one DLI per plant per email type:

| DLI Name | Recipients | Used for |
|---|---|---|
| `APPR_1000_HO` | BCSPPD HO team addresses | HO Notification email |
| `APPR_1000_BR` | Branch team addresses | Branch Notification email |
| `APPR_2000_HO` | Plant 2000 HO team | HO Notification |
| … | … | … |

- Set DLI as **Shared** so `SO_DLI_READ_API1` with `shared_dli = 'X'` finds it first.
- If shared not found, code falls back to personal DLI automatically.

---

## 8. Authorization Object Setup

Transaction: **SU21** — Create Authorization Object `ZWO_APPR`

| Field | Domain | Description |
|---|---|---|
| `ACTVT` | ACTVT | Activity (03=Display, 43=Approve) |
| `ZAPPR_LVL` | CHAR2 | Approval Level (L1 / L3 / AD) |
| `WERKS` | WERKS | Plant |

Assign to roles:
- **L1 role (BCSPPD):** `ACTVT=03,43` | `ZAPPR_LVL=L1` | `WERKS=<plant>`
- **L3 role (SDH HO):** `ACTVT=03,43` | `ZAPPR_LVL=L3` | `WERKS=<plant>`
- **Admin role:** `ACTVT=*` | `ZAPPR_LVL=AD` | `WERKS=*`

---

## 9. TVARVC Reason Code Setup

Transaction: **SE38** → run `RSTVARC` or go directly to **SM31 → TVARVC**.

### Reject Reasons (`ZWO_REJECT_REASON_xx`)

| Name | Low | Description |
|---|---|---|
| `ZWO_REJECT_REASON_01` | `R01Over-delivery quantity` | Qty exceeds task list |
| `ZWO_REJECT_REASON_02` | `R02Material substitution` | Different material used |
| `ZWO_REJECT_REASON_03` | `R03Unauthorized addition` | Item not in task list |

### Change Reasons (`ZWO_CHANGE_REASON_xx`)

| Name | Low | Description |
|---|---|---|
| `ZWO_CHANGE_REASON_01` | `C01Engineering change` | Approved design change |
| `ZWO_CHANGE_REASON_02` | `C02Supplier shortage` | Alternative sourcing |
| `ZWO_CHANGE_REASON_03` | `C03Site condition` | Field condition adjustment |

> The first 10 chars of `LOW` = `reason_code`, remaining chars = `reason_desc` (see `F01` load logic).

---

## 10. Testing Checklist

### Table Control (Screen 0300)
- [ ] Single WO load: enter From only → one WO loads
- [ ] Range load: From ≠ To → multiple WOs load in TC
- [ ] L1 login → only red (mismatch) rows visible
- [ ] L3 login → all rows visible
- [ ] Approve checkbox toggles for mismatch rows (L1 only)
- [ ] Reason dropdown shows reject reasons for unchecked, change reasons for checked
- [ ] Missing reason → error message on save
- [ ] Save L1 → `LVL_STATUS` becomes `1`
- [ ] Save L3 → `APPR_STATUS` becomes `2`, no auto email

### ALV Re-entry (Free Object Pattern)
- [ ] Navigate 0100 → 0310 → Back → 0310 again: **no duplicate ALV**
- [ ] Navigate 0100 → 0320 → Back → 0320 again: **no duplicate ALV**
- [ ] Navigate 0100 → 0330 → Back → 0330 again: **no duplicate ALV**
- [ ] Double-click row in 0310 → opens correct WO in 0300
- [ ] Re-enter 0330 after Load → previous data cleared, fresh load works

### Email (Screen 0330)
- [ ] Enter WO → Load → items appear in ALV with Reason columns
- [ ] Unmark some rows → only marked rows included in email
- [ ] Select HO → DLI `APPR_<WERKS>_HO` used
- [ ] Select BR → DLI `APPR_<WERKS>_BR` used
- [ ] Click Send without selecting type → error message shown
- [ ] Email received in SOST → check HTML table has Reason Rejection + Reason Change columns
- [ ] DLI not found → warning shown, continues to next plant

### Authorization
- [ ] L1 user cannot see/approve non-mismatch rows
- [ ] L3 user can approve all rows
- [ ] User with no `ZWO_APPR` auth → message and exit

---

## 11. Function Module Implementation Guide

This Function Group exposes **4 Function Modules** in `ZFG_WO_APPROVALUXX`. Each FM is a thin wrapper — all real logic lives in a backing `FORM` inside the appropriate F-include (Clean ABAP pattern).

### Design Rule: Thin FM — Fat FORM

```
FUNCTION ZFG_WO_xxx.          ← thin: parameter declaration + RAISING only
  PERFORM fm_xxx ...           ← delegates all logic to F-include FORM
ENDFUNCTION.

FORM fm_xxx ...                ← fat: real business logic here (in F01/F03/F05)
ENDFORM.
```

Benefits:
- FORMs are testable independently via `PERFORM` in any program
- FM interface stays clean — no business logic mixed with exception handling
- Easy to add new FMs without duplicating code

---

### Step-by-Step: Creating a Function Module in SE80

#### Step 1 — Open the Function Group

1. SE80 → select **Function Group** from dropdown
2. Enter `ZFG_WO_APPROVAL` → Enter
3. In the tree, right-click the Function Group → **Create → Function Module**

#### Step 2 — Define the FM Name and Attributes

| FM Name | Short Text |
|---|---|
| `ZFG_WO_APPROVAL_MAIN` | WO Approval — Start Main Screen |
| `ZFG_WO_CHECK_AUTH` | WO Approval — Check User Authorization |
| `ZFG_WO_GET_STATUS` | WO Approval — Get WO Approval Status |
| `ZFG_WO_SEND_EMAIL` | WO Approval — Send Notification Email |

For each FM, set:
- **Processing Type:** Normal Function Module
- **Release State:** Released (after testing)

#### Step 3 — Define Parameters in the FM Editor

Switch to the **Import / Export / Exception** tabs and enter:

**ZFG_WO_APPROVAL_MAIN** — no parameters, no exceptions.

**ZFG_WO_CHECK_AUTH:**

| Tab | Name | Type | Type Name |
|---|---|---|---|
| Export | `EV_USER_LEVEL` | TYPE | `CHAR2` |
| Exception | `NO_AUTHORIZATION` | — | — |

**ZFG_WO_GET_STATUS:**

| Tab | Name | Type | Type Name |
|---|---|---|---|
| Import | `IV_AUFNR` | TYPE | `AUFNR` |
| Export | `EV_APPR_STATUS` | TYPE | `CHAR1` |
| Export | `EV_LVL_STATUS` | TYPE | `CHAR1` |
| Export | `EV_FOUND` | TYPE | `ABAP_BOOL` |
| Exception | `NOT_FOUND` | — | — |

**ZFG_WO_SEND_EMAIL:**

| Tab | Name | Type | Type Name |
|---|---|---|---|
| Import | `IV_AUFNR` | TYPE | `AUFNR` |
| Import | `IV_EMAIL_TYPE` | TYPE | `CHAR2` |
| Exception | `SEND_FAILED` | — | — |
| Exception | `NO_RECIPIENTS` | — | — |

#### Step 4 — Implement the FM Body (Source Code tab)

Paste the **thin wrapper** body from `ZFG_WO_APPROVALUXX.abap`.
Each FM body is just 3–10 lines delegating to a backing FORM.

Example — `ZFG_WO_CHECK_AUTH`:

```abap
  PERFORM fm_check_auth
    CHANGING ev_user_level.
  IF ev_user_level IS INITIAL.
    MESSAGE e000(db) WITH 'No authorization for Work Order Approval (ZWO_APPR).'
                          'Contact your system administrator.'
      RAISING no_authorization.
  ENDIF.
```

Example — `ZFG_WO_SEND_EMAIL`:

```abap
  DATA: lv_rc TYPE sy-subrc.
  PERFORM fm_send_email
    USING    iv_aufnr iv_email_type
    CHANGING lv_rc.
  CASE lv_rc.
    WHEN 1.
      MESSAGE i000(db) WITH 'No items found for WO' iv_aufnr 'to send email.'
        RAISING no_recipients.
    WHEN 2.
      MESSAGE e000(db) WITH 'Email send failed for WO' iv_aufnr
                            '- check SOST for details.'
        RAISING send_failed.
  ENDCASE.
```

#### Step 5 — Verify Backing FORMs Exist in F-Includes

| FM | Backing FORM | Location |
|---|---|---|
| `ZFG_WO_APPROVAL_MAIN` | `fm_approval_main` | `ZFG_WO_APPROVALF01` |
| `ZFG_WO_CHECK_AUTH` | `fm_check_auth` | `ZFG_WO_APPROVALF01` |
| `ZFG_WO_GET_STATUS` | `fm_get_wo_status` | `ZFG_WO_APPROVALF03` |
| `ZFG_WO_SEND_EMAIL` | `fm_send_email` | `ZFG_WO_APPROVALF05` |

#### Step 6 — Activate

1. Save each FM body (Ctrl+S)
2. Activate individually or use **mass activation** (SE80 → Activate All)
3. Run syntax check — all green before proceeding

---

### Calling a Reusable FM from an Exit / BAdI

```abap
" Example: WO Release Exit — block release if not yet approved
DATA: lv_appr_status TYPE char1,
      lv_lvl_status  TYPE char1,
      lv_found       TYPE abap_bool.

CALL FUNCTION 'ZFG_WO_GET_STATUS'
  EXPORTING
    iv_aufnr       = caufvd_imp-aufnr
  IMPORTING
    ev_appr_status = lv_appr_status
    ev_lvl_status  = lv_lvl_status
    ev_found       = lv_found
  EXCEPTIONS
    not_found = 1
    OTHERS    = 2.

IF sy-subrc <> 0.
  MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
            WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  no_release = 'X'.
  RETURN.
ENDIF.

IF lv_found = abap_true AND lv_appr_status <> '2'.
  MESSAGE i000(db) WITH 'WO' caufvd_imp-aufnr
                        'is pending approval. Release blocked.'.
  no_release = 'X'.
ENDIF.
```

### Calling ZFG_WO_SEND_EMAIL from a Batch Report

```abap
CALL FUNCTION 'ZFG_WO_SEND_EMAIL'
  EXPORTING
    iv_aufnr      = lv_aufnr
    iv_email_type = 'HO'
  EXCEPTIONS
    send_failed   = 1
    no_recipients = 2
    OTHERS        = 3.

IF sy-subrc <> 0.
  MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
            WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
ENDIF.
```
