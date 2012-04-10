/* This file contains UTF-8 characters; use a UTF-8 capable editor. */
\encoding UNICODE

/* This script fills the database with data it copies from schema old_hydro.
 * It must be run while connected to the database as user hydro.
 *
 * See Hydroscope Report 4, "Migration", for more information.
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
    EXECUTE 'SELECT max(id)+1 FROM '||table_name INTO STRICT nextid;
    EXECUTE 'ALTER SEQUENCE '||sequence_name||' RESTART WITH '||nextid;
END
$$ LANGUAGE plpgsql;

/* instruments => InstrumentType */
INSERT INTO hcore_instrumenttype(id, descr, descr_alt)
    SELECT instrtype, instrtpname, '' FROM old_hydro.instruments;

/* pol_districts => PoliticalDivision */
INSERT INTO hcore_gentity(id, name, short_name, remarks, name_alt,
    short_name_alt, remarks_alt)
    SELECT 300+pdid, pdname, pdname, '', '', '', ''
    FROM old_hydro.pol_districts WHERE pdid>0;
INSERT INTO hcore_garea(gentity_ptr_id)
    SELECT 300+pdid FROM old_hydro.pol_districts WHERE pdid>0;
INSERT INTO hcore_politicaldivision(garea_ptr_id, parent_id, code)
    SELECT 300+pdid, 84, '' FROM old_hydro.pol_districts WHERE pdid>0;

/* services => Organization */
INSERT INTO hcore_lentity(id, remarks, remarks_alt)
    SELECT srvid, '', '' FROM old_hydro.services;
INSERT INTO hcore_organization(lentity_ptr_id, name, acronym, name_alt,
    acronym_alt)
    SELECT srvid, srvname, srvcodename, '', '' FROM old_hydro.services;

/* states => PoliticalDivision */
INSERT INTO hcore_gentity(id, name, short_name, remarks, name_alt,
    short_name_alt, remarks_alt)
    SELECT 400+sttid, sttname, sttcodename, '', '', '', ''
    FROM old_hydro.states WHERE pdid>0;
INSERT INTO hcore_garea(gentity_ptr_id)
    SELECT 400+sttid FROM old_hydro.states WHERE pdid>0;
INSERT INTO hcore_politicaldivision(garea_ptr_id, parent_id, code)
    SELECT 400+sttid, 300+pdid, '' FROM old_hydro.states WHERE pdid>0;

/* stcategories => StationType */
INSERT INTO hcore_stationtype(id, descr, descr_alt)
    SELECT stcatid, stcatname, '' FROM old_hydro.stcategories WHERE stcatid>0;

/* timesteps => TimeStep */
INSERT INTO hcore_timestep(id, length_minutes, length_months, descr, descr_alt)
    SELECT timeresid, minutes, 0, tmrname, ''
    FROM old_hydro.timesteps WHERE minutes>0;
INSERT INTO hcore_timestep(id, length_minutes, length_months, descr, descr_alt)
    VALUES (6, 0, 1, 'Μηνιαία', '');
INSERT INTO hcore_timestep(id, length_minutes, length_months, descr, descr_alt)
    VALUES (7, 0, 12, 'Ετήσια', '');

/* variables => Variable */
INSERT INTO hcore_variable(id, descr, descr_alt)
    SELECT varid, varname, '' FROM old_hydro.variables;

/* water_districts => WaterDivision */
INSERT INTO hcore_gentity(id, name, short_name, remarks, name_alt,
    short_name_alt, remarks_alt)
    SELECT 500+wtrid, wtrname, wtrcodename, '', '', '', ''
    FROM old_hydro.water_districts WHERE wtrid>0;
INSERT INTO hcore_garea(gentity_ptr_id)
    SELECT 500+wtrid FROM old_hydro.water_districts WHERE wtrid>0;
INSERT INTO hcore_waterdivision(garea_ptr_id)
    SELECT 500+wtrid FROM old_hydro.water_districts WHERE wtrid>0;

/* basins => WaterBasin */
INSERT INTO hcore_gentity(id, name, short_name, remarks, name_alt,
    short_name_alt, remarks_alt)
    SELECT 1000+wbid, wbname, '', '', '', '', ''
    FROM old_hydro.basins WHERE wbid>0;
INSERT INTO hcore_garea(gentity_ptr_id)
    SELECT 1000+wbid FROM old_hydro.basins WHERE wbid>0;
INSERT INTO hcore_waterbasin(garea_ptr_id, water_division_id)
    SELECT 1000+wbid, CASE WHEN wtrid>0 THEN 500+wtrid ELSE NULL END
    FROM old_hydro.basins WHERE wbid>0;
INSERT INTO hcore_gentityaltcodetype(id, descr, descr_alt)
    VALUES (1, 'Κωδικός ΥΠΑΝ', '');
INSERT INTO hcore_gentityaltcode(gentity_id, type_id, value)
    SELECT 1000+wbid, 1, wbcode FROM old_hydro.basins WHERE wbid>0;

/* sub_basins => WaterBasin */
INSERT INTO hcore_gentity(id, name, short_name, remarks, name_alt,
    short_name_alt, remarks_alt)
    SELECT 1400+wsbid, wsbname, '', '', '', '', ''
    FROM old_hydro.sub_basins WHERE wsbid>0;
INSERT INTO hcore_garea(gentity_ptr_id)
    SELECT 1400+wsbid FROM old_hydro.sub_basins WHERE wsbid>0;
INSERT INTO hcore_waterbasin(garea_ptr_id, water_division_id, parent_id)
    SELECT 1400+sb.wsbid, 500+sb.wtrid, 1000+b.wbid
    FROM old_hydro.sub_basins sb, old_hydro.basins b
    WHERE sb.wsbid>0 AND sb.wbcode=b.wbcode;
INSERT INTO hcore_gentityaltcode(gentity_id, type_id, value)
    SELECT 1400+wsbid, 1, wsbcode FROM old_hydro.sub_basins WHERE wsbid>0;

/* raw_timeseries_info => Timeseries */
INSERT INTO hcore_timezone (id, code, utc_offset) VALUES (1, 'EET', 120);
INSERT INTO hcore_unitofmeasurement (id, symbol, descr, descr_alt) VALUES (1,  '°', '', '');
INSERT INTO hcore_unitofmeasurement (id, symbol, descr, descr_alt) VALUES (2,  'm/s', '', '');
INSERT INTO hcore_unitofmeasurement (id, symbol, descr, descr_alt) VALUES (3,  'mm', '', '');
INSERT INTO hcore_unitofmeasurement (id, symbol, descr, descr_alt) VALUES (4,  '°C', '', '');
INSERT INTO hcore_unitofmeasurement (id, symbol, descr, descr_alt) VALUES (5,  'hPa', '', '');
INSERT INTO hcore_unitofmeasurement (id, symbol, descr, descr_alt) VALUES (6,  'gr/m³', '', '');
INSERT INTO hcore_unitofmeasurement (id, symbol, descr, descr_alt) VALUES (7,  '%', '', '');
INSERT INTO hcore_unitofmeasurement (id, symbol, descr, descr_alt) VALUES (8,  'm', '', '');
INSERT INTO hcore_unitofmeasurement (id, symbol, descr, descr_alt) VALUES (9,  'm³/s', '', '');
INSERT INTO hcore_unitofmeasurement (id, symbol, descr, descr_alt) VALUES (10, 'beaufort', '', '');
INSERT INTO hcore_unitofmeasurement (id, symbol, descr, descr_alt) VALUES (11, 'min', '', '');
INSERT INTO hcore_unitofmeasurement (id, symbol, descr, descr_alt) VALUES (12, 'n/a', '', 'not applicable');
INSERT INTO hcore_unitofmeasurement (id, symbol, descr, descr_alt) VALUES (13, 'cm', '', '');
INSERT INTO hcore_unitofmeasurement (id, symbol, descr, descr_alt) VALUES (14, 'unknown', '', '');
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (1, 2);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (2, 4);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (2, 5);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (2, 107);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (3, 7);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (3, 8);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (3, 12);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (3, 13);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (3, 14);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (3, 15);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (3, 52);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (3, 54);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (3, 55);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (3, 106);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (4, 10);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (4, 18);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (4, 19);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (4, 20);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (4, 21);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (4, 22);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (4, 23);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (4, 24);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (4, 25);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (4, 26);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (4, 28);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (4, 29);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (4, 30);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (4, 31);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (4, 32);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (4, 34);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (4, 35);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (4, 36);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (4, 37);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (4, 39);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (4, 56);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (4, 57);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (5, 44);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (5, 46);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (6, 48);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (7, 50);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (8, 88);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (8, 103);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (9, 101);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (10, 1);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (11, 9);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (11, 16);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (12, 11);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (12, 17);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (12, 40);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (12, 41);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (12, 108);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (12, 109);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (12, 110);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (13, 53);
/* FIXME: Can't understand visibility units 42, 43 */
/* FIXME: Can't understand units for 45 ΠΙΕΣΗ (ΒΑΡΟΜΕΤΡΟ ΣΤΑΘΕΡΑ) and 47 ΠΙΕΣΗ (ΣΤΑΘΕΡΑ ΒΑΡΟΜ.) */
/* FIXME: Can't understand units for radiation 62 */
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (14, 42);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (14, 43);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (14, 45);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (14, 47);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (14, 62);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (14, 102);
INSERT INTO hcore_unitofmeasurement_variables (unitofmeasurement_id, variable_id) VALUES (14, 111);
INSERT INTO hcore_timeseries
    (id, gentity_id, variable_id, unit_of_measurement_id, precision, name,
    time_zone_id, remarks, instrument_id, time_step_id, nominal_offset_minutes,
    nominal_offset_months, actual_offset_minutes, actual_offset_months)
    SELECT r.id, 
    CASE WHEN geoinfoid=5010150001 THEN 501030 ELSE geoinfoid/10000 END,
    varid,
    unitofmeasurement_id,
    NULL, '', 1, COALESCE(comments, ''), instrid/100,
    CASE WHEN timeresid BETWEEN 1 AND 7 THEN timeresid ELSE NULL END,
    NULL, NULL,
    CASE WHEN timeresid BETWEEN 1 AND 7 THEN 0 ELSE NULL END,
    CASE WHEN timeresid BETWEEN 1 AND 7 THEN 0 ELSE NULL END
    FROM old_hydro.raw_timeseries_info r
    LEFT JOIN hcore_unitofmeasurement_variables uv ON uv.variable_id=r.varid;
    
/* stationconfig => Instrument */
INSERT INTO hcore_instrument(id, station_id, type_id, manufacturer, model,
    is_active, start_date, end_date, name, remarks, name_alt, remarks_alt)
    SELECT stconfigid/100,
    CASE WHEN stationid=5010150001 THEN 501030 ELSE stationid/10000 END,
    instrtype, '', '', False, instartdate, inenddate, '', COALESCE(notes, ''),
    '', ''
    FROM old_hydro.stationconfig
    WHERE stationid IN
        (SELECT stationid FROM old_hydro.stations WHERE srvid = :service_id);

/* stations => Station */
INSERT INTO hcore_gentity(id, water_basin_id, water_division_id,
    political_division_id, name, short_name, remarks, name_alt, short_name_alt,
    remarks_alt)
    SELECT CASE WHEN stationid=5010150001 THEN 501030 ELSE stationid/10000 END,
    CASE WHEN wbid>0 THEN 1000+wbid ELSE NULL END,
    CASE WHEN wtrid>0 THEN 500+wtrid ELSE NULL END,
    CASE WHEN sttid>0 THEN 400+sttid ELSE NULL END,
    COALESCE(stationname, 'Anonymous'), '', COALESCE(comments, ''), '', '', ''
    FROM old_hydro.stations WHERE srvid = :service_id;
INSERT INTO hcore_gpoint(gentity_ptr_id, abscissa, ordinate, srid, approximate,
    altitude, asrid)
    SELECT CASE WHEN stationid=5010150001 THEN 501030 ELSE stationid/10000 END,
    x, y, 2100, False, altitude, NULL
    FROM old_hydro.stations WHERE srvid = :service_id AND x<>0;
INSERT INTO hcore_gpoint(gentity_ptr_id, abscissa, ordinate, srid, approximate,
    altitude, asrid)
    SELECT CASE WHEN stationid=5010150001 THEN 501030 ELSE stationid/10000 END,
    to_number(phi, '99') + to_number(phi, '   99')/60
        + CASE WHEN char_length(phi)>5 THEN to_number(phi, '      99')/3600 ELSE 0 END
        + CASE WHEN char_length(phi)>8 THEN to_number(phi, '         99')/360000 ELSE 0 END,
    to_number(lamda, '99') + to_number(lamda, '   99')/60
        + CASE WHEN char_length(lamda)>5 THEN to_number(lamda, '      99')/3600 ELSE 0 END
        + CASE WHEN char_length(trim(' ' from lamda))>8 THEN to_number(lamda, '         99')/360000 ELSE 0 END,
    7030, False, altitude, NULL
    FROM old_hydro.stations
    WHERE srvid = :service_id AND (x=0 OR x is null) AND phi<>'' AND phi<>'00 00 00';
INSERT INTO hcore_gpoint(gentity_ptr_id, abscissa, ordinate, srid, approximate,
    altitude, asrid)
    SELECT CASE WHEN stationid=5010150001 THEN 501030 ELSE stationid/10000 END,
    NULL, NULL, NULL, False, altitude, NULL
    FROM old_hydro.stations
    WHERE srvid = :service_id AND (x=0 OR x is null) AND (phi='' OR phi='00 00 00' OR phi IS NULL);
INSERT INTO hcore_station(gpoint_ptr_id, owner_id, type_id, is_active,
    is_automatic, start_date, end_date)
    SELECT CASE WHEN stationid=5010150001 THEN 501030 ELSE stationid/10000 END,
    srvid, CASE WHEN stcatid>0 THEN stcatid ELSE 1 END,
    CASE WHEN st_isactiv=1 THEN True ELSE False END, False,
    startdate, enddate
    FROM old_hydro.stations WHERE srvid = :service_id;
SELECT update_sequence('hcore_lentity_id_seq', 'hcore_lentity');
INSERT INTO hcore_person(lentity_ptr_id, last_name, first_name, middle_names,
    initials, last_name_alt, first_name_alt, middle_names_alt, initials_alt)
    SELECT nextval('hcore_lentity_id_seq'),
    split_part(observer, ' ', 1), split_part(observer, ' ', 2), '', '', '', '',
    '', ''
    FROM old_hydro.stations WHERE srvid = :service_id AND observer<>'';
INSERT INTO hcore_lentity(id, remarks, remarks_alt)
    SELECT lentity_ptr_id, '', '' FROM hcore_person;
INSERT INTO hcore_overseer(station_id, person_id, is_current)
    SELECT CASE WHEN s.stationid=5010150001 THEN 501030 ELSE s.stationid/10000 END,
    p.lentity_ptr_id, False
    FROM old_hydro.stations s, hcore_person p
    WHERE srvid = :service_id AND split_part(s.observer, ' ', 1)=p.last_name
      AND split_part(s.observer, ' ', 2)=p.first_name;

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
