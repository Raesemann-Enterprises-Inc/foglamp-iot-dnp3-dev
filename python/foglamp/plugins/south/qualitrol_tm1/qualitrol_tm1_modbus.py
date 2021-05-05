# -*- coding: utf-8 -*-
import logging
from foglamp.common import logger
from pymodbus.client.sync import ModbusTcpClient as ModbusClient
from pymodbus.transaction import ModbusBinaryFramer as ModbusFramer
from pymodbus.constants import Endian
from pymodbus.payload import BinaryPayloadDecoder

# Modbus register offsets
HYDROGEN_CONCENTRATION_PPM_OFFSET = 0
HYDROGEN_RATE_OF_CHANGE_PPM_PER_DAY_OFFSET = 1
MOISTURE_PPM_OFFSET = 2
RELATIVE_SATURATION_PCT_OFFSET = 3
OIL_TEMP_OFFSET = 4

_LOGGER = logger.setup(__name__, level=logging.INFO)
""" Setup the access to the logging system of foglamp """

class ModbusTM1:

    def __init__(self, ip_address, port):
        _LOGGER.info(f'Initializing TM1 ip address:{ip_address} port {port}')
        self._connection = ModbusClient(ip_address,port)
        self._connection.connect()
        self._connection.DEBUG = True
        self._ip_address = ip_address
        self._port = port

    
    def _convert_to_signedint(self,registers):
        """ Convert registers to signed int """
        decoder = BinaryPayloadDecoder.fromRegisters(registers, byteorder=Endian.Big, wordorder=Endian.Big)
        return decoder.decode_16bit_int()

    def _convert_to_unsignedint(self,registers):
        """ Convert registers to unsigned int """
        decoder = BinaryPayloadDecoder.fromRegisters(registers, byteorder=Endian.Big, wordorder=Endian.Big)
        return decoder.decode_16bit_uint()

    @property
    def connection(self):
        return self._connection

    @connection.setter
    def connection(self, value):
        self._connection = value

    def get_readings(self):
        """ Read Modbus registers from the TM1 and process results to readings for FogLAMP """

        readings = {}

        if self.connection is None:
            try:
                self._connection = ModbusClient(self._ip_address, port=self._port)
            except:
                raise ValueError
        values = []
        try:
            # Read the first 5 holding registers
            read =self._connection.read_holding_registers(address = 0, count = 5, unit=1)
            values = read.registers
        except ModbusIOException as ex:
            _LOGGER.error(f'Modbus IO Exception: {ex}')

        # Processed the returned registers to scaled readings. 
        # Refer to page 35 of TM1 manual for register formats and scaling information
        try:
            if values is not None:
                readings['hydrogen_concentration_ppm'] = values[HYDROGEN_CONCENTRATION_PPM_OFFSET]
                readings['hydrogen_rate_of_change_ppm_per_day'] = self._convert_to_signedint([values[HYDROGEN_RATE_OF_CHANGE_PPM_PER_DAY_OFFSET]])/10
                readings['moisture_ppm'] =  self._convert_to_unsignedint([values[MOISTURE_PPM_OFFSET]])/10
                readings['relative_saturation_pct'] = self._convert_to_unsignedint([read.registers[RELATIVE_SATURATION_PCT_OFFSET]])/10
                readings['oil_temp'] = self._convert_to_signedint([values[OIL_TEMP_OFFSET]])/10
        except Exception as ex:
            _LOGGER.error(f'Error processing returned Modbus registers: {ex}')

        return readings

    def close(self):
        _LOGGER.info('Closing TM1 connection')
        try:
            if self.connection is not None:
                self.connection.close()
                return('TM1 connection closed.')
        except:
            raise
        else:
            self.connection = None