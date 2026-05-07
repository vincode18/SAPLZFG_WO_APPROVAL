*&---------------------------------------------------------------------*
*& GUI Title : T310
*& Screen    : 0310 - Pending Approval List
*&---------------------------------------------------------------------*
*& Create in SE80 / SE41:
*&   Right-click GUI Title folder -> Create -> T310
*&
*& Title text (with substitution placeholder):
*&   WO Approval: Pending List - &1
*&
*& Runtime call (status_0310 OUTPUT):
*&   SET TITLEBAR 'T310' WITH gc_title-pending.
*&
*& gc_title-pending is defined in LZFG_WO_APPROVALTOP and substitutes
*& into &1 at render time (e.g. "WO Approval: Pending List - Pending Work Orders").
*&
*& Activation:
*&   Ctrl+F3 on T310 in SE41.
*&---------------------------------------------------------------------*
