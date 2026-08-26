# MOC Restaurant v2.2.0 - Business Management Fallback

This build adds a Business Management option directly to `/mocrestaurant`.

## Why
Previously, owners/managers could only open the employee/business portal by
standing at a placed Manager Station. If no Manager Station existed, there was
no prompt and no fallback route into the management system.

## New access path
`/mocrestaurant`
-> `Business Management`
-> Select Restaurant
-> Employee / Business Management

The physical Manager Station is still supported and remains the immersive
in-world access point.

## Permissions
Opening the fallback does not bypass MOC Restaurant's server-side permissions.
Owners/admins still receive their allowed options, and unauthorized users do
not gain management abilities.

No SQL update is required for this fix.
