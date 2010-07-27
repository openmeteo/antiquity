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

       \i oldopenmeteo2enhydris.sql

*/

\set ON_ERROR_STOP
BEGIN TRANSACTION;
SET CONSTRAINTS ALL DEFERRED;

/* Temporary function */
CREATE FUNCTION update_sequence (sequence_name TEXT, table_name TEXT)
RETURNS void AS $$
DECLARE
    nextid INTEGER;
BEGIN
    EXECUTE 'SELECT coalesce(max(id), 0)+1 FROM '||table_name
                                                            INTO STRICT nextid;
    EXECUTE 'ALTER SEQUENCE '||sequence_name||' RESTART WITH '||nextid;
END
$$ LANGUAGE plpgsql;

/* Countries => PoliticalDivision */
/* descr has a value of up to 245, so let's use it as the gentity id. */
INSERT INTO hcore_gentity(id, name, short_name, remarks, name_alt,
    short_name_alt, remarks_alt)
    SELECT descr, descr_en, descr_en, '', '', '', ''
    FROM old_openmeteo.vcountries;
INSERT INTO hcore_garea(gentity_ptr_id)
    SELECT descr FROM old_openmeteo.vcountries;
INSERT INTO hcore_politicaldivision(garea_ptr_id, parent_id, code)
    SELECT descr, NULL, lower(code) FROM old_openmeteo.vcountries;


/* Update sequences */
SELECT update_sequence('hcore_instrumenttype_id_seq', 'hcore_instrumenttype');
SELECT update_sequence('hcore_gentity_id_seq', 'hcore_gentity');
SELECT update_sequence('hcore_lentity_id_seq', 'hcore_lentity');
SELECT update_sequence('hcore_stationtype_id_seq', 'hcore_stationtype');
SELECT update_sequence('hcore_timestep_id_seq', 'hcore_timestep');
SELECT update_sequence('hcore_variable_id_seq', 'hcore_variable');
SELECT update_sequence('hcore_timezone_id_seq', 'hcore_timezone');
SELECT update_sequence('hcore_unitofmeasurement_id_seq', 'hcore_unitofmeasurement');
SELECT update_sequence('hcore_timeseries_id_seq', 'hcore_timeseries');
SELECT update_sequence('hcore_instrument_id_seq', 'hcore_instrument');
DROP FUNCTION update_sequence (sequence_name TEXT, table_name TEXT);

ROLLBACK;
