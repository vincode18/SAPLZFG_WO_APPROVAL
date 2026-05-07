*&---------------------------------------------------------------------*
*& PBO Module : STATUS_0100
*& Screen     : 0100 — Main Menu
*&---------------------------------------------------------------------*
MODULE status_0100 OUTPUT.
  SET PF-STATUS gc_status-main.
  SET TITLEBAR 'T100' WITH gc_title-main.
ENDMODULE.
