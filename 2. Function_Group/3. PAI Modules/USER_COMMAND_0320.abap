*&---------------------------------------------------------------------*
*& PAI Module : USER_COMMAND_0320
*& Screen     : 0320 — Approval History (Read-Only)
*&   FILTER / BT_EXEC_0320 : load ALV using s_w320 / s_a320 ranges.
*&   ALV starts empty — data loads only after Execute button pressed.
*&---------------------------------------------------------------------*
MODULE user_command_0320 INPUT.
  save_ok = ok_code.
  CLEAR ok_code.

  CASE save_ok.
    WHEN 'FILTER' OR 'BT_EXEC_0320'.
      " Execute button: load history with current range filters
      PERFORM load_appr_history.       " uses s_w320, s_a320, r_swerk
      IF gr_alv_0320 IS BOUND.
        gr_alv_0320->refresh_table_display( ).
      ENDIF.
    WHEN '&BACK'.
      " v1.7.3: Full reset — free objects + clear filters so re-entry is clean
      PERFORM free_alv_0320.
      CLEAR: gv_0320_initialized, s_w320[], s_a320[].
      SET SCREEN 0100. LEAVE SCREEN.
    WHEN '&EXIT' OR '&CANCEL'.
      PERFORM free_alv_0320.
      CLEAR: gv_0320_initialized, s_w320[], s_a320[].
      LEAVE PROGRAM.
  ENDCASE.
ENDMODULE.
