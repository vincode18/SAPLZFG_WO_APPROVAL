# DOCU 1.6 — Screen Development Tutorial (SE51)

**Project**  : SAP WO Approval System
**Program**  : `SAPLZFG_WO_APPROVAL` (auto module pool of function group `ZFG_WO_APPROVAL`)
**Tx Code**  : `ZWOAPP`
**Based on** : PRD 1.5 — `../PRD/PRD 1.5/Planning.md`
**Scope**    : Layout design for Screens `0100`, `0300`, `0310`, `0320`, `0330`.

> Flow logic files (`.../4. Screens/0xxx.abap`) and PBO/PAI modules are **already written**.
> This doc only covers **SE51 Screen Painter** work: screen attributes, layout elements, element list, and activation.

---

## 0. PREREQUISITES

Before opening SE51:

```
[✓] Function group ZFG_WO_APPROVAL activated
[✓] Include LZFG_WO_APPROVALTOP activated
    → p_aufnr_from / p_aufnr_to / p_email_type / p_wo_mail exist
    → gs_items_tc work area exists
    → CONTROLS: tc_items TYPE TABLEVIEW USING SCREEN 0300 declared
[✓] Screens planned: 0100, 0300 (host), 0301 (subscreen of 0300),
                     0310, 0320, 0330
[✓] GUI statuses ZSTAT_0100 / ZSTAT_0300 / ZSTAT_0310 / ZSTAT_0320 / ZSTAT_0330
    (Subscreen 0301 inherits ZSTAT_0300 from its host — no own status)
[✓] Titlebars  T100 / T300 / T310 / T320 / T330
[✓] DDIC tables ZTWOAPPRH, ZTWOAPPR active
```

Open SE51 for each screen:
```
SE80 → Function Group: ZFG_WO_APPROVAL
     → Screens → <screen-num> → Change (F6)
```

---

## 1. COMMON SE51 TERMINOLOGY

```
 +--- Screen Painter: 3 tabs ---+
 |  [Attributes]   [Element list]   [Flow logic]
 +-------------------------------+
        |
        v
    [Layout] button (F7)  → drag & drop editor (Graphical Layout)
```

| Term | Meaning |
|---|---|
| **Dynpro Type** | Normal / Subscreen / Modal | (use **Normal** for 0100-0330)
| **Next Dynpro** | Where control goes on ENTER (use same screen number to loop) |
| **Element List** | Tab that shows all placed UI elements + their attributes |
| **FctCode** | Function code sent to PAI when user triggers the element |
| **Custom Container (CC)** | Placeholder region for ALV grids (reserved area, no OK code) |
| **Table Control** | Native dynpro list with `CONTROLS ... TYPE TABLEVIEW` binding |

---

## 1.5 INCLUDE CONVENTION (Function Group Module Pool)

All 5 screens share the **same two includes** for their PBO/PAI bodies:

```text
 LZFG_WO_APPROVALTOP       Global data / types / constants
 LZFG_WO_APPROVALF01..F07  FORM routines (business logic)
 LZFG_WO_APPROVALO01       ALL PBO (OUTPUT) modules  - 0100/0300/0310/0320/0330
 LZFG_WO_APPROVALI01       ALL PAI (INPUT)  modules  - 0100/0300/0310/0320/0330
```

**Rule when SE51 asks "Create PBO/PAI Module -> Include Selection":**

| You are creating           | Pick this include                |
|----------------------------|----------------------------------|
| Any `MODULE ... OUTPUT.`   | `LZFG_WO_APPROVALO01` (existing) |
| Any `MODULE ... INPUT.`    | `LZFG_WO_APPROVALI01` (existing) |

> Do **NOT** pick "New Include" (`O02`, `I02`, ...) for new modules — keep one
> file per direction so cross-screen helpers like `load_reasons`,
> `set_reason_dropdown`, `validate_reason` live next to each other.
>
> After activation, confirm the master program `ZFG_WO_APPROVAL` has both
> `INCLUDE LZFG_WO_APPROVALO01.` and `INCLUDE LZFG_WO_APPROVALI01.` (Latin O / I,
> not Cyrillic О / І).

---

## 2. SCREEN 0100 — MAIN MENU

### 2.1 Purpose
Entry screen. The **4 navigation buttons** (APPR/PEND/HIST/MAIL) live in the
**Application Toolbar of GUI Status `ZSTAT_0100`** — NOT as on-screen pushbuttons.
The screen body shows only an informational/welcome area. F3 = Exit.

### 2.2 Target Layout

```
 +--- Application Toolbar (from ZSTAT_0100) --------------------------------+
 | [F5 APPR] [F6 PEND] [F7 HIST] [F8 MAIL]                       [F3 Exit] |
 +--------------------------------------------------------------------------+
 Col: 0        10        20        30        40        50        60        70
     +---------+---------+---------+---------+---------+---------+---------+
 R01 |                                                                     |
 R02 |   .--- Work Order Approval System ------------------------------.   |
 R03 |   |                                                             |   |
 R04 |   |   Welcome to the WO Approval main menu.                     |   |
 R05 |   |                                                             |   |
 R06 |   |   Use the toolbar buttons above to navigate:                |   |
 R07 |   |     F5  Open Approval      (Screen 0300)                    |   |
 R08 |   |     F6  Pending List       (Screen 0310)                    |   |
 R09 |   |     F7  Approval History   (Screen 0320)                    |   |
 R10 |   |     F8  Send Email         (Screen 0330)                    |   |
 R11 |   |                                                             |   |
 R12 |   '-------------------------------------------------------------'   |
 R13 |                                                                     |
     +---------------------------------------------------------------------+
```

### 2.3 Attributes Tab

```
Short Description : Main Menu — WO Approval
Dynpro Type       : (*) Normal
Next Dynpro       : 0100
Cursor Position   : (blank)
Settings          : (all unchecked)
```

### 2.4 Screen Layout — Element List (NO pushbuttons)

| Name      | Type  | Text / Binding                             | FctCode | Line | Col | Length  |
|-----------|-------|--------------------------------------------|---------|------|-----|---------|
| `FR_MAIN` | Frame | Work Order Approval System                 | -       | 2    | 3   | 65 × 11 |
| `LB_WELC` | Text  | Welcome to the WO Approval main menu.      | -       | 4    | 6   | 50      |
| `LB_HINT` | Text  | Use the toolbar buttons above to navigate: | -       | 6    | 6   | 50      |
| `LB_APPR` | Text  | F5  Open Approval      (Screen 0300)       | -       | 7    | 10  | 45      |
| `LB_PEND` | Text  | F6  Pending List       (Screen 0310)       | -       | 8    | 10  | 45      |
| `LB_HIST` | Text  | F7  Approval History   (Screen 0320)       | -       | 9    | 10  | 45      |
| `LB_MAIL` | Text  | F8  Send Email         (Screen 0330)       | -       | 10   | 10  | 45      |

> **No pushbuttons on this screen.** All navigation is via the GUI Status
> Application Toolbar (see 2.7). Screen body is purely informational.

### 2.5 Flow Logic (already written — do not edit)

```abap
PROCESS BEFORE OUTPUT.
  MODULE status_0100.
PROCESS AFTER INPUT.
  MODULE user_command_0100.
```

### 2.6 PAI FctCode Matching

`ZSTAT_0100` toolbar codes **must** match `WHEN` branches in
`@2. Function_Group/3. PAI Modules/USER_COMMAND_0100.abap`:

```abap
CASE sy-ucomm.
  WHEN 'APPR'.
    CLEAR: gv_aufnr, p_aufnr_from, p_aufnr_to.   "<-- shared with subscreen 0301
    SET SCREEN 0300. LEAVE SCREEN.
  WHEN 'PEND'.  ...  SET SCREEN 0310. LEAVE SCREEN.
  WHEN 'HIST'.  ...  SET SCREEN 0320. LEAVE SCREEN.
  WHEN 'MAIL'.  ...  SET SCREEN 0330. LEAVE SCREEN.
  WHEN '&EXIT' OR '&BACK' OR '&CANC'.  LEAVE PROGRAM.
ENDCASE.
```

> **Subscreen note (`APPR` branch):** Screen 0300 embeds Subscreen **0301**
> (WO-range header) via `CALL SUBSCREEN sub_header_300 INCLUDING sy-repid '0301'.`.
> Because 0301 reuses the global variables `p_aufnr_from` / `p_aufnr_to` declared
> in `LZFG_WO_APPROVALTOP`, the `CLEAR` above is enough to reset the header —
> **no PAI code change needed on 0100** when the subscreen is added.
> See §3.4 / §3.5 for the subscreen design.

### 2.7 GUI Status `ZSTAT_0100` — Application Toolbar

In SE80/SE41, open `ZSTAT_0100` (Normal Screen type).

#### Application Toolbar (Items 1-7)

| Slot | FctCode | F-Key | Icon         | Button Text       |
|------|---------|-------|--------------|-------------------|
| 1    | `APPR`  | F5    | `ICON_OKAY`  | Open Approval     |
| 2    | `PEND`  | F6    | `ICON_LIST`  | Pending List      |
| 3    | `HIST`  | F7    | `ICON_DOCUMENT` | Approval History |
| 4    | `MAIL`  | F8    | `ICON_MAIL`  | Send Email        |

> **Do NOT prefix with `&`.** `&` is reserved for system codes (`&EXIT`, `&BACK`, `&CANC`, `&SAVE`).
> Plain `APPR` / `PEND` / `HIST` / `MAIL` must match the `WHEN` branches in the PAI.

#### Function Keys

| F-Key | FctCode | Purpose             |
|-------|---------|---------------------|
| F3    | `&EXIT` | Exit program        |
| F5    | `APPR`  | (dup of toolbar)    |
| F6    | `PEND`  | (dup of toolbar)    |
| F7    | `HIST`  | (dup of toolbar)    |
| F8    | `MAIL`  | (dup of toolbar)    |
| F12   | `&CANC` | Cancel              |
| F15   | `&BACK` | Back                |

> F5–F8 entries appear automatically in Function Keys when you add them to the App Toolbar — no manual duplication needed.

#### Menu Bar

Leave empty (System + Help menus auto-generated).

### 2.8 Activation Checklist

```
[✓] Activate GUI Status ZSTAT_0100 (toolbar: APPR/PEND/HIST/MAIL + F3=&EXIT)
[✓] Activate Titlebar  T100  ("Work Order Approval - Main Menu")
[✓] Ctrl+F3 on Screen 0100 (layout + flow logic)
[✓] Test: F8 from SE51 → screen opens, 4 toolbar buttons visible, F3 exits
[✓] Test: click each toolbar button → navigates to 0300/0310/0320/0330
         (will short-dump until those screens exist — expected)
```

---

## 3. SCREEN 0300 — APPROVAL INPUT & TABLE CONTROL

### 3.1 Purpose
Input one WO or a range (From/To), press **Execute** to load mismatched RESB vs TaskList items into a **Table Control** `tc_items`. User ticks approve/reject and reason → press **Save**.

### 3.2 Target Layout

Screen 0300 is composed of **three regions**:

```
 Col: 0      10      20      30      40      50      60      70      80      90
     +-------+-------+-------+-------+-------+-------+-------+-------+-------+
     |  == Subscreen Area SUB_HEADER_300 (embeds Screen 0301) ==            |
 R01 | .---------------------------------------------------------------------.
 R01 | | Work Order From: [__________]  To: [__________]   [ Execute ]      |  ← Screen 0301
 R02 | '--------------------------------------------------------------------'|
     |  == Table Control TC_ITEMS ==                                         |
 R03 | .----------------------- Table Control: TC_ITEMS --------------------.|
 R04 | | [✓] Appr Material     Description            WO Qty  TL Qty Reason||
 R05 | |---- --- ------------- --------------------- ------- ------ -------||
 R06 | | [ ] [ ] ____________ ____________________  _____   _____  [____v]||
 R07 | | [ ] [ ] ____________ ____________________  _____   _____  [____v]||
 R08 | | [ ] [ ] ____________ ____________________  _____   _____  [____v]||
 R09 | | [ ] [ ] ____________ ____________________  _____   _____  [____v]||
 R10 | | [ ] [ ] ____________ ____________________  _____   _____  [____v]||
 R11 | '--------------------------------------------------------------------'|
     |  == Footer ==                                                         |
 R12 |                                          [ Save Approval ]           |
     +----------------------------------------------------------------------+
```

> **Region split:**
>
> - R01-R02 → Subscreen Area `SUB_HEADER_300` hosting **Screen 0301** (Dynpro Type: **Subscreen**)
> - R03-R11 → Table Control `TC_ITEMS` on Screen 0300 itself
> - R12    → `BT_SAVE` pushbutton on Screen 0300 itself

### 3.3 Attributes Tab

```
Short Description : Approval Entry + Table Control
Dynpro Type       : (*) Normal
Next Dynpro       : 0300
```

### 3.4 Header Subscreen 0301 — WO-Range Input

The header row (From/To/Execute) lives on its **own dynpro**, Screen **0301**,
of type **Subscreen**, which is embedded into 0300 via `CALL SUBSCREEN` (§3.5).

#### 3.4.1 Create Screen 0301

```
SE80 → Function Group ZFG_WO_APPROVAL → right-click Screens → Create → Screen
Screen Number : 0301
```

#### 3.4.2 Screen 0301 — Attributes Tab

```
Short Description : WO Range Header (Subscreen)
Dynpro Type       : (*) Subscreen     <-- CRITICAL: not Normal
Next Dynpro       : (leave blank — subscreens ignore it)
```

> ⚠ Subscreens **cannot** declare their own PF-STATUS, Titlebar, or OK_CODE.
> The host (0300) provides those. The `EXEC` FctCode fired by `BT_EXEC` on 0301
> flows into 0300's `save_ok` and is handled by `MODULE user_command_0300`.

#### 3.4.3 Screen 0301 — Element List (Row 1)

Paint these 5 elements on Screen **0301** (not 0300):

| Name           | Type         | DDIC / Source                                                | FctCode | Line | Col | Len |
|----------------|--------------|--------------------------------------------------------------|---------|------|-----|-----|
| `LB_FROM`      | Text         | "WO From:"                                                   | -       | 1    | 1   | 14  |
| `P_AUFNR_FROM` | Input/Output | `AUFNR` (auto-binds to global var `P_AUFNR_FROM` TYPE AUFNR) | -       | 1    | 16  | 12  |
| `LB_TO`        | Text         | "To:"                                                        | -       | 1    | 31  | 4   |
| `P_AUFNR_TO`   | Input/Output | `AUFNR` (auto-binds to global var `P_AUFNR_TO`)              | -       | 1    | 36  | 12  |
| `BT_EXEC`      | Pushbutton   | "Execute"                                                    | `EXEC`  | 1    | 55  | 15  |

> **Binding tip:** In the I/O field attributes, set **Name** = `P_AUFNR_FROM`
> and **Dict type** = `AUFNR`. The screen field auto-binds to the global
> variable of the same name declared in `LZFG_WO_APPROVALTOP`.

#### 3.4.4 Screen 0301 — Flow Logic (empty)

```abap
PROCESS BEFORE OUTPUT.

PROCESS AFTER INPUT.
```

> Leave both events **empty**. The host 0300 handles everything (PBO modules,
> PAI `EXEC` via `user_command_0300`). Do NOT add `SET PF-STATUS`, titlebar,
> or `user_command_0301` — subscreens ignore them.

#### 3.4.5 Screen 0301 — Canvas Size

Canvas: **2 rows × 75 columns**. This is the *maximum* footprint the subscreen
can render — the `SUB_HEADER_300` area on 0300 (§3.5) must be **at least**
this size or fields will be clipped.

### 3.5 Subscreen Area `SUB_HEADER_300` on Screen 0300

On Screen 0300's **Layout**, place a **Subscreen Area** element (the empty
placeholder rectangle — not the subscreen itself):

```
Layout Editor → Toolbar → "Subscreen Area" icon (rectangle labelled "SUB")
 → drag rectangle at Line 1 / Col 1, size 2 rows × 75 cols
 → double-click → Name = SUB_HEADER_300
```

| Name             | Type           | Text | FctCode | Line | Col | Size   |
|------------------|----------------|------|---------|------|-----|--------|
| `SUB_HEADER_300` | Subscreen Area | -    | -       | 1    | 1   | 75 × 2 |

> **Naming rule:** the area name here (`SUB_HEADER_300`) must match the
> argument in the `CALL SUBSCREEN` statement in §3.9 flow logic — exactly,
> case-insensitive.

### 3.6 Table Control `TC_ITEMS` — Properties

In Layout Editor → drag **Table Control** → name it `TC_ITEMS`:

```
Name               : TC_ITEMS
Line Selection     : Single (or Multiple if you want bulk)
Column Selection   : No
Vertical Scrollbar : Yes
With Title         : Yes  ("Approval Items")
Separators         : Yes (columns + lines)
Resizing           : [✓] Column width
```

Position/size: **Line 3 / Col 1**, **Width 118**, **Height 9 lines**
(i.e. **below** the `SUB_HEADER_300` area from §3.5).

> **Preferred creation path:** use the **Table Control Wizard** (right-click
> the empty TC shell → Table Control Wizard). Walk through the 7 wizard steps,
> pick the columns from `GS_ITEMS_TC`, but on the "Flow Logic generation" step
> **UNCHECK all four options** — the flow logic in §3.9 is already hand-written
> and must not be overwritten.

### 3.7 Table Control Columns (inside `TC_ITEMS`)

Each column references the work area `GS_ITEMS_TC-*`.

| Col # | Column Name                 | Type      | Header       | Len | Notes                          |
|-------|-----------------------------|-----------|--------------|-----|--------------------------------|
| 1     | `GS_ITEMS_TC-MARK`          | Checkbox  | (blank)      | 1   | Row selector                   |
| 2     | `GS_ITEMS_TC-APPR_FLAG`     | Checkbox  | Appr         | 1   | Tick = approved                |
| 3     | `GS_ITEMS_TC-MATNR`         | I/O       | Material     | 18  | Read-only                      |
| 4     | `GS_ITEMS_TC-MAKTX`         | I/O       | Description  | 40  | Read-only                      |
| 5     | `GS_ITEMS_TC-BDMNG`         | I/O       | WO Qty       | 13  | Read-only                      |
| 6     | `GS_ITEMS_TC-MEINS`         | I/O       | UoM          | 3   | Read-only                      |
| 7     | `GS_ITEMS_TC-MENGE_TL`      | I/O       | TL Qty       | 13  | Read-only                      |
| 8     | `GS_ITEMS_TC-REASON_CODE`   | Listbox   | Reason       | 10  | **Dropdown (see 3.8)**         |

Set **Input = ON** only for `MARK`, `APPR_FLAG`, `REASON_CODE` (the rest are display-only). PBO `control_field_attributes` further hides/disables per user level.

### 3.8 Listbox Setup for `REASON_CODE`

On the `GS_ITEMS_TC-REASON_CODE` column:

```
Field properties:
  Format         : LISTBOX
  Value list     : populated at runtime via VRM_SET_VALUES
                   (already done in MODULE set_reason_dropdown)
  Drop-down key  : GS_ITEMS_TC-REASON_CODE   <-- ID used in VRM call
```

> The PBO module already calls:
>
> ```abap
> CALL FUNCTION 'VRM_SET_VALUES'
>   EXPORTING id = 'GS_ITEMS_TC-REASON_CODE' values = lt_values.
> ```
>
> so the dropdown key **must exactly be** `GS_ITEMS_TC-REASON_CODE`.

### 3.9 Footer — Save Button (on Screen 0300)

| Name      | Type       | Text            | FctCode | Line | Col | Len |
|-----------|------------|-----------------|---------|------|-----|-----|
| `BT_SAVE` | Pushbutton | Save Approval   | `SAVE`  | 12   | 85  | 20  |

(Back/Exit handled in GUI Status toolbar as `&BACK` / `&EXIT`.)

### 3.10 Flow Logic (already written)

**Screen 0300** — host. Note the `CALL SUBSCREEN` statements in **both** PBO
and PAI; PBO takes `INCLUDING <prog> <dynpro>`, PAI takes only the area name.

```abap
PROCESS BEFORE OUTPUT.
  MODULE status_0300.
  MODULE load_reasons.
  CALL SUBSCREEN sub_header_300 INCLUDING sy-repid '0301'.   "<-- embeds 0301
  LOOP AT gt_items_tc INTO gs_items_tc
       WITH CONTROL tc_items CURSOR tc_items-current_line.
    MODULE read_tc_line.
    MODULE set_row_color.
    MODULE set_reason_dropdown.
    MODULE control_field_attributes.
  ENDLOOP.

PROCESS AFTER INPUT.
  CALL SUBSCREEN sub_header_300.                             "<-- transports 0301 input
  LOOP AT gt_items_tc.
    CHAIN.
      FIELD gs_items_tc-mark.
      FIELD gs_items_tc-appr_flag.
      FIELD gs_items_tc-reason_code.
      MODULE modify_tc_line.
      MODULE validate_reason ON CHAIN-REQUEST.
    ENDCHAIN.
  ENDLOOP.
  MODULE user_command_0300.
```

**Screen 0301** — subscreen, empty flow logic (host handles everything):

```abap
PROCESS BEFORE OUTPUT.

PROCESS AFTER INPUT.
```

> **Ordering rules (host 0300):**
>
> - `CALL SUBSCREEN ... INCLUDING ...` must come **before** the `LOOP AT` in
>   PBO so the header renders above the table.
> - `CALL SUBSCREEN sub_header_300.` must come **before** the `LOOP AT` in
>   PAI so the `EXEC` FctCode is transported before `user_command_0300` runs.
> - PAI form has **no** `INCLUDING` keyword — short form only.

### 3.11 Module Wiring (SE51 Flow Logic -> Include Selection)

When you double-click each `MODULE` name on the Flow Logic tab, SAP asks which
include to place the body in. Use this mapping for Screen 0300 — **9 modules total**.
Screen **0301** has no modules (flow logic is empty).

| Screen | SE51 double-click on                | Direction | Include target        |
|--------|-------------------------------------|-----------|-----------------------|
| 0300   | `MODULE status_0300.`               | OUTPUT    | `LZFG_WO_APPROVALO01` |
| 0300   | `MODULE load_reasons.`              | OUTPUT    | `LZFG_WO_APPROVALO01` |
| 0300   | `MODULE read_tc_line.`              | OUTPUT    | `LZFG_WO_APPROVALO01` |
| 0300   | `MODULE set_row_color.`             | OUTPUT    | `LZFG_WO_APPROVALO01` |
| 0300   | `MODULE set_reason_dropdown.`       | OUTPUT    | `LZFG_WO_APPROVALO01` |
| 0300   | `MODULE control_field_attributes.`  | OUTPUT    | `LZFG_WO_APPROVALO01` |
| 0300   | `MODULE modify_tc_line.`            | INPUT     | `LZFG_WO_APPROVALI01` |
| 0300   | `MODULE validate_reason ...`        | INPUT     | `LZFG_WO_APPROVALI01` |
| 0300   | `MODULE user_command_0300.`         | INPUT     | `LZFG_WO_APPROVALI01` |

> **Subscreen 0301 has NO modules at all.** All FctCodes (incl. `EXEC`) are
> handled by the host's `user_command_0300`. Range validation, if desired,
> can be added inside `user_command_0300` before `PERFORM load_wo_range_for_approval`.

Bodies to paste (source of truth):
`@2. Function_Group/2. PBO Modules/STATUS_0300.abap` and
`@2. Function_Group/3. PAI Modules/USER_COMMAND_0300.abap`.

### 3.12 Activation Checklist

```
[✓] Ctrl+F3 on screen 0301  (Subscreen — activate FIRST)
[✓] Ctrl+F3 on screen 0300  (host — activates only if 0301 is active)
[✓] Activate GUI Status ZSTAT_0300 (buttons: EXEC, SAVE, &BACK, &EXIT)
[✓] Activate Titlebar T300
[✓] Test: Screen 0300 opens → subscreen area renders From/To/Execute on row 1
[✓] Test: enter single WO → Execute → mismatch rows load in TC_ITEMS
[✓] Test: enter WO range From/To → multi-WO items load
[✓] Test (L1 login): only red (mismatch) rows visible
[✓] Test: tick Appr + pick Reason → Save → data lands in ZTWOAPPR
[✓] Test: Back from 0300 → returns to 0100 without dump; p_aufnr_from/to cleared
```

> **Activation order matters:** if 0300 is activated while 0301 is inactive,
> you get runtime error `DYNPRO_NOT_FOUND 0301` at the `CALL SUBSCREEN`.

---

## 4. SCREEN 0310 — PENDING APPROVAL LIST (ALV)

### 4.1 Purpose
Show WOs with `APPR_STATUS = 1` (or non-final). User can:

- **Double-click** a row (fires `&IC1` natively from the ALV grid) → navigate to Screen 0300 with that AUFNR pre-loaded in `s_aufnr`.
- Press **F5 / Open WO toolbar button** (fires `&SELECT`) → same navigation.
- Press **F3 / Back** → return to Screen 0100.
- Press **F12 / Cancel** or **Exit** → leave program.

### 4.2 Target Layout

```text
 Col: 0      10      20      30      40      50      60      70      80      90
     +-------+-------+-------+-------+-------+-------+-------+-------+-------+
 R01 |                                                                       |
 R02 | .------------ Custom Container: CC_ALV_0310 ------------------------.|
 R03 | |                                                                   ||
 R04 | |    (ALV Grid rendered here at runtime — cl_gui_alv_grid)          ||
 R05 | |                                                                   ||
 R06 | |   AUFNR | WERKS | APPR_STATUS | APPROVED_BY | APPROVED_DATE | ... ||
 R07 | |   ----- | ----- | ----------- | ----------- | ------------- | --- ||
 R08 | |   ....                                                           ||
 R09 | |                                                                   ||
 R10 | '-------------------------------------------------------------------'|
     +----------------------------------------------------------------------+
```

### 4.3 Attributes Tab

```text
Short Description : Pending Approval List
Dynpro Type       : (*) Normal
Next Dynpro       : 0310
```

### 4.4 Layout — Element List

| Name          | Type               | Text | FctCode | Line | Col | Size     |
|---------------|--------------------|------|---------|------|-----|----------|
| `CC_ALV_0310` | **Custom Control** | -    | -       | 1    | 1   | 118 × 18 |

> **Line 1 / Col 1**: start the container from the very first row — there is no
> header input area on this screen. The ALV grid fills the full screen.
> Name must exactly match `container_name = 'CC_ALV_0310'` in `FORM init_alv_0310`
> (`LZFG_WO_APPROVALF07`), case-insensitive in SAP but keep it consistent.

How to drop it:

```text
Layout Editor (F7) → Toolbar → "Custom Control" icon
 → drag rectangle from Line 1 Col 1 down to roughly line 18
 → double-click → set Name = CC_ALV_0310
```

### 4.4.1 Element List — OK Field (mandatory)

After placing `CC_ALV_0310`, switch to the **Element List** tab and set the OK field:

```text
Element List tab → scroll to bottom "OK" row → Name = OK_CODE
```

> Without `OK_CODE` bound here, `&SELECT`, `&IC1`, `&BACK` etc. are never
> transported to `user_command_0310` and the toolbar / double-click do nothing.

### 4.5 Flow Logic (already written)

See `@2. Function_Group/4. Screens/0310.abap`:

```abap
PROCESS BEFORE OUTPUT.
  MODULE status_0310.          " Lazy-init ALV on first entry, refresh otherwise

PROCESS AFTER INPUT.
  MODULE user_command_0310.    " Handles &SELECT / &IC1 / &BACK / &EXIT / &CANC
```

> No `CALL SUBSCREEN` and no `LOOP AT` — this screen has a single Custom
> Container, so the flow logic is minimal.

### 4.6 Module Wiring — Screen 0310

| SE51 double-click on          | Direction | Include target         | Body source file                       |
|-------------------------------|-----------|------------------------|----------------------------------------|
| `MODULE status_0310.`         | OUTPUT    | `LZFG_WO_APPROVALO01`  | `2. PBO Modules/STATUS_0310.abap`      |
| `MODULE user_command_0310.`   | INPUT     | `LZFG_WO_APPROVALI01`  | `3. PAI Modules/USER_COMMAND_0310.abap`|

> Both bodies are **already appended** to the include files and ready — SE51
> will navigate directly to the existing code without showing a "Create Module"
> stub.

### 4.6.1 PAI FctCode Reference — `user_command_0310`

```abap
MODULE user_command_0310 INPUT.
  save_ok = ok_code.
  CLEAR ok_code.

  CASE save_ok.
    WHEN '&SELECT' OR '&IC1'.        " &SELECT = toolbar button, &IC1 = ALV double-click
      PERFORM open_selected_wo_from_pending.
    WHEN '&BACK'.
      CLEAR gv_0310_initialized.     " Reset: PBO rebuilds ALV on next entry
      SET SCREEN 0100. LEAVE SCREEN.
    WHEN '&EXIT' OR '&CANC'.
      CLEAR gv_0310_initialized.
      LEAVE PROGRAM.
  ENDCASE.
ENDMODULE.
```

> **FctCode convention note:** the toolbar button in `ZSTAT_0310` must be
> defined with FctCode = **`&SELECT`** (with ampersand) to match the `WHEN`
> branch. `&IC1` is the SAP system code auto-fired by ALV on double-click —
> no explicit F-key registration needed; it fires natively.

### 4.7 GUI Status `ZSTAT_0310`

```
SE80 → ZFG_WO_APPROVAL → GUI Status folder → right-click → Create
  Status name : ZSTAT_0310
  Short text  : Pending Approval List
  Status type : Normal Screen
```

**Application Toolbar:**

| Slot | FctCode    | F-Key | Icon                  | Button Text |
|------|------------|-------|-----------------------|-------------|
| 1    | `&SELECT`  | F5    | `ICON_SELECT_DETAIL`  | Open WO     |

**Function Keys:**

| F-Key      | FctCode   | Purpose                        |
|------------|-----------|--------------------------------|
| F2         | `&IC1`    | ALV double-click (auto-fired)  |
| F3         | `&BACK`   | Back to Screen 0100            |
| Shift+F3   | `&EXIT`   | Leave Program                  |
| F12        | `&CANC`   | Cancel → Leave Program         |
| F5         | `&SELECT` | Mirror of toolbar slot 1       |

> Leave Menu Bar empty — System + Help menus auto-generate.

### 4.8 Titlebar `T310`

```text
SE80 → ZFG_WO_APPROVAL → GUI Title folder → right-click → Create → T310
  Title text : WO Approval: Pending List - &1
```

Runtime assignment in `status_0310`:

```abap
SET TITLEBAR 'T310' WITH gc_title-pending.
```
`gc_title-pending` substitutes into `&1` at render time.

### 4.9 Activation Checklist

```
Activation ORDER matters — includes first, then screen objects:

[ ] 1. Ctrl+F3  LZFG_WO_APPROVALO01   (contains status_0310)
[ ] 2. Ctrl+F3  LZFG_WO_APPROVALI01   (contains user_command_0310)
[ ] 3. Ctrl+F3  LZFG_WO_APPROVALF07   (contains init_alv_0310, free_alv_0310,
                                        handle_double_click_0310)
[ ] 4. Ctrl+F3  LZFG_WO_APPROVALF03   (contains open_selected_wo_from_pending)
[ ] 5. Create + Ctrl+F3  ZSTAT_0310   (toolbar: &SELECT F5; keys: F3/Shift+F3/F12)
[ ] 6. Create + Ctrl+F3  T310         (title: "WO Approval: Pending List - &1")
[ ] 7. Layout:  drop CC_ALV_0310 Custom Control (Line 1, Col 1, 118 x 18)
[ ] 8. Element List: OK field = OK_CODE
[ ] 9. Ctrl+F3  Screen 0310
```

**Test plan:**

```text
[ ] Tx ZWOAPP → click PEND toolbar button on 0100
    → Screen 0310 opens, ALV fills with pending WOs (APPR_STATUS <> approved)
[ ] Double-click any row
    → s_aufnr populated with that AUFNR, Screen 0300 opens with range pre-loaded
[ ] F5 / Open WO button on 0310 toolbar (same row selected)
    → same navigation via &SELECT branch
[ ] F3 from 0310
    → back to 0100 (gv_0310_initialized cleared, no dump)
[ ] Re-click PEND
    → ALV rebuilds fresh (lazy-init fires again)
[ ] F12 / Cancel from 0310
    → LEAVE PROGRAM (no dump, gv_0310_initialized cleared)
```

---

## 5. SCREEN 0320 — APPROVAL HISTORY (READ-ONLY ALV)

### 5.1 Purpose
Read-only audit view of `ZTWOAPPR`. No editing, no double-click handler.

### 5.2 Target Layout

```
     +---------------------------------------------------------------------+
 R01 |                                                                     |
 R02 | .------------ Custom Container: CC_ALV_0320 -----------------------.|
 R03 | |    AUFNR | MATNR | WERKS | L1 Appr | L3 Appr | Reason Rej |...  ||
 R04 | |    ----                                                         ||
 R05 | '-----------------------------------------------------------------'|
     +---------------------------------------------------------------------+
```

### 5.3 Attributes Tab

```
Short Description : Approval History (Read-Only)
Dynpro Type       : (*) Normal
Next Dynpro       : 0320
```

### 5.4 Layout — Element List

| Name          | Type           | Line | Col | Size     |
|---------------|----------------|------|-----|----------|
| `CC_ALV_0320` | Custom Control | 2    | 1   | 118 × 18 |

Name must match `container_name = 'CC_ALV_0320'` in `FORM init_alv_0320`.

### 5.5 Flow Logic

```abap
PROCESS BEFORE OUTPUT.
  MODULE status_0320.
PROCESS AFTER INPUT.
  MODULE user_command_0320.
```

### 5.6 Module Wiring — Screen 0320

| SE51 double-click on          | Direction | Include target        |
|-------------------------------|-----------|-----------------------|
| `MODULE status_0320.`         | OUTPUT    | `LZFG_WO_APPROVALO01` |
| `MODULE user_command_0320.`   | INPUT     | `LZFG_WO_APPROVALI01` |

Bodies to paste:
`@2. Function_Group/2. PBO Modules/STATUS_0320.abap` and
`@2. Function_Group/3. PAI Modules/USER_COMMAND_0320.abap`.

### 5.7 Activation Checklist

```
[✓] Ctrl+F3 on screen 0320
[✓] Activate GUI Status ZSTAT_0320 (&BACK, &EXIT)
[✓] Activate Titlebar T320
[✓] Test: ALV loads all rows from ZTWOAPPR
[✓] Test: columns Reason Rejection / Reason Change visible
[✓] Test: no editable cells, no toolbar actions that modify data
```

---

## 6. SCREEN 0330 — MANUAL EMAIL SEND

### 6.1 Purpose
User enters a WO + plant → **Load** → items list (ALV with Send checkbox) → picks email type **HO** / **BR** → clicks **Send Email** → BCS email fires.

### 6.2 Target Layout

```
 Col: 0      10      20      30      40      50      60      70      80      90
     +-------+-------+-------+-------+-------+-------+-------+-------+-------+
 R01 | Work Order: [__________]  Plant: [____]     [ Load Items ]           |
 R02 |                                                                       |
 R03 | .------------ Custom Container: CC_ALV_0330 ------------------------.|
 R04 | |  [✓] AUFNR | MATNR | MAKTX | WO Qty | TL Qty | Mismatch | Reason.. ||
 R05 | |  ...                                                              ||
 R06 | '-------------------------------------------------------------------'|
 R07 |                                                                       |
 R08 | Email Type:  ( ) HO Notification    ( ) Branch Notification          |
 R09 | DLI Preview: APPR_<WERKS3>_<HO|BR>                                   |
 R10 |                                                   [ Send Email ]     |
     +----------------------------------------------------------------------+
```

### 6.3 Attributes Tab

```
Short Description : Manual Email Send
Dynpro Type       : (*) Normal
Next Dynpro       : 0330
```

### 6.4 Layout — Element List

| Name          | Type           | Text / Binding              | FctCode | Line | Col | Len |
|---------------|----------------|-----------------------------|---------|------|-----|-----|
| `LB_WO`       | Text           | "Work Order:"               | -       | 1    | 1   | 12  |
| `P_WO_MAIL`   | I/O Field      | `AUFNR` → var `P_WO_MAIL`   | -       | 1    | 14  | 12  |
| `LB_PLANT`    | Text           | "Plant:"                    | -       | 1    | 30  | 7   |
| `GV_WERKS`    | I/O Field      | `WERKS_D` → var `GV_WERKS`  | -       | 1    | 38  | 6   |
| `BT_LOAD`     | Pushbutton     | Load Items                  | `LOAD`  | 1    | 50  | 18  |
| `CC_ALV_0330` | Custom Control | (ALV container)             | -       | 3    | 1   | 118 × 4 |
| `RB_HO`       | Radio Button   | HO Notification             | -       | 8    | 14  | 20  |
| `RB_BR`       | Radio Button   | Branch Notification         | -       | 8    | 40  | 22  |
| `LB_DLI`      | Text           | "DLI Preview: ..."          | -       | 9    | 1   | 60  |
| `BT_SEND`     | Pushbutton     | Send Email                  | `SEND`  | 10   | 85  | 20  |

### 6.5 Radio Button Group

Both `RB_HO` and `RB_BR` must belong to **one radio group** (e.g. `GR1`) so only one can be selected.

```
Attributes of RB_HO:
  Name        : P_EMAIL_TYPE     <-- bound to global var
  Radio group : GR1
  Value       : HO

Attributes of RB_BR:
  Name        : P_EMAIL_TYPE
  Radio group : GR1
  Value       : BR
```

> After selection, `P_EMAIL_TYPE` holds `'HO'` or `'BR'` — which the PAI module passes to `process_send_email`.

### 6.6 Custom Container Name

`CC_ALV_0330` — must match `container_name = 'CC_ALV_0330'` in `FORM init_alv_0330` (`LZFG_WO_APPROVALF07`).

### 6.7 Flow Logic

```abap
PROCESS BEFORE OUTPUT.
  MODULE status_0330.
PROCESS AFTER INPUT.
  MODULE user_command_0330.
```

### 6.8 Module Wiring — Screen 0330

| SE51 double-click on          | Direction | Include target        |
|-------------------------------|-----------|-----------------------|
| `MODULE status_0330.`         | OUTPUT    | `LZFG_WO_APPROVALO01` |
| `MODULE user_command_0330.`   | INPUT     | `LZFG_WO_APPROVALI01` |

Bodies to paste:
`@2. Function_Group/2. PBO Modules/STATUS_0330.abap` and
`@2. Function_Group/3. PAI Modules/USER_COMMAND_0330.abap`.

### 6.9 Activation Checklist

```
[✓] Ctrl+F3 on screen 0330
[✓] Activate GUI Status ZSTAT_0330 (LOAD, SEND, &BACK, &EXIT)
[✓] Activate Titlebar T330
[✓] Test: enter WO + plant → Load → ALV fills with items
[✓] Test: mark a few rows → select HO → Send → SOST shows HO email
[✓] Test: select BR → Send → SOST shows BR email
[✓] Test: no rows marked → Send → warning message
```

---

## 7. CREATE TRANSACTION `ZWOAPP` (SE93 / SE80 right-click → Create → Transaction)

### 7.1 Dialog: Create Transaction

```
 +======================== Create Transaction =================+
 | Transaction code    : ZWOAPP                                |
 | Short text          : Work Order Approval System            |
 |                                                             |
 | Start object        : (*) Program and dynpro (dialog trans) |
 +=============================================================+
```

### 7.2 Properties

```
 +--- Dialog Transaction ---------------------------------------+
 | Program ............... SAPLZFG_WO_APPROVAL                  |
 | Screen number ......... 0100                                 |
 | [✓] SAP GUI for Windows                                      |
 | [✓] SAP GUI for Java                                         |
 | [ ] SAP GUI for HTML                                         |
 | Authorization object .. ZWO_APPR  (optional, recommended)    |
 +--------------------------------------------------------------+
```

> **Program name rule:** `SAPL` + function-group-name = `SAPLZFG_WO_APPROVAL`.
> Do **NOT** use `ZFM_...` or the function group name alone.

### 7.3 Test

```
/nZWOAPP   → Screen 0100 opens
```

---

## 8. COMMON PITFALLS

| Symptom | Root Cause | Fix |
|---|---|---|
| Dump `DYNPRO_NOT_FOUND` | Screen not activated | Activate screen + flow logic |
| Dump `DYNPRO_NOT_FOUND 0301` on entry to 0300 | Subscreen 0301 not activated yet | Activate 0301 FIRST, then 0300 (§3.12) |
| Dump `CALL_SUBSCREEN_TYPE_MISMATCH` | Screen 0301 Dynpro Type = Normal instead of Subscreen | 0301 Attributes → Dynpro Type = Subscreen |
| `EXEC` pressed on subscreen but `user_command_0300` not fired | `CALL SUBSCREEN sub_header_300.` missing in 0300 PAI (or placed after the LOOP) | Put it **before** the `LOOP AT gt_items_tc` in PAI |
| Subscreen area empty, fields clipped | 0300 `SUB_HEADER_300` area smaller than 0301 canvas | Make 0300 area ≥ 75 cols × 2 rows |
| `INCLUDE statement not allowed here` syntax error | Wrote `CALL SUBSCREEN ... INCLUDING ...` in PAI | PAI uses short form only: `CALL SUBSCREEN sub_header_300.` |
| Dump `MESSAGE_TYPE_X` on PAI | FctCode on screen ≠ `WHEN` in module | Align values exactly |
| Table Control shows blank rows | `DESCRIBE TABLE ... LINES tc_items-lines` missing | Already in `status_0300` — ensure it runs |
| Reason dropdown empty | VRM ID mismatch | Column field name must be `GS_ITEMS_TC-REASON_CODE` |
| ALV on 0310/0320/0330 renders garbage on re-entry | Stale container/grid refs | Lazy-init pattern (`gv_<scr>_initialized` flag) already handles it — do not skip `free_alv_*` call |
| Radio buttons both off | Not in same group or missing initial value | Set `P_EMAIL_TYPE = 'HO'` in an INIT form; assign both radios to group `GR1` |
| TX launches empty grey screen | Wrong program in SE93 | Program must be `SAPLZFG_WO_APPROVAL` |
| L1 sees all rows on 0300 | Filter form not run | `load_wo_range_for_approval` must do `DELETE gt_items_tc WHERE is_mismatch = abap_false` when `gv_user_level = gc_user_lvl-l1` |

---

## 9. END-TO-END SMOKE TEST

```
 Tx: /nZWOAPP
    |
    v
 [Screen 0100 — Main Menu]  ──APPR──▶ [Screen 0300]
    │                       ──PEND──▶ [Screen 0310]
    │                       ──HIST──▶ [Screen 0320]
    │                       ──MAIL──▶ [Screen 0330]
    │
    ▼ F3
 Exit program
```

Per-path test:
```
APPR : enter WO range → Execute → rows load → tick + reason → Save
       → row persisted in ZTWOAPPR; header in ZTWOAPPRH
PEND : ALV lists pending WOs → double-click → 0300 opens pre-filled
HIST : ALV read-only → Reason Rejection / Reason Change columns show
MAIL : WO+plant → Load → mark rows → pick HO/BR → Send → SOST contains mail
```

---

## 10. NEXT STEPS / OPEN ITEMS

- [ ] Build screens 0100, 0300 (+ subscreen 0301), 0310, 0320, 0330 per sections 2–6
- [ ] Create GUI statuses `ZSTAT_0100..ZSTAT_0330` (buttons + F3 exit)
- [ ] Create titlebars `T100..T330`
- [ ] Create transaction `ZWOAPP` per section 7
- [ ] Assign `ZWO_APPR` auth values in PFCG roles for BCSPPD / SDH HO
- [ ] Maintain TVARVC entries `ZWO_REJECT_REASON`, `ZWO_CHANGE_REASON`
- [ ] Run smoke test of section 9

---

*End of DOCU 1.6 — Screen Tutorial*
