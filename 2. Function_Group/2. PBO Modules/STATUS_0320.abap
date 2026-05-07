*&---------------------------------------------------------------------*
*& PBO Module : STATUS_0320   (v1.7.3)
*& Screen     : 0320 — Approval History (Read-Only)
*& ALV starts empty. User enters range + clicks FILTER to load data.
*& Plant range pre-filled from r_swerk for convenience.
*&---------------------------------------------------------------------*
MODULE status_0320 OUTPUT.
  SET PF-STATUS gc_status-history.
  SET TITLEBAR  'T320' WITH gc_title-history.

  " Guard: ensure authorization is set
  IF gv_user_level IS INITIAL.
    PERFORM check_authorization.
  ENDIF.
  IF r_swerk IS INITIAL.
    PERFORM build_plant_range.
  ENDIF.

  IF gv_0320_initialized IS INITIAL.
    PERFORM free_alv_0320.
    PERFORM default_filter_0320.   " Pre-fill s_w320 from r_swerk (Plant range)
    PERFORM init_alv_0320.         " Create ALV pre-loaded with history data
    gv_0320_initialized = abap_true.
  ELSE.
    IF gr_alv_0320 IS BOUND.
      gr_alv_0320->refresh_table_display( ).
    ENDIF.
  ENDIF.
ENDMODULE.
