*&---------------------------------------------------------------------*
*& Include  : ZFG_WO_APPROVALF02
*& Contains : Save Logic Object Lock/Unlock
*&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*& FORM: save_approval
*& Dispatcher — routes to save_as_l1, save_as_l4, or save_as_l5 based
*&---------------------------------------------------------------------*
FORM save_approval.

  " Ensure user level is set (may be empty if not called at startup)
  IF gv_user_level IS INITIAL.
    PERFORM check_authorization.
  ENDIF.

  CASE gv_user_level.
    WHEN gc_user_lvl-l1.
      PERFORM save_as_l1. " L1 saves for inputting Reason Rejection
    WHEN gc_user_lvl-l4.
      PERFORM save_as_l4. " L4 saves for inputting Reason Change
    WHEN gc_user_lvl-l3.
      PERFORM save_as_l3. " L3 can't edit Reason Rejection or Reason Change
    WHEN gc_user_lvl-l5.
      PERFORM save_as_l5. " L5 saves can edit Reason Rejection or Reason Change
    WHEN OTHERS.
      MESSAGE e000(db) WITH 'Unauthorized save attempt - no valid approval level assigned.'
                            'Contact your SAP Admin.'.
  ENDCASE.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: approve_items
*& Approval routing based on plant/PLNNR live status
*& - If both plant and PLNNR live: L1 approves mismatch items
*& - If plant live but PLNNR not live: Routes to L3 approval
*& - Only processes items marked with mark = 'X'
*&---------------------------------------------------------------------*
FORM approve_items.

  DATA: ls_item       TYPE ty_items_tc,
        lv_lock_ok    TYPE flag,
        lv_count      TYPE i,
        lv_plant_live TYPE flag,
        lv_plnnr_live TYPE flag,
        ls_tvarvc     TYPE tvarvc,
        lv_plant      TYPE werks_d,
        lv_plnnr      TYPE plnnr.

  " Ensure user is L1 or L3
  IF gv_user_level IS INITIAL.
    PERFORM check_authorization.
  ENDIF.

  " Check if any items are marked
  LOOP AT gt_items_tc INTO ls_item WHERE mark = 'X'.
    ADD 1 TO lv_count.
  ENDLOOP.

  IF lv_count = 0.
    MESSAGE 'Please select at least one item to approve' TYPE 'E'.
    RETURN.
  ENDIF.

  " Get plant and PLNNR from first marked item
  READ TABLE gt_items_tc INTO ls_item WITH KEY mark = 'X'.
  IF sy-subrc = 0.
    lv_plant = ls_item-werks.
    lv_plnnr = ls_item-plnnr.
  ENDIF.

  " Check if plant is live in TVARVC (type S)
  SELECT SINGLE * FROM tvarvc INTO ls_tvarvc
    WHERE name = 'APPROVAL_WO_KEY_GEN'
      AND type = 'S'
      AND low = lv_plant.
  IF sy-subrc = 0.
    lv_plant_live = 'X'.
  ENDIF.

  " Check if PLNNR is live in TVARVC (type S)
  SELECT SINGLE * FROM tvarvc INTO ls_tvarvc
    WHERE name = 'APPROVAL_WO_TASKLIST'
      AND type = 'S'
      AND low = lv_plnnr.
  IF sy-subrc = 0.
    lv_plnnr_live = 'X'.
  ENDIF.

  " Route based on live status
  IF lv_plant_live = 'X' AND lv_plnnr_live = 'X'.
    " Both live → L1 approval path
    PERFORM l1_approve_both_live.
  ELSEIF lv_plant_live = 'X' AND lv_plnnr_live IS INITIAL.
    " Plant live, PLNNR not live → L3 approval path
    PERFORM l3_approve_plant_only.
  ELSE.
    MESSAGE |Plant { lv_plant } is not yet live in TVARVC. Approval not allowed.| TYPE 'E'.
    RETURN.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: l1_approve_both_live
*& L1 approval when both plant and PLNNR are live
*&---------------------------------------------------------------------*
FORM l1_approve_both_live.

  DATA: ls_item    TYPE ty_items_tc,
        lv_lock_ok TYPE flag,
        lv_count   TYPE i.

  IF gv_user_level <> gc_user_lvl-l1 AND gv_user_level <> gc_user_lvl-l5.
    MESSAGE 'Only L1 (HO) or L5 (Helpdesk) users can use this function when both plant and PLNNR are live' TYPE 'E'.
    RETURN.
  ENDIF.

  " Process only marked items for L1 approval
  lv_count = 0.
  LOOP AT gt_items_tc INTO ls_item WHERE mark = 'X'.
    ls_item-appr_flag   = 'X'.
    ls_item-l1_approved = 'X'.
    ls_item-l3_approved = 'X'.
    MODIFY gt_items_tc FROM ls_item.
    ADD 1 TO lv_count.
  ENDLOOP.

  IF lv_count = 0.
    MESSAGE 'No items found for L1 approval' TYPE 'I'.
    RETURN.
  ENDIF.

  " Lock WO object before update
  PERFORM lock_wo_object CHANGING lv_lock_ok.
  IF lv_lock_ok <> 'X'.
    RETURN.
  ENDIF.

  " Update database - L1/L5 sets approval_lvl1 + approval_lvl3 for marked items only
  LOOP AT gt_items_tc INTO ls_item WHERE mark = 'X'.
    UPDATE ztwoappr
      SET approval_lvl1  = 'X'
          approval_lvl3  = 'X'
          reason_reject  = space
          reason_change  = space
          changed_by     = sy-uname
          changed_date   = sy-datum
      WHERE aufnr     = gv_aufnr
        AND matnr     = ls_item-matnr
        AND change_id = ls_item-rspos.
  ENDLOOP.

  " Set global flag to lock screen in PBO
  gv_screen_locked = 'X'.

  COMMIT WORK AND WAIT.
  PERFORM unlock_wo_object.
  IF gv_user_level = gc_user_lvl-l5.
    MESSAGE s000(db) WITH lv_count 'mismatch item(s) approved by L5.'.
  ELSE.
    MESSAGE s000(db) WITH lv_count 'mismatch item(s) approved by L1.'.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: l3_approve_plant_only
*& L3 approval when plant is live but PLNNR is not
*& Only processes marked items
*&---------------------------------------------------------------------*
FORM l3_approve_plant_only.

  DATA: ls_item    TYPE ty_items_tc,
        lv_lock_ok TYPE flag,
        lv_count   TYPE i.

  IF gv_user_level <> gc_user_lvl-l3 AND gv_user_level <> gc_user_lvl-l5.
    MESSAGE 'Only L3 (SDH) or L5 (Helpdesk) users can use this function when PLNNR is not live' TYPE 'E'.
    RETURN.
  ENDIF.

  " Process only marked items for L3 approval
  lv_count = 0.
  LOOP AT gt_items_tc INTO ls_item WHERE mark = 'X'.
    ls_item-appr_flag = 'X'.
    ls_item-l3_approved = 'X'.
    MODIFY gt_items_tc FROM ls_item.
    ADD 1 TO lv_count.
  ENDLOOP.

  IF lv_count = 0.
    MESSAGE 'No items found for L3 approval' TYPE 'I'.
    RETURN.
  ENDIF.

  " Lock WO object before update
  PERFORM lock_wo_object CHANGING lv_lock_ok.
  IF lv_lock_ok <> 'X'.
    RETURN.
  ENDIF.

  " Update database - L3 sets approval_lvl3 for marked items only
  LOOP AT gt_items_tc INTO ls_item WHERE mark = 'X'.
    UPDATE ztwoappr
      SET approval_lvl3  = 'X'
          reason_reject  = ls_item-reason_reject
          reason_change  = ls_item-reason_change
          changed_by     = sy-uname
          changed_date   = sy-datum
       WHERE aufnr     = gv_aufnr
        AND matnr     = ls_item-matnr
        AND change_id = ls_item-rspos.
  ENDLOOP.

  " Set global flag to lock screen in PBO
  gv_screen_locked = 'X'.

  COMMIT WORK AND WAIT.
  PERFORM unlock_wo_object.
  MESSAGE s000(db) WITH lv_count 'item(s) approved by L3 (Tasklist not live).'.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: reset_approval_items
*& L5 (Helpdesk) only: Clears all approval flags for selected items
*& in both ZTWOAPPR (database) and gt_items_tc (memory).
*&---------------------------------------------------------------------*
FORM reset_approval_items.

  DATA: ls_item    TYPE ty_items_tc,
        lv_count   TYPE i,
        lv_lock_ok TYPE flag.

  " L5 only
  IF gv_user_level <> gc_user_lvl-l5.
    MESSAGE 'Only L5 (Helpdesk) users can reset approval flags' TYPE 'E'.
    RETURN.
  ENDIF.

  " Check at least one item is marked
  lv_count = 0.
  LOOP AT gt_items_tc INTO ls_item WHERE mark = 'X'.
    ADD 1 TO lv_count.
  ENDLOOP.
  IF lv_count = 0.
    MESSAGE 'No items selected. Please mark items to reset' TYPE 'I'.
    RETURN.
  ENDIF.

  " Lock WO object before update
  PERFORM lock_wo_object CHANGING lv_lock_ok.
  IF lv_lock_ok <> 'X'.
    RETURN.
  ENDIF.

  " Clear approval flags in ZTWOAPPR for all marked items
  LOOP AT gt_items_tc INTO ls_item WHERE mark = 'X'.
    UPDATE ztwoappr
      SET approval_lvl1  = space
          approval_lvl3  = space
          approval_stat  = space
          reason_reject  = space
          changed_by     = sy-uname
          changed_date   = sy-datum
      WHERE aufnr = gv_aufnr
        AND matnr = ls_item-matnr.

    " Reset in-memory flags
    ls_item-l1_approved   = space.
    ls_item-l3_approved   = space.
    ls_item-approval_stat = space.
    ls_item-appr_flag     = space.
    ls_item-reason_reject = space.
    ls_item-mark          = space.
    MODIFY gt_items_tc FROM ls_item.
  ENDLOOP.

  COMMIT WORK AND WAIT.
  PERFORM unlock_wo_object.
  MESSAGE s000(db) WITH lv_count 'item(s) approval reset by L5 (Helpdesk).'.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: reject_items
*& L1 (HO) rejection: Requires reason_reject to be filled for selected items
*&---------------------------------------------------------------------*
FORM reject_items.

  DATA: ls_item     TYPE ty_items_tc,
        lv_selected TYPE i,
        lv_lock_ok  TYPE flag.

  " Ensure user is L1
  IF gv_user_level IS INITIAL.
    PERFORM check_authorization.
  ENDIF.

  IF gv_user_level <> gc_user_lvl-l1.
    MESSAGE 'Only L1 (HO) users can use this function' TYPE 'E'.
    RETURN.
  ENDIF.

  " Check if any items are selected
  LOOP AT gt_items_tc INTO ls_item WHERE mark = 'X'.
    ADD 1 TO lv_selected.
  ENDLOOP.

  IF lv_selected = 0.
    MESSAGE 'Please select at least one item to reject' TYPE 'E'.
    RETURN.
  ENDIF.

  " Validate reason_reject is filled for selected items
  LOOP AT gt_items_tc INTO ls_item WHERE mark = 'X'.
    IF ls_item-reason_reject IS INITIAL.
      MESSAGE 'Reason Reject is required for all selected items' TYPE 'E'.
      RETURN.
    ENDIF.
  ENDLOOP.

  " Lock WO object before update
  PERFORM lock_wo_object CHANGING lv_lock_ok.
  IF lv_lock_ok <> 'X'.
    RETURN.
  ENDIF.

  " Update database - L1 sets rejection
  LOOP AT gt_items_tc INTO ls_item WHERE mark = 'X'.
    UPDATE ztwoappr
      SET approval_lvl1  = space
          reason_reject  = ls_item-reason_reject
          reason_change  = space
          changed_by     = sy-uname
          changed_date   = sy-datum
       WHERE aufnr     = gv_aufnr
        AND matnr     = ls_item-matnr
        AND change_id = ls_item-rspos.

    " Update internal table
    ls_item-appr_flag = space.
    MODIFY gt_items_tc FROM ls_item.
  ENDLOOP.

  COMMIT WORK AND WAIT.
  PERFORM unlock_wo_object.
  MESSAGE s000(db) WITH lv_selected 'item(s) rejected by L1.'.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: save_as_l1
*& L1 (BCSPPD HO): Only REASON_REJECT is allowed. REASON_CHANGE must
*& be empty. Saves mismatch rows only.
*&---------------------------------------------------------------------*
FORM save_as_l1.

  DATA: ls_apprh  TYPE ztwoapprh,
        ls_appr   TYPE ztwoappr,
        lv_all_ok TYPE flag VALUE 'X'.

  " L1 validation: if rejecting (appr_flag empty), reason_reject mandatory.
  " reason_change is not permitted for L1.
  LOOP AT gt_items_tc INTO DATA(ls_item) WHERE is_mismatch = 'X'.
    IF ls_item-appr_flag IS INITIAL AND ls_item-reason_reject IS INITIAL.
      MESSAGE 'L1: Enter a Reason Reject for all rejected mismatch items before saving' TYPE 'E'.
      RETURN.
    ENDIF.
    IF ls_item-reason_change IS NOT INITIAL.
      MESSAGE 'L1: Reason Change is not permitted at this approval level' TYPE 'E'.
      RETURN.
    ENDIF.
  ENDLOOP.

  " Lock WO object before update
  DATA: lv_lock_ok TYPE flag.
  PERFORM lock_wo_object CHANGING lv_lock_ok.
  IF lv_lock_ok <> 'X'.
    RETURN.
  ENDIF.

  " Update ZTWOAPPR detail lines
  LOOP AT gt_items_tc INTO ls_item WHERE is_mismatch = 'X'.
    UPDATE ztwoappr
      SET approval_lvl1  = ls_item-appr_flag
          reason_reject  = ls_item-reason_reject
          reason_change  = space
          changed_by     = sy-uname
          changed_date   = sy-datum
      WHERE aufnr     = gv_aufnr
        AND matnr     = ls_item-matnr
        AND change_id = ls_item-rspos.
  ENDLOOP.

  " Record L1 audit on header
  UPDATE ztwoapprh
    SET changed_by   = sy-uname
        changed_date = sy-datum
        changed_time = sy-uzeit
    WHERE aufnr = gv_aufnr.

  COMMIT WORK AND WAIT.
  PERFORM unlock_wo_object.
  MESSAGE s000(db) WITH 'L1 approval saved successfully. WO is now pending L3 (HO) review.'.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: save_as_l4
*& L4 (Branch): Only REASON_CHANGE is allowed. REASON_REJECT must be empty.
*&---------------------------------------------------------------------*
FORM save_as_l4.

  DATA: ls_item    TYPE ty_items_tc,
        lv_lock_ok TYPE flag,
        lv_count   TYPE i.

  " L4 validation: marked rows must have reason_change; reason_reject not permitted
  LOOP AT gt_items_tc TRANSPORTING NO FIELDS WHERE mark = 'X'.
    ADD 1 TO lv_count.
  ENDLOOP.
  IF lv_count = 0.
    MESSAGE 'Please select at least one item to save' TYPE 'E'.
    RETURN.
  ENDIF.

  LOOP AT gt_items_tc INTO ls_item WHERE mark = 'X'.
    IF ls_item-reason_reject IS NOT INITIAL.
      MESSAGE 'L4: Reason Reject is not permitted at this approval level' TYPE 'E'.
      RETURN.
    ENDIF.
*    IF ls_item-reason_change IS INITIAL.
*      MESSAGE 'L4: Please fill Reason Change for all selected items' TYPE 'E'.
*      RETURN.
*    ENDIF.
  ENDLOOP.

  " Lock WO object before update
  PERFORM lock_wo_object CHANGING lv_lock_ok.
  IF lv_lock_ok <> 'X'.
    RETURN.
  ENDIF.

  " Check if any marked row has reason_change filled (submission) or all empty (reset)
  DATA: lv_has_reason TYPE flag.
  LOOP AT gt_items_tc INTO ls_item WHERE mark = 'X'.
    IF ls_item-reason_change IS NOT INITIAL.
      lv_has_reason = 'X'.
      EXIT.
    ENDIF.
  ENDLOOP.

  " Update only marked rows
  LOOP AT gt_items_tc ASSIGNING FIELD-SYMBOL(<ls_l4_item>) WHERE mark = 'X'.
    " When reason_change is filled (submission), set approval_lvl3='X' to lock field on reload
    " When reason is cleared (reset), set approval_lvl3=space to unlock field
    DATA: lv_appr_lvl3 TYPE char1.
    IF <ls_l4_item>-reason_change IS NOT INITIAL.
      lv_appr_lvl3 = 'X'.
    ELSE.
      lv_appr_lvl3 = space.
    ENDIF.

    UPDATE ztwoappr
      SET reason_reject  = space
          reason_change  = <ls_l4_item>-reason_change
          approval_lvl3  = lv_appr_lvl3
          changed_by     = sy-uname
          changed_date   = sy-datum
      WHERE aufnr     = gv_aufnr
        AND matnr     = <ls_l4_item>-matnr
        AND change_id = <ls_l4_item>-rspos.
    " Update in-memory flag
    <ls_l4_item>-l3_approved = lv_appr_lvl3.
  ENDLOOP.

  IF lv_has_reason = 'X'.
    " Submission: set header to submitted for L1 review
    UPDATE ztwoapprh
      SET appr_status  = gc_appr_status-submitted
          changed_by   = sy-uname
          changed_date = sy-datum
          changed_time = sy-uzeit
      WHERE aufnr = gv_aufnr.
  ELSE.
    " Reset save: keep current header status, just record changed_by
    UPDATE ztwoapprh
      SET changed_by   = sy-uname
          changed_date = sy-datum
          changed_time = sy-uzeit
      WHERE aufnr = gv_aufnr.
  ENDIF.

  COMMIT WORK AND WAIT.
  PERFORM unlock_wo_object.

  IF lv_has_reason = 'X'.
    MESSAGE s000(db) WITH 'L4 application submitted. Pending L1 review.'.
  ELSE.
    MESSAGE s000(db) WITH 'Reason(s) cleared and saved. Screen unlocked for re-entry.'.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: save_as_l3
*& L3 (SDH HO): Can fill both REASON_REJECT and REASON_CHANGE.
*& After save, fields lock — L3 cannot re-edit once L4 filled
*& reason_change or L1 filled reason_reject.
*&---------------------------------------------------------------------*
FORM save_as_l3.

  DATA: ls_item    TYPE ty_items_tc,
        lv_count   TYPE i,
        lv_lock_ok TYPE flag.

  LOOP AT gt_items_tc TRANSPORTING NO FIELDS WHERE mark = 'X'.
    ADD 1 TO lv_count.
  ENDLOOP.

  IF lv_count = 0.
    MESSAGE 'Please select at least one item to save' TYPE 'E'.
    RETURN.
  ENDIF.

  PERFORM lock_wo_object CHANGING lv_lock_ok.
  IF lv_lock_ok <> 'X'.
    RETURN.
  ENDIF.

  " Ensure header row exists in ZTWOAPPRH
  DATA: ls_apprh_l3 TYPE ztwoapprh.
  SELECT SINGLE * FROM ztwoapprh INTO @ls_apprh_l3 WHERE aufnr = @gv_aufnr.
  IF sy-subrc <> 0.
    CLEAR ls_apprh_l3.
    ls_apprh_l3-aufnr        = gv_aufnr.
    ls_apprh_l3-appr_status  = gc_appr_status-submitted.
    ls_apprh_l3-changed_by   = sy-uname.
    ls_apprh_l3-changed_date = sy-datum.
    ls_apprh_l3-changed_time = sy-uzeit.
    INSERT ztwoapprh FROM ls_apprh_l3.
  ENDIF.

  DATA: ls_appr_l3 TYPE ztwoappr.
  LOOP AT gt_items_tc ASSIGNING FIELD-SYMBOL(<ls_l3_item>) WHERE mark = 'X'.
    UPDATE ztwoappr
      SET reason_reject  = <ls_l3_item>-reason_reject
          reason_change  = <ls_l3_item>-reason_change
          changed_by     = sy-uname
          changed_date   = sy-datum
       WHERE aufnr     = gv_aufnr
        AND matnr     = <ls_l3_item>-matnr
        AND change_id = <ls_l3_item>-rspos.
    IF sy-subrc <> 0.
      CLEAR ls_appr_l3.
      ls_appr_l3-aufnr         = gv_aufnr.
      ls_appr_l3-matnr         = <ls_l3_item>-matnr.
      ls_appr_l3-change_id     = <ls_l3_item>-rspos.
      ls_appr_l3-reason_reject = <ls_l3_item>-reason_reject.
      ls_appr_l3-reason_change = <ls_l3_item>-reason_change.
      ls_appr_l3-changed_by    = sy-uname.
      ls_appr_l3-changed_date  = sy-datum.
      INSERT ztwoappr FROM ls_appr_l3.
    ENDIF.
    " Lock fields after save: set l3_approved if either reason is filled
    IF <ls_l3_item>-reason_change IS NOT INITIAL OR <ls_l3_item>-reason_reject IS NOT INITIAL.
      <ls_l3_item>-l3_approved = 'X'.
    ELSE.
      <ls_l3_item>-l3_approved = space.
    ENDIF.
  ENDLOOP.

  UPDATE ztwoapprh
    SET changed_by   = sy-uname
        changed_date = sy-datum
        changed_time = sy-uzeit
    WHERE aufnr = gv_aufnr.

  COMMIT WORK AND WAIT.
  PERFORM unlock_wo_object.

  MESSAGE s000(db) WITH 'Reason(s) saved. Fields locked until Reset Reason is used.'.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: save_as_l5
*& L5 (Helpdesk): Both REASON_REJECT and REASON_CHANGE are permitted.
*& Fields always remain open after save — L5 can always re-edit.
*&---------------------------------------------------------------------*
FORM save_as_l5.

  DATA: ls_item    TYPE ty_items_tc,
        lv_count   TYPE i,
        lv_lock_ok TYPE flag.

  " Count marked rows
  LOOP AT gt_items_tc TRANSPORTING NO FIELDS WHERE mark = 'X'.
    ADD 1 TO lv_count.
  ENDLOOP.

  IF lv_count = 0.
    MESSAGE 'Please select at least one item to save' TYPE 'E'.
    RETURN.
  ENDIF.

*  " L5/L3 validation: marked rows must have reason_change or reason_reject filled
*  LOOP AT gt_items_tc INTO ls_item WHERE mark = 'X'.
*    IF ls_item-reason_change IS INITIAL AND ls_item-reason_reject IS INITIAL.
*      MESSAGE 'All selected items must have a Reason Change or Reason Reject before saving' TYPE 'E'.
*      RETURN.
*    ENDIF.
*  ENDLOOP.

  " Lock WO object before update
  PERFORM lock_wo_object CHANGING lv_lock_ok.
  IF lv_lock_ok <> 'X'.
    RETURN.
  ENDIF.

  " Ensure header row exists in ZTWOAPPRH — insert if missing
  DATA: ls_apprh_l5 TYPE ztwoapprh.
  SELECT SINGLE * FROM ztwoapprh INTO @ls_apprh_l5 WHERE aufnr = @gv_aufnr.
  IF sy-subrc <> 0.
    CLEAR ls_apprh_l5.
    ls_apprh_l5-aufnr        = gv_aufnr.
    ls_apprh_l5-appr_status  = gc_appr_status-submitted.
    ls_apprh_l5-changed_by   = sy-uname.
    ls_apprh_l5-changed_date = sy-datum.
    ls_apprh_l5-changed_time = sy-uzeit.
    INSERT ztwoapprh FROM ls_apprh_l5.
  ENDIF.

  " Update only marked rows — both reason fields saved as-is
  DATA: ls_appr_l5 TYPE ztwoappr.
  LOOP AT gt_items_tc ASSIGNING FIELD-SYMBOL(<ls_save_item>) WHERE mark = 'X'.
    UPDATE ztwoappr
      SET approval_lvl3  = <ls_save_item>-appr_flag
          reason_reject  = <ls_save_item>-reason_reject
          reason_change  = <ls_save_item>-reason_change
          changed_by     = sy-uname
          changed_date   = sy-datum
      WHERE aufnr     = gv_aufnr
        AND matnr     = <ls_save_item>-matnr
        AND change_id = <ls_save_item>-rspos.
    " If row does not exist yet, insert it
    IF sy-subrc <> 0.
      CLEAR ls_appr_l5.
      ls_appr_l5-aufnr         = gv_aufnr.
      ls_appr_l5-matnr         = <ls_save_item>-matnr.
      ls_appr_l5-change_id     = <ls_save_item>-rspos.
      ls_appr_l5-approval_lvl3 = <ls_save_item>-appr_flag.
      ls_appr_l5-reason_reject = <ls_save_item>-reason_reject.
      ls_appr_l5-reason_change = <ls_save_item>-reason_change.
      ls_appr_l5-changed_by    = sy-uname.
      ls_appr_l5-changed_date  = sy-datum.
      INSERT ztwoappr FROM ls_appr_l5.
    ENDIF.
    " If reason was cleared (reset), unlock the row immediately in memory
    IF <ls_save_item>-reason_change IS INITIAL AND <ls_save_item>-reason_reject IS INITIAL.
      <ls_save_item>-l3_approved = space.
    ENDIF.
  ENDLOOP.

  " Only set header to approved if at least one marked row has appr_flag set
  DATA: lv_has_approval TYPE flag.
  LOOP AT gt_items_tc INTO ls_item WHERE mark = 'X'.
    IF ls_item-appr_flag IS NOT INITIAL.
      lv_has_approval = 'X'.
      EXIT.
    ENDIF.
  ENDLOOP.

  IF lv_has_approval = 'X'.
    UPDATE ztwoapprh
      SET appr_status    = gc_appr_status-approved
          approved_by    = sy-uname
          approved_date  = sy-datum
          approved_time  = sy-uzeit
          changed_by     = sy-uname
          changed_date   = sy-datum
          changed_time   = sy-uzeit
      WHERE aufnr = gv_aufnr.
  ELSE.
    " Reset save: just record who cleared the data; keep current approval status
    UPDATE ztwoapprh
      SET changed_by   = sy-uname
          changed_date = sy-datum
          changed_time = sy-uzeit
      WHERE aufnr = gv_aufnr.
  ENDIF.

  COMMIT WORK AND WAIT.
  PERFORM unlock_wo_object.

  IF lv_has_approval = 'X'.
    MESSAGE s000(db) WITH 'Final approval saved. Use Send Email Tab to notify recipients.'.
  ELSE.
    MESSAGE s000(db) WITH 'Reason(s) saved. Awaiting final approval.'.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: unlock_wo
*& Release enqueue lock on ZTWOAPPRH (custom approval table) for gv_aufnr.
*&---------------------------------------------------------------------*
FORM unlock_wo.
  " Release enqueue lock only if held
  IF gv_locked = 'X' AND gv_aufnr IS NOT INITIAL.
    DATA: lv_aufnr_ul TYPE aufnr.
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = gv_aufnr
      IMPORTING
        output = lv_aufnr_ul.
    CALL FUNCTION 'CO_ZF_ORDER_DELOCK'
      EXPORTING
        aufnr  = lv_aufnr_ul
      EXCEPTIONS
        OTHERS = 1.
    CLEAR gv_locked.
  ENDIF.

  " Always reset screen
  CLEAR: gv_aufnr, gv_werks, gv_screen_locked.
  CLEAR: s_aufnr[], gs_items_tc.
  REFRESH gt_items_tc.
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: lock_wo_object
*& Lock WO object using CO_ZF_ORDER_LOCK_MULTI (exclusive mode).
*& cv_lock_ok = 'X' on success, space if WO locked by another user.
*&---------------------------------------------------------------------*
FORM lock_wo_object CHANGING cv_lock_ok TYPE flag.

  DATA: lt_enqueue    TYPE TABLE OF ordtyp_pre,
        lt_not_locked TYPE TABLE OF ord_pre,
        ls_caufv      TYPE caufv,
        ls_enqueue    TYPE ordtyp_pre,
        lv_aufnr      TYPE aufnr.

  cv_lock_ok = space.

  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
    EXPORTING
      input  = gv_aufnr
    IMPORTING
      output = lv_aufnr.

  SELECT SINGLE * FROM caufv INTO @ls_caufv WHERE aufnr = @lv_aufnr.
  IF sy-subrc <> 0.
    MESSAGE s000(db) WITH 'Work Order' gv_aufnr 'not found in system.' '' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  MOVE-CORRESPONDING ls_caufv TO ls_enqueue.
  IF ls_caufv-prueflos IS INITIAL.
    ls_enqueue-kein_prlos = 'X'.
  ENDIF.
  APPEND ls_enqueue TO lt_enqueue.

  CALL FUNCTION 'CO_ZF_ORDER_LOCK_MULTI'
    EXPORTING
      lock_mode   = 'E'
    TABLES
      enqueue_tab = lt_enqueue
      not_locked  = lt_not_locked.

  IF lt_not_locked IS INITIAL.
    cv_lock_ok = 'X'.
  ELSE.
    " Rollback: delock any WOs that were successfully locked before the failure
    LOOP AT lt_enqueue INTO ls_enqueue.
      READ TABLE lt_not_locked WITH KEY aufnr = ls_enqueue-aufnr TRANSPORTING NO FIELDS.
      IF sy-subrc <> 0.
        CALL FUNCTION 'CO_ZF_ORDER_DELOCK'
          EXPORTING
            aufnr  = ls_enqueue-aufnr
          EXCEPTIONS
            OTHERS = 1.
      ENDIF.
    ENDLOOP.
    " SAP standard lock-conflict message (same text shown when IW32 has the WO open)
    MESSAGE s802(alm_me) WITH 'Order' lv_aufnr 'is currently' 'being processed'.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: select_all_items
*& Mark all rows in the table control with mark='X' for bulk approval.
*&---------------------------------------------------------------------*
FORM select_all_items.
  LOOP AT gt_items_tc ASSIGNING FIELD-SYMBOL(<ls_item>).
    <ls_item>-mark = 'X'.
  ENDLOOP.
  MESSAGE 'All items selected' TYPE 'S'.
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: reset_reason
*& Clears reason fields on marked rows (all rows if none marked).
*& L1  -> clears reason_reject only
*& L4  -> clears reason_change only
*& L5  -> clears both reason_reject and reason_change
*&---------------------------------------------------------------------*
FORM reset_reason.

  DATA: lv_count     TYPE i,
        lv_processed TYPE i.

  IF gv_user_level IS INITIAL.
    PERFORM check_authorization.
  ENDIF.

  IF gv_user_level <> gc_user_lvl-l1
    AND gv_user_level <> gc_user_lvl-l4
    AND gv_user_level <> gc_user_lvl-l5.
    MESSAGE 'Reset Reason is not permitted for your user level' TYPE 'E'.
    RETURN.
  ENDIF.

  " Count marked rows
  LOOP AT gt_items_tc TRANSPORTING NO FIELDS WHERE mark = 'X'.
    ADD 1 TO lv_count.
  ENDLOOP.

  LOOP AT gt_items_tc ASSIGNING FIELD-SYMBOL(<ls_item>).
    " Process only marked rows; if none marked, process all
    IF lv_count > 0 AND <ls_item>-mark <> 'X'.
      CONTINUE.
    ENDIF.
    " Skip rows already fully approved by L1 => except L5 can always override
    IF <ls_item>-l1_approved = 'X' AND gv_user_level <> gc_user_lvl-l5.
      CONTINUE.
    ENDIF.

    CASE gv_user_level.
      WHEN gc_user_lvl-l1.
        CLEAR <ls_item>-reason_reject.
      WHEN gc_user_lvl-l4.
        CLEAR <ls_item>-reason_change.
      WHEN gc_user_lvl-l5.
        CLEAR: <ls_item>-reason_reject, <ls_item>-reason_change.
    ENDCASE.
    ADD 1 TO lv_processed.
  ENDLOOP.

  IF lv_processed = 0.
    MESSAGE 'No rows available to reset' TYPE 'S' DISPLAY LIKE 'W'.
  ELSE.
    MESSAGE lv_processed && ' row(s) reason cleared' TYPE 'S'.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: unlock_wo_object
*& Unlock WO object using CO_ZF_ORDER_DELOCK after commit.
*&---------------------------------------------------------------------*
FORM unlock_wo_object.
  DATA: lv_aufnr TYPE aufnr.

  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
    EXPORTING
      input  = gv_aufnr
    IMPORTING
      output = lv_aufnr.

  CALL FUNCTION 'CO_ZF_ORDER_DELOCK'
    EXPORTING
      aufnr  = lv_aufnr
    EXCEPTIONS
      OTHERS = 1.
ENDFORM.