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
      "Full reset — free objects + clear
      PERFORM free_alv_0330.
      CLEAR: gv_0330_initialized, gv_send_mode, s_w330[], s_a330[].
      SET SCREEN 0100. LEAVE SCREEN.

    WHEN '&EXIT' OR '&CANC'.
      PERFORM free_alv_0330.
      CLEAR: gv_0330_initialized, gv_send_mode, s_w330[], s_a330[].
      LEAVE PROGRAM.
  ENDCASE.
ENDMODULE.
