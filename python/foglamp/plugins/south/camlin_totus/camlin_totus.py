import copy
import logging
import time
import uuid

from foglamp.common import logger
from foglamp.plugins.common import utils
from foglamp.plugins.south.camlin_totus.dnp3_master import Dnp3_Master

""" Plugin for reading data from a Camlin Totus via DNP3 protocol
"""

__author__ = "Rob Raesemann, rob@raesemann.com, +1 904-613-5988"
__copyright__ = "Copyright (c) 2022 Raesemann Enterprises, Inc."
__license__ = "Apache 2.0"
__version__ = "${VERSION}"

# Global variable holds reference to DNP3 master since it runs continuously once initialized
master = None

_DEFAULT_CONFIG = {
    'plugin': {
        'description': 'Camlin Totus Transformer Monitor South using DNP3 Plugin',
        'type': 'string',
        'default': 'camlin_totus',
        'readonly': 'true'
    },
    'assetName': {
        'description': 'Asset name',
        'type': 'string',
        'default': 'CAMLIN_TOTUS',
        'order': "1"
    },
    'address': {
        'description': 'Address of Camlin Totus',
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
        'name': 'camlin_totus',
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
        _LOGGER.info('Initializing Camlin Totus DNP3 connection -- ip:{} id:{}'.format(outstation_address,outstation_id))
        master = Dnp3_Master(outstation_address,outstation_id)
        master.open()
        return master
    except Exception as ex:
        _LOGGER.error(f'Exception opening DNP3 connection to Camlin Totus: {ex}')

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
    Thermal_OilTempA_OFFSET = 16
    Thermal_TopOilTemp_OFFSET = 22
    Thermal_BottomOilTemp_OFFSET = 24
    Thermal_TapChangerTemp_OFFSET = 26
    Electrical_TransformerLoadB_OFFSET = 33
    DGA_SourceA_CH4_OFFSET = 38
    DGA_SourceA_C2H6_OFFSET = 39
    DGA_SourceA_C2H4_OFFSET = 40
    DGA_SourceA_C2H2_OFFSET = 41
    DGA_SourceA_CO_OFFSET = 42
    DGA_SourceA_H2O_OFFSET = 47
    CALC_TD_Primary_Tandelta_A_avg2_OFFSET = 111
    CALC_TD_Primary_Tandelta_B_avg2_OFFSET = 113
    CALC_TD_Primary_Tandelta_C_avg2_OFFSET = 115
    CALC_TD_Primary_Current_Ch1_avg_OFFSET = 116
    CALC_TD_Primary_Current_Ch2_avg_OFFSET = 117
    CALC_TD_Primary_Current_Ch3_avg_OFFSET = 118
    CALC_TD_Primary_Capacitance_RelCapA_avg2_OFFSET = 123
    CALC_TD_Primary_Capacitance_RelCapB_avg2_OFFSET = 124
    CALC_TD_Primary_Capacitance_RelCapC_avg2_OFFSET = 125
    CALC_TD_Secondary_Tandelta_A_avg2_OFFSET = 170
    CALC_TD_Secondary_Tandelta_B_avg2_OFFSET = 172
    CALC_TD_Secondary_Tandelta_C_avg2_OFFSET = 174
    CALC_TD_Secondary_Current_Ch1_avg_OFFSET = 175
    CALC_TD_Secondary_Current_Ch2_avg_OFFSET = 176
    CALC_TD_Secondary_Current_Ch3_avg_OFFSET = 177
    CALC_TD_Secondary_Capacitance_RelCapA_avg2_OFFSET = 182
    CALC_TD_Secondary_Capacitance_RelCapB_avg2_OFFSET = 183
    CALC_TD_Secondary_Capacitance_RelCapC_avg2_OFFSET = 184
    T1_Ageing_Overall_Accumulated_OFFSET = 373
    T1_Ageing_Overall_RemainingLife_OFFSET = 374
    T1_Ageing_Overall_Speed_OFFSET = 375
    T1_Losses_LoadLosses_OFFSET = 376
    T1_Losses_NoLoadLosses_OFFSET = 377
    T1_Losses_Total_OFFSET = 378
    Thermal_TopOilTempA_OFFSET = 379
    Thermal_BottomOilTempA_1hAvg_OFFSET = 386
    Thermal_TapChangerTempA_OFFSET = 391


    try:
        
        all_dnp3_readings = master.values
        # Assemble the readings using the registers that we are concerned about.
        # Apply scaling factor.
        if all_dnp3_readings:
            _LOGGER.debug(all_dnp3_readings)
            readings = {
                'Thermal_OilTempA' : all_dnp3_readings['analog'][Thermal_OilTempA_OFFSET],
                'Thermal_TopOilTemp' : all_dnp3_readings['analog'][Thermal_TopOilTemp_OFFSET],
                'Thermal_BottomOilTemp' : all_dnp3_readings['analog'][Thermal_BottomOilTemp_OFFSET],
                'Thermal_TapChangerTemp' : all_dnp3_readings['analog'][Thermal_TapChangerTemp_OFFSET],
                'Electrical_TransformerLoadB' : all_dnp3_readings['analog'][Electrical_TransformerLoadB_OFFSET],
                'DGA_SourceA_CH4' : all_dnp3_readings['analog'][DGA_SourceA_CH4_OFFSET],
                'DGA_SourceA_C2H6' : all_dnp3_readings['analog'][DGA_SourceA_C2H6_OFFSET],
                'DGA_SourceA_C2H4' : all_dnp3_readings['analog'][DGA_SourceA_C2H4_OFFSET],
                'DGA_SourceA_C2H2' : all_dnp3_readings['analog'][DGA_SourceA_C2H2_OFFSET],
                'DGA_SourceA_CO' : all_dnp3_readings['analog'][DGA_SourceA_CO_OFFSET],
                'DGA_SourceA_H2O' : all_dnp3_readings['analog'][DGA_SourceA_H2O_OFFSET],
                'CALC_TD_Primary_Tandelta_A_avg2' : all_dnp3_readings['analog'][CALC_TD_Primary_Tandelta_A_avg2_OFFSET],
                'CALC_TD_Primary_Tandelta_B_avg2' : all_dnp3_readings['analog'][CALC_TD_Primary_Tandelta_B_avg2_OFFSET],
                'CALC_TD_Primary_Tandelta_C_avg2' : all_dnp3_readings['analog'][CALC_TD_Primary_Tandelta_C_avg2_OFFSET],
                'CALC_TD_Primary_Current_Ch1_avg' : all_dnp3_readings['analog'][CALC_TD_Primary_Current_Ch1_avg_OFFSET],
                'CALC_TD_Primary_Current_Ch2_avg' : all_dnp3_readings['analog'][CALC_TD_Primary_Current_Ch2_avg_OFFSET],
                'CALC_TD_Primary_Current_Ch3_avg' : all_dnp3_readings['analog'][CALC_TD_Primary_Current_Ch3_avg_OFFSET],
                'CALC_TD_Primary_Capacitance_RelCapA_avg2' : all_dnp3_readings['analog'][CALC_TD_Primary_Capacitance_RelCapA_avg2_OFFSET],
                'CALC_TD_Primary_Capacitance_RelCapB_avg2' : all_dnp3_readings['analog'][CALC_TD_Primary_Capacitance_RelCapB_avg2_OFFSET],
                'CALC_TD_Primary_Capacitance_RelCapC_avg2' : all_dnp3_readings['analog'][CALC_TD_Primary_Capacitance_RelCapC_avg2_OFFSET],
                'CALC_TD_Secondary_Tandelta_A_avg2' : all_dnp3_readings['analog'][CALC_TD_Secondary_Tandelta_A_avg2_OFFSET],
                'CALC_TD_Secondary_Tandelta_B_avg2' : all_dnp3_readings['analog'][CALC_TD_Secondary_Tandelta_B_avg2_OFFSET],
                'CALC_TD_Secondary_Tandelta_C_avg2' : all_dnp3_readings['analog'][CALC_TD_Secondary_Tandelta_C_avg2_OFFSET],
                'CALC_TD_Secondary_Current_Ch1_avg' : all_dnp3_readings['analog'][CALC_TD_Secondary_Current_Ch1_avg_OFFSET],
                'CALC_TD_Secondary_Current_Ch2_avg' : all_dnp3_readings['analog'][CALC_TD_Secondary_Current_Ch2_avg_OFFSET],
                'CALC_TD_Secondary_Current_Ch3_avg' : all_dnp3_readings['analog'][CALC_TD_Secondary_Current_Ch3_avg_OFFSET],
                'CALC_TD_Secondary_Capacitance_RelCapA_avg2' : all_dnp3_readings['analog'][CALC_TD_Secondary_Capacitance_RelCapA_avg2_OFFSET],
                'CALC_TD_Secondary_Capacitance_RelCapB_avg2' : all_dnp3_readings['analog'][CALC_TD_Secondary_Capacitance_RelCapB_avg2_OFFSET],
                'CALC_TD_Secondary_Capacitance_RelCapC_avg2' : all_dnp3_readings['analog'][CALC_TD_Secondary_Capacitance_RelCapC_avg2_OFFSET],
                'T1_Ageing_Overall_Accumulated' : all_dnp3_readings['analog'][T1_Ageing_Overall_Accumulated_OFFSET],
                'T1_Ageing_Overall_RemainingLife' : all_dnp3_readings['analog'][T1_Ageing_Overall_RemainingLife_OFFSET],
                'T1_Ageing_Overall_Speed' : all_dnp3_readings['analog'][T1_Ageing_Overall_Speed_OFFSET],
                'T1_Losses_LoadLosses' : all_dnp3_readings['analog'][T1_Losses_LoadLosses_OFFSET],
                'T1_Losses_NoLoadLosses' : all_dnp3_readings['analog'][T1_Losses_NoLoadLosses_OFFSET],
                'T1_Losses_Total' : all_dnp3_readings['analog'][T1_Losses_Total_OFFSET],
                'Thermal_TopOilTempA' : all_dnp3_readings['analog'][Thermal_TopOilTempA_OFFSET],
                'Thermal_BottomOilTempA_1hAvg' : all_dnp3_readings['analog'][Thermal_BottomOilTempA_1hAvg_OFFSET],
                'Thermal_TapChangerTempA' : all_dnp3_readings['analog'][Thermal_TapChangerTempA_OFFSET]
            }
            _LOGGER.debug(readings)
        else:
            readings = {}

    except Exception as ex:
        readings = {}
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

    _LOGGER.info("Old config for Camlin Totus plugin {} \n new config {}".format(handle, new_config))

    diff = utils.get_diff(handle, new_config)

    if 'address' in diff or 'port' in diff:
        plugin_shutdown(handle)
        new_handle = plugin_init(new_config)
        new_handle['restart'] = 'yes'
        _LOGGER.info("Restarting Camlin Totus DNP3 plugin due to change in configuration keys [{}]".format(', '.join(diff)))

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
        _LOGGER.error(f'Error in shutting down Camlin Totus plugin; {ex}')
