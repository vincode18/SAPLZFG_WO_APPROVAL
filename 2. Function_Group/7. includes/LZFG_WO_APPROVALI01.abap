*----------------------------------------------------------------------*
***INCLUDE LZFG_WO_APPROVALI01.
*----------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0100  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_0100 INPUT.
  save_ok = ok_code.
  CLEAR ok_code.

  CASE save_ok.
    WHEN 'APPR'.
      CLEAR: gv_aufnr, gv_werks, gv_screen_locked, s_aufnr, gs_items_tc.
      REFRESH: gt_items_tc,
              s_aufnr[].
      SET SCREEN 0300. LEAVE SCREEN.
    WHEN 'PEND'.
      " Reset Screen 0310 state
      CLEAR: gv_0310_initialized, gv_0310_tree_initialized.
      REFRESH: s_w310, s_a310.
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

*&---------------------------------------------------------------------*
*& Module MODIFY_TC_LINE INPUT
*&---------------------------------------------------------------------*
*& Saves the edited TC row (work area gs_items_tc) back into the
*& internal table gt_items_tc at the current line.
*&---------------------------------------------------------------------*
*&SPWIZARD: INPUT MODULE FOR TC 'TC_ITEMS'. DO NOT CHANGE THIS LINE!
*&SPWIZARD: MODIFY TABLE
MODULE tc_items_modify INPUT.
  MODIFY gt_items_tc
    FROM gs_items_tc
    INDEX tc_items-current_line.
ENDMODULE.

*&---------------------------------------------------------------------*
*& Module VALIDATE_REASON INPUT
*&---------------------------------------------------------------------*
*& ON CHAIN-REQUEST guard: a rejection reason is mandatory when the
*& user chooses to REJECT a mismatch row. Checks either REASON_REJECT
*& or REASON_CHANGE field.
*&---------------------------------------------------------------------*
MODULE validate_reason INPUT.
  IF gs_items_tc-is_mismatch = abap_true
    AND gs_items_tc-appr_flag = abap_false
    AND gs_items_tc-reason_reject IS INITIAL
    AND gs_items_tc-reason_change IS INITIAL.
    MESSAGE 'Please enter a rejection reason for mismatch items' TYPE 'E'.
  ENDIF.
ENDMODULE.

*&---------------------------------------------------------------------*
*& Module USER_COMMAND_0300 INPUT
*&---------------------------------------------------------------------*
*& Host dispatcher. EXEC fires from Subscreen 0301 BT_EXEC, SAVE fires
*& from host 0300 BT_SAVE, &BACK/&EXIT/&CANC come from ZSTAT_0300.
*&---------------------------------------------------------------------*
MODULE user_command_0300 INPUT.
  save_ok = ok_code.
  CLEAR ok_code.

  CASE save_ok.
    WHEN '&EXEC' OR '&ONLI'.
      PERFORM load_wo_range_for_approval.
    WHEN '&APPR'.
      PERFORM approve_items.
    WHEN '&RJCT'.
      PERFORM reject_items.
    WHEN '&SAVE'.
      PERFORM save_approval.
    WHEN '&SALL'.
      PERFORM select_all_items.
    WHEN '&RSET'.
      PERFORM reset_reason.
    WHEN '&BACK'.
      PERFORM unlock_wo.
      CLEAR gv_open_from_pending.
      SET SCREEN 0100. LEAVE SCREEN.
    WHEN '&EXIT' OR '&CANC'.
      PERFORM unlock_wo.
      CLEAR gv_open_from_pending.
      LEAVE PROGRAM.
  ENDCASE.
ENDMODULE.

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

  " Step 1: Dispatch control events first
  CALL METHOD cl_gui_cfw=>dispatch
    IMPORTING
      return_code = lv_return_code.
  IF lv_return_code <> cl_gui_cfw=>rc_noevent.
    CLEAR ok_code.
    EXIT.
  ENDIF.

  " Step 2: Normal ok-code processing
  save_ok = ok_code.
  CLEAR ok_code.

  CASE save_ok.
    WHEN '&SELECT' OR '&IC1'.
      PERFORM open_selected_wo_pending USING space.

    WHEN 'BT_EXEC_310'.
      " Execute pressed in subscreen 0311 — apply plant/werks filter.
      PERFORM rebuild_tree_0310.
      PERFORM load_pending_wo_list.
      IF gr_alv_0310 IS BOUND.
        gr_alv_0310->refresh_table_display( ).
      ENDIF.

    WHEN '&BACK'.
      CLEAR: gv_0310_initialized, gv_0310_tree_initialized.
      REFRESH: s_w310, s_a310.        " Reset filter fields for clean re-entry
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

*&---------------------------------------------------------------------*
*& PAI Module : USER_COMMAND_0320   (v1.6)
*& Screen     : 0320 — Approval History (Read-Only)
*&   FILTER : reload ALV using current s_w320 / s_a320 ranges.
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
      " Full reset & free objects
      PERFORM free_alv_0320.
      CLEAR: gv_0320_initialized, s_w320[], s_a320[].
      SET SCREEN 0100. LEAVE SCREEN.
    WHEN '&EXIT' OR '&CANCEL'.
      PERFORM free_alv_0320.
      CLEAR: gv_0320_initialized, s_w320[], s_a320[].
      LEAVE PROGRAM.
  ENDCASE.
ENDMODULE.

*&---------------------------------------------------------------------*
*& PAI Module : USER_COMMAND_0330   (v1.7.2)
*& Screen     : 0330 — Manual Email Send
*&   FILTER  : narrow the Approval-Ready ALV.
*&   LOAD    : reuses the existing load_items_for_email when a single
*&             WO is in p_wo_mail (kept for backward compatibility).
*&   SEND    : group selected ALV rows by plant, send one email per plant.
*&             Direction comes from gv_send_mode (set by resolve_send_mode).
*&   SALL/DSEL : toggle MARK on every visible row.
*&---------------------------------------------------------------------*
MODULE user_command_0330 INPUT.
  save_ok = ok_code.
  CLEAR ok_code.

  CASE save_ok.
    WHEN 'FILTER' OR 'LOAD'.
      PERFORM load_appr_ready_list.    " uses s_w330, s_a330, r_swerk
      PERFORM refresh_alv_0330.

    WHEN 'SALL'.
      " any pending cell edits before bulk-marking
      IF gr_alv_0330 IS BOUND.
        gr_alv_0330->check_changed_data( ).
      ENDIF.
      LOOP AT gt_appr_ready ASSIGNING FIELD-SYMBOL(<fs_sa>).
        <fs_sa>-mark = 'X'.
      ENDLOOP.
      PERFORM refresh_alv_0330.

    WHEN 'DSEL'.
      " any pending cell edits before bulk-deselecting
      IF gr_alv_0330 IS BOUND.
        gr_alv_0330->check_changed_data( ).
      ENDIF.
      LOOP AT gt_appr_ready ASSIGNING FIELD-SYMBOL(<fs_ds>).
        CLEAR <fs_ds>-mark.
      ENDLOOP.
      PERFORM refresh_alv_0330.

    WHEN 'SEND'.
      " Authorization: only L1 (Head Office) and L4 (Branch)
      IF gv_user_level <> gc_user_lvl-l1
        AND gv_user_level <> gc_user_lvl-l4
        AND gv_user_level <> gc_user_lvl-l5.
        MESSAGE 'Only BCSPPD HO, Branch or HELPDESK users may send emails from this screen.'
                TYPE 'E'.
        RETURN.
      ENDIF.
      "checkbox edits before reading marks
      IF gr_alv_0330 IS BOUND.
        gr_alv_0330->check_changed_data( ).
      ENDIF.
      IF gv_user_level = gc_user_lvl-l5.
        " HELPDESK sends both directions for HO & Branch
        PERFORM process_send_email_grouped USING gc_send_mode-ho.
        PERFORM process_send_email_grouped USING gc_send_mode-br.
      ELSEIF gv_send_mode IS INITIAL.
        MESSAGE 'Send mode not resolved. Contact SAP Administrator.' TYPE 'E'.
      ELSE.
        PERFORM process_send_email_grouped USING gv_send_mode.
      ENDIF.

    WHEN '&BACK'.
      "Full reset — free objects
      PERFORM free_alv_0330.
      CLEAR: gv_0330_initialized, gv_send_mode, s_w330[], s_a330[].
      SET SCREEN 0100. LEAVE SCREEN.

    WHEN '&EXIT' OR '&CANC'.
      PERFORM free_alv_0330.
      CLEAR: gv_0330_initialized, gv_send_mode, s_w330[], s_a330[].
      LEAVE PROGRAM.
  ENDCASE.
ENDMODULE.