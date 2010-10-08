/*

Script to migrate from the hydria (odysseus, c. 2005) to enhydris.
It works on hydria version 6.0.2 (c. 2009)

Based on script oldopenmeteo2enhydris by A. Christofides, 2010-06.
Adaptation for hydria by S. Kozanis 2010-09

How to do it:

1. First, use pg_dump to dump the old database to a file. Dump only
   the 'hydro' schema not the old_hydro. Make these
   replacements:

    Replace            With
    ----------------   -----------------------
    FUNCTION hydro.   FUNCTION hydria.
    TABLE hydro.      TABLE hydria.
    OWNER TO ?????    OWNER TO hydria

2. Delete all REVOKE and GRANT commands at the end of the script.

3. In the beginning add

       CREATE USER hydria;

   delete CREATE SCHEMA hydro and ALTER SCHEMA hydro ... lines

   and further below change

       SET search_path = hydro, pg_catalog;

   to

       CREATE SCHEMA AUTHORIZATION hydria;
       SET search_path = hydria, public, pg_catalog;

4. Create a new database and run the dumped sql in the new database as follows:

       \set ON_ERROR_STOP
       BEGIN;
       \i dumpfile
       COMMIT;

    This will import the old database schema (hydria). You can browse
    the imported database by explicit specify schema:
    SELECT hydria.table.... or by
    SET search_path TO hydria;

5. Install enhydris, following enhydris instructions, syncdb, migrate.

6. Run import_hydria_gentityfiles.py script to import gentity file.
   Copy files under enhydris/site-media/gentityfile
   If you want to move the files to another directory instead of
   gentityfile, maybe some modifications should be done in scripts.

   Then run import_hydria_curves.py script to import generic
   data such as curves.

7. Import political and  water divisions from an export file. Run then 
   this script (as the database user as which enhydris connects):
   
       \i hydroscope_divisions.sql
       \i hydria2enhydris.sql
   (ensure first that the search_path is set to public)

8. Run the script hydria2enhydris_fix_nominaloffset.py for additional fixes.

9. Finally run import_hydria_curves.py script to import curves data.


NOTES

In the new design of hcore_timeseries, unit_of_measurement is a not
null key. In the old design the unit was allowed to be null. It is
good to set not null values on unit before migration. As an ugly
solution, all null values are imported as a 'not set' item with
id=1001.

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

CREATE FUNCTION addto_remarks (remark TEXT, label TEXT, value TEXT) RETURNS TEXT AS $$
DECLARE
    aresult TEXT;
    BEGIN
        aresult = NULL;
        IF not remark is NULL or remark = '' THEN
            aresult = remark || E'\n';
        END IF;
        IF not value IS NULL THEN
            aresult = aresult ||label||': '||value;
        END IF;
        RETURN aresult;
    END;
$$ LANGUAGE plpgsql;





/********************************************************************/
/*    P A R T   1:  L E N T I T I E S   ,   G E N E R I C S         */
/********************************************************************/

/* Services -> Organizations */
INSERT INTO hcore_lentity(id, remarks, remarks_alt)
    SELECT id, '', '' FROM hydria.services;
INSERT INTO hcore_Organization(lentity_ptr_id, name, acronym,
    name_alt, acronym_alt)
    SELECT id, COALESCE(descr, ''), COALESCE(short_descr, ''), 
        COALESCE(descr_en, ''), COALESCE(short_descr_en, '') 
        FROM hydria.services;





/********************************************************************/
/*    P A R T   2:  G E N T I T I E S                               */
/********************************************************************/

/* GENERIC GENTITIES SECTION */

--Fill data into GentityAltCodeType lookup table
COPY hcore_gentityaltcodetype (id, descr, descr_alt, original_id, original_db_id, last_modified) FROM stdin;
1	Κωδικός υπηρεσίας	Service code	\N	\N	\N
2	Υπ.Αν.	MIET	\N	\N	\N
3	Υδροσκόπιο	Hydroscope	\N	\N	\N
4	WMO	WMO	\N	\N	\N
5	Άλλος	Other	\N	\N	\N
\.

--Import gentities for stations, basins
INSERT INTO hcore_gentity(id, water_basin_id, water_division_id,
    political_division_id, name, short_name, remarks, name_alt, short_name_alt,
    remarks_alt)
    SELECT id+1000, NULL, NULL, NULL, COALESCE(name::varchar(200), ''), 
        COALESCE(descr::varchar(50),''), 
        COALESCE(remarks, ''), COALESCE(name_en, ''), COALESCE(descr_en, ''),
        COALESCE(remarks_en, '') 
        FROM hydria.gentities
        WHERE terminal_subtable='stations' OR terminal_subtable='basins';

--Set prefecture from gentities_real to the appropriate
--political_division property
UPDATE hcore_gentity h
    SET political_division_id = 
        CASE WHEN g.prefecture=2 THEN 453
            WHEN g.prefecture=1 THEN 406 WHEN g.prefecture=3 THEN 402 WHEN g.prefecture=4 THEN 407
            WHEN g.prefecture=5 THEN 405 WHEN g.prefecture=6 THEN 403 WHEN g.prefecture=7 THEN 404
            WHEN g.prefecture=11 THEN 409 WHEN g.prefecture=12 THEN 410 WHEN g.prefecture=13 THEN 413
            WHEN g.prefecture=14 THEN 414 WHEN g.prefecture=15 THEN 408 WHEN g.prefecture=16 THEN 411
            WHEN g.prefecture=17 THEN 412 WHEN g.prefecture=21 THEN 448 WHEN g.prefecture=22 THEN 445
            WHEN g.prefecture=23 THEN 447 WHEN g.prefecture=24 THEN 446 WHEN g.prefecture=31 THEN 422
            WHEN g.prefecture=32 THEN 420 WHEN g.prefecture=33 THEN 419 WHEN g.prefecture=34 THEN 421
            WHEN g.prefecture=41 THEN 418 WHEN g.prefecture=42 THEN 415 WHEN g.prefecture=43 THEN 416
            WHEN g.prefecture=44 THEN 417 WHEN g.prefecture=51 THEN 426 WHEN g.prefecture=52 THEN 435
            WHEN g.prefecture=53 THEN 430 WHEN g.prefecture=54 THEN 427 WHEN g.prefecture=55 THEN 436
            WHEN g.prefecture=56 THEN 423 WHEN g.prefecture=57 THEN 428 WHEN g.prefecture=58 THEN 425
            WHEN g.prefecture=59 THEN 429  WHEN g.prefecture=61 THEN 431 WHEN g.prefecture=62 THEN 434
            WHEN g.prefecture=63 THEN 424 WHEN g.prefecture=64 THEN 432 WHEN g.prefecture=71 THEN 437
            WHEN g.prefecture=72 THEN 439 WHEN g.prefecture=73 THEN 438 WHEN g.prefecture=81 THEN 444
            WHEN g.prefecture=82 THEN 440 WHEN g.prefecture=83 THEN 441 WHEN g.prefecture=84 THEN 443
            WHEN g.prefecture=85 THEN 442 WHEN g.prefecture=91 THEN 451 WHEN g.prefecture=92 THEN 452
            WHEN g.prefecture=93 THEN 450 WHEN g.prefecture=94 THEN 449
        END
    FROM hydria.gentities_real g WHERE g.id+1000=h.id;

--Import gpoints such as stations
INSERT INTO hcore_gpoint(gentity_ptr_id, abscissa, ordinate, srid, approximate,
    altitude, asrid)
    SELECT id+1000, x, y, 2100, False, alt, NULL
    FROM hydria.gentities WHERE terminal_subtable='stations';

--Water basins from gpoints to gentities
UPDATE hcore_gentity h
    SET water_basin_id = p.basin+1000
    FROM hydria.gpoints p, hydria.gentities g
    WHERE h.id=g.id+1000 AND p.id=g.id;

--Import gareas such as basins
INSERT INTO hcore_garea(gentity_ptr_id, area)
    SELECT a.id+1000, a.area FROM hydria.gareas a, hydria.gentities g
    WHERE g.id=a.id AND g.terminal_subtable='basins';

--gentities_real location is imported in the gentity remarks
UPDATE hcore_gentity h
    SET (remarks, remarks_alt) =
        (addto_remarks(h.remarks, 'Τοποθεσία', g.location),
        addto_remarks(h.remarks_alt, 'Location', g.location_en))
    FROM hydria.gentities_real g WHERE g.id+1000=h.id;

--gentities_real municipality is imported in the gentity remarks
UPDATE hcore_gentity h
    SET (remarks, remarks_alt) =
        (addto_remarks(h.remarks, 'Δήμος', g.municipality),
        addto_remarks(h.remarks_alt, 'Municipality', g.municipality_en))
    FROM hydria.gentities_real g WHERE g.id+1000=h.id;



/* STATIONS SECTION */

--Import station type lookup table
INSERT INTO hcore_stationtype(id, descr, descr_alt)
    SELECT id, COALESCE(descr,''), COALESCE(descr_en,'') FROM hydria.stypes;

--Import stations to hcore_station, use one of ssubtype or stype, the
--first not null.
INSERT INTO hcore_station(gpoint_ptr_id, owner_id, type_id, is_active,
    is_automatic, start_date, end_date)
    SELECT id+1000, service, COALESCE(ssubtype, stype), station_active,
    telemetry, start_date, end_date 
    FROM hydria.stations;

--In the following lines all the stations alternate codes are
--imported , use the sequence to obtain new ids
INSERT INTO hcore_gentityaltcode(gentity_id, type_id, value)
    SELECT id+1000, 1, service_code
    FROM hydria.stations WHERE service_code IS NOT NULL;
INSERT INTO hcore_gentityaltcode(gentity_id, type_id, value)
    SELECT id+1000, 2, miet_code
    FROM hydria.stations WHERE miet_code IS NOT NULL;
INSERT INTO hcore_gentityaltcode(gentity_id, type_id, value)
    SELECT id+1000, 3, hydroscope_code
    FROM hydria.stations WHERE hydroscope_code IS NOT NULL;
INSERT INTO hcore_gentityaltcode(gentity_id, type_id, value)
    SELECT id+1000, 4, wmo_code
    FROM hydria.stations WHERE wmo_code IS NOT NULL;
INSERT INTO hcore_gentityaltcode(gentity_id, type_id, value)
    SELECT id+1000, 5, other_code
    FROM hydria.stations WHERE other_code IS NOT NULL;

/*stations.observer is imported as remark. Administration could
  set then a overseer property based on the observer as stated
  in the remarks.
*/
UPDATE hcore_gentity h
    SET (remarks, remarks_alt) =
        (addto_remarks(h.remarks, 'Παρατηρητής', s.observer),
        addto_remarks(h.remarks_alt, 'Observer', s.observer_en))
    FROM hydria.stations s WHERE s.id+1000=h.id;



/* WATER BASINS SECTION */

--Import data from basins
INSERT INTO hcore_waterbasin(garea_ptr_id, parent_id, water_division_id)
    SELECT id+1000, parent+1000, NULL FROM hydria.basins;

INSERT INTO hcore_gentityaltcode(gentity_id, type_id, value)
    SELECT id+1000, 2, miet_code
    FROM hydria.basins WHERE miet_code IS NOT NULL;

UPDATE hcore_gentity h
    SET water_division_id = b.water_district+500
    FROM hydria.basins b
    WHERE b.id+1000=h.water_basin_id;

UPDATE hcore_waterbasin h 
    SET water_division_id = b.water_district+500
    FROM hydria.basins b
    WHERE b.id+1000=h.garea_ptr_id;



/* GENTITY EVENTS SECTION */

--Import lookup table
INSERT INTO hcore_eventtype(id, descr, descr_alt)
    SELECT id, COALESCE(descr, ''), COALESCE(descr_en, '') 
    FROM hydria.gevent_types;

--Import events, use the sequence to obtain ids
INSERT INTO hcore_gentityevent(gentity_id, date, type_id, "user", report, report_alt)
    SELECT id+1000, event_date, event_type,
    COALESCE(event_user, ''), COALESCE(report, ''),
    COALESCE(report_en, '') FROM hydria.gentities_events;



/* GENTITY FILES SECTION */

--Import ftypes to filetype lookup table
INSERT INTO hcore_filetype(id, descr, descr_alt, mime_type)
    SELECT id, COALESCE(descr, ''), COALESCE(descr_en, ''),
    COALESCE(mime_type, '')
    FROM hydria.ftypes;

--Import files, generate filename gentities_multimedia -> gentityfile
--Should change the 'gentityfile/' prefix accordint to django settings
INSERT INTO hcore_gentityfile(gentity_id, descr, descr_alt,
    remarks, remarks_alt, date, file_type_id, content)
    SELECT m.id+1000, COALESCE(multimedia_name, ''),
    COALESCE(multimedia_name_en, ''), COALESCE(m.remarks, ''),
    COALESCE(m.remarks_en, ''), mdate, ftype,'gentityfile/'||
    'imported_hydria_gentityfile_'||id+1000||'-'||num||'.'||
    CASE WHEN ftype=1 THEN 'jpg' WHEN ftype=2 THEN 'mpg'
        WHEN ftype=3 THEN 'mp3' WHEN ftype=4 THEN 'avi'
        WHEN ftype=5 THEN 'wmv' WHEN ftype=6 THEN 'wav'
        WHEN ftype=7 THEN 'png' WHEN ftype=8 THEN 'mbp'
        WHEN ftype=9 THEN 'gif'
    END
    FROM hydria.gentities_multimedia m
    WHERE m.id+1000 IN (SELECT id FROM hcore_gentity);



/* GENTITY GENERIC SECTION */

--Import hq curves
INSERT INTO hcore_gentitygenericdata(id,gentity_id, descr, descr_alt,
    remarks, remarks_alt, data_type_id, content)
    SELECT id, gentity+1000, COALESCE(name, ''), COALESCE(name_en, ''),
    COALESCE(remarks, ''), COALESCE(remarks_en, ''), 1, ''
    FROM hydria.curves WHERE terminal_subtable='hq_curves';





/********************************************************************/
/*    P A R T   3:   I N S T R U M E N T S                          */
/********************************************************************/

--Import itypes lookup table
INSERT INTO hcore_instrumenttype(id, descr, descr_alt)
    SELECT id, COALESCE(descr,''), COALESCE(descr_en,'') 
    FROM hydria.itypes;

--Import instruments to instruments
INSERT INTO hcore_instrument(id, station_id, type_id, name, name_alt,
    remarks, remarks_alt, manufacturer, model, is_active,
    start_date, end_date)
    SELECT id, station+1000, itype, COALESCE(name, ''),
    COALESCE(name_en, ''), COALESCE(remarks, ''),
    COALESCE(remarks_en, ''), COALESCE(manufacturer, ''),
    COALESCE(model, ''), COALESCE(instrument_active, False),
    start_date, end_date FROM hydria.instruments;





/********************************************************************/
/*    P A R T   4:   T I M E S E R I E S                            */
/********************************************************************/

/* TIMESERIES GENERICS SECTION */

--Fill data into TimeZone, insert a row for EET 
INSERT INTO hcore_timezone(id, code, utc_offset)
    VALUES(1, 'EET', 120);

--Import units into unitofmeasurement
INSERT INTO hcore_unitofmeasurement(id, descr, descr_alt, symbol)
    SELECT id, COALESCE(descr, ''), COALESCE(descr_en, ''),
    COALESCE(symbol, '') FROM hydria.units;

--Insert a dummy unit for null imported timeseries.unit
INSERT INTO hcore_unitofmeasurement(id, descr, descr_alt, symbol)
    VALUES(1001, 'Χωρίς μονάδες', 'Not set', '-');

--Import vars into variable 
INSERT INTO hcore_variable(id, descr, descr_alt)
    SELECT id, COALESCE(descr, ''), COALESCE(descr_en, '')
    FROM hydria.vars;



/* FILL SOME DEFAULT TIMESTEPS SECTION */

COPY hcore_timestep (id, descr, descr_alt, length_minutes, length_months, original_id, original_db_id, last_modified) FROM stdin;
1	Δεκάλεπτο	Ten-minute	10	0	\N	\N	\N
2	Ωριαίο	Hourly	60	0	\N	\N	\N
3	Ημερήσιο	Daily	1440	0	\N	\N	\N
4	Μηνιαίο	Monthly	0	1	\N	\N	\N
5	Ετήσιο	Annual	0	12	\N	\N	\N
6	Πεντάλεπτο	Five-minute	5	0	\N	\N	\N
\.



/* IMPORT TIME SERIES AND RECORDS SECTION */

--Time series to time series
INSERT INTO hcore_timeseries
    (id, gentity_id, variable_id, unit_of_measurement_id, name, name_alt,
     precision, time_zone_id, remarks, remarks_alt, instrument_id,
     time_step_id, interval_type_id, nominal_offset_minutes, 
     nominal_offset_months, actual_offset_minutes, actual_offset_months)
     SELECT id, gentity+1000, var, COALESCE(unit, 1001), COALESCE(name, ''),
     COALESCE(name_en, ''), precision, 1,
     addto_remarks(COALESCE(remarks, ''), 'Τύπος', 
         CASE WHEN ttype=1 THEN 'Πρωτογενής' ELSE 'Επεξεργασμένη' END), 
     addto_remarks(COALESCE(remarks_en, ''), 'Type', 
         CASE WHEN ttype=1 THEN 'Raw data' ELSE 'Processed data' END), 
     instrument, 
     CASE WHEN tstep=6 THEN NULL WHEN tstep=7 THEN 6 ELSE tstep END,     
     CASE WHEN var_type=1 THEN NULL WHEN var_type=2 THEN 1
          WHEN var_type=3 THEN 2 WHEN var_type=4 THEN 4
          WHEN var_type=5 THEN 3 WHEN var_type=6 THEN 2 END,
     CASE WHEN tstep_strict=True THEN 0 ELSE NULL END, 
     CASE WHEN tstep_strict=True THEN 
        CASE WHEN hydrological_year=True THEN 9 ELSE 0 END
     ELSE NULL END, 
     COALESCE(toffset, 0), 
     CASE WHEN tstep=4 THEN 1 WHEN tstep=5 THEN 12 ELSE 0 END 
     FROM hydria.timeseries t
     WHERE t.synth=False AND ttype<3 
        AND t.gentity+1000 IN (SELECT id from hcore_gentity);

/* timeseries data */
INSERT INTO ts_records (id, top, middle, bottom)
    SELECT id, COALESCE(top, ''), middle, bottom FROM hydria.ts_records
    WHERE num=0 AND id IN (SELECT id FROM hcore_timeseries);





/********************************************************************/
/*    P A R T   5:   F I N A L I Z A T I O N                        */
/********************************************************************/

/* Update sequences */
SELECT update_sequence('hcore_gentity_id_seq', 'hcore_gentity');
SELECT update_sequence('hcore_lentity_id_seq', 'hcore_lentity');
SELECT update_sequence('hcore_stationtype_id_seq', 'hcore_stationtype');
SELECT update_sequence('hcore_eventtype_id_seq', 'hcore_eventtype');
SELECT update_sequence('hcore_gentityevent_id_seq', 'hcore_gentityevent');
SELECT update_sequence('hcore_gentityaltcode_id_seq', 'hcore_gentityaltcode');
SELECT update_sequence('hcore_gentityaltcodetype_id_seq', 'hcore_gentityaltcodetype');
SELECT update_sequence('hcore_gentityfile_id_seq', 'hcore_gentityfile');
SELECT update_sequence('hcore_filetype_id_seq', 'hcore_filetype');
SELECT update_sequence('hcore_instrumenttype_id_seq', 'hcore_instrumenttype');
SELECT update_sequence('hcore_instrument_id_seq', 'hcore_instrument');
SELECT update_sequence('hcore_variable_id_seq', 'hcore_variable');
SELECT update_sequence('hcore_timezone_id_seq', 'hcore_timezone');
SELECT update_sequence('hcore_unitofmeasurement_id_seq', 'hcore_unitofmeasurement');
SELECT update_sequence('hcore_timestep_id_seq', 'hcore_timestep');
SELECT update_sequence('hcore_timeseries_id_seq', 'hcore_timeseries');
SELECT update_sequence('hcore_gentitygenericdata_id_seq', 'hcore_gentitygenericdata');

/* Finally delete - drop migration functions */
DROP FUNCTION update_sequence (sequence_name TEXT, table_name TEXT);
DROP FUNCTION addto_remarks (remark TEXT, label TEXT, value TEXT);









/* Keep the following lines until resolving some issues... Stefanos
   2010-09-16
*/
--COMMIT;

--variables to units correspondence made manually, as old openmeteo didn't
--have it.
/*
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
*/ 


