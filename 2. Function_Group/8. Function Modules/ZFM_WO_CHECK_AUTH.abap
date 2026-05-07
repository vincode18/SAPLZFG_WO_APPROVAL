*&---------------------------------------------------------------------*
*& Function Module : ZFM_WO_CHECK_AUTH
*& Function Group  : ZFG_WO_APPROVAL
*& Description     : Reusable authorization check for WO Approval.
*&                   Returns the user's approval level (L1 / L3 / AD).
*&                   Raises NO_AUTHORIZATION if no valid level found.
*& Backing FORM    : fm_check_auth (ZFG_WO_APPROVALF01)
*&
*& Callers         : Exit programs, BAdI implementations, other reports.
*&---------------------------------------------------------------------*
*&
*& Usage example:
*&   DATA: lv_level TYPE char2.
*&
*&   CALL FUNCTION 'ZFM_WO_CHECK_AUTH'
*&     IMPORTING
*&       ev_user_level    = lv_level
*&     EXCEPTIONS
*&       no_authorization = 1
*&       OTHERS           = 2.
*&   IF sy-subrc <> 0.
*&     MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
*&               WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
*&   ENDIF.
*&   " lv_level = 'L1' / 'L3' / 'AD'
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
