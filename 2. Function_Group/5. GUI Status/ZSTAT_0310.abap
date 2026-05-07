*&---------------------------------------------------------------------*
*& GUI Status : ZSTAT_0310
*& Screen     : 0310 - Pending Approval List
*&---------------------------------------------------------------------*
*& Create in SE80 / SE41:
*&   Right-click GUI Status folder -> Create -> ZSTAT_0310
*&   Short text  : Pending Approval List
*&   Status type : Normal Screen
*&
*& --- Application Toolbar (slot 1 only) -------------------------------
*&   Slot  FctCode  F-Key   Icon                       Button Text
*&   1     SELECT   F5      ICON_SELECT_DETAIL         Open WO
*&
*&   NOTE: FctCode is plain "SELECT" (no & prefix).
*&         Custom fcodes never start with & -- & is reserved for SAP
*&         system codes like &BACK, &EXIT, &CANC, &IC1, &F03 ...
*&
*& --- Function Keys ---------------------------------------------------
*&   F2          &IC1     (auto-fired by ALV on double-click row)
*&   F3          &BACK    Back to Screen 0100
*&   Shift+F3    &EXIT    Leave Program
*&   F12         &CANC    Cancel -> Leave Program
*&   F5          SELECT   (mirror of toolbar slot 1)
*&
*& --- Menu Bar --------------------------------------------------------
*&   Leave empty - System + Help menus auto-generate.
*&
*& --- PAI Routing (see LZFG_WO_APPROVALI01 user_command_0310) ---------
*&   WHEN 'SELECT' OR '&IC1'  -> PERFORM open_selected_wo_from_pending
*&   WHEN '&BACK'             -> CLEAR gv_0310_initialized; SET SCREEN 0100
*&   WHEN '&EXIT' OR '&CANC'  -> CLEAR gv_0310_initialized; LEAVE PROGRAM
*&
*& --- Activation ------------------------------------------------------
*&   Ctrl+F3 on ZSTAT_0310 in SE41.
*&---------------------------------------------------------------------*
