*&---------------------------------------------------------------------*
*& Include         : LZFG_WO_APPROVALTOP
*& Description     : Global Data, Types, Constants, Table Controls
*& Function Group  : ZFG_WO_APPROVAL  (PRD v1.5)
*&---------------------------------------------------------------------*
FUNCTION-POOL zfg_wo_approval.
*----------------------------------------------------------------------*
* TC item type
* Holds one row per WO component (RESB) with its TL counterpart (STPO).
*----------------------------------------------------------------------*
TYPES: BEGIN OF ty_items_tc,
         aufnr          TYPE aufnr,
         rsnum          TYPE rsnum,           " Reservation Number (RESB-RSNUM)
         rspos          TYPE rspos,           " Reservation Item   (RESB-RSPOS)
         plnnr          TYPE plnnr,           " Tasklist Number (VIAUFKS-PLNNR)
         plnal          TYPE plnal,           " Group Counter   (VIAUFKS-PLNAL)
         matnr          TYPE matnr,           " WO PN (RESB-MATNR)
         maktx          TYPE maktx,           " WO PN description
         werks          TYPE werks_d,
         bdmng          TYPE bdmng,           " WO Required Qty
         meins          TYPE meins,
         pn_tasklist    TYPE matnr,           " TL PN (STPO-IDNRK)
         desc_tasklist  TYPE maktx,           " TL PN description
         menge_tl       TYPE menge_d,         " Task List Qty (STPO-MENGE)
         meins_tl       TYPE meins,
         comp_status    TYPE char1,           " 'X' = match, ' ' = mismatch
         comp_match     TYPE char3,           " 'Yes' / 'No'
         sermat         TYPE char40,          " Serial Material (AFIH-SERMAT)
         interchange    TYPE char3,           " 'Yes' / 'No' — ZINCHG flag
         interchange_pn TYPE matnr,           " Interchanged PN (ZINCHG-SMATN)
         is_mismatch    TYPE abap_bool,       " Drives row colour
         appr_flag      TYPE char1,           " X = Approved
         approval_stat  TYPE zde_apprstat,     " ZTWOAPPR-APPROVAL_STAT
         mark           TYPE char1,           " Checkbox mark
         l1_approved    TYPE abap_bool,
         l3_approved    TYPE abap_bool,
         reason_code    TYPE char10,
         reason_reject  TYPE char40,
         reason_change  TYPE char40,
         row_color      TYPE lvc_t_scol,
       END OF ty_items_tc.

*----------------------------------------------------------------------*
* Bulk-fetch work types (ported from report)
*   ty_comp     — RESB × VIAUFKS join (one row per WO component)
*   ty_tasklist — PLMZ × STPO join  (one row per BOM item per tasklist)
*----------------------------------------------------------------------*
TYPES: BEGIN OF ty_comp,
         aufnr TYPE aufnr,
         rsnum TYPE rsnum,
         rspos TYPE rspos,
         matnr TYPE matnr,
         maktx TYPE maktx,
         bdmng TYPE bdmng,
         meins TYPE meins,
         plnnr  TYPE plnnr,
         plnty  TYPE plnty,
         plnal  TYPE plnal,
         werks  TYPE werks_d,
         sermat TYPE char40,
         erdat  TYPE erdat,
         aedat  TYPE aedat,
       END OF ty_comp,

       BEGIN OF ty_tasklist,
         plnnr TYPE plnnr,
         plnal TYPE plnal,
         stlnr TYPE stnum,
         stlkn TYPE stlkn,
         idnrk TYPE matnr,
         menge TYPE menge_d,
         maktx TYPE maktx,
       END OF ty_tasklist.

TYPES: BEGIN OF ty_reason,
         reason_code TYPE char10,
         reason_desc TYPE char60,
       END OF ty_reason.

TYPES: BEGIN OF ty_email_recipient,
         recipient TYPE ad_smtpadr,
         name      TYPE so_obj_des,
       END OF ty_email_recipient.

*----------------------------------------------------------------------*
* CONSTANTS
*----------------------------------------------------------------------*
CONSTANTS: BEGIN OF gc_user_lvl,
             l1 TYPE char2 VALUE 'L1', "BCSPPD HO
             l3 TYPE char2 VALUE 'L3', "SDH
             l4 TYPE char2 VALUE 'L4', "BRANCH
             l5 TYPE char2 VALUE 'L5', "Helpdesk
           END OF gc_user_lvl.

CONSTANTS: BEGIN OF gc_appr_status,
             draft     TYPE char1 VALUE '0',
             submitted TYPE char1 VALUE '1',
             approved  TYPE char1 VALUE '2',
           END OF gc_appr_status.

*----------------------------------------------------------------------*
* GLOBAL DATA
*----------------------------------------------------------------------*
DATA: gv_aufnr        TYPE aufnr,
      gv_aufnr_from   TYPE aufnr,
      gv_aufnr_to     TYPE aufnr,
      gv_werks        TYPE werks_d,
      gv_user_level   TYPE char2,
      gv_locked       TYPE abap_bool,
      gv_screen_locked TYPE abap_bool,
      gv_open_from_pending TYPE abap_bool.  " Set when 0310 'Open WO' navigates to 0300

DATA: r_swerk TYPE RANGE OF werks_d.

DATA: gt_items_tc       TYPE STANDARD TABLE OF ty_items_tc,
      gs_items_tc       TYPE ty_items_tc,
      gt_selected       TYPE STANDARD TABLE OF ty_items_tc,
      gt_recipients     TYPE STANDARD TABLE OF ty_email_recipient,
      gt_reject_reasons TYPE STANDARD TABLE OF ty_reason,
      gt_change_reasons TYPE STANDARD TABLE OF ty_reason.

*----------------------------------------------------------------------*
* Bulk-fetch work tables (rebuilt every load)
*----------------------------------------------------------------------*
DATA: gt_comp     TYPE STANDARD TABLE OF ty_comp,
      gs_comp     TYPE ty_comp,
      gt_tasklist TYPE STANDARD TABLE OF ty_tasklist,
      gs_tasklist TYPE ty_tasklist.

*----------------------------------------------------------------------*
* SCREEN INPUT FIELDS
*----------------------------------------------------------------------*
DATA: p_email_type TYPE char2,         " 'HO' or 'BR'
      p_wo_mail    TYPE aufnr.         " WO for Screen 0330 load

*----------------------------------------------------------------------*
* OK Code / Function Code
*----------------------------------------------------------------------*
DATA: ok_code TYPE sy-ucomm,
      save_ok TYPE sy-ucomm.

*----------------------------------------------------------------------*
* GUI Status & Title Variables
*----------------------------------------------------------------------*
DATA: gv_status_0100 TYPE sy-pfkey VALUE 'ZSTAT_0100',
      gv_title_0100  TYPE sy-title VALUE 'Work Order Approval - Main Menu',
      gv_status_0300 TYPE sy-pfkey VALUE 'ZSTAT_0300',
      gv_title_0300  TYPE sy-title VALUE 'Work Order Approval - Entry',
      gv_status_0310 TYPE sy-pfkey VALUE 'ZSTAT_0310',
      gv_title_0310  TYPE sy-title VALUE 'Work Order Approval - Pending List',
      gv_status_0320 TYPE sy-pfkey VALUE 'ZSTAT_0320',
      gv_title_0320  TYPE sy-title VALUE 'Work Order Approval - History',
      gv_status_0330 TYPE sy-pfkey VALUE 'ZSTAT_0330',
      gv_title_0330  TYPE sy-title VALUE 'Work Order Approval - Manual Email'.

*----------------------------------------------------------------------*
* Constants for GUI Status
*----------------------------------------------------------------------*
CONSTANTS:
  BEGIN OF gc_status,
    main    TYPE sy-pfkey VALUE 'ZSTAT_0100',
    entry   TYPE sy-pfkey VALUE 'ZSTAT_0300',
    pending TYPE sy-pfkey VALUE 'ZSTAT_0310',
    history TYPE sy-pfkey VALUE 'ZSTAT_0320',
    email   TYPE sy-pfkey VALUE 'ZSTAT_0330',
  END OF gc_status.

*----------------------------------------------------------------------*
* Constants for GUI Title
*----------------------------------------------------------------------*
CONSTANTS:
  BEGIN OF gc_title,
    main    TYPE sy-title VALUE 'WO Approval: Main Menu',
    entry   TYPE sy-title VALUE 'WO Approval: Entry',
    pending TYPE sy-title VALUE 'WO Approval: Pending List',
    history TYPE sy-title VALUE 'WO Approval: History',
    email   TYPE sy-title VALUE 'WO Approval: Manual Email',
  END OF gc_title.

*----------------------------------------------------------------------*
* TABLE CONTROL
*----------------------------------------------------------------------*
*&SPWIZARD: DECLARATION OF TABLECONTROL 'TC_ITEMS' ITSELF
CONTROLS: TC_ITEMS TYPE TABLEVIEW USING SCREEN 0300.

*----------------------------------------------------------------------*
* EVENT HANDLER CLASS — ALV double-click for Screen 0310
* (DEFINITION only — IMPLEMENTATION lives in LZFG_WO_APPROVALF07)
*----------------------------------------------------------------------*
CLASS lcl_alv_event_0310 DEFINITION.
  PUBLIC SECTION.
    METHODS handle_dblclick_0310
      FOR EVENT double_click OF cl_gui_alv_grid
      IMPORTING e_row e_column.
ENDCLASS.

*----------------------------------------------------------------------*
* ALV OBJECTS — Screen 0310 (Pending List)
*----------------------------------------------------------------------*
DATA: gv_0310_initialized TYPE abap_bool,
      gr_alv_0310         TYPE REF TO cl_gui_alv_grid,
      gr_cont_0310        TYPE REF TO cl_gui_custom_container,
      go_evt_0310         TYPE REF TO lcl_alv_event_0310,
      gt_fcat_0310        TYPE lvc_t_fcat,
      gs_layout_0310      TYPE lvc_s_layo,
      gt_pending_wo       TYPE STANDARD TABLE OF ztwoapprh.


*----------------------------------------------------------------------*
* ALV OBJECTS — Screen 0320 (Approval History)
*----------------------------------------------------------------------*
TYPES: BEGIN OF ty_appr_history.       " ztwoappr + WERKS from header
  INCLUDE STRUCTURE ztwoappr.
TYPES: werks TYPE werks_d,             " Plant joined from ZTWOAPPRH
       END OF ty_appr_history.

DATA: gv_0320_initialized TYPE abap_bool,
      gr_alv_0320         TYPE REF TO cl_gui_alv_grid,
      gr_cont_0320        TYPE REF TO cl_gui_custom_container,
      gt_fcat_0320        TYPE lvc_t_fcat,
      gs_layout_0320      TYPE lvc_s_layo,
      gt_appr_history     TYPE STANDARD TABLE OF ty_appr_history.

*----------------------------------------------------------------------*
* TREE OBJECTS — Screen 0310 (Pending WO Tree Filter)
*----------------------------------------------------------------------*
CLASS lcl_tree_event_0310 DEFINITION DEFERRED.
CLASS cl_gui_cfw DEFINITION LOAD.

TYPES: item_table_0310_type LIKE STANDARD TABLE OF mtreeitm
         WITH DEFAULT KEY.

DATA: gv_0310_tree_initialized TYPE abap_bool,
      gr_tree_0310              TYPE REF TO cl_gui_list_tree,
      gr_tree_cont_0310         TYPE REF TO cl_gui_custom_container,
      go_tree_evt_0310          TYPE REF TO lcl_tree_event_0310,
      gv_tree_selected_key      TYPE tv_nodekey,
      gt_pending_tree           TYPE STANDARD TABLE OF ztwoapprh.

*DATA: BEGIN OF gt_node OCCURS 0,
*        node_key TYPE tv_nodekey,
*        aufnr    TYPE aufk-aufnr,
*      END OF gt_node.

TYPES: BEGIN OF ty_tree_key,
         node_key TYPE tv_nodekey,
         aufnr    TYPE aufnr,
       END OF ty_tree_key.

DATA: gt_tree_keys TYPE ty_tree_key OCCURS 0,
      ls_tree_key  TYPE ty_tree_key.

*----------------------------------------------------------------------*
*  v1.8 — SCREEN 0312 (Pending Approval) filter subscreen
*  Plant + WO range. Default plant filled from r_swerk in PBO.
*  Embedded into Screen 0310 via subscreen area SS_310.
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF SCREEN 0312 AS SUBSCREEN.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT (10) text-p01 FOR FIELD s_w310.
    SELECT-OPTIONS s_w310 FOR aufk-werks.       " Plant
  SELECTION-SCREEN END OF LINE.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT (10) text-p02 FOR FIELD s_a310.
    SELECT-OPTIONS s_a310 FOR aufk-aufnr.       " Work Order
  SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF SCREEN 0312.

*----------------------------------------------------------------------*
* Tree node key constants for Screen 0310
*----------------------------------------------------------------------*
CONSTANTS:
  BEGIN OF gc_tree_0310,
    root    TYPE tv_nodekey VALUE 'PEND_ROOT',
    monthly TYPE tv_nodekey VALUE 'MONTHLY',
    weekly  TYPE tv_nodekey VALUE 'WEEKLY',
  END OF gc_tree_0310.

*----------------------------------------------------------------------*
* Event handler class DEFINITION — tree node/item click for Screen 0310
* IMPLEMENTATION lives in LZFG_WO_APPROVALF07
*----------------------------------------------------------------------*
CLASS lcl_tree_event_0310 DEFINITION.
  PUBLIC SECTION.
    METHODS handle_node_dblclick_0310
      FOR EVENT node_double_click
      OF cl_gui_list_tree
      IMPORTING node_key.
    METHODS handle_item_dblclick_0310
      FOR EVENT item_double_click
      OF cl_gui_list_tree
      IMPORTING node_key item_name.
ENDCLASS.

*----------------------------------------------------------------------*
* ALV OBJECTS — Screen 0330 (Manual Email Send)
*----------------------------------------------------------------------*
DATA: gv_0330_initialized TYPE abap_bool,
      gr_alv_0330         TYPE REF TO cl_gui_alv_grid,
      gr_cont_0330        TYPE REF TO cl_gui_custom_container,
      gt_fcat_0330        TYPE lvc_t_fcat,
      gs_layout_0330      TYPE lvc_s_layo.

*----------------------------------------------------------------------*
* NAVIGATION FLAGS (screen-to-screen source tracking)
*----------------------------------------------------------------------*
DATA: gv_0300_initialized TYPE abap_bool.

*----------------------------------------------------------------------*
* SUBSCREEN 0301 — WO Range Header
* Embedded into Screen 0300 via subscreen area SS_300.
* Flow logic: CALL SUBSCREEN ss_300 INCLUDING sy-repid '0301'.
* s_aufnr = SELECT-OPTIONS range for Work Order number (AUFNR).
* SAP auto-generates Screen 0301 from this block on activation.
*----------------------------------------------------------------------*
TABLES: aufk.

SELECTION-SCREEN BEGIN OF SCREEN 0301 AS SUBSCREEN.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT (10) text-001 FOR FIELD s_aufnr.
    SELECT-OPTIONS s_aufnr FOR aufk-aufnr.
  SELECTION-SCREEN END OF LINE.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT (10) text-002 FOR FIELD s_werks.
    SELECT-OPTIONS s_werks FOR aufk-werks.
  SELECTION-SCREEN END OF LINE.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT (10) text-003 FOR FIELD s_erdat.
    SELECT-OPTIONS s_erdat FOR aufk-erdat.
  SELECTION-SCREEN END OF LINE.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT (10) text-004 FOR FIELD s_aedat.
    SELECT-OPTIONS s_aedat FOR aufk-aedat.
  SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF SCREEN 0301.

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
*  L1 (HO/BCSPPD) sends approval result   to Branch  -> 'BR'
*  L4 (Branch)    sends review request     to HO      -> 'HO'
*  L5 (Helpdesk)  can send both directions.
*----------------------------------------------------------------------*
CONSTANTS:
  BEGIN OF gc_send_mode,
    ho TYPE char2 VALUE 'HO',     " L4 Branch -> HO: request for review
    br TYPE char2 VALUE 'BR',     " L1 HO     -> Branch: approval result
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