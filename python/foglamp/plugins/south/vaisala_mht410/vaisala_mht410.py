# -*- coding: utf-8 -*-

# FOGLAMP_BEGIN
# See: http://foglamp.readthedocs.io/
# FOFLAMP_END

import copy
import logging
import datetime
import uuid

from foglamp.common import logger
from foglamp.plugins.common import utils
from foglamp.plugins.south.vaisala_mht410.modbus_mht410 import ModbusHht410
from foglamp.services.south import exceptions

""" Plugin for reading data from a Vaisala MHT410
"""

__author__ = "Rob Raesemann, rob@raesemann.com, +1 904-613-5988"
__copyright__ = "Copyright (c) 2021 Raesemann Enterprises, Inc."
__license__ = "Apache 2.0"
__version__ = "${VERSION}"

_DEFAULT_CONFIG = {
    'plugin': {
        'description': 'Vaisala MHT410 South Service Plugin',
        'type': 'string',
        'default': 'vaisala_mht410',
        'readonly': 'true'
    },
    'assetName': {
        'description': 'Asset name',
        'type': 'string',
        'default': 'mht410',
        'order': "1",
        'displayName': 'Asset Name'
    },
    'address': {
        'description': 'Address of Modbus TCP server',
        'type': 'string',
        'default': '127.0.0.1',
        'order': '2',
        'displayName': 'Address'
    },
    'port': {
        'description': 'Port of Modbus TCP server',
        'type': 'integer',
        'default': '502',
        'order': '3',
        'displayName': 'Port'
    }
}

_LOGGER = logger.setup(__name__, level=logging.INFO)
""" Setup the access to the logging system of foglamp """

def plugin_info():
    """ Returns information about the plugin.

    Args:
    Returns:
        dict: plugin information
    Raises:
    """

    return {
        'name': 'vaisala_mht10',
        'version': '1.9.0',
        'mode': 'poll',
        'type': 'south',
        'interface': '1.0',
        'config': _DEFAULT_CONFIG
    }

def plugin_init(config):
    """ Initialise the plugin.

    Args:
        config: JSON configuration document for the plugin configuration category
    Returns:
        handle: JSON object to be used in future calls to the plugin
    Raises:
    """
    master_ip = config['address']['value']
    modbus_port = int(config['port']['value'])
    
    config['vaisala_mht410'] = ModbusHht410(master_ip,modbus_port)

    return config

def plugin_poll(handle):
    """ Poll readings from the modbus device and returns it in a JSON document as a Python dict.

    Available for poll mode only.

    Args:
        handle: handle returned by the plugin initialisation call
    Returns:
        returns a reading in a JSON document, as a Python dict, if it is available
        None - If no reading is available
    Raises:
        DataRetrievalError
    """
    readings = []
    data = {}

    try:
        vaisala_mht410 = handle['vaisala_mht410']
        readings = vaisala_mht410.get_readings()
        data = {
            "asset": handle['assetName']['value'],
            "timestamp":  utils.local_timestamp() ,
            "key": str(uuid.uuid4()),
            "readings": readings
        }

    except Exception as ex:
        raise exceptions.DataRetrievalError(ex)
    else:
        return data


def plugin_reconfigure(handle, new_config):
    """ Reconfigures the plugin

    it should be called when the configuration of the plugin is changed during the operation of the south service.
    The new configuration category should be passed.

    Args:
        handle: handle returned by the plugin initialisation call
        new_config: JSON object representing the new configuration category for the category
    Returns:
        new_handle: new handle to be used in the future calls
    Raises:
    """

    _LOGGER.info('Reconfiguring Plugin')
    vaisala_mht410 = handle['vaisala_mht410']
    vaisala_mht410.close()
    vaisala_mht410 = None
    
    master_ip = new_config['address']['value']
    modbus_port = int(new_config['port']['value'])
    asset_name = new_config['assetName']['value']
    
    handle['vaisala_mht410'] = None
    handle['address']['value'] = master_ip
    handle['port']['value'] = modbus_port
    handle['assetName']['value'] = asset_name
    
    vaisala_mht410 = ModbusHht410(master_ip,modbus_port)
    
    handle['vaisala_mht410'] = vaisala_mht410
    _LOGGER.info(f'New Configuration:  Master IP: {master_ip}  Modbus port: {modbus_port} Asset name: {asset_name}')

    return handle


def plugin_shutdown(handle):
    """ Shutdowns the plugin doing required cleanup

    To be called prior to the south service being shut down.

    Args:
        handle: handle returned by the plugin initialisation call
    Returns:
    Raises:
    """
    try:
        
        _LOGGER.info("shutting down mht410")
        vaisala_mht410 = handle['vaisala_mht410']
        vaisala_mht410.close()
        vaisala_mht410 = None
    except Exception as ex:
        _LOGGER.exception('Error in shutting down vaisala_mht410 plugin; %s', ex)
        raise
