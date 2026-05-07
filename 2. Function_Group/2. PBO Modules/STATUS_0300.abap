*&---------------------------------------------------------------------*
*& PBO Modules : Screen 0300 (HOST) + Screen 0301 (SUBSCREEN)
*&---------------------------------------------------------------------*
*& Screen 0300 = Normal dynpro. Hosts:
*&   (a) Subscreen Area  SUB_HEADER_300  → embeds Screen 0301
*&       Flow logic: CALL SUBSCREEN sub_header_300 INCLUDING sy-repid '0301'.
*&   (b) Table Control   TC_ITEMS
*&   (c) Pushbutton      BT_SAVE          FctCode = SAVE
*&
*& Screen 0301 = Subscreen dynpro (Dynpro Type: Subscreen). Holds the
*& WO-range header (P_AUFNR_FROM, P_AUFNR_TO, BT_EXEC). Its flow logic
*& is EMPTY by design — all PBO runs below belong to host 0300, and the
*& EXEC FctCode from BT_EXEC is handled by host's user_command_0300.
*& Subscreens cannot own PF-STATUS, Titlebar, or OK_CODE.
*&
*& PBO module call order inside host 0300 (see screens/0300.abap):
*&   status_0300          → PF-STATUS + titlebar + TC line count
*&   load_reasons         → fills gt_reject_reasons / gt_change_reasons
*&   CALL SUBSCREEN ...   → renders Screen 0301 into SUB_HEADER_300
*&   LOOP AT gt_items_tc  → TC row modules below
*&     read_tc_line
*&     set_row_color
*&     set_reason_dropdown
*&     control_field_attributes
*&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*& PBO Module : STATUS_0300
*& Screen     : 0300 — Host screen (Approval Input + Table Control)
*&---------------------------------------------------------------------*
MODULE status_0300 OUTPUT.
  SET PF-STATUS gc_status-entry.
  SET TITLEBAR 'T300' WITH gc_title-entry.
  DESCRIBE TABLE gt_items_tc LINES tc_items-lines.
ENDMODULE.

*&---------------------------------------------------------------------*
MODULE load_reasons OUTPUT.
  PERFORM load_reasons_from_tvarvc.
ENDMODULE.

*&---------------------------------------------------------------------*
MODULE read_tc_line OUTPUT.
  READ TABLE gt_items_tc INTO gs_items_tc INDEX tc_items-current_line.
ENDMODULE.

*&---------------------------------------------------------------------*
MODULE set_row_color OUTPUT.
  LOOP AT SCREEN.
    IF gs_items_tc-is_mismatch = abap_true.
      screen-intensified = '1'.
    ENDIF.
    MODIFY SCREEN.
  ENDLOOP.
ENDMODULE.

*&---------------------------------------------------------------------*
MODULE set_reason_dropdown OUTPUT.
  DATA: lt_values TYPE vrm_values,
        ls_value  TYPE vrm_value.
  CLEAR lt_values.

  IF gs_items_tc-is_mismatch = abap_true.
    IF gs_items_tc-appr_flag = abap_false.
      LOOP AT gt_reject_reasons INTO DATA(ls_reject).
        ls_value-key  = ls_reject-reason_code.
        ls_value-text = |{ ls_reject-reason_code } - { ls_reject-reason_desc }|.
        APPEND ls_value TO lt_values.
      ENDLOOP.
    ELSE.
      LOOP AT gt_change_reasons INTO DATA(ls_change).
        ls_value-key  = ls_change-reason_code.
        ls_value-text = |{ ls_change-reason_code } - { ls_change-reason_desc }|.
        APPEND ls_value TO lt_values.
      ENDLOOP.
    ENDIF.
    CALL FUNCTION 'VRM_SET_VALUES'
      EXPORTING
        id     = 'GS_ITEMS_TC-REASON_CODE'
        values = lt_values.
  ENDIF.
ENDMODULE.

*&---------------------------------------------------------------------*
MODULE control_field_attributes OUTPUT.
  LOOP AT SCREEN.
    IF screen-name = 'GS_ITEMS_TC-APPR_FLAG'.
      CASE gv_user_level.
        WHEN gc_user_lvl-l1.
          IF gs_items_tc-is_mismatch = abap_true.
            screen-input = 1.
          ELSE.
            screen-input      = 0.
            screen-invisible  = 1.
          ENDIF.
        WHEN gc_user_lvl-l3 OR gc_user_lvl-l4 OR gc_user_lvl-l5.
          screen-input = 1.
        WHEN OTHERS.
          screen-input = 0.
      ENDCASE.
    ENDIF.
    IF screen-name = 'GS_ITEMS_TC-REASON_CODE'.
      IF gs_items_tc-is_mismatch = abap_true.
        screen-input = 1.
      ELSE.
        screen-input     = 0.
        screen-invisible = 1.
      ENDIF.
    ENDIF.
    MODIFY SCREEN.
  ENDLOOP.
ENDMODULE.
