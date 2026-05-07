*&---------------------------------------------------------------------*
*& Screen : 0300 - Approval Input & Table Control (TC_ITEMS)
*& Flow Logic - Wizard-generated frame + hand-written approval modules
*&---------------------------------------------------------------------*
PROCESS BEFORE OUTPUT.
  MODULE status_0300.
  MODULE load_reasons.
  CALL SUBSCREEN ss_300 INCLUDING sy-repid '0301'.
  MODULE set_reason_dropdown.

  LOOP AT gt_items_tc INTO gs_items_tc
       WITH CONTROL tc_items
       CURSOR tc_items-current_line.
    MODULE read_tc_line.
    MODULE set_row_color.
    MODULE control_field_attributes.
  ENDLOOP.

PROCESS AFTER INPUT.
  CALL SUBSCREEN ss_300.

  LOOP AT gt_items_tc.
    CHAIN.
      FIELD gs_items_tc-mark.
      FIELD gs_items_tc-appr_flag.
      "FIELD gs_items_tc-reason_code.
      FIELD gs_items_tc-reason_reject.
      FIELD gs_items_tc-reason_change.
      MODULE tc_items_modify ON CHAIN-REQUEST.
      MODULE validate_reason  ON CHAIN-REQUEST.
    ENDCHAIN.
  ENDLOOP.

  MODULE user_command_0300.