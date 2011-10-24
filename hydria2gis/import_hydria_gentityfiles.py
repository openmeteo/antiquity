#!/usr/bin/python

import psycopg2
import Image

db = psycopg2.connect("host='localhost' dbname='eydap-meteo' \
    user='eydap-meteo'")
c = db.cursor()
c.execute("SET search_path TO oldeydap")
c.execute("SELECT id, drawing from xsections")
row = c.fetchone()
while row!=None:
    filename = 'imported_xsection_%d.bmp'%(row[0],)
    filename2 = 'imported_xsection_%d.png'%(row[0],)
    if row[1] and len(row[1])>0:
        file = open(filename,"wb")
        file.write(row[1])
        file.close()
        im = Image.open(filename)
        im.save(filename2)
    row = c.fetchone()
