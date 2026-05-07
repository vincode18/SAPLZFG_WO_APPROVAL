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