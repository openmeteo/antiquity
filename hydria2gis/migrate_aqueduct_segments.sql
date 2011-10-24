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


/*** LOOKUP Tables section ***/

INSERT INTO gis_objects_gisroughnesscoeftype(id, descr, descr_alt)
    SELECT id, COALESCE(descr,''), COALESCE(descr_en,'') 
    FROM oldeydap.roughness_coef_types;

INSERT INTO gis_objects_gisxsectiontype(id, descr, descr_alt)
    SELECT id, COALESCE(descr,''), COALESCE(descr_en,'') 
    FROM oldeydap.xsection_types;

INSERT INTO hcore_gentitygenericdatatype(id, descr, descr_alt,
                                         file_extension)
       VALUES (5, 'Καμπύλη πιεζ. φορτίου - παροχής υδραγωγείου',
                  'Aqueduct head-discharge curve', 'txt');

--Import conduits cross sections

INSERT INTO gis_objects_gisxsection(id, closed, dimensions,
                                    drawing_file, xsection_type_id)
    SELECT id, COALESCE(closed, False), 
            COALESCE(dimensions,''),
            'gentityfile/imported_xsection_'||id||'.png',
            xsection_type
    FROM oldeydap.xsections;
                
UPDATE gis_objects_gisxsection SET drawing_file='' 
    WHERE id IN (SELECT id FROM oldeydap.xsections 
                 WHERE drawing IS NULL);

--Import gentities for aqueducts
UPDATE hcore_gentity h
    SET (water_basin_id, water_division_id, political_division_id,
         name, short_name, remarks, name_alt, short_name_alt,
         remarks_alt) =
        (NULL, NULL, NULL, COALESCE(o.name::varchar(200), ''), 
        COALESCE(o.descr::varchar(50),''), 
        COALESCE(o.remarks, ''), COALESCE(o.name_en, ''), COALESCE(o.descr_en, ''),
        COALESCE(o.remarks_en, ''))
        FROM oldeydap.gentities o, gis_objects_gisentity b
        WHERE h.id in (SELECT a.gline_ptr_id 
                       FROM  gis_objects_gisaqueductline a
                       WHERE  a.gisentity_ptr_id = b.id)
        AND o.id=b.original_gentity_id;

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
    FROM oldeydap.gentities_real g, gis_objects_gisentity b
    WHERE h.id in (SELECT a.gline_ptr_id 
                   FROM  gis_objects_gisaqueductline a
                   WHERE  a.gisentity_ptr_id = b.id)
    AND g.id=b.original_gentity_id;

--Water basins from gpoints to gentities
UPDATE hcore_gentity h
    SET water_basin_id = p.basin+1000
    FROM oldeydap.gentities_real g, gis_objects_gisentity b,
         oldeydap.gpoints p
    WHERE h.id in (SELECT a.gline_ptr_id 
                   FROM  gis_objects_gisaqueductline a
                   WHERE  a.gisentity_ptr_id = b.id)
    AND g.id=b.original_gentity_id AND p.id=g.id;

--gentities_real location is imported in the gentity remarks
UPDATE hcore_gentity h
    SET (remarks, remarks_alt) =
        (addto_remarks(h.remarks, 'Τοποθεσία', g.location),
        addto_remarks(h.remarks_alt, 'Location', g.location_en))
    FROM oldeydap.gentities_real g, gis_objects_gisentity b
    WHERE h.id in (SELECT a.gline_ptr_id 
                   FROM  gis_objects_gisaqueductline a
                   WHERE  a.gisentity_ptr_id = b.id)
    AND g.id=b.original_gentity_id;

--gentities_real municipality is imported in the gentity remarks
UPDATE hcore_gentity h
    SET (remarks, remarks_alt) =
        (addto_remarks(h.remarks, 'Δήμος', g.municipality),
        addto_remarks(h.remarks_alt, 'Municipality', g.municipality_en))
    FROM oldeydap.gentities_real g, gis_objects_gisentity b
    WHERE h.id in (SELECT a.gline_ptr_id 
                   FROM  gis_objects_gisaqueductline a
                   WHERE  a.gisentity_ptr_id = b.id)
    AND g.id=b.original_gentity_id;

UPDATE hcore_gline h
    SET length = g.length
    FROM oldeydap.glines g, gis_objects_gisentity b
    WHERE h.gentity_ptr_id in (SELECT a.gline_ptr_id 
                   FROM  gis_objects_gisaqueductline a
                   WHERE  a.gisentity_ptr_id = b.id)
    AND g.id=b.original_gentity_id;

/* GENTITY FILES SECTION */

--Import ftypes to filetype lookup table

--Import files, generate filename gentities_multimedia -> gentityfile
--Should change the 'gentityfile/' prefix accordint to django settings
INSERT INTO hcore_gentityfile(gentity_id, descr, descr_alt,
    remarks, remarks_alt, date, file_type_id, content)
    SELECT a.gisentity_ptr_id, COALESCE(m.multimedia_name, ''),
    COALESCE(m.multimedia_name_en, ''), COALESCE(m.remarks, ''),
    COALESCE(m.remarks_en, ''), m.mdate, m.ftype,'gentityfile/'||
    'imported_hydria_gentityfile_'||m.id+1000||'-'||m.num||'.'||
    CASE WHEN ftype=1 THEN 'jpg' WHEN ftype=2 THEN 'mpg'
        WHEN ftype=3 THEN 'mp3' WHEN ftype=4 THEN 'avi'
        WHEN ftype=5 THEN 'wmv' WHEN ftype=6 THEN 'wav'
        WHEN ftype=7 THEN 'png' WHEN ftype=8 THEN 'mbp'
        WHEN ftype=9 THEN 'gif'
    END
    FROM gis_objects_gisentity b,
         gis_objects_gisaqueductline a,
         oldeydap.gentities_multimedia m
    WHERE m.id=b.original_gentity_id AND a.gisentity_ptr_id = b.id;


/* SPECIAL AQUEDUCT FIELDS */


UPDATE gis_objects_gisaqueductline r
    SET (group_id, xsection_id, area, width, depth, slope,
         roughness_coef, roughness_coef_type_id, bank_slope,
         leakage_coef, measure_discharge, measure_stage,
         start_position, end_position, duct_segment_type_id,
         discharge_capacity, duct_flow_type_id, duct_status_id,
         repers, repers_en, pipe_mat_id, alt1, alt2)=
        (c.parent, c.xsection, c.area, c.width, c.depth, c.slope,
         c.roughness_coef, c.roughness_coef_type, c.bank_slope,
         t.leakage_coef, COALESCE(c.measure_discharge, False),
                              COALESCE(c.measure_stage, False),
         c.start_position, c.end_position, t.duct_segment_type,
         t.discharge_capacity, t.duct_flow_type, t.duct_status,
         COALESCE(t.repers, ''), COALESCE(t.repers_en, ''),
               t.pipe_mat, g.alt, l.alt2)
    FROM oldeydap.aqueducts t,
         oldeydap.conduits c,
         oldeydap.glines l,
         oldeydap.gentities g,
         gis_objects_gisentity a
    WHERE r.gisentity_ptr_id=a.id
        AND a.gtype_id=6
        AND t.id=a.original_gentity_id
        AND t.id=c.id
        AND c.id=l.id
        AND g.id=l.id;


/* GENTITY GENERIC SECTION */

INSERT INTO hcore_gentitygenericdata(id, gentity_id, descr, descr_alt,
    remarks, remarks_alt, data_type_id, content)
    SELECT c.id, a.gisentity_ptr_id, COALESCE(c.name, ''), 
           COALESCE(c.name_en, ''), COALESCE(c.remarks, ''), 
           COALESCE(c.remarks_en, ''), 5, ''
    FROM gis_objects_gisentity b,
         gis_objects_gisaqueductline a,
         oldeydap.curves c
    WHERE c.gentity=b.original_gentity_id AND a.gisentity_ptr_id = b.id
          AND c.terminal_subtable='duct_discharge_capacity';


/********************************************************************/
/*     T I M E S E R I E S                                          */
/********************************************************************/

/* IMPORT TIME SERIES AND RECORDS SECTION */

--Time series to time series

ALTER TABLE hcore_timeseries ADD COLUMN old_id integer NULL DEFAULT
            NULL;

INSERT INTO hcore_timeseries
    (old_id, gentity_id, variable_id, unit_of_measurement_id, name, name_alt,
     precision, time_zone_id, remarks, remarks_alt, instrument_id,
     time_step_id, interval_type_id, nominal_offset_minutes, 
     nominal_offset_months, actual_offset_minutes, actual_offset_months,
     hidden)
     SELECT t.id, a.gline_ptr_id, var, COALESCE(unit, 1001), 
     COALESCE(name, ''), COALESCE(name_en, ''), precision, 1,
     addto_remarks(COALESCE(t.remarks, ''), 'Τύπος', 
         CASE WHEN ttype=1 THEN 'Πρωτογενής' ELSE 'Επεξεργασμένη' END), 
     addto_remarks(COALESCE(t.remarks_en, ''), 'Type', 
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
     CASE WHEN tstep=4 THEN 1 WHEN tstep=5 THEN 12 ELSE 0 END,
     False
     FROM oldeydap.timeseries t, gis_objects_gisentity b,
          gis_objects_gisaqueductline a
     WHERE t.gentity = b.original_gentity_id 
           AND a.gisentity_ptr_id=b.id
           AND b.gtype_id=6
           AND t.synth=False AND ttype<3;

/* timeseries data */
INSERT INTO ts_records (id, top, middle, bottom)
    SELECT t.id, COALESCE(r.top, ''), r.middle, r.bottom 
    FROM oldeydap.ts_records r, hcore_timeseries t
    WHERE t.old_id IS NOT NULL AND
          r.id=t.old_id;

/********************************************************************/
/*                   F I N A L I Z A T I O N                        */
/********************************************************************/

/* Update sequences */
SELECT update_sequence('hcore_gentityfile_id_seq', 'hcore_gentityfile');
SELECT update_sequence('hcore_timeseries_id_seq', 'hcore_timeseries');
SELECT update_sequence('gis_objects_gisroughnesscoeftype_id_seq',
                       'gis_objects_gisroughnesscoeftype');
SELECT update_sequence('gis_objects_gisxsectiontype_id_seq',
                       'gis_objects_gisxsectiontype');
SELECT update_sequence('hcore_gentitygenericdatatype_id_seq',
                       'hcore_gentitygenericdatatype');
SELECT update_sequence('gis_objects_gisxsection_id_seq',
                       'gis_objects_gisxsection');
SELECT update_sequence('hcore_gentitygenericdata_id_seq',
                       'hcore_gentitygenericdata');

/* Finally delete - drop migration functions */
DROP FUNCTION update_sequence (sequence_name TEXT, table_name TEXT);
DROP FUNCTION addto_remarks (remark TEXT, label TEXT, value TEXT);

ROLLBACK;

--COMMIT;
--ALTER TABLE hcore_timeseries DROP COLUMN old_id;
