#!/usr/bin/python

import psycopg2
from datetime import datetime, time

db = psycopg2.connect("host='localhost' dbname='eydap-meteo' \
    user='eydap-meteo'")
curs_curves = db.cursor()
curs_hsvb = db.cursor()
curs_leak = db.cursor()
curs_spill = db.cursor()
curs_update = db.cursor()
curs_curves.execute("SET search_path TO oldeydap")

curs_curves.execute("SELECT id FROM curves WHERE terminal_subtable='reservoir_hsvb'")
row_curves = curs_curves.fetchone()
while row_curves!=None:
    id = row_curves[0]
    curs_hsvb.execute("SELECT h, s, v "
                      "FROM reservoir_hsvb WHERE id=%s "
                      "ORDER BY h", (id, ))
    row_hsvb = curs_hsvb.fetchone()
    outstr = ''
    while row_hsvb!=None:
        outstr+= '%f,%f,%f'%row_hsvb
        row_hsvb = curs_hsvb.fetchone()
        if row_hsvb!=None: outstr+='\n'
    curs_update.execute("UPDATE public.hcore_gentitygenericdata SET \
                         content=%s WHERE id=%s", (outstr, id))
    print "Imported reservoir hsvb curve with id=%d"%id
    row_curves = curs_curves.fetchone()

curs_curves.execute("SELECT id FROM curves WHERE terminal_subtable='reservoir_leakage'")
row_curves = curs_curves.fetchone()
while row_curves!=None:
    id = row_curves[0]
    curs_leak.execute("SELECT value_a, value_b, value_c, value_e "
                      "FROM reservoir_leakage WHERE id=%s "
                      "ORDER BY month", (id, ))
    row_leak = curs_leak.fetchone()
    outstr = ''
    while row_leak!=None:
        outstr+= '%f,%f,%f,%f'%row_leak
        row_leak = curs_leak.fetchone()
        if row_leak!=None: outstr+='\n'
    curs_update.execute("UPDATE public.hcore_gentitygenericdata SET \
                         content=%s WHERE id=%s", (outstr, id))
    print "Imported reservoir leakage coefficients with id=%d"%id
    row_curves = curs_curves.fetchone()

curs_curves.execute("SELECT id FROM curves WHERE terminal_subtable='reservoir_spill'")
row_curves = curs_curves.fetchone()
while row_curves!=None:
    id = row_curves[0]
    curs_spill.execute("SELECT h, q "
                      "FROM reservoir_spill WHERE id=%s "
                      "ORDER BY h", (id, ))
    row_spill = curs_spill.fetchone()
    outstr = ''
    while row_spill!=None:
        outstr+= '%f,%f'%row_spill
        row_spill = curs_spill.fetchone()
        if row_spill!=None: outstr+='\n'
    curs_update.execute("UPDATE public.hcore_gentitygenericdata SET \
                         content=%s WHERE id=%s", (outstr, id))
    print "Imported reservoir spill h-q with id=%d"%id
    row_curves = curs_curves.fetchone()

db.rollback()
#db.commit()
