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
from foglamp.plugins.south.qualitrol_tm1.qualitrol_tm1_modbus import ModbusTM1
from foglamp.services.south import exceptions

""" Plugin for reading data from a Qualitrol TM-1
"""

__author__ = "Rob Raesemann, rob@raesemann.com, +1 904-613-5988"
__copyright__ = "Copyright (c) 2021 Raesemann Enterprises, Inc."
__license__ = "Apache 2.0"
__version__ = "${VERSION}"

_DEFAULT_CONFIG = {
    'plugin': {
        'description': 'Qualitrol TM-1 South Service Plugin',
        'type': 'string',
        'default': 'qualitrol_tm1',
        'readonly': 'true'
    },
    'assetName': {
        'description': 'Asset name',
        'type': 'string',
        'default': 'tm1',
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
        'name': 'qualitrol_tm1',
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
    
    config['qualitrol_tm1'] = ModbusTM1(master_ip,modbus_port)

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
        qualitrol_tm1 = handle['qualitrol_tm1']
        readings = qualitrol_tm1.get_readings()
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
    qualitrol_tm1 = handle['qualitrol_tm1']
    qualitrol_tm1.close()
    qualitrol_tm1 = None
    
    master_ip = new_config['address']['value']
    modbus_port = int(new_config['port']['value'])
    asset_name = new_config['assetName']['value']
    
    handle['qualitrol_tm1'] = None
    handle['address']['value'] = master_ip
    handle['port']['value'] = modbus_port
    handle['assetName']['value'] = asset_name
    
    qualitrol_tm1 = ModbusTM1(master_ip,modbus_port)
    
    handle['qualitrol_tm1'] = qualitrol_tm1
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
        
        _LOGGER.info("shutting down tm1")
        qualitrol_tm1 = handle['qualitrol_tm1']
        qualitrol_tm1.close()
        qualitrol_tm1 = None
    except Exception as ex:
        _LOGGER.exception('Error in shutting down qualitrol_tm1 plugin; %s', ex)
        raise ex