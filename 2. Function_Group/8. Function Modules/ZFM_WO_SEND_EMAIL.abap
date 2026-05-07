*&---------------------------------------------------------------------*
*& Function Module : ZFM_WO_SEND_EMAIL
*& Function Group  : ZFG_WO_APPROVAL
*& Description     : Reusable email trigger for WO Approval notifications.
*&                   Accepts a WO number and email type (HO/BR), then
*&                   orchestrates the full 4-layer send process:
*&                     Layer 1: process_send_email (orchestrator)
*&                     Layer 2: get_email_from_dli  (DLI reader)
*&                     Layer 3: build_email_html    (HTML builder)
*&                     Layer 4: send_email_bcs      (BCS sender)
*& Backing FORM    : fm_send_email (ZFG_WO_APPROVALF05)
*&
*& Callers         : Screen 0330 PAI (manual trigger), batch programs,
*&                   other reports needing to resend approval emails.
*&---------------------------------------------------------------------*
*&
*& Usage example:
*&   CALL FUNCTION 'ZFM_WO_SEND_EMAIL'
*&     EXPORTING
*&       iv_aufnr      = lv_aufnr
*&       iv_email_type = 'HO'       " 'HO' or 'BR'
*&     EXCEPTIONS
*&       send_failed   = 1
*&       no_recipients = 2
*&       OTHERS        = 3.
*&   IF sy-subrc <> 0.
*&     MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
*&               WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
*&   ENDIF.
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
