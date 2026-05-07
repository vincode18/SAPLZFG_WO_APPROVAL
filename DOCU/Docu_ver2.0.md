# Work Order Approval System - Documentation Version 2.5

## Overview

**Function Group**: ZFG_WO_APPROVAL  
**Version**: 2.5 (v1.7.3 Screen 0320/0330: inline 0001 exclusion in default_filter_0320; full re-entry reset — free ALV + clear s_w320/s_w330/s_a320/s_a330/gv_send_mode on BACK/EXIT)  
**Transaction**: ZWOAPP  
**Description**: Work Order Approval System for multi-level approval of service order components with task list comparison

The system provides a comprehensive approval workflow for Work Orders (WOs) with the following key capabilities:
- Multi-level authorization (L1/L3/L4/L5)
- Component comparison between WO (RESB) and Task List (STPO)
- Material interchange detection (ZINCHG)
- Email notifications with HTML formatting
- ALV-based list displays for pending approvals and history
- Manual email trigger functionality

---

## System Architecture

### Component Structure

```
ZFG_WO_APPROVAL (Function Group)
├── 1. Master Program
│   └── ZFG_WO_APPROVAL.abap
├── 2. PBO Modules (6 files)
│   ├── STATUS_0100.abap
│   ├── STATUS_0300.abap
│   ├── STATUS_0310.abap
│   ├── STATUS_0320.abap
│   ├── STATUS_0330.abap
│   └── TC_ITEMS_CHANGE_TC_ATTR.abap
├── 3. PAI Modules (6 files)
│   ├── TC_ITEMS_MODIFY.abap
│   ├── USER_COMMAND_0100.abap
│   ├── USER_COMMAND_0300.abap
│   ├── USER_COMMAND_0310.abap
│   ├── USER_COMMAND_0320.abap
│   └── USER_COMMAND_0330.abap
├── 4. Screens (10 files)
│   ├── 0100.abap (Main Menu)
│   ├── 0300.abap (Entry Screen - Host)
│   ├── 0301.abap (Subscreen - WO Range Input)
│   ├── 0310.abap (Pending Approval List - 3-Panel: Tree + Subscreen + ALV)
│   ├── 0311.abap (Subscreen - Plant/Werks Filter for Screen 0310)
│   ├── 0320.abap (Approval History - Read-Only ALV + SS_320 Filter)
│   ├── 0321.abap (NOT USED)
│   ├── 0322.abap (Subscreen - Plant/WO Range Filter for Screen 0320)
│   ├── 0330.abap (Manual Email Send - Selectable ALV + SS_330 Filter)
│   └── 0332.abap (Subscreen - Plant/WO Range Filter for Screen 0330)
├── 5. GUI Status (4 files)
│   ├── ZSTAT_0100.abap
│   ├── ZSTAT_0300.abap
│   ├── ZSTAT_0310.abap
│   └── ZSTAT_0320.abap
├── 6. GUI Title (4 files)
│   ├── T100.abap
│   ├── T300.abap
│   ├── T310.abap
│   └── T320.abap
├── 7. Includes (11 files)
│   ├── LZFG_WO_APPROVALTOP.abap (Global Data, Types, Constants, Tree Globals for Screen 0310)
│   ├── LZFG_WO_APPROVALF01.abap (Authorization & Init)
│   ├── ZFG_WO_APPROVALF02.abap (Save Logic - L1/L3)
│   ├── ZFG_WO_APPROVALF03.abap (Data Retrieval & Compare)
│   ├── ZFG_WO_APPROVALF04.abap (WO Range Load & Table Control)
│   ├── LZFG_WO_APPROVALF05.abap (Email Orchestration)
│   ├── LZFG_WO_APPROVALF06.abap (HTML Builder & BCS Sender — build_email_html, build_email_html_plant, send_email_bcs)
│   ├── LZFG_WO_APPROVALF07.abap (ALV Free/Init FORMs + Tree FORMs for Screen 0310)
│   ├── LZFG_WO_APPROVALO01.abap (PBO Modules)
│   ├── LZFG_WO_APPROVALI01.abap (PAI Modules)
│   └── ZFG_WO_APPROVALUXX.abap (Function Module Stubs)
├── 8. Function Modules (4 files)
│   ├── ZFM_WO_APPROVAL_MAIN.abap
│   ├── ZFM_WO_CHECK_AUTH.abap
│   ├── ZFM_WO_GET_STATUS.abap
│   └── ZFM_WO_SEND_EMAIL.abap
└── 9. Transactions (1 file)
    └── ZWOAPP.abap
```

---

## Screen Flow

### Navigation Diagram

```
Screen 0100 (Main Menu)
│
├── [APPR] → Screen 0300 (Entry - WO Approval)
│   │
│   ├── [EXEC] → Load WO Range → Display Table Control
│   │   │
│   │   ├── [APPR] → Approve Selected Items
│   │   │
│   │   ├── [SAVE] → Save Approval (L1/L3/L4/L5 logic)
│   │   │
│   │   └── [&BACK] → Return to 0100
│
├── [PEND] → Screen 0310 (Pending Approval List - 3-Panel)
│   │
│   ├── Tree left panel: Pending WO buckets (Monthly / Weekly)
│   │   └── Double-click tree node → ALV filters to selected WO/date range
│   ├── Top-right subscreen 0311: Plant/WO range filter + Execute button (v1.8)
│   │   ├── s_w310: Plant range (pre-filled from r_swerk)
│   │   ├── s_a310: Work Order range
│   │   └── [EXEC_310] → Rebuild tree + reload ALV with range filters
│   ├── Double-click ALV row / [&SELECT] → Open WO in Screen 0300
│   └── [&BACK] → Return to 0100
│
├── [HIST] → Screen 0320 (Approval History - Read-Only ALV)
│   │
│   ├── Subscreen 0322: Plant / WO Range Filter
│   │   └── [FILTER] → Reload ALV with plant/WO ranges (s_w320, s_a320)
│   │   └── Plant default: Pre-filled from r_swerk (user's authorized plants)
│   │
│   └── [&BACK] → Return to 0100
│
├── [MAIL] → Screen 0330 (Manual Email Send - Selectable ALV)
│   │
│   ├── Subscreen 0332: Plant / WO Range Filter
│   │   └── [FILTER] → Reload "Approval Ready" ALV with ranges (s_w330, s_a330)
│   │   └── Plant default: Pre-filled from r_swerk
│   │
│   ├── [LOAD] → Load "Approval Ready" WOs (submitted/approved headers)
│   │   └── Shows: Total/Approved/Rejected/Pending component counts per WO
│   │
│   ├── [SALL] / [DSEL] → Select/Deselect all rows (v1.7.2: flush pending edits first)
│   │
│   ├── [SEND] → Send Email (grouped by plant)
│   │   └── v1.7.2: Auth guard — only L1 or L4 may send
│   │   └── L1 (HO) → Send to Branch (BR mode): build_email_html_plant — "Dear Tim Cabang"
│   │   └── L4 (Branch) → Send to HO (HO mode): build_email_html — "Dear BCSPPD HO Team"
│   │   └── L3 (SDH) → Blocked: error message
│   │   └── L5 (Helpdesk) → Blocked: error message
│   │   └── One email per plant (APPR_<WERKS>_HO or APPR_<WERKS>_BR DLI)
│   │
│   └── [&BACK] → Return to 0100
│
└── [&EXIT] / [&BACK] / [&CANCEL] → Leave Program
```

---

## Authorization Levels

### User Level Hierarchy

| Level | Description | Authorization Object | Key Capabilities |
|-------|-------------|---------------------|------------------|
| **L5** | Helpdesk | ZWO_APPR (APPR_LEVEL='L5') | Full approval, both reason fields, final approval |
| **L3** | SDH HO | ZWO_APPR (APPR_LEVEL='L3') | Full approval, both reason fields, final approval |
| **L4** | Branch | ZWO_APPR (APPR_LEVEL='L4') | Approval with REASON_CHANGE only, REASON_REJECT locked |
| **L1** | BCSPPD HO | ZWO_APPR (APPR_LEVEL='L1') | Approval with REASON_REJECT only, REASON_CHANGE locked, mismatch-only view |

### Authorization Check Flow

```
check_authorization (FORM in F01)
│
├── Check L5 (HELPDESK) → Highest priority
├── Check L3 (SDH HO)
├── Check L4 (Branch)
├── Check L1 (BCSPPD)
└── If none → Raise error message
```

### Field Access Control by User Level

| Field | L1 | L3 | L4 | L5 |
|-------|----|----|----|----|
| APPR_FLAG | Mismatch only | All | All | All |
| REASON_REJECT | Editable | Editable | Hidden | Editable |
| REASON_CHANGE | Hidden | Editable | Editable | Editable |
| Comparison Data | Read-only | Read-only | Read-only | Read-only |

---

## Key Business Flows

### 1. WO Approval Entry Flow

**Screen**: 0300 (Entry Screen)  
**Trigger**: User enters WO range and clicks EXEC

```
USER_COMMAND_0300 → &EXEC
│
├→ load_wo_range_for_approval (FORM in F04)
│   │
│   ├→ Validate s_aufnr is not initial
│   │
│   ├→ Pre-filter: Exclude already approved WOs from ZTWOAPPRH
│   │
│   ├→ fetch_component_data (FORM in F03)
│   │   ├→ SELECT RESB × VIAUFKS for s_aufnr range
│   │   ├→ Filter: autyp='30' (Service Order), xloek=space (not deleted)
│   │   └→ fetch_component_descriptions (MAKT enrichment)
│   │
│   ├→ fetch_tasklist_data_bulk (FORM in F03)
│   │   ├→ SELECT PLMZ × STPO for all tasklists
│   │   ├→ Filter: lkenz<>'X' (not deleted)
│   │   └→ fetch_tasklist_descriptions (MAKT enrichment)
│   │
│   ├→ build_comparison_items (FORM in F03)
│   │   ├→ Binary search match: (plnnr, plnal, idnrk=matnr)
│   │   ├→ Set comp_status, comp_match, is_mismatch
│   │   ├→ check_material_interchange (ZINCHG lookup)
│   │   └→ Restore saved approval data from ZTWOAPPR
│   │
│   ├→ Lock all WOs in scope (CO_ZF_ORDER_LOCK_MULTI)
│   │
│   └→ L1 Filter: Delete non-mismatch rows for L1 users
│
└→ Display in TC_ITEMS (Table Control)
```

### 2. Save Approval Flow

**Screen**: 0300  
**Trigger**: User clicks SAVE button

```
USER_COMMAND_0300 → &SAVE
│
├→ save_approval (FORM in F02)
│   │
│   ├→ Ensure gv_user_level is set
│   │
│   ├→ CASE gv_user_level
│   │   │
│   │   ├→ WHEN 'L1' → save_as_l1
│   │   │   ├→ Validate: reason_reject mandatory on mismatches
│   │   │   ├→ Validate: reason_change must be empty
│   │   │   ├→ Lock WO object (CO_ZF_ORDER_LOCK_MULTI)
│   │   │   ├→ UPDATE ZTWOAPPR (approval_lvl1, reason_reject)
│   │   │   ├→ UPDATE ZTWOAPPRH (changed_by, changed_date)
│   │   │   └→ Message: "L1 approval saved. Pending L3 review."
│   │   │
│   │   ├→ WHEN 'L4' → save_as_l4
│   │   │   ├→ Validate: All items must have appr_flag
│   │   │   ├→ Validate: reason_change mandatory
│   │   │   ├→ Validate: reason_reject not permitted
│   │   │   ├→ Lock WO object
│   │   │   ├→ UPDATE ZTWOAPPR (approval_lvl3, reason_change)
│   │   │   ├→ UPDATE ZTWOAPPRH (appr_status='2'=Approved)
│   │   │   └→ Message: "Use Send Email (0330) to notify recipients."
│   │   │
│   │   └→ WHEN 'L3' OR 'L5' → save_as_l5
│   │       ├→ Validate: All items must have appr_flag
│   │       ├→ Lock WO object
│   │       ├→ UPDATE ZTWOAPPR (approval_lvl3, both reason fields)
│   │       ├→ UPDATE ZTWOAPPRH (appr_status='2'=Approved)
│   │       └→ Message: "Use Send Email (0330) to notify recipients."
│   │
│   └→ COMMIT WORK AND WAIT
│       └→ unlock_wo_object (CO_ZF_ORDER_DELOCK)
```

### 3. Item-Level Approval Flow

**Screen**: 0300  
**Trigger**: User clicks APPROVE button

```
USER_COMMAND_0300 → &APPR
│
├→ approve_selected_items (FORM in F02)
│   │
│   ├→ Check: At least one item marked
│   │
│   ├→ Analyze selected items
│   │   ├→ Check for mismatches (is_mismatch = abap_true)
│   │   └─ Check for empty tasklists (pn_tasklist IS INITIAL)
│   │
│   ├→ Validation based on item types
│   │   ├→ IF has_mismatch → Require L1 level
│   │   │   └→ Validate reason_change is filled
│   │   └─ IF has_empty_tl (no mismatch) → Require L3 or L5
│   │
│   ├→ Lock WO object
│   │
│   ├→ UPDATE selected items
│   │   ├→ Mismatch + L1 → UPDATE approval_lvl1
│   │   └─ Others → UPDATE approval_lvl3
│   │
│   ├→ Update header if all approved
│   │   └─ SET appr_status='2'
│   │
│   └→ COMMIT WORK, unlock, success message
```

### 4. Email Notification Flow (4-Layer Architecture)

**Screen**: 0330 (Manual Email Send)  
**Trigger**: User clicks SEND button

```
USER_COMMAND_0330 → SEND
│
├→ v1.7.2: Auth guard — reject if gv_user_level is not L1 or L4
├→ v1.7.2: gr_alv_0330->check_changed_data( ) — flush in-flight edits
│
├→ process_send_email_grouped (FORM in F05) - LAYER 1: Orchestrator
│   │
│   ├→ Sanity: any marked rows in gt_appr_ready?
│   │
│   ├→ Group by WERKS (plant)
│   │
│   ├→ LOOP AT lt_groups
│   │   │
│   │   ├→ Materialize gt_selected via load_items_for_email per WO
│   │   │
│   │   ├→ Build DLI name: APPR_<WERKS>_<HO|BR>
│   │   │
│   │   ├→ get_email_from_dli (FORM in F05) - LAYER 2: DLI Reader
│   │   │   ├→ Try Shared DLI first (SO_DLI_READ_API1)
│   │   │   ├→ Fallback to Personal DLI
│   │   │   └→ Fill gt_recipients table
│   │   │
│   │   ├→ v1.7.2: Template dispatch - LAYER 3: HTML Builder
│   │   │   ├→ IF pv_email_type = 'BR' (L1→Branch)
│   │   │   │   └→ build_email_html_plant (FORM in F06)
│   │   │   │       ├→ FIRST: green header (#009933), gold TH (#FFD700)
│   │   │   │       │         "Dear Tim Cabang", Indonesian body text
│   │   │   │       ├→ BODY: No, WO, Plant, Material, Desc, WO Qty, TL Qty,
│   │   │   │       │        Status, Reason Rejection, Reason Change
│   │   │   │       └─ LAST: Indonesian footer, "BCSPPD HO Team"
│   │   │   └→ ELSE (L4→HO mode)
│   │   │       └→ build_email_html (FORM in F06)
│   │   │           ├→ FIRST: blue header (#003399), "Dear BCSPPD HO Team"
│   │   │           ├→ BODY: No, WO, Material, Desc, WO Qty, TL Qty,
│   │   │           │        Status, Reason Rejection, Reason Change
│   │   │           └─ LAST: Action = review in ZWOAPP
│   │   │
│   │   └→ send_email_bcs (FORM in F06) - LAYER 4: BCS Sender
│   │       ├→ Create CL_BCS persistent object
│   │       ├→ Create HTML document (CL_DOCUMENT_BCS)
│   │       ├→ Set sender: mail_sap@unitedtractors.com
│   │       ├→ Add recipients from gt_recipients
│   │       ├→ Set send immediately
│   │       ├→ Send email
│   │       └─ COMMIT WORK
│   │
│   └→ Display success/skip message
```

### 5. Pending Approval List Flow

**Screen**: 0310 (3-Panel: Tree + Subscreen + ALV)  
**Trigger**: User navigates from main menu

```
STATUS_0310 (PBO)
│
├→ default_filter_0310 (v1.8 — pre-fill s_w310 from r_swerk if empty)
│
├→ Lazy-init pattern
│   │
│   ├→ IF gv_0310_initialized IS INITIAL
│   │   │
│   │   ├→ free_alv_0310 + free_tree_0310
│   │   │
│   │   ├→ init_alv_0310 (CC_ALV_0310 — right-bottom panel)
│   │   │   ├→ build_fcat_0310
│   │   │   ├→ load_pending_wo_list (v1.8 — filter by s_w310, s_a310, r_swerk)
│   │   │   │   ├→ IF L1 → SELECT appr_status='1' (Submitted)
│   │   │   │   └─ IF L3/L4/L5 → SELECT appr_status<>'2' (Not approved)
│   │   │   ├→ Create CC_ALV_0310 container + ALV grid
│   │   │   ├→ Register double-click event handler (lcl_alv_event_0310)
│   │   │   └─ set_table_for_first_display → gt_pending_wo
│   │   │
│   │   ├→ init_tree_0310 (CC_TREE_0310 — left full-height panel)
│   │   │   ├→ load_pending_tree_0310 (v1.8 — filter by s_w310, s_a310, r_swerk)
│   │   │   │   └─ ZTWOAPPRH: APPR_STATUS='1', REQUESTED_DATE >= TODAY-7
│   │   │   ├→ CREATE gr_tree_cont_0310 + gr_tree_0310
│   │   │   ├→ Register events: node_double_click, item_double_click (APPL_EVENT='X')
│   │   │   ├→ SET HANDLER → go_tree_evt_0310
│   │   │   └─ add_nodes_and_items: Root > Monthly > M_leaves, Root > Weekly > W_leaves
│   │   │
│   │   └→ gv_0310_initialized = abap_true, gv_0310_tree_initialized = abap_true
│   │
│   └→ ELSE → gr_alv_0310->refresh_table_display
│
├→ CALL SUBSCREEN ss_0310 INCLUDING sy-repid '0311' (v1.8 — range filter)
│   └─ Subscreen 0311: s_w310 (Plant range), s_a310 (WO range)
│
├→ Tree double-click → CL_GUI_CFW=>DISPATCH → handle_node/item_dblclick_0310
│   └─ filter_alv_0310_by_tree → update gt_pending_wo → refresh_table_display
│
├→ ALV double-click → handle_dblclick_0310 → open_selected_wo_from_pending
│   └─ SET SCREEN 0300
│
├→ USER_COMMAND_0310 → EXEC_310
│   ├→ rebuild_tree_0310 (free + reinit tree with s_w310/s_a310 filters)
│   ├→ load_pending_wo_list (v1.8 — apply range filters)
│   └─ gr_alv_0310->refresh_table_display
│
└→ USER_COMMAND_0310 → &BACK
    ├→ CLEAR gv_0310_initialized, gv_0310_tree_initialized
    ├→ free_tree_0310
    └─ SET SCREEN 0100
```

### 6. Approval History Flow

**Screen**: 0320 (Read-Only ALV)  
**Trigger**: User navigates from main menu

```
STATUS_0320 (PBO)
│
├→ Lazy-init pattern
│   ├→ IF gv_0320_initialized IS INITIAL
│   │   ├→ free_alv_0320
│   │   ├→ init_alv_0320 (CC_ALV_0320)
│   │   │   ├→ build_fcat_0320
│   │   │   ├→ load_appr_history (SELECT * FROM ZTWOAPPR)
│   │   │   └─ set_table_for_first_display → gt_appr_history
│   │   └→ gv_0320_initialized = abap_true
│   └→ ELSE → gr_alv_0320->refresh_table_display
│
└→ USER_COMMAND_0320 → &BACK
    ├→ CLEAR gv_0320_initialized
    └─ SET SCREEN 0100
```

### 7. Bulk Comparison Pipeline

**Ported from Report**: ZR_SVC_WO_APPROVAL_v8.5  
**Location**: ZFG_WO_APPROVALF03

```
build_comparison_items (FORM)
│
├→ Input: gt_comp (RESB × VIAUFKS), gt_tasklist (PLMZ × STPO)
│
├→ Pre-load ZTWOAPPR detail rows for all WOs
│
├→ LOOP AT gt_comp
│   │
│   ├→ Build ty_items_tc row from WO data
│   │   └─ aufnr, plnnr, plnal, matnr, maktx, werks, bdmng, meins
│   │
│   ├→ Binary search in gt_tasklist
│   │   └─ KEY: plnnr, plnal, idnrk=matnr
│   │
│   ├→ IF match found
│   │   ├→ Set comp_status='X', comp_match='Yes'
│   │   ├→ Populate TL data: pn_tasklist, desc_tasklist, menge_tl
│   │   └─ is_mismatch = abap_false
│   │
│   └─ ELSE (no match OR no tasklist)
│       ├→ Set comp_status=space, comp_match='No'
│       └─ is_mismatch = abap_true
│
├→ check_material_interchange
│   └─ SELECT from ZINCHG WHERE matwa=matnr AND incode IN ('018','016')
│       ├→ IF found → interchange='Yes', interchange_pn=smatn
│       └─ ELSE → interchange='No'
│
├→ Restore saved approval from ZTWOAPPR
│   └─ READ TABLE lt_appr WITH KEY aufnr, matnr
│       └─ Set: appr_flag, reason_reject, reason_change
│
└→ APPEND to gt_items_tc
```

---

## Data Structures

### Global Types (LZFG_WO_APPROVALTOP)

#### ty_items_tc - Table Control Item Type
```
- aufnr          : AUFNR (Work Order)
- plnnr          : PLNNR (Tasklist Number)
- plnal          : PLNAL (Group Counter)
- matnr          : MATNR (WO Part Number)
- maktx          : MAKTX (WO Description)
- werks          : WERKS_D (Plant)
- bdmng          : BDMNG (WO Required Qty)
- meins          : MEINS (UoM)
- pn_tasklist    : MATNR (TL Part Number)
- desc_tasklist  : MAKTX (TL Description)
- menge_tl       : MENGE_D (Task List Qty)
- meins_tl       : MEINS (TL UoM)
- comp_status    : CHAR1 ('X'=match, ' '=mismatch)
- comp_match     : CHAR3 ('Yes'/'No')
- interchange    : CHAR3 ('Yes'/'No')
- interchange_pn : MATNR (Interchanged PN)
- is_mismatch    : ABAP_BOOL (Drives row color)
- appr_flag      : CHAR1 (X=Approved)
- mark           : CHAR1 (Checkbox)
- reason_code    : CHAR10
- reason_reject  : CHAR40
- reason_change  : CHAR40
- row_color      : LVC_T_SCOL
```

#### ty_comp - Component Data (Bulk Fetch)
```
- aufnr, rsnum, rspos, matnr, maktx, bdmng, meins
- plnnr, plnty, plnal, werks
```

#### ty_tasklist - Tasklist Data (Bulk Fetch)
```
- plnnr, plnal, stlnr, stlkn, idnrk, menge, maktx
```

### Global Variables

```
gv_aufnr           : Current Work Order
gv_aufnr_from      : Range start
gv_aufnr_to        : Range end
gv_werks           : Current plant
gv_user_level      : User auth level (L1/L3/L4/L5)
gv_locked          : Lock status flag

gt_items_tc        : Table control data (ty_items_tc)
gt_comp            : Bulk component data
gt_tasklist        : Bulk tasklist data
gt_selected        : Marked items for email
gt_recipients      : Email recipients
gt_reject_reasons  : TVARVC reject reasons
gt_change_reasons  : TVARVC change reasons

--- v2.0 Tree additions (Screen 0310) ---
gv_0310_tree_initialized : Tree init flag (abap_bool)
gr_tree_0310             : CL_GUI_LIST_TREE instance
gr_tree_cont_0310        : CL_GUI_CUSTOM_CONTAINER for tree
go_tree_evt_0310         : lcl_tree_event_0310 event handler
gv_tree_selected_key     : Currently selected tree node (tv_nodekey)
gt_pending_tree          : ZTWOAPPRH rows loaded for tree (APPR_STATUS='1')

--- v1.8 Subscreen 0311 range filters (Screen 0310) ---
s_w310                   : SELECT-OPTIONS range for Plant (WERKS)
s_a310                   : SELECT-OPTIONS range for Work Order (AUFNR)
```

### Constants

```
gc_user_lvl:
  - l1 = 'L1' (BCSPPD HO)
  - l3 = 'L3' (SDH)
  - l4 = 'L4' (BRANCH)
  - l5 = 'L5' (Helpdesk)

gc_appr_status:
  - draft = '0'
  - submitted = '1'
  - approved = '2'

gc_tree_0310 (v2.0 — tree node keys for Screen 0310):
  - root    = 'PEND_ROOT'
  - monthly = 'MONTHLY'
  - weekly  = 'WEEKLY'
```

---

## Function Modules

### ZFM_WO_APPROVAL_MAIN
**Purpose**: Entry point called by transaction ZWOAPP  
**Parameters**: None  
**Flow**: 
1. Perform authorization check
2. Call Screen 0100

### ZFM_WO_CHECK_AUTH
**Purpose**: Reusable authorization check for external callers  
**Parameters**:
- EXPORTING: ev_user_level (CHAR2)
- EXCEPTIONS: no_authorization  
**Flow**: Calls fm_check_auth, raises exception if no auth found  
**Callers**: Exit programs, BAdI implementations, other reports

### ZFM_WO_GET_STATUS
**Purpose**: Query WO approval status  
**Parameters**:
- IMPORTING: iv_aufnr (AUFNR)
- EXPORTING: ev_appr_status (CHAR1), ev_lvl_status (CHAR1), ev_found (ABAP_BOOL)
- EXCEPTIONS: not_found  
**Flow**: Reads ZTWOAPPRH, returns status codes  
**Callers**: WO Release exits, status check programs

### ZFM_WO_SEND_EMAIL
**Purpose**: Reusable email trigger for approval notifications  
**Parameters**:
- IMPORTING: iv_aufnr (AUFNR), iv_email_type (CHAR2 - 'HO'/'BR')
- EXCEPTIONS: send_failed, no_recipients  
**Flow**: 
1. Load items for WO
2. Mark all rows
3. Call process_send_email (4-layer architecture)  
**Callers**: Screen 0330, batch programs, resend utilities

---

## Database Tables

### ZTWOAPPRH - Approval Header
**Key Fields**:
- aufnr (Work Order - Primary Key)
- werks (Plant)
- appr_status (0=Draft, 1=Submitted, 2=Approved)
- approved_by, approved_date, approved_time
- changed_by, changed_date, changed_time

### ZTWOAPPR - Approval Detail
**Key Fields**:
- aufnr, matnr (Composite Key)
- approval_lvl1, approval_lvl2, approval_lvl3
- reason_reject, reason_change
- appr_by_lvl1, appr_date_lvl1, appr_time_lvl1
- change_id, approval_stat

### ZINCHG - Material Interchange
**Key Fields**:
- matwa (Material from)
- smatn (Material to)
- incode ('018'/'016' for interchange codes)

---

## ALV Initialization Pattern (v1.5)

All ALV screens (0310, 0320, 0330) follow the **Lazy-Init Pattern**:

```
PBO Module
│
├→ IF gv_0XXX_initialized IS INITIAL
│   │
│   ├→ free_alv_0XXX
│   │   ├→ Free ALV grid if bound
│   │   ├→ Free container if bound
│   │   └─ Clear field catalog, layout, data
│   │
│   ├→ init_alv_0XXX
│   │   ├→ Build field catalog
│   │   ├→ Load data from DB
│   │   ├→ Create container
│   │   ├→ Create ALV grid
│   │   ├→ Register event handlers (if needed)
│   │   └─ set_table_for_first_display
│   │
│   └→ gv_0XXX_initialized = abap_true
│
└→ ELSE
    └→ refresh_table_display
```

**Cleanup on Exit**:
- PAI module &BACK/&EXIT/&CANC clears gv_0XXX_initialized
- Ensures clean rebuild on next screen entry

---

## Key Changes in Version 1.5

1. **L1 Filter**: L1 users now see ONLY mismatch rows in Screen 0300
2. **Email Columns**: Added Reason Rejection and Reason Change to email HTML table
3. **Auto Email Removed**: No automatic email trigger after save - user must use Screen 0330
4. **WO Range Load**: New bulk pipeline for loading WO ranges (ported from report v8.5)
5. **Lazy-Init ALV**: All ALV screens use initialization flag pattern for clean rebuilds

---

## Key Changes in Version 2.0

1. **Screen 0310 — 3-Panel Layout**: Screen 0310 (Pending Approval List) now has three panels:
   - **Left panel** `CC_TREE_0310`: `CL_GUI_LIST_TREE` showing Pending Approval WOs grouped by Monthly and Weekly date buckets
   - **Top-right panel** `SS_310`: Subscreen `0312` with Plant (`s_w310`) and WO (`s_a310`) filter fields + Execute button
   - **Bottom-right panel** `CC_ALV_0310`: Existing pending WO ALV (resized to share right column)
2. **Tree Filter Navigation**: Double-clicking a tree node filters the ALV to WOs matching that node (Root = all, Monthly/Weekly folder = date range, leaf = single WO)
3. **Plant/WO Filter**: Pressing Execute in subscreen 0312 rebuilds the tree with an optional plant or WO filter applied to the ZTWOAPPRH query
4. **Screen 0312 Created**: New subscreen (replaces 0311) hosting `s_w310`/`s_a310` filter fields
5. **CL_GUI_CFW=>DISPATCH**: Added as first statement in `USER_COMMAND_0310` PAI module to route tree application events to ABAP handler methods
6. **Tree Lifecycle**: `free_tree_0310` / `init_tree_0310` / `rebuild_tree_0310` FORMs added to `LZFG_WO_APPROVALF07`
7. **New Globals**: Tree objects, subscreen input fields, node key constants added to `LZFG_WO_APPROVALTOP`

---

## Key Changes in Version 1.8.2

### Enhancement: Open WO from Pending List → Screen 0300 with Auto-Load

Clicking **"Open WO"** on Screen 0310 now navigates directly to Screen 0300 with the selected Work Order's comparison data pre-loaded in the Table Control.

### Navigation Flow

1. User selects a row in the ALV grid on Screen 0310 (or double-clicks it)
2. `USER_COMMAND_0310` catches ok-code `&SELECT` / `&IC1` (or the ALV double-click event) → calls `PERFORM open_selected_wo_from_pending`
3. `open_selected_wo_from_pending` resolves the AUFNR:
   - **Double-click path**: `gv_aufnr` already set by `handle_dblclick_0310` — used directly
   - **Button path**: calls `gr_alv_0310->get_selected_rows()` to read the highlighted row from `gt_pending_wo`
4. AUFNR is zero-padded via `CONVERSION_EXIT_ALPHA_INPUT`, stored in `s_aufnr`
5. `gv_open_from_pending = abap_true` and `CLEAR gv_0300_initialized` are set before `SET SCREEN 0300`
6. Screen 0300 PBO (`STATUS_0300`) detects `gv_open_from_pending`, clears it, and calls `PERFORM load_wo_range_for_approval` — table control fills automatically
7. User sees the component vs. tasklist comparison for the selected WO immediately, ready to approve/reject

### Files Changed

| File | Change |
| ---- | ------ |
| `LZFG_WO_APPROVALTOP` | Added `gv_open_from_pending TYPE abap_bool` global flag |
| `LZFG_WO_APPROVALF03` — `open_selected_wo_from_pending` | Rewrote: reads `gr_alv_0310->get_selected_rows()` for button path; `gv_aufnr` priority for double-click path; sets `gv_open_from_pending` before navigation |
| `LZFG_WO_APPROVALF07` — `handle_dblclick_0310` | Simplified: sets `gv_aufnr` then delegates to `open_selected_wo_from_pending` |
| `STATUS_0300` | Added auto-load block: if `gv_open_from_pending` then clear flag + `PERFORM load_wo_range_for_approval` |
| `USER_COMMAND_0300` | `CLEAR gv_open_from_pending` added to `&BACK` and `&EXIT`/`&CANC` handlers |

---

## Key Changes in Version 1.8.1

**Enhancement: Tree Node Key Counter Pattern** — fixes `add_nodes_and_items` crash when the same AUFNR appears in both Monthly and Weekly folders.

### Problem

`cl_gui_list_tree` requires every `node_key` to be globally unique. A WO requested within the current month but also within the last 7 days falls into **both** folders. Using AUFNR directly as the node_key caused a duplicate key error and the tree failed to render.

### Solution

- **Running counter** (`lv_counter TYPE i`) increments globally across both the monthly and weekly loops — never resets, so weekly keys never collide with monthly ones.
- Keys generated as `N000000001`, `N000000002`, … (`'N'` prefix + 9-digit zero-padded counter).
- **Lookup table** `gt_tree_keys` (`TYPE ty_tree_key OCCURS 0`) maps each generated `node_key → aufnr`. On leaf double-click, the handler reads this table to recover the AUFNR.

### Modified Files

| File | Change |
| ---- | ------ |
| `LZFG_WO_APPROVALTOP` | Replaced `gt_node OCCURS 0 WITH HEADER LINE` with `ty_tree_key` type + `gt_tree_keys`/`ls_tree_key` (no header line) |
| `LZFG_WO_APPROVALF07` — `build_tree_nodes_0310` | Added `lv_counter`/`lv_counter_c` DATA; `CLEAR gt_tree_keys` at start; counter-based `CONCATENATE 'N' lv_counter_c INTO lv_node_key`; `APPEND ls_tree_key TO gt_tree_keys` per leaf in both loops |
| `LZFG_WO_APPROVALF07` — `filter_alv_0310_by_tree` | `WHEN OTHERS`: `READ TABLE gt_tree_keys INTO ls_tree_key WITH KEY node_key = gv_tree_selected_key` with `sy-subrc <> 0 → RETURN` guard |
| `LZFG_WO_APPROVALF07` — `free_tree_0310` | Added `gt_tree_keys` to `CLEAR:` chain |

---

## Key Changes in Version 1.7.3

1. **`default_filter_0320` — Inline 0001 exclusion**: replaced post-loop `E EQ 0001` append with `CHECK ls_r-low <> '0001'` inside the loop. Plant `0001` no longer appears in `s_w320` at all (not even with an exclusion sign).
2. **Screen 0320 re-entry reset** (`USER_COMMAND_0320`): `&BACK`, `&EXIT`, `&CANCEL` now call `PERFORM free_alv_0320` and `CLEAR s_w320[] s_a320[]` before leaving. On re-entry `default_filter_0320` re-runs correctly with fresh `r_swerk` pre-fill.
3. **Screen 0330 re-entry reset** (`USER_COMMAND_0330`): `&BACK`, `&EXIT`, `&CANC` now call `PERFORM free_alv_0330` and `CLEAR s_w330[] s_a330[] gv_send_mode` before leaving. Clears `gv_send_mode` so `resolve_send_mode` re-runs on next entry.
4. **Root cause of 0330 stale filter** (from debugger): `s_w330[] IS NOT INITIAL` guard in `default_filter_0330` caused immediate `RETURN` on re-entry — the old plant range persisted. Fix is in the exit handlers, not the `CHECK` logic (which was already correct from v1.7.2).
5. **Version comments**: `STATUS_0320` and `STATUS_0330` header comments bumped to `v1.7.3`.

---

## Key Changes in Version 1.7.2

1. **Plant Pre-fill Excludes `0001`**: `default_filter_0330` now skips `r_swerk` entries where `low = '0001'`, preventing the HO admin plant from appearing in the default filter on Screen 0330.
2. **Display-Only ALV Grid**: `init_alv_0330` sets `gs_layout_0330-edit = abap_false`. Only the `MARK` (Send) column retains `edit = abap_true` via field catalog. All other columns have `edit = abap_false` explicitly set in `build_fcat_0330`.
3. **SALL/DSEL Flush Before Mark**: `USER_COMMAND_0330` calls `gr_alv_0330->check_changed_data()` before the SALL and DSEL loops, ensuring in-flight checkbox edits are committed before bulk-marking overrides them.
4. **SEND Authorization Guard**: Only `L1` (Head Office) and `L4` (Branch) users may send. `L3` and `L5` receive a hard error message and `RETURN` immediately. The old `gv_send_mode IS INITIAL` check is retained as a secondary operational guard.
5. **Correct HTML Template Dispatch**: `process_send_email_grouped` now routes to the correct builder:
   - `pv_email_type = 'BR'` → `build_email_html_plant` (L1→Branch, green theme, Indonesian text)
   - `pv_email_type = 'HO'` → `build_email_html` (L4→HO, blue theme, English text)
6. **New `FORM build_email_html_plant`** added to `LZFG_WO_APPROVALF06`: adapted from `ZR_SVC_WO_APPROVAL_v8.5`, using `ty_items_tc` fields. Green heading (`#009933`), gold table header (`#FFD700`), Indonesian greeting and footer, signed off as *BCSPPD HO Team*.
7. **PBO Guard in `STATUS_0330`**: Added `check_authorization` / `build_plant_range` guards before the init block, matching the pattern used in Screen 0310 (v1.7.1).

### Authorization Matrix — Screen 0330 (v1.7.2)

| Role | Plant Pre-fill | Can Send | Send Direction | HTML Template |
|------|----------------|----------|----------------|---------------|
| L1 — Head Office (BCSPPD) | All auth plants excl. 0001 | ✅ | HO → Branch (`BR`) | `build_email_html_plant` |
| L3 — SDH | Own plant(s) excl. 0001 | ❌ Error | — | — |
| L4 — Branch | Own plant excl. 0001 | ✅ | Branch → HO (`HO`) | `build_email_html` |
| L5 — Helpdesk | All auth plants excl. 0001 | ❌ Error | — | — |

---

## Transaction Configuration

**Transaction Code**: ZWOAPP  
**Type**: Function Module Transaction  
**Program**: ZFM_WO_APPROVAL_MAIN  
**Authorization Object**: ZWO_APPR (APPR_LEVEL, ACTVT, WERKS)

---

## Error Handling

### Lock Conflicts
- WO locked by another user → Error message with retry instruction
- Lock via CO_ZF_ORDER_LOCK_MULTI (exclusive mode)
- Unlock via CO_ZF_ORDER_DELOCK after COMMIT

### Authorization Errors
- No ZWO_APPR auth → Error message to contact admin
- Level-specific field access controlled in PBO screen attributes

### Data Validation
- Missing reason on mismatch → Error before save
- Empty WO range → Error before load
- No items selected for approval → Error before process

---

## Performance Considerations

1. **Bulk Fetch Strategy**: 
   - Single SELECT for all components (RESB × VIAUFKS)
   - Single SELECT for all tasklists (PLMZ × STPO)
   - FOR ALL ENTRIES for MAKT descriptions

2. **Binary Search**: 
   - gt_tasklist sorted by (plnnr, plnal, idnrk)
   - BINARY SEARCH used in comparison loop

3. **Pre-Filtering**:
   - Exclude already-approved WOs before bulk fetch
   - Reduces RESB read volume significantly

4. **ALV Refresh**:
   - Only refresh_display on subsequent PBO calls
   - Full rebuild only on first entry or after exit

---

## Integration Points

### Exit Programs
- ZFM_WO_CHECK_AUTH: Authorization check
- ZFM_WO_GET_STATUS: Status query for release blocking

### Email System
- SBWP Distribution Lists: APPR_<WERKS>_HO, APPR_<WERKS>_BR
- BCS (Business Communication Service) for HTML email sending

### Material Master
- MAKT table for material descriptions
- ZINCHG for interchange detection

### PM/CS Tables
- RESB: Reservation/Component data
- VIAUFKS: Order header data
- PLMZ: Tasklist header
- STPO: BOM item data
- CAUFV: Order header for locking

---

## Configuration Requirements

### TVARVC Variables
- ZWO_REJECT_REASON*: Rejection reason codes (format: CODEDescription)
- ZWO_CHANGE_REASON*: Change reason codes (format: CODEDescription)

### Distribution Lists (SBWP)
- APPR_<WERKS>_HO: HO recipients for approval requests
- APPR_<WERKS>_BR: Branch recipients for approval notifications

### Authorization Object
- ZWO_APPR with fields:
  - ACTVT: Activity (02=Change)
  - APPR_LEVEL: L1/L3/L4/L5
  - WERKS: Plant (optional)

---

## Troubleshooting

### Issue: No items displayed after loading WO range
**Check**:
- WO range is not empty
- WOs are not already fully approved in ZTWOAPPRH
- User has plant authorization (I_SWERK)
- Service orders have components (RESB)

### Issue: Email not sent
**Check**:
- DLI exists in SBWP (APPR_<WERKS>_HO or _BR)
- DLI has valid email addresses
- SOST transaction for send status
- User has email send authorization

### Issue: Cannot save approval
**Check**:
- User level matches required level for item type
- Reason fields are filled as per level rules
- WO is not locked by another user
- Authorization object ZWO_APPR is correctly assigned

---

## Version History

| Version | Date | Key Changes |
|---------|------|-------------|
| 2.5 | Current | v1.7.3 Screen 0320/0330: inline CHECK 0001 in default_filter_0320; &BACK/&EXIT on 0320 calls free_alv_0320 + clears s_w320[] s_a320[]; &BACK/&EXIT on 0330 calls free_alv_0330 + clears s_w330[] s_a330[] gv_send_mode; STATUS_0320/0330 bumped to v1.7.3 |
| 2.4 | Previous | v1.7.2 Screen 0330: plant pre-fill excludes plant 0001; ALV layout-level edit=false, only MARK col editable via fcat; SALL/DSEL call check_changed_data before bulk-mark; SEND hard-blocks L3/L5; process_send_email_grouped dispatches build_email_html_plant (BR) or build_email_html (HO); new FORM build_email_html_plant added to F06 |
| 2.3 | Previous | v1.7.1 Screen 0310: auto_load_0310 replaces default_filter_0310 (s_w310/s_a310 left blank, r_swerk auto-applied); build_plant_range removes s_werks pre-filter; tree node key uses AUFNR directly (no M/W prefix) to fix truncation; ALPHA exit for tree labels; BACK/EXIT clears s_w310+s_a310+free_alv |
| 2.2 | Previous | v1.8 Screen 0310 subscreen 0311 range filtering (s_w310, s_a310), default_filter_0310, refactored load_pending_tree_0310 and load_pending_wo_list for range-based queries |
| 2.0 | Previous | Screen 0310 3-panel layout (Tree + Subscreen + ALV), CL_GUI_LIST_TREE integration, subscreen 0311, plant/werks filter, tree-driven ALV filtering |
| 1.5 | Earlier | L1 mismatch-only view, email columns, manual email trigger, bulk pipeline |
| 1.0 | Initial | Base implementation |

---

*Documentation generated on: 2026-05-04*  
*Function Group: ZFG_WO_APPROVAL*  
*Version: 2.5*