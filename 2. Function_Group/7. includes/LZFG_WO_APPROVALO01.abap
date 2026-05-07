*----------------------------------------------------------------------*
***INCLUDE LZFG_WO_APPROVALO01.
*----------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Module STATUS_0100 OUTPUT
*&---------------------------------------------------------------------*
*& Screen     : 0100 — Main Menu
*&---------------------------------------------------------------------*
MODULE status_0100 OUTPUT.
  SET PF-STATUS gc_status-main.
  SET TITLEBAR 'T100' WITH gc_title-main.
ENDMODULE.
*&---------------------------------------------------------------------*
*& PBO Modules : Screen 0300 (HOST) + Screen 0301 (SUBSCREEN)
*&---------------------------------------------------------------------*
*& Screen 0300 hosts:
*&   (a) Subscreen Area  SUB_HEADER_300   → embeds Screen 0301
*&       CALL SUBSCREEN sub_header_300 INCLUDING sy-repid '0301'.
*&   (b) Table Control   TC_ITEMS
*&
*& Screen 0301 = Subscreen dynpro holding Work Order from/to inputs,
*& BT_EXEC. Its flow logic is EMPTY — all PBO runs below belong to
*& host 0300, and EXEC is routed to host's user_command_0300.
*&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*& Module STATUS_0300 OUTPUT
*&---------------------------------------------------------------------*
MODULE status_0300 OUTPUT.
  SET PF-STATUS gc_status-entry.
  SET TITLEBAR 'T300' WITH gc_title-entry.
  DESCRIBE TABLE gt_items_tc LINES tc_items-lines.
  " Ensure authorization level
  IF gv_user_level IS INITIAL.
    PERFORM check_authorization.
  ENDIF.
  " Auto-load when navigated from Screen 0310 'Open WO' button
  IF gv_open_from_pending = abap_true.
    CLEAR gv_open_from_pending.
    PERFORM load_wo_range_for_approval.
  ENDIF.
ENDMODULE.

*&---------------------------------------------------------------------*
*& Module LOAD_REASONS OUTPUT
*&---------------------------------------------------------------------*
*& Loads the reject / change reason dropdowns from TVARVC. Must run
*& before the TC LOOP so set_reason_dropdown can populate the listbox.
*&---------------------------------------------------------------------*
MODULE load_reasons OUTPUT.
  PERFORM load_reasons_from_tvarvc.
ENDMODULE.

*&---------------------------------------------------------------------*
*& Module READ_TC_LINE OUTPUT
*&---------------------------------------------------------------------*
*& Reads the current TC row into gs_items_tc (work area).
*&---------------------------------------------------------------------*
MODULE read_tc_line OUTPUT.
  READ TABLE gt_items_tc INTO gs_items_tc INDEX tc_items-current_line.
ENDMODULE.

*&---------------------------------------------------------------------*
*& Module SET_ROW_COLOR OUTPUT
*&---------------------------------------------------------------------*
*& Highlights mismatch rows (RESB vs TaskList differ) with intensified
*& screen attribute.
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
*& Module SET_REASON_DROPDOWN OUTPUT
*&---------------------------------------------------------------------*
*& Fills the REASON_REJECT and REASON_CHANGE listbox.
*& Populated from TVARVC reason tables.
*&---------------------------------------------------------------------*
MODULE set_reason_dropdown OUTPUT.
  DATA: lt_values TYPE vrm_values,
        ls_value  TYPE vrm_value.

  " --- REASON_REJECT dropdown ---
  " key = reason_desc so VRM writes the full description into the field
  CLEAR lt_values.
  LOOP AT gt_reject_reasons INTO DATA(ls_reject).
    ls_value-key  = ls_reject-reason_desc.
    ls_value-text = ls_reject-reason_desc.
    APPEND ls_value TO lt_values.
  ENDLOOP.
  CALL FUNCTION 'VRM_SET_VALUES'
    EXPORTING
      id     = 'GS_ITEMS_TC-REASON_REJECT'
      values = lt_values.

  " --- REASON_CHANGE dropdown ---
  " key = reason_desc so VRM writes the full description into the field
  CLEAR lt_values.
  LOOP AT gt_change_reasons INTO DATA(ls_change).
    ls_value-key  = ls_change-reason_desc.
    ls_value-text = ls_change-reason_desc.
    APPEND ls_value TO lt_values.
  ENDLOOP.
  CALL FUNCTION 'VRM_SET_VALUES'
    EXPORTING
      id     = 'GS_ITEMS_TC-REASON_CHANGE'
      values = lt_values.
ENDMODULE.

*&---------------------------------------------------------------------*
*& Module CONTROL_FIELD_ATTRIBUTES OUTPUT
*&---------------------------------------------------------------------*
*& Toggles input/visibility of APPR_FLAG and REASON_CODE columns based
*& on user authorization level and whether the row is a mismatch.
*&---------------------------------------------------------------------*
MODULE control_field_attributes OUTPUT.
  LOOP AT SCREEN.
    CASE screen-name.

        " --- MARK checkbox: always editable (user selects rows to approve) ---
      WHEN 'GS_ITEMS_TC-MARK'.
        screen-input = 1. " Editable field

        " --- L1/L3 approval checkboxes: always read-only ---
      WHEN 'GS_ITEMS_TC-L1_APPROVED' OR
           'GS_ITEMS_TC-L3_APPROVED'.
        screen-input = 0. " Read-only field

        " --- Editable fields: controlled by screen lock, user level, and saved state ---
      WHEN 'GS_ITEMS_TC-APPR_FLAG'     OR
           'GS_ITEMS_TC-REASON_REJECT' OR
           'GS_ITEMS_TC-REASON_CHANGE'.
        IF gv_screen_locked = abap_true OR gv_user_level IS INITIAL.
          screen-input = 0.
        ELSEIF gs_items_tc-l1_approved = abap_true.
          screen-input = 0. "L1 has fully approved
        ELSEIF gs_items_tc-l3_approved = abap_true
            AND gv_user_level <> gc_user_lvl-l5
            AND ( screen-name = 'GS_ITEMS_TC-REASON_CHANGE'
               OR screen-name = 'GS_ITEMS_TC-REASON_REJECT' ).  " L3/L4 submitted => lock both for non-L5
          screen-input = 0.
        ELSE.
          PERFORM apply_user_level_field_rules USING screen-name.
        ENDIF.

        " --- Comparison data: always read-only ---
      WHEN 'GS_ITEMS_TC-APPROVAL_STAT'  OR
           'GS_ITEMS_TC-AUFNR'          OR
           'GS_ITEMS_TC-PLNNR'          OR
           'GS_ITEMS_TC-PLNAL'          OR
           'GS_ITEMS_TC-MATNR'          OR
           'GS_ITEMS_TC-MAKTX'          OR
           'GS_ITEMS_TC-WERKS'          OR
           'GS_ITEMS_TC-BDMNG'          OR
           'GS_ITEMS_TC-MEINS'          OR
           'GS_ITEMS_TC-PN_TASKLIST'    OR
           'GS_ITEMS_TC-DESC_TASKLIST'  OR
           'GS_ITEMS_TC-MENGE_TL'       OR
           'GS_ITEMS_TC-MEINS_TL'       OR
           'GS_ITEMS_TC-COMP_STATUS'    OR
           'GS_ITEMS_TC-COMP_MATCH'     OR
           'GS_ITEMS_TC-SERMAT'         OR
           'GS_ITEMS_TC-INTERCHANGE'    OR
           'GS_ITEMS_TC-INTERCHANGE_PN'.
        screen-input = 0. " Read-only fields

    ENDCASE.
    MODIFY SCREEN. " Update screen attributes
  ENDLOOP.
ENDMODULE.

*&---------------------------------------------------------------------*
*& FORM: apply_user_level_field_rules
*& Applies user-level specific field control when screen is not locked
*&---------------------------------------------------------------------*
FORM apply_user_level_field_rules USING pv_screen_name TYPE screen-name.

  CASE pv_screen_name.

      " --- Reason fields: editability depends on user level ---
      " L1  : only REASON_REJECT allowed  (REASON_CHANGE locked)
      " L4  : only REASON_CHANGE allowed  (REASON_REJECT locked)
      " L3/L5: both fields allowed
    WHEN 'GS_ITEMS_TC-REASON_REJECT'.
      CASE gv_user_level.
        WHEN gc_user_lvl-l4.
          screen-input     = 0.
          screen-invisible = 1.
        WHEN OTHERS.
          screen-input = 1.
      ENDCASE.

    WHEN 'GS_ITEMS_TC-REASON_CHANGE'.
      CASE gv_user_level.
        WHEN gc_user_lvl-l1.
          screen-input     = 0.
          screen-invisible = 1.
        WHEN OTHERS.
          screen-input = 1.
      ENDCASE.

      " --- Approval flag: keep user-level rule ---
    WHEN 'GS_ITEMS_TC-APPR_FLAG'.
      CASE gv_user_level.
        WHEN gc_user_lvl-l1.
          IF gs_items_tc-is_mismatch = abap_true.
            screen-input = 1.
          ELSE.
            screen-input     = 0.
            screen-invisible = 1.
          ENDIF.
        WHEN gc_user_lvl-l3 OR gc_user_lvl-l4 OR gc_user_lvl-l5.
          screen-input = 1.
        WHEN OTHERS.
          screen-input = 0.
      ENDCASE.

  ENDCASE.

ENDFORM.

*&---------------------------------------------------------------------*
*& PBO Module : STATUS_0310
*& Screen     : 0310 - Pending Approval List (ALV)
*&---------------------------------------------------------------------*
*& Lazy-init pattern: on FIRST entry, free any stale ALV objects then
*& build a fresh container + ALV + load data. On SUBSEQUENT PBO calls
*& (same session), just refresh the display.
*&
*& gv_0310_initialized is cleared by user_command_0310 on &BACK / &EXIT
*& so the next entry rebuilds cleanly.
*&---------------------------------------------------------------------*
MODULE status_0310 OUTPUT.
  SET PF-STATUS gc_status-pending.
  SET TITLEBAR 'T310' WITH gc_title-pending.

  IF gv_0310_initialized IS INITIAL.
    PERFORM free_alv_0310.      " Free old objects if re-entering screen
    PERFORM init_alv_0310.      " Create fresh container + ALV + load data
    gv_0310_initialized = abap_true.
  ELSE.
    IF gt_pending_wo IS NOT INITIAL AND gr_alv_0310 IS BOUND.
      gr_alv_0310->refresh_table_display( ).
    ENDIF.
  ENDIF.
ENDMODULE.

*&---------------------------------------------------------------------*
*& PBO Module : STATUS_0320
*& Screen     : 0320 - Approval History (Read-Only ALV)
*&---------------------------------------------------------------------*
*& Lazy-init pattern: on FIRST entry, free any stale ALV objects then
*& build a fresh container + ALV + load full history from ZTWOAPPR.
*& On SUBSEQUENT PBO calls (same session), just refresh the display.
*&
*& gv_0320_initialized is cleared by user_command_0320 on &BACK / &EXIT
*& so the next entry rebuilds cleanly.
*&---------------------------------------------------------------------*
MODULE status_0320 OUTPUT.
  SET PF-STATUS gc_status-history.
  SET TITLEBAR 'T320' WITH gc_title-history.

  IF gv_0320_initialized IS INITIAL.
    PERFORM free_alv_0320.      " Free old objects if re-entering screen
    PERFORM init_alv_0320.      " Create fresh container + ALV + load history
    gv_0320_initialized = abap_true.
  ELSE.
    IF gt_appr_history IS NOT INITIAL AND gr_alv_0320 IS BOUND.
      gr_alv_0320->refresh_table_display( ).
    ENDIF.
  ENDIF.
ENDMODULE.

*&---------------------------------------------------------------------*
*& PBO Module : STATUS_0330
*& Screen     : 0330 - Manual Email Send (ALV)
*&---------------------------------------------------------------------*
*& Lazy-init pattern: on FIRST entry, free any stale ALV objects then
*& build a fresh container + ALV (empty — data loaded via LOAD button).
*& On SUBSEQUENT PBO calls (same session), just refresh the ALV display.
*&
*& gv_0330_initialized is cleared by user_command_0330 on &BACK / &EXIT
*& so the next entry rebuilds cleanly.
*&---------------------------------------------------------------------*
MODULE status_0330 OUTPUT.
  SET PF-STATUS gc_status-email.
  SET TITLEBAR 'T330' WITH gc_title-email.

  IF gv_0330_initialized IS INITIAL.
    PERFORM free_alv_0330.      " Free old objects if re-entering screen
    CLEAR: p_wo_mail, p_email_type.  " Reset input fields on fresh entry
    PERFORM init_alv_0330.      " Create container + ALV (empty — filled on LOAD)
    gv_0330_initialized = abap_true.
  ELSE.
    PERFORM refresh_alv_0330.   " Refresh ALV display if items were loaded
  ENDIF.
ENDMODULE.