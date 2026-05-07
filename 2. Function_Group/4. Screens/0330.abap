*&---------------------------------------------------------------------*
*& Screen : 0330 — Manual Email Send  (v1.6 — adds SS_330 filter + ALV)
*& Flow Logic
*&---------------------------------------------------------------------*
PROCESS BEFORE OUTPUT.
  MODULE status_0330.
  CALL SUBSCREEN ss_330 INCLUDING sy-repid '0332'.

PROCESS AFTER INPUT.
  CALL SUBSCREEN ss_330.
  MODULE user_command_0330.
