# MOC Restaurant v3.2.1 - Final LocationTypes Fix

This build permanently cleans the `Config.LocationTypes` section.

The final placeable types include:
- Register
- Grill
- Fryer
- Prep Station
- Drink Station
- Dry Storage
- Freezer
- Tray Pickup
- Manager Station
- Drive-Thru Speaker
- Drive-Thru Payment Window
- Drive-Thru Pickup Window
- Delivery Receiving

Ingredient Supplier is intentionally removed because that feature was retired in
favor of Deliveries & Restocking.

Diagnostic command:
`moclocationtypescheck`

Expected:
- Delivery Receiving present: true
- Ingredient Supplier present: false
- No DUPLICATE location-type lines

No SQL update is required for this fix.
