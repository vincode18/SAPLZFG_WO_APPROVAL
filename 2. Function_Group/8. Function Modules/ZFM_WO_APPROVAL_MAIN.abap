*&---------------------------------------------------------------------*
*& Function Module : ZFM_WO_APPROVAL_MAIN
*& Function Group  : ZFG_WO_APPROVAL
*& Description     : Entry point called by transaction ZWOAPP.
*&                   Performs authorization check then launches Screen 0100.
*& Backing FORM    : fm_approval_main (ZFG_WO_APPROVALF01)
*&---------------------------------------------------------------------*
*&
*& Usage example:
*&   Called automatically by transaction ZWOAPP.
*&   To call programmatically:
*&
*&   CALL FUNCTION 'ZFM_WO_APPROVAL_MAIN'.
*&---------------------------------------------------------------------*
FUNCTION ZFM_WO_APPROVAL_MAIN.
*"----------------------------------------------------------------------
*"  No parameters.
*"----------------------------------------------------------------------
  PERFORM check_authorization.
  CALL SCREEN 0100.
ENDFUNCTION.
