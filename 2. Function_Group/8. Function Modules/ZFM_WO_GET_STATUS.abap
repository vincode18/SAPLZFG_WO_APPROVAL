*&---------------------------------------------------------------------*
*& Function Module : ZFM_WO_GET_STATUS
*& Function Group  : ZFG_WO_APPROVAL
*& Description     : Reusable WO approval status query.
*&                   Returns APPR_STATUS and LVL_STATUS for a given WO.
*&                   Used by Exit programs to decide whether to block release.
*& Backing FORM    : fm_get_wo_status (ZFG_WO_APPROVALF03)
*&
*& Callers         : WO Release exits, other programs checking approval state.
*&---------------------------------------------------------------------*
*&
*& Usage example:
*&   DATA: lv_appr_status TYPE char1,
*&         lv_lvl_status  TYPE char1,
*&         lv_found       TYPE abap_bool.
*&
*&   CALL FUNCTION 'ZFM_WO_GET_STATUS'
*&     EXPORTING
*&       iv_aufnr       = lv_aufnr
*&     IMPORTING
*&       ev_appr_status = lv_appr_status
*&       ev_lvl_status  = lv_lvl_status
*&       ev_found       = lv_found
*&     EXCEPTIONS
*&       not_found = 1
*&       OTHERS    = 2.
*&   IF sy-subrc <> 0.
*&     MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
*&               WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
*&   ENDIF.
*&   " ev_appr_status: '0'=Draft '1'=Pending '2'=Approved
*&   " ev_lvl_status : '0'=New   '1'=L1 Done '2'=L3 Done
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
