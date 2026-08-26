# MOC Restaurant v1.5.0 Fixed Build

This rebuild corrects two problems in the earlier packages:

1. `/mocrestaurant` is now the single restaurant administration entry point.
   Use **Open Builder** inside that menu to place registers, cooking stations,
   storage, manager locations, and drive-thru points.
2. Placement now uses a dedicated in-game placement mode. Select a location
   type, walk to the exact spot, face the desired direction, press **E**, and
   confirm. Press **BACKSPACE** to cancel.
3. The FiveM manifest has been normalized to `fx_version 'cerulean'`.
   Some earlier later-version packages incorrectly contained the release number
   in the fx_version field.

Commands:
- `/moccreate` - create a restaurant.
- `/mocrestaurant` - open administration and the builder.
- `/mocorders` - available in versions that include the order system.
