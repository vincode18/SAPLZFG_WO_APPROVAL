*&---------------------------------------------------------------------*
*& Include  : ZFG_WO_APPROVALUXX
*& Contains : All Function Module definitions for ZFG_WO_APPROVAL
*&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*& FM: ZFM_WO_APPROVAL_MAIN
*& Entry point called by transaction ZWOAPP.
*&---------------------------------------------------------------------*
FUNCTION ZFM_WO_APPROVAL_MAIN.
*"----------------------------------------------------------------------
*"  No parameters.
*"----------------------------------------------------------------------
  PERFORM check_authorization.
  CALL SCREEN 0100.
ENDFUNCTION.

*&---------------------------------------------------------------------*
*& FM: ZFM_WO_CHECK_AUTH
*& Reusable auth check — returns user level, raises if no auth.
*& Callers: Exit programs, BAdI, other reports.
*&---------------------------------------------------------------------*
FUNCTION ZFM_WO_CHECK_AUTH.
*"----------------------------------------------------------------------
*"  EXPORTING
*"     REFERENCE(EV_USER_LEVEL) TYPE  CHAR2
*"  EXCEPTIONS
*"      NO_AUTHORIZATION
*"----------------------------------------------------------------------
  PERFORM fm_check_auth
    CHANGING ev_user_level.
  IF ev_user_level IS INITIAL.
    MESSAGE e000(db) WITH 'No authorization for Work Order Approval (ZWO_APPR).'
                          'Contact your system administrator.'
      RAISING no_authorization.
  ENDIF.
ENDFUNCTION.

*&---------------------------------------------------------------------*
*& FM: ZFM_WO_GET_STATUS
*& Reusable WO approval status query.
*& Callers: Exit programs to decide whether to block WO release.
*&---------------------------------------------------------------------*
FUNCTION ZFM_WO_GET_STATUS.
*"----------------------------------------------------------------------
*"  IMPORTING
*"     REFERENCE(IV_AUFNR)       TYPE  AUFNR
*"  EXPORTING
*"     REFERENCE(EV_APPR_STATUS) TYPE  CHAR1
*"     REFERENCE(EV_LVL_STATUS)  TYPE  CHAR1
*"     REFERENCE(EV_FOUND)       TYPE  ABAP_BOOL
*"  EXCEPTIONS
*"      NOT_FOUND
*"----------------------------------------------------------------------
  PERFORM fm_get_wo_status
    USING    iv_aufnr
    CHANGING ev_appr_status ev_lvl_status ev_found.
  IF ev_found = abap_false.
    MESSAGE i000(db) WITH 'Work Order' iv_aufnr 'not found in approval system.'
      RAISING not_found.
  ENDIF.
ENDFUNCTION.

*&---------------------------------------------------------------------*
*& FM: ZFM_WO_SEND_EMAIL
*& Reusable email trigger for WO Approval notifications.
*& Callers: Screen 0330 PAI, batch programs, other reports.
*&---------------------------------------------------------------------*
FUNCTION ZFM_WO_SEND_EMAIL.
*"----------------------------------------------------------------------
*"  IMPORTING
*"     REFERENCE(IV_AUFNR)      TYPE  AUFNR
*"     REFERENCE(IV_EMAIL_TYPE) TYPE  CHAR2    " 'HO' or 'BR'
*"  EXCEPTIONS
*"      SEND_FAILED
*"      NO_RECIPIENTS
*"----------------------------------------------------------------------
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
ENDFUNCTION.
