# SAP List Tree Control Demo

## Purpose

This sample demonstrates how to build a classic ABAP module pool application around the CL_GUI_LIST_TREE control inside a custom container.

It is useful as a reusable pattern for agents because it shows the full lifecycle of a list tree demo:

- screen setup and module pool flow
- container creation
- tree creation and registration
- node and item table construction
- event handler wiring
- lazy loading of child nodes
- cleanup on exit

## What This Sample Proves

The program is not a business application. It is a control sample that proves the following technical points:

- a tree can be embedded into a custom control on screen 100
- the application can register tree events and react in ABAP Objects methods
- tree data can be built from node and item tables
- nodes can be added later when a branch is expanded
- the demo can be closed safely by freeing the frontend container

## Main Objects

| Object | Role | Notes |
| --- | --- | --- |
| SAPTLIST_TREE_CONTROL_DEMO | Main report | Starts the demo, includes all source parts, creates the application object, and opens screen 100 |
| TLIST_TREE_CONTROL_DEMOTOP | Global declarations | Holds global references, screen fields, and node key constants |
| TLIST_TREE_CONTROL_DEMOCL1 | Local event class | Implements the event handlers for the tree control |
| TLIST_TREE_CONTROL_DEMOO01 | PBO module | Creates the tree on first display and sets the GUI status |
| TLIST_TREE_CONTROL_DEMOI01 | PAI module | Dispatches control events and handles exit logic |
| TLIST_TREE_CONTROL_DEMOF01 | Form routines | Builds the node and item tables and creates the tree |
| 0100.abap | Screen flow | Defines the screen process logic for screen 100 |

## Global State

The demo relies on a small set of global variables that carry control state across PBO and PAI:

- G_APPLICATION is the local application object that owns the event handlers.
- G_CUSTOM_CONTAINER is the custom container that hosts the tree control.
- G_TREE is the CL_GUI_LIST_TREE instance.
- G_OK_CODE stores the user command from screen 100.
- G_EVENT stores the last tree event name.
- G_NODE_KEY stores the key of the node that triggered the event.
- G_ITEM_NAME stores the item name that triggered the event.

The sample also defines a constant structure for node keys:

- root
- child1
- child2
- new1
- new2
- new3
- new4

These keys are used consistently across the node table, item table, and event handlers.

## Runtime Flow

1. The report starts in START-OF-SELECTION.
2. The application object is created.
3. Screen 100 is called with SET SCREEN 100.
4. PBO runs and sets PF-STATUS MAIN.
5. On the first screen cycle, the tree is created inside the custom control TREE_CONTAINER.
6. The tree registers the supported frontend events.
7. The application class methods are attached as handlers for those events.
8. Initial nodes and items are inserted into the tree.
9. When the user interacts with the tree, CL_GUI_CFW=>DISPATCH sends the control event to the ABAP handler.
10. Back frees the custom container and exits the program.

## Screen 100 Behavior

Screen 100 is the only user-facing screen in the sample.

PBO responsibilities:

- set the application toolbar/status with MAIN
- create the tree once if it does not yet exist
- avoid re-creating the control on every roundtrip

PAI responsibilities:

- dispatch frontend control events before normal OK-code processing
- ignore normal flow when the control already handled the event
- free the tree and container on BACK

The screen uses a custom control placeholder named TREE_CONTAINER. That control is the host for the tree frontend object.

## Tree Setup

The tree is created with CL_GUI_LIST_TREE and configured as a single-selection list tree with item selection enabled.

Important configuration points:

- the parent is the custom container
- node selection mode is single
- item selection is turned on
- headers are suppressed

The tree is then registered for these events:

- node double click
- item double click
- expand no children
- link click
- button click
- checkbox change

Each event is marked as an application event so it is sent back to PAI and handled in ABAP code.

## Event Handling Map

| Event | Handler | Stored Data | Behavior |
| --- | --- | --- | --- |
| NODE_DOUBLE_CLICK | HANDLE_NODE_DOUBLE_CLICK | G_EVENT, G_NODE_KEY | Records the node key and clears the item name |
| ITEM_DOUBLE_CLICK | HANDLE_ITEM_DOUBLE_CLICK | G_EVENT, G_NODE_KEY, G_ITEM_NAME | Records both the node key and item name |
| LINK_CLICK | HANDLE_LINK_CLICK | G_EVENT, G_NODE_KEY, G_ITEM_NAME | Records the clicked link context |
| BUTTON_CLICK | HANDLE_BUTTON_CLICK | G_EVENT, G_NODE_KEY, G_ITEM_NAME | Records the clicked button context |
| CHECKBOX_CHANGE | HANDLE_CHECKBOX_CHANGE | G_EVENT, G_NODE_KEY, G_ITEM_NAME | Records the checkbox change context |
| EXPAND_NO_CHILDREN | HANDLE_EXPAND_NO_CHILDREN | G_EVENT, G_NODE_KEY | Adds child nodes dynamically when Child2 is expanded |

The first five handlers only update the global screen fields so the user can see what was clicked.

The expand handler is different: it builds additional nodes and items and inserts them into the tree at runtime.

## Tree Hierarchy

The sample tree is intentionally small so the structure is easy to read and reuse.

Root node:

- Objekte

First branch:

- Dynpros
	- New1
		- item 1: icon
		- item 2: 0100
		- item 3: MUELLER
		- item 4: Kommentar zu Dynpro 100
	- New2
		- item 1: icon
		- item 2: 0200
		- item 3: HARRYHIRSCH
		- item 4: Kommentar zu Dynpro 200

Second branch:

- Programme
	- New3 is added later on expand
	- New4 is added later on expand

Child2 is created as an expander node. It is visible as a node that can be opened even though no child nodes are loaded initially.

## Lazy Loading Behavior

The demo uses EXPAND_NO_CHILDREN to show how a tree can load content on demand.

When the user expands Child2:

- the event handler checks whether the node key is Child2
- two child nodes are created: New3 and New4
- items are attached to both nodes
- the new entries are passed to ADD_NODES_AND_ITEMS

This pattern is important because it demonstrates that the tree frontend does not have to be fully populated up front.

## Node and Item Construction Rules

The node table and item table are built in a fixed sequence.

Node table rules:

- root nodes are inserted first
- child nodes must never appear before their parents
- the relation key and relationship type define the tree hierarchy
- folder nodes use ISFOLDER = X
- Child2 uses EXPANDER = X to force lazy loading behavior

Item table rules:

- each item is linked to a node key
- ITEM_NAME identifies which logical cell on the node is being filled
- text items use ITEM_CLASS = ITEM_CLASS_TEXT
- some items use background highlighting and proportional fonts
- MTREEITM is the structure expected by the tree control

## Forms And Methods

CREATE_AND_INIT_TREE is responsible for the full frontend setup.

It performs the following steps:

- create the custom container
- create the tree control
- register frontend events
- connect handler methods
- build the sample node and item data
- insert the data into the tree

BUILD_NODE_AND_ITEM_TABLE builds the initial hierarchy and the visible text items.

HANDLE_EXPAND_NO_CHILDREN adds the additional branch for Child2 on demand.

The remaining event methods only capture the last user action and write it to the screen fields.

## Cleanup And Exit

The BACK command is the only explicit exit path in this sample.

During cleanup:

- the custom container is freed
- the tree reference is cleared
- the program leaves cleanly

This is important because the tree lives inside a frontend container and should be released when the screen closes.

## Reusable Agent Notes

Use this sample as a reference when you need one of the following patterns:

- a module pool with a custom control host
- a tree control built from tables rather than hardcoded nested UI logic
- a local ABAP Objects event handler class for frontend events
- a lazy-loading node expansion example
- a minimal cleanup pattern for a control-based dynpro

If you reuse the sample in a new program, keep these rules in mind:

- create the application object before the first screen call
- create the tree only once in PBO
- always call CL_GUI_CFW=>DISPATCH in PAI when control events are registered
- store your business data separately if you need it later
- preserve parent-before-child ordering when building the node table

## Quick Reading Guide For Agents

If an agent needs to understand this demo fast, read in this order:

1. Purpose
2. Main Objects
3. Runtime Flow
4. Tree Setup
5. Event Handling Map
6. Lazy Loading Behavior
7. Cleanup And Exit

That reading order gives the control flow first and the reusable implementation details second.

## Short Summary

This demo shows how to create a classic SAP list tree in a custom container, register and handle frontend tree events in ABAP Objects, and add child nodes dynamically when a branch is expanded. It is a compact reusable reference for module pool screen flow, control setup, and event-driven tree interaction.
