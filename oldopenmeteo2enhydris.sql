/*

Script to migrate from the old openmeteo (c. 2005) to enhydris. Very few
installations of old openmeteo are known to exist, so you are unlikely to need
this. But I had to migrate one, so I made it. A. Christofides, 2010-06.

How to do it:

1. First, use pg_dump to dump the old database to a file. Make these
   replacements:

    Replace            With
    ----------------   -----------------------
    FUNCTION public.   FUNCTION old_openmeteo.
    TABLE public.      TABLE old_openmeteo.
    OWNER TO ?????     OWNER TO old_openmeteo

2. Delete all REVOKE and GRANT commands at the end of the script.

3. In the beginning add

       CREATE USER old_openmeteo;

   and further below change

       SET search_path = public, pg_catalog;

   to

       CREATE SCHEMA AUTHORIZATION old_openmeteo;
       SET search_path = old_openmeteo, public, pg_catalog;

4. Create a new database and run the dumped sql in the new database as follows:

       \set ON_ERROR_STOP
       BEGIN;
       \i dumpfile
       COMMIT;

5. Install enhydris, following enhydris instructions, syncdb, migrate.

6. Run this script (as the database user as which enhydris connects):

       BEGIN;
       \i openmeteo2enhydris.sql
       COMMIT;

*/
