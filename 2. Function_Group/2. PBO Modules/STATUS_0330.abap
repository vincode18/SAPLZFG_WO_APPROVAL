*&---------------------------------------------------------------------*
*& PBO Module : STATUS_0330   (v1.7.3)
*& Screen     : 0330 — Manual Email Send
*& Plant default + send-mode resolution per current user level.
*&---------------------------------------------------------------------*
MODULE status_0330 OUTPUT.
  SET PF-STATUS gc_status-email.
  SET TITLEBAR  'T330' WITH gc_title-email.

  " v1.7.2: Guard — ensure authorization + plant range are ready
  IF gv_user_level IS INITIAL.
    PERFORM check_authorization.
  ENDIF.
  IF r_swerk IS INITIAL.
    PERFORM build_plant_range.
  ENDIF.

  IF gv_0330_initialized IS INITIAL.
    PERFORM free_alv_0330.
    PERFORM default_filter_0330.   " v1.7.2 — pre-fill plant excl. 0001
    PERFORM resolve_send_mode.     " v1.6 — set gv_send_mode from user level
    PERFORM init_alv_0330.
    gv_0330_initialized = abap_true.
  ELSE.
    PERFORM refresh_alv_0330.
  ENDIF.
ENDMODULE.
