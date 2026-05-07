*&---------------------------------------------------------------------*
*& PBO Module : STATUS_0310
*& Screen     : 0310 — 3-Panel (Tree + Subscreen + ALV)
*&---------------------------------------------------------------------*
MODULE status_0310 OUTPUT.
  SET PF-STATUS gc_status-pending.
  SET TITLEBAR 'T310' WITH gc_title-pending.

  " Guard: ensure authorization is set before proceeding
  IF gv_user_level IS INITIAL.
    PERFORM check_authorization.
  ENDIF.
  IF r_swerk IS INITIAL.
    PERFORM build_plant_range.
  ENDIF.

  "PERFORM default_filter_0310.            " pre-fill s_w310 from r_swerk

  " v1.7.1: s_w310/s_a310 left blank — auto_load_0310 uses r_swerk directly
  PERFORM auto_load_0310.

  IF gv_0310_initialized IS INITIAL.
    PERFORM free_alv_0310.
    PERFORM free_tree_0310.

    " ALV initialised first — creates CC_ALV_0310 container and loads
    PERFORM init_alv_0310.

    " Tree initialised second
    PERFORM init_tree_0310.

    gv_0310_initialized      = abap_true.
    gv_0310_tree_initialized = abap_true.
  ELSE.
    IF gr_alv_0310 IS BOUND.
      gr_alv_0310->refresh_table_display( ).
    ENDIF.
  ENDIF.
ENDMODULE.
