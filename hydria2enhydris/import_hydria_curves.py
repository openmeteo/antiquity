#!/usr/bin/python

import psycopg2
from datetime import datetime, time

db = psycopg2.connect("host='localhost' dbname='eydap-meteo' \
    user='eydap-meteo'")
curs_curves = db.cursor()
curs_hq_curves = db.cursor()
curs_hq_points = db.cursor()
curs_update = db.cursor()
curs_curves.execute("SET search_path TO oldeydap")

curs_curves.execute("SELECT id FROM curves WHERE terminal_subtable='hq_curves'")
row_curves = curs_curves.fetchone()
while row_curves!=None:
    id = row_curves[0]
    curs_hq_curves.execute("SELECT COUNT(c.id) FROM hq_curves c "
                           "WHERE id=%s "
                           "AND c.num IN (SELECT curve_num FROM "
                           "hq_points WHERE id=c.id)"%(id,)) 
    row_hq_curves = curs_hq_curves.fetchone()
    count = row_hq_curves[0]
    curs_hq_curves.execute("SELECT id, num, log, ext, coffset, \
                  start_date, end_date FROM \
                  hq_curves WHERE id=%s ORDER BY num", (id,))
    row_hq_curves = curs_hq_curves.fetchone()
    s = 'Delimiter=","\nDecimalSeparator="."\nDateFormat="yyyy-mm-dd hh:nn"\n'
    s = s + 'Count=%s\n\n'%count
    while row_hq_curves!=None:
        astartdate = row_hq_curves[5]
        if not astartdate: 
            row_hq_curves = curs_hq_curves.fetchone()
            continue
        if astartdate is not datetime: astartdate = datetime.combine(astartdate, time())
        aenddate = row_hq_curves[6]
        if not aenddate:
            row_hq_curves = curs_hq_curves.fetchone()
            continue
        if aenddate is not datetime: aenddate = datetime.combine(aenddate, time())
        s = s + 'StartDate='+astartdate.isoformat(' ')[:16]+'\n'
        s = s + 'EndDate='+aenddate.isoformat(' ')[:16]+'\n'
        s = s + 'StartMonth=1\nEndMonth=12\n'
        s = s + 'Extension='+('False', 'True')[row_hq_curves[3]]+'\n'
        s = s + 'Logarithmic='+('False', 'True')[row_hq_curves[2]]+'\n'
        s = s + 'Offset=%f'%row_hq_curves[4]+'\n'
        curs_hq_points.execute("SELECT COUNT(id) FROM hq_points WHERE (id, curve_num)=\
                                (%s, %s)", (id, row_hq_curves[1]))
        row_hq_points = curs_hq_points.fetchone()
        s = s + 'PointsCount=%d'%row_hq_points[0]+'\n\n'
        curs_hq_points.execute("SELECT h, q FROM hq_points WHERE (id, curve_num)=\
                                (%s, %s) ORDER BY h", (id, row_hq_curves[1]))
        row_hq_points = curs_hq_points.fetchone()
        while row_hq_points!=None:
            s = s + '%f,%f'%row_hq_points+'\n'
            row_hq_points = curs_hq_points.fetchone()
        s+='\n'
        row_hq_curves = curs_hq_curves.fetchone()
    curs_update.execute("UPDATE public.hcore_gentitygenericdata SET \
                         content=%s WHERE id=%s", (s, id))
    print "Imported stage-discharge curve with id=%d"%id
    row_curves = curs_curves.fetchone()

db.commit()
