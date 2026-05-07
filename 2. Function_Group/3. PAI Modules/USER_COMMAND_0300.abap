*&---------------------------------------------------------------------*
*& PAI Modules : Screen 0300 (HOST) + Screen 0301 (SUBSCREEN)
*&---------------------------------------------------------------------*
*& Screen 0300 = Normal dynpro. PAI order (see screens/0300.abap):
*&   CALL SUBSCREEN sub_header_300.    " transports P_WOFR/P_WOTO, BT_EXEC
*&   LOOP AT gt_items_tc. CHAIN ...
*&     modify_tc_line
*&     validate_reason ON CHAIN-REQUEST
*&   ENDCHAIN. ENDLOOP.
*&   user_command_0300.                  " handles EXEC / SAVE / &BACK / &EXIT
*&
*& Screen 0301 = Subscreen dynpro (empty flow logic). Subscreens cannot
*& own OK_CODE, so the EXEC FctCode fired by BT_EXEC on 0301 is routed
*& into host 0300's user_command_0300 via the CALL SUBSCREEN above.
*&
*& Field transport:
*&   BT_EXEC click (on 0301) → host PAI runs → user_command_0300
*&   p_wofr / p_woto are painted on 0301 but stored in the
*&   same globals declared in LZFG_WO_APPROVALTOP — so the assignment
*&   in build_aufnr_range_from_params picks up the value
*&   the user typed into the subscreen without extra plumbing.
*&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*& PAI Module : MODIFY_TC_LINE  (Screen 0300 Table Control CHAIN)
*&---------------------------------------------------------------------*
MODULE modify_tc_line INPUT.
  MODIFY gt_items_tc FROM gs_items_tc INDEX tc_items-current_line.
ENDMODULE.

*&---------------------------------------------------------------------*
*& PAI Module : VALIDATE_REASON  (Screen 0300 Table Control CHAIN)
*&---------------------------------------------------------------------*
MODULE validate_reason INPUT.
  IF gs_items_tc-is_mismatch = abap_true
    AND gs_items_tc-appr_flag = abap_false
    AND gs_items_tc-reason_code IS INITIAL.
    MESSAGE 'Please enter a rejection reason for mismatch items' TYPE 'E'.
  ENDIF.
ENDMODULE.

*&---------------------------------------------------------------------*
*& PAI Module : USER_COMMAND_0300  (host dispatcher)
*&---------------------------------------------------------------------*
*& EXEC  fired by BT_EXEC on Subscreen 0301 (routed via CALL SUBSCREEN).
*& SAVE  fired by BT_SAVE on host 0300.
*& &BACK / &EXIT / &CANC come from GUI Status ZSTAT_0300.
*&---------------------------------------------------------------------*
MODULE user_command_0300 INPUT.
  save_ok = ok_code.
  CLEAR ok_code.

  CASE save_ok.
    WHEN 'EXEC'.                          " from Subscreen 0301 s_aufnr
      PERFORM load_wo_range_for_approval.
    WHEN '&APPR'.
      PERFORM approve_items.
    WHEN '&RJCT'.
      PERFORM reject_items.
    WHEN '&RAPR'.
      PERFORM reset_approval_items.
    WHEN 'SAVE'.                          " from Host 0300 BT_SAVE
      PERFORM save_approval.
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
