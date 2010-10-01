#!/usr/bin/python

import psycopg2

fileexts = ('jpg', 'mpg', 'mp3', 'avi', 'wmv', 'wav', 'png',\
    'bmp', 'gif')

db = psycopg2.connect("host='localhost' dbname='enhydris_db' \
    user='enhydris_user' password='mppw123'")
c = db.cursor()
d = db.cursor()
c.execute("SET search_path TO hydria")
d.execute("SET search_path TO hydria")
c.execute("SELECT id, num, ftype FROM gentities_multimedia")
row = c.fetchone()
while row!=None:
    filename = 'imported_hydria_gentityfile_'+str(row[0]+1000)+'-'+str(row[1])+\
        '.'+fileexts[row[2]-1]
    d.execute("SELECT multimedia FROM gentities_multimedia WHERE id="+str(row[0])+\
        " AND num="+str(row[1]))
    file = open(filename,"wb")
    row2 = d.fetchone()
    file.write(row2[0])
    file.close()
    row = c.fetchone()
