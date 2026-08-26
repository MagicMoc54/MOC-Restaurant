# Upgrading MOC Restaurant

MOC Restaurant was developed incrementally. For the safest upgrade path:

1. Back up the resource and database.
2. Read the target release's `RELEASE_NOTES.md` / `Fix Notes`.
3. Apply applicable SQL upgrades in version order.
4. Replace the resource.
5. Restart.
6. Test that version before moving to the next release.

The stable baseline produced by this development cycle is **v3.3.6**.
