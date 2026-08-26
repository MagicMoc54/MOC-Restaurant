# Changelog

## v3.3.6 — Stable Release — Interaction Mode Removed

- Removed the per-restaurant prompt/qb-target experiment and returned to the known-working [E] prompt flow.
- Declared stable release baseline.

## v3.3.5 — Remove Legacy POS Fallback

- Removed all legacy/default POS fallbacks; Menu Management became the single POS source of truth.

## v3.3.4 — Definitive POS Delete Fix

- Added removable Existing Menu Items and verified exact POS database-row deletion.

## v3.3.3 — POS Delete Sync Fix

- Focused POS delete synchronization patch.

## v3.3.2 — POS Menu Sync Fix

- Made the POS open path use the restaurant-specific live menu.

## v3.3.1 — POS / Navigation / Interaction / Recipe Upgrade

- Added POS/menu sync, navigation work, interaction-mode experiment, and richer recipe requirements.

## v3.3.0 — Custom Restaurant Blips

- Added in-game restaurant blip sprite, color, scale, and position configuration.

## v3.2.4 — Duplicate Kitchen Prompt Fix

- Disabled duplicate legacy kitchen interaction prompt; one production prompt remains.

## v3.2.3 — Recipe Visibility Fix

- Fixed restaurant recipe visibility at physical kitchen stations.

## v3.2.2 — Menu Management Open Fix

- Rebuilt Menu Management open path using explicit server request/response.

## v3.2.1 — Clean Kitchen Production

- Retired Ingredient Supplier and introduced restaurant-specific kitchen production.

## v3.2.0 — Restaurant-Specific Menus

- Added restaurant-specific menu and recipe data.

## v3.1.3 — Ingredient Supplier Native Prompt Fix

- Moved Ingredient Supplier to a native prompt for conflict isolation.

## v3.1.2 — Ingredient Supplier Config Fix

- Cleaned malformed Config.LocationTypes affecting the supplier.

## v3.1.1 — Ingredient Supplier Prompt Fix

- Repaired Ingredient Supplier prompt path.

## v3.1.0 — Ingredient Supplier

- Introduced Ingredient Supplier experiment.

## v3.0.0 — Production Polish

- Production polish and startup diagnostics.

## v2.3.0 — Advanced Features Foundation

- Advanced-feature foundation while preserving the stable v2.2.9 business/delivery branch.

## v2.2.9 — Delivery Receiving Builder Fix

- Added Delivery Receiving as a builder-placeable station.

## v2.2.8 — Delivery Receive Fix

- Rebuilt delivery receiving with explicit request/confirmation and diagnostics.

## v2.2.7 — Explicit Clock In/Out

- Replaced toggle duty logic with explicit Clock In and Clock Out actions.

## v2.2.6 — Automatic QBCore + qb-banking Setup

- Added automatic runtime QBCore job and qb-banking account setup.

## v2.2.5 — Clock Display + Business Account Fix

- Fixed clock display and added in-game Business Account / Job Setup.

## v2.2.4 — Clock + Delivery Fix

- Normalized boolean clock state and embedded delivery callbacks into the proven Business Management server path.

## v2.2.3 — Delivery Callback Fix

- Repaired missing delivery callback registration.

## v2.2.2 — Clock In/Out Fix

- Repaired clock state saving and Business Management refresh.

## v2.2.1 — Complete Deliveries & Restocking

- Completed playable Deliveries & Restocking with business-account purchasing and Delivery Receiving.

## v2.2.0 — Deliveries & Restocking Foundation

- Added deliveries/restocking database and configuration foundation.

## v2.1.0 — Creator Expansion + Business Direct Fix

- Expanded restaurant creator data and added reliable direct Business Management access.

## v2.0.1 — Complete Business Management

- Completed the usable Business Management interface and owner/employee workflow.

## v2.0.0 — Business Management

- Introduced Business Management, employees, ranks, payroll, and sales foundation.

## v1.9.0 — Animations & Immersion

- Added animation and immersion improvements.

## v1.8.0 — Drive-Thru

- Added drive-thru workflow.

## v1.7.0 — Trays & Bags

- Added trays/bags and order packaging workflow.

## v1.6.0 — Kitchen Display

- Improved kitchen display/interactions.

## v1.5.5 — Per-Station Interaction Radius

- Added configurable per-station interaction radius to prevent nearby station conflicts.

## v1.5.4 — POS & Storage Fix

- Stabilized POS and storage behavior.

## v1.5.3 — POS Diagnostics

- Added POS diagnostics and repaired POS startup/open behavior.

## v1.5.2 — POS UI Reliability Fix

- Additional POS UI reliability fixes.

## v1.5.1 — POS UI Fix

- Focused POS user-interface repair.

## v1.5.0 — Advanced POS

- Expanded the POS experience and advanced register workflow.

## v1.4.0 — Storage & Inventory

- Added restaurant storage and inventory support.

## v1.3.1 — Kitchen Crafting Hotfix

- Hotfix release for kitchen crafting behavior.

## v1.3.0 — Kitchen Crafting

- Added kitchen crafting and production stations.

## v1.2.0 — POS & Orders

- Added POS/register ordering foundation and restaurant orders.

## v1.1.0 — In-Game Restaurant Builder

- Added the in-game restaurant creation/builder workflow.

## v1.0.0 — Core Foundation

- Initial MOC Restaurant framework and database foundation.
