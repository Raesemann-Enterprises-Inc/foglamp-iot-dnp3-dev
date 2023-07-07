# -*- coding: utf-8 -*-
import json
import logging
import time
import uuid

from pymodbus.client import sync
from foglamp.common import logger
from pymodbus.client.sync import ModbusTcpClient as ModbusClient
from pymodbus.transaction import ModbusRtuFramer as ModbusFramer
from pymodbus.payload import BinaryPayloadDecoder
from pymodbus.constants import Endian
from pymodbus.compat import iteritems
from pymodbus.constants import Defaults

from foglamp.common import logger
from foglamp.plugins.common import utils

# Modbus register offsets
HYDROGEN_CONCENTRATION_PPM_OFFSET = 0
HYDROGEN_RATE_OF_CHANGE_PPM_PER_DAY_OFFSET = 1
MOISTURE_PPM_OFFSET = 2
RELATIVE_SATURATION_PCT_OFFSET = 3
OIL_TEMP_OFFSET = 4

_LOGGER = logger.setup(__name__, level=logging.INFO)
""" Setup the access to the logging system of foglamp """

class VaisalaDPT145:

    def __init__(self, ip_address, port, device_config):
        _LOGGER.info(f'Initializing DPT145 ip address:  {ip_address}:{port}')
        _LOGGER.info(f'Initializing DPT145 device_config:{json.dumps(device_config)}')
        
        log = logging.getLogger("pymodbus")
        log.setLevel(logging.DEBUG)

        self._ip_address = ip_address
        self._port = port
        self._device_config = device_config
        self._connection = None


    @property
    def connection(self):
        if self._connection is None:
            try:
                _LOGGER.info('There is no Modbus connection. Creating a new one')
                self._connection = ModbusClient(
                    self._ip_address, 
                    port=self._port, 
                    timeout = 10, 
                    retries = 5,
                    retry_on_empty=True,
                    reset_socket=False,
                    strict = False,
                    framer=ModbusFramer)
                self._connection.connect()
                self._connection.DEBUG = True
            except:
                raise ValueError
        return self._connection

    @connection.setter
    def connection(self, value):
        self._connection = value

    def get_readings(self):
        """ Read Modbus registers from the TM1 and process results to readings for FogLAMP """

        readings_cleaned = {}
        asset_readings = []

        try:
        
            for unit in self._device_config["units"]:
                _LOGGER.info(f'connection: {self._connection}')
                unit_id = unit["Id"]
                _LOGGER.info(f'unit {unit_id} : {type(unit_id)}')
                address = 0x05
                count = 50
                _LOGGER.info(f'Polling unit {unit_id} : {unit["Asset_Name"]}')
                time.sleep(.1)
                rr = self.connection.read_holding_registers(address, count, unit=unit_id)

                if rr.registers:
                    _LOGGER.info(f'Decoding {rr.registers}')
                    decoder = BinaryPayloadDecoder.fromRegisters(rr.registers,Endian.Big,Endian.Big)

                    readings = {
                        'temp': decoder.decode_32bit_float(),               # address 5 - float
                        'tdiff': decoder.decode_32bit_float(),              # address 7 - float
                        'skipped1': decoder.skip_bytes(4),                  # address 9 and 10 - no value - skip
                        'tdatm': decoder.decode_32bit_float(),              # address 11 - float
                        'skipped2': decoder.skip_bytes(16),                 # address 13-20 - no value - skip
                        'water': decoder.decode_32bit_float(),              # address 21 - float
                        'skipped2': decoder.skip_bytes(44),                 # address 23-44 - no value - skip
                        'pmeas': decoder.decode_32bit_float()*14.5038,      # address 45 - float
                        'rho': decoder.decode_32bit_float(),                # address 47 - float
                        'pnorm': decoder.decode_32bit_float()*14.5038        # address 49 - float
                    }

                    _LOGGER.info(f'Raw readings: {readings}')
                    readings_clean = {}
                    for name, value in iteritems(readings):
                        if not name.startswith('skipped'):
                            _LOGGER.info ("%s:\t" % name, value)
                            readings_clean[name] = value

                        asset_reading = {
                            "asset": f'{self._device_config["asset_prefix"]}{unit["Asset_Name"]}',
                            "timestamp": utils.local_timestamp(),
                            "key": str(uuid.uuid4()),
                            "readings":readings_clean
                            }

                        asset_readings.append(asset_reading)

            _LOGGER.info(asset_readings)            
            return asset_readings

        except Exception as ex:
            _LOGGER.error(f'Error reading registers: {ex}')


    def close(self):
        _LOGGER.info('Closing connection')
        try:
            if self.connection is not None:
                self.connection.close()
                return("Connection closed")
        except:
            raise
        else:
            self.connection = None
            return("No connection to close")