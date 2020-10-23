""" Simple test script to assist in debugging any DNP3 protocol issues
"""

from dnp3_master import Dnp3_Master
import time

OUTSTATION_IP = "192.168.1.100"
OUTSTATION_ID = 10

def create_Dnp3_Master():
    print("Creating test master")
    newmaster = Dnp3_Master(OUTSTATION_IP,OUTSTATION_ID)
    newmaster.open()

    while(1):
        time.sleep(5)
        values = newmaster.values
        print('==========================================')
        print(values)


create_Dnp3_Master()
