*&---------------------------------------------------------------------*
*& Include  : LZFG_WO_APPROVALF07
*& Contains : ALV Free/Init FORMs for Screens 0310, 0320, 0330
*& Pattern  : Initialization Flag (ABAP_Free_Screen_Objects_Skills.md)
*&---------------------------------------------------------------------*

*----------------------------------------------------------------------*
* EVENT HANDLER IMPLEMENTATION — ALV double-click for Screen 0310
* (DEFINITION + DATA go_evt_0310 are in LZFG_WO_APPROVALTOP)
*----------------------------------------------------------------------*
CLASS lcl_alv_event_0310 IMPLEMENTATION.
  METHOD handle_dblclick_0310.
    DATA: ls_wo TYPE ztwoapprh.
    READ TABLE gt_pending_wo INTO ls_wo INDEX e_row-index.
    IF sy-subrc = 0.
      PERFORM open_selected_wo_pending USING ls_wo-aufnr.
    ENDIF.
  ENDMETHOD.
ENDCLASS.

*----------------------------------------------------------------------*
* SCREEN 0310 — PENDING APPROVAL LIST
*----------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*& FORM: free_alv_0310
*&---------------------------------------------------------------------*
FORM free_alv_0310.
  IF gr_alv_0310 IS BOUND.
    gr_alv_0310->free( ).
    CLEAR gr_alv_0310.
  ENDIF.
  IF gr_cont_0310 IS BOUND.
    gr_cont_0310->free( ).
    CLEAR gr_cont_0310.
  ENDIF.
  CLEAR: gt_fcat_0310, gs_layout_0310, gt_pending_wo.
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: build_fcat_0310
*&---------------------------------------------------------------------*
FORM build_fcat_0310.
  DATA ls_fcat TYPE lvc_s_fcat.
  CLEAR gt_fcat_0310.

  ls_fcat-fieldname = 'AUFNR'.      ls_fcat-coltext = 'Work Order'.
  ls_fcat-outputlen = 12.           APPEND ls_fcat TO gt_fcat_0310. CLEAR ls_fcat.

  ls_fcat-fieldname = 'WERKS'.      ls_fcat-coltext = 'Plant'.
  ls_fcat-outputlen = 6.            APPEND ls_fcat TO gt_fcat_0310. CLEAR ls_fcat.

  ls_fcat-fieldname = 'APPR_STATUS'. ls_fcat-coltext = 'Status'.
  ls_fcat-outputlen = 8.             APPEND ls_fcat TO gt_fcat_0310. CLEAR ls_fcat.

  ls_fcat-fieldname = 'APPROVED_BY'.   ls_fcat-coltext = 'Approved By'.
  ls_fcat-outputlen = 12.              APPEND ls_fcat TO gt_fcat_0310. CLEAR ls_fcat.

  ls_fcat-fieldname = 'APPROVED_DATE'. ls_fcat-coltext = 'Approved On'.
  ls_fcat-outputlen = 10.              APPEND ls_fcat TO gt_fcat_0310. CLEAR ls_fcat.

  ls_fcat-fieldname = 'CHANGED_BY'.   ls_fcat-coltext = 'Changed By'.
  ls_fcat-outputlen = 12.              APPEND ls_fcat TO gt_fcat_0310. CLEAR ls_fcat.

  ls_fcat-fieldname = 'CHANGED_DATE'. ls_fcat-coltext = 'Changed On'.
  ls_fcat-outputlen = 10.              APPEND ls_fcat TO gt_fcat_0310. CLEAR ls_fcat.
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: load_pending_wo_list                              (v1.7.1)
*& Load WOs into gt_pending_wo.
*& lr_plant: blank s_w310 = use r_swerk; typed s_w310 = use that.
*& r_swerk always applied as hard auth guard.
*&---------------------------------------------------------------------*
FORM load_pending_wo_list.
  DATA: lr_plant TYPE RANGE OF werks_d,
        ls_plant LIKE LINE OF lr_plant,
        ls_rw    LIKE LINE OF r_swerk,
        ls_sw    LIKE LINE OF s_w310.

  CLEAR gt_pending_wo.

  IF r_swerk IS INITIAL.
    MESSAGE 'No plant authorization. Cannot load data.' TYPE 'W'.
    RETURN.
  ENDIF.

  " Build effective plant range
  IF s_w310[] IS INITIAL.
    LOOP AT r_swerk INTO ls_rw.
      ls_plant-sign   = ls_rw-sign.
      ls_plant-option = ls_rw-option.
      ls_plant-low    = ls_rw-low.
      ls_plant-high   = ls_rw-high.
      APPEND ls_plant TO lr_plant.
    ENDLOOP.
  ELSE.
    LOOP AT s_w310 INTO ls_sw.
      ls_plant-sign   = ls_sw-sign.
      ls_plant-option = ls_sw-option.
      ls_plant-low    = ls_sw-low.
      ls_plant-high   = ls_sw-high.
      APPEND ls_plant TO lr_plant.
    ENDLOOP.
  ENDIF.

  CASE gv_user_level.
    WHEN gc_user_lvl-l1.
      " L1 sees submitted WOs pending approval
      SELECT * FROM ztwoapprh
        INTO TABLE @gt_pending_wo
        WHERE appr_status = @gc_appr_status-submitted
          AND werks      IN @lr_plant
          AND werks      IN @r_swerk
          AND aufnr      IN @s_a310.
    WHEN gc_user_lvl-l3 OR gc_user_lvl-l4 OR gc_user_lvl-l5.
      " L3/L4/L5 see all non-final WOs
      SELECT * FROM ztwoapprh
        INTO TABLE @gt_pending_wo
        WHERE appr_status <> @gc_appr_status-approved
          AND werks       IN @lr_plant
          AND werks       IN @r_swerk
          AND aufnr       IN @s_a310.
  ENDCASE.
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: init_alv_0310
*&---------------------------------------------------------------------*
FORM init_alv_0310.
  PERFORM build_fcat_0310.
  PERFORM load_pending_wo_list.

  gs_layout_0310-zebra      = abap_true.
  gs_layout_0310-cwidth_opt = abap_true.
  gs_layout_0310-sel_mode   = 'A'.

  CREATE OBJECT gr_cont_0310
    EXPORTING
      container_name = 'CC_ALV_0310'.

  CREATE OBJECT gr_alv_0310
    EXPORTING
      i_parent = gr_cont_0310.

  CREATE OBJECT go_evt_0310.
  SET HANDLER go_evt_0310->handle_dblclick_0310 FOR gr_alv_0310.

  gr_alv_0310->set_table_for_first_display(
    EXPORTING
      is_layout       = gs_layout_0310
      i_default       = abap_true
      i_save          = 'A'
    CHANGING
      it_fieldcatalog = gt_fcat_0310
      it_outtab       = gt_pending_wo ).
ENDFORM.


*----------------------------------------------------------------------*
* SCREEN 0320 — APPROVAL HISTORY
*======================================================================*
* SCREEN 0320 — APPROVAL HISTORY  (v1.6 — Plant default + filter)
*======================================================================*

*&---------------------------------------------------------------------*
*& FORM: free_alv_0320
*&---------------------------------------------------------------------*
FORM free_alv_0320.
  IF gr_alv_0320 IS BOUND.
    gr_alv_0320->free( ).
    CLEAR gr_alv_0320.
  ENDIF.
  IF gr_cont_0320 IS BOUND.
    gr_cont_0320->free( ).
    CLEAR gr_cont_0320.
  ENDIF.
  CLEAR: gt_fcat_0320, gs_layout_0320, gt_appr_history.
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: default_filter_0320
*& Pre-fill s_w320 with r_swerk so the ALV opens scoped to the
*& current user's authorized plants. User can override the range
*& on screen and press FILTER.
*&---------------------------------------------------------------------*
FORM default_filter_0320.
  DATA ls_w LIKE LINE OF s_w320.

  IF s_w320[] IS NOT INITIAL.
    RETURN.   " User has typed something — respect it.
  ENDIF.

  LOOP AT r_swerk INTO DATA(ls_r).
    CHECK ls_r-low <> '0001'.  " v1.7.3: skip HO admin plant — ls_r is loop source, not ls_w
    CLEAR ls_w.
    ls_w-sign   = ls_r-sign.
    ls_w-option = ls_r-option.
    ls_w-low    = ls_r-low.
    ls_w-high   = ls_r-high.
    APPEND ls_w TO s_w320.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: build_fcat_0320
*& Same field catalog as v1.5 — read-only history.
*&---------------------------------------------------------------------*
FORM build_fcat_0320.
  DATA ls_fcat TYPE lvc_s_fcat.
  CLEAR gt_fcat_0320.

  ls_fcat-fieldname = 'AUFNR'.          ls_fcat-coltext = 'Work Order'.
  ls_fcat-outputlen = 12.               APPEND ls_fcat TO gt_fcat_0320. CLEAR ls_fcat.

  ls_fcat-fieldname = 'WERKS'.          ls_fcat-coltext = 'Plant'.
  ls_fcat-outputlen = 6.                APPEND ls_fcat TO gt_fcat_0320. CLEAR ls_fcat.

  ls_fcat-fieldname = 'MATNR'.          ls_fcat-coltext = 'Material'.
  ls_fcat-outputlen = 18.               APPEND ls_fcat TO gt_fcat_0320. CLEAR ls_fcat.

  ls_fcat-fieldname = 'CHANGE_ID'.      ls_fcat-coltext = 'Change ID'.
  ls_fcat-outputlen = 20.               APPEND ls_fcat TO gt_fcat_0320. CLEAR ls_fcat.

  ls_fcat-fieldname = 'REASON_CHANGE'.  ls_fcat-coltext = 'Reason Change'.
  ls_fcat-outputlen = 40.               APPEND ls_fcat TO gt_fcat_0320. CLEAR ls_fcat.

  ls_fcat-fieldname = 'REASON_REJECT'.  ls_fcat-coltext = 'Reason Reject'.
  ls_fcat-outputlen = 40.               APPEND ls_fcat TO gt_fcat_0320. CLEAR ls_fcat.

  ls_fcat-fieldname = 'APPROVAL_STAT'.  ls_fcat-coltext = 'Approval Status'.
  ls_fcat-outputlen = 14.               APPEND ls_fcat TO gt_fcat_0320. CLEAR ls_fcat.

  ls_fcat-fieldname = 'APPROVAL_LVL1'.  ls_fcat-coltext = 'L1 Approved'.
  ls_fcat-checkbox  = abap_true.
  ls_fcat-outputlen = 8.                APPEND ls_fcat TO gt_fcat_0320. CLEAR ls_fcat.

  ls_fcat-fieldname = 'APPROVAL_LVL3'.  ls_fcat-coltext = 'L3 Approved'.
  ls_fcat-checkbox  = abap_true.
  ls_fcat-outputlen = 8.                APPEND ls_fcat TO gt_fcat_0320. CLEAR ls_fcat.

  ls_fcat-fieldname = 'APPR_BY_LVL1'.   ls_fcat-coltext = 'Appr By L1'.
  ls_fcat-outputlen = 12.               APPEND ls_fcat TO gt_fcat_0320. CLEAR ls_fcat.

  ls_fcat-fieldname = 'APPR_DATE_LVL1'. ls_fcat-coltext = 'Appr Date L1'.
  ls_fcat-outputlen = 10.               APPEND ls_fcat TO gt_fcat_0320. CLEAR ls_fcat.

  ls_fcat-fieldname = 'APPR_BY_LVL3'.   ls_fcat-coltext = 'Appr By L3'.
  ls_fcat-outputlen = 12.               APPEND ls_fcat TO gt_fcat_0320. CLEAR ls_fcat.

  ls_fcat-fieldname = 'APPR_DATE_LVL3'. ls_fcat-coltext = 'Appr Date L3'.
  ls_fcat-outputlen = 10.               APPEND ls_fcat TO gt_fcat_0320. CLEAR ls_fcat.
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: load_appr_history
*& Load ZTWOAPPR rows into gt_appr_history. Joins WERKS from ZTWOAPPRH.
*& Filters: s_a320 (WO range), s_w320 (Plant range), r_swerk (auth).
*&---------------------------------------------------------------------*
FORM load_appr_history.
  DATA: lt_raw TYPE STANDARD TABLE OF ztwoappr,
        lt_hdr TYPE STANDARD TABLE OF ztwoapprh,
        ls_out TYPE ty_appr_history.

  CLEAR gt_appr_history.

  IF r_swerk IS INITIAL.
    MESSAGE 'No plant authorization. Cannot load data.' TYPE 'W'.
    RETURN.
  ENDIF.

  " Step 1: Build effective plant range
  " If user typed a plant in s_w320, use it. Otherwise use r_swerk.
  DATA: lt_plant TYPE RANGE OF werks_d,
        ls_plant LIKE LINE OF lt_plant,
        ls_rw    LIKE LINE OF r_swerk,
        ls_sw    LIKE LINE OF s_w320.

  IF s_w320[] IS NOT INITIAL.
    LOOP AT s_w320 INTO ls_sw.
      ls_plant-sign   = ls_sw-sign.
      ls_plant-option = ls_sw-option.
      ls_plant-low    = ls_sw-low.
      ls_plant-high   = ls_sw-high.
      APPEND ls_plant TO lt_plant.
    ENDLOOP.
  ELSE.
    LOOP AT r_swerk INTO ls_rw.
      ls_plant-sign   = ls_rw-sign.
      ls_plant-option = ls_rw-option.
      ls_plant-low    = ls_rw-low.
      ls_plant-high   = ls_rw-high.
      APPEND ls_plant TO lt_plant.
    ENDLOOP.
  ENDIF.

  " Step 2: Get authorized WO headers matching plant and WO range
  SELECT aufnr, werks
    FROM ztwoapprh
    INTO CORRESPONDING FIELDS OF TABLE @lt_hdr
    WHERE aufnr IN @s_a320
      AND werks IN @lt_plant
      AND werks IN @r_swerk.

  IF lt_hdr IS INITIAL.
    RETURN.
  ENDIF.

  " Step 2: Get component rows for those WOs
  SELECT * FROM ztwoappr
    INTO TABLE @lt_raw
    FOR ALL ENTRIES IN @lt_hdr
    WHERE aufnr = @lt_hdr-aufnr.

  SORT lt_raw BY aufnr matnr.           " ORDER BY not allowed with FAE

  " Step 3: Merge WERKS into output rows
  LOOP AT lt_raw INTO DATA(ls_raw).
    CLEAR ls_out.
    MOVE-CORRESPONDING ls_raw TO ls_out.
    READ TABLE lt_hdr INTO DATA(ls_hdr) WITH KEY aufnr = ls_raw-aufnr.
    IF sy-subrc = 0.
      ls_out-werks = ls_hdr-werks.    " Populate Plant from header
    ENDIF.
    APPEND ls_out TO gt_appr_history.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: init_alv_0320                                    (v1.7)
*& Create ALV container and pre-load history data scoped to the user's
*& authorized plants (s_w320 pre-filled from r_swerk by default_filter_0320).
*& User can narrow the filter and press FILTER to reload.
*&---------------------------------------------------------------------*
FORM init_alv_0320.
  PERFORM build_fcat_0320.
  PERFORM load_appr_history.        " Pre-load history

  gs_layout_0320-zebra      = abap_true.
  gs_layout_0320-cwidth_opt = abap_true.
  gs_layout_0320-no_toolbar = space.        " ALV toolbar shown — read-only

  CREATE OBJECT gr_cont_0320
    EXPORTING
      container_name = 'CC_ALV_0320'.

  CREATE OBJECT gr_alv_0320
    EXPORTING
      i_parent = gr_cont_0320.

  gr_alv_0320->set_table_for_first_display(
    EXPORTING
      is_layout       = gs_layout_0320
      i_default       = abap_true
      i_save          = 'A'
    CHANGING
      it_fieldcatalog = gt_fcat_0320
      it_outtab       = gt_appr_history ).
ENDFORM.


*======================================================================*
* SCREEN 0330 — MANUAL EMAIL SEND  (v1.6 — Plant default + selectable ALV)
*======================================================================*

*&---------------------------------------------------------------------*
*& FORM: free_alv_0330
*&---------------------------------------------------------------------*
FORM free_alv_0330.
  IF gr_alv_0330 IS BOUND.
    gr_alv_0330->free( ).
    CLEAR gr_alv_0330.
  ENDIF.
  IF gr_cont_0330 IS BOUND.
    gr_cont_0330->free( ).
    CLEAR gr_cont_0330.
  ENDIF.
  CLEAR: gt_fcat_0330, gs_layout_0330, gt_appr_ready, gv_send_mode.
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: default_filter_0330
*& Same idea as default_filter_0320 — pre-fill plant range from r_swerk.
*&---------------------------------------------------------------------*
FORM default_filter_0330.
  DATA ls_w LIKE LINE OF s_w330.

  IF s_w330[] IS NOT INITIAL.
    RETURN.
  ENDIF.

  LOOP AT r_swerk INTO DATA(ls_r).
    CHECK ls_r-low <> '0001'.  " v1.7.3: skip HO admin plant — ls_r is loop source, not ls_w
    CLEAR ls_w.
    ls_w-sign   = ls_r-sign.
    ls_w-option = ls_r-option.
    ls_w-low    = ls_r-low.
    ls_w-high   = ls_r-high.
    APPEND ls_w TO s_w330.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: resolve_send_mode
*& Maps user level to default send direction for Screen 0330:
*&   L1 (BCSPPD HO) -> 'BR'  HO sends approval result  to Branch
*&   L4 (Branch)    -> 'HO'  Branch sends review request to HO
*&   L5 (Helpdesk)  -> ' '   L5 bypasses this; USER_COMMAND_0330 sends both
*&   L3 (SDH)       -> ' '   no send permission
*&---------------------------------------------------------------------*
FORM resolve_send_mode.
  CLEAR gv_send_mode.
   CASE gv_user_level.
    WHEN gc_user_lvl-l4.   
      gv_send_mode = gc_send_mode-ho.
    WHEN gc_user_lvl-l1.   
      gv_send_mode = gc_send_mode-br.
    WHEN OTHERS.           
      CLEAR gv_send_mode.
  ENDCASE.
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: build_fcat_0330
*&---------------------------------------------------------------------*
FORM build_fcat_0330.
  DATA ls_fcat TYPE lvc_s_fcat.
  CLEAR gt_fcat_0330.

   " v1.7.2: MARK — only editable column
  ls_fcat-fieldname = 'MARK'.        ls_fcat-coltext = 'Send'.
  ls_fcat-checkbox  = abap_true.     ls_fcat-edit    = abap_true.
  ls_fcat-outputlen = 5.             APPEND ls_fcat TO gt_fcat_0330. CLEAR ls_fcat.

  " v1.7.2: All other columns — explicitly read-only
  ls_fcat-fieldname = 'AUFNR'.       ls_fcat-coltext = 'Work Order'.
  ls_fcat-edit      = abap_false.    ls_fcat-outputlen = 12.
  APPEND ls_fcat TO gt_fcat_0330. CLEAR ls_fcat.

  ls_fcat-fieldname = 'WERKS'.       ls_fcat-coltext = 'Plant'.
  ls_fcat-edit      = abap_false.    ls_fcat-outputlen = 6.
  APPEND ls_fcat TO gt_fcat_0330. CLEAR ls_fcat.

  ls_fcat-fieldname = 'APPR_STATUS'. ls_fcat-coltext = 'Hdr Status'.
  ls_fcat-edit      = abap_false.    ls_fcat-outputlen = 8.
  APPEND ls_fcat TO gt_fcat_0330. CLEAR ls_fcat.

  ls_fcat-fieldname = 'TOTAL_CMP'.   ls_fcat-coltext = 'Total Comp'.
  ls_fcat-edit      = abap_false.    ls_fcat-outputlen = 6.
  APPEND ls_fcat TO gt_fcat_0330. CLEAR ls_fcat.

  ls_fcat-fieldname = 'APPR_CMP'.    ls_fcat-coltext = 'Approved'.
  ls_fcat-edit      = abap_false.    ls_fcat-outputlen = 6.
  APPEND ls_fcat TO gt_fcat_0330. CLEAR ls_fcat.

  ls_fcat-fieldname = 'REJT_CMP'.    ls_fcat-coltext = 'Rejected'.
  ls_fcat-edit      = abap_false.    ls_fcat-outputlen = 6.
  APPEND ls_fcat TO gt_fcat_0330. CLEAR ls_fcat.

  ls_fcat-fieldname = 'PEND_CMP'.    ls_fcat-coltext = 'Pending'.
  ls_fcat-edit      = abap_false.    ls_fcat-outputlen = 6.
  APPEND ls_fcat TO gt_fcat_0330. CLEAR ls_fcat.

  ls_fcat-fieldname = 'CHANGED_BY'.  ls_fcat-coltext = 'Changed By'.
  ls_fcat-edit      = abap_false.    ls_fcat-outputlen = 12.
  APPEND ls_fcat TO gt_fcat_0330. CLEAR ls_fcat.

  ls_fcat-fieldname = 'CHANGED_ON'.  ls_fcat-coltext = 'Changed On'.
  ls_fcat-edit      = abap_false.    ls_fcat-outputlen = 10.
  APPEND ls_fcat TO gt_fcat_0330. CLEAR ls_fcat.
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: load_appr_ready_list
*& Materializes one row per WO header that already has component-level
*& approval activity (header status submitted or fully approved). The
*& counts come from ZTWOAPPR. Filtered by SS_330 ranges + r_swerk.
*&---------------------------------------------------------------------*
FORM load_appr_ready_list.

  CLEAR gt_appr_ready.

  DATA: lt_hdr TYPE STANDARD TABLE OF ztwoapprh.

  SELECT * FROM ztwoapprh
    INTO TABLE @lt_hdr
    WHERE aufnr IN @s_a330
      AND werks IN @s_w330
      AND werks IN @r_swerk
      AND appr_status IN ( @gc_appr_status-submitted, @gc_appr_status-approved ).

  IF lt_hdr IS INITIAL.
    RETURN.
  ENDIF.

  " Pull component rows in one shot
  DATA: lt_cmp TYPE STANDARD TABLE OF ztwoappr.
  SELECT * FROM ztwoappr
    INTO TABLE @lt_cmp
    FOR ALL ENTRIES IN @lt_hdr
    WHERE aufnr = @lt_hdr-aufnr.

  LOOP AT lt_hdr INTO DATA(ls_hdr).
    CLEAR gs_appr_ready.
    gs_appr_ready-aufnr       = ls_hdr-aufnr.
    gs_appr_ready-werks       = ls_hdr-werks.
    gs_appr_ready-appr_status = ls_hdr-appr_status.
    gs_appr_ready-changed_by  = ls_hdr-changed_by.
    gs_appr_ready-changed_on  = ls_hdr-changed_date.

    LOOP AT lt_cmp INTO DATA(ls_cmp) WHERE aufnr = ls_hdr-aufnr.
      gs_appr_ready-total_cmp = gs_appr_ready-total_cmp + 1.
      IF ls_cmp-appr_valid = 'X'.
        gs_appr_ready-appr_cmp = gs_appr_ready-appr_cmp + 1.
      ELSEIF ls_cmp-approval_stat = 'Reject Approval'.
        gs_appr_ready-rejt_cmp = gs_appr_ready-rejt_cmp + 1.
      ELSE.
        gs_appr_ready-pend_cmp = gs_appr_ready-pend_cmp + 1.
      ENDIF.
    ENDLOOP.

    APPEND gs_appr_ready TO gt_appr_ready.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: init_alv_0330
*&---------------------------------------------------------------------*
FORM init_alv_0330.
  PERFORM build_fcat_0330.
  PERFORM load_appr_ready_list.    " v1.6 — open the ALV pre-loaded

  gs_layout_0330-zebra      = abap_true.
  gs_layout_0330-cwidth_opt = abap_true.
  gs_layout_0330-edit       = abap_false.  " v1.7.2: display-only; MARK col editable via fcat

  CREATE OBJECT gr_cont_0330
    EXPORTING
      container_name = 'CC_ALV_0330'.

  CREATE OBJECT gr_alv_0330
    EXPORTING
      i_parent = gr_cont_0330.

  gr_alv_0330->set_table_for_first_display(
    EXPORTING
      is_layout       = gs_layout_0330
      i_default       = abap_true
      i_save          = 'A'
    CHANGING
      it_fieldcatalog = gt_fcat_0330
      it_outtab       = gt_appr_ready ).
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: refresh_alv_0330
*&---------------------------------------------------------------------*
FORM refresh_alv_0330.
  IF gr_alv_0330 IS BOUND.
    " Force the grid to commit any in-place edits before we re-paint
    gr_alv_0330->check_changed_data( ).
    gr_alv_0330->refresh_table_display( ).
  ENDIF.
ENDFORM.


*======================================================================*
* SCREEN 0310 — TREE SECTION (CL_GUI_LIST_TREE — Pending WO Filter)
*======================================================================*

*----------------------------------------------------------------------*
* EVENT HANDLER IMPLEMENTATION — tree node/item click for Screen 0310
* (DEFINITION + DATA are in LZFG_WO_APPROVALTOP)
*----------------------------------------------------------------------*
CLASS lcl_tree_event_0310 IMPLEMENTATION.

  METHOD handle_node_dblclick_0310.
    gv_tree_selected_key = node_key.
    PERFORM filter_alv_0310_by_tree.
  ENDMETHOD.

  METHOD handle_item_dblclick_0310.
    gv_tree_selected_key = node_key.
    PERFORM filter_alv_0310_by_tree.
  ENDMETHOD.

ENDCLASS.

*&---------------------------------------------------------------------*
*& FORM: free_tree_0310
*& Destroys the tree container and hosted tree control.
*& Called on BACK/EXIT and before re-initialisation on re-entry.
*& Does NOT touch ALV objects or gt_pending_wo.
*&---------------------------------------------------------------------*
FORM free_tree_0310.
  IF gr_tree_0310 IS BOUND.
    gr_tree_0310->free( ).
    CLEAR gr_tree_0310.
  ENDIF.
  IF gr_tree_cont_0310 IS BOUND.
    gr_tree_cont_0310->free( ).
    CLEAR gr_tree_cont_0310.
  ENDIF.
  CLEAR: go_tree_evt_0310, gv_tree_selected_key, gt_pending_tree, gt_tree_keys.
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: auto_load_0310                                    (v1.7.1)
*& Auto-load tree + ALV from r_swerk. s_w310/s_a310 left blank.
*& If user fills s_w310/s_a310 and presses Execute, those values
*& act as narrowing filters (intersected with r_swerk).
*&---------------------------------------------------------------------*
FORM auto_load_0310.
  IF r_swerk IS INITIAL.
    MESSAGE 'No plant authorization. Contact system administrator.' TYPE 'W'.
    RETURN.
  ENDIF.
  " s_w310 / s_a310 intentionally left blank — load_pending_wo_list
  " treats blank s_w310 as "use r_swerk only".
  PERFORM load_pending_wo_list.
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: load_pending_tree_0310                              (v1.7.1)
*& Loads ZTWOAPPRH rows into gt_pending_tree (APPR_STATUS submitted).
*& Date window: REQUESTED_DATE >= SY-DATUM - 7.
*& lr_plant: blank s_w310 = use r_swerk; typed s_w310 = use that.
*&---------------------------------------------------------------------*
FORM load_pending_tree_0310.
  DATA: lv_week_start TYPE d,
        lr_plant      TYPE RANGE OF werks_d,
        ls_plant      LIKE LINE OF lr_plant,
        ls_rw         LIKE LINE OF r_swerk,
        ls_sw         LIKE LINE OF s_w310.

  lv_week_start = sy-datum - 7.

  CLEAR gt_pending_tree.

  IF r_swerk IS INITIAL.
    MESSAGE 'No plant authorization. Cannot load tree.' TYPE 'W'.
    RETURN.
  ENDIF.

  " Build effective plant range
  IF s_w310[] IS INITIAL.
    LOOP AT r_swerk INTO ls_rw.
      ls_plant-sign   = ls_rw-sign.
      ls_plant-option = ls_rw-option.
      ls_plant-low    = ls_rw-low.
      ls_plant-high   = ls_rw-high.
      APPEND ls_plant TO lr_plant.
    ENDLOOP.
  ELSE.
    LOOP AT s_w310 INTO ls_sw.
      ls_plant-sign   = ls_sw-sign.
      ls_plant-option = ls_sw-option.
      ls_plant-low    = ls_sw-low.
      ls_plant-high   = ls_sw-high.
      APPEND ls_plant TO lr_plant.
    ENDLOOP.
  ENDIF.

  SELECT * FROM ztwoapprh
    INTO TABLE @gt_pending_tree
    WHERE appr_status    = @gc_appr_status-submitted
      AND requested_date >= @lv_week_start
      AND werks          IN @lr_plant
      AND werks          IN @r_swerk     " Hard authorization filter
      AND aufnr          IN @s_a310.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: build_tree_nodes_0310
*& Builds the node and item tables from gt_pending_tree.
*&
*& Tree structure:
*&   PEND_ROOT  "Pending Approval WO"
*&     MONTHLY  "Monthly (YYYY-MM)"   — REQUESTED_DATE >= 1st of current month
*&       M_<AUFNR>  leaf per WO
*&     WEEKLY   "Weekly (from YYYY-MM-DD)" — REQUESTED_DATE >= SY-DATUM - 7
*&       W_<AUFNR>  leaf per WO
*&
*& A WO appearing in both windows gets a leaf in both folders.
*& Node key rule: prefix M_ or W_ + AUFNR (max 12 chars = 14 total,
*& within the TV_NODEKEY 20-char limit).
*&---------------------------------------------------------------------*
FORM build_tree_nodes_0310
  USING
    node_table TYPE treev_ntab
    item_table TYPE item_table_0310_type.

  DATA: ls_node        TYPE treev_node,
        ls_item        TYPE mtreeitm,
        lv_node_key    TYPE tv_nodekey,
        lv_counter     TYPE i,          " Counter for unique node keys
        lv_counter_c   TYPE n LENGTH 9, " 9-digit counter for unique node keys
        lv_month_start TYPE d,
        lv_week_start  TYPE d,
        lv_label       TYPE char60,
        lv_aufnr_disp  TYPE char12.

  lv_month_start      = sy-datum.
  lv_month_start+6(2) = '01'.
  lv_week_start       = sy-datum - 7.

  CLEAR: gt_tree_keys, lv_counter. " Reset counters

  " ── Root ──────────────────────────────────────────────────────────
  CLEAR ls_node.
  ls_node-node_key = gc_tree_0310-root.
  ls_node-isfolder = 'X'.
  CLEAR: ls_node-relatkey, ls_node-relatship.
  APPEND ls_node TO node_table.

  CLEAR ls_item.
  ls_item-node_key  = gc_tree_0310-root.
  ls_item-item_name = '1'.
  ls_item-class     = cl_gui_list_tree=>item_class_text.
  ls_item-alignment = cl_gui_list_tree=>align_auto.
  ls_item-font      = cl_gui_list_tree=>item_font_prop.
  ls_item-text      = 'Pending Approval WO'.
  APPEND ls_item TO item_table.

  " ── MONTHLY folder ────────────────────────────────────────────────
  CLEAR ls_node.
  ls_node-node_key  = gc_tree_0310-monthly.
  ls_node-relatkey  = gc_tree_0310-root.
  ls_node-relatship = cl_gui_list_tree=>relat_last_child.
  ls_node-isfolder  = 'X'.
  APPEND ls_node TO node_table.

  CLEAR ls_item.
  ls_item-node_key  = gc_tree_0310-monthly.
  ls_item-item_name = '1'.
  ls_item-class     = cl_gui_list_tree=>item_class_text.
  ls_item-alignment = cl_gui_list_tree=>align_auto.
  ls_item-font      = cl_gui_list_tree=>item_font_prop.
  lv_label = 'Monthly (' && sy-datum(4) && '-' && sy-datum+4(2) && ')'.
  ls_item-text = lv_label.
  APPEND ls_item TO item_table.

  " Monthly leaf nodes
  LOOP AT gt_pending_tree INTO DATA(ls_wo).
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = ls_wo-aufnr
      IMPORTING
        output = ls_wo-aufnr.
    CHECK ls_wo-requested_date >= lv_month_start.

    lv_counter   = lv_counter + 1.
    lv_counter_c = lv_counter.
    CONCATENATE 'N' lv_counter_c INTO lv_node_key.

    CLEAR ls_tree_key.
    ls_tree_key-node_key = lv_node_key.
    ls_tree_key-aufnr    = ls_wo-aufnr.
    APPEND ls_tree_key TO gt_tree_keys.

    CLEAR ls_node.
    ls_node-node_key  = lv_node_key.
    ls_node-relatkey  = gc_tree_0310-monthly.
    ls_node-relatship = cl_gui_list_tree=>relat_last_child.
    APPEND ls_node TO node_table.

    CLEAR ls_item.
    ls_item-node_key  = lv_node_key.
    ls_item-item_name = '1'.
    ls_item-class     = cl_gui_list_tree=>item_class_text.
    ls_item-alignment = cl_gui_list_tree=>align_auto.
    ls_item-font      = cl_gui_list_tree=>item_font_prop.
    " Format AUFNR for display (remove leading zeros)
    lv_aufnr_disp = ls_wo-aufnr.
    SHIFT lv_aufnr_disp LEFT DELETING LEADING '0'.
    CONCATENATE lv_aufnr_disp '  ' ls_wo-werks INTO ls_item-text.
    APPEND ls_item TO item_table.
  ENDLOOP.

  " ── WEEKLY folder ─────────────────────────────────────────────────
  CLEAR ls_node.
  ls_node-node_key  = gc_tree_0310-weekly.
  ls_node-relatkey  = gc_tree_0310-root.
  ls_node-relatship = cl_gui_list_tree=>relat_last_child.
  ls_node-isfolder  = 'X'.
  APPEND ls_node TO node_table.

  CLEAR ls_item.
  ls_item-node_key  = gc_tree_0310-weekly.
  ls_item-item_name = '1'.
  ls_item-class     = cl_gui_list_tree=>item_class_text.
  ls_item-alignment = cl_gui_list_tree=>align_auto.
  ls_item-font      = cl_gui_list_tree=>item_font_prop.
  lv_label = 'Weekly (From : ' && lv_week_start(4) && '-'
                             && lv_week_start+4(2) && '-'
                             && lv_week_start+6(2) && ')'.
  ls_item-text = lv_label.
  APPEND ls_item TO item_table.

  " Weekly leaf nodes — counter continues from monthly, no reset
  LOOP AT gt_pending_tree INTO ls_wo.
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = ls_wo-aufnr
      IMPORTING
        output = ls_wo-aufnr.
    CHECK ls_wo-requested_date >= lv_week_start.

    lv_counter   = lv_counter + 1.
    lv_counter_c = lv_counter.
    CONCATENATE 'N' lv_counter_c INTO lv_node_key.

    CLEAR ls_tree_key.
    ls_tree_key-node_key = lv_node_key.
    ls_tree_key-aufnr    = ls_wo-aufnr.
    APPEND ls_tree_key TO gt_tree_keys.

    CLEAR ls_node.
    ls_node-node_key  = lv_node_key.
    ls_node-relatkey  = gc_tree_0310-weekly.
    ls_node-relatship = cl_gui_list_tree=>relat_last_child.
    APPEND ls_node TO node_table.

    CLEAR ls_item.
    ls_item-node_key  = lv_node_key.
    ls_item-item_name = '1'.
    ls_item-class     = cl_gui_list_tree=>item_class_text.
    ls_item-alignment = cl_gui_list_tree=>align_auto.
    ls_item-font      = cl_gui_list_tree=>item_font_prop.
    lv_aufnr_disp = ls_wo-aufnr.
    SHIFT lv_aufnr_disp LEFT DELETING LEADING '0'.
    CONCATENATE lv_aufnr_disp '  ' ls_wo-werks INTO ls_item-text.
    APPEND ls_item TO item_table.
  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: init_tree_0310
*& Creates CC_TREE_0310 container and CL_GUI_LIST_TREE on Screen 0310.
*& Call AFTER init_alv_0310 so the ALV container already exists.
*&---------------------------------------------------------------------*
FORM init_tree_0310.
  DATA: node_table TYPE treev_ntab,
        item_table TYPE item_table_0310_type,
        events     TYPE cntl_simple_events,
        ls_event   TYPE cntl_simple_event.

  " Load pending WOs for tree buckets
  PERFORM load_pending_tree_0310.

  " Create the custom container on the screen
  CREATE OBJECT gr_tree_cont_0310
    EXPORTING
      container_name              = 'CC_TREE_0310'
    EXCEPTIONS
      cntl_error                  = 1
      cntl_system_error           = 2
      create_error                = 3
      lifetime_error              = 4
      lifetime_dynpro_dynpro_link = 5.
  IF sy-subrc <> 0.
    MESSAGE 'Cannot create tree container CC_TREE_0310' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  " Create list tree — single-selection, item selection on, no column headers
  CREATE OBJECT gr_tree_0310
    EXPORTING
      parent                      = gr_tree_cont_0310
      node_selection_mode         = cl_gui_list_tree=>node_sel_mode_single
      item_selection              = 'X'
      with_headers                = ' '
    EXCEPTIONS
      cntl_system_error           = 1
      create_error                = 2
      failed                      = 3
      illegal_node_selection_mode = 4
      lifetime_error              = 5.
  IF sy-subrc <> 0.
    MESSAGE 'Cannot create list tree for Screen 0310' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  " Register node_double_click and item_double_click as application events
  " APPL_EVENT = 'X' routes the event through PAI where DISPATCH handles it
  ls_event-eventid    = cl_gui_list_tree=>eventid_node_double_click.
  ls_event-appl_event = 'X'.
  APPEND ls_event TO events.

  ls_event-eventid    = cl_gui_list_tree=>eventid_item_double_click.
  ls_event-appl_event = 'X'.
  APPEND ls_event TO events.

  CALL METHOD gr_tree_0310->set_registered_events
    EXPORTING
      events                    = events
    EXCEPTIONS
      cntl_error                = 1
      cntl_system_error         = 2
      illegal_event_combination = 3.
  IF sy-subrc <> 0.
    MESSAGE 'Cannot register tree events for Screen 0310' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  " Wire event handler methods
  CREATE OBJECT go_tree_evt_0310.
  SET HANDLER go_tree_evt_0310->handle_node_dblclick_0310 FOR gr_tree_0310.
  SET HANDLER go_tree_evt_0310->handle_item_dblclick_0310 FOR gr_tree_0310.

  " Build node/item data and insert into tree
  PERFORM build_tree_nodes_0310 USING node_table item_table.

  CALL METHOD gr_tree_0310->add_nodes_and_items
    EXPORTING
      node_table                     = node_table
      item_table                     = item_table
      item_table_structure_name      = 'MTREEITM'
    EXCEPTIONS
      failed                         = 1
      cntl_system_error              = 3
      error_in_tables                = 4
      dp_error                       = 5
      table_structure_name_not_found = 6.
  IF sy-subrc <> 0.
    MESSAGE 'Cannot insert nodes into tree for Screen 0310' TYPE 'S' DISPLAY LIKE 'E'.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: rebuild_tree_0310
*& Called when the user presses Execute (EXEC_310) in subscreen 0311.
*& Frees the existing tree, reloads data with the current plant/werks
*& filter values, and recreates the tree from scratch.
*&---------------------------------------------------------------------*
FORM rebuild_tree_0310.
  PERFORM free_tree_0310.
  PERFORM init_tree_0310.
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM: filter_alv_0310_by_tree
*& Called by the event handler after a tree node is double-clicked.
*& Filters gt_pending_wo (the ALV data table for Screen 0310) to the
*& WOs matching the selected node, then refreshes the ALV display.
*&
*& Node key mapping:
*&   PEND_ROOT  — reset ALV to full gt_pending_tree
*&   MONTHLY    — ALV shows WOs from current calendar month
*&   WEEKLY     — ALV shows WOs from last 7 days
*&   M_<AUFNR>  — ALV shows that single WO (monthly context)
*&   W_<AUFNR>  — ALV shows that single WO (weekly context)
*&
*& gt_pending_wo is the internal table passed to the ALV via
*& set_table_for_first_display in init_alv_0310. Writing to it and
*& calling refresh_table_display is the correct update pattern —
*& do NOT call set_table_for_first_display again.
*&---------------------------------------------------------------------*
FORM filter_alv_0310_by_tree.
  DATA: lt_filtered    TYPE STANDARD TABLE OF ztwoapprh,
        lv_aufnr       TYPE aufnr,
        lv_month_start TYPE d,
        lv_week_start  TYPE d.

  CHECK gr_alv_0310 IS BOUND.

  lv_month_start      = sy-datum.
  lv_month_start+6(2) = '01'.
  lv_week_start       = sy-datum - 7.

  CASE gv_tree_selected_key.

    WHEN gc_tree_0310-root.
      " Show all pending WOs loaded into the tree
      gt_pending_wo = gt_pending_tree.

    WHEN gc_tree_0310-monthly.
      " Show all WOs from current calendar month
      LOOP AT gt_pending_tree INTO DATA(ls_wo).
        CHECK ls_wo-requested_date >= lv_month_start.
        APPEND ls_wo TO lt_filtered.
      ENDLOOP.
      gt_pending_wo = lt_filtered.

    WHEN gc_tree_0310-weekly.
      " Show all WOs from last 7 days
      LOOP AT gt_pending_tree INTO ls_wo.
        CHECK ls_wo-requested_date >= lv_week_start.
        APPEND ls_wo TO lt_filtered.
      ENDLOOP.
      gt_pending_wo = lt_filtered.

    WHEN OTHERS.
      " Leaf node: key is N<counter> — recover AUFNR from gt_tree_keys lookup
      READ TABLE gt_tree_keys INTO ls_tree_key
        WITH KEY node_key = gv_tree_selected_key.
      IF sy-subrc <> 0.
        RETURN.
      ENDIF.
      lv_aufnr = ls_tree_key-aufnr.

      " Populate s_a310 with the clicked WO so the filter bar reflects selection
      CLEAR s_a310.
      APPEND VALUE #( sign = 'I' option = 'EQ' low = lv_aufnr ) TO s_a310.

      LOOP AT gt_pending_tree INTO ls_wo
        WHERE aufnr = lv_aufnr.
        APPEND ls_wo TO lt_filtered.
      ENDLOOP.
      gt_pending_wo = lt_filtered.
      "ENDIF.

  ENDCASE.

  gr_alv_0310->refresh_table_display( ).

ENDFORM.