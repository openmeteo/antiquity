#!/usr/bin/python

import psycopg2
from datetime import datetime, timedelta
from timeseries import datetime_from_iso

step_minutes = {1: 10, 2: 60, 3: 1440, 7: 5}

db = psycopg2.connect("host='localhost' dbname='enhydris_db' \
    user='enhydris_user' password='mppw123'")
c1 = db.cursor()
c2 = db.cursor()
c3 = db.cursor()
c1.execute("SET search_path TO public")
c2.execute("SET search_path TO public")
c3.execute("SET search_path TO public")
c1.execute("SELECT id, time_step_id FROM hcore_timeseries WHERE"
    " time_step_id IN (1, 2, 3, 6) AND nominal_offset_minutes IS NOT NULL")
row = c1.fetchone()
while row!=None:
    c2.execute("SELECT bottom from ts_records WHERE id=%s", (row[0],))
    row2 = c2.fetchone()
    if row2!=None:
        s = row2[0].split('\n')[0].split(',')[0]
        if s:
            atimestamp = datetime_from_iso(s)
            reference_date = atimestamp.replace(day=1, hour=0, minute=0)
            d = atimestamp - reference_date
            diff_in_minutes = d.days*1440 + d.seconds/60
            amod = diff_in_minutes % step_minutes[row[1]]
            print "Processing time series id %s with "\
                  "time step=%s minutes, setting"\
                  " nominal offset to %s minutes"%(row[0],
                      step_minutes[row[1]], amod)
            c3.execute("UPDATE hcore_timeseries SET"
                " nominal_offset_minutes=%s WHERE id=%s", (amod, row[0]))
    row = c1.fetchone()

db.commit()
