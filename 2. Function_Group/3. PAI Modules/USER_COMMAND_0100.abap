*&---------------------------------------------------------------------*
*& PAI Module : USER_COMMAND_0100
*& Screen     : 0100 — Main Menu
*&---------------------------------------------------------------------*
MODULE user_command_0100 INPUT.
  save_ok = ok_code.
  CLEAR ok_code.

  CASE save_ok.
    WHEN 'APPR'.
      CLEAR: gv_aufnr, gv_werks, gv_screen_locked, s_aufnr, gs_items_tc.
      REFRESH: gt_items_tc, s_aufnr.
      SET SCREEN 0300. LEAVE SCREEN.
    WHEN 'PEND'.
      " Reset Screen 0310 state so re-entry is always clean
      CLEAR: gv_0310_initialized, gv_0310_tree_initialized.
      REFRESH: s_w310, s_a310.        " REFRESH clears table body (CLEAR only clears header)
      SET SCREEN 0310. LEAVE SCREEN.
    WHEN 'HIST'.
      CLEAR gv_0320_initialized.
      REFRESH: s_w320, s_a320.
      SET SCREEN 0320. LEAVE SCREEN.
    WHEN 'MAIL'.
      CLEAR: p_wo_mail, p_email_type.
      SET SCREEN 0330. LEAVE SCREEN.
    WHEN '&EXIT' OR '&BACK' OR '&CANC'.
      LEAVE PROGRAM.
  ENDCASE.
ENDMODULE.
