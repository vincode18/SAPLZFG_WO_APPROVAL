*-------------------------------------------------------------------
***INCLUDE list_tree_control_demoI01 .
*-------------------------------------------------------------------
*&---------------------------------------------------------------------*
*&      Module  PAI_0400  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE PAI_100 INPUT.
  data: return_code type i.
* CL_GUI_CFW=>DISPATCH must be called if events are registered
* that trigger PAI
* this method calls the event handler method of an event
  CALL METHOD CL_GUI_CFW=>DISPATCH
    importing return_code = return_code.
  if return_code <> cl_gui_cfw=>rc_noevent.
    " a control event occured => exit PAI
    clear g_ok_code.
    exit.
  endif.

  CASE G_OK_CODE.
    WHEN 'BACK'. " Finish program
      IF NOT G_CUSTOM_CONTAINER IS INITIAL.
        " destroy tree container (detroys contained tree control, too)
        CALL METHOD G_CUSTOM_CONTAINER->FREE
          EXCEPTIONS
            CNTL_SYSTEM_ERROR = 1
            CNTL_ERROR        = 2.
        IF SY-SUBRC <> 0.
          MESSAGE A000.
        ENDIF.
        CLEAR G_CUSTOM_CONTAINER.
        CLEAR G_TREE.
      ENDIF.
      LEAVE PROGRAM.
  ENDCASE.

* CAUTION: clear ok code!
  CLEAR G_OK_CODE.
ENDMODULE.                 " PAI_0100  INPUT
*** INCLUDE list_tree_control_demoI01