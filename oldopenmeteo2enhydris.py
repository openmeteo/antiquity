#!/usr/bin/python
"""
Script for the second phase of old openmeteo to enhydris migration.
Look at oldopenmeteo2enhydris.sql for general information. What this
does is to modify the dates of the monthly and annual timeseries
because of ticket #143.

Assuming that "dir" is the openmeteo directory, run as follows:
    export PYTHONPATH=dir:dir/enhydris
    export DJANGO_SETTINGS=settings
    ./oldopenmeteo2enhydris.sql

"""

import sys
from datetime import timedelta

from django.db import connection, transaction

from enhydris.hcore import models
from pthelma.timeseries import Timeseries

transaction.enter_transaction_management()
tms = models.Timeseries.objects.filter(time_step__id__in=[4,5])
for tm in tms:
    sys.stderr.write("Doing timeseries %d..." % (tm.id,))
    t = Timeseries(id=tm.id)
    nt = Timeseries(id=tm.id)
    t.read_from_db(connection)
    for (d, value) in t.items():
        d += timedelta(hours=1)
        assert(not d.minute and not d.hour and not d.second and d.day==1,
            "Invalid date "+str(d))
        nt[d] = value
    nt.write_to_db(connection, transaction=transaction, commit=False)
    sys.stderr.write(" Done\n")
transaction.commit()
