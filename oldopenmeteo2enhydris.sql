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

7. Run the script oldopenmeteo2enhydris.py for additional fixes.

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

/* instruments => Instrument */
INSERT INTO hcore_instrument(id, station_id, type_id, manufacturer, model,
    is_active, start_date, end_date, name, remarks, name_alt, remarks_alt)
    SELECT id, station,
    CASE WHEN id IN (6, 14, 24, 43, 53, 63, 73, 85, 95, 105) THEN 5
         WHEN id IN (5, 13, 23, 42, 52, 62, 72, 84, 94, 104) THEN 4
         WHEN id IN (10, 20, 30, 49, 59, 69, 81, 91, 101, 111) THEN 9
         WHEN id=79 THEN 10
         WHEN id IN (9, 18, 28, 47, 57, 67, 89, 99, 109, 77, 3, 17, 27, 46, 56, 66, 88, 98, 108) THEN 2
         WHEN id=80 THEN 11
         WHEN id IN (1, 11, 21, 40, 50, 60, 70, 82, 92, 102, 71, 2, 12, 22, 41, 51, 83, 93, 103, 61) THEN 1
         WHEN id IN (4, 19, 29, 48, 58, 68, 78, 90, 100, 110) THEN 3
         WHEN id IN (8, 16, 26, 45, 55, 65, 87, 97, 107, 75) THEN 7
         WHEN id=76 THEN 8
         WHEN id IN (7, 15, 25, 44, 54, 64, 86, 96, 106, 74) THEN 6
         END,
    '', '', instrument_active, NULL, NULL, name_en, '', '', ''
    FROM old_openmeteo.vinstruments;

/* munits => UnitOfMeasurement */
INSERT INTO hcore_unitofmeasurement (id, symbol, descr, descr_alt)
    SELECT id, symbol, name_en, '' FROM old_openmeteo.vmunits;

/* vars => Variable */
INSERT INTO hcore_variable(id, descr, descr_alt)
    SELECT id, descr_en, '' FROM old_openmeteo.vvars;

/* variables to units correspondence made manually, as old openmeteo didn't
 * have it.
 */
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (1, 1);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (2, 2);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (3, 3);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (4, 4);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (4, 9);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (4, 10);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (5, 5);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (6, 6);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (7, 6);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (8, 7);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (9, 8);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (10, 4);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (10, 9);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (10, 10);
 
/* timeseries => Timeseries */
/* Note: we lose tinterval_type because the enhydris doesn't have it
 * (https://openmeteo.org/code/ticket/4)
 */
INSERT INTO hcore_timezone (id, code, utc_offset) VALUES (1, 'EET', 120);
INSERT INTO hcore_timestep (id, descr, descr_alt, length_minutes, length_months)
    VALUES (1, '10-minute', '', 10, 0);
INSERT INTO hcore_timestep (id, descr, descr_alt, length_minutes, length_months)
    VALUES (2, 'Hourly', '', 60, 0);
INSERT INTO hcore_timestep (id, descr, descr_alt, length_minutes, length_months)
    VALUES (3, 'Daily', '', 1440, 0);
INSERT INTO hcore_timestep (id, descr, descr_alt, length_minutes, length_months)
    VALUES (4, 'Monthly', '', 0, 1);
INSERT INTO hcore_timestep (id, descr, descr_alt, length_minutes, length_months)
    VALUES (5, 'Annual', '', 0, 12);
INSERT INTO hcore_timeseries
    (id, gentity_id, variable_id, unit_of_measurement_id, precision, name,
    time_zone_id, remarks, instrument_id, time_step_id, nominal_offset_minutes,
    nominal_offset_months, actual_offset_minutes, actual_offset_months)
    SELECT t.id, t.gentity, t.var, t.munit, t.precision, t.name_en, 1,
    t.remarks_en, t.instrument, st.id, CASE WHEN t.strict THEN 0 ELSE NULL END,
    CASE WHEN t.strict THEN 0 ELSE NULL END,
    CASE WHEN st.length_months>0 THEN -60 ELSE 0,/* Hardwire 1 month, -1 hours actual offset in */
    CASE WHEN st.length_months>0 THEN 1 ELSE 0   /* monthly and annual timeseries; see ticket #143 */
    FROM old_openmeteo.vtimeseries t
    LEFT JOIN hcore_timestep st ON 
        (t.tstep_unit=1 AND st.length_minutes=t.length AND st.length_months=0) OR
        (t.tstep_unit=2 AND st.length_minutes=0 AND st.length_months=t.length);

/* timeseries data */
INSERT INTO ts_records (id, top, middle, bottom)
    SELECT id, COALESCE(top, ''), middle, bottom FROM old_openmeteo.timeseries_records;

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

COMMIT;
