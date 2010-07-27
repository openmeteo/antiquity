/*

Script to migrate from the old openmeteo (c. 2005) to enhydris. Very few
installations of old openmeteo are known to exist, so you are unlikely to need
this. But I had to migrate one, so I made it.

Note that the script does not do a migration that is correct in all cases, but
only a migration appropriate for the one installation that I had to migrate.
So some object types might not be migrated (because that installation does not
have them), and some peculiarities of that installation are hardwired in the
migration script.

A. Christofides, 2010-06.

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

/* Countries => PoliticalDivision 
 * descr has a value of up to 245, so let's use 100 plus that as the gentity
 * id. This is in order to leave the first few ids free for stations (so that
 * they keep the same id as in the old database, as they are only 11.
 */
INSERT INTO hcore_gentity(id, name, short_name, remarks, name_alt,
    short_name_alt, remarks_alt)
    SELECT 100+descr, descr_en, descr_en, '', '', '', ''
    FROM old_openmeteo.vcountries;
INSERT INTO hcore_garea(gentity_ptr_id)
    SELECT 100+descr FROM old_openmeteo.vcountries;
INSERT INTO hcore_politicaldivision(garea_ptr_id, parent_id, code)
    SELECT 100+descr, NULL, lower(code) FROM old_openmeteo.vcountries;

/* People => Person */
INSERT INTO hcore_lentity(id, remarks, remarks_alt)
    SELECT id, '', '' FROM old_openmeteo.vpeople;
INSERT INTO hcore_person(lentity_ptr_id, last_name, first_name, middle_names,
    initials, last_name_alt, first_name_alt, middle_names_alt, initials_alt)
    SELECT id, last_name_en, first_names_en, '', '', '', '', '', ''
    FROM old_openmeteo.vpeople;

/* stypes => StationType */
INSERT INTO hcore_stationtype(id, descr, descr_alt)
    SELECT id, descr_en, '' FROM old_openmeteo.vstypes;

/* Stations => Station 
 * We put the location description in remarks, because we don't have a location
 * description field.
 */
INSERT INTO hcore_gentity(id, water_basin_id, water_division_id,
    political_division_id, name, short_name, remarks, name_alt, short_name_alt,
    remarks_alt)
    SELECT s.id, NULL, NULL, 187, g.string, g.string, s.address_en, s.name_en,
    s.name_en, ''
    FROM old_openmeteo.vstations s
    LEFT JOIN old_openmeteo.string_contents g ON g.language='gr'
                                                            AND g.id=s.name;
INSERT INTO hcore_gpoint(gentity_ptr_id, abscissa, ordinate, srid, approximate,
    altitude, asrid)
    SELECT id, x, y, 2100, False, altitude, NULL
    FROM old_openmeteo.vstations;
INSERT INTO hcore_station(gpoint_ptr_id, owner_id, type_id, is_active,
    is_automatic, start_date, end_date)
    SELECT id, owner, stype, station_active, telemetry, NULL, NULL
    FROM old_openmeteo.vstations;

/* Manually create InstrumentType, as old openmeteo does not have equivalent. */
INSERT INTO hcore_instrumenttype(id, descr, descr_alt) VALUES( 1, 'Rainfall sensor', '');
INSERT INTO hcore_instrumenttype(id, descr, descr_alt) VALUES( 2, 'Solar radiation sensor', '');
INSERT INTO hcore_instrumenttype(id, descr, descr_alt) VALUES( 3, 'Sunshine duration sensor', '');
INSERT INTO hcore_instrumenttype(id, descr, descr_alt) VALUES( 4, 'Air temperature sensor', '');
INSERT INTO hcore_instrumenttype(id, descr, descr_alt) VALUES( 5, 'Humidity sensor', '');
INSERT INTO hcore_instrumenttype(id, descr, descr_alt) VALUES( 6, 'Wind velocity sensor', '');
INSERT INTO hcore_instrumenttype(id, descr, descr_alt) VALUES( 7, 'Wind direction sensor', '');
INSERT INTO hcore_instrumenttype(id, descr, descr_alt) VALUES( 8, 'Wind velocity and direction sensor', '');
INSERT INTO hcore_instrumenttype(id, descr, descr_alt) VALUES( 9, 'Battery sensor', '');
INSERT INTO hcore_instrumenttype(id, descr, descr_alt) VALUES(10, 'Evaporation sensor', '');
INSERT INTO hcore_instrumenttype(id, descr, descr_alt) VALUES(11, 'Air pressure sensor', '');

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
