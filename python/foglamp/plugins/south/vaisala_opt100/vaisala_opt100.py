import copy
import logging
import time
import uuid

from foglamp.common import logger
from foglamp.plugins.common import utils
from foglamp.plugins.south.vaisala_opt100.dnp3_master import Dnp3_Master

""" Plugin for reading data from a OPT100 via DNP3 protocol
"""

__author__ = "Rob Raesemann, rob@raesemann.com, +1 904-613-5988"
__copyright__ = "Copyright (c) 2020 Raesemann Enterprises, Inc."
__license__ = "Apache 2.0"
__version__ = "${VERSION}"

# Global variable holds reference to DNP3 master since it runs continuously once initialized
master = None

_DEFAULT_CONFIG = {
    'plugin': {
        'description': 'OPT100 South using DNP3 Service Plugin',
        'type': 'string',
        'default': 'vaisala_opt100',
        'readonly': 'true'
    },
    'assetName': {
        'description': 'Asset name',
        'type': 'string',
        'default': 'OPT100',
        'order': "1"
    },
    'address': {
        'description': 'Address of OPT100',
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

def plugin_info():
    """ Returns information about the plugin.

    Args:
    Returns:
        dict: plugin information
    Raises:
    """

    return {
        'name': 'vaisala_opt100',
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
        _LOGGER.info('Initializing OPT100 DNP3 connection -- ip:{} id:{}'.format(outstation_address,outstation_id))
        master = Dnp3_Master(outstation_address,outstation_id)
        master.open()
        return master
    except Exception as ex:
        _LOGGER.error(f'Exception opening DNP3 connection to OPT100: {ex}')

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
        master = open_dnp3_master(handle)
        time.sleep(30)
        return

    # DNP3 register offsets for the variables we are concerned with for this plugin

    METHANE_OFFSET = 0
    ACETYLENE_OFFSET = 1
    ETHYLENE_OFFSET = 2
    ETHANE_OFFSET = 3
    CARBON_MONOXIDE_OFFSET = 4
    CARBON_DIOXIDE_OFFSET = 5
    TCG_OFFSET = 6
    HYDROGEN_OFFSET = 7
    OIL_MOISTURE_OFFSET = 8
    OIL_TEMP_OFFSET = 9
    MOISTURE_IN_OIL_OFFSET = 10
    GAS_PRESSURE_OFFSET = 11
    _24HR_METHANE_AVERAGE_OFFSET = 20
    _24HR_ACETYLENE_AVERAGE_OFFSET = 21
    _24HR_ETHYLENE_AVERAGE_OFFSETT = 22
    _24HR_ETHANE_AVERAGE_OFFSET = 23
    _24HR_CARBON_MONOXIDE_AVERAGE_OFFSET = 24
    _24HR_CARBON_DIOXIDE_AVERAGE_OFFSET = 25
    _24HR_TCG_AVERAGE_OFFSET = 26
    _24HR_HYDROGEN_AVERAGE_OFFSET = 27
    _24HR_OIL_MOISTURE_AVERAGE_OFFSET = 28
    _24HR_GAS_PRESSURE_AVERAGE_OFFSET = 29
    METHANE_HYDROGEN_RATIO_OFFSET = 100
    ACETYLENE_ETHYLENE_RATIO_OFFSET = 101
    ACETYLENE_METHANE_RATIO_OFFSET = 102
    # ETHANE_ACETYLENE_RATIO_OFFSET = 103
    ETHYLENE_ETHANE_RATIO_OFFSET = 104
    CARBON_DIOXIDE_CARBON_MONOXIDE_RATIO_OFFSET = 105


    try:
        all_dnp3_readings = master.values
        # Assemble the readings using the registers that we are concerned about.
        # Apply scaling factor.
        if all_dnp3_readings:
            readings = {
                'methane' : all_dnp3_readings['analog'][METHANE_OFFSET],
                'acetylene' : all_dnp3_readings['analog'][ACETYLENE_OFFSET],
                'ethylene' : all_dnp3_readings['analog'][ETHYLENE_OFFSET],
                'ethane' : all_dnp3_readings['analog'][ETHANE_OFFSET],
                'carbon_monoxide' : all_dnp3_readings['analog'][CARBON_MONOXIDE_OFFSET],
                'carbon_dioxide' : all_dnp3_readings['analog'][CARBON_DIOXIDE_OFFSET],
                'tcg' : all_dnp3_readings['analog'][TCG_OFFSET],
                'hydrogen' : all_dnp3_readings['analog'][HYDROGEN_OFFSET],
                'oil_moisture' : all_dnp3_readings['analog'][OIL_MOISTURE_OFFSET],
                'oil_temp' : all_dnp3_readings['analog'][OIL_TEMP_OFFSET],
                'moisture_in_oil' : all_dnp3_readings['analog'][MOISTURE_IN_OIL_OFFSET],
                'gas_pressure' : all_dnp3_readings['analog'][GAS_PRESSURE_OFFSET],
                '24hr_methane_average' : all_dnp3_readings['analog'][_24HR_METHANE_AVERAGE_OFFSET],
                '24hr_acetylene_average' : all_dnp3_readings['analog'][_24HR_ACETYLENE_AVERAGE_OFFSET],
                '24hr_ethylene_average' : all_dnp3_readings['analog'][_24HR_ETHYLENE_AVERAGE_OFFSETT],
                '24hr_ehthane_average' : all_dnp3_readings['analog'][_24HR_ETHANE_AVERAGE_OFFSET],
                '24hr_carbon_monoxide_average' : all_dnp3_readings['analog'][_24HR_CARBON_MONOXIDE_AVERAGE_OFFSET],
                '24hr_carbon_dioxide_average' : all_dnp3_readings['analog'][_24HR_CARBON_DIOXIDE_AVERAGE_OFFSET],
                '24hr_tcg_average' : all_dnp3_readings['analog'][_24HR_TCG_AVERAGE_OFFSET],
                '24hr_hydrogen_average' : all_dnp3_readings['analog'][_24HR_HYDROGEN_AVERAGE_OFFSET],
                '24hr_oil_moisture_average' : all_dnp3_readings['analog'][_24HR_OIL_MOISTURE_AVERAGE_OFFSET],
                '24hr_gas_pressure_average' : all_dnp3_readings['analog'][_24HR_GAS_PRESSURE_AVERAGE_OFFSET],
                'methane_hydrogen_ratio' : all_dnp3_readings['analog'][METHANE_HYDROGEN_RATIO_OFFSET],
                'acetylene_ethylene_ratio' : all_dnp3_readings['analog'][ACETYLENE_ETHYLENE_RATIO_OFFSET],
                'acetylene_methane_ratio' : all_dnp3_readings['analog'][ACETYLENE_METHANE_RATIO_OFFSET],
                # 'ethane_acetylene_ratio' : all_dnp3_readings['analog'][ETHANE_ACETYLENE_RATIO_OFFSET],
                'ethylene_ethane_ratio' : all_dnp3_readings['analog'][ETHYLENE_ETHANE_RATIO_OFFSET],
                'carbon_dioxide_carbon_monoxide_ratio' : all_dnp3_readings['analog'][CARBON_DIOXIDE_CARBON_MONOXIDE_RATIO_OFFSET]
            }
        else:
            readings = {}

    except Exception as ex:
        _LOGGER.error(f'Error processing readings: {ex}')
    finally:
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
        _LOGGER.error(f'Execptoin in plugin poll: {ex}')
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

    _LOGGER.info("Old config for OPT100 plugin {} \n new config {}".format(handle, new_config))

    diff = utils.get_diff(handle, new_config)

    if 'address' in diff or 'port' in diff:
        plugin_shutdown(handle)
        new_handle = plugin_init(new_config)
        new_handle['restart'] = 'yes'
        _LOGGER.info("Restarting OPT100 DNP3 plugin due to change in configuration keys [{}]".format(', '.join(diff)))

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
        _LOGGER.error(f'Error in shutting down OPT100 plugin; {ex}')
