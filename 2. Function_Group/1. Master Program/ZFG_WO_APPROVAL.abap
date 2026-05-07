*******************************************************************
*   System-defined Include-files.                                 *
*******************************************************************
*&---------------------------------------------------------------------*
*& Function Group : ZFG_WO_APPROVAL
*& Description    : Work Order Approval System — Main Function Group
*& Author         : SAP Development Team
*& Created        : 2024
*& Modified       : 2026
*& Module         : PM (Plant Maintenance)
*& Functional Area: Service Work Order Approval
*& Version        : 1.5
*&---------------------------------------------------------------------*
FUNCTION-POOL ZFG_WO_APPROVAL.

    INCLUDE LZFG_WO_APPROVALTOP.        " Global Data / Types / Constants
*INCLUDE LZFG_WO_APPROVALUXX.        " Function Module Stubs
*
    INCLUDE LZFG_WO_APPROVALF01.        " Authorization & Init
    INCLUDE LZFG_WO_APPROVALF02.        " Save Logic (L1 / L3)
    INCLUDE LZFG_WO_APPROVALF03.        " Data Retrieval & Compare
    INCLUDE LZFG_WO_APPROVALF04.        " WO Range Load & Table Control
    INCLUDE LZFG_WO_APPROVALF05.        " Email Orchestration 
    INCLUDE LZFG_WO_APPROVALF06.        " HTML Builder & BCS Sender 
    INCLUDE LZFG_WO_APPROVALF07.        " ALV Free/Init FORMs for 0310/0320/0330

    INCLUDE lzfg_wo_approvalo01.

    INCLUDE lzfg_wo_approvali01.
*
*INCLUDE LZFG_WO_APPROVALО01.        " PBO Modules
*INCLUDE LZFG_WO_APPROVALІ01.        " PAI Modules

*******************************************************************
*   User-defined Include-files (if necessary).                    *
*******************************************************************
* INCLUDE LZFG_WO_APPROVALF...               " Subroutines
* INCLUDE LZFG_WO_APPROVALO...               " PBO-Modules
* INCLUDE LZFG_WO_APPROVALI...               " PAI-Modules
* INCLUDE LZFG_WO_APPROVALE...               " Events
* INCLUDE LZFG_WO_APPROVALP...               " Local class implement.
* INCLUDE LZFG_WO_APPROVALT99.               " ABAP Unit tests