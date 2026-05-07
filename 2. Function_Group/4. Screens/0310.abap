*&---------------------------------------------------------------------*
*& Screen : 0310 — 3-Panel (Tree + Subscreen + ALV)
*& Flow Logic (v1.8 — subscreen 0311 range filter)
*&---------------------------------------------------------------------*
PROCESS BEFORE OUTPUT.
  MODULE status_0310.
  CALL SUBSCREEN ss_310 INCLUDING sy-repid '0312'.

PROCESS AFTER INPUT.
  CALL SUBSCREEN ss_310.
  MODULE user_command_0310.
