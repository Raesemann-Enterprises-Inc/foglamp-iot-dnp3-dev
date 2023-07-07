import copy
import logging
import time
import uuid
import time

from foglamp.common import logger
from foglamp.plugins.common import utils
from foglamp.plugins.south.camlin_totus.dnp3_master import Dnp3_Master


outstation_address = '10.119.236.75'
outstation_id = 10

print('Opening Master...')
master = Dnp3_Master(outstation_address,outstation_id)
master.open()

master._getValues()
while 1:
    time.sleep(1)
    readings = master.values
    print(readings)


#master.close()
print("done")