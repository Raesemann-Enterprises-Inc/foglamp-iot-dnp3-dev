import copy
import json
import logging
import time
import uuid
from foglamp.common import logger
from foglamp.plugins.common import utils
from foglamp.services.south import exceptions
from foglamp.plugins.south.b100dnp3.dnp3_master import Dnp3_Master

""" Plugin for reading data from a B100 via DNP3 protocol
"""

__author__ = "Rob Raesemann, rob@raesemann.com, +1 904-613-5988"
__copyright__ = "Copyright (c) 2020 Raesemann Enterprises, Inc."
__license__ = "Apache 2.0"
__version__ = "${VERSION}"

# Global variable holds reference to DNP3 master since it runs continuously once initialized
master = None

_DEFAULT_CONFIG = {
    'plugin': {
        'description': 'B100 South using DNP3 Service Plugin',
        'type': 'string',
        'default': 'b100dnp3',
        'readonly': 'true'
    },
    'assetName': {
        'description': 'Asset name',
        'type': 'string',
        'default': 'B100',
        'order': "1"
    },
    'address': {
        'description': 'Address of B100',
        'type': 'string',
        'default': '127.0.0.1',
        'order': '2'
    },
    'id': {
        'description': 'Outstation ID',
        'type': 'integer',
        'default': '10',
        'order': '3'
    }
}

_LOGGER = logger.setup(__name__, level=logging.INFO)
""" Setup the access to the logging system of foglamp """

OUTSTATION_ID = 10
"""  The outstation this request is targeting """

def plugin_info():
    """ Returns information about the plugin.

    Args:
    Returns:
        dict: plugin information
    Raises:
    """

    return {
        'name': 'b100dnp3',
        'version': '1.0.0',
        'mode': 'poll',
        'type': 'south',
        'interface': '1.0',
        'config': _DEFAULT_CONFIG
    }

def open_dnp3_master(handle):
    """ Open the DNP3 master using the supplied configuration.

    Args:
        handle: handle returned by the plugin initialisation call
    Returns:
        master - reference to the opened DNP3 master
    Raises:
        DeviceCommunicationError
    """

    outstation_address = handle['address']['value']
    outstation_id = int(handle['id']['value'])

    try:
        _LOGGER.info('Initializing B100 DNP3 connection -- ip:{} id:{}'.format(outstation_address,outstation_id))
        master = Dnp3_Master(outstation_address,outstation_id)
        master.open()
        return master
    except Exception as ex:
        raise exceptions.DeviceCommunicationError(ex)

def close_dnp3_master():
    master.close()

def plugin_init(config):
    """ Initialise the plugin.

    Args:
        config: JSON configuration document for the plugin configuration category
    Returns:
        handle: JSON object to be used in future calls to the plugin
    Raises:
    """
    
    return copy.deepcopy(config)


def get_readings(handle):
    """ Get readings from DNP3 master and process needed registers to return readings as a Python dict.

    Available for poll mode only.

    Args:
        handle: handle returned by the plugin initialisation call
    Returns:
        returns readings as a Python dict
        None - If no reading is available
    Raises:
        DataRetrievalError
    """

    # The DNP3 master will stay open receiving unsolicited updates continuously after the plugin initializes
    global master

    # If the DNP3 master has not been initialized, open it with the configured parameters
    if master is None:
        master = open_dnp3_master(handle);
        time.sleep(30)
        return

    # DNP3 register offsets for the variables we are concerned with for this plugin

    LTC_TANK_TEMP_OFFSET = 120
    TOP_OIL_TEMP_OFFSET = 150
    WINDING_1_HOTSPOT_TEMP_OFFSET = 180
    WINDING_2_HOTSPOT_TEMP_OFFSET = 210
    WINDING_3_HOTSPOT_TEMP_OFFSET = 240
    WINDING_1_CURRENT_AMPS_OFFSET = 281
    WINDING_2_CURRENT_AMPS_OFFSET = 286
    WINDING_3_CURRENT_AMPS_OFFSET = 291


    try:
        all_dnp3_readings = master.values
        
        # Assemble the readings using the registers that we are concerned about. Apply scaling factor.
        readings = {
            'top_oil_temp': all_dnp3_readings['analog'][TOP_OIL_TEMP_OFFSET]/1000,
            'ltc_tank_temp': all_dnp3_readings['analog'][LTC_TANK_TEMP_OFFSET]/1000,
            'winding_1_hotspot_temp' : all_dnp3_readings['analog'][WINDING_1_HOTSPOT_TEMP_OFFSET]/1000,
            'winding_2_hotspot_temp' : all_dnp3_readings['analog'][WINDING_2_HOTSPOT_TEMP_OFFSET]/1000,
            'winding_3_hotspot_temp' : all_dnp3_readings['analog'][WINDING_3_HOTSPOT_TEMP_OFFSET]/1000,
            'winding_1_current_amps' : all_dnp3_readings['analog'][WINDING_1_CURRENT_AMPS_OFFSET]/100,
            'winding_2_current_amps' : all_dnp3_readings['analog'][WINDING_2_CURRENT_AMPS_OFFSET]/100,
            'winding_3_current_amps' : all_dnp3_readings['analog'][WINDING_3_CURRENT_AMPS_OFFSET]/100,
        }

    except Exception as ex:
        raise exceptions.DataRetrievalError(ex)

    return readings


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

    try:

        readings = get_readings(handle)
        
        wrapper = {
            'asset': handle['assetName']['value'],
            'timestamp': utils.local_timestamp(),
            'key': str(uuid.uuid4()),
            'readings': readings
        }

    except Exception as ex:
        raise exceptions.DataRetrievalError(ex)
    else:
        return wrapper


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

    _LOGGER.info("Old config for B100 plugin {} \n new config {}".format(handle, new_config))

    diff = utils.get_diff(handle, new_config)

    if 'address' in diff or 'port' in diff:
        plugin_shutdown(handle)
        new_handle = plugin_init(new_config)
        new_handle['restart'] = 'yes'
        _LOGGER.info("Restarting B100 DNP3 plugin due to change in configuration keys [{}]".format(', '.join(diff)))

    else:
        new_handle = copy.deepcopy(new_config)
        new_handle['restart'] = 'yes'

    close_dnp3_master()
    return new_handle


def plugin_shutdown(handle):
    """ Shutdowns the plugin doing required cleanup

    To be called prior to the south service being shut down.

    Args:
        handle: handle returned by the plugin initialisation call
    Returns:
    Raises:
    """
    try:
        return_message = "connection_closed"
        _LOGGER.info(return_message)
    except Exception as ex:
        _LOGGER.exception('Error in shutting down B100 plugin; {}',format(ex))
        raise