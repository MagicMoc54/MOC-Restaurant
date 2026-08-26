# Installation

1. Back up your FiveM server files and database.
2. Place `moc_restaurant` inside your resources folder.
3. Ensure the resource dependencies used by your configuration are started before MOC Restaurant.
4. Review `moc_restaurant/sql/`.
5. For a fresh install, use the base SQL supplied by the resource/version you are installing.
6. For an upgrade, run only the SQL upgrade files required between your current version and target version.
7. Add `ensure moc_restaurant` to your server configuration if it is not already started elsewhere.
8. Restart the resource/server and perform a functional test before upgrading further.

Do not skip backups when changing database schema.
