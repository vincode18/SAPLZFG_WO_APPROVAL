# 📘 FILE 1 — ABAP PROGRAMMING PROMPT (v2.0)
## Work Order Approval System (SAPMZWO_APPROVAL)

**Version:** 2.0 (Updated with ZTWOAPPRH + LVL_STATUS + SBWP Email)
**Module:** PM (Plant Maintenance)
**Target Agent:** ABAP Developer Agent
**Language:** ABAP 7.40+ (Module Pool Program)

---

## 🔄 CHANGES FROM v1.0

| Change | Details |
|--------|---------|
| **Table name** | `ZTWOAPPR_H` → **`ZTWOAPPRH`** (no underscore) |
| **New field** | Added `LVL_STATUS` to ZTWOAPPRH (tracks L1/L3 progress: 0=Draft, 1=L1 Done, 2=Final) |
| **Email approach** | Replaced ZTWOEMAIL tables with **SBWP Distribution List (DLI)** pattern |
| **Email library** | Using `CL_BCS` + `SO_DLI_READ_API1` (modern approach) |
| **DLI naming** | Convention: `APPR_<WERKS3>_<TYPE>` (e.g., `APPR_100_HO`, `APPR_100_BR`) |
| **Per-plant email** | One email per plant group for cleaner segregation |

---

## 🎯 ROLE & CONTEXT FOR AGENT

```
You are a Senior SAP ABAP Developer specializing in Module Pool (SAPM) programs
for Plant Maintenance. Generate production-ready code with the following standards:

- ABAP 7.40+ modern syntax (inline declarations, VALUE, CORRESPONDING, FOR, REDUCE)
- Comprehensive error handling with TRY...CATCH cx_bcs
- Hungarian notation: lv_, lt_, ls_, lr_, gv_, gt_, go_
- ABAP Doc comments ("!) on all public methods
- Code Inspector compliant (priority 1 & 2 = 0 findings)
- Performance-optimized (no SELECT inside LOOP)
- Proper lock handling (ENQUEUE/DEQUEUE)
- Authorization checks at entry points
- SBWP DLI pattern for email recipients (NO hardcoded addresses, NO config tables)
- COMMIT WORK after every successful cl_bcs=>send( )
```

---

## 📋 PROJECT OVERVIEW

### Business Objective
2-level approval workflow for Work Order parts validation against Task List (IA06)
components, with email notifications via SBWP Distribution Lists.

### Approval Levels (v8.2+)
| Level | Role | Scope |
|-------|------|-------|
| **L1** | BCSPPD HO | Approves ONLY mismatched parts (red lines) |
| **L3** | SDH | Final approval for ALL parts (red + normal) |
| **AD** | Admin | Full access + DLI management |

### LVL_STATUS Field (NEW)

```
ZTWOAPPRH-LVL_STATUS values:
  0 = Draft (no level approval yet)
  1 = L1 Completed (BCSPPD HO done, waiting L3)
  2 = L3 Completed (SDH done — Final)

ZTWOAPPRH-APPR_STATUS values (unchanged):
  0 = No Approval
  1 = Request Approval
  2 = Parts Approved
```

### Status Progression

```
┌─────────────────────────────────────────────────────────────────┐
│               APPROVAL STATE MACHINE                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  [Branch Submit]                                                 │
│      APPR_STATUS=1  LVL_STATUS=0                                 │
│           │                                                      │
│           │ L1 saves approval                                    │
│           ▼                                                      │
│      APPR_STATUS=1  LVL_STATUS=1    (L1 done, pending L3)        │
│           │                                                      │
│           │ L3 saves final                                       │
│           ▼                                                      │
│      APPR_STATUS=2  LVL_STATUS=2    (Fully approved)             │
│           │                                                      │
│           │ Auto-trigger email via SBWP DLI                      │
│           ▼                                                      │
│      [Ready for Execution]                                       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Comparison Logic

```
WORK ORDER DATA                       MASTER DATA (TASK LIST)
┌─────────────────┐                   ┌──────────────────────────┐
│    VIAUFKS      │                   │          PLKO            │
│ (Header Order)  │                   │   (Task List Header)     │
└────────┬────────┘                   └────────────┬─────────────┘
         │[AUFNR]                                  │[PLNNR, PLNAL]
         ▼                                         ▼
┌─────────────────┐                   ┌──────────────────────────┐
│      RESB       │                   │          PLMZ            │
│ (Reservations)  │                   │   (Comp. Allocation)     │
└────────┬────────┘                   └────────────┬─────────────┘
         │[MATNR]◄────[COMPARE KEY]────┐            │[STLNR, STLTY]
         │                             │            ▼
         │                             │  ┌──────────────────────────┐
         │                             └──┤         STPO             │
         │                                │    (BOM Components)      │
         │                                │  [IDNRK]                 │
         ▼                                └──────────────────────────┘
    COMPARISON LOGIC
    IF RESB-MATNR NOT IN STPO-IDNRK → MISMATCH (🔴 Red Line)
    ELSE → MATCH (Normal)
```

---

## 🗂️ PROGRAM STRUCTURE

### Program Identification
| Attribute | Value |
|-----------|-------|
| Program Type | Module Pool (M) |
| Program Name | `SAPMZWO_APPROVAL` |
| Function Group | `ZFG_WO_APPROVAL` |
| Transaction Code | `ZWOAPP` |
| Package | `ZPM_APPROVAL` |
| Message Class | `ZWO_APPR` |
| Authorization Object | `ZWO_APPR` |

### Function Group Includes
```
ZFG_WO_APPROVAL
├── ZFG_WO_APPROVAL_TOP       "Global declarations + types
├── ZFG_WO_APPROVAL_F01       "Data retrieval (RESB, STPO)
├── ZFG_WO_APPROVAL_F02       "Approval logic (L1/L3 save + LVL_STATUS)
├── ZFG_WO_APPROVAL_F03       "Table Control handling
├── ZFG_WO_APPROVAL_F04       "Lock/Unlock
├── ZFG_WO_APPROVAL_F05       "Authorization check
├── ZFG_WO_APPROVAL_F06       "Email — SBWP DLI + CL_BCS (4 FORMs)
├── ZFG_WO_APPROVAL_F07       "TVARVC reason loader
├── ZFG_WO_APPROVAL_F08       "Comparison logic
├── ZFG_WO_APPROVAL_O01       "PBO modules
└── ZFG_WO_APPROVAL_I01       "PAI modules
```

---

## 🖥️ SCREEN NAVIGATION MAP

```
╔══════════════════════════════════════════════════════════════════════╗
║                    TRANSACTION: /NZWOAPP                             ║
║                                                                      ║
║                  [USER LOGIN + AUTH CHECK]                           ║
║                         ZWO_APPR                                     ║
║                         │                                            ║
║                         ▼                                            ║
║            ┌────────────────────────────┐                            ║
║            │   SCREEN 0100 — MAIN MENU  │                            ║
║            └──────────────┬─────────────┘                            ║
║                           │                                          ║
║      ┌──────────┬─────────┼──────────┬──────────┐                   ║
║      │          │         │          │          │                   ║
║      ▼          ▼         ▼          ▼          ▼                   ║
║   ┌─────┐   ┌─────┐   ┌─────┐    ┌─────┐    ┌─────┐                ║
║   │0300 │   │0310 │   │0320 │    │0330 │    │EXIT │                ║
║   │Appr │   │Pend │   │Hist │    │Mail │    │ F3  │                ║
║   └──┬──┘   └──┬──┘   └──┬──┘    └──┬──┘    └─────┘                ║
║      │         │         │          │                               ║
║      │         │         │          │                               ║
║      ▼         ▼         ▼          ▼                               ║
║   [Table    [Date     [Audit     [WO Input                          ║
║   Control   Range     Trail      + DLI Preview                      ║
║   Editable] Filter]   Display]   + Send via BCS]                    ║
║                                                                      ║
║      ▲                                                               ║
║      │ [Double-click]                                                ║
║      └──────── from 0310 ──────────┐                                 ║
║                                    │                                 ║
╚════════════════════════════════════╪═════════════════════════════════╝
                                     │
                                     ▼
                          ┌────────────────────┐
                          │ Loads WO in 0300   │
                          │ for approval       │
                          └────────────────────┘
```

---

## 📝 STEP-BY-STEP DEVELOPMENT

### **STEP 1 — Function Group & TOP Include**

```abap
*&---------------------------------------------------------------------*
*& Include ZFG_WO_APPROVAL_TOP
*&---------------------------------------------------------------------*
FUNCTION-POOL zfg_wo_approval.

" ==========================================================
" TABLES (Note: ZTWOAPPRH — no underscore before H)
" ==========================================================
TABLES: ztwoapprh,         "Header
        ztwoappr,          "Detail
        viaufks,           "WO Header view
        resb,              "Reservations
        plko, plmz, stpo.  "Task List

" ==========================================================
" TYPES DEFINITIONS
" ==========================================================
TYPES: BEGIN OF ty_items_tc,
         mark          TYPE char1,
         rowcolor      TYPE char4,
         status_icon   TYPE icon_d,
         matnr         TYPE matnr,
         maktx         TYPE maktx,
         change_id     TYPE char10,
         rspos         TYPE rspos,
         bdmng         TYPE bdmng,
         meins         TYPE meins,
         menge_tl      TYPE menge_d,
         meins_tl      TYPE meins,
         is_mismatch   TYPE char1,
         approval_stat TYPE char20,
         approval_lvl1 TYPE flag,
         approval_lvl3 TYPE flag,
         appr_flag     TYPE flag,
         reason_code   TYPE char3,
         reason_desc   TYPE char60,
         appr_by_lvl1  TYPE syuname,
         appr_date_lvl1 TYPE datum,
         reason_change TYPE char40,
         reason_reject TYPE char40,
         appr_by_lvl3  TYPE syuname,
         appr_date_lvl3 TYPE datum,
         appr_valid    TYPE flag,
         agingdays     TYPE int4,
         werks         TYPE werks_d,    "For email grouping
       END OF ty_items_tc.

" Email recipient type (from SBWP skill)
TYPES: BEGIN OF ty_email_recipient,
         recipient TYPE ad_smtpadr,
         name      TYPE so_obj_des,
       END OF ty_email_recipient.

" Plant group type
TYPES: BEGIN OF ty_group_key,
         werks TYPE werks_d,
       END OF ty_group_key.

TYPES: BEGIN OF ty_reason,
         reason_code TYPE char3,
         reason_desc TYPE char60,
       END OF ty_reason.

TYPES: BEGIN OF ty_pending,
         aufnr         TYPE aufnr,
         ktext         TYPE aufk-ktext,
         werks         TYPE werks_d,
         requested_by  TYPE uname,
         requested_date TYPE datum,
         appr_status   TYPE char1,
         lvl_status    TYPE char1,     "NEW FIELD
         aging         TYPE int4,
         mismatch_cnt  TYPE int4,
       END OF ty_pending.

" ==========================================================
" GLOBAL DATA
" ==========================================================
DATA: gt_items_tc       TYPE TABLE OF ty_items_tc,
      gs_items_tc       TYPE ty_items_tc,
      gt_reject_reasons TYPE TABLE OF ty_reason,
      gt_change_reasons TYPE TABLE OF ty_reason,
      gt_pending        TYPE TABLE OF ty_pending,
      
      " Email (SBWP pattern)
      gt_selected       TYPE TABLE OF ty_items_tc,
      gt_recipients     TYPE TABLE OF ty_email_recipient,
      
      gs_header         TYPE ztwoapprh,
      gv_aufnr          TYPE aufnr,
      gv_werks          TYPE werks_d,
      gv_plnnr          TYPE plnnr,
      gv_plnal          TYPE plnal,
      gv_user_level     TYPE char2,
      gv_ok_code        TYPE sy-ucomm.

CONTROLS: tc_items TYPE TABLEVIEW USING SCREEN 0300.

" ==========================================================
" CONSTANTS
" ==========================================================
CONSTANTS: BEGIN OF gc_appr_status,
             no_approval  TYPE char1 VALUE '0',
             request      TYPE char1 VALUE '1',
             approved     TYPE char1 VALUE '2',
           END OF gc_appr_status,
           
           BEGIN OF gc_lvl_status,
             draft   TYPE char1 VALUE '0',
             l1_done TYPE char1 VALUE '1',
             l3_done TYPE char1 VALUE '2',
           END OF gc_lvl_status,
           
           BEGIN OF gc_item_stat,
             pending TYPE char20 VALUE 'PENDING',
             approve TYPE char20 VALUE 'APPROVE',
             reject  TYPE char20 VALUE 'REJECT',
           END OF gc_item_stat,
           
           BEGIN OF gc_user_lvl,
             l1 TYPE char2 VALUE 'L1',
             l3 TYPE char2 VALUE 'L3',
             ad TYPE char2 VALUE 'AD',
           END OF gc_user_lvl,
           
           " DLI naming + sender
           gc_dli_prefix    TYPE char5  VALUE 'APPR_',
           gc_sender_email  TYPE string VALUE 'noreply@yourcompany.com',
           gc_sender_name   TYPE string VALUE 'WO Approval System'.
```

---

### **STEP 2 — Authorization Check (F05)**

```abap
FORM check_user_authorization CHANGING cv_user_level TYPE char2.
  
  CLEAR cv_user_level.
  
  AUTHORITY-CHECK OBJECT 'ZWO_APPR'
    ID 'ACTVT'     FIELD '43'
    ID 'ZAPPR_LVL' FIELD 'L1'
    ID 'WERKS'     FIELD gv_werks.
  IF sy-subrc = 0.
    cv_user_level = gc_user_lvl-l1.
    RETURN.
  ENDIF.
  
  AUTHORITY-CHECK OBJECT 'ZWO_APPR'
    ID 'ACTVT'     FIELD '43'
    ID 'ZAPPR_LVL' FIELD 'L3'
    ID 'WERKS'     FIELD gv_werks.
  IF sy-subrc = 0.
    cv_user_level = gc_user_lvl-l3.
    RETURN.
  ENDIF.
  
  AUTHORITY-CHECK OBJECT 'ZWO_APPR'
    ID 'ACTVT'     FIELD '*'
    ID 'ZAPPR_LVL' FIELD 'AD'
    ID 'WERKS'     FIELD '*'.
  IF sy-subrc = 0.
    cv_user_level = gc_user_lvl-ad.
    RETURN.
  ENDIF.
  
  MESSAGE e001(zwo_appr).
  
ENDFORM.
```

---

### **STEP 3 — TVARVC Reason Loader (F07)**

```abap
FORM load_reasons_from_tvarvc.
  
  CHECK gt_reject_reasons IS INITIAL OR gt_change_reasons IS INITIAL.
  
  SELECT low AS reason_code, high AS reason_desc
    INTO CORRESPONDING FIELDS OF TABLE @gt_reject_reasons
    FROM tvarvc
    WHERE name = 'ZWO_REJECT_REASON'
      AND type = 'S' AND sign = 'I' AND opti = 'EQ'
    ORDER BY low.
  
  IF gt_reject_reasons IS INITIAL.
    MESSAGE e002(zwo_appr).
  ENDIF.
  
  SELECT low AS reason_code, high AS reason_desc
    INTO CORRESPONDING FIELDS OF TABLE @gt_change_reasons
    FROM tvarvc
    WHERE name = 'ZWO_CHANGE_REASON'
      AND type = 'S' AND sign = 'I' AND opti = 'EQ'
    ORDER BY low.
  
  IF gt_change_reasons IS INITIAL.
    MESSAGE e003(zwo_appr).
  ENDIF.
  
ENDFORM.

FORM get_reason_description
  USING    iv_reason_code TYPE char3
  CHANGING cv_reason_desc TYPE char60.
  
  DATA: ls_reason TYPE ty_reason.
  
  IF iv_reason_code(1) = 'R'.
    READ TABLE gt_reject_reasons INTO ls_reason
      WITH KEY reason_code = iv_reason_code.
  ELSEIF iv_reason_code(1) = 'C'.
    READ TABLE gt_change_reasons INTO ls_reason
      WITH KEY reason_code = iv_reason_code.
  ENDIF.
  
  cv_reason_desc = ls_reason-reason_desc.
  
ENDFORM.
```

---

### **STEP 4 — Comparison Logic (F01 + F08)**

```abap
FORM get_wo_header
  USING    iv_aufnr TYPE aufnr
  CHANGING cs_header TYPE viaufks
           cv_error  TYPE char1.
  
  CLEAR: cs_header, cv_error.
  
  SELECT SINGLE aufnr, ktext, werks, gsber, auart, plnnr, plnal, ernam, erdat
    FROM viaufks
    INTO CORRESPONDING FIELDS OF @cs_header
    WHERE aufnr = @iv_aufnr.
  
  IF sy-subrc <> 0.
    cv_error = abap_true.
    MESSAGE e004(zwo_appr) WITH iv_aufnr.
  ENDIF.
ENDFORM.

FORM get_wo_components
  USING    iv_aufnr TYPE aufnr
  CHANGING ct_components TYPE ANY TABLE.
  
  SELECT a~aufnr, a~rspos, a~matnr, a~bdmng, a~meins, a~werks, b~maktx
    INTO CORRESPONDING FIELDS OF TABLE @ct_components
    FROM resb AS a
    LEFT OUTER JOIN makt AS b
      ON a~matnr = b~matnr AND b~spras = @sy-langu
    WHERE a~aufnr = @iv_aufnr
      AND a~xloek = @space
      AND a~postp IN ('L','N').
ENDFORM.

FORM get_tasklist_components
  USING    iv_plnnr TYPE plnnr
           iv_plnal TYPE plnal
  CHANGING ct_tl_comp TYPE ANY TABLE.
  
  SELECT a~plnnr, a~plnal, a~stlnr, a~stlty,
         c~idnrk, c~menge, c~meins
    INTO CORRESPONDING FIELDS OF TABLE @ct_tl_comp
    FROM plko AS a
    INNER JOIN plmz AS b ON a~plnnr = b~plnnr AND a~plnal = b~plnal
    INNER JOIN stpo AS c ON b~stlnr = c~stlnr AND b~stlty = c~stlty
    WHERE a~plnnr = @iv_plnnr
      AND a~plnal = @iv_plnal
      AND a~loekz = @space
      AND c~lkenz = @space
      AND c~postp = 'L'.
ENDFORM.

FORM compare_wo_vs_tasklist
  USING    iv_aufnr TYPE aufnr
  CHANGING ct_result TYPE ty_items_tc
           cv_mismatch_count TYPE i.
  
  DATA: lt_wo_parts  TYPE TABLE OF ty_items_tc,
        lt_tl_parts  TYPE TABLE OF ty_items_tc,
        ls_header    TYPE viaufks,
        lv_error     TYPE char1.
  
  CLEAR: ct_result, cv_mismatch_count.
  
  PERFORM get_wo_header USING iv_aufnr CHANGING ls_header lv_error.
  CHECK lv_error = abap_false.
  
  gv_plnnr = ls_header-plnnr.
  gv_plnal = ls_header-plnal.
  gv_werks = ls_header-werks.
  
  PERFORM get_wo_components USING iv_aufnr CHANGING lt_wo_parts.
  
  IF gv_plnnr IS NOT INITIAL.
    PERFORM get_tasklist_components USING gv_plnnr gv_plnal CHANGING lt_tl_parts.
  ENDIF.
  
  LOOP AT lt_wo_parts ASSIGNING FIELD-SYMBOL(<ls_wo>).
    READ TABLE lt_tl_parts WITH KEY matnr = <ls_wo>-matnr TRANSPORTING NO FIELDS.
    
    IF sy-subrc <> 0.
      <ls_wo>-is_mismatch = abap_true.
      <ls_wo>-rowcolor    = 'C610'.
      <ls_wo>-status_icon = icon_red_light.
      cv_mismatch_count = cv_mismatch_count + 1.
    ELSE.
      <ls_wo>-is_mismatch = abap_false.
      <ls_wo>-rowcolor    = ''.
      <ls_wo>-status_icon = icon_green_light.
    ENDIF.
    
    " Merge existing approval status
    SELECT SINGLE approval_stat, approval_lvl1, approval_lvl3,
                  appr_by_lvl1, appr_date_lvl1,
                  appr_by_lvl3, appr_date_lvl3,
                  reason_change, reason_reject,
                  appr_valid, agingdays
      FROM ztwoappr
      INTO CORRESPONDING FIELDS OF @<ls_wo>
      WHERE aufnr = @iv_aufnr AND matnr = @<ls_wo>-matnr.
    
    <ls_wo>-werks = gv_werks.  "For email grouping
    APPEND <ls_wo> TO ct_result.
  ENDLOOP.
  
ENDFORM.
```

---

### **STEP 5 — Load WO with Lock (F04)**

```abap
FORM load_wo_for_approval.
  
  DATA: lv_mismatch_cnt TYPE i.
  
  IF gv_aufnr IS INITIAL.
    MESSAGE e020(zwo_appr).
  ENDIF.
  
  " Lock header
  CALL FUNCTION 'ENQUEUE_EZTWOAPPRH'
    EXPORTING
      mode_ztwoapprh = 'E'
      mandt          = sy-mandt
      aufnr          = gv_aufnr
    EXCEPTIONS
      foreign_lock   = 1
      system_failure = 2
      OTHERS         = 3.
  
  IF sy-subrc <> 0.
    MESSAGE e021(zwo_appr) WITH gv_aufnr sy-msgv1.
  ENDIF.
  
  " Read / create header
  SELECT SINGLE * FROM ztwoapprh INTO @gs_header WHERE aufnr = @gv_aufnr.
  
  IF sy-subrc <> 0.
    gs_header = VALUE ztwoapprh(
      mandt        = sy-mandt
      aufnr        = gv_aufnr
      appr_status  = gc_appr_status-no_approval
      lvl_status   = gc_lvl_status-draft        "NEW FIELD
      created_by   = sy-uname
      created_date = sy-datum
      created_time = sy-uzeit ).
    INSERT ztwoapprh FROM @gs_header.
  ENDIF.
  
  gv_werks = gs_header-werks.
  
  PERFORM check_user_authorization CHANGING gv_user_level.
  PERFORM compare_wo_vs_tasklist USING gv_aufnr CHANGING gt_items_tc lv_mismatch_cnt.
  
  IF lv_mismatch_cnt > 0.
    MESSAGE s030(zwo_appr) WITH lv_mismatch_cnt.
  ELSE.
    MESSAGE s031(zwo_appr).
  ENDIF.
  
ENDFORM.

FORM unlock_wo.
  CHECK gv_aufnr IS NOT INITIAL.
  CALL FUNCTION 'DEQUEUE_EZTWOAPPRH'
    EXPORTING
      mode_ztwoapprh = 'E'
      mandt          = sy-mandt
      aufnr          = gv_aufnr.
ENDFORM.
```

---

### **STEP 6 — Save with LVL_STATUS Progression (F02)**

```abap
FORM save_approval.
  
  " Pre-validation
  LOOP AT gt_items_tc INTO gs_items_tc WHERE is_mismatch = abap_true.
    IF gs_items_tc-reason_code IS INITIAL.
      MESSAGE e040(zwo_appr) WITH gs_items_tc-matnr.
      RETURN.
    ENDIF.
  ENDLOOP.
  
  CASE gv_user_level.
    WHEN gc_user_lvl-l1.
      PERFORM save_as_l1.
    WHEN gc_user_lvl-l3.
      PERFORM save_as_l3.
    WHEN gc_user_lvl-ad.
      PERFORM save_as_l3.
  ENDCASE.
  
  COMMIT WORK.
  
ENDFORM.

FORM save_as_l1.
  
  LOOP AT gt_items_tc INTO gs_items_tc WHERE is_mismatch = abap_true.
    
    DATA(ls_appr) = VALUE ztwoappr(
      mandt          = sy-mandt
      aufnr          = gv_aufnr
      matnr          = gs_items_tc-matnr
      change_id      = |CHG{ sy-datum+2(6) }{ sy-uzeit }|
      approval_lvl1  = gs_items_tc-appr_flag
      appr_by_lvl1   = sy-uname
      appr_date_lvl1 = sy-datum
      appr_time_lvl1 = sy-uzeit
      waers          = 'IDR'
      meins          = gs_items_tc-meins
      changed_by     = sy-uname
      changed_date   = sy-datum
      changed_time   = sy-uzeit ).
    
    IF gs_items_tc-appr_flag = abap_true.
      ls_appr-approval_stat = gc_item_stat-approve.
      ls_appr-reason_change = gs_items_tc-reason_desc.
      CLEAR ls_appr-reason_reject.
    ELSE.
      ls_appr-approval_stat = gc_item_stat-reject.
      ls_appr-reason_reject = gs_items_tc-reason_desc.
      CLEAR ls_appr-reason_change.
    ENDIF.
    
    SELECT SINGLE created_by FROM ztwoappr INTO @DATA(lv_existing)
      WHERE aufnr = @gv_aufnr AND matnr = @gs_items_tc-matnr.
    
    IF sy-subrc = 0.
      MODIFY ztwoappr FROM @ls_appr.
    ELSE.
      ls_appr-created_by   = sy-uname.
      ls_appr-created_date = sy-datum.
      ls_appr-created_time = sy-uzeit.
      INSERT ztwoappr FROM @ls_appr.
    ENDIF.
  ENDLOOP.
  
  " ⭐ UPDATE HEADER: APPR_STATUS=1, LVL_STATUS=1 (L1 Done)
  DATA: lv_req_by TYPE uname,
        lv_req_dt TYPE datum,
        lv_req_tm TYPE uzeit.
  
  IF gs_header-requested_by IS INITIAL.
    lv_req_by = sy-uname.
    lv_req_dt = sy-datum.
    lv_req_tm = sy-uzeit.
  ELSE.
    lv_req_by = gs_header-requested_by.
    lv_req_dt = gs_header-requested_date.
    lv_req_tm = gs_header-requested_time.
  ENDIF.
  
  UPDATE ztwoapprh
     SET appr_status    = @gc_appr_status-request
         lvl_status     = @gc_lvl_status-l1_done    "NEW
         requested_by   = @lv_req_by
         requested_date = @lv_req_dt
         requested_time = @lv_req_tm
         changed_by     = @sy-uname
         changed_date   = @sy-datum
         changed_time   = @sy-uzeit
   WHERE aufnr = @gv_aufnr.
  
  MESSAGE s052(zwo_appr).  "L1 approval saved. Pending L3.
  
ENDFORM.

FORM save_as_l3.
  
  LOOP AT gt_items_tc INTO gs_items_tc.
    
    SELECT SINGLE * FROM ztwoappr INTO @DATA(ls_appr)
      WHERE aufnr = @gv_aufnr AND matnr = @gs_items_tc-matnr.
    
    IF sy-subrc <> 0.
      ls_appr = VALUE ztwoappr(
        mandt        = sy-mandt
        aufnr        = gv_aufnr
        matnr        = gs_items_tc-matnr
        change_id    = |CHG{ sy-datum+2(6) }{ sy-uzeit }|
        waers        = 'IDR'
        meins        = gs_items_tc-meins
        created_by   = sy-uname
        created_date = sy-datum
        created_time = sy-uzeit ).
    ENDIF.
    
    ls_appr-approval_lvl3  = gs_items_tc-appr_flag.
    ls_appr-appr_by_lvl3   = sy-uname.
    ls_appr-appr_date_lvl3 = sy-datum.
    ls_appr-appr_time_lvl3 = sy-uzeit.
    
    IF gs_items_tc-appr_flag = abap_true.
      ls_appr-appr_valid    = abap_true.
      ls_appr-approval_stat = gc_item_stat-approve.
    ELSE.
      ls_appr-appr_valid    = abap_false.
      ls_appr-approval_stat = gc_item_stat-reject.
      IF gs_items_tc-reason_desc IS NOT INITIAL.
        ls_appr-reason_reject = gs_items_tc-reason_desc.
      ENDIF.
    ENDIF.
    
    ls_appr-changed_by   = sy-uname.
    ls_appr-changed_date = sy-datum.
    ls_appr-changed_time = sy-uzeit.
    
    MODIFY ztwoappr FROM @ls_appr.
  ENDLOOP.
  
  " ⭐ UPDATE HEADER: LVL_STATUS=2 + APPR_STATUS=2 if all approved
  SELECT COUNT(*) FROM ztwoappr INTO @DATA(lv_pending)
    WHERE aufnr = @gv_aufnr AND approval_lvl3 <> @abap_true.
  
  IF lv_pending = 0.
    UPDATE ztwoapprh
       SET appr_status   = @gc_appr_status-approved
           lvl_status    = @gc_lvl_status-l3_done   "NEW: Final
           approved_by   = @sy-uname
           approved_date = @sy-datum
           approved_time = @sy-uzeit
           changed_by    = @sy-uname
           changed_date  = @sy-datum
           changed_time  = @sy-uzeit
     WHERE aufnr = @gv_aufnr.
    
    " AUTO email via SBWP DLI
    PERFORM trigger_auto_email_branch USING gv_aufnr.
    
    MESSAGE s051(zwo_appr).
  ELSE.
    UPDATE ztwoapprh
       SET changed_by   = @sy-uname
           changed_date = @sy-datum
           changed_time = @sy-uzeit
     WHERE aufnr = @gv_aufnr.
  ENDIF.
  
ENDFORM.

FORM trigger_auto_email_branch USING iv_aufnr TYPE aufnr.
  
  DATA: lv_cnt TYPE i.
  
  PERFORM compare_wo_vs_tasklist USING iv_aufnr CHANGING gt_items_tc lv_cnt.
  
  LOOP AT gt_items_tc ASSIGNING FIELD-SYMBOL(<ls>).
    <ls>-mark = abap_true.
  ENDLOOP.
  
  PERFORM process_send_email USING 'BR'.
  
ENDFORM.
```

---

### **STEP 7 — Email via SBWP DLI (F06) — 4-Layer Pattern**

This replaces all ZTWOEMAIL config tables. Recipients come from **SBWP Distribution Lists**.

```abap
*&---------------------------------------------------------------------*
*& LAYER 1 — ORCHESTRATOR
*&---------------------------------------------------------------------*
FORM process_send_email USING pv_email_type TYPE char2.  "HO or BR
  
  DATA: lv_count        TYPE i,
        lv_answer       TYPE char1,
        lv_dli_name     TYPE so_recname,
        lt_html         TYPE bcsy_text,
        lv_subject      TYPE so_obj_des,
        lv_date_str(10) TYPE c,
        lv_werks_3      TYPE char3,
        lv_total_sent   TYPE i,
        lv_total_items  TYPE i,
        lv_group_count  TYPE i,
        lv_item_count   TYPE i,
        lv_skip_count   TYPE i.
  
  DATA: lt_groups        TYPE TABLE OF ty_group_key,
        ls_group         TYPE ty_group_key,
        lt_group_items   TYPE TABLE OF ty_items_tc,
        lt_save_selected TYPE TABLE OF ty_items_tc.
  
  " Auth check
  IF gv_user_level IS INITIAL.
    MESSAGE e001(zwo_appr).
    RETURN.
  ENDIF.
  
  " Collect selected + unique plants
  CLEAR: gt_selected, gt_recipients, lv_count.
  LOOP AT gt_items_tc INTO gs_items_tc WHERE mark = abap_true.
    lv_count = lv_count + 1.
    APPEND gs_items_tc TO gt_selected.
    
    READ TABLE lt_groups WITH KEY werks = gs_items_tc-werks TRANSPORTING NO FIELDS.
    IF sy-subrc <> 0.
      ls_group-werks = gs_items_tc-werks.
      APPEND ls_group TO lt_groups.
    ENDIF.
  ENDLOOP.
  
  IF lv_count = 0.
    MESSAGE 'Please select at least one item' TYPE 'I'.
    RETURN.
  ENDIF.
  
  lv_group_count = lines( lt_groups ).
  
  " Confirmation
  CALL FUNCTION 'POPUP_TO_CONFIRM'
    EXPORTING
      titlebar              = 'Send Email Notification'
      text_question         = |Send email for { lv_count } item(s) | &&
                              |across { lv_group_count } plant(s)?|
      text_button_1         = 'Yes'
      text_button_2         = 'No'
      default_button        = '2'
      display_cancel_button = ''
    IMPORTING
      answer                = lv_answer.
  
  IF lv_answer <> '1'.
    RETURN.
  ENDIF.
  
  WRITE sy-datum TO lv_date_str DD/MM/YYYY.
  lt_save_selected = gt_selected.
  
  CLEAR: lv_total_sent, lv_total_items, lv_skip_count.
  LOOP AT lt_groups INTO ls_group.
    
    " Filter items for this plant
    CLEAR: lt_group_items, gt_recipients.
    LOOP AT lt_save_selected INTO gs_items_tc WHERE werks = ls_group-werks.
      APPEND gs_items_tc TO lt_group_items.
    ENDLOOP.
    
    CHECK lt_group_items IS NOT INITIAL.
    lv_item_count = lines( lt_group_items ).
    
    " Build DLI name: APPR_<plant3>_<type>
    lv_werks_3 = ls_group-werks(3).
    CONCATENATE gc_dli_prefix lv_werks_3 INTO lv_dli_name.
    CONDENSE lv_dli_name NO-GAPS.
    
    IF pv_email_type = 'HO'.
      CONCATENATE lv_dli_name '_HO' INTO lv_dli_name.
    ELSEIF pv_email_type = 'BR'.
      CONCATENATE lv_dli_name '_BR' INTO lv_dli_name.
    ENDIF.
    
    " Read SBWP DLI
    PERFORM get_email_from_dli USING lv_dli_name.
    
    IF gt_recipients IS INITIAL.
      MESSAGE |No recipients in DLI { lv_dli_name } — skipped|
              TYPE 'S' DISPLAY LIKE 'W'.
      lv_skip_count = lv_skip_count + 1.
      CONTINUE.
    ENDIF.
    
    " Point to group items for HTML builder
    gt_selected = lt_group_items.
    
    IF pv_email_type = 'HO'.
      lv_subject = |[APPROVAL] WO Approval Request — { lv_item_count } item(s) | &&
                   |— Plant { ls_group-werks }|.
    ELSE.
      lv_subject = |[APPROVED] WO Ready for Execution — Plant { ls_group-werks }|.
    ENDIF.
    
    " Build HTML
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
    
    " Send via BCS
    TRY.
        PERFORM send_email_bcs TABLES gt_recipients
                               USING  lv_subject lt_html.
        lv_total_sent  = lv_total_sent + 1.
        lv_total_items = lv_total_items + lv_item_count.
      CATCH cx_bcs INTO DATA(lx_bcs).
        MESSAGE |Error sending for { ls_group-werks }: | &&
                |{ lx_bcs->get_text( ) }| TYPE 'S' DISPLAY LIKE 'W'.
        lv_skip_count = lv_skip_count + 1.
    ENDTRY.
    
  ENDLOOP.
  
  gt_selected = lt_save_selected.
  
  IF lv_total_sent > 0.
    DATA(lv_msg) = |Email sent to { lv_total_sent } plant(s) | &&
                   |for { lv_total_items } item(s)|.
    IF lv_skip_count > 0.
      lv_msg = lv_msg && |, { lv_skip_count } skipped|.
    ENDIF.
    MESSAGE lv_msg TYPE 'S'.
  ELSE.
    MESSAGE 'No emails sent — check SBWP Distribution Lists' TYPE 'W'.
  ENDIF.
  
ENDFORM.

*&---------------------------------------------------------------------*
*& LAYER 2 — DLI READER (using SO_DLI_READ_API1)
*&---------------------------------------------------------------------*
FORM get_email_from_dli USING p_lv_dli_name TYPE so_recname.
  
  DATA: dli_entries          LIKE sodlienti1 OCCURS 0 WITH HEADER LINE,
        ls_recipient         TYPE ty_email_recipient,
        lv_dli_name_internal LIKE soobjinfi1-obj_name.
  
  CLEAR gt_recipients.
  lv_dli_name_internal = p_lv_dli_name.
  
  " Try SHARED DLI first
  CALL FUNCTION 'SO_DLI_READ_API1'
    EXPORTING
      dli_name                   = lv_dli_name_internal
      shared_dli                 = 'X'
    TABLES
      dli_entries                = dli_entries
    EXCEPTIONS
      dli_not_exist              = 1
      operation_no_authorization = 2
      parameter_error            = 3
      x_error                    = 4
      OTHERS                     = 5.
  
  " Fallback to PERSONAL DLI
  IF sy-subrc <> 0.
    REFRESH dli_entries.
    CALL FUNCTION 'SO_DLI_READ_API1'
      EXPORTING
        dli_name                   = lv_dli_name_internal
        shared_dli                 = ' '
      TABLES
        dli_entries                = dli_entries
      EXCEPTIONS
        dli_not_exist              = 1
        operation_no_authorization = 2
        parameter_error            = 3
        x_error                    = 4
        OTHERS                     = 5.
  ENDIF.
  
  IF sy-subrc <> 0.
    RETURN.   "Empty gt_recipients
  ENDIF.
  
  LOOP AT dli_entries.
    IF dli_entries-member_adr IS NOT INITIAL.
      CLEAR ls_recipient.
      ls_recipient-recipient = dli_entries-member_adr.
      ls_recipient-name      = dli_entries-member_nam.
      APPEND ls_recipient TO gt_recipients.
    ENDIF.
  ENDLOOP.
  
ENDFORM.

*&---------------------------------------------------------------------*
*& LAYER 3 — HTML BUILDER (FIRST/BODY/LAST)
*&---------------------------------------------------------------------*
FORM build_email_html
  USING    p_flag       TYPE string
           p_date_str   TYPE c
           p_count      TYPE i
           p_type       TYPE char2
           p_werks      TYPE werks_d
  CHANGING pt_html      TYPE bcsy_text.
  
  DATA: htmltag        TYPE string,
        ls_data        TYPE ty_items_tc,
        lv_counter     TYPE i,
        lv_count_str   TYPE string,
        lv_date_str    TYPE string,
        lv_counter_str TYPE string,
        lv_bdmng_str   TYPE string,
        lv_menge_str   TYPE string,
        lv_matnr_out   TYPE string,
        lv_aufnr_out   TYPE string,
        lv_reason      TYPE string,
        lv_uname       TYPE string.
  
  lv_count_str = p_count.
  lv_date_str  = p_date_str.
  
  CASE p_flag.
    WHEN 'FIRST'.
      APPEND '<html>' TO pt_html.
      APPEND '<head><style type="text/css">' TO pt_html.
      APPEND 'body { font-family: Arial, sans-serif; font-size: 12px; }' TO pt_html.
      APPEND 'table { border-collapse: collapse; width: 100%; border: 2px solid #000; }' TO pt_html.
      APPEND 'th, td { padding: 8px; border: 1px solid #ddd; text-align: left; }' TO pt_html.
      APPEND 'th { background-color: #003399; color: white; font-weight: bold; }' TO pt_html.
      APPEND 'tr:nth-child(even) { background-color: #F8F8F8; }' TO pt_html.
      APPEND '.mismatch { background-color: #ffcccc; }' TO pt_html.
      APPEND '.match { background-color: #e6ffe6; }' TO pt_html.
      APPEND '</style></head><body>' TO pt_html.
      
      IF p_type = 'HO'.
        APPEND '<h2 style="color:#003399;">Work Order Approval Request</h2>' TO pt_html.
        APPEND '<p>Dear <b>BCSPPD HO Team</b>,</p>' TO pt_html.
        APPEND '<p>The following Work Order components require your review and approval.</p>' TO pt_html.
      ELSE.
        APPEND '<h2 style="color:#009933;">Work Order Fully Approved</h2>' TO pt_html.
        APPEND '<p>Dear <b>Branch Team</b>,</p>' TO pt_html.
        APPEND '<p>The following Work Order has been fully approved and is ready for execution.</p>' TO pt_html.
      ENDIF.
      
      CONCATENATE '<p><b>Plant:</b> ' p_werks
                  ' | <b>Date:</b> ' p_date_str
                  ' | <b>Total Items:</b> ' lv_count_str
                  '</p><br>' INTO htmltag.
      APPEND htmltag TO pt_html.
      
      APPEND '<table><tr>' TO pt_html.
      APPEND '<th>No</th><th>Work Order</th><th>Material</th>' TO pt_html.
      APPEND '<th>Description</th><th>WO Qty</th><th>TL Qty</th>' TO pt_html.
      APPEND '<th>Status</th><th>Reason</th></tr>' TO pt_html.
    
    WHEN 'BODY'.
      CLEAR lv_counter.
      LOOP AT gt_selected INTO ls_data.
        lv_counter = lv_counter + 1.
        lv_counter_str = lv_counter.
        
        CALL FUNCTION 'CONVERSION_EXIT_ALPHA_OUTPUT'
          EXPORTING input = gv_aufnr IMPORTING output = lv_aufnr_out.
        
        CALL FUNCTION 'CONVERSION_EXIT_MATN1_OUTPUT'
          EXPORTING input = ls_data-matnr IMPORTING output = lv_matnr_out.
        
        lv_bdmng_str = ls_data-bdmng.
        lv_menge_str = ls_data-menge_tl.
        CONDENSE: lv_bdmng_str, lv_menge_str.
        
        IF ls_data-is_mismatch = abap_true.
          APPEND '<tr class="mismatch">' TO pt_html.
        ELSE.
          APPEND '<tr class="match">' TO pt_html.
        ENDIF.
        
        CONCATENATE '<td style="text-align:center;">' lv_counter_str '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.
        CONCATENATE '<td style="font-weight:bold;">' lv_aufnr_out '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.
        CONCATENATE '<td>' lv_matnr_out '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.
        CONCATENATE '<td>' ls_data-maktx '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.
        CONCATENATE '<td style="text-align:right;">' lv_bdmng_str ' ' ls_data-meins '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.
        
        IF ls_data-menge_tl IS INITIAL.
          APPEND '<td style="text-align:center;">-</td>' TO pt_html.
        ELSE.
          CONCATENATE '<td style="text-align:right;">' lv_menge_str ' ' ls_data-meins_tl '</td>' INTO htmltag.
          APPEND htmltag TO pt_html.
        ENDIF.
        
        IF ls_data-is_mismatch = abap_true.
          APPEND '<td style="color:red;text-align:center;"><b>MISMATCH</b></td>' TO pt_html.
        ELSE.
          APPEND '<td style="color:green;text-align:center;">MATCH</td>' TO pt_html.
        ENDIF.
        
        IF ls_data-reason_change IS NOT INITIAL.
          lv_reason = ls_data-reason_change.
        ELSEIF ls_data-reason_reject IS NOT INITIAL.
          lv_reason = ls_data-reason_reject.
        ELSE.
          lv_reason = '-'.
        ENDIF.
        CONCATENATE '<td>' lv_reason '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.
        
        APPEND '</tr>' TO pt_html.
      ENDLOOP.
    
    WHEN 'LAST'.
      APPEND '</table><br>' TO pt_html.
      APPEND '<p><b>Summary:</b></p><ul>' TO pt_html.
      CONCATENATE '<li>Total items: <b>' lv_count_str '</b></li>' INTO htmltag.
      APPEND htmltag TO pt_html.
      CONCATENATE '<li>Plant: <b>' p_werks '</b></li>' INTO htmltag.
      APPEND htmltag TO pt_html.
      CONCATENATE '<li>Date: <b>' p_date_str '</b></li>' INTO htmltag.
      APPEND htmltag TO pt_html.
      APPEND '</ul><br>' TO pt_html.
      
      IF p_type = 'HO'.
        APPEND '<p><b>Action:</b> Please review in transaction <b>ZWOAPP</b>.</p>' TO pt_html.
      ELSE.
        APPEND '<p>Please proceed with material issue and execution.</p>' TO pt_html.
      ENDIF.
      
      APPEND '<p>Thank you,</p>' TO pt_html.
      lv_uname = sy-uname.
      CONCATENATE '<p><b>' lv_uname '</b><br>WO Approval System</p>' INTO htmltag.
      APPEND htmltag TO pt_html.
      
      APPEND '<hr><p style="font-size:10px;color:#888;">' TO pt_html.
      APPEND 'Automated email — please do not reply.</p>' TO pt_html.
      APPEND '</body></html>' TO pt_html.
  ENDCASE.
  
ENDFORM.

*&---------------------------------------------------------------------*
*& LAYER 4 — BCS SENDER
*&---------------------------------------------------------------------*
FORM send_email_bcs
  TABLES  pt_email   LIKE gt_recipients
  USING   p_subject  TYPE so_obj_des
          p_html_tab TYPE bcsy_text
  RAISING cx_bcs.
  
  CHECK NOT pt_email[] IS INITIAL.
  
  DATA: lo_email           TYPE REF TO cl_bcs,
        lo_email_body      TYPE REF TO cl_document_bcs,
        lo_receiver        TYPE REF TO if_recipient_bcs,
        lo_internet_sender TYPE REF TO if_sender_bcs,
        l_address          TYPE adr6-smtp_addr,
        lv_send_result     TYPE c.
  
  TRY.
      lo_email = cl_bcs=>create_persistent( ).
      
      lo_email_body = cl_document_bcs=>create_document(
        i_type    = 'HTM'
        i_text    = p_html_tab
        i_subject = p_subject ).
      
      lo_email->set_document( lo_email_body ).
      
      lo_internet_sender = cl_cam_address_bcs=>create_internet_address(
        i_address_string = CONV ad_smtpadr( gc_sender_email )
        i_address_name   = CONV so_obj_des( gc_sender_name ) ).
      lo_email->set_sender( i_sender = lo_internet_sender ).
      
      LOOP AT pt_email.
        l_address   = pt_email-recipient.
        lo_receiver = cl_cam_address_bcs=>create_internet_address( l_address ).
        lo_email->add_recipient(
          i_recipient = lo_receiver
          i_express   = 'X' ).
      ENDLOOP.
      
      lo_email->set_send_immediately( 'X' ).
      
      lo_email->send(
        EXPORTING i_with_error_screen = 'X'
        RECEIVING result              = lv_send_result ).
      
      IF lv_send_result = 'X'.
        MESSAGE s000(db) WITH 'Email has been sent'.
      ENDIF.
      
      COMMIT WORK.
      
    CATCH cx_bcs INTO DATA(lx).
      MESSAGE s000(db) WITH 'Email has not been sent'.
      RAISE EXCEPTION lx.
  ENDTRY.
  
ENDFORM.
```

---

### **STEP 8 — Table Control (Screen 0300 Flow)**

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

**PBO & PAI Modules:**

```abap
MODULE status_0300 OUTPUT.
  SET PF-STATUS 'STATUS_0300'.
  SET TITLEBAR 'TITLE_0300' WITH gv_aufnr.
  DESCRIBE TABLE gt_items_tc LINES tc_items-lines.
ENDMODULE.

MODULE load_reasons OUTPUT.
  PERFORM load_reasons_from_tvarvc.
ENDMODULE.

MODULE set_row_color OUTPUT.
  LOOP AT SCREEN.
    IF gs_items_tc-is_mismatch = abap_true.
      screen-intensified = '1'.
    ENDIF.
    MODIFY SCREEN.
  ENDLOOP.
ENDMODULE.

MODULE set_reason_dropdown OUTPUT.
  DATA: lt_values TYPE vrm_values,
        ls_value  TYPE vrm_value.
  CLEAR lt_values.
  
  IF gs_items_tc-is_mismatch = abap_true.
    IF gs_items_tc-appr_flag = abap_false.
      LOOP AT gt_reject_reasons INTO DATA(ls_reject).
        ls_value-key  = ls_reject-reason_code.
        ls_value-text = |{ ls_reject-reason_code } - { ls_reject-reason_desc }|.
        APPEND ls_value TO lt_values.
      ENDLOOP.
    ELSE.
      LOOP AT gt_change_reasons INTO DATA(ls_change).
        ls_value-key  = ls_change-reason_code.
        ls_value-text = |{ ls_change-reason_code } - { ls_change-reason_desc }|.
        APPEND ls_value TO lt_values.
      ENDLOOP.
    ENDIF.
    
    CALL FUNCTION 'VRM_SET_VALUES'
      EXPORTING
        id     = 'GS_ITEMS_TC-REASON_CODE'
        values = lt_values.
  ENDIF.
ENDMODULE.

MODULE control_field_attributes OUTPUT.
  LOOP AT SCREEN.
    IF screen-name = 'GS_ITEMS_TC-APPR_FLAG'.
      CASE gv_user_level.
        WHEN gc_user_lvl-l1.
          IF gs_items_tc-is_mismatch = abap_true.
            screen-input = 1.
          ELSE.
            screen-input = 0.
            screen-invisible = 1.
          ENDIF.
        WHEN gc_user_lvl-l3 OR gc_user_lvl-ad.
          screen-input = 1.
        WHEN OTHERS.
          screen-input = 0.
      ENDCASE.
    ENDIF.
    IF screen-name = 'GS_ITEMS_TC-REASON_CODE'.
      IF gs_items_tc-is_mismatch = abap_true.
        screen-input = 1.
      ELSE.
        screen-input = 0.
        screen-invisible = 1.
      ENDIF.
    ENDIF.
    MODIFY SCREEN.
  ENDLOOP.
ENDMODULE.

MODULE modify_tc_line INPUT.
  MODIFY gt_items_tc FROM gs_items_tc INDEX tc_items-current_line.
ENDMODULE.

MODULE validate_reason INPUT.
  CHECK gs_items_tc-is_mismatch = abap_true.
  IF gs_items_tc-appr_flag = abap_false AND gs_items_tc-reason_code IS INITIAL.
    MESSAGE e010(zwo_appr) WITH gs_items_tc-matnr.
  ENDIF.
  IF gs_items_tc-appr_flag = abap_true AND gs_items_tc-reason_code IS INITIAL.
    MESSAGE e011(zwo_appr) WITH gs_items_tc-matnr.
  ENDIF.
  IF gs_items_tc-appr_flag = abap_false AND gs_items_tc-reason_code(1) = 'C'.
    MESSAGE e012(zwo_appr).
  ENDIF.
  IF gs_items_tc-appr_flag = abap_true AND gs_items_tc-reason_code(1) = 'R'.
    MESSAGE e013(zwo_appr).
  ENDIF.
  PERFORM get_reason_description
    USING gs_items_tc-reason_code CHANGING gs_items_tc-reason_desc.
ENDMODULE.

MODULE user_command_0300 INPUT.
  gv_ok_code = sy-ucomm.
  CLEAR sy-ucomm.
  CASE gv_ok_code.
    WHEN 'LOAD'.
      PERFORM load_wo_for_approval.
    WHEN 'SAVE'.
      PERFORM save_approval.
    WHEN 'EMAIL_HO'.
      PERFORM process_send_email USING 'HO'.
    WHEN 'EMAIL_BR'.
      PERFORM process_send_email USING 'BR'.
    WHEN 'BACK' OR 'EXIT' OR 'CANCEL'.
      PERFORM unlock_wo.
      LEAVE TO SCREEN 0100.
  ENDCASE.
ENDMODULE.
```

---

### **STEP 9 — Screen 0100 (Main Menu)**

```abap
MODULE status_0100 OUTPUT.
  SET PF-STATUS 'STATUS_0100'.
  SET TITLEBAR  'TITLE_0100'.
  IF gv_user_level IS INITIAL.
    PERFORM check_user_authorization CHANGING gv_user_level.
  ENDIF.
ENDMODULE.

MODULE user_command_0100 INPUT.
  CASE sy-ucomm.
    WHEN 'APPR'. CLEAR: gv_aufnr, gt_items_tc. LEAVE TO SCREEN 0300.
    WHEN 'PEND'. LEAVE TO SCREEN 0310.
    WHEN 'HIST'. LEAVE TO SCREEN 0320.
    WHEN 'MAIL'. LEAVE TO SCREEN 0330.
    WHEN 'EXIT' OR 'BACK' OR 'CANCEL'. LEAVE PROGRAM.
  ENDCASE.
ENDMODULE.
```

---

### **STEP 10 — Screen 0310 (Pending with LVL_STATUS)**

```abap
DATA: so_date  TYPE RANGE OF datum,
      so_aufnr TYPE RANGE OF aufnr,
      p_werks  TYPE werks_d.

MODULE set_default_date_range OUTPUT.
  IF so_date IS INITIAL.
    so_date = VALUE #( (
      sign   = 'I' option = 'BT'
      low    = sy-datum - 30 high = sy-datum ) ).
  ENDIF.
ENDMODULE.

FORM load_pending_list.
  CLEAR gt_pending.
  
  " Filter: LVL_STATUS in ('0','1') — not yet final
  SELECT h~aufnr, a~ktext, h~werks,
         h~requested_by, h~requested_date,
         h~appr_status, h~lvl_status
    INTO CORRESPONDING FIELDS OF TABLE @gt_pending
    FROM ztwoapprh AS h
    INNER JOIN aufk AS a ON h~aufnr = a~aufnr
    WHERE h~requested_date IN @so_date
      AND h~aufnr IN @so_aufnr
      AND h~werks = @p_werks
      AND h~lvl_status IN ( '0', '1' ).
  
  LOOP AT gt_pending ASSIGNING FIELD-SYMBOL(<ls>).
    <ls>-aging = sy-datum - <ls>-requested_date.
    SELECT COUNT(*) FROM ztwoappr
      INTO @<ls>-mismatch_cnt
      WHERE aufnr = @<ls>-aufnr AND approval_stat = 'REJECT'.
  ENDLOOP.
ENDFORM.
```

---

### **STEP 11 — Screen 0320 (History — LVL_STATUS=2)**

```abap
FORM load_history.
  TYPES: BEGIN OF ty_history,
           aufnr          TYPE aufnr,
           matnr          TYPE matnr,
           approval_stat  TYPE char20,
           appr_by_lvl1   TYPE syuname,
           appr_date_lvl1 TYPE datum,
           appr_by_lvl3   TYPE syuname,
           appr_date_lvl3 TYPE datum,
           reason_change  TYPE char40,
           reason_reject  TYPE char40,
           appr_valid     TYPE flag,
           agingdays      TYPE int4,
         END OF ty_history.
  
  DATA: gt_history TYPE TABLE OF ty_history.
  
  " History = only finalized (LVL_STATUS=2)
  SELECT i~aufnr, i~matnr, i~approval_stat,
         i~appr_by_lvl1, i~appr_date_lvl1,
         i~appr_by_lvl3, i~appr_date_lvl3,
         i~reason_change, i~reason_reject,
         i~appr_valid, i~agingdays
    INTO TABLE @gt_history
    FROM ztwoappr AS i
    INNER JOIN ztwoapprh AS h ON h~aufnr = i~aufnr
    WHERE h~lvl_status = '2'
      AND i~appr_date_lvl3 IN @so_hst_dt
      AND i~aufnr IN @so_hst_wo.
ENDFORM.
```

---

### **STEP 12 — Screen 0330 (Manual Email via SBWP)**

```abap
DATA: gv_em_aufnr TYPE aufnr,
      gv_em_type  TYPE char2,
      gv_rad_ho   TYPE char1,
      gv_rad_br   TYPE char1.

MODULE status_0330 OUTPUT.
  SET PF-STATUS 'STATUS_0330'.
  SET TITLEBAR 'TITLE_0330'.
  IF gv_em_type IS INITIAL.
    gv_rad_ho = 'X'.
    gv_em_type = 'HO'.
  ENDIF.
ENDMODULE.

MODULE user_command_0330 INPUT.
  IF gv_rad_ho = 'X'.
    gv_em_type = 'HO'.
  ELSEIF gv_rad_br = 'X'.
    gv_em_type = 'BR'.
  ENDIF.
  
  CASE sy-ucomm.
    WHEN 'SEND'.
      PERFORM send_email_from_0330.
    WHEN 'BACK'.
      LEAVE TO SCREEN 0100.
  ENDCASE.
ENDMODULE.

FORM send_email_from_0330.
  IF gv_em_aufnr IS INITIAL.
    MESSAGE e070(zwo_appr).
  ENDIF.
  
  DATA: lv_cnt TYPE i.
  gv_aufnr = gv_em_aufnr.
  PERFORM compare_wo_vs_tasklist USING gv_em_aufnr CHANGING gt_items_tc lv_cnt.
  
  LOOP AT gt_items_tc ASSIGNING FIELD-SYMBOL(<ls>).
    <ls>-mark = abap_true.
  ENDLOOP.
  
  PERFORM process_send_email USING gv_em_type.
  CLEAR gv_em_aufnr.
ENDFORM.
```

---

## 🎨 SCREEN VIEWS

### Screen 0100 — Main Menu
```
┌───────────────────────────────────────────────────────────────────┐
│  WORK ORDER APPROVAL SYSTEM                    [User: USER001]    │
│  Transaction: ZWOAPP                            [Level: L1]       │
├───────────────────────────────────────────────────────────────────┤
│                                                                    │
│           ┌─────────────────────────────────────────┐             │
│           │   [1] 📋 APPROVAL WORK ORDER            │             │
│           │   [2] ⏳ PENDING APPROVAL               │             │
│           │   [3] 📊 APPROVAL HISTORY               │             │
│           │   [4] 📧 SEND EMAIL (via SBWP DLI)      │             │
│           │   [5] 🚪 EXIT (F3)                      │             │
│           └─────────────────────────────────────────┘             │
└───────────────────────────────────────────────────────────────────┘
```

### Screen 0300 — Approval WO (L1 View)
```
┌──────────────────────────────────────────────────────────────────────────────┐
│ WORK ORDER APPROVAL                             User: BCSPPD01 [L1 - HO]     │
├──────────────────────────────────────────────────────────────────────────────┤
│ WO: [4000001]  Plant: 1000                                                   │
│ APPR_STATUS: 1 (Request)   LVL_STATUS: 0 (Draft)   Aging: 3 days             │
│ Requested By: PLANNER01    Date: 18.04.2026                                  │
├──────────────────────────────────────────────────────────────────────────────┤
│ ┌───┬───┬──────────┬─────────────┬──────┬──────┬──────┬────────────────────┐│
│ │Sel│Ic │Material  │Description  │WO Qty│TL Qty│ Appr │Reason       [▼]    ││
│ ├───┼───┼──────────┼─────────────┼──────┼──────┼──────┼────────────────────┤│
│ │[ ]│🟢 │MAT001    │Bearing 6205 │ 10   │ 10   │ N/A  │         -          ││
│ │[X]│🔴 │MAT999    │Unknown Part │  2   │  -   │ [X]  │C02 - PN ITC    [▼] ││
│ │[X]│🔴 │MAT888    │Extra Filter │  1   │  -   │ [ ]  │R01 - PN Unit Mdl[▼]││
│ └───┴───┴──────────┴─────────────┴──────┴──────┴──────┴────────────────────┘│
│                                                                              │
│ [Save L1] [Email HO (via SBWP)] [Email BR (via SBWP)] [Back]                │
└──────────────────────────────────────────────────────────────────────────────┘
         After Save L1:
         → ZTWOAPPRH.APPR_STATUS = 1
         → ZTWOAPPRH.LVL_STATUS = 1 (L1 Done)
         → Pending L3 review
```

### Screen 0300 — Approval WO (L3 View)
```
┌──────────────────────────────────────────────────────────────────────────────┐
│ WORK ORDER APPROVAL                             User: SDH_USER [L3 - SDH]    │
├──────────────────────────────────────────────────────────────────────────────┤
│ WO: [4000001]  Plant: 1000                                                   │
│ APPR_STATUS: 1 (Request)   LVL_STATUS: 1 (L1 Done)    Aging: 3 days          │
│ L1 Approved By: BCSPPD01 on 20.04.2026                                       │
├──────────────────────────────────────────────────────────────────────────────┤
│ ┌───┬───┬──────────┬─────────────┬──────┬──────┬──────┬────────────────────┐│
│ │Sel│Ic │Material  │Description  │WO Qty│TL Qty│ Appr │L1 Decision         ││
│ ├───┼───┼──────────┼─────────────┼──────┼──────┼──────┼────────────────────┤│
│ │[ ]│🟢 │MAT001    │Bearing 6205 │ 10   │ 10   │ [X]  │    -               ││
│ │[ ]│🔴 │MAT999    │Unknown Part │  2   │  -   │ [X]  │✓ Appr (C02)        ││
│ │[ ]│🔴 │MAT888    │Extra Filter │  1   │  -   │ [ ]  │✗ Reject (R01)      ││
│ └───┴───┴──────────┴─────────────┴──────┴──────┴──────┴────────────────────┘│
│                                                                              │
│ [Save L3 Final] [Email HO] [Email BR] [Back]                                │
└──────────────────────────────────────────────────────────────────────────────┘
         After Save L3:
         → ZTWOAPPRH.APPR_STATUS = 2 (Parts Approved)
         → ZTWOAPPRH.LVL_STATUS = 2 (L3 Done - Final)
         → AUTO EMAIL via SBWP DLI APPR_100_BR
```

### Screen 0310 — Pending (with LVL_STATUS)
```
┌──────────────────────────────────────────────────────────────────────────────┐
│ PENDING APPROVAL (LVL_STATUS = 0 or 1)                                       │
├──────────────────────────────────────────────────────────────────────────────┤
│ Date: [22.03.2026] TO [21.04.2026] (default: 30 days)   Plant: [1000]       │
│                                                            [Execute] [Reset] │
├──────────────────────────────────────────────────────────────────────────────┤
│ ┌──────────┬────────────┬──────┬─────────┬──────────┬──────┬──────┬────────┐│
│ │WO        │Description │Plant │Req By   │Req Date  │Appr  │Lvl   │Aging   ││
│ ├──────────┼────────────┼──────┼─────────┼──────────┼──────┼──────┼────────┤│
│ │4000001   │Maintenance │ 1000 │PLANNER01│18.04.26  │ 1    │ 0    │  3     ││
│ │4000002   │Overhaul    │ 1000 │PLANNER02│19.04.26  │ 1    │ 1    │  2     ││ ←L1 done
│ │4000003   │Inspection  │ 1000 │PLANNER01│20.04.26  │ 1    │ 0    │  1     ││
│ └──────────┴────────────┴──────┴─────────┴──────────┴──────┴──────┴────────┘│
│                                                                              │
│ [Refresh] [Export] [Back]   Double-click → Open in Screen 0300               │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Screen 0330 — Email via SBWP DLI
```
┌──────────────────────────────────────────────────────────────────────────────┐
│ EMAIL NOTIFICATION (via SBWP Distribution List)                              │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Work Order Number:  [4000001____]                                           │
│                                                                              │
│  Email Type:         (●) Submit to BCSPPD HO (DLI: APPR_<plant>_HO)         │
│                      (○) Reminder to Branch  (DLI: APPR_<plant>_BR)         │
│                                                                              │
│  📋 DLI Source:  SBWP > Distribution Lists                                  │
│                  Recipients are maintained by end-users in SBWP             │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ DLI Name:    APPR_100_HO                                              │  │
│  │ Strategy:    Try SHARED → Fallback PERSONAL → Skip if empty           │  │
│  │                                                                       │  │
│  │ Expected recipients from SBWP:                                        │  │
│  │   - Maintained via SBWP transaction                                   │  │
│  │   - Zero code changes when adding/removing users                      │  │
│  │                                                                       │  │
│  │ Items: All rows of WO 4000001                                         │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  [Send Email via BCS] [Back]                                                 │
└──────────────────────────────────────────────────────────────────────────────┘

NOTE: Empty DLI → graceful skip with warning (no dump)
      All sent emails visible in SOST
```

---

## ✅ DEVELOPMENT CHECKLIST (v2.0)

```
┌──────────────────────────────────────────────────────────────────────┐
│                    DEVELOPMENT SEQUENCE                              │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ☐ 1. Create Function Group ZFG_WO_APPROVAL                          │
│  ☐ 2. Create includes (TOP, F01-F08, O01, I01)                       │
│  ☐ 3. Create Message class ZWO_APPR                                  │
│  ☐ 4. Create Module Pool SAPMZWO_APPROVAL                            │
│  ☐ 5. Design Screen 0100 (Main Menu)                                 │
│  ☐ 6. Design Screen 0300 (Table Control with LVL_STATUS display)     │
│  ☐ 7. Design Screen 0310 (Pending — LVL_STATUS filter)               │
│  ☐ 8. Design Screen 0320 (History — LVL_STATUS=2 only)               │
│  ☐ 9. Design Screen 0330 (Email — SBWP DLI input)                    │
│  ☐10. Implement Auth check (F05)                                     │
│  ☐11. Implement TVARVC loader (F07)                                  │
│  ☐12. Implement Comparison (F08)                                     │
│  ☐13. Implement Save L1 → LVL_STATUS=1 (F02)                         │
│  ☐14. Implement Save L3 → LVL_STATUS=2 + auto email (F02)            │
│  ☐15. Implement Email F06 — 4 FORMs (SBWP pattern):                  │
│       ☐ process_send_email   (Orchestrator)                          │
│       ☐ get_email_from_dli   (SO_DLI_READ_API1 — shared + personal)  │
│       ☐ build_email_html     (FIRST/BODY/LAST)                       │
│       ☐ send_email_bcs       (CL_BCS + COMMIT WORK)                  │
│  ☐16. Create DLIs in SBWP (shared):                                  │
│       ☐ APPR_100_HO, APPR_100_BR                                     │
│       ☐ APPR_200_HO, APPR_200_BR                                     │
│       ☐ (per plant as needed)                                        │
│  ☐17. Configure SCOT SMTP node                                       │
│  ☐18. Test SOST after each send                                      │
│  ☐19. Implement Lock/Unlock (F04)                                    │
│  ☐20. Create Transaction ZWOAPP                                      │
│  ☐21. Code Inspector (priority 1 & 2 = 0)                            │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 🧪 TESTING SCENARIOS

### Test Case 1 — L1 Save with LVL_STATUS=1
```
Pre:  WO 4000001 with 2 mismatched parts
      ZTWOAPPRH: APPR_STATUS=0, LVL_STATUS=0

Step: 1. Login as L1 user
      2. Load WO 4000001
      3. Approve MAT999+C02, Reject MAT888+R01
      4. Save

Expect:
  ZTWOAPPRH.APPR_STATUS = 1
  ZTWOAPPRH.LVL_STATUS  = 1   ← L1 Done
  NO email triggered
```

### Test Case 2 — L3 Final with SBWP Email
```
Pre:  WO 4000001 after L1 save
      ZTWOAPPRH: APPR_STATUS=1, LVL_STATUS=1

Step: 1. Login as L3 user
      2. Load WO 4000001
      3. Approve all items
      4. Save

Expect:
  ZTWOAPPRH.APPR_STATUS = 2
  ZTWOAPPRH.LVL_STATUS  = 2   ← Final
  APPROVED_BY/DATE/TIME filled
  Email → SBWP DLI APPR_100_BR (shared/personal)
  Visible in SOST
```

### Test Case 3 — SBWP DLI Empty (Graceful Skip)
```
Pre:  DLI APPR_999_HO does NOT exist

Step: 1. Load WO plant 999
      2. Click Email HO

Expect:
  Shared read fails → Personal read fails
  Warning: "No recipients in DLI APPR_999_HO - skipped"
  NO dump
```

---

## 🔧 CODE QUALITY RULES

1. ✅ **No hardcoded emails** — always SBWP DLI (`SO_DLI_READ_API1`)
2. ✅ **COMMIT WORK** after every `cl_bcs->send( )`
3. ✅ **TRY...CATCH cx_bcs** around all sends
4. ✅ **CHECK NOT recipients IS INITIAL** before send
5. ✅ **i_type='HTM'** for HTML (not 'RAW')
6. ✅ **Set sender** via `cl_cam_address_bcs=>create_internet_address`
7. ✅ **i_express='X'** for priority
8. ✅ **set_send_immediately('X')** to bypass SOST queue
9. ✅ **Shared DLI first**, fallback to personal
10. ✅ **LVL_STATUS validation** — L3 only when LVL_STATUS=1

---

**END OF FILE 1 v2.0 — ABAP PROGRAMMING PROMPT**
