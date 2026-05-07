*&---------------------------------------------------------------------*
*& Report ZR_SVC_WO_APPROVAL
*&---------------------------------------------------------------------*
*& Developer    : Viandra Fajar
*& Created on   : 21.11.2025
*& Function     : Service Work Order Parts PN Approval Report
*&---------------------------------------------------------------------*
REPORT zr_svc_wo_approval.

*----------------------------------------------------------------------*
* Tables Declaration
*----------------------------------------------------------------------*
TABLES: aufk,      " Order Master Data
        afih,      " Maint Order Header
        afko,      " Maint Order Operations
        makt,      " Material Descriptions
        t001w,
        ztwoappr.  " WO Approval Table

*----------------------------------------------------------------------*
* Type Definition: Component Table (from RESB + VIAUFKS)
*----------------------------------------------------------------------*
TYPES: BEGIN OF ty_comp,
         aufnr TYPE aufnr,           " Work Order Number
         rsnum TYPE rsnum,           " Reservation Number
         rspos TYPE rspos,           " Reservation Item
         matnr TYPE matnr,           " Material Number (WO Component)
         bdmng TYPE bdmng,           " Requirement Quantity
         plnnr TYPE plnnr,           " Tasklist Number (from VIAUFKS)
         plnty TYPE plnty,           " Tasklist Type (from VIAUFKS)
         plnal TYPE plnal,           " Group Counter (from VIAUFKS)
         werks TYPE werks_d,         " Plant (from VIAUFKS)
         maktx TYPE maktx,           " Material Description
         meins TYPE meins,              " Base Unit of Measure
       END OF ty_comp.

*----------------------------------------------------------------------*
* Type Definition: Tasklist Table (from STPO)
*----------------------------------------------------------------------*
TYPES: BEGIN OF ty_tasklist,
         plnnr TYPE plnnr,           " Tasklist Number (VIAUFKS)
         plnal TYPE plnal,           " Group Counter
         stlnr TYPE stnum,           " BOM Number (PLMZ)
         stlkn TYPE stlkn,           " BOM Item Node
         idnrk TYPE idnrk,           " Component Material
         menge TYPE kmpmg,           " Component Quantity
         maktx TYPE maktx,           " Material Description
       END OF ty_tasklist.

*----------------------------------------------------------------------*
* Type Definition: ALV Output Table
*----------------------------------------------------------------------*
TYPES: BEGIN OF ty_alv_output,
         selected           TYPE char1,           " Checkbox selection
         traffic_light      TYPE icon_d,          " Traffic Light Icon
         aedat              TYPE aedat,           " Request Date
         gsber              TYPE gsber,           " Business Area
         werks              TYPE werks_d,         " Plant
         equ_matnr          TYPE matnr,           " Equipment Model (EQUI-MATNR)
         equnr              TYPE equnr,           " Equipment Number
         aufnr              TYPE aufnr,           " Work Order Number
         rsnum              TYPE rsnum,           " Reservation Number
         rspos              TYPE rspos,           " Reservation Item
         matnr              TYPE matnr,           " Material Number
         interchange        TYPE char3,           " Interchange Flag
         interchange_pn     TYPE matnr,           " Interchanged Part Number
         sermat             TYPE matnr,           " Material
         agingdays          TYPE int4,            " Aging in Days
         approver           TYPE syuname,         " Approver Username
         approval_stat      TYPE char20,          " Approval Status
         chk_bcsppd         TYPE char1,           " Checkbox BCSPPD Approved
         chk_pdh            TYPE char1,           " Checkbox PDH Approved
         chk_sdh            TYPE char1,           " Checkbox SDH Approved
         approval_lvl1      TYPE char1,           " Approval Level 1 Flag (BCSPPD)
         approval_lvl2      TYPE char1,           " Approval Level 2 Flag (PDH)
         approval_lvl3      TYPE char1,           " Approval Level 3 Flag (SDH)
         approved_by_lvl1   TYPE syuname,         " Approved By User - Level 1 (BCSPPD)
         approved_date_lvl1 TYPE datum,           " Approval Date - Level 1 (BCSPPD)
         approved_time_lvl1 TYPE uzeit,           " Approval Time - Level 1 (BCSPPD)
         approved_by_lvl3   TYPE syuname,         " Approved By User - Level 3 (SDH)
         approved_date_lvl3 TYPE datum,           " Approval Date - Level 3 (SDH)
         approved_time_lvl3 TYPE uzeit,           " Approval Time - Level 3 (SDH)
         serialnr           TYPE gernr,           " Serial Number
         warpl              TYPE warpl,           " Maintenance Planning
         abnum              TYPE abnum,           " Call Number
         maufnr             TYPE maufnr,          " Superior Order
         auart              TYPE aufart,          " Order Type
         plnnr              TYPE plnnr,           " Tasklist Number
         stlnr              TYPE stnum,           " BOM Number for tasklist
         pn_tasklist        TYPE matnr,           " Part Number from Tasklist
         desc_tasklist      TYPE maktx,           " Description from Tasklist
         qty_tasklist       TYPE menge_d,         " Quantity from Tasklist
         map_tasklist       TYPE verpr,           " MAP from Tasklist
         pn_workorder       TYPE matnr,           " Part Number from WO
         desc_workorder     TYPE maktx,           " Description from WO
         qty_workorder      TYPE menge_d,         " Quantity from WO
         map_workorder      TYPE verpr,           " MAP from WO
         reason_change      TYPE char100,         " Reason for Change
         reason_reject      TYPE char100,         " Reason for Rejection
         created_date       TYPE datum,           " Created Date
         approved_date      TYPE datum,           " Approved Date
         change_id          TYPE char10,          " Change ID
         comp_match         TYPE char3,           " Component Match (Yes/No)
         comp_status        TYPE char1,           " Component Match Flag (X=Match, space=Mismatch)
         need_ho            TYPE char1,           " Need HO Approval Flag (X=needs L1, space=skip L1)
         linecolor          TYPE char4,           " Row color (C6xx = Red for mismatch)
         appr_valid         TYPE char1,           " Approval Validation Flag (X=Valid for APVD/Release)
         waers              TYPE waers,           " Currency Key (MBEW-VERPR) => IDR
         meins              TYPE meins,           " Base Unit of Measure (from RESB-BDMNG)
       END OF ty_alv_output.

" Email Recipients Type
TYPES: BEGIN OF ty_email_recipient,
         recipient TYPE ad_smtpadr,  " Email address
         name      TYPE string,      " Recipient name
       END OF ty_email_recipient.

TYPES: tt_email_recipients TYPE TABLE OF ty_email_recipient.

TYPES: tt_aufnr_range TYPE RANGE OF aufnr.

*----------------------------------------------------------------------*
* Include for Icons
*----------------------------------------------------------------------*
INCLUDE <icon>.

*----------------------------------------------------------------------*
* Internal Tables and Work Areas
*----------------------------------------------------------------------*
DATA: gt_alv_data           TYPE TABLE OF ty_alv_output,
      gs_alv_data           TYPE ty_alv_output,
      gt_comp               TYPE TABLE OF ty_comp,        " Component data from RESB
      gs_comp               TYPE ty_comp,                 " component
      gt_tasklist           TYPE TABLE OF ty_tasklist,    " Tasklist data from STPO
      gs_tasklist           TYPE ty_tasklist,             " tasklist
      gt_fieldcat           TYPE slis_t_fieldcat_alv,
      gs_fieldcat           TYPE slis_fieldcat_alv,
      gs_layout             TYPE slis_layout_alv,
      gv_repid              TYPE sy-repid,
      "ALV Attachment
      gt_list_top_of_page   TYPE slis_t_listheader,  " Header ALV
      gt_events             TYPE slis_t_event,       " Event table
      gv_lines              TYPE i,                  " Total records
      "Email Processing
      gt_selected           TYPE TABLE OF ty_alv_output,     " Selected items for email
      gt_recipients         TYPE TABLE OF ty_email_recipient, " Email recipients
      "Dropdown Lists for ALV
      gt_dropdown_change    TYPE lvc_t_dral,         " Dropdown for Reason Change
      gt_dropdown_reject    TYPE lvc_t_dral,         " Dropdown for Reason Reject
      "Authorization Flags
      "gv_auth_pdh           TYPE flag,              " No PDH
      gv_auth_sdh           TYPE flag,              " SDH Authorization
      gv_auth_bcsppd        TYPE flag,              " BCSPPD Authorization
      gv_auth_branch        TYPE flag,              " Branch User Authorization
      gv_auth_helpdesk      TYPE flag,              " HELPDESK Authorization (L5) - Full Access
      gv_auth_level         TYPE char20,            " Authorization Level (L1/L3/L4/L5) No PDH
      gv_werks_not_in_param TYPE flag.             " Flag: WERKS not in APPROVAL_WO_KEY_GEN

RANGES: r_swerk FOR t001w-werks.
*----------------------------------------------------------------------*
* Selection Screen - Block 1: Basic Filter Criteria
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
  SELECT-OPTIONS: s_date  FOR aufk-aedat, "Created on WO
                  s_gsber FOR aufk-gsber, "OBLIGATORY,
                  s_werks FOR aufk-werks OBLIGATORY,
                  s_equnr FOR afih-equnr,
                  s_aufnr FOR aufk-aufnr,
                  s_matnr FOR makt-matnr.
  "PARAMETERS: p_aufnr TYPE aufk-aufnr.
SELECTION-SCREEN END OF BLOCK b1.

*----------------------------------------------------------------------*
* Selection Screen - Block 2: Advanced Filters
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-002.
  PARAMETERS: p_intch TYPE char3 AS LISTBOX VISIBLE LENGTH 15 DEFAULT 'ALL'.
  SELECT-OPTIONS: s_age FOR ztwoappr-agingdays, "aging Days Approval
                  s_appby FOR sy-uname.
SELECTION-SCREEN END OF BLOCK b2.

*----------------------------------------------------------------------*
* Selection Screen - Block 3: Approval Status Filter
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE TEXT-003.
  PARAMETERS: rb_all  RADIOBUTTON GROUP grp1 DEFAULT 'X',
              rb_pend RADIOBUTTON GROUP grp1,
              rb_appr RADIOBUTTON GROUP grp1,
              rb_rejt RADIOBUTTON GROUP grp1.
SELECTION-SCREEN END OF BLOCK b3.

*----------------------------------------------------------------------*
* Initialization
*----------------------------------------------------------------------*
INITIALIZATION.
  gv_repid = sy-repid.
  PERFORM init_listbox.


  " If date range not provided, Using current month range
*  DATA: ls_date_line LIKE LINE OF s_date,
*        lv_first_day TYPE sy-datum,
*        lv_last_day  TYPE sy-datum.
*
*  IF s_date[] IS INITIAL.
*    " Get first day of current month
*    lv_first_day = sy-datum.
*    lv_first_day+6(2) = '01'.
*
*    " last day of current month
*    CALL FUNCTION 'RP_LAST_DAY_OF_MONTHS'
*      EXPORTING
*        day_in            = sy-datum
*      IMPORTING
*        last_day_of_month = lv_last_day.
*
*    ls_date_line-sign = 'I'.
*    ls_date_line-option = 'BT'.
*    ls_date_line-low = lv_first_day.
*    ls_date_line-high = lv_last_day.
*    APPEND ls_date_line TO s_date.
*  ENDIF.

*----------------------------------------------------------------------*
* At Selection Screen - Input Validation
*----------------------------------------------------------------------*
AT SELECTION-SCREEN.
  PERFORM check_authorization.

  " Validate date range (check first interval if provided)
  DATA: ls_age_line  LIKE LINE OF s_age.

  LOOP AT s_date INTO DATA(ls_date_line).
    IF ls_date_line-option = 'BT' AND ls_date_line-high IS NOT INITIAL.
      IF ls_date_line-low > ls_date_line-high.
        MESSAGE 'From date cannot be greater than To date' TYPE 'E'.
      ENDIF.
    ENDIF.
  ENDLOOP.

  " Validate aging range (check first interval if provided)
  IF s_age[] IS NOT INITIAL.
    READ TABLE s_age INDEX 1 INTO ls_age_line.
    IF ls_age_line-high IS NOT INITIAL AND ls_age_line-low > ls_age_line-high.
      MESSAGE 'From aging cannot be greater than To aging' TYPE 'E'.
    ENDIF.
  ENDIF.

  " Validate WO REQU status, Skip for L5
*  IF s_aufnr[] IS NOT INITIAL AND gv_auth_level <> 'L5'.
*    LOOP AT s_aufnr INTO DATA(ls_aufnr_line).
*      PERFORM validate_wo_requ_status USING ls_aufnr_line-low.
*      IF ls_aufnr_line-high IS NOT INITIAL.
*        PERFORM validate_wo_requ_status USING ls_aufnr_line-high.
*      ENDIF.
*    ENDLOOP.
*  ENDIF.

  "Validate WO Comp and Approval Status
  IF s_aufnr[] IS NOT INITIAL.
    PERFORM validate_wo_appr_status.
  ENDIF.

*----------------------------------------------------------------------*
* Start of Selection
*----------------------------------------------------------------------*
START-OF-SELECTION.
  PERFORM fetch_data.

  IF gt_alv_data IS INITIAL.
    IF gv_werks_not_in_param = 'X'.
      MESSAGE 'Plant is not maintained in APPROVAL_WO_KEY_GEN parameter' TYPE 'S' DISPLAY LIKE 'W'.
    ELSE.
      MESSAGE 'No data found for the selected criteria' TYPE 'S' DISPLAY LIKE 'W'.
    ENDIF.
  ELSE.
    DESCRIBE TABLE gt_alv_data LINES gv_lines. "Count total records
    PERFORM display_alv.
  ENDIF.

*&---------------------------------------------------------------------*
*& Form init_listbox
*&---------------------------------------------------------------------*
*& Initialize Interchangeability dropdown listbox
*&---------------------------------------------------------------------*
FORM init_listbox.
  DATA: lt_values TYPE vrm_values,
        ls_value  TYPE vrm_value.

  " Add 'All' option
  ls_value-key = 'A'.
  ls_value-text = 'All'.
  APPEND ls_value TO lt_values.

  " Add 'Yes' option
  ls_value-key = 'Y'.
  ls_value-text = 'Yes'.
  APPEND ls_value TO lt_values.

  " Add 'No' option
  ls_value-key = 'N'.
  ls_value-text = 'No'.
  APPEND ls_value TO lt_values.

  " Set values for dropdown
  CALL FUNCTION 'VRM_SET_VALUES'
    EXPORTING
      id     = 'P_INTCH'
      values = lt_values.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form check_authorization
*&---------------------------------------------------------------------*
*& Check user authorization for ZWO_APPR object
*& L1=BCSPPD, L3=SDH, L4=Branch  (L2=PDH removed from approval flow)
*&---------------------------------------------------------------------*
FORM check_authorization.

  DATA: lv_gsber TYPE gsber,
        lv_werks TYPE werks_d.
  REFRESH: r_swerk.
  " Initialize authorization flags
  CLEAR: gv_auth_sdh, gv_auth_bcsppd, gv_auth_branch, gv_auth_helpdesk, gv_auth_level. " gv_auth_pdh removed

  " Check HELPDESK Authorization (L5) FIRST - Full Approval
  AUTHORITY-CHECK OBJECT 'ZWO_APPR'
    ID 'ACTVT' FIELD '02'
    ID 'APPR_LEVEL' FIELD 'L5'.

  IF sy-subrc = 0.
    gv_auth_helpdesk = 'X'.
    gv_auth_level = 'L5'.
  ELSE.
    " Only check lower levels if user is NOT Helpdesk (L5)
    " This prevents dual-flag (e.g. HELPDESK + BCSPPD both 'X')

    " Check BCSPPD Authorization (L1) with user input GSBER/WERKS
    AUTHORITY-CHECK OBJECT 'ZWO_APPR'
      ID 'ACTVT' FIELD '02'
      ID 'APPR_LEVEL' FIELD 'L1'.
    IF sy-subrc = 0.
      gv_auth_bcsppd = 'X'.
      IF gv_auth_level IS INITIAL.
        gv_auth_level = 'L1'.
      ENDIF.
    ENDIF.

*    " Check PDH Authorization (L2) with user input GSBER/WERKS
*    AUTHORITY-CHECK OBJECT 'ZWO_APPR'
*      ID 'ACTVT' FIELD '02'
*      ID 'APPR_LEVEL' FIELD 'L2'.
*    IF sy-subrc = 0.
*      gv_auth_pdh = 'X'.
*      IF gv_auth_level IS INITIAL.
*        gv_auth_level = 'L2'.
*      ENDIF.
*    ENDIF.

    " Check SDH Authorization (L3) with user input GSBER/WERKS
    AUTHORITY-CHECK OBJECT 'ZWO_APPR'
      ID 'ACTVT' FIELD '02'
      ID 'APPR_LEVEL' FIELD 'L3'.
    IF sy-subrc = 0.
      gv_auth_sdh = 'X'.
      IF gv_auth_level IS INITIAL.
        gv_auth_level = 'L3'.
      ENDIF.
    ENDIF.

    " Check Branch Authorization (L4) with user input GSBER/WERKS
    AUTHORITY-CHECK OBJECT 'ZWO_APPR'
      ID 'ACTVT' FIELD '02'
      ID 'APPR_LEVEL' FIELD 'L4'.
    IF sy-subrc = 0.
      gv_auth_branch = 'X'.
      IF gv_auth_level IS INITIAL.
        gv_auth_level = 'L4'.
      ENDIF.
    ENDIF.
  ENDIF.

  SELECT * FROM t001w WHERE werks IN s_werks.
    AUTHORITY-CHECK OBJECT 'I_SWERK'
             ID 'TCD' FIELD 'IW33'
             ID 'SWERK' FIELD t001w-werks.
    IF sy-subrc = 0.
      r_swerk-sign = 'I'. r_swerk-option = 'EQ'.
      r_swerk-low = t001w-werks.
      APPEND r_swerk.
    ENDIF.

  ENDSELECT.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form validate_wo_requ_status
*&---------------------------------------------------------------------*
*& Checks if REQU status from STSMA 'UT_TECO' has been reached
*& If not setting, shows error "Please trigger the WO save first"
*&---------------------------------------------------------------------*
*FORM validate_wo_requ_status USING iv_aufnr TYPE aufnr.
*
*  DATA: lv_aufnr_conv TYPE aufnr,
*        lv_objnr      TYPE j_objnr,
*        lv_stsma      TYPE j_stsma,
*        lv_estat      TYPE j_estat,
*        lv_inact      TYPE j_inact.
*
*  CONSTANTS: lc_stat_profile TYPE j_stsma VALUE 'UT_TECO',
*             lc_stat_requ    TYPE j_txt04 VALUE 'REQU'.
*
*  " Convert Order Number (add leading zeros)
*  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
*    EXPORTING
*      input  = iv_aufnr
*    IMPORTING
*      output = lv_aufnr_conv.
*
*  " Validate Work Order exists in AUFK
*  SELECT SINGLE aufnr INTO @DATA(lv_aufnr)
*    FROM aufk
*    WHERE aufnr = @lv_aufnr_conv.
*
*  IF sy-subrc <> 0.
*    MESSAGE |Work Order { iv_aufnr } not found| TYPE 'E'.
*  ENDIF.
*
*  " Build Object Number (Format: OR + 12-digit order number)
*  CONCATENATE 'OR' lv_aufnr_conv INTO lv_objnr.
*
*  " Get Status Profile assigned to this Work Order from JSTO
*  SELECT SINGLE stsma INTO @lv_stsma
*    FROM jsto
*    WHERE objnr = @lv_objnr.
*
*  IF lv_stsma IS INITIAL.
*    MESSAGE |Work Order { iv_aufnr }: No status profile assigned| TYPE 'E'.
*  ENDIF.
*
*  " Get ESTAT for REQU from TJ30/TJ30T
*  SELECT SINGLE a~estat INTO @lv_estat
*    FROM tj30 AS a
*    INNER JOIN tj30t AS b ON a~stsma = b~stsma
*                          AND a~estat = b~estat
*    WHERE a~stsma = @lv_stsma
*      AND b~spras = @sy-langu
*      AND b~txt04 = @lc_stat_requ.
*
*  IF sy-subrc <> 0.
*    MESSAGE |Work Order { iv_aufnr }: REQU status not found in profile { lv_stsma }| TYPE 'E'.
*  ENDIF.
*
*  " Check if REQU is active in JEST
*  SELECT SINGLE inact INTO @lv_inact
*    FROM jest
*    WHERE objnr = @lv_objnr
*      AND stat  = @lv_estat.
*
*  IF sy-subrc <> 0 OR lv_inact <> space.
*    " REQU status is NOT active - show popup error
*    MESSAGE 'The Work Order is not yet in Requested Approval (REQU) status. Please Save WO first in IW32 before continue.' TYPE 'I' DISPLAY LIKE 'E'.
*    STOP.
*  ENDIF.
*
*ENDFORM.

*&---------------------------------------------------------------------*
*& Form validate_wo_approval_status
*&---------------------------------------------------------------------*
*& Validate WO components and approval status before processing
*& => If WO has no components "Component is Empty, Don't need approval WO"
*& => If ALL components have appr_valid = 'X' "Approval has Completed"
*&---------------------------------------------------------------------*
FORM validate_wo_appr_status.

  DATA: lt_wo_list      TYPE TABLE OF aufnr,
        lt_wo_no_comp   TYPE TABLE OF aufnr,
        lt_wo_completed TYPE TABLE OF aufnr,
        lv_comp_c       TYPE i,
        lv_total_c      TYPE i,
        lv_appr_c       TYPE i,
        lv_msg          TYPE string,
        lv_aufnr        TYPE aufnr.

  LOOP AT s_aufnr INTO DATA(ls_aufnr).
    IF ls_aufnr-option = 'EQ'.
      CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
        EXPORTING
          input  = ls_aufnr-low
        IMPORTING
          output = lv_aufnr.
      APPEND lv_aufnr TO lt_wo_list.
    ELSEIF ls_aufnr-option EQ 'BT' AND ls_aufnr-high IS NOT INITIAL.
      "Range
      SELECT aufnr FROM aufk
        APPENDING TABLE lt_wo_list
        WHERE aufnr BETWEEN ls_aufnr-low AND ls_aufnr-high
          AND werks IN s_werks.
    ENDIF.
  ENDLOOP.

  CHECK lt_wo_list IS NOT INITIAL.

  "Check each WO for Component and Approval Status
  LOOP AT lt_wo_list INTO lv_aufnr.
    CLEAR: lv_comp_c, lv_total_c, lv_appr_c.

    " Count components in RESB (xloek = space means not deleted)
    SELECT COUNT(*) FROM resb INTO lv_comp_c
      WHERE aufnr = lv_aufnr
        AND xloek = space.

    IF lv_comp_c = 0.
      " WO has no components
      APPEND lv_aufnr TO lt_wo_no_comp.
    ELSE.
      " components has all appr_valid = 'X'
      SELECT COUNT(*) FROM ztwoappr
        INTO lv_total_c
        WHERE aufnr = lv_aufnr.

      IF lv_total_c > 0.
        SELECT COUNT(*) FROM ztwoappr
          INTO lv_appr_c
          WHERE aufnr = lv_aufnr
            AND appr_valid = 'X'.

        IF lv_appr_c = lv_total_c AND lv_appr_c > 0.
          " All components are approved
          APPEND lv_aufnr TO lt_wo_completed.
        ENDIF.
      ENDIF.
    ENDIF.
  ENDLOOP.

  " Messages for WOs without components - show popup per WO
  IF lt_wo_no_comp IS NOT INITIAL.
    LOOP AT lt_wo_no_comp INTO lv_aufnr.
      CALL FUNCTION 'CONVERSION_EXIT_ALPHA_OUTPUT'
        EXPORTING
          input  = lv_aufnr
        IMPORTING
          output = lv_aufnr.
      lv_msg = |WO { lv_aufnr }: Component is Empty, Don't need approval WO|.
      MESSAGE lv_msg TYPE 'I'.
    ENDLOOP.
    STOP.
  ENDIF.

  " Messages for WOs with completed approval - show popup per WO
  IF lt_wo_completed IS NOT INITIAL.
    LOOP AT lt_wo_completed INTO lv_aufnr.
      CALL FUNCTION 'CONVERSION_EXIT_ALPHA_OUTPUT'
        EXPORTING
          input  = lv_aufnr
        IMPORTING
          output = lv_aufnr.
      lv_msg = |WO { lv_aufnr }: Approval has Completed, don't need approval again|.
      MESSAGE lv_msg TYPE 'I'.
    ENDLOOP.
    IF gv_auth_helpdesk <> 'X'. " Helpdesk (L5) can still open the report even if approval is completed
      STOP.
    ENDIF.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form fetch_data
*&---------------------------------------------------------------------*
*& Main entry point for data fetching - orchestrates the modular fetch
*&---------------------------------------------------------------------*
FORM fetch_data.
  DATA: lv_status TYPE char20.

  " Clear all tables
  CLEAR: gt_comp, gt_tasklist, gt_alv_data, gv_werks_not_in_param.

  " Step 1: Get status filter
  PERFORM determine_status_filter CHANGING lv_status.

  " Step 2: Fetch RESB and VIAUFKS (BOM Info)
  PERFORM fetch_component_data.

  " Step 3: Fetch STPO
  PERFORM fetch_tasklist_data_bulk.

  " Step 4: Compare RESB-MATNR and STPO-IDNRK to build ALV
  PERFORM compare_and_build_alv USING lv_status.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form determine_status_filter
*&---------------------------------------------------------------------*
*& Determine status filter based on radio button selection
*&---------------------------------------------------------------------*
FORM determine_status_filter CHANGING cv_status TYPE char20.

  CLEAR cv_status.

  IF rb_pend = 'X'.
    cv_status = 'Pending Approve'.
  ELSEIF rb_appr = 'X'.
    cv_status = 'Full Approved'.
  ELSEIF rb_rejt = 'X'.
    cv_status = 'Reject Approval'.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form fetch_component_data
*&---------------------------------------------------------------------*
*& Fetch component data from RESB & VIAUFKS
*& RESB: aufnr, rsnum, rspos, matnr, bdmng
*& VIAUFKS: stlnr, plnal, plnnr (tasklist/BOM info)
*& Logic: If p_aufnr is provided, ignore date filter (single WO mode)
*&        If p_aufnr is empty, use date filter (bulk approval mode)
*&---------------------------------------------------------------------*
FORM fetch_component_data.

  " WO range mode - using s_aufnr SELECT-OPTIONS
  IF s_aufnr[] IS NOT INITIAL.
    " Fetch with WO filter, WITHOUT date filter
    SELECT r~aufnr,
           r~rsnum,
           r~rspos,
           r~matnr,
           r~bdmng,
           r~meins,              " Base Unit of Measure
           v~plnnr,              " Tasklist Number from VIAUFKS
           v~plnty,              " Tasklist Type from VIAUFKS
           v~plnal,              " Group Counter from VIAUFKS
           v~werks               " Plant from VIAUFKS
      INTO CORRESPONDING FIELDS OF TABLE @gt_comp
      FROM resb AS r
      INNER JOIN viaufks AS v ON v~aufnr = r~aufnr
      WHERE r~aufnr IN @s_aufnr
        AND v~werks IN @r_swerk
        AND v~gsber IN @s_gsber
        AND v~autyp = '30'              " Service Order
        "AND v~warpl LIKE '%PMP%'        " Maintenance Plan contains PMP
        AND r~xloek = @space            " Not deleted
        AND r~matnr IN @s_matnr.
  ELSE.
    " Bulk approval mode - using date filter (for L1/BCSPPD users)
    SELECT r~aufnr,
           r~rsnum,
           r~rspos,
           r~matnr,
           r~bdmng,
           r~meins,              " Base Unit of Measure
           v~plnnr,              " Tasklist Number from VIAUFKS
           v~plnty,              " Tasklist Type from VIAUFKS
           v~plnal,              " Group Counter from VIAUFKS
           v~werks               " Plant from VIAUFKS
      INTO CORRESPONDING FIELDS OF TABLE @gt_comp
      FROM resb AS r
      INNER JOIN viaufks AS v ON v~aufnr = r~aufnr
      WHERE v~werks IN @r_swerk
        AND v~gsber IN @s_gsber
        AND v~aedat IN @s_date
        AND v~autyp = '30'              " Service Order
        "AND v~warpl LIKE '%PMP%'        " Maintenance Plan contains PMP
        AND r~xloek = @space            " Not deleted
        AND r~matnr IN @s_matnr.
  ENDIF.

  IF gt_comp IS INITIAL.
    MESSAGE 'No component data found' TYPE 'S' DISPLAY LIKE 'W'.
  ELSE.
    " Fetch material descriptions separately
    PERFORM fetch_component_descriptions.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form fetch_component_descriptions
*&---------------------------------------------------------------------*
*& Fetch material descriptions (MAKTX) for components from MAKT table
*&---------------------------------------------------------------------*
FORM fetch_component_descriptions.

  TYPES: BEGIN OF lty_makt,
           matnr TYPE matnr,
           maktx TYPE maktx,
         END OF lty_makt.

  DATA: lt_makt TYPE TABLE OF lty_makt,
        ls_makt TYPE lty_makt.

  CHECK gt_comp IS NOT INITIAL.

  " Fetch material descriptions
  SELECT matnr, maktx
    INTO TABLE @lt_makt
    FROM makt
    FOR ALL ENTRIES IN @gt_comp
    WHERE matnr = @gt_comp-matnr
      AND spras = @sy-langu.

  " Update gt_comp with descriptions
  LOOP AT gt_comp ASSIGNING FIELD-SYMBOL(<fs_comp>).
    READ TABLE lt_makt INTO ls_makt WITH KEY matnr = <fs_comp>-matnr.
    IF sy-subrc = 0.
      <fs_comp>-maktx = ls_makt-maktx.
    ENDIF.
  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form fetch_tasklist_data_bulk
*&---------------------------------------------------------------------*
*& Fetch tasklist BOM data using PLNNR from VIAUFKS
*& Path: VIAUFKS(PLNNR) → PLMZ(STLNR) → STPO(IDNRK)
*&---------------------------------------------------------------------*
FORM fetch_tasklist_data_bulk.

  CHECK gt_comp IS NOT INITIAL.

  " STPO contains the BOM items (IDNRK = component material)
  SELECT p~plnnr,
         p~plnal,
         p~stlnr,
         s~stlkn,
         s~idnrk,
         s~menge
    INTO CORRESPONDING FIELDS OF TABLE @gt_tasklist
    FROM plmz AS p
    INNER JOIN stpo AS s ON s~stlnr = p~stlnr
    FOR ALL ENTRIES IN @gt_comp
    WHERE p~plnnr = @gt_comp-plnnr
      AND p~plnal = @gt_comp-plnal
      AND s~lkenz <> 'X'.             " Not deleted

  IF gt_tasklist IS NOT INITIAL.
    " Fetch material descriptions separately
    PERFORM fetch_tasklist_descriptions.
  ENDIF.

  " Sort for binary search optimization (by PLNNR + PLNAL + IDNRK)
  SORT gt_tasklist BY plnnr plnal idnrk.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form fetch_tasklist_descriptions
*&---------------------------------------------------------------------*
*& Fetch material descriptions (MAKTX) for tasklist items from MAKT table
*&---------------------------------------------------------------------*
FORM fetch_tasklist_descriptions.

  TYPES: BEGIN OF lty_makt,
           matnr TYPE matnr,
           maktx TYPE maktx,
         END OF lty_makt.

  DATA: lt_makt TYPE TABLE OF lty_makt,
        ls_makt TYPE lty_makt.

  CHECK gt_tasklist IS NOT INITIAL.

  " Fetch material descriptions for tasklist items
  SELECT matnr, maktx
    INTO TABLE @lt_makt
    FROM makt
    FOR ALL ENTRIES IN @gt_tasklist
    WHERE matnr = @gt_tasklist-idnrk
      AND spras = @sy-langu.

  " Update gt_tasklist with descriptions
  LOOP AT gt_tasklist ASSIGNING FIELD-SYMBOL(<fs_tasklist>).
    READ TABLE lt_makt INTO ls_makt WITH KEY matnr = <fs_tasklist>-idnrk.
    IF sy-subrc = 0.
      <fs_tasklist>-maktx = ls_makt-maktx.
    ENDIF.
  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form compare_and_build_alv
*&---------------------------------------------------------------------*
*& Checks if PLNNR is registered => determines approval levels required.
*& Compares WO component vs tasklist BOM => flags mismatch red.
*& Fetches prices, approval data, applies filters => builds ALV output.
*&---------------------------------------------------------------------*
FORM compare_and_build_alv USING iv_status TYPE char20.

  DATA: lv_filter_ok     TYPE flag,
        lv_need_ho       TYPE flag,
        lv_plnnr_matched TYPE flag,          " Flag: Tasklist matches parameter
        lv_param_plnnr   TYPE char20.
  "lv_param_werks   TYPE char10.
  DATA: r_appr_key       TYPE RANGE OF char40,
        r_appr_key_plnnr TYPE RANGE OF char40,       " PLNNR(e.g PSPMP21)
        ls_appr_key_line LIKE LINE OF r_appr_key_plnnr.

  " JKT
  CALL FUNCTION 'ZFM_TVARVC_SELOP'
    EXPORTING
      i_name   = 'APPROVAL_WO_KEY_GEN'
    TABLES
      t_result = r_appr_key
    EXCEPTIONS
      no_data  = 1
      OTHERS   = 2.

  IF sy-subrc = 1.
    MESSAGE 'Plant has not been maintained in APPROVAL_WO_KEY_GEN parameter (TVARVC)' TYPE 'E'.
  ELSEIF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.

  " PSPMP21
  CALL FUNCTION 'ZFM_TVARVC_SELOP'
    EXPORTING
      i_name   = 'APPROVAL_WO_TASKLIST'
    TABLES
      t_result = r_appr_key_plnnr
    EXCEPTIONS
      no_data  = 1
      OTHERS   = 2.
  " If not maintained, only L3 (SDH) approval needed (skip L1)  " L2(PDH) removed

  LOOP AT gt_comp INTO gs_comp.
    CLEAR: gs_alv_data, lv_need_ho, lv_plnnr_matched.
    IF r_appr_key[] IS NOT INITIAL.
      IF gs_comp-werks IN r_appr_key.
      ELSE.
        gv_werks_not_in_param = 'X'.
        CONTINUE.  " WERKS not maintain
      ENDIF.
    ENDIF.

    " ===== Logic Tasklist approval based  ===== " L2(PDH) removed
    " If PLNNR registered in APPROVAL_WO_TASKLIST => L1 + L3 required (need_ho = 'X')
    " If PLNNR NOT registered                     => only L3 (SDH) required (need_ho = ' ')
    lv_plnnr_matched = ' '.
    IF r_appr_key_plnnr[] IS NOT INITIAL AND gs_comp-plnnr IS NOT INITIAL.
      LOOP AT r_appr_key_plnnr INTO ls_appr_key_line.
        IF gs_comp-plnnr CS ls_appr_key_line-low OR ls_appr_key_line-low CS gs_comp-plnnr.
          lv_plnnr_matched = 'X'.
          EXIT.  " Found match, no need to check further
        ENDIF.
      ENDLOOP.
    ENDIF.

    " Set need_ho flag
*    IF lv_plnnr_matched = 'X'.
*      lv_need_ho = 'X'.  " PLNNR Registered => full: L1(BCSPPD HO) + L3 No PDH
*    ELSE.
*      lv_need_ho = ' '.  " PLNNR not Registered => skip L1, only L3 (SDH)
*    ENDIF.

    " Move component data to ALV structure
    gs_alv_data-aufnr           = gs_comp-aufnr.
    gs_alv_data-rsnum           = gs_comp-rsnum.
    gs_alv_data-rspos           = gs_comp-rspos.
    gs_alv_data-matnr           = gs_comp-matnr.
    gs_alv_data-pn_workorder    = gs_comp-matnr.
    gs_alv_data-desc_workorder  = gs_comp-maktx.
    gs_alv_data-qty_workorder   = gs_comp-bdmng.
    gs_alv_data-meins           = gs_comp-meins.  " UoM
    gs_alv_data-waers           = 'IDR'.          " Hardcode currency
    gs_alv_data-plnnr           = gs_comp-plnnr.
    "gs_alv_data-need_ho         = lv_need_ho.    " Set NEED_HO flag

    " Fetch CAUFV additional data (werks, gsber, aedat, equnr, etc.)
    PERFORM fetch_caufv_data USING gs_comp-aufnr
                             CHANGING gs_alv_data.

    " ===== MAIN COMPARISON =====
    " Using PLNNR + PLNAL from VIAUFKS to match tasklist
    IF gs_comp-plnnr IS NOT INITIAL.
      READ TABLE gt_tasklist INTO gs_tasklist
        WITH KEY plnnr = gs_comp-plnnr
                 plnal = gs_comp-plnal
                 idnrk = gs_comp-matnr
        BINARY SEARCH.

      IF sy-subrc = 0.
        " MATCH
        gs_alv_data-comp_status = 'X'.
        gs_alv_data-comp_match  = 'Yes'.
        gs_alv_data-pn_tasklist = gs_tasklist-idnrk.
        gs_alv_data-desc_tasklist = gs_tasklist-maktx.
        gs_alv_data-qty_tasklist = gs_tasklist-menge.
        gs_alv_data-stlnr = gs_tasklist-stlnr.  " Get STLNR from tasklist
      ELSE.
        " MISMATCH: Component NOT in Tasklist BOM
        gs_alv_data-comp_status = space.
        gs_alv_data-comp_match  = 'No'.
        IF lv_plnnr_matched = 'X'.
          gs_alv_data-linecolor = 'C610'.
        ENDIF.

        " Get first tasklist item for reference
        READ TABLE gt_tasklist INTO gs_tasklist
          WITH KEY plnnr = gs_comp-plnnr
                   plnal = gs_comp-plnal
          BINARY SEARCH.
        IF sy-subrc = 0.
          " gs_alv_data-pn_tasklist = gs_tasklist-idnrk.
          " gs_alv_data-desc_tasklist = gs_tasklist-maktx.
          gs_alv_data-stlnr = gs_tasklist-stlnr.
        ENDIF.
      ENDIF.
    ELSE.
      " No Tasklist Number - treat as mismatch
      gs_alv_data-comp_status = space.
      gs_alv_data-comp_match  = 'No'.
      IF lv_plnnr_matched = 'X'.
        gs_alv_data-linecolor = 'C610'.  " tasklist under approval control
      ENDIF.
    ENDIF.

    " Set need_ho flag AFTER comparison
    " need_ho = 'X' only when PLNNR registered AND component mismatches
    IF lv_plnnr_matched = 'X' AND gs_alv_data-comp_status = space.
      gs_alv_data-need_ho = 'X'.  " PLNNR Registered + Mismatch => L1(BCSPPD) + L3(SDH)
    ELSE.
      gs_alv_data-need_ho = ' '.  " Match or PLNNR not registered => only L3(SDH)
    ENDIF.

    " Get MAP prices for WO and Tasklist
    PERFORM fetch_map_prices CHANGING gs_alv_data.

    " Check for material interchange
    PERFORM check_material_interchange CHANGING gs_alv_data.

    " Fetch approval data from ZTWOAPPR
    PERFORM fetch_approval_data CHANGING gs_alv_data.

    " Set traffic light based on approval status
    PERFORM set_traffic_light CHANGING gs_alv_data.

    " Remove leading zeros
    PERFORM convert_alpha_output CHANGING gs_alv_data.

    " Calculate aging days
    gs_alv_data-agingdays = sy-datum - gs_alv_data-aedat.

    " Apply all filters
    PERFORM apply_filters USING gs_alv_data iv_status
                          CHANGING lv_filter_ok.
    CHECK lv_filter_ok = 'X'.

    APPEND gs_alv_data TO gt_alv_data.
  ENDLOOP.

*  IF gt_alv_data IS INITIAL AND gt_comp IS NOT INITIAL AND r_appr_key[] IS NOT INITIAL.
*    MESSAGE 'Plant is not maintained in APPROVAL_WO_KEY_GEN parameter(TVARVC)' TYPE 'S' DISPLAY LIKE 'W'.
*  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form fetch_caufv_data
*&---------------------------------------------------------------------*
*& Fetch additional CAUFV data (werks, gsber, aedat, equnr, etc.)
*& for a specific Work Order
*&---------------------------------------------------------------------*
FORM fetch_caufv_data USING iv_aufnr TYPE aufnr
                      CHANGING cs_data TYPE ty_alv_output.

  " Get CAUFV + AFIH + AFKO + EQUI data for the Work Order
  SELECT SINGLE c~werks,
                c~gsber,
                c~aedat,
                c~auart,
                h~equnr,
                e~matnr AS equ_matnr,         " Equipment Model from EQUI
                h~sermat,
                h~serialnr,
                h~warpl,
                h~abnum,
                k~maufnr
    INTO (@cs_data-werks,
          @cs_data-gsber,
          @cs_data-aedat,
          @cs_data-auart,
          @cs_data-equnr,
          @cs_data-equ_matnr,
          @cs_data-sermat,
          @cs_data-serialnr,
          @cs_data-warpl,
          @cs_data-abnum,
          @cs_data-maufnr)
    FROM caufv AS c
    LEFT JOIN afih AS h ON h~aufnr = c~aufnr
    LEFT JOIN equi AS e ON e~equnr = h~equnr
    LEFT JOIN afko AS k ON k~aufnr = c~aufnr
    WHERE c~aufnr = @iv_aufnr.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form fetch_map_prices
*&---------------------------------------------------------------------*
*& Fetch MAP (Moving Average Price) for WO and Tasklist materials
*&---------------------------------------------------------------------*
FORM fetch_map_prices CHANGING cs_data TYPE ty_alv_output.

  " Get MAP for Work Order material
  IF cs_data-pn_workorder IS NOT INITIAL.
    SELECT SINGLE verpr
      INTO cs_data-map_workorder
      FROM mbew
      WHERE matnr = cs_data-pn_workorder
        AND bwkey = cs_data-werks.
  ENDIF.

  " Get MAP for Tasklist material
  IF cs_data-pn_tasklist IS NOT INITIAL.
    SELECT SINGLE verpr
      INTO cs_data-map_tasklist
      FROM mbew
      WHERE matnr = cs_data-pn_tasklist
        AND bwkey = cs_data-werks.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form convert_alpha_output
*&---------------------------------------------------------------------*
*& Remove leading zeros from Equipment, Work Order, and Tasklist fields
*&---------------------------------------------------------------------*
FORM convert_alpha_output CHANGING cs_data TYPE ty_alv_output.

  " Equipment
  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_OUTPUT'
    EXPORTING
      input  = cs_data-equnr
    IMPORTING
      output = cs_data-equnr.

  " WO Number
  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_OUTPUT'
    EXPORTING
      input  = cs_data-aufnr
    IMPORTING
      output = cs_data-aufnr.

  " Tasklist
  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_OUTPUT'
    EXPORTING
      input  = cs_data-stlnr
    IMPORTING
      output = cs_data-stlnr.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form fetch_material_data
*&---------------------------------------------------------------------*
*& Fetch material and WO information from RESB and MBEW tables
*&---------------------------------------------------------------------*
FORM fetch_material_data CHANGING cs_data TYPE ty_alv_output.
  DATA: lv_stlnr TYPE stnum,
        lv_matnr TYPE matnr,
        lv_bdmng TYPE bdmng.

  " Get material from reservation/requirements (RESB)
  SELECT matnr, bdmng, stlnr
    INTO (@lv_matnr, @lv_bdmng, @lv_stlnr)
    FROM resb
    WHERE aufnr = @cs_data-aufnr
      "AND xloek = ''
      AND matnr IN @s_matnr
    ORDER BY rsnum DESCENDING.
  ENDSELECT.

  IF sy-subrc = 0.
    " Set material values from work order
    cs_data-pn_workorder = lv_matnr.
    cs_data-qty_workorder = lv_bdmng.
    cs_data-matnr = lv_matnr.

    " Store STLNR for tasklist processing
    cs_data-stlnr = lv_stlnr.

    " Get material description for work order
    SELECT SINGLE maktx
      INTO cs_data-desc_workorder
      FROM makt
      WHERE matnr = cs_data-pn_workorder
        AND spras = sy-langu.

    " Get material price (MAP) for work order
    SELECT SINGLE verpr
      INTO cs_data-map_workorder
      FROM mbew
      WHERE matnr = cs_data-pn_workorder
        AND bwkey = cs_data-werks.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form fetch_tasklist_data
*&---------------------------------------------------------------------*
*& Fetch tasklist-related data (material, description, price)
*&---------------------------------------------------------------------*
*FORM fetch_tasklist_data CHANGING cs_data TYPE ty_alv_output.
*
*  DATA: lv_idnrk TYPE idnrk,
*        lv_menge TYPE kmpmg,
*        lv_stlnr TYPE stnum.
*
*  " Get tasklist data using join: AFKO -> PLKO -> PLMZ -> STPO
*  " PLMZ-STLNR = STPO-STLNR with filter PLNAL = '01'
*  " PLNAL based on Group Counter in Tasklist
*  SELECT SINGLE s~idnrk, s~menge, a~stlnr
*    INTO (@lv_idnrk, @lv_menge, @lv_stlnr)
*    FROM afko AS a
*    INNER JOIN plko AS p ON p~plnnr = a~plnnr
*    INNER JOIN plmz AS m ON m~plnnr = p~plnnr
*                        AND m~plnal = p~plnal
*    INNER JOIN stpo AS s ON s~stlnr = m~stlnr
*                        AND s~stlkn = m~stlkn
*    WHERE a~aufnr = @cs_data-aufnr
*      AND m~plnal = '01'
*      AND s~lkenz <> 'X'.
*
*  IF sy-subrc = 0.
*    " Store STLNR in output data
*    cs_data-stlnr = lv_stlnr.
*
*    " Set tasklist values
*    cs_data-pn_tasklist = lv_idnrk.
*    cs_data-qty_tasklist = lv_menge.
*
*    " Get material description for tasklist
*    SELECT SINGLE maktx
*      INTO cs_data-desc_tasklist
*      FROM makt
*      WHERE matnr = cs_data-pn_tasklist
*        AND spras = sy-langu.
*
*    " Get material price (MAP) for tasklist
*    SELECT SINGLE verpr
*      INTO cs_data-map_tasklist
*      FROM mbew
*      WHERE matnr = cs_data-pn_tasklist
*        AND bwkey = cs_data-werks.
*  ENDIF.
*
*ENDFORM.

*&---------------------------------------------------------------------*
*& Form check_material_interchange
*&---------------------------------------------------------------------*
*& Check if material exists in ZINCHG table for interchange status
*& MATWA = Material to check (PN Work Order)
*& SMATN = Source Material, INCODE = 018 or 016
*&---------------------------------------------------------------------*
FORM check_material_interchange CHANGING cs_data TYPE ty_alv_output.

  DATA: lv_smatn TYPE matnr.

  SELECT SINGLE smatn
    INTO lv_smatn
    FROM zinchg
    WHERE matwa = cs_data-pn_workorder
      AND ( incode = '018' OR incode = '016' ).

  IF sy-subrc EQ 0.
    cs_data-interchange = 'Yes'.
    " Don't show interchange PN
    cs_data-interchange_pn = lv_smatn.
*    CLEAR cs_data-interchange_pn.
  ELSE.
    " Material does not exist in ZINCHG table => Interchange = No
    cs_data-interchange = 'No'.
    CLEAR cs_data-interchange_pn.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form fetch_approval_data
*&---------------------------------------------------------------------*
*& Fetch approval data from custom table ZTWOAPPR
*&---------------------------------------------------------------------*
FORM fetch_approval_data CHANGING cs_data TYPE ty_alv_output.

  DATA: lv_aufnr TYPE aufnr,
        lv_matnr TYPE matnr.

  " Convert keys to have leading zeros (match database format)
  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
    EXPORTING
      input  = cs_data-aufnr
    IMPORTING
      output = lv_aufnr.

  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
    EXPORTING
      input  = cs_data-matnr
    IMPORTING
      output = lv_matnr.

  " Get approval data from custom table
  SELECT SINGLE approval_stat
                reason_change
                reason_reject
                approved_by
                approved_date
                created_date
                change_id
                approval_lvl1
                approval_lvl2
                approval_lvl3
                appr_valid
    INTO (cs_data-approval_stat,
          cs_data-reason_change,
          cs_data-reason_reject,
          cs_data-approver,
          cs_data-approved_date,
          cs_data-created_date,
          cs_data-change_id,
          cs_data-approval_lvl1,
          cs_data-approval_lvl2,
          cs_data-approval_lvl3,
          cs_data-appr_valid)
    FROM ztwoappr
    WHERE aufnr = lv_aufnr
      AND matnr = lv_matnr.

  " If no approval record exists, set default values
  IF sy-subrc <> 0.
    cs_data-approval_stat = 'Pending Approve'.
    cs_data-created_date = cs_data-aedat.
    CLEAR: cs_data-approver,
           cs_data-approved_date,
           cs_data-reason_change,
           cs_data-reason_reject,
           cs_data-change_id,
           cs_data-approval_lvl1,
           cs_data-approval_lvl2,
           cs_data-approval_lvl3,
           cs_data-appr_valid.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form check_component_match
*&---------------------------------------------------------------------*
*& Check if WO Component matches Tasklist Component using comp_status flag
*& Returns: 'X' if components match, ' ' if mismatch
*&---------------------------------------------------------------------*
FORM check_component_match USING is_data TYPE ty_alv_output
                           CHANGING cv_match TYPE flag.

  " Use comp_status flag for match determination
  IF is_data-comp_status = 'X'.
    cv_match = 'X'.   " Components match
  ELSE.
    cv_match = ' '.   " Components do not match
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form set_traffic_light
*&---------------------------------------------------------------------*
*& Sets traffic light and approval checkboxes based on approval status
*& need_ho = ' ' (not registered in APPROVAL_WO_TASKLIST) => SDH -> Full Approved  (PDH removed)
*& need_ho = 'X' (registered in APPROVAL_WO_TASKLIST) => BCSPPD(HO) -> SDH -> Full Approved  (PDH removed)
*&---------------------------------------------------------------------*
FORM set_traffic_light CHANGING cs_data TYPE ty_alv_output.

  " Map DB approval level flags to role checkboxes
  " DB Field         -> Checkbox    -> Role
  " approval_lvl1    -> chk_bcsppd  -> BCSPPD (HO)           L1
  " approval_lvl2    -> chk_pdh     -> PDH  (Parts Dept Head) L2 => No PDH
  " approval_lvl3    -> chk_sdh     -> SDH  (Service Dept Head) L3
  " Only show BCSPPD checkbox when HO approval is actually needed
  IF cs_data-need_ho = 'X'.
    cs_data-chk_bcsppd = cs_data-approval_lvl1.  " L1 = BCSPPD
  ELSE.
    CLEAR cs_data-chk_bcsppd.                    " L1 not needed => no checkbox
  ENDIF.
  "cs_data-chk_pdh    = cs_data-approval_lvl2.  " L2 = PDH
  cs_data-chk_sdh    = cs_data-approval_lvl3.  " L3 = SDH

  " Set traffic light based on approval status
  CASE cs_data-approval_stat.
    WHEN 'Pending Approve'.
      " No approvals yet - Yellow light
      cs_data-traffic_light = icon_yellow_light.
      CLEAR: cs_data-chk_bcsppd, cs_data-chk_pdh, cs_data-chk_sdh.

    WHEN 'Reject Approval'.
      " Rejected - Red light
      cs_data-traffic_light = icon_red_light.
      CLEAR: cs_data-chk_bcsppd, cs_data-chk_pdh, cs_data-chk_sdh.

    WHEN 'Approved BCSPPD'.
      " BCSPPD approved, waiting for SDH (PDH removed from flow)
      cs_data-traffic_light = icon_yellow_light.

    WHEN 'Approved PDH'.
      " REMOVED: PDH no longer in flow - backward compat: treat as waiting for SDH
      cs_data-traffic_light = icon_yellow_light.

    WHEN 'Approved SDH' OR 'Full Approved'.
      " Fully approved - Green light
      cs_data-traffic_light = icon_green_light.
      cs_data-selected = 'X'.
      " Normalize status to 'Full Approved' for display
      cs_data-approval_stat = 'Full Approved'.

    WHEN OTHERS.
      cs_data-traffic_light = icon_yellow_light.
      CLEAR: cs_data-chk_bcsppd, cs_data-chk_pdh, cs_data-chk_sdh.
  ENDCASE.

  CLEAR cs_data-appr_valid.
  IF cs_data-approval_stat = 'Full Approved'. " Already fully approved
    cs_data-appr_valid = 'X'.
  ELSEIF cs_data-need_ho = space.
    " PLNNR not registered => only SDH required (PDH removed)
    IF cs_data-chk_sdh = 'X'.
      cs_data-appr_valid = 'X'.
    ENDIF.
  ELSE.
    " PLNNR registered in APPROVAL_WO_TASKLIST => BCSPPD + SDH required (No PDH)
    IF cs_data-chk_bcsppd = 'X' AND cs_data-chk_sdh = 'X'.
      cs_data-appr_valid = 'X'.
    ENDIF.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form apply_filters
*&---------------------------------------------------------------------*
*& Apply all selection filters to determine if record should be included
*& Returns: 'X' if record passes all filters, ' ' otherwise
*&---------------------------------------------------------------------*
FORM apply_filters USING is_data   TYPE ty_alv_output
                         iv_status TYPE char20
                   CHANGING cv_filter_ok TYPE flag.

  cv_filter_ok = 'X'.

  " These are parts that require BCSPPD approval (comp_status = space = mismatch)
  IF gv_auth_level = 'L1'.                " L1 = BCSPPD users
    IF is_data-comp_match = 'Yes'.
      cv_filter_ok = ' '.
      RETURN.
    ENDIF.
  ENDIF.

  " Apply interchange filter
  IF p_intch <> 'ALL' AND p_intch <> 'A'.
    IF ( p_intch = 'Y' AND is_data-interchange <> 'Yes' ) OR
       ( p_intch = 'N' AND is_data-interchange <> 'No' ).
      cv_filter_ok = ' '.
      RETURN.
    ENDIF.
  ENDIF.

  " Apply aging filter
  IF s_age[] IS NOT INITIAL AND is_data-agingdays NOT IN s_age.
    cv_filter_ok = ' '.
    RETURN.
  ENDIF.

  " Apply approver filter
  IF s_appby[] IS NOT INITIAL AND is_data-approver NOT IN s_appby.
    cv_filter_ok = ' '.
    RETURN.
  ENDIF.

  " Apply status filter
  IF iv_status IS NOT INITIAL AND is_data-approval_stat <> iv_status.
    cv_filter_ok = ' '.
    RETURN.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form build_fieldcat
*&---------------------------------------------------------------------*
*& Build field catalog for ALV display - 35 columns
*&---------------------------------------------------------------------*
FORM build_fieldcat.
  CLEAR: gt_fieldcat, gs_fieldcat.

  " Column 1: Email to HO Checkbox
  gs_fieldcat-fieldname = 'SELECTED'.
  gs_fieldcat-seltext_m = 'Email to HO'.
  gs_fieldcat-col_pos = 1.
  gs_fieldcat-checkbox = 'X'.
  gs_fieldcat-edit = space.           " Not editable - managed by program
  gs_fieldcat-outputlen = 8.
  gs_fieldcat-fix_column = 'X'.        " Freeze column
  APPEND gs_fieldcat TO gt_fieldcat.
  CLEAR gs_fieldcat.

  " Column 2: Traffic Light
  gs_fieldcat-fieldname = 'TRAFFIC_LIGHT'.
  gs_fieldcat-seltext_m = 'Status'.
  gs_fieldcat-col_pos = 2.
  gs_fieldcat-icon = 'X'.
  gs_fieldcat-outputlen = 4.
  gs_fieldcat-fix_column = 'X'.        " Freeze column
  APPEND gs_fieldcat TO gt_fieldcat.
  CLEAR gs_fieldcat.

  " Column 3: Approval Status
  gs_fieldcat-fieldname = 'APPROVAL_STAT'.
  gs_fieldcat-seltext_m = 'Approval Status'.
  gs_fieldcat-col_pos = 3.
  gs_fieldcat-outputlen = 20.
  gs_fieldcat-fix_column = 'X'.        " Freeze column
  APPEND gs_fieldcat TO gt_fieldcat.
  CLEAR gs_fieldcat.

  " Column 4: BCSPPD Approval Checkbox (only for Comp_Match = No)
  gs_fieldcat-fieldname = 'CHK_BCSPPD'.
  gs_fieldcat-seltext_m = 'BCSPPD'.
  gs_fieldcat-col_pos = 4.
  gs_fieldcat-checkbox = 'X'.
  gs_fieldcat-outputlen = 6.
  gs_fieldcat-fix_column = 'X'.        " Freeze column
  APPEND gs_fieldcat TO gt_fieldcat.
  CLEAR gs_fieldcat.

*  " Column 5: PDH Approval Checkbox
*  gs_fieldcat-fieldname = 'CHK_PDH'.
*  gs_fieldcat-seltext_m = 'PDH'.
*  gs_fieldcat-col_pos = 5.
*  gs_fieldcat-checkbox = 'X'.
*  gs_fieldcat-outputlen = 6.
*  gs_fieldcat-fix_column = 'X'.        " Freeze column
*  APPEND gs_fieldcat TO gt_fieldcat.
*  CLEAR gs_fieldcat.

  " Column 6: SDH Approval Checkbox
  gs_fieldcat-fieldname = 'CHK_SDH'.
  gs_fieldcat-seltext_m = 'SDH'.
  gs_fieldcat-col_pos = 6.
  gs_fieldcat-checkbox = 'X'.
  gs_fieldcat-outputlen = 6.
  gs_fieldcat-fix_column = 'X'.        " Freeze column
  APPEND gs_fieldcat TO gt_fieldcat.
  CLEAR gs_fieldcat.

  " Column 7: Request Date
  gs_fieldcat-fieldname = 'AEDAT'.
  gs_fieldcat-seltext_m = 'Req Date'.
  gs_fieldcat-col_pos = 7.
  gs_fieldcat-outputlen = 10.
  gs_fieldcat-fix_column = 'X'.        " Freeze column
  APPEND gs_fieldcat TO gt_fieldcat.
  CLEAR gs_fieldcat.

  " Column 8: Business Area
  gs_fieldcat-fieldname = 'GSBER'.
  gs_fieldcat-seltext_m = 'Bus Area'.
  gs_fieldcat-col_pos = 8.
  gs_fieldcat-outputlen = 4.
  gs_fieldcat-fix_column = 'X'.        " Freeze column
  APPEND gs_fieldcat TO gt_fieldcat.
  CLEAR gs_fieldcat.

  " Column 9: Plant
  gs_fieldcat-fieldname = 'WERKS'.
  gs_fieldcat-seltext_m = 'Plant'.
  gs_fieldcat-col_pos = 9.
  gs_fieldcat-outputlen = 4.
  gs_fieldcat-fix_column = 'X'.        " Freeze column
  APPEND gs_fieldcat TO gt_fieldcat.
  CLEAR gs_fieldcat.

  " Column 10: Superior Order
  gs_fieldcat-fieldname = 'MAUFNR'.
  gs_fieldcat-seltext_m = 'Sup Order'.
  gs_fieldcat-col_pos = 10.
  gs_fieldcat-outputlen = 8.
  gs_fieldcat-fix_column = 'X'.        " Freeze column
  APPEND gs_fieldcat TO gt_fieldcat.
  CLEAR gs_fieldcat.

  " Column 11: Work Order
  gs_fieldcat-fieldname = 'AUFNR'.
  gs_fieldcat-seltext_m = 'Work Order'.
  gs_fieldcat-col_pos = 11.
  gs_fieldcat-outputlen = 12.
  gs_fieldcat-hotspot = 'X'.
  gs_fieldcat-fix_column = 'X'.        " Freeze column
  APPEND gs_fieldcat TO gt_fieldcat.
  CLEAR gs_fieldcat.

  " Column 12: Reason for Change (Dropdown)
  gs_fieldcat-fieldname = 'REASON_CHANGE'.
  gs_fieldcat-seltext_m = 'Reason Change'.
  gs_fieldcat-col_pos = 12.
  gs_fieldcat-hotspot = 'X'.           "make popup Change
  gs_fieldcat-outputlen = 30.
  gs_fieldcat-fix_column = 'X'.        " Freeze column
  APPEND gs_fieldcat TO gt_fieldcat.
  CLEAR gs_fieldcat.

  " Column 13: Reason for Rejection
  gs_fieldcat-fieldname = 'REASON_REJECT'.
  gs_fieldcat-seltext_m = 'Reason Reject'.
  gs_fieldcat-col_pos = 13.
  gs_fieldcat-hotspot = 'X'.            "make popup Reject
  gs_fieldcat-outputlen = 30.
  gs_fieldcat-fix_column = 'X'.        " Freeze column
  APPEND gs_fieldcat TO gt_fieldcat.
  CLEAR gs_fieldcat.

  " Column 14: Part Number
  gs_fieldcat-fieldname = 'MATNR'.
  gs_fieldcat-seltext_m = 'Part Number'.
  gs_fieldcat-col_pos = 14.
  gs_fieldcat-outputlen = 18.
  APPEND gs_fieldcat TO gt_fieldcat.
  CLEAR gs_fieldcat.

  " Column 15: Interchange Flag
  gs_fieldcat-fieldname = 'INTERCHANGE'.
  gs_fieldcat-seltext_m = 'Int. Status(Y/N)'.
  gs_fieldcat-col_pos = 15.
  gs_fieldcat-outputlen = 3.
  APPEND gs_fieldcat TO gt_fieldcat.
  CLEAR gs_fieldcat.

  " Column 16: Interchanged Part Number
  gs_fieldcat-fieldname = 'INTERCHANGE_PN'.
  gs_fieldcat-seltext_m = 'PN Interchge'.
  gs_fieldcat-col_pos = 16.
  gs_fieldcat-outputlen = 10.
  APPEND gs_fieldcat TO gt_fieldcat.
  CLEAR gs_fieldcat.

  " Column 17: Component Match (PN WO vs PN Tasklist)
  gs_fieldcat-fieldname = 'COMP_MATCH'.
  gs_fieldcat-seltext_m = 'PN Match'.
  gs_fieldcat-col_pos = 17.
  gs_fieldcat-outputlen = 5.
  APPEND gs_fieldcat TO gt_fieldcat.
  CLEAR gs_fieldcat.

  " Column 18: Aging Days
  gs_fieldcat-fieldname = 'AGINGDAYS'.
  gs_fieldcat-seltext_m = 'Aging'.
  gs_fieldcat-col_pos = 18.
  gs_fieldcat-outputlen = 6.
  APPEND gs_fieldcat TO gt_fieldcat.
  CLEAR gs_fieldcat.

  " Column 19: Approver
  gs_fieldcat-fieldname = 'APPROVER'.
  gs_fieldcat-seltext_m = 'Approver'.
  gs_fieldcat-col_pos = 19.
  gs_fieldcat-outputlen = 12.
  APPEND gs_fieldcat TO gt_fieldcat.
  CLEAR gs_fieldcat.

  " Column 20: Equipment Model (EQUI-MATNR)
  gs_fieldcat-fieldname = 'EQU_MATNR'.
  gs_fieldcat-seltext_m = 'Model'.
  gs_fieldcat-col_pos = 20.
  gs_fieldcat-outputlen = 18.
  APPEND gs_fieldcat TO gt_fieldcat.
  CLEAR gs_fieldcat.

  " Column 21: Equipment
  gs_fieldcat-fieldname = 'EQUNR'.
  gs_fieldcat-seltext_m = 'Equipment'.
  gs_fieldcat-col_pos = 21.
  gs_fieldcat-outputlen = 18.
  APPEND gs_fieldcat TO gt_fieldcat.
  CLEAR gs_fieldcat.

  " Column 22: Serial Number
  gs_fieldcat-fieldname = 'SERIALNR'.
  gs_fieldcat-seltext_m = 'Serial No'.
  gs_fieldcat-col_pos = 22.
  gs_fieldcat-outputlen = 18.
  APPEND gs_fieldcat TO gt_fieldcat.
  CLEAR gs_fieldcat.

  " Column 23: Maintenance Planning
  gs_fieldcat-fieldname = 'WARPL'.
  gs_fieldcat-seltext_m = 'Maint Plan'.
  gs_fieldcat-col_pos = 23.
  gs_fieldcat-outputlen = 8.
  gs_fieldcat-hotspot = 'X'.
  APPEND gs_fieldcat TO gt_fieldcat.
  CLEAR gs_fieldcat.

  " Column 24: Call Number
  gs_fieldcat-fieldname = 'ABNUM'.
  gs_fieldcat-seltext_m = 'Call No'.
  gs_fieldcat-col_pos = 24.
  gs_fieldcat-outputlen = 12.
  APPEND gs_fieldcat TO gt_fieldcat.
  CLEAR gs_fieldcat.

  " Column 25: Bill of Material (BOM Number from STPO)
  gs_fieldcat-fieldname = 'STLNR'.
  gs_fieldcat-seltext_m = 'BOM'.
  gs_fieldcat-col_pos = 25.
  gs_fieldcat-outputlen = 10.
  APPEND gs_fieldcat TO gt_fieldcat.
  CLEAR gs_fieldcat.

  " Column 26: Tasklist
  gs_fieldcat-fieldname = 'PLNNR'.
  gs_fieldcat-seltext_m = 'Tasklist'.
  gs_fieldcat-col_pos = 26.
  gs_fieldcat-outputlen = 8.
  APPEND gs_fieldcat TO gt_fieldcat.
  CLEAR gs_fieldcat.

  " Column 27: PN Tasklist
  gs_fieldcat-fieldname = 'PN_TASKLIST'.
  gs_fieldcat-seltext_m = 'PN Tasklist'.
  gs_fieldcat-col_pos = 27.
  gs_fieldcat-emphasize = 'C510'.
  gs_fieldcat-outputlen = 18.
  APPEND gs_fieldcat TO gt_fieldcat.
  CLEAR gs_fieldcat.

  " Column 28: Description Tasklist
  gs_fieldcat-fieldname = 'DESC_TASKLIST'.
  gs_fieldcat-seltext_m = 'Desc PN Tasklist'.
  gs_fieldcat-col_pos = 28.
  gs_fieldcat-emphasize = 'C510'.
  gs_fieldcat-outputlen = 40.
  APPEND gs_fieldcat TO gt_fieldcat.
  CLEAR gs_fieldcat.

  " Column 29: Quantity Tasklist
  gs_fieldcat-fieldname = 'QTY_TASKLIST'.
  gs_fieldcat-seltext_m = 'Qty PN Tasklist'.
  gs_fieldcat-col_pos = 29.
  gs_fieldcat-emphasize = 'C510'.
  gs_fieldcat-outputlen = 13.
  "gs_fieldcat-datatype = 'QUAN'.
  gs_fieldcat-qfieldname = 'MEINS'.
  gs_fieldcat-do_sum = 'X'.
  APPEND gs_fieldcat TO gt_fieldcat.
  CLEAR gs_fieldcat.

  " Column 30: MAP Tasklist
  gs_fieldcat-fieldname = 'MAP_TASKLIST'.
  gs_fieldcat-seltext_m = 'MAP PN Tasklist'. "Moving Average Price PN Tasklist
  gs_fieldcat-col_pos = 30.
  gs_fieldcat-emphasize = 'C510'.
  gs_fieldcat-outputlen = 11.
  gs_fieldcat-datatype = 'CURR'.
  gs_fieldcat-cfieldname = 'WAERS'.
  gs_fieldcat-do_sum = 'X'.
  APPEND gs_fieldcat TO gt_fieldcat.
  CLEAR gs_fieldcat.

  " Column 31: Currency Key (IDR - after MAP PN Tasklist)
  gs_fieldcat-fieldname = 'WAERS'.
  gs_fieldcat-seltext_m = 'Currency'.
  gs_fieldcat-col_pos = 31.
  gs_fieldcat-emphasize = 'C510'.
  gs_fieldcat-outputlen = 5.
  APPEND gs_fieldcat TO gt_fieldcat.
  CLEAR gs_fieldcat.

  "=============PN WO Data
  " Column 32: PN Work Order
  gs_fieldcat-fieldname = 'PN_WORKORDER'.
  gs_fieldcat-seltext_m = 'PN Work Order'.
  gs_fieldcat-col_pos = 32.
  gs_fieldcat-emphasize = 'C310'.
  gs_fieldcat-outputlen = 18.
  APPEND gs_fieldcat TO gt_fieldcat.
  CLEAR gs_fieldcat.

  " Column 33: Description Work Order
  gs_fieldcat-fieldname = 'DESC_WORKORDER'.
  gs_fieldcat-seltext_m = 'Desc PN WO'.
  gs_fieldcat-col_pos = 33.
  gs_fieldcat-emphasize = 'C310'.
  gs_fieldcat-outputlen = 40.
  APPEND gs_fieldcat TO gt_fieldcat.
  CLEAR gs_fieldcat.

  " Column 34: Quantity Work Order
  gs_fieldcat-fieldname = 'QTY_WORKORDER'.
  gs_fieldcat-seltext_m = 'Qty PN WO'.
  gs_fieldcat-col_pos = 34.
  gs_fieldcat-emphasize = 'C310'.
  gs_fieldcat-outputlen = 13.
  gs_fieldcat-datatype = 'QUAN'.
  gs_fieldcat-qfieldname = 'MEINS'.        " Reference unit field (RESB-BDMNG)
  gs_fieldcat-do_sum = 'X'.
  APPEND gs_fieldcat TO gt_fieldcat.
  CLEAR gs_fieldcat.

  " Column 35: MAP Work Order
  gs_fieldcat-fieldname = 'MAP_WORKORDER'.
  gs_fieldcat-seltext_m = 'MAP PN WO'. "Moving Average Price PN in WO
  gs_fieldcat-col_pos = 35.
  gs_fieldcat-emphasize = 'C310'.
  gs_fieldcat-outputlen = 11.
  gs_fieldcat-datatype = 'CURR'.
  gs_fieldcat-cfieldname = 'WAERS'.        " Reference currency field (MBEW-VERPR)
  gs_fieldcat-do_sum = 'X'.
  APPEND gs_fieldcat TO gt_fieldcat.
  CLEAR gs_fieldcat.

  " Column 36: Currency Key (IDR - after MAP PN WO)
  gs_fieldcat-fieldname = 'WAERS'.
  gs_fieldcat-seltext_m = 'Currency'.
  gs_fieldcat-col_pos = 36.
  gs_fieldcat-emphasize = 'C310'.
  gs_fieldcat-outputlen = 5.
  APPEND gs_fieldcat TO gt_fieldcat.
  CLEAR gs_fieldcat.

  " Column 37: Created Date
  gs_fieldcat-fieldname = 'CREATED_DATE'.
  gs_fieldcat-seltext_m = 'Crtd Date'.
  gs_fieldcat-col_pos = 37.
  gs_fieldcat-outputlen = 10.
  APPEND gs_fieldcat TO gt_fieldcat.
  CLEAR gs_fieldcat.

  " Column 38: Approved Date
  gs_fieldcat-fieldname = 'APPROVED_DATE'.
  gs_fieldcat-seltext_m = 'Appr Date'.
  gs_fieldcat-col_pos = 38.
  gs_fieldcat-outputlen = 10.
  APPEND gs_fieldcat TO gt_fieldcat.
  CLEAR gs_fieldcat.

  " Column 39: Approval Validation Flag
  gs_fieldcat-fieldname = 'APPR_VALID'.
  gs_fieldcat-seltext_m = 'Appr Valid'.
  gs_fieldcat-col_pos = 39.
  gs_fieldcat-checkbox = 'X'.
  gs_fieldcat-outputlen = 8.
  APPEND gs_fieldcat TO gt_fieldcat.
  CLEAR gs_fieldcat.

  " Column 40: Base Unit of Measure (hidden - reference for Qty QUAN fields)
  gs_fieldcat-fieldname = 'MEINS'.
  gs_fieldcat-seltext_m = 'UoM'.
  gs_fieldcat-col_pos = 40.
  gs_fieldcat-outputlen = 3.
  gs_fieldcat-tech = 'X'.                 " Hidden/technical field
  APPEND gs_fieldcat TO gt_fieldcat.
  CLEAR gs_fieldcat.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form display_alv
*&---------------------------------------------------------------------*
*& Display ALV Grid with built field catalog
*&---------------------------------------------------------------------*
FORM display_alv.

  DATA: ls_grid_settings TYPE lvc_s_glay.

  " Build field catalog
  PERFORM build_fieldcat.
  " Build events
  PERFORM event_build.
  " Build header commentary
  PERFORM comment_build USING gt_list_top_of_page[].
  " Set layout options
  gs_layout-colwidth_optimize = 'X'.      " Optimize column width
  gs_layout-zebra = 'X'.                  " Zebra striping
  gs_layout-box_fieldname = 'SELECTED'.   " Checkbox field
  gs_layout-info_fieldname = 'LINECOLOR'. " Row color field

  ls_grid_settings-coll_top_p = 'X'.    " Enable column freeze
  ls_grid_settings-edt_cll_cb = 'X'.    " Edit cell callback

  " Display ALV Grid
  CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY'
    EXPORTING
      i_callback_program       = gv_repid
      i_callback_pf_status_set = 'SET_PF_STATUS'
      i_callback_user_command  = 'USER_COMMAND'
      i_callback_top_of_page   = 'TOP_OF_PAGE'
      is_layout                = gs_layout
      it_fieldcat              = gt_fieldcat
      it_events                = gt_events
      i_save                   = ' '
      i_grid_settings          = ls_grid_settings
    TABLES
      t_outtab                 = gt_alv_data
    EXCEPTIONS
      program_error            = 1
      OTHERS                   = 2.

  IF sy-subrc <> 0.
    MESSAGE 'Error displaying ALV' TYPE 'E'.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form comment_build
*&---------------------------------------------------------------------*
*& Build header commentary for ALV display
*&---------------------------------------------------------------------*
*&      --> lt_top_of_page - Header lines table
*&---------------------------------------------------------------------*
FORM comment_build USING lt_top_of_page TYPE slis_t_listheader.

  DATA: ls_line TYPE slis_listheader,
        lv_text TYPE char50.

  REFRESH: lt_top_of_page.

  " Header line - Report title
  CLEAR ls_line.
  ls_line-typ  = 'H'.
  ls_line-info = 'Service WO Component Approval Status Report'.
  APPEND ls_line TO lt_top_of_page.

  " Selection line - Company
  CLEAR ls_line.
  ls_line-typ  = 'S'.
  ls_line-key  = 'PT. United Tractors'.
  ls_line-info = '  '.
  APPEND ls_line TO lt_top_of_page.

  " Selection line - Execution Date
  CLEAR ls_line.
  ls_line-typ  = 'S'.
  ls_line-key  = 'Execution Date:'.
  WRITE sy-datum TO ls_line-info DD/MM/YYYY.
  APPEND ls_line TO lt_top_of_page.

  " Selection line - User Name
  CLEAR ls_line.
  ls_line-typ  = 'S'.
  ls_line-key  = 'User Name:'.
  ls_line-info = sy-uname.
  APPEND ls_line TO lt_top_of_page.

  " Selection line - Authorization Level
  CLEAR ls_line.
  ls_line-typ  = 'S'.
  ls_line-key  = 'User Auth:'.
  CASE gv_auth_level.
    WHEN 'L1'.
      ls_line-info = 'BCSPPD (L1)'.
*    WHEN 'L2'.
*      ls_line-info = 'PDH (L2)'. " REMOVED: PDH(L2) no longer in approval flow
    WHEN 'L3'.
      ls_line-info = 'SDH (L3)'.
    WHEN 'L4'.
      ls_line-info = 'Branch (L4)'.
    WHEN 'L5'.
      ls_line-info = 'HELPDESK (L5)'.
    WHEN OTHERS.
      ls_line-info = 'No Authorization'.
  ENDCASE.
  APPEND ls_line TO lt_top_of_page.

  " Selection line - Approval Status Filter
  CLEAR ls_line.
  ls_line-typ  = 'S'.
  ls_line-key  = 'Status Filter:'.
  IF rb_all = 'X'.
    ls_line-info = 'All Status'.
  ELSEIF rb_pend = 'X'.
    ls_line-info = 'Pending Approve'.
  ELSEIF rb_appr = 'X'.
    ls_line-info = 'Approve Parts'.
  ELSEIF rb_rejt = 'X'.
    ls_line-info = 'Reject Approval'.
  ENDIF.
  APPEND ls_line TO lt_top_of_page.

  " Selection line - Interchange Filter
*  CLEAR ls_line.
*  ls_line-typ  = 'S'.
*  ls_line-key  = 'Interchange:'.
*  CASE p_intch.
*    WHEN 'A'.
*      ls_line-info = 'All'.
*    WHEN 'Y'.
*      ls_line-info = 'Yes'.
*    WHEN 'N'.
*      ls_line-info = 'No'.
*  ENDCASE.
*  APPEND ls_line TO lt_top_of_page.

  " Selection line - Total Records
  CLEAR ls_line.
  ls_line-typ  = 'S'.
  ls_line-key  = 'Total Records:'.
  lv_text = gv_lines.
  CONDENSE lv_text.
  CONCATENATE lv_text 'records found' INTO ls_line-info SEPARATED BY space.
  APPEND ls_line TO lt_top_of_page.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form top_of_page
*&---------------------------------------------------------------------*
*& Display header at top of page
*&---------------------------------------------------------------------*
FORM top_of_page.
  CALL FUNCTION 'REUSE_ALV_COMMENTARY_WRITE'
    EXPORTING
      it_list_commentary = gt_list_top_of_page
      i_logo             = 'UT_LOGO'
      i_end_of_list_grid = ' '.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form event_build
*&---------------------------------------------------------------------*
*& Build event table for ALV
*&---------------------------------------------------------------------*
FORM event_build.

  " Register top of page event
  PERFORM eventtab_build USING gt_events
                         slis_ev_top_of_page
                         'TOP_OF_PAGE'.

  " Register user command event
  PERFORM eventtab_build USING gt_events
                      slis_ev_user_command
                      'USER_COMMAND'.

  " Register PF status event
  PERFORM eventtab_build USING gt_events
                      slis_ev_pf_status_set
                      'SET_PF_STATUS'.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form eventtab_build
*&---------------------------------------------------------------------*
*& Build individual event entry
*&---------------------------------------------------------------------*
*&      --> rt_events - Event table
*&      --> p_event_name - Event name
*&      --> p_form_name - Form routine name
*&---------------------------------------------------------------------*
FORM eventtab_build USING rt_events TYPE slis_t_event
                          p_event_name TYPE slis_alv_event-name
                          p_form_name TYPE slis_alv_event-form.

  DATA: ls_event TYPE slis_alv_event.

  " Get all available events if table is empty
  IF rt_events[] IS INITIAL.
    CALL FUNCTION 'REUSE_ALV_EVENTS_GET'
      EXPORTING
        i_list_type = 0
      IMPORTING
        et_events   = rt_events.
  ENDIF.

  " Find and modify the specific event
  READ TABLE rt_events WITH KEY name = p_event_name INTO ls_event.
  IF sy-subrc = 0.
    ls_event-form = p_form_name.
    MODIFY rt_events FROM ls_event INDEX sy-tabix
      TRANSPORTING form.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form set_pf_status
*&---------------------------------------------------------------------*
*& Set PF-Status for ALV toolbar
*&---------------------------------------------------------------------*
FORM set_pf_status USING extab TYPE slis_t_extab.

  "SET PF-STATUS 'STANDARD_FULLSCREEN' OF PROGRAM 'SAPLKKBL' EXCLUDING extab.
  SET PF-STATUS 'APPROVAL'.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form user_command
*&---------------------------------------------------------------------*
*& Handle user commands (buttons, double-click)
*&---------------------------------------------------------------------*
FORM user_command USING r_ucomm LIKE sy-ucomm
                        rs_selfield TYPE slis_selfield.

  DATA: lv_count  TYPE i,
        lv_answer TYPE char1,
        lv_tabix  TYPE sy-tabix,
        lv_reason TYPE char100,
        lt_fields TYPE TABLE OF sval,
        ls_field  TYPE sval.

  CASE r_ucomm.
    WHEN '&IC1'. " Double-click
      READ TABLE gt_alv_data INTO gs_alv_data INDEX rs_selfield-tabindex.
      IF sy-subrc = 0.
        " Check which field was clicked
        CASE rs_selfield-fieldname.
          WHEN 'AUFNR'. " Work Order
            SET PARAMETER ID 'ANR' FIELD gs_alv_data-aufnr.
            CALL TRANSACTION 'IW33' AND SKIP FIRST SCREEN.
          WHEN 'WARPL'. " Maintenance Plan
            SET PARAMETER ID 'MPL' FIELD gs_alv_data-warpl.
            CALL TRANSACTION 'IP10' AND SKIP FIRST SCREEN.
          WHEN 'REASON_CHANGE'. " Reason for Change - Show dropdown popup
            PERFORM show_reason_change USING rs_selfield-tabindex
                                        CHANGING rs_selfield-refresh.
          WHEN 'REASON_REJECT'. " Reason for Rejection - Show dropdown popup
            PERFORM show_reason_reject USING rs_selfield-tabindex
                                        CHANGING rs_selfield-refresh.
        ENDCASE.
      ENDIF.
    WHEN 'APPROVE'. "Approve button clicked
      PERFORM process_approve CHANGING rs_selfield-refresh.
    WHEN 'REJECT'. "Reject button clicked
      PERFORM process_reject CHANGING rs_selfield-refresh.
    WHEN 'RESET'. "Reset button clicked
      PERFORM process_reset CHANGING rs_selfield-refresh.
    WHEN 'DELETE'. "Delete Reason Change/Reject based on authorization
      PERFORM process_delete_reason CHANGING rs_selfield-refresh.

    WHEN 'SEND'. "Send Email Notification to BRANCH by Plant
      PERFORM process_send_email CHANGING rs_selfield-refresh.

    WHEN 'SEND_HO'. "Send Email Notification to BCSPPD HO
      PERFORM process_send_email_ho CHANGING rs_selfield-refresh.
  ENDCASE.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form process_approve
*&---------------------------------------------------------------------*
*& Process sequential approval for selected items
*& Match OR (Mismatch + PLNNR not registered): SDH -> Full Approved  (PDH removed)
*& Mismatch + PLNNR registered:                BCSPPD -> SDH -> Full Approved  (PDH removed)
*&---------------------------------------------------------------------*
FORM process_approve CHANGING cv_refresh TYPE char1.

  DATA: lv_count          TYPE i,
        lv_answer         TYPE char1,
        lv_tabix          TYPE sy-tabix,
        lv_match          TYPE flag,
        lv_auth_ok        TYPE flag,
        lv_skip_count     TYPE i,
        lv_auth_level     TYPE string,
        lv_new_status     TYPE char20,
        lv_current_status TYPE char20,
        lt_wo_release     TYPE tt_aufnr_range,
        ls_wo_range       LIKE LINE OF lt_wo_release.

  DATA: BEGIN OF ls_caufv_chk,
          ilart    TYPE afih-ilart,
          zzsfcase TYPE aufk-zzsfcase,
        END OF ls_caufv_chk,
        lv_aufnr_conv TYPE aufnr.

  " Check if user has any approval authorization
  IF gv_auth_sdh = ' '                  " gv_auth_pdh removed (PDH L2 no longer in flow)
      AND gv_auth_bcsppd = ' '
      AND gv_auth_branch = ' '
      AND gv_auth_helpdesk = ' '.
    MESSAGE 'You do not have authorization to approve items' TYPE 'E'.
    RETURN.
  ENDIF.

  " Determine user's authorization level for display
  IF gv_auth_helpdesk = 'X'.
    lv_auth_level = 'HELPDESK'.
  ELSEIF gv_auth_bcsppd = 'X'.
    lv_auth_level = 'BCSPPD'.
*  ELSEIF gv_auth_pdh = 'X'.      " REMOVED: PDH(L2)
*    lv_auth_level = 'PDH'.
  ELSEIF gv_auth_sdh = 'X'.
    lv_auth_level = 'SDH'.
  ELSEIF gv_auth_branch = 'X'.
    lv_auth_level = 'Branch'.
  ENDIF.

  " Count selected items
  CLEAR: lv_count, lv_skip_count.
  LOOP AT gt_alv_data INTO gs_alv_data WHERE selected = 'X'.
    lv_count = lv_count + 1.
  ENDLOOP.

  IF lv_count = 0.
    MESSAGE 'Please select at least one item to approve' TYPE 'I'.
    RETURN.
  ENDIF.

  " Confirm approval
  CALL FUNCTION 'POPUP_TO_CONFIRM'
    EXPORTING
      titlebar              = 'Approve Items'
      text_question         = |Approve { lv_count } selected item(s) as { lv_auth_level }?|
      text_button_1         = 'Yes'
      text_button_2         = 'No'
      default_button        = '2'
      display_cancel_button = ''
    IMPORTING
      answer                = lv_answer
    EXCEPTIONS
      text_not_found        = 1
      OTHERS                = 2.

  IF lv_answer <> '1'.
    RETURN.
  ENDIF.
  DATA lv_continue TYPE flag.
  PERFORM lock CHANGING lv_continue.
  CHECK lv_continue = 'X'.
  " Process approval with authorization validation
  CLEAR lv_count.
  LOOP AT gt_alv_data INTO gs_alv_data WHERE selected = 'X'.
    lv_tabix = sy-tabix.
    lv_current_status = gs_alv_data-approval_stat.

    " ── Case SF Number validation (ZZSFCASE) ──
    " Only for Order Type ZISO: if Activity Type (ILART) is one of
    " TRS USW USN SER DEL INS FAC MID OVH PPM LOG DEV UIW
    " then a Case Number must be assigned before approval.
    IF gs_alv_data-auart = 'ZISO'.
      CLEAR: ls_caufv_chk, lv_aufnr_conv.
      CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
        EXPORTING
          input  = gs_alv_data-aufnr
        IMPORTING
          output = lv_aufnr_conv.
      SELECT SINGLE h~ilart, a~zzsfcase
        INTO @ls_caufv_chk
        FROM afih AS h
        INNER JOIN aufk AS a ON a~aufnr = h~aufnr
        WHERE h~aufnr = @lv_aufnr_conv.
      IF sy-subrc = 0.
        IF 'TRS USW USN SER DEL INS FAC MID OVH PPM LOG DEV UIW' CS ls_caufv_chk-ilart
          AND ls_caufv_chk-ilart IS NOT INITIAL.
          IF ls_caufv_chk-zzsfcase IS INITIAL.
            MESSAGE w398(00) WITH 'Please assign Case Number to WO' gs_alv_data-aufnr 'via ZSVC_ASSIGNCASEWO' ''.
            gs_alv_data-selected = space.
            MODIFY gt_alv_data FROM gs_alv_data INDEX lv_tabix TRANSPORTING selected.
            lv_skip_count = lv_skip_count + 1.
            CONTINUE.
          ENDIF.
        ENDIF.
      ENDIF.
    ENDIF.

    CLEAR : lv_auth_ok, lv_new_status.

    "Approval flows
    IF gv_auth_helpdesk = 'X'.     " HELPDESK
      IF lv_current_status = 'Full Approved'.
        lv_skip_count = lv_skip_count + 1.
        CONTINUE.
      ENDIF.
      lv_auth_ok = 'X'.
      lv_new_status = 'Full Approved'.  " HELPDESK => fully approve

    ELSEIF gs_alv_data-comp_status = 'X'
         OR ( gs_alv_data-comp_status = space AND gs_alv_data-need_ho = space ).
      " MATCHED component => Only L3 (SDH) needed  (L2 PDH removed)
      " OR MISMATCH + PLNNR NOT registered => also L3 (SDH) only, skip L1
      " Flow: SDH > Full Approved  (PDH removed from flow)
      CASE lv_current_status.
        WHEN 'Pending Approve'.
          IF gv_auth_sdh = 'X'.           " SDH approves directly (PDH step removed)
            lv_auth_ok = 'X'.
            lv_new_status = 'Full Approved'. "Fully approved
          ENDIF.
*        WHEN 'Approved PDH'.             " No PDH
*          IF gv_auth_sdh = 'X'.
*            lv_auth_ok = 'X'.
*            lv_new_status = 'Full Approved'. "Fully approved
*          ENDIF.
        WHEN 'Full Approved' OR 'Approved SDH'.
          lv_skip_count = lv_skip_count + 1.
          CONTINUE.
      ENDCASE.
    ELSE.
      " comp_status = ' ' AND need_ho = 'X' => PLNNR registered + MISMATCH
      " L1 (BCSPPD), L3 (SDH) needed  (L2 PDH removed)
      " Flow: BCSPPD > SDH > Full Approved  (PDH removed from flow)
      CASE lv_current_status.
        WHEN 'Pending Approve'.
          IF gv_auth_bcsppd = 'X'.     " First Approval: BCSPPD HO
            IF gs_alv_data-reason_change IS INITIAL.
              MESSAGE |Item { gs_alv_data-aufnr } from { gs_alv_data-werks }: Please fill Reason Change before BCSPPD approval| TYPE 'W'.
              gs_alv_data-selected = space.
              MODIFY gt_alv_data FROM gs_alv_data INDEX lv_tabix TRANSPORTING selected.
              lv_skip_count = lv_skip_count + 1.
              CONTINUE.
            ENDIF.
            lv_auth_ok = 'X'.
            lv_new_status = 'Approved BCSPPD'.
          ENDIF.
        WHEN 'Approved BCSPPD'.
          " Second approval needed: SDH  (PDH step removed)
          IF gv_auth_sdh = 'X'.
            lv_auth_ok = 'X'.
            lv_new_status = 'Full Approved'.  " Fully approved (PDH step removed)
          ENDIF.
*        WHEN 'Approved PDH'.             " REMOVED: PDH(L2)
*          " Third approval needed: SDH
*          IF gv_auth_sdh = 'X'.
*            lv_auth_ok = 'X'.
*            lv_new_status = 'Full Approved'.  " Fully approved
*          ENDIF.
        WHEN 'Full Approved' OR 'Approved SDH'.
          " Already fully approved
          lv_skip_count = lv_skip_count + 1.
          CONTINUE.
      ENDCASE.
    ENDIF.

    IF lv_auth_ok = ' '.  " Skip if user doesn't have authorization for this step
      lv_skip_count = lv_skip_count + 1.
      CONTINUE.
    ENDIF.

    " Update status
    gs_alv_data-approval_stat = lv_new_status.
    gs_alv_data-approver = sy-uname.
    gs_alv_data-approved_date = sy-datum.
    gs_alv_data-selected = ''.
    " Level 1 (BCSPPD)
    IF gv_auth_bcsppd = 'X' AND gs_alv_data-approval_lvl1 = space.
      gs_alv_data-approved_by_lvl1 = sy-uname.
      gs_alv_data-approved_date_lvl1 = sy-datum.
      gs_alv_data-approved_time_lvl1 = sy-uzeit.
    ENDIF.

    " Level 3 (SDH)
    IF gv_auth_sdh = 'X' AND gs_alv_data-approval_lvl3 = space.
      gs_alv_data-approved_by_lvl3 = sy-uname.
      gs_alv_data-approved_date_lvl3 = sy-datum.
      gs_alv_data-approved_time_lvl3 = sy-uzeit.
    ENDIF.

    " HELPDESK approval => real user flags based on need_ho
    IF gv_auth_helpdesk = 'X'.
      IF gs_alv_data-need_ho = 'X'.       " Tasklist/PLNNR registered + mismatch => needs L1 (BCSPPD) + L3 (SDH)
        gs_alv_data-approval_lvl1 = 'X'.  " L1 = BCSPPD approved
        "gs_alv_data-approval_lvl2 = 'X'.  " L2 = PDH     *REMOVED: PDH(L2)
        gs_alv_data-approval_lvl3 = 'X'.  " L3 = SDH approved
        gs_alv_data-chk_bcsppd = 'X'.     " BCSPPD checkbox
        "gs_alv_data-chk_pdh = 'X'.        " PDH checkbox *REMOVED: PDH(L2)
        gs_alv_data-chk_sdh = 'X'.        " SDH checkbox
        " Track L1 approval
        IF gs_alv_data-approved_by_lvl1 = space.
          gs_alv_data-approved_by_lvl1 = sy-uname.
          gs_alv_data-approved_date_lvl1 = sy-datum.
          gs_alv_data-approved_time_lvl1 = sy-uzeit.
        ENDIF.
      ELSE.
        " PLNNR not registered OR match => only L3 (SDH) needed
        CLEAR: gs_alv_data-approval_lvl1,  " L1 not needed
               gs_alv_data-chk_bcsppd.     " BCSPPD not needed
        gs_alv_data-approval_lvl3 = 'X'.  " L3 = SDH approved
        gs_alv_data-chk_sdh = 'X'.        " SDH checkbox
      ENDIF.
      gs_alv_data-appr_valid = 'X'.     " Approval valid for Release
      " Track L3 approval
      IF gs_alv_data-approved_by_lvl3 = space.
        gs_alv_data-approved_by_lvl3 = sy-uname.
        gs_alv_data-approved_date_lvl3 = sy-datum.
        gs_alv_data-approved_time_lvl3 = sy-uzeit.
      ENDIF.
    ELSE. " Approval by other roles (BCSPPD, SDH)
      IF gv_auth_bcsppd = 'X'.
        gs_alv_data-approval_lvl1 = 'X'.  " L1 = BCSPPD approved
      ENDIF.
*      IF gv_auth_pdh = 'X'.              " REMOVED: PDH(L2)
*        gs_alv_data-approval_lvl2 = 'X'.  " L2 = PDH approved
*      ENDIF.
      IF gv_auth_sdh = 'X'.
        gs_alv_data-approval_lvl3 = 'X'.  " L3 = SDH approved
      ENDIF.
    ENDIF.

    " Set appr_valid when Full Approved
    IF lv_new_status = 'Full Approved'.
      gs_alv_data-appr_valid = 'X'.
    ENDIF.

    " Set traffic light based on new status
    PERFORM set_traffic_light CHANGING gs_alv_data.

    " Update database table
    PERFORM update_approval_record USING gs_alv_data.

    " Collect WO
    IF lv_new_status = 'Full Approved'.
      READ TABLE lt_wo_release WITH KEY low = gs_alv_data-aufnr TRANSPORTING NO FIELDS.
      IF sy-subrc <> 0.
        CLEAR ls_wo_range.
        ls_wo_range-sign   = 'I'.
        ls_wo_range-option = 'EQ'.
        ls_wo_range-low    = gs_alv_data-aufnr.
        APPEND ls_wo_range TO lt_wo_release.
      ENDIF.
*      PERFORM set_wo_status_apvd USING gs_alv_data-aufnr. " Set REQU to APVD
*      PERFORM trigger_auto_release_wo USING gs_alv_data-aufnr. " Auto RELEASE WO
    ENDIF.

    " Update internal table
    MODIFY gt_alv_data FROM gs_alv_data INDEX lv_tabix TRANSPORTING
           approval_stat traffic_light approver approved_date selected
           chk_bcsppd chk_pdh chk_sdh approval_lvl1 approval_lvl2 approval_lvl3 appr_valid
           approved_by_lvl1 approved_date_lvl1 approved_time_lvl1
           approved_by_lvl3 approved_date_lvl3 approved_time_lvl3.
    lv_count = lv_count + 1.
  ENDLOOP.

  " Commit changes
  COMMIT WORK AND WAIT.

  " Ensure all WO components exist in ZTWOAPPR before syncing header.
  " Without this, partially-approved WOs could be released prematurely
  " because ZFM_APPRH_SYNC only sees the approved rows in ZTWOAPPR.
  PERFORM ensure_pending_components USING lt_wo_release.

  "Sync Header for each WO
  PERFORM sync_header_table USING lt_wo_release.

  " Release control is now via ZTWOAPPRH header table (sync_header_tables above).
  " Process WO RELEASE
*  IF lt_wo_release IS NOT INITIAL.
*    PERFORM process_wo_release_batch USING lt_wo_release.
*  ENDIF.

  IF lv_count > 0.
    IF lv_skip_count > 0.
      MESSAGE |{ lv_count } item(s) approved as { lv_auth_level }. { lv_skip_count } item(s) skipped| TYPE 'S'.
    ELSE.
      MESSAGE |{ lv_count } item(s) approved by { lv_auth_level }| TYPE 'S'.
    ENDIF.
  ELSE.
    MESSAGE |No items approved - Waiting for previous approval level or already approved| TYPE 'W'.
  ENDIF.
  cv_refresh = 'X'.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form process_reject
*&---------------------------------------------------------------------*
*& Process rejection for selected items with authorization check
*& SDH/BCSPPD can reject based on component match status  (PDH removed)
*&---------------------------------------------------------------------*
FORM process_reject CHANGING cv_refresh TYPE char1.

  DATA: lv_count      TYPE i,
        lv_answer     TYPE char1,
        lv_match      TYPE flag,
        lv_auth_ok    TYPE flag,
        lv_skip_count TYPE i,
        lv_auth_level TYPE string.

  " Check if user has any rejection authorization
  IF gv_auth_sdh = ' ' AND               " gv_auth_pdh removed
     gv_auth_bcsppd = ' ' AND gv_auth_branch = ' ' AND
     gv_auth_helpdesk = ' '.
    MESSAGE 'You do not have authorization to reject items' TYPE 'E'.
    RETURN.
  ENDIF.

  " Determine user's authorization level for display
  IF gv_auth_helpdesk = 'X'.
    lv_auth_level = 'HELPDESK'.
  ELSEIF gv_auth_bcsppd = 'X'.
    lv_auth_level = 'BCSPPD'.
*  ELSEIF gv_auth_pdh = 'X'.              " REMOVED: PDH(L2)
*    lv_auth_level = 'PDH'.
  ELSEIF gv_auth_sdh = 'X'.
    lv_auth_level = 'SDH'.
  ELSEIF gv_auth_branch = 'X'.
    lv_auth_level = 'Branch'.
  ENDIF.

  " Count selected items
  CLEAR: lv_count, lv_skip_count.
  LOOP AT gt_alv_data INTO gs_alv_data WHERE selected = 'X'.
    lv_count = lv_count + 1.
  ENDLOOP.

  IF lv_count = 0.
    MESSAGE 'Please select at least one item to reject' TYPE 'I'.
    RETURN.
  ENDIF.

  " Confirm rejection
  CALL FUNCTION 'POPUP_TO_CONFIRM'
    EXPORTING
      titlebar              = 'Reject Items'
      text_question         = |Reject { lv_count } selected item(s) as { lv_auth_level }?|
      text_button_1         = 'Yes'
      text_button_2         = 'No'
      default_button        = '2'
      display_cancel_button = ''
    IMPORTING
      answer                = lv_answer
    EXCEPTIONS
      text_not_found        = 1
      OTHERS                = 2.

  IF lv_answer <> '1'.
    RETURN.
  ENDIF.
  DATA lv_continue TYPE flag.
  PERFORM lock CHANGING lv_continue.
  CHECK lv_continue = 'X'.
  " Process rejection
  CLEAR lv_count.
  LOOP AT gt_alv_data ASSIGNING FIELD-SYMBOL(<fs_data>) WHERE selected = 'X'.

    " Check component match (RESB-MATNR compare STPO-IDNRK)
    PERFORM check_component_match USING <fs_data> CHANGING lv_match.

    " Validate authorization based on component match
    CLEAR lv_auth_ok.
    IF gv_auth_helpdesk = 'X'.
      lv_auth_ok = 'X'.
    ELSEIF lv_match = 'X'.
      " Components match - SDH or BCSPPD can reject (No PDH)
      IF gv_auth_sdh = 'X' OR gv_auth_bcsppd = 'X'.  " gv_auth_pdh removed
        lv_auth_ok = 'X'.
      ENDIF.
    ELSE.
      " Components don't match - BCSPPD required (No PDH)
      IF gv_auth_bcsppd = 'X'.  " gv_auth_pdh removed
        lv_auth_ok = 'X'.
      ENDIF.
    ENDIF.

    IF lv_auth_ok = ' '.
      lv_skip_count = lv_skip_count + 1.
      CONTINUE.  " Skip items user is not authorized to reject
    ENDIF.

    " BCSPPD must fill Reason Reject before rejecting
    IF gv_auth_bcsppd = 'X' AND <fs_data>-reason_reject IS INITIAL.
      MESSAGE |WO item { <fs_data>-aufnr } from { gs_alv_data-werks }: Please fill Reason Reject before BCSPPD rejection| TYPE 'W'.
      lv_skip_count = lv_skip_count + 1.
      CONTINUE.
    ENDIF.

    " Update status
    <fs_data>-approval_stat = 'Reject Approval'.
    <fs_data>-traffic_light = icon_red_light.
    <fs_data>-approver = sy-uname.
    <fs_data>-approved_date = sy-datum.
    <fs_data>-selected = ''.
    " Clear checkboxes and approval level flags when Rejected
    CLEAR: <fs_data>-chk_bcsppd,
           <fs_data>-chk_pdh,
           <fs_data>-chk_sdh,
           <fs_data>-approval_lvl1,
           <fs_data>-approval_lvl2,
           <fs_data>-approval_lvl3,
           <fs_data>-approved_by_lvl1,
           <fs_data>-approved_date_lvl1,
           <fs_data>-approved_time_lvl1,
           <fs_data>-approved_by_lvl3,
           <fs_data>-approved_date_lvl3,
           <fs_data>-approved_time_lvl3.

    " Update database table
    PERFORM update_approval_record USING <fs_data>.
    lv_count = lv_count + 1.
    PERFORM unlock USING <fs_data>-aufnr.
  ENDLOOP.
  .
  " Commit changes
  COMMIT WORK AND WAIT.
  IF lv_count > 0.
    IF lv_skip_count > 0.
      MESSAGE |{ lv_count } item(s) rejected. { lv_skip_count } item(s) skipped (no authorization)| TYPE 'S'.
    ELSE.
      MESSAGE |{ lv_count } item(s) rejected successfully| TYPE 'S'.
    ENDIF.
  ELSE.
    MESSAGE 'No items rejected - insufficient authorization for selected items' TYPE 'W'.
  ENDIF.
  cv_refresh = 'X'.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form process_reset
*&---------------------------------------------------------------------*
*& Process reset to pending for selected items
*&---------------------------------------------------------------------*
FORM process_reset CHANGING cv_refresh TYPE char1.

  DATA: lv_count  TYPE i,
        lv_answer TYPE char1,
        lv_tabix  TYPE sy-tabix.

  " Check if user has HELPDESK authorization for reset
  IF gv_auth_helpdesk = ' '.
    MESSAGE 'Only HELPDESK users can reset approval status' TYPE 'E'.
    RETURN.
  ENDIF.

  " Count selected items
  CLEAR lv_count.
  LOOP AT gt_alv_data INTO gs_alv_data WHERE selected = 'X'.
    lv_count = lv_count + 1.
  ENDLOOP.

  IF lv_count = 0.
    MESSAGE 'Please select at least one item to reset' TYPE 'I'.
    RETURN.
  ENDIF.

  " Confirm reset
  CALL FUNCTION 'POPUP_TO_CONFIRM'
    EXPORTING
      titlebar              = 'Reset Approval'
      text_question         = |Reset { lv_count } item(s) to Pending Approval?|
      text_button_1         = 'Yes'
      text_button_2         = 'No'
      default_button        = '2'
      display_cancel_button = ''
    IMPORTING
      answer                = lv_answer
    EXCEPTIONS
      text_not_found        = 1
      OTHERS                = 2.

  IF lv_answer <> '1'.
    RETURN.
  ENDIF.
  DATA lv_continue TYPE flag.
  PERFORM lock CHANGING lv_continue.
  CHECK lv_continue = 'X'.
  " Collect unique WO numbers for header reset
  DATA: lt_wo_reset TYPE tt_aufnr_range,
        ls_wo_range LIKE LINE OF lt_wo_reset.

  " Process reset
  LOOP AT gt_alv_data INTO gs_alv_data WHERE selected = 'X'.
    lv_tabix = sy-tabix.

    " Update status back to Pending Approval
    gs_alv_data-approval_stat = 'Pending Approve'.
    gs_alv_data-traffic_light = icon_yellow_light.
    gs_alv_data-selected = ''.
    " Clear data when resetting
    CLEAR: gs_alv_data-approver,
           gs_alv_data-approved_date,
           gs_alv_data-reason_change,
           gs_alv_data-reason_reject.

    " Clear all approval checkboxes and level flags
    CLEAR: gs_alv_data-chk_bcsppd,
           gs_alv_data-chk_pdh,
           gs_alv_data-chk_sdh,
           gs_alv_data-approval_lvl1,
           gs_alv_data-approval_lvl2,
           gs_alv_data-approval_lvl3,
           gs_alv_data-appr_valid,
           gs_alv_data-approved_by_lvl1,
           gs_alv_data-approved_date_lvl1,
           gs_alv_data-approved_time_lvl1,
           gs_alv_data-approved_by_lvl3,
           gs_alv_data-approved_date_lvl3,
           gs_alv_data-approved_time_lvl3.

    " Collect unique WO for reset
    READ TABLE lt_wo_reset WITH KEY low = gs_alv_data-aufnr TRANSPORTING NO FIELDS.
    IF sy-subrc <> 0.
      ls_wo_range-sign   = 'I'.
      ls_wo_range-option = 'EQ'.
      ls_wo_range-low    = gs_alv_data-aufnr.
      APPEND ls_wo_range TO lt_wo_reset.
    ENDIF.

    " Update database table
    PERFORM update_approval_record USING gs_alv_data.

    " Update internal table
    MODIFY gt_alv_data FROM gs_alv_data INDEX lv_tabix TRANSPORTING
           approval_stat traffic_light approver approved_date reason_change reason_reject selected
           chk_bcsppd chk_pdh chk_sdh approval_lvl1 approval_lvl2 approval_lvl3 appr_valid
           approved_by_lvl1 approved_date_lvl1 approved_time_lvl1
           approved_by_lvl3 approved_date_lvl3 approved_time_lvl3.
    PERFORM unlock USING gs_alv_data-aufnr.
  ENDLOOP.

  " Commit changes
  COMMIT WORK AND WAIT.

  "Reset Header tabel (ZTAPPRH)
  PERFORM reset_header_tables USING lt_wo_reset.

  MESSAGE |{ lv_count } item(s) reset to Pending Approval| TYPE 'S'.
  cv_refresh = 'X'.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form process_delete_reason
*&---------------------------------------------------------------------*
*& Delete Reason Change or Reason Reject based on user authorization
*&---------------------------------------------------------------------*
*&      <-- RS_SELFIELD_REFRESH
*&---------------------------------------------------------------------*
FORM process_delete_reason  CHANGING pv_refresh TYPE char1.

  DATA: lv_count      TYPE i,
        lv_answer     TYPE char1,
        lv_tabix      TYPE sy-tabix,
        lv_field_name TYPE string,
        lv_auth_desc  TYPE string.

  " Determine which field user can delete based on authorization
  " L4 (Branch) = Can delete Reason Change only
  " L1 (BCSPPD) = Can delete Reason Reject only
  " L5 (Helpdesk) = Can delete both
  " L3 (SDH) = Cannot delete any reason
  " L2 (PDH) = REMOVED from approval flow
  IF gv_auth_level = 'L4'.         " Branch
    lv_field_name = 'Reason Change'.
    lv_auth_desc = 'Branch'.
  ELSEIF gv_auth_level = 'L1'.     " BCSPPD
    lv_field_name = 'Reason Reject'.
    lv_auth_desc = 'BCSPPD'.
  ELSEIF gv_auth_level = 'L5' OR gv_auth_helpdesk = 'X'.  " HELPDESK
    lv_field_name = 'Both'.
    lv_auth_desc = 'HELPDESK'.
*  ELSEIF gv_auth_level = 'L2'.     " PDH users DELETE
*    MESSAGE 'PDH users cannot delete Reason. Please contact BCSPPD HO.' TYPE 'E'.
*    RETURN.
  ELSEIF gv_auth_level = 'L3'.     " SDH users - NOT authorized
    MESSAGE 'SDH users cannot delete Reason. Please contact BCSPPD HO' TYPE 'E'.
    RETURN.
  ELSE.
    MESSAGE 'You do not have authorization to delete reasons' TYPE 'E'.
    RETURN.
  ENDIF.

  CLEAR lv_count.
  LOOP AT gt_alv_data INTO gs_alv_data WHERE selected = 'X'.
    lv_count = lv_count + 1.
  ENDLOOP.

  IF lv_count = 0.
    MESSAGE 'Please select at least one item to delete reason' TYPE 'I'.
    RETURN.
  ENDIF.

  CALL FUNCTION 'POPUP_TO_CONFIRM'
    EXPORTING
      titlebar              = 'Delete Reason'
      text_question         = |Delete { lv_field_name } for { lv_count } selected item(s)?|
      text_button_1         = 'Yes'
      text_button_2         = 'No'
      default_button        = '2'
      display_cancel_button = ''
    IMPORTING
      answer                = lv_answer
    EXCEPTIONS
      text_not_found        = 1
      OTHERS                = 2.

  IF lv_answer <> '1'.
    RETURN.
  ENDIF.

  " Process deletion
  CLEAR lv_count.
  LOOP AT gt_alv_data ASSIGNING FIELD-SYMBOL(<fs_del>) WHERE selected = 'X'.
    lv_tabix = sy-tabix.
    " Clear the appropriate field based on authorization
    CASE gv_auth_level.
      WHEN 'L4'.    " Branch - clear Reason Change only
        CLEAR <fs_del>-reason_change.
      WHEN 'L1'.    " BCSPPD - clear Reason Reject only
        CLEAR <fs_del>-reason_reject.
        <fs_del>-approval_stat = 'Pending Approve'. " When Reason Reject is deleted, revert status back to Pending Approve
        <fs_del>-traffic_light = icon_yellow_light.
        CLEAR: <fs_del>-approver,
               <fs_del>-approved_date.
      WHEN 'L5'.    " HELPDESK - clear both
        CLEAR: <fs_del>-reason_change,
               <fs_del>-reason_reject.
        <fs_del>-approval_stat = 'Pending Approve'.
        <fs_del>-traffic_light = icon_yellow_light.
        CLEAR: <fs_del>-approver,
               <fs_del>-approved_date.
    ENDCASE.
    " Clear selection
    <fs_del>-selected = ''.
    PERFORM update_approval_record USING <fs_del>.
    lv_count = lv_count + 1.
  ENDLOOP.

  " Commit changes
  COMMIT WORK AND WAIT.

  IF lv_count > 0.
    MESSAGE |{ lv_count } item(s): { lv_field_name } deleted successfully| TYPE 'S'.
  ELSE.
    MESSAGE 'No items processed' TYPE 'W'.
  ENDIF.
  pv_refresh = 'X'.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form update_approval_record
*&---------------------------------------------------------------------*
*& Update or insert approval record in ZTWOAPPR table
*&---------------------------------------------------------------------*
FORM update_approval_record USING is_data TYPE ty_alv_output.

  DATA: lt_data TYPE TABLE OF ty_alv_output,
        ls_data TYPE ty_alv_output.

  " Convert single record to internal table
  ls_data = is_data.
  INSERT ls_data INTO TABLE lt_data.

  PERFORM batch_data_update USING lt_data.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form batch_data_update
*&---------------------------------------------------------------------*
*& batch update/insert approval records in ZTWOAPPR table
*&---------------------------------------------------------------------*
FORM batch_data_update USING it_data TYPE table.

  DATA: lt_approval    TYPE TABLE OF ztwoappr,
        ls_approval    TYPE ztwoappr,
        lt_existing    TYPE TABLE OF ztwoappr,
        ls_existing    TYPE ztwoappr,
        ls_data        TYPE ty_alv_output,
        lv_aufnr       TYPE aufnr,
        lv_matnr       TYPE matnr,
        lv_error_count TYPE i.

  " First, collect all keys to check existing records
  DATA: lt_keys TYPE TABLE OF ztwoappr.
  LOOP AT it_data INTO ls_data.
    CLEAR ls_approval.

    " Convert AUFNR back (add leading zeros)
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = ls_data-aufnr
      IMPORTING
        output = lv_aufnr.

    " Convert MATNR back (add leading zeros)
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = ls_data-matnr
      IMPORTING
        output = lv_matnr.

    ls_approval-aufnr = lv_aufnr.
    ls_approval-matnr = lv_matnr.
    INSERT ls_approval INTO TABLE lt_keys.
  ENDLOOP.

  IF lt_keys IS NOT INITIAL.
    SELECT *
      INTO TABLE lt_existing
      FROM ztwoappr
      FOR ALL ENTRIES IN lt_keys
      WHERE aufnr = lt_keys-aufnr
        AND matnr = lt_keys-matnr.
  ENDIF.

  " Build internal table
  LOOP AT it_data INTO ls_data.
    CLEAR: ls_approval, lv_aufnr, lv_matnr.

    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = ls_data-aufnr
      IMPORTING
        output = lv_aufnr.

    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = ls_data-matnr
      IMPORTING
        output = lv_matnr.

    READ TABLE lt_existing INTO ls_existing
      WITH KEY aufnr = lv_aufnr
               matnr = lv_matnr.

    IF sy-subrc = 0.
      ls_approval = ls_existing.
    ELSE.
      ls_approval-created_by   = sy-uname.
      ls_approval-created_date = sy-datum.
      ls_approval-created_time = sy-uzeit.
    ENDIF.

    " Fill/update approval record fields
    ls_approval-mandt         = sy-mandt.
    ls_approval-aufnr         = lv_aufnr.
    ls_approval-matnr         = lv_matnr.
    ls_approval-change_id     = ls_data-change_id.
    ls_approval-approval_stat = ls_data-approval_stat.
    ls_approval-reason_change = ls_data-reason_change.
    ls_approval-reason_reject = ls_data-reason_reject.
    ls_approval-agingdays     = ls_data-agingdays.
    ls_approval-approved_by   = ls_data-approver.
    ls_approval-approved_date = ls_data-approved_date.
    ls_approval-changed_by    = sy-uname.
    ls_approval-changed_date  = sy-datum.
    ls_approval-changed_time  = sy-uzeit.
    " Set approval level flags from ALV data
    ls_approval-approval_lvl1 = ls_data-approval_lvl1.  " L1 = BCSPPD
    ls_approval-approval_lvl2 = ls_data-approval_lvl2.  " L2 = PDH
    ls_approval-approval_lvl3 = ls_data-approval_lvl3.  " L3 = SDH
    ls_approval-appr_valid    = ls_data-appr_valid.     " Approval Validation Flag
    " Set Level 1 (BCSPPD) - only update if current user approved L1
    IF ls_data-approved_by_lvl1 IS NOT INITIAL.
      ls_approval-appr_by_lvl1   = ls_data-approved_by_lvl1.
      ls_approval-appr_date_lvl1 = ls_data-approved_date_lvl1.
      ls_approval-appr_time_lvl1 = ls_data-approved_time_lvl1.
    ENDIF.
    " Set Level 3 (SDH) - only update if current user approved L3
    IF ls_data-approved_by_lvl3 IS NOT INITIAL.
      ls_approval-appr_by_lvl3   = ls_data-approved_by_lvl3.
      ls_approval-appr_date_lvl3 = ls_data-approved_date_lvl3.
      ls_approval-appr_time_lvl3 = ls_data-approved_time_lvl3.
    ENDIF.
    " Set checkbox flags from ALV data
*    ls_approval-chk_bcsppd = ls_data-chk_bcsppd.        " BCSPPD checkbox
*    ls_approval-chk_pdh = ls_data-chk_pdh.              " PDH checkbox
*    ls_approval-chk_sdh = ls_data-chk_sdh.              " SDH checkbox

    " Add to bulk table
    INSERT ls_approval INTO TABLE lt_approval.
  ENDLOOP.

  IF lt_approval IS NOT INITIAL.
    MODIFY ztwoappr FROM TABLE lt_approval.
    IF sy-subrc <> 0.
      lv_error_count = lv_error_count + 1.
    ENDIF.
  ENDIF.

  IF lv_error_count > 0.
    MESSAGE |Error updating { lv_error_count } approval record(s)| TYPE 'W'.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form process_send_email
*&---------------------------------------------------------------------*
*& Process sending email notification for selected items using DLI
*& sending Email to Branch user from HO
*&---------------------------------------------------------------------*
*&      <-- RS_SELFIELD_REFRESH
*&---------------------------------------------------------------------*
FORM process_send_email  CHANGING p_rs_selfield_refresh.

  DATA: lv_count        TYPE i,
        lv_answer       TYPE char1,
        lv_dli_name     TYPE so_recname,
        lt_html         TYPE bcsy_text,
        lv_subject      TYPE so_obj_des,
        lv_date_str(10) TYPE c,
        lv_werks_3      TYPE char3,
        lv_total_sent   TYPE i,
        lv_total_items  TYPE i,
        lv_plant_count  TYPE i,
        lv_item_count   TYPE i,
        lv_skip_plants  TYPE i.

  " Type for grouping by plant
  TYPES: BEGIN OF lty_plant,
           werks TYPE werks_d,
         END OF lty_plant.

  DATA: lt_plants        TYPE TABLE OF lty_plant,
        ls_plant         TYPE lty_plant,
        lt_plant_items   TYPE TABLE OF ty_alv_output,
        lt_save_selected TYPE TABLE OF ty_alv_output.

  " Check if user has authorization to send email (HELPDESK or BCSPPD)
  IF gv_auth_helpdesk = ' ' AND gv_auth_bcsppd = ' '.
    MESSAGE 'Only HELPDESK or BCSPPD users can send email to Branch' TYPE 'E'.
    RETURN.
  ENDIF.

  " Clear selected items table
  CLEAR: gt_selected, gt_recipients.

  " Count selected items and collect unique plants
  CLEAR lv_count.
  LOOP AT gt_alv_data INTO gs_alv_data WHERE selected = 'X'.
    lv_count = lv_count + 1.
    APPEND gs_alv_data TO gt_selected.
    READ TABLE lt_plants WITH KEY werks = gs_alv_data-werks TRANSPORTING NO FIELDS. " Collect Plant
    IF sy-subrc <> 0.
      ls_plant-werks = gs_alv_data-werks.
      APPEND ls_plant TO lt_plants.
    ENDIF.
  ENDLOOP.

  IF lv_count = 0.
    MESSAGE 'Please select at least one item to send email notification' TYPE 'I'.
    RETURN.
  ENDIF.

  lv_plant_count = lines( lt_plants ).

  " Confirm sending email - show plant count
  CALL FUNCTION 'POPUP_TO_CONFIRM'
    EXPORTING
      titlebar              = 'Send Email Notification'
      text_question         = |Send email for { lv_count } item(s) across { lv_plant_count } plant(s) to Branch?|
      text_button_1         = 'Yes'
      text_button_2         = 'No'
      default_button        = '2'
      display_cancel_button = ''
    IMPORTING
      answer                = lv_answer
    EXCEPTIONS
      text_not_found        = 1
      OTHERS                = 2.

  IF lv_answer <> '1'.
    RETURN.
  ENDIF.

  " Format current date
  WRITE sy-datum TO lv_date_str DD/MM/YYYY.

  " Save original gt_selected
  lt_save_selected = gt_selected.

  " Loop through each plant and send separate email
  CLEAR: lv_total_sent, lv_total_items, lv_skip_plants.
  LOOP AT lt_plants INTO ls_plant.
    " Filter selected items for this plant only
    CLEAR: lt_plant_items, gt_recipients.
    LOOP AT lt_save_selected INTO gs_alv_data WHERE werks = ls_plant-werks.
      APPEND gs_alv_data TO lt_plant_items.
    ENDLOOP.

    CHECK lt_plant_items IS NOT INITIAL.

    lv_item_count = lines( lt_plant_items ).

    " Build DLI name based on plant (format: APPR_XXX where 3-char plant code)
    lv_werks_3 = ls_plant-werks(3).
    CONCATENATE 'APPR_' lv_werks_3 INTO lv_dli_name.
    CONDENSE lv_dli_name NO-GAPS.

    " Get email recipients from Distribution List for this plant
    PERFORM get_email_from_dli USING lv_dli_name.

    " Skip if no recipients found for this plant
    IF gt_recipients IS INITIAL.
      MESSAGE |No recipients found in DLI { lv_dli_name } for plant { ls_plant-werks } - skipped| TYPE 'S' DISPLAY LIKE 'W'.
      lv_skip_plants = lv_skip_plants + 1.
      CONTINUE.
    ENDIF.

    " Replace gt_selected with plant-specific items for HTML build
    gt_selected = lt_plant_items.

    " Build email subject with plant info
    lv_subject = |Service WO Approval - { lv_item_count } Item(s) Plant { ls_plant-werks } Request for Review|.

    " Build HTML Body using FIRST/BODY/LAST pattern
    CLEAR: lt_html.
    PERFORM build_email_html_plant USING 'FIRST' lv_date_str lv_item_count
                                   CHANGING lt_html.
    PERFORM build_email_html_plant USING 'BODY' lv_date_str lv_item_count
                                   CHANGING lt_html.
    PERFORM build_email_html_plant USING 'LAST' lv_date_str lv_item_count
                                   CHANGING lt_html.

    TRY.
        " Send email via BCS
        PERFORM send_email_bcs TABLES gt_recipients
                               USING lv_subject
                                     lt_html.

        lv_total_sent = lv_total_sent + 1.
        lv_total_items = lv_total_items + lv_item_count.

      CATCH cx_bcs INTO DATA(lx_bcs).
        MESSAGE |Error sending email for plant { ls_plant-werks }: { lx_bcs->get_text( ) }| TYPE 'S' DISPLAY LIKE 'W'.
        lv_skip_plants = lv_skip_plants + 1.
    ENDTRY.
  ENDLOOP.

  " Restore gt_selected
  gt_selected = lt_save_selected.

  IF lv_total_sent > 0.
    DATA(lv_msg) = |Email sent to { lv_total_sent } plant(s) for { lv_total_items } item(s)|.
    IF lv_skip_plants > 0.
      lv_msg = lv_msg && |, { lv_skip_plants } plant(s) skipped|.
    ENDIF.
    MESSAGE lv_msg TYPE 'S'.
  ELSE.
    MESSAGE 'No emails sent - check Distribution Lists for each plant' TYPE 'W'.
  ENDIF.

  p_rs_selfield_refresh = 'X'.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_email_from_dli
*&---------------------------------------------------------------------*
*& Get email recipients from Distribution List (DL)
*&---------------------------------------------------------------------*
*&      --> LV_DLI_NAME
*&---------------------------------------------------------------------*
FORM get_email_from_dli  USING    p_lv_dli_name.

  DATA: dli_entries          LIKE sodlienti1 OCCURS 0 WITH HEADER LINE,
        ls_recipient         TYPE ty_email_recipient,
        lv_dli_name_internal LIKE soobjinfi1-obj_name.

  CLEAR: gt_recipients.

  " Internal format
  lv_dli_name_internal = p_lv_dli_name.

  " Call FM to read Distribution List (shared)
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

  " If shared DLI failed, try personal DLI
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
    RETURN.
  ENDIF.

  " Process DLI entries - get email directly from member_address
  LOOP AT dli_entries.
    IF dli_entries-member_adr IS NOT INITIAL.
      CLEAR ls_recipient.
      ls_recipient-recipient = dli_entries-member_adr.
      ls_recipient-name = dli_entries-member_nam.
      APPEND ls_recipient TO gt_recipients.
    ENDIF.
  ENDLOOP.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form build_email_html
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> P_
*&      --> LV_DATE_STR
*&      --> LV_COUNT
*&      <-- LT_HTML
*&---------------------------------------------------------------------*
FORM build_email_html USING p_flag      TYPE string
                            p_date_str  TYPE c
                            p_count     TYPE i
                   CHANGING pt_html     TYPE bcsy_text.

  DATA: htmltag        TYPE string,
        ls_data        TYPE ty_alv_output,
        lv_counter     TYPE i,
        lv_count_str   TYPE string,
        lv_date_str    TYPE string,
        lv_counter_str TYPE string.

  " Convert variables to strings
  lv_count_str = p_count.
  lv_date_str = p_date_str.

  CASE p_flag.
    WHEN 'FIRST'.
      " HTML Header
      APPEND '<html>' TO pt_html.
      APPEND '<head>' TO pt_html.
      APPEND '<style type="text/css">' TO pt_html.
      APPEND 'body { font-family: Arial, sans-serif; font-size: 12px; }' TO pt_html.
      APPEND 'table { border-collapse: collapse; font-family: Arial, sans-serif; width: 100%; border: 2px solid #000000; }' TO pt_html.
      APPEND 'th, td { padding: 8px; border: 1px solid #ddd; text-align: left; word-break: break-word; }' TO pt_html.
      APPEND 'th { background-color: #FFD700; font-weight: bold; color: #000000; }' TO pt_html. "colour header and table
      APPEND 'tr:nth-child(even) { background-color: #FFFFFF; }' TO pt_html.
      APPEND 'tr:hover { background-color: #e8f4fc; }' TO pt_html.
      APPEND '.highlight { background-color: #fff2cc; }' TO pt_html.
      APPEND '</style>' TO pt_html.
      APPEND '</head>' TO pt_html.
      APPEND '<body>' TO pt_html.

      " Email content - Header
      APPEND '<h2 style="color:#2E75B6;">Service WO Component Approval</h2>' TO pt_html.
      APPEND '<p>Dear BCSPPD HO Team,</p>' TO pt_html.

      " Main message
      APPEND '<p>Dengan ini kami mohon bantuannya untuk review dan approval PN' TO pt_html.
      APPEND 'yang tidak sesuai dengan Component pada Tasklist.</p>' TO pt_html.
      APPEND '<br>' TO pt_html.

      " Table header
      APPEND '<table>' TO pt_html.
      APPEND '<tr>' TO pt_html.
      APPEND '<th>No</th>' TO pt_html.
      APPEND '<th>Work Order</th>' TO pt_html.
      APPEND '<th>Plant</th>' TO pt_html.
      APPEND '<th>Equipment</th>' TO pt_html.
      APPEND '<th>PN Tasklist</th>' TO pt_html.
      APPEND '<th>Desc Tasklist</th>' TO pt_html.
      APPEND '<th>PN Work Order</th>' TO pt_html.
      APPEND '<th>Desc WO</th>' TO pt_html.
      APPEND '<th>Status</th>' TO pt_html.
      APPEND '<th>Aging Days</th>' TO pt_html.
      APPEND '<th>Reason Change</th>' TO pt_html.
      APPEND '<th>Reason Reject</th>' TO pt_html.
      APPEND '</tr>' TO pt_html.

    WHEN 'BODY'.
      " Table rows with approval data
      CLEAR: lv_counter.
      LOOP AT gt_selected INTO ls_data.
        DATA: lv_aufnr_out TYPE string,
              lv_equnr_out TYPE string.

        lv_counter = lv_counter + 1.
        lv_counter_str = lv_counter.

        " Remove leading zeros using alpha conversion
        CALL FUNCTION 'CONVERSION_EXIT_ALPHA_OUTPUT'
          EXPORTING
            input  = ls_data-aufnr
          IMPORTING
            output = lv_aufnr_out.

        CALL FUNCTION 'CONVERSION_EXIT_ALPHA_OUTPUT'
          EXPORTING
            input  = ls_data-equnr
          IMPORTING
            output = lv_equnr_out.

        APPEND '<tr>' TO pt_html.

        CONCATENATE '<td style="text-align: center;">' lv_counter_str '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.

        CONCATENATE '<td style="font-weight: bold;">' lv_aufnr_out '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.

        CONCATENATE '<td style="text-align: center;">' ls_data-werks '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.

        CONCATENATE '<td>' lv_equnr_out '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.

        CONCATENATE '<td class="highlight">' ls_data-pn_tasklist '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.

        CONCATENATE '<td>' ls_data-desc_tasklist '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.

        CONCATENATE '<td class="highlight">' ls_data-pn_workorder '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.

        CONCATENATE '<td>' ls_data-desc_workorder '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.

        CONCATENATE '<td>' ls_data-approval_stat '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.

        DATA: lv_aging_str TYPE string.
        lv_aging_str = ls_data-agingdays.
        CONDENSE lv_aging_str.
        CONCATENATE '<td style="text-align: center;">' lv_aging_str '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.

        CONCATENATE '<td>' ls_data-reason_change '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.

        CONCATENATE '<td>' ls_data-reason_reject '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.

        APPEND '</tr>' TO pt_html.
      ENDLOOP.

    WHEN 'LAST'.
      " Close table and add footer
      APPEND '</table>' TO pt_html.
      APPEND '<br>' TO pt_html.

      " Summary
      APPEND '<p><b>Ringkasan:</b></p>' TO pt_html.
      APPEND '<ul>' TO pt_html.

      CONCATENATE '<li>Total item yang membutuhkan review: <b>' lv_count_str '</b></li>' INTO htmltag.
      APPEND htmltag TO pt_html.

      CONCATENATE '<li>Tanggal notifikasi: <b>' lv_date_str '</b></li>' INTO htmltag.
      APPEND htmltag TO pt_html.

      APPEND '</ul>' TO pt_html.
      APPEND '<br>' TO pt_html.

      " Closing
      APPEND '<p>Terimakasih atas perhatiannya,</p>' TO pt_html.

      DATA: lv_uname TYPE string.
      lv_uname = sy-uname.
      CONCATENATE '<p><b>' lv_uname '</b><br>PT United Tractors Tbk</p>' INTO htmltag.
      APPEND htmltag TO pt_html.

      APPEND '<br>' TO pt_html.
      APPEND '<hr>' TO pt_html.
      APPEND '<p style="font-size: 10px; color: #888888;">' TO pt_html.
      APPEND 'This email was sent from Service WO Component Approval Report.<br>' TO pt_html.
      APPEND 'Please do not reply directly to this email.' TO pt_html.
      APPEND '</p>' TO pt_html.

      APPEND '</body>' TO pt_html.
      APPEND '</html>' TO pt_html.

  ENDCASE.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form send_email_bcs
*&---------------------------------------------------------------------*
*& Send HTML email using BCS
*&---------------------------------------------------------------------*
*&      --> GT_RECIPIENTS
*&      --> LV_SUBJECT
*&      --> LT_HTML
*&---------------------------------------------------------------------*

FORM send_email_bcs TABLES pt_email LIKE gt_recipients
                    USING p_subject TYPE so_obj_des
                          p_html_tab TYPE bcsy_text
                    RAISING cx_bcs.

  CHECK NOT pt_email[] IS INITIAL.

  DATA: lv_subject         TYPE so_obj_des,
        lo_email           TYPE REF TO cl_bcs,
        lo_email_body      TYPE REF TO cl_document_bcs,
        lo_receiver        TYPE REF TO if_recipient_bcs,
        lx_exception       TYPE REF TO cx_bcs,
        lo_internet_sender TYPE REF TO if_sender_bcs,
        l_address          TYPE adr6-smtp_addr,
        lv_send_result     TYPE c.

  TRY.
      lo_email = cl_bcs=>create_persistent( ).
      lv_subject = p_subject.
      lo_email_body = cl_document_bcs=>create_document(
        i_type    = 'HTM'
        i_text    = p_html_tab
        i_subject = lv_subject ).

      lo_email->set_document( lo_email_body ).

      " Set sender (optional - uses default sender from mail configuration)
      lo_internet_sender = cl_cam_address_bcs=>create_internet_address(
        i_address_string = 'mail_sap@unitedtractors.com'
        i_address_name   = 'PT. United Tractors Tbk' ).
      CALL METHOD lo_email->set_sender
        EXPORTING
          i_sender = lo_internet_sender.

      " Add recipients
      LOOP AT pt_email.
        l_address = pt_email-recipient.
        lo_receiver = cl_cam_address_bcs=>create_internet_address( l_address ).
        lo_email->add_recipient( i_recipient = lo_receiver
                                 i_express   = 'X' ).
      ENDLOOP.

      lo_email->set_send_immediately( 'X' ).
      lo_email->send( EXPORTING i_with_error_screen = 'X'
                      RECEIVING result              = lv_send_result ).

      IF lv_send_result = 'X'.
        MESSAGE s000(db) WITH 'Email has been sent'.
      ENDIF.
      COMMIT WORK.

    CATCH cx_bcs INTO lx_exception.
      MESSAGE s000(db) WITH 'Email has not been sent'.
      RAISE EXCEPTION lx_exception.
  ENDTRY.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form process_send_email_ho
*&---------------------------------------------------------------------*
*& Process sending email notification for selected items to APPR_HO DLI
*&---------------------------------------------------------------------*
*&      <-- P_RS_SELFIELD_REFRESH
*&---------------------------------------------------------------------*
FORM process_send_email_ho CHANGING p_rs_selfield_refresh.

  DATA: lv_count        TYPE i,
        lv_answer       TYPE char1,
        lv_dli_name     TYPE so_recname,
        lt_html         TYPE bcsy_text,
        lv_subject      TYPE so_obj_des,
        lv_date_str(10) TYPE c.

  " Check if user has authorization to send email to HO (HELPDESK or Branch)
  IF gv_auth_helpdesk = ' ' AND gv_auth_branch = ' '.
    MESSAGE 'Only HELPDESK or Branch users can send email to HO' TYPE 'E'.
    RETURN.
  ENDIF.

  " Clear selected items table
  CLEAR: gt_selected, gt_recipients.

  " Count selected items and takeout if BCSPPD was Approved
  DATA: lv_skip_count   TYPE i,
        lv_reason_count TYPE i.
  CLEAR: lv_count, lv_skip_count.
  LOOP AT gt_alv_data INTO gs_alv_data WHERE selected = 'X'.
    IF gs_alv_data-chk_bcsppd = 'X'.
      lv_skip_count = lv_skip_count + 1.
      CONTINUE.
    ENDIF.
    IF gs_alv_data-comp_match = 'No' AND gs_alv_data-reason_change IS INITIAL.         " Validate Reason Change - only required if comp_match is 'No'
      MESSAGE |WO Item { gs_alv_data-aufnr } from { gs_alv_data-werks } Please fill Reason Change before sending to HO!| TYPE 'W'.
      lv_reason_count = lv_reason_count + 1.
      CONTINUE.
    ENDIF.
    lv_count = lv_count + 1.
    APPEND gs_alv_data TO gt_selected.
  ENDLOOP.

  IF lv_count = 0.
    IF lv_skip_count > 0 AND lv_reason_count = 0.
      MESSAGE 'All selected items already approved by BCSPPD. No email needed!' TYPE 'I'.
    ELSEIF lv_reason_count > 0.
      MESSAGE |{ lv_reason_count } item(s) missing. Please fill Reason Change by ADM_SVC { gs_alv_data-werks } first!.| TYPE 'W'.
    ELSE.
      MESSAGE 'Please select at least one item to send email notification' TYPE 'I'.
    ENDIF.
    RETURN.
  ENDIF.

  " Inform user about skipped items
  IF lv_skip_count > 0 OR lv_reason_count > 0.
    MESSAGE |{ lv_skip_count } BCSPPD approved, { lv_reason_count } missing Reason - skipped| TYPE 'I'.
  ENDIF.

  " Use fixed DLI name for HO
  lv_dli_name = 'APPR_HO'.

  " Get email recipients from Distribution List
  PERFORM get_email_from_dli USING lv_dli_name.

  " Check if recipients found
  IF gt_recipients IS INITIAL.
    MESSAGE |No recipients found in Distribution List { lv_dli_name }| TYPE 'W'.
    RETURN.
  ENDIF.

  " Confirm sending email
  CALL FUNCTION 'POPUP_TO_CONFIRM'
    EXPORTING
      titlebar              = 'Send Email to BCSPPD HO'
      text_question         = |Send email notification for { lv_count } item(s) to { lines( gt_recipients ) } HO recipient(s)?|
      text_button_1         = 'Yes'
      text_button_2         = 'No'
      default_button        = '2'
      display_cancel_button = ''
    IMPORTING
      answer                = lv_answer
    EXCEPTIONS
      text_not_found        = 1
      OTHERS                = 2.

  IF lv_answer <> '1'.
    RETURN.
  ENDIF.

  " Format current date
  WRITE sy-datum TO lv_date_str DD/MM/YYYY.

  " Build email subject
  lv_subject = |Service WO Component Approval - { lv_count } Item(s) Request for HO Review|.

  " Build HTML Body using FIRST/BODY/LAST pattern
  CLEAR: lt_html.
  PERFORM build_email_html USING 'FIRST' lv_date_str lv_count
                           CHANGING lt_html.
  PERFORM build_email_html USING 'BODY' lv_date_str lv_count
                           CHANGING lt_html.
  PERFORM build_email_html USING 'LAST' lv_date_str lv_count
                           CHANGING lt_html.

  TRY.
      " Send email via BCS
      PERFORM send_email_bcs TABLES gt_recipients
                             USING lv_subject
                                   lt_html.

      MESSAGE |Email notification sent successfully for { lv_count } item(s) to { lines( gt_recipients ) } HO recipients| TYPE 'S'.

    CATCH cx_bcs INTO DATA(lx_bcs).
      MESSAGE |Error sending email: { lx_bcs->get_text( ) }| TYPE 'E'.
  ENDTRY.

  p_rs_selfield_refresh = 'X'.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form build_email_html_plant
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> P_
*&      --> LV_DATE_STR
*&      --> LV_COUNT
*&      <-- LT_HTML
*&---------------------------------------------------------------------*
FORM build_email_html_plant USING p_flag      TYPE string
                                  p_date_str  TYPE c
                                  p_count     TYPE i
                         CHANGING pt_html     TYPE bcsy_text.

  DATA: htmltag        TYPE string,
        ls_data        TYPE ty_alv_output,
        lv_counter     TYPE i,
        lv_count_str   TYPE string,
        lv_date_str    TYPE string,
        lv_counter_str TYPE string.

  " Convert variables to strings
  lv_count_str = p_count.
  lv_date_str = p_date_str.

  CASE p_flag.
    WHEN 'FIRST'.
      " HTML Header
      APPEND '<html>' TO pt_html.
      APPEND '<head>' TO pt_html.
      APPEND '<style type="text/css">' TO pt_html.
      APPEND 'body { font-family: Arial, sans-serif; font-size: 12px; }' TO pt_html.
      APPEND 'table { border-collapse: collapse; font-family: Arial, sans-serif; width: 100%; border: 2px solid #000000; }' TO pt_html.
      APPEND 'th, td { padding: 8px; border: 1px solid #000000; text-align: left; word-break: break-word; }' TO pt_html.
      APPEND 'th { background-color: #FFD700; font-weight: bold; color: #000000; }' TO pt_html. " Table header and bg colour
      APPEND 'tr:nth-child(even) { background-color: #FFFFFF; }' TO pt_html.
      APPEND 'tr:hover { background-color: #e8f4fc; }' TO pt_html.
      APPEND '.highlight { background-color: #fff2cc; }' TO pt_html.
      APPEND '</style>' TO pt_html.
      APPEND '</head>' TO pt_html.
      APPEND '<body>' TO pt_html.

      " Email content - Header
      APPEND '<h2 style="color:#2E75B6;">Service WO Component Approval</h2>' TO pt_html.
      APPEND '<p>Dear Tim Cabang,</p>' TO pt_html.

      " Main message
      APPEND '<p>Bersama ini kami sampaikan hasil review dan Approval PN yang tidak sesuai ' TO pt_html.
      APPEND 'dengan Bill Of Material Tasklist sebagai berikut:</p>' TO pt_html.
      APPEND '<br>' TO pt_html.

      " Table header
      APPEND '<table>' TO pt_html.
      APPEND '<tr>' TO pt_html.
      APPEND '<th>No</th>' TO pt_html.
      APPEND '<th>Work Order</th>' TO pt_html.
      APPEND '<th>Plant</th>' TO pt_html.
      APPEND '<th>Equipment</th>' TO pt_html.
      APPEND '<th>PN Tasklist</th>' TO pt_html.
      APPEND '<th>Desc Tasklist</th>' TO pt_html.
      APPEND '<th>PN Work Order</th>' TO pt_html.
      APPEND '<th>Desc WO</th>' TO pt_html.
      APPEND '<th>Status</th>' TO pt_html.
      APPEND '<th>Aging Days</th>' TO pt_html.
      APPEND '<th>Reason Change</th>' TO pt_html.
      APPEND '<th>Reason Reject</th>' TO pt_html.
      APPEND '</tr>' TO pt_html.

    WHEN 'BODY'.
      " Table rows with approval data
      CLEAR: lv_counter.
      LOOP AT gt_selected INTO ls_data.
        DATA: lv_aufnr_out TYPE string,
              lv_equnr_out TYPE string.

        lv_counter = lv_counter + 1.
        lv_counter_str = lv_counter.

        " Remove leading zeros using alpha conversion
        CALL FUNCTION 'CONVERSION_EXIT_ALPHA_OUTPUT'
          EXPORTING
            input  = ls_data-aufnr
          IMPORTING
            output = lv_aufnr_out.

        CALL FUNCTION 'CONVERSION_EXIT_ALPHA_OUTPUT'
          EXPORTING
            input  = ls_data-equnr
          IMPORTING
            output = lv_equnr_out.

        APPEND '<tr>' TO pt_html.

        CONCATENATE '<td style="text-align: center;">' lv_counter_str '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.

        CONCATENATE '<td style="font-weight: bold;">' lv_aufnr_out '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.

        CONCATENATE '<td style="text-align: center;">' ls_data-werks '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.

        CONCATENATE '<td>' lv_equnr_out '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.

        CONCATENATE '<td class="highlight">' ls_data-pn_tasklist '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.

        CONCATENATE '<td>' ls_data-desc_tasklist '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.

        CONCATENATE '<td class="highlight">' ls_data-pn_workorder '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.

        CONCATENATE '<td>' ls_data-desc_workorder '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.

        CONCATENATE '<td>' ls_data-approval_stat '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.

        DATA: lv_aging_str TYPE string.
        lv_aging_str = ls_data-agingdays.
        CONDENSE lv_aging_str.
        CONCATENATE '<td style="text-align: center;">' lv_aging_str '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.

        CONCATENATE '<td>' ls_data-reason_change '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.

        CONCATENATE '<td>' ls_data-reason_reject '</td>' INTO htmltag.
        APPEND htmltag TO pt_html.

        APPEND '</tr>' TO pt_html.
      ENDLOOP.

    WHEN 'LAST'.
      " Close table and add footer
      APPEND '</table>' TO pt_html.
      APPEND '<br>' TO pt_html.

      " Instructions for Plant
      APPEND '<p>Silahkan dilanjutkan untuk Approval berikutnya untuk WO yang sudah kami Approve.</p>' TO pt_html.
      APPEND '<p>Untuk WO Reject silakan ubah PN sesuai dengan BOM Tasklist nya.</p>' TO pt_html.
      APPEND '<br>' TO pt_html.

      " Summary
      APPEND '<p><b>Ringkasan:</b></p>' TO pt_html.
      APPEND '<ul>' TO pt_html.

      CONCATENATE '<li>Total item: <b>' lv_count_str '</b></li>' INTO htmltag.
      APPEND htmltag TO pt_html.

      CONCATENATE '<li>Tanggal notifikasi: <b>' lv_date_str '</b></li>' INTO htmltag.
      APPEND htmltag TO pt_html.

      APPEND '</ul>' TO pt_html.
      APPEND '<br>' TO pt_html.

      " Closing
      APPEND '<p>Best Regards,</p>' TO pt_html.
      APPEND '<p><b>BCSPPD HO Team</b></p>' TO pt_html.

      APPEND '<br>' TO pt_html.
      APPEND '<hr>' TO pt_html.
      APPEND '<p style="font-size: 10px; color: #888888;">' TO pt_html.
      APPEND 'This email was sent from Service WO Component Approval Report.<br>' TO pt_html.
      APPEND 'Please do not reply directly to this email.' TO pt_html.
      APPEND '</p>' TO pt_html.

      APPEND '</body>' TO pt_html.
      APPEND '</html>' TO pt_html.

  ENDCASE.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form show_reason_change
*&---------------------------------------------------------------------*
*& Show popup dropdown for selecting Reason for Change
*&---------------------------------------------------------------------*
*&      --> RS_SELFIELD_TABINDEX
*&      <-- RS_SELFIELD_REFRESH
*&---------------------------------------------------------------------*
FORM show_reason_change USING p_tabindex TYPE sy-tabix
                              CHANGING p_refresh TYPE char1.

  DATA: lt_values   TYPE TABLE OF spopli,
        ls_value    TYPE spopli,
        lv_answer   TYPE char1,
        lv_selected TYPE char100.

  " Build dropdown list for Reason Change
  CLEAR ls_value.
  ls_value-selflag = ''.
  ls_value-varoption = 'Parts Tidak Tersedia'.
  APPEND ls_value TO lt_values.

  CLEAR ls_value.
  ls_value-selflag = ''.
  ls_value-varoption = 'PN Interchange (ITC)'.
  APPEND ls_value TO lt_values.

  CLEAR ls_value.
  ls_value-selflag = ''.
  ls_value-varoption = 'Parts Subtitusi'.
  APPEND ls_value TO lt_values.

  CLEAR ls_value.
  ls_value-selflag = ''.
  ls_value-varoption = 'PN Mengikuti OMM'.
  APPEND ls_value TO lt_values.

  " Show popup with list
  CALL FUNCTION 'POPUP_TO_DECIDE_LIST'
    EXPORTING
      textline1          = 'Select Reason for Change:'
      titel              = 'Reason Change'
      start_col          = 25
      start_row          = 6
    IMPORTING
      answer             = lv_answer
    TABLES
      t_spopli           = lt_values
    EXCEPTIONS
      not_enough_answers = 1
      too_much_answers   = 2
      too_much_marks     = 3
      OTHERS             = 4.

  IF sy-subrc <> 0 OR lv_answer = 'A'.
    RETURN.  " User cancelled
  ENDIF.

  " Get selected value
  READ TABLE lt_values INTO ls_value WITH KEY selflag = 'X'.
  IF sy-subrc = 0.
    lv_selected = ls_value-varoption.

    " Update ALV data
    READ TABLE gt_alv_data INTO gs_alv_data INDEX p_tabindex.
    IF sy-subrc = 0.
      gs_alv_data-reason_change = lv_selected.
      MODIFY gt_alv_data FROM gs_alv_data INDEX p_tabindex.

      " Update database record
      PERFORM update_approval_record USING gs_alv_data.
      COMMIT WORK AND WAIT.

      MESSAGE |Reason Change updated: { lv_selected }| TYPE 'S'.
      p_refresh = 'X'.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form show_reason_reject
*&---------------------------------------------------------------------*
*& Show popup dropdown for selecting Reason for Rejection
*&---------------------------------------------------------------------*
*&      --> RS_SELFIELD_TABINDEX
*&      <-- RS_SELFIELD_REFRESH
*&---------------------------------------------------------------------*
FORM show_reason_reject USING p_tabindex TYPE sy-tabix
                              CHANGING p_refresh TYPE char1.

  DATA: lt_values   TYPE TABLE OF spopli,
        ls_value    TYPE spopli,
        lv_answer   TYPE char1,
        lv_selected TYPE char100.

  " Build dropdown list for Reason Rejection
  CLEAR ls_value.
  ls_value-selflag = ''.
  ls_value-varoption = 'PN tidak sesuai dengan Unit Model'.
  APPEND ls_value TO lt_values.

  CLEAR ls_value.
  ls_value-selflag = ''.
  ls_value-varoption = 'PN tidak termasuk Parts PS'.
  APPEND ls_value TO lt_values.

  " Show popup with list
  CALL FUNCTION 'POPUP_TO_DECIDE_LIST'
    EXPORTING
      textline1          = 'Select Reason for Rejection:'
      titel              = 'Reason Rejection'
      start_col          = 25
      start_row          = 6
    IMPORTING
      answer             = lv_answer
    TABLES
      t_spopli           = lt_values
    EXCEPTIONS
      not_enough_answers = 1
      too_much_answers   = 2
      too_much_marks     = 3
      OTHERS             = 4.

  IF sy-subrc <> 0 OR lv_answer = 'A'.
    RETURN.  " User cancelled
  ENDIF.

  " Get selected value
  READ TABLE lt_values INTO ls_value WITH KEY selflag = 'X'.
  IF sy-subrc = 0.
    lv_selected = ls_value-varoption.

    " Update ALV data
    READ TABLE gt_alv_data INTO gs_alv_data INDEX p_tabindex.
    IF sy-subrc = 0.
      gs_alv_data-reason_reject = lv_selected.
      MODIFY gt_alv_data FROM gs_alv_data INDEX p_tabindex.

      " Update database record
      PERFORM update_approval_record USING gs_alv_data.
      COMMIT WORK AND WAIT.

      MESSAGE |Reason Rejection updated: { lv_selected }| TYPE 'S'.
      p_refresh = 'X'.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form trigger_auto_release_wo
*&---------------------------------------------------------------------*
*& Trigger automatic WO release after final approval is complete
*& Checks if all components for the WO are approved before releasing
*& Ref => ALM_ME_ORDER_RELEASE
*&---------------------------------------------------------------------*
*&      --> GS_ALV_DATA_AUFNR
*&---------------------------------------------------------------------*
" Auto-release via BAPI removed; user re-releases in IW32
FORM trigger_auto_release_wo  USING p_gs_alv_data_aufnr TYPE aufnr.

  DATA: lv_aufnr_conv TYPE aufnr,
        lv_objnr      TYPE j_objnr,
        lv_iphas      TYPE char1,
        lv_auart      TYPE aufart,
        lv_pending    TYPE i,
        lv_message    TYPE char200,
        ls_return     TYPE bapiret2,
        lt_return     TYPE TABLE OF bapiret2.

  CONSTANTS: lc_released TYPE char1 VALUE '2', " IPHAS field in CAUFV is '2' => Released
             lc_vrgng    TYPE char4 VALUE 'BFRE'.

* Convert Order Number (add leading zeros)
  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
    EXPORTING
      input  = p_gs_alv_data_aufnr
    IMPORTING
      output = lv_aufnr_conv.

* Build Object Number (OR + 12-digit order number)
  CONCATENATE 'OR' lv_aufnr_conv INTO lv_objnr.

* Check if ALL components for this WO are approved in ZTWOAPPR
  SELECT COUNT(*)
    INTO @lv_pending
    FROM ztwoappr
    WHERE aufnr = @lv_aufnr_conv
      AND approval_stat <> 'Full Approved'
      AND approval_stat <> 'Reject Approval'.

  IF lv_pending > 0.
    " Not all items approved yet - skip release
    RETURN.
  ENDIF.

* Check if order exists and get order type
  SELECT SINGLE aufnr, auart
    INTO @DATA(ls_aufk)
    FROM aufk
    WHERE aufnr = @lv_aufnr_conv.

  IF sy-subrc <> 0.
    MESSAGE |WO { p_gs_alv_data_aufnr } not found - Release skipped| TYPE 'W'.
    RETURN.
  ENDIF.

  lv_auart = ls_aufk-auart.

* Check current order phase (IPHAS) - skip if already released
  SELECT SINGLE iphas
    INTO @lv_iphas
    FROM viaufks
    WHERE aufnr = @lv_aufnr_conv.

  IF lv_iphas = lc_released.
    MESSAGE |WO { p_gs_alv_data_aufnr } is already released| TYPE 'S'.
    RETURN.
  ENDIF.

*  Check if Release is allowed (Business Transaction => BFRE)
*  CALL FUNCTION 'STATUS_CHANGE_FOR_ACTIVITY'
*    EXPORTING
*      check_only           = 'X'
*      objnr                = lv_objnr
*      vrgng                = lc_vrgng "BFRE
*    EXCEPTIONS
*      activity_not_allowed = 1
*      object_not_found     = 2
*      status_inconsistent  = 3
*      status_not_allowed   = 4
*      wrong_input          = 5
*      warning_occured      = 6
*      error_message        = 7
*      OTHERS               = 8.
*
*  IF sy-subrc <> 0 AND sy-subrc <> 6.
*    MESSAGE ID sy-msgid TYPE 'W' NUMBER sy-msgno
*            WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
*    RETURN.
*  ENDIF.

* Perform Release using BAPI_ALM_ORDER_MAINTAIN
  DATA: lt_alm_order_method TYPE STANDARD TABLE OF bapi_alm_order_method,
        ls_alm_order_method TYPE bapi_alm_order_method,
        lt_header           TYPE STANDARD TABLE OF bapi_alm_order_headers_i,
        lt_header_up        TYPE STANDARD TABLE OF bapi_alm_order_headers_up,
        ls_header           TYPE bapi_alm_order_headers_i,
        ls_header_up        TYPE bapi_alm_order_headers_up.
  DATA: lv_any_error TYPE flag.
  ls_header-orderid = lv_aufnr_conv.
  ls_header_up-orderid = lv_aufnr_conv.

  APPEND ls_header TO lt_header.
  APPEND ls_header_up TO lt_header_up.

  ls_alm_order_method-refnumber  = '00001'.
  ls_alm_order_method-objecttype = 'HEADER'.
  ls_alm_order_method-method     = 'RELEASE'.
  ls_alm_order_method-objectkey  = lv_aufnr_conv.
  APPEND ls_alm_order_method TO lt_alm_order_method.

* Add SAVE method to persist the release
  CLEAR ls_alm_order_method.
  ls_alm_order_method-refnumber  = '00001'.
  ls_alm_order_method-objecttype = space.
  ls_alm_order_method-method     = 'SAVE'.
  ls_alm_order_method-objectkey  = lv_aufnr_conv.
  APPEND ls_alm_order_method TO lt_alm_order_method.

  CALL FUNCTION 'BUFFER_REFRESH_ALL'. " Refresh buffer before release

  CALL FUNCTION 'BAPI_ALM_ORDER_MAINTAIN'
    TABLES
      it_methods   = lt_alm_order_method
      it_header    = lt_header
      it_header_up = lt_header_up
      return       = lt_return.

* Check for errors
  DATA: lv_error TYPE flag.
  CLEAR lv_error.
  LOOP AT lt_return INTO ls_return.
    IF ls_return-type CA 'AE'.
      lv_error = 'X'.
    ENDIF.
  ENDLOOP.

  IF lv_error = 'X'.
    CALL FUNCTION 'MESSAGES_INITIALIZE'.
    LOOP AT lt_return INTO ls_return WHERE type CA 'AE'. " Error occurred
      "MESSAGE ls_return-message TYPE 'W'.
      PERFORM insert_message USING ls_return-id
                                  ls_return-type
                                  ls_return-number
                                  ls_return-message_v1
                                  ls_return-message_v2
                                  ls_return-message_v3
                                  ls_return-message_v4
                                  lv_aufnr_conv
                                 CHANGING lv_any_error.
    ENDLOOP.
    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.  " Rollback changes if release failed
    PERFORM display_message.
    RETURN.
  ELSE.
    " No error - commit the release
    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
      EXPORTING
        wait = 'X'.
    MESSAGE |WO { p_gs_alv_data_aufnr } released successfully| TYPE 'S'.

    "PERFORM set_status_nrtc USING p_gs_alv_data_aufnr. " Set NRTC
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form set_wo_status_apvd
*&---------------------------------------------------------------------*
*& Set WO User Status from REQU to APVD after Full Approved
*& Only triggers when ALL parts for the WO are approved
*& Calls ZFM_SVC_SET_STATUS_APVD function module
*&---------------------------------------------------------------------*
*&      --> P_AUFNR  Work Order Number
*&---------------------------------------------------------------------*
*FORM set_wo_status_apvd USING p_aufnr TYPE aufnr.
*
*  DATA: lv_success    TYPE flag,
*        lv_message    TYPE char200,
*        lv_aufnr_conv TYPE aufnr,
*        lv_pending    TYPE i.
*
*  " Convert Order Number (add leading zeros)
*  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
*    EXPORTING
*      input  = p_aufnr
*    IMPORTING
*      output = lv_aufnr_conv.
*
*  " Check if ALL components for this WO are approved in ZTWOAPPR
*  SELECT COUNT(*)
*    INTO @lv_pending
*    FROM ztwoappr
*    WHERE aufnr = @lv_aufnr_conv
*      AND approval_stat <> 'Full Approved'
*      AND approval_stat <> 'Reject Approval'.
*
*  IF lv_pending > 0.
*    " Not all items approved yet - skip APVD status change
*    RETURN.
*  ENDIF.
*
*  " All parts approved - Call FM to set APVD status (REQU => APVD)
*  CALL FUNCTION 'ZFM_SVC_SET_STATUS_APVD'
*    EXPORTING
*      iv_aufnr              = p_aufnr
*      iv_commit             = 'X'
*    IMPORTING
*      ev_success            = lv_success
*      ev_message            = lv_message
*    EXCEPTIONS
*      order_not_found       = 1
*      status_change_error   = 2
*      approval_not_complete = 3
*      OTHERS                = 4.
*
*  IF sy-subrc <> 0 OR lv_success = ' '.
*    " Log warning
*    MESSAGE lv_message TYPE 'W'.
*  ELSE.
*    MESSAGE lv_message TYPE 'S'.
*  ENDIF.
*
*ENDFORM.
*&---------------------------------------------------------------------*
*& Form process_wo_release_batch
*&---------------------------------------------------------------------*
*& Checks if ALL parts in ZTWOAPPR are NOT "Pending Approve" before release
*& Logic: Check All Parts -> Set APVD Status -> Trigger Auto Release
*&---------------------------------------------------------------------*
*&      --> LT_WO_RELEASE
*&---------------------------------------------------------------------*
" UPDATE: auto-release no longer needed
*FORM process_wo_release_batch  USING    it_wo_release TYPE tt_aufnr_range.
*
*  DATA: lv_aufnr         TYPE aufnr,
*        lv_aufnr_conv    TYPE aufnr,
*        lv_all_approved  TYPE flag,
*        lv_release_count TYPE i,
*        lv_skip_count    TYPE i,
*        lv_apvd_only_cnt TYPE i,
*        lv_warpl         TYPE viaufks-warpl.
*
*  CLEAR: lv_release_count, lv_skip_count.
*
*  " Process each collected WO number
*  LOOP AT it_wo_release INTO DATA(ls_wo_range).
*    lv_aufnr = ls_wo_range-low.
*
*    " Step 1: Check if ALL parts for this WO are approved (not pending)
*    PERFORM check_all_parts_approved USING lv_aufnr
*                                     CHANGING lv_all_approved.
*
*    IF lv_all_approved = ''.
*      lv_skip_count = lv_skip_count + 1.
*      CONTINUE.
*    ENDIF.
*
*    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
*      EXPORTING
*        input  = lv_aufnr
*      IMPORTING
*        output = lv_aufnr_conv.
*
*    " Step 2: Check if WO has Maintenance Plan (WARPL)
*    CLEAR lv_warpl.
*    SELECT SINGLE warpl
*      INTO @lv_warpl
*      FROM viaufks
*      WHERE aufnr = @lv_aufnr_conv.
*
**    IF lv_warpl IS NOT INITIAL.
**      PERFORM set_apvd_user_status USING lv_aufnr. "With WARPL
**      "PERFORM trigger_auto_release_wo USING lv_aufnr.      => Trigger Auto Release WO
**      lv_release_count = lv_release_count + 1.
**    ELSE.
**      PERFORM set_apvd_user_status USING lv_aufnr. " WARPL is empty
**      lv_apvd_only_cnt = lv_apvd_only_cnt + 1.
**    ENDIF.
*
*  ENDLOOP.
*
*  " Display summary message
*  IF lv_release_count > 0 OR lv_apvd_only_cnt > 0.
*    DATA(lv_msg) = |{ lv_release_count } WO(s) released (with Maintenance Plan)|.
*    IF lv_apvd_only_cnt > 0.
*      lv_msg = lv_msg && |, { lv_apvd_only_cnt } WO(s) APVD only (no Maintenance Plan)|.
*    ENDIF.
*    IF lv_skip_count > 0.
*      lv_msg = lv_msg && |, { lv_skip_count } WO(s) skipped (pending parts)|.
*    ENDIF.
*    MESSAGE lv_msg TYPE 'S'.
*  ENDIF.
*
*
*ENDFORM.
*&---------------------------------------------------------------------*
*& Form check_all_parts_approved
*&---------------------------------------------------------------------*
*& Check if ALL parts/lines in ZTWOAPPR for a WO are approved
*&---------------------------------------------------------------------*
*&      --> LV_AUFNR
*&      <-- LV_ALL_APPROVED
*&---------------------------------------------------------------------*
FORM check_all_parts_approved  USING   iv_aufnr
                               CHANGING cv_all_approved TYPE flag.


  DATA: lv_aufnr_conv  TYPE aufnr,
        lv_total_count TYPE i,
        lv_valid_count TYPE i.

  CLEAR cv_all_approved.
  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
    EXPORTING
      input  = iv_aufnr
    IMPORTING
      output = lv_aufnr_conv.

  SELECT COUNT(*) FROM ztwoappr
    INTO lv_total_count
    WHERE aufnr = lv_aufnr_conv
      AND matnr <> ''.

  IF lv_total_count = 0.
    " No parts in table
    cv_all_approved = ' '.
    RETURN.
  ENDIF.

  SELECT COUNT(*) FROM ztwoappr
   INTO lv_valid_count
   WHERE aufnr = lv_aufnr_conv
     AND matnr <> ''
     AND appr_valid = 'X'.

  " All parts approved if valid_count = total_count
  IF lv_valid_count = lv_total_count.
    cv_all_approved = 'X'.
  ELSE.
    cv_all_approved = ' '.
  ENDIF.

ENDFORM.
FORM display_message .

  CALL FUNCTION 'MESSAGES_SHOW'
    EXPORTING
      i_use_grid         = 'X'
    EXCEPTIONS
      inconsistent_range = 1
      no_messages        = 2
      OTHERS             = 3.
*  ENDIF.
ENDFORM.
FORM insert_message  USING  p_msgid
                            p_msgty
                            p_msgno
                            p_msgv1
                            p_msgv2
                            p_msgv3
                            p_msgv4
                            p_linno
                     CHANGING p_flg_err TYPE flag.


  CALL FUNCTION 'MESSAGE_STORE'
    EXPORTING
      arbgb                   = p_msgid
      exception_if_not_active = ' '
      msgty                   = p_msgty
      msgv1                   = p_msgv1
      msgv2                   = p_msgv2
      msgv3                   = p_msgv3
      msgv4                   = p_msgv4
      txtnr                   = p_msgno
      zeile                   = p_linno
    EXCEPTIONS
      message_type_not_valid  = 1
      not_active              = 2
      OTHERS                  = 3.

  IF p_msgty = 'E' OR p_msgty = 'A'.
    p_flg_err = 'X'.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form set_apvd_user_status
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LV_AUFNR
*&---------------------------------------------------------------------*
*FORM set_apvd_user_status  USING    iv_aufnr TYPE aufnr.
*
*  DATA: lv_success TYPE flag,
*        lv_message TYPE char200.
*
*  " Call FM
*  CALL FUNCTION 'ZFM_SVC_SET_STATUS_APVD'
*    EXPORTING
*      iv_aufnr              = iv_aufnr
*      iv_commit             = 'X'
*    IMPORTING
*      ev_success            = lv_success
*      ev_message            = lv_message
*    EXCEPTIONS
*      order_not_found       = 1
*      status_change_error   = 2
*      approval_not_complete = 3
*      OTHERS                = 4.
*
*  IF sy-subrc = 0 AND lv_success = 'X'.
*    MESSAGE lv_message TYPE 'S'.
*  ELSE.
*    IF sy-subrc <> 0.
*      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
*              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
*    ENDIF.
*  ENDIF.
*
*ENDFORM.
*&---------------------------------------------------------------------*
*& Form set_status_nrtc
*&---------------------------------------------------------------------*
*& Set WO User Status to NRTC after successful Release
*& Calls ZFM_SVC_SET_STATUS_NRTC function module
*&---------------------------------------------------------------------*
*&      --> IV_AUFNR
*&---------------------------------------------------------------------*
*FORM set_status_nrtc  USING    iv_aufnr TYPE aufnr.
*
*  DATA: lv_success TYPE abap_bool,
*        lv_message TYPE char200.
*
*  CALL FUNCTION 'ZFM_SVC_SET_STATUS_NRTC'
*    EXPORTING
*      iv_aufnr            = iv_aufnr
*      iv_commit           = abap_true
*    IMPORTING
*      ev_success          = lv_success
*      ev_message          = lv_message
*    EXCEPTIONS
*      order_not_found     = 1
*      status_change_error = 2
*      status_not_apvd     = 3
*      OTHERS              = 4.
*
*  IF sy-subrc = 0 AND lv_success = abap_true.
*    MESSAGE lv_message TYPE 'S'.
*  ELSE.
*    MESSAGE lv_message TYPE 'W'.
*  ENDIF.
*
*
*ENDFORM.
*&---------------------------------------------------------------------*
*& Form sync_header_table
*&---------------------------------------------------------------------*
*& Sync Header Table (ZTWOAPPRH) using ZFM_APPRH_SYNC
*& Called after approval to update header status when all components approved
*& When ALL appr_valid = 'X', update header to '2' + Auto Release WO
*&---------------------------------------------------------------------*
*&      --> LT_WO_RELEASE
*&---------------------------------------------------------------------*
FORM sync_header_table  USING   it_wo_list TYPE tt_aufnr_range.

  DATA: lv_aufnr         TYPE aufnr,
        lv_aufnr_conv    TYPE aufnr,
        lv_success       TYPE char1,
        lv_new_status    TYPE char1,
        lv_total         TYPE i,
        lv_approved      TYPE i,
        lv_pending       TYPE i,
        lv_sync_count    TYPE i,
        lv_release_count TYPE i,
        lv_skip_count    TYPE i.
  DATA: lv_crt TYPE flag.
  CHECK it_wo_list IS NOT INITIAL.

  CLEAR: lv_sync_count, lv_skip_count.
  LOOP AT it_wo_list INTO DATA(ls_wo_rangex).
    lv_aufnr = ls_wo_rangex-low.
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = lv_aufnr
      IMPORTING
        output = lv_aufnr_conv.

    SELECT SINGLE * FROM ztwoapprh INTO @DATA(ls_hdrrel) WHERE aufnr = @lv_aufnr_conv.
    IF sy-subrc NE 0.
      SELECT SINGLE * FROM caufv INTO @DATA(ls_ord) WHERE aufnr = @lv_aufnr_conv.
      CHECK sy-subrc = 0.
      ls_hdrrel-aufnr = ls_ord-aufnr.
      ls_hdrrel-werks = ls_ord-werks.
      ls_hdrrel-appr_status = '1'.
      INSERT ztwoapprh FROM ls_hdrrel.
      lv_crt = 'X'.
    ENDIF.
  ENDLOOP.
  IF lv_crt = 'X'.
    COMMIT WORK AND WAIT.
  ENDIF.

  LOOP AT it_wo_list INTO DATA(ls_wo_range).
    lv_aufnr = ls_wo_range-low.

    " Convert Order Number (add leading zeros)
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = lv_aufnr
      IMPORTING
        output = lv_aufnr_conv.
    PERFORM unlock USING lv_aufnr_conv .
    WAIT UP TO 1 SECONDS.
    " Call ZFM_APPRH_SYNC to sync header status
    CALL FUNCTION 'ZFM_APPRH_SYNC'
      EXPORTING
        iv_aufnr         = lv_aufnr_conv
        iv_commit        = 'X'
      IMPORTING
        ev_success       = lv_success
        ev_new_status    = lv_new_status
        ev_total         = lv_total
        ev_approved      = lv_approved
        ev_pending       = lv_pending
      EXCEPTIONS
        header_not_found = 1
        no_components    = 2
        not_in_approval  = 3
        update_failed    = 4
        OTHERS           = 5.

    IF sy-subrc = 0 AND lv_success = 'X'.
      lv_sync_count = lv_sync_count + 1.

      " Auto Release WO when header updated to '2' (all appr_valid = 'X')
      IF lv_new_status = '2'.


        PERFORM trigger_auto_release_wo USING lv_aufnr.
        lv_release_count = lv_release_count + 1.
      ENDIF.
    ELSE.
      lv_skip_count = lv_skip_count + 1.
    ENDIF.
  ENDLOOP.

  IF lv_sync_count > 0.
    IF lv_release_count > 0.
      MESSAGE |Header synced for { lv_sync_count } WO(s), Auto Released { lv_release_count } WO(s)| TYPE 'S'.
    ELSE.
      MESSAGE |Header synced for { lv_sync_count } WO(s)| TYPE 'S'.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form reset_header_tables
*&---------------------------------------------------------------------*
*& Reset Header Table (ZTWOAPPRH) using ZFM_APPRH_RESET
*& Called during reset to clear header and component approval data
*&---------------------------------------------------------------------*
*&      --> IT_WO_LIST  Work Order range table
*&---------------------------------------------------------------------*
FORM reset_header_tables  USING    it_wo_list TYPE tt_aufnr_range.

  DATA: lv_aufnr       TYPE aufnr,
        lv_success     TYPE char1,
        lv_old_status  TYPE char1,
        lv_reset_count TYPE i,
        lv_skip_count  TYPE i.

  CHECK it_wo_list IS NOT INITIAL.

  CLEAR: lv_reset_count, lv_skip_count.

  LOOP AT it_wo_list INTO DATA(ls_wo_range).
    lv_aufnr = ls_wo_range-low.

    " Call ZFM_APPRH_RESET to reset header and components
    CALL FUNCTION 'ZFM_APPRH_RESET'
      EXPORTING
        iv_aufnr        = lv_aufnr
        iv_commit       = 'X'
      IMPORTING
        ev_success      = lv_success
        ev_old_status   = lv_old_status
      EXCEPTIONS
        order_not_found = 1
        update_failed   = 2
        OTHERS          = 3.

    IF sy-subrc = 0 AND lv_success = 'X'.
      lv_reset_count = lv_reset_count + 1.
    ELSE.
      lv_skip_count = lv_skip_count + 1.
    ENDIF.
  ENDLOOP.

  IF lv_reset_count > 0.
    MESSAGE |Header reset for { lv_reset_count } WO(s)| TYPE 'S'.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& SUMMARY: ZR_SVC_WO_APPROVAL Architecture
*&---------------------------------------------------------------------*
*&
*& (ACTIVE)   : Approval Complete → ZTWOAPPRH '2' → Auto Release WO
*&            : WO Release → ZTWOAPPRH table → User Exit gate
*&
*& KEY FLOW:
*& 1. User Release in IW32 => User Exit ZXWO1U02 clicked
*& 2. ZFM_APPR_CHK_REL checks ZTWOAPPRH status ('1'=Block, '2'=Allow)
*& 3. Report approves components => ZTWOAPPR updated (appr_valid='X')
*& 4. sync_header_tables => ZFM_APPRH_SYNC => ZTWOAPPRH '1' to '2'
*& 5. When ALL appr_valid='X' => Auto Release WO (trigger_auto_release_wo)
*& 6. Admin reset_header_tables => ZFM_APPRH_RESET => Clear approvals
*&
*& VALIDATION:
*& - validate_wo_approval_status: Check WO components and approval status
*&   - Empty components (RESB) => Info "Don't need approval WO"
*&   - All appr_valid = 'X' => Info "Approval has Completed"
*&
*& HEADER: ZTWOAPPRH (appr_status: '1'=Pending, '2'=Approved)
*&
*& FORMS  : fetch_data, compare_and_build_alv (35 ALV columns)
*& NEW    : sync_header_tables + trigger_auto_release_wo (Auto Release)
*&           validate_wo_approval_status (Empty/Completed check)
*& LEGACY (commented): validate_wo_requ_status, process_wo_release_batch,set_wo_status_apvd
*&
*& AUTH LEVELS: L1=BCSPPD, L3=SDH, L4=Branch, L5=HELPDESK (Full)  " No PDH(L2)
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Form lock
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      <-- CONTINUE
*&---------------------------------------------------------------------*
FORM lock  CHANGING p_continue.

  DATA BEGIN OF ordt_pre OCCURS 0.
  INCLUDE STRUCTURE ordtyp_pre.
  DATA END OF ordt_pre.
  DATA lt_ord_pre  TYPE TABLE OF ord_pre.
  DATA: lv_xcount    TYPE i, lv_any_error TYPE flag.

  p_continue = 'X'.

  LOOP AT gt_alv_data INTO gs_alv_data WHERE selected = 'X'.
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = gs_alv_data-aufnr
      IMPORTING
        output = gs_alv_data-aufnr.

    READ TABLE ordt_pre WITH KEY aufnr = gs_alv_data-aufnr.
    IF sy-subrc NE 0.
      SELECT SINGLE * FROM caufv INTO @DATA(ls_caufv_mor) WHERE aufnr = @gs_alv_data-aufnr.
      IF sy-subrc = 0.
        MOVE-CORRESPONDING ls_caufv_mor TO ordt_pre.
        IF ls_caufv_mor-prueflos IS INITIAL.
          ordt_pre-kein_prlos = 'X'.
        ENDIF.
        APPEND ordt_pre. CLEAR ordt_pre.
      ENDIF.
    ENDIF.
  ENDLOOP.
  IF NOT ordt_pre[] IS INITIAL.
    CALL FUNCTION 'CO_ZF_ORDER_LOCK_MULTI'
      EXPORTING
        lock_mode   = 'S'
      TABLES
        enqueue_tab = ordt_pre
        not_locked  = lt_ord_pre.
    DESCRIBE TABLE lt_ord_pre LINES lv_xcount.
    IF NOT lv_xcount IS INITIAL.

      CALL FUNCTION 'MESSAGES_INITIALIZE'.

      LOOP AT lt_ord_pre INTO DATA(ordnotlock) .
        PERFORM insert_message USING 'ALM_ME'
                              'E'
                              '802'
                              'Order '
                              ordnotlock-aufnr
                              'is currently'
                              'being processed'
                              ordnotlock-aufnr
                         CHANGING lv_any_error.
      ENDLOOP.
      IF lv_any_error NE space.
        p_continue = space.
        LOOP AT ordt_pre.
          READ TABLE lt_ord_pre  WITH KEY aufnr = ordt_pre-aufnr TRANSPORTING NO FIELDS.
          CHECK sy-subrc NE 0.
          CALL FUNCTION 'CO_ZF_ORDER_DELOCK'
            EXPORTING
              aufnr = ordt_pre-aufnr.
        ENDLOOP.
        PERFORM display_message.
        RETURN.
      ENDIF.



*      MESSAGE e802(alm_me) with 'Order ' lt_ord_pre-aufnr 'is currently' 'being processed' . "N1071405
    ENDIF.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form ensure_pending_components
*&---------------------------------------------------------------------*
*& Insert missing WO components into ZTWOAPPR as 'Pending Approve'
*& so ZFM_APPRH_SYNC counts all parts before allowing release.
*&---------------------------------------------------------------------*
*&      --> IT_WO_LIST
*&---------------------------------------------------------------------*
FORM ensure_pending_components USING it_wo_list TYPE tt_aufnr_range.

  DATA: ls_alv       TYPE ty_alv_output,
        ls_approval  TYPE ztwoappr,
        lt_insert    TYPE TABLE OF ztwoappr,
        lv_aufnr     TYPE aufnr,
        lv_matnr     TYPE matnr,
        lv_count     TYPE i.

  CHECK it_wo_list IS NOT INITIAL.

  LOOP AT it_wo_list INTO DATA(ls_wo).
    " For each WO, find all its components in the ALV
    LOOP AT gt_alv_data INTO ls_alv WHERE aufnr = ls_wo-low.
      " Convert keys to DB format (leading zeros)
      CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
        EXPORTING input  = ls_alv-aufnr
        IMPORTING output = lv_aufnr.
      CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
        EXPORTING input  = ls_alv-matnr
        IMPORTING output = lv_matnr.

      " Check if record already exists in ZTWOAPPR
      SELECT SINGLE aufnr FROM ztwoappr
        INTO lv_aufnr
        WHERE aufnr = lv_aufnr
          AND matnr = lv_matnr.

      IF sy-subrc <> 0.
        " Record does not exist => insert a Pending Approve stub
        CLEAR ls_approval.
        ls_approval-mandt         = sy-mandt.
        ls_approval-aufnr         = lv_aufnr.
        ls_approval-matnr         = lv_matnr.
        ls_approval-approval_stat = 'Pending Approve'.
        ls_approval-appr_valid    = ' '.
        ls_approval-created_by    = sy-uname.
        ls_approval-created_date  = sy-datum.
        ls_approval-created_time  = sy-uzeit.
        ls_approval-changed_by    = sy-uname.
        ls_approval-changed_date  = sy-datum.
        ls_approval-changed_time  = sy-uzeit.
        INSERT ls_approval INTO TABLE lt_insert.
      ENDIF.
    ENDLOOP.
  ENDLOOP.

  IF lt_insert IS NOT INITIAL.
    INSERT ztwoappr FROM TABLE lt_insert.
    COMMIT WORK AND WAIT.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form unlock
*&---------------------------------------------------------------------*
*& Dequeue (release) a single WO lock using CO_ZF_ORDER_DELOCK.
*& Called after COMMIT WORK for each processed WO.
*&---------------------------------------------------------------------*
*&      --> P_AUFNR
*&---------------------------------------------------------------------*
FORM unlock USING p_aufnr TYPE aufnr.
  DATA: lv_aufnr TYPE aufk-aufnr.
  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
    EXPORTING
      input  = p_aufnr
    IMPORTING
      output = lv_aufnr.

  CALL FUNCTION 'CO_ZF_ORDER_DELOCK'
    EXPORTING
      aufnr  = lv_aufnr
    EXCEPTIONS
      OTHERS = 1.

ENDFORM.