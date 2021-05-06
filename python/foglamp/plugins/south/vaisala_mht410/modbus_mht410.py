# -*- coding: utf-8 -*-

import logging

from foglamp.common import logger
from pymodbus.client.sync import ModbusTcpClient as ModbusClient
from pymodbus.transaction import ModbusBinaryFramer as ModbusFramer
from pymodbus.constants import Endian
from pymodbus.payload import BinaryPayloadDecoder

_LOGGER = logger.setup(__name__, level=logging.INFO)
""" Setup the access to the logging system of foglamp """

# The Vaisala Indigo 520 handles the pollogin of the DHT10 probe. If the DHT410 is configured as the first probe
# then it is Modbus device 241
DHT410_MODBUS_DEVICE_ID = 241

# the MHT410 registers that we are interested in. We want to read a block of 2 16 bit registers from each offset.
# We will then convert these registers to a 32 bit floating point number.
read_registers = {
    'hydrogen_concentration': 1,
    'water_concentration_in_oil': 17,
    'sensor_temperature' : 27
}

class ModbusHht410:

    def __init__(self, ip_address, port):
        _LOGGER.info(f'Initializing mht410 ip address:{ip_address} port {port}')
        self._connection = ModbusClient(ip_address,port)
        self._ip_address = ip_address
        self._port = port

    def _convert_to_float(self,registers):
        """ Converts unsigned int from Modbus device to a floating point number """
        decoder = BinaryPayloadDecoder.fromRegisters(registers, byteorder=Endian.Big, wordorder=Endian.Big)
        return round(decoder.decode_32bit_float(),2)

    @property
    def connection(self):
        return self._connection

    @connection.setter
    def connection(self, value):
        self._connection = value

    def get_readings(self):

        readings = {}

        if self.connection is None:
            try:
                self._connection = ModbusClient(self._ip_address, port=self._port)
            except:
                raise ValueError

        for key, value in read_registers.items():
            try:
                read =self._connection.read_holding_registers(value,2,unit=DHT410_MODBUS_DEVICE_ID)
                raw = read.registers
                readings[key] = self._convert_to_float(raw)
            except Exception as ex:
                _LOGGER.error(f'Error polling DHT410: {ex}')

        return readings

    def close(self):
        _LOGGER.info('Closing MHT410 connection')
        try:
            if self.connection is not None:
                self.connection.close()
                return('MHT410 connection closed.')
        except:
            raise
        else:
            self.connection = None