# ZST_WO_APPROVAL_TC - Table Control Structure

Dictionary structure for Screen 0300 Table Control (TC_ITEMS). Contains all fields displayed in the approval comparison table, including WO component data, tasklist comparison fields, and approval flags. Used by SE51 to validate field references at design time; runtime data flows through the local work area `GS_ITEMS_TC` (type `TY_ITEMS_TC`).

## Structure Definition

| Component | Data Type | Reference Table | Reference Field | Description |
|-----------|-----------|-----------------|-----------------|-------------|
| AUFNR | AUFNR | - | - | Work Order Number |
| PLNNR | PLNNR | - | - | Tasklist Number |
| PLNAL | PLNAL | - | - | Group Counter |
| MATNR | MATNR | - | - | WO Part Number |
| MAKTX | MAKTX | - | - | WO Part Description |
| WERKS | WERKS_D | - | - | Plant |
| BDMNG | QUAN | RESB | BDMNG | WO Required Quantity |
| MEINS | MEINS | - | - | Unit of Measure |
| PN_TASKLIST | MATNR | - | - | Tasklist Part Number |
| DESC_TASKLIST | MAKTX | - | - | Tasklist Description |
| MENGE_TL | QUAN | STPO | MENGE | Tasklist Quantity |
| MEINS_TL | MEINS | - | - | Tasklist UoM |
| COMP_STATUS | CHAR | - | Length 1 | Comparison Status ('X' = match) |
| COMP_MATCH | CHAR | - | Length 3 | Match Result ('Yes'/'No') |
| INTERCHANGE | CHAR | - | Length 3 | Interchange Flag ('Yes'/'No') |
| INTERCHANGE_PN | MATNR | - | - | Interchanged Part Number |
| IS_MISMATCH | CHAR | - | Length 1 | Mismatch Flag |
| APPR_FLAG | CHAR | - | Length 1 | Approval Flag (X = approved) |
| MARK | CHAR | - | Length 1 | Row Selection Checkbox |
| REASON_CODE | CHAR | - | Length 10 | Rejection Reason Code |

## Usage Notes

- This structure is only for SE51 screen painter validation
- Runtime data uses `GT_ITEMS_TC` / `GS_ITEMS_TC` with type `TY_ITEMS_TC`
- QUAN fields (BDMNG, MENGE_TL) require reference table/field for proper unit handling
- IS_MISMATCH uses CHAR(1) instead of ABAP_BOOL for dictionary compatibility