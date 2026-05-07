*&---------------------------------------------------------------------*
*& PAI Module : USER_COMMAND_0310
*& Screen     : 0310 — 3-Panel (Tree + Subscreen + ALV)
*&---------------------------------------------------------------------*
*&   EXEC_310       - Execute filter from subscreen 0311 (Plant/Werks).
*&   &BACK          - Return to 0100. Clears init flags so PBO rebuilds.
*&   &EXIT / &CANC  - Leave program. Clears init flags for safety.
*&---------------------------------------------------------------------*
MODULE user_command_0310 INPUT.
  DATA: lv_return_code TYPE i.

  " ── Step 1: Dispatch control events first ───────────────────────────
  CALL METHOD cl_gui_cfw=>dispatch
    IMPORTING return_code = lv_return_code.
  IF lv_return_code <> cl_gui_cfw=>rc_noevent.
    CLEAR ok_code.
    EXIT.
  ENDIF.

  " ── Step 2: Normal ok-code processing ───────────────────────────────
  save_ok = ok_code.
  CLEAR ok_code.

  CASE save_ok.
    WHEN '&SELECT' OR '&IC1'.
      PERFORM open_selected_wo_from_pending.

    WHEN 'EXEC_310'.
      " Execute pressed in subscreen 0311 — apply plant/werks filter.
      PERFORM rebuild_tree_0310.
      PERFORM load_pending_wo_list.
      IF gr_alv_0310 IS BOUND.
        gr_alv_0310->refresh_table_display( ).
      ENDIF.

    WHEN '&BACK'.
      CLEAR: gv_0310_initialized, gv_0310_tree_initialized.
      REFRESH: s_w310, s_a310.        " REFRESH clears table body (CLEAR only clears header)
      PERFORM free_alv_0310.
      PERFORM free_tree_0310.
      SET SCREEN 0100. LEAVE SCREEN.

    WHEN '&EXIT' OR '&CANC'.
      CLEAR: gv_0310_initialized, gv_0310_tree_initialized.
      REFRESH: s_w310, s_a310.
      PERFORM free_alv_0310.
      PERFORM free_tree_0310.
      LEAVE PROGRAM.

  ENDCASE.
ENDMODULE.
