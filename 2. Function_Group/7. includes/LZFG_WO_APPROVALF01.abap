*&---------------------------------------------------------------------*
*& Include  : ZFG_WO_APPROVALF01
*& Contains : Authorization Check, Plant Range
*&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*& FORM: check_authorization
*& Determine user level (L1/L3/L4/L5) via ZWO_APPR auth object.
*& Levels checked (highest first): L5 (HELPDESK) > L3 (SDH) > L4 (Branch) > L1 (BCSPPD)
*&---------------------------------------------------------------------*
FORM check_authorization.

  CLEAR gv_user_level.

  " Check L5 (HELPDESK — highest level)
  AUTHORITY-CHECK OBJECT 'ZWO_APPR'
    ID 'ACTVT'      FIELD '02'
    ID 'APPR_LEVEL' FIELD 'L5'.
  IF sy-subrc = 0.
    gv_user_level = gc_user_lvl-l5.
    RETURN.
  ENDIF.

  " Check L3 (Check SDH)
  AUTHORITY-CHECK OBJECT 'ZWO_APPR'
    ID 'ACTVT'      FIELD '02'
    ID 'APPR_LEVEL' FIELD 'L3'.
  IF sy-subrc = 0.
    gv_user_level = gc_user_lvl-l3.
    RETURN.
  ENDIF.

  " Check L4 (Branch)
  AUTHORITY-CHECK OBJECT 'ZWO_APPR'
    ID 'ACTVT'      FIELD '02'
    ID 'APPR_LEVEL' FIELD 'L4'.
  IF sy-subrc = 0.
    gv_user_level = gc_user_lvl-l4.
    RETURN.
  ENDIF.

  " Check L1 (BCSPPD)
  AUTHORITY-CHECK OBJECT 'ZWO_APPR'
    ID 'ACTVT'      FIELD '02'
    ID 'APPR_LEVEL' FIELD 'L1'.
  IF sy-subrc = 0.
    gv_user_level = gc_user_lvl-l1.
    RETURN.
  ENDIF.

  MESSAGE e000(db) WITH 'No authorization for Work Order Approval (ZWO_APPR).'
                        'Contact your system administrator.'.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: build_plant_range
*& Build r_swerk range of authorized plants (IWERK) per user level.
*&---------------------------------------------------------------------*
FORM build_plant_range.

  DATA: lt_t001w  TYPE STANDARD TABLE OF t001w,
        ls_t001w  TYPE t001w,
        ls_swerk  LIKE LINE OF r_swerk.

  CLEAR r_swerk.

  " Select all plants — I_SWERK authority check is the sole filter.
  SELECT * FROM t001w INTO TABLE lt_t001w.

  LOOP AT lt_t001w INTO ls_t001w.
    AUTHORITY-CHECK OBJECT 'I_SWERK'
      ID 'TCD'   FIELD 'IW33'
      ID 'SWERK' FIELD ls_t001w-werks.
    IF sy-subrc = 0.
      ls_swerk-sign   = 'I'.
      ls_swerk-option = 'EQ'.
      ls_swerk-low    = ls_t001w-werks.
      APPEND ls_swerk TO r_swerk.
    ENDIF.
  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: load_reasons_from_tvarvc
*& Load reject and change reasons from TVARVC into global tables.
*&---------------------------------------------------------------------*
FORM load_reasons_from_tvarvc.

  DATA: ls_reason  TYPE ty_reason,
        lt_tvarvc  TYPE STANDARD TABLE OF tvarvc,
        ls_tv      TYPE tvarvc.

  CHECK gt_reject_reasons IS INITIAL AND gt_change_reasons IS INITIAL.

  " Reject Reasons
  CLEAR gt_reject_reasons.
  SELECT * FROM tvarvc INTO TABLE lt_tvarvc
    WHERE name LIKE 'ZWO_REJECT_REASON%'
    AND   type = 'S'.

  LOOP AT lt_tvarvc INTO ls_tv.
    CLEAR ls_reason.
    ls_reason-reason_code = ls_tv-numb.
    ls_reason-reason_desc = ls_tv-low.
    APPEND ls_reason TO gt_reject_reasons.
  ENDLOOP.

  " Change Reasons
  CLEAR gt_change_reasons.
  SELECT * FROM tvarvc INTO TABLE lt_tvarvc
    WHERE name LIKE 'ZWO_CHANGE_REASON%'
    AND   type = 'S'.

  LOOP AT lt_tvarvc INTO ls_tv.
    CLEAR ls_reason.
    ls_reason-reason_code = ls_tv-numb.
    ls_reason-reason_desc = ls_tv-low.
    APPEND ls_reason TO gt_change_reasons.
  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM remind_items_via_teams                  [ENHANCEMENT2]
*& Sends marked TC rows to Power Automate for Teams-based approval.
*& Level auto-determined: LVL3 (SDH) first, LVL1 (HO ADM) after SDH done.
*&---------------------------------------------------------------------*
FORM remind_items_via_teams.

  DATA lt_items TYPE teams_in_handler=>tt_appr_line.

  LOOP AT gt_items_tc INTO gs_items_tc WHERE mark = abap_true.
    APPEND VALUE #(
      aufnr = gs_items_tc-aufnr
      werks = gs_items_tc-werks
      maktx = gs_items_tc-maktx
      bdmng = gs_items_tc-bdmng
      meins = gs_items_tc-meins ) TO lt_items.
  ENDLOOP.

  IF lt_items IS INITIAL.
    MESSAGE 'Mark at least one item before sending Teams reminder' TYPE 'I'.
    RETURN.
  ENDIF.

  " Auto-determine approval level from ZTWOAPPR current state
  DATA: lv_appr_level TYPE char4,
        lv_lvl3_done  TYPE char1.

  SELECT SINGLE approval_lvl3 FROM ztwoappr
    INTO @lv_lvl3_done
    WHERE aufnr = @gv_aufnr.

  lv_appr_level = COND #( WHEN lv_lvl3_done = 'X' THEN 'LVL1'   " escalate to HO ADM
                           ELSE                          'LVL3' ). " send to SDH first

  DATA: lv_req_id    TYPE char32,
        lv_http_code TYPE i.

  CALL FUNCTION 'Z_WO_APPR_TEAMS_SEND'
    EXPORTING  iv_aufnr      = gv_aufnr
               iv_requestor  = sy-uname
               iv_appr_level = lv_appr_level
    TABLES     it_items      = lt_items
    IMPORTING  ev_req_id     = lv_req_id
               ev_http_code  = lv_http_code
    EXCEPTIONS http_error    = 1
               payload_empty = 2
               OTHERS        = 3.

  CASE sy-subrc.
    WHEN 0.
      DATA(lv_level_txt) = COND #( WHEN lv_appr_level = 'LVL1'
                                   THEN 'HO ADM (LVL1)'
                                   ELSE 'SDH Branch (LVL3)' ).
      MESSAGE |Teams reminder sent to { lv_level_txt }. Request: { lv_req_id }| TYPE 'S'.
    WHEN 2.
      MESSAGE 'No items marked' TYPE 'I'.
    WHEN OTHERS.
      MESSAGE |Teams trigger failed — HTTP { lv_http_code }| TYPE 'E'.
  ENDCASE.

ENDFORM.