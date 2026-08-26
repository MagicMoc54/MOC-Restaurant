# MOC Restaurant v2.2.0 - Business Management Direct Open Fix

This replaces the silent client callback path with an explicit server request/response.

When opening Business Management:
1. Client shows `Opening Business Management...`
2. Server receives the restaurant ID.
3. Server validates/creates the owner employee record.
4. Server builds the permission profile.
5. Server pushes the profile back to the client.
6. Client renders the Business Management menu.

If the server cannot build the profile, the player receives an error notification and
txAdmin/server console receives a `[MOC Restaurant] Business Management ERROR...` line.

The physical Manager Station uses the same robust path.

No SQL changes are required for this patch.
