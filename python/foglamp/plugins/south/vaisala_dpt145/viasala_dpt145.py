# -*- coding: utf-8 -*-

# FOGLAMP_BEGIN
# See: http://foglamp.readthedocs.io/
# FOFLAMP_END

import logging
import uuid
import json

from foglamp.common import logger
from foglamp.plugins.common import utils
from foglamp.plugins.south.vaisala_dpt145.vaisala_dpt145_modbus import VaisalaDPT145
from foglamp.services.south import exceptions

""" Plugin for reading data from a Vaisala DPT145 """

__author__ = "Rob Raesemann, rob@raesemann.com, +1 904-613-5988"
__copyright__ = "Copyright (c) 2022 Raesemann Enterprises, Inc."
__license__ = "Apache 2.0"
__version__ = "${VERSION}"

_DEFAULT_CONFIG = {
    'plugin': {
        'description': 'Vaisala DPT145 South Service Plugin',
        'type': 'string',
        'default': 'vaisala_dpt145',
        'readonly': 'true'
    },
    'address': {
        'description': 'Address of Modbus TCP server',
        'type': 'string',
        'default': '10.119.236.44',
        'order': '1',
        'displayName': 'Address'
    },
    'port': {
        'description': 'Port of Modbus TCP server',
        'type': 'integer',
        'default': '502',
        'order': '2',
        'displayName': 'Port'
    },
    'device_config': {
        'description': 'Modbus devices',
        'type': 'JSON',
        'default': json.dumps({
                    "asset_prefix":"iiot:td:Robinwood.",
                    "units":[
                        {
                            "Id":1,
                            "Asset_Name":"8T4"
                        },
                        {
                            "Id":2,
                            "Asset_Name":"826"
                        },
                        {
                            "Id":3,
                            "Asset_Name":"8T6"
                        },
                        {
                            "Id":4,
                            "Asset_Name":"851"
                        },
                        {
                            "Id":5,
                            "Asset_Name":"8T5"
                        }
                    ]
                }),
        'order': '3',
        'displayName': 'Device Configuration'
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
        'name': 'vaisala_dpt145',
        'version': '1.9.3',
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
    config['vaisala_dpt145'] = VaisalaDPT145(master_ip,modbus_port,config['device_config']['value'])

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
    _LOGGER.info('Polling DPT 145s')
    readings = []
    data = {}

    try:
        vaisala_dpt145 = handle['vaisala_dpt145']
        readings = vaisala_dpt145.get_readings()
        _LOGGER.info(f'DPT145 readings: {readings}')
        # if readings:
        #     data = {
        #         "asset": handle['assetName']['value'],
        #         "timestamp":  utils.local_timestamp() ,
        #         "key": str(uuid.uuid4()),
        #         "readings": readings
        #     }
        # else:
        #     _LOGGER.error('No readings received') 

    except Exception as ex:
        raise exceptions.DataRetrievalError(ex)
    else:
        return readings


def plugin_reconfigure(handle, new_config):
    """ Reconfigures the plugin

    it should be called when the configuration of the plugin is changed
    during the operation of the south service.
    The new configuration category should be passed.

    Args:
        handle: handle returned by the plugin initialisation call
        new_config: JSON object representing the new configuration category for the category
    Returns:
        new_handle: new handle to be used in the future calls
    Raises:
    """

    _LOGGER.info('Reconfiguring Plugin')
    vaisala_dpt145 = handle['vaisala_dpt145']
    vaisala_dpt145.close()
    vaisala_dpt145 = None
    
    master_ip = new_config['address']['value']
    modbus_port = int(new_config['port']['value'])
    asset_name = new_config['assetName']['value']
    
    handle['vaisala_dpt145'] = None
    handle['address']['value'] = master_ip
    handle['port']['value'] = modbus_port
    handle['assetName']['value'] = asset_name
    
    vaisala_dpt145 = VaisalaDPT145(master_ip,modbus_port,handle['device_config']['value'])
    
    handle['vaisala_dpt145'] = vaisala_dpt145
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
        _LOGGER.info("Shutting down DPT145 communication")
        vaisala_dpt145 = handle['vaisala_dpt145']
        vaisala_dpt145.close()
        vaisala_dpt145 = None
    except Exception as ex:
        _LOGGER.exception('Error in shutting down vaisala_dpt145 plugin; %s', ex)
        raise