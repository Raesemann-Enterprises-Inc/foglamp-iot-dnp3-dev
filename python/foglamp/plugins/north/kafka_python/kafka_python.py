# -*- coding: utf-8 -*-

""" Kafka North plugin"""
from kafka import KafkaProducer
from kafka.errors import KafkaError
import asyncio
import json
import uuid
import logging
import os.path
from os import path

from foglamp.common import logger
from foglamp.plugins.north.common.common import *

__author__ = "Rob Raesemann"
__copyright__ = "Copyright (c) 2019 Raesemann Enterprises"
__license__ = "Apache 2.0"
__version__ = "${VERSION}"

_LOGGER = logger.setup(__name__, level=logging.INFO)

_CONFIG_CATEGORY_NAME = "KAFKA"
_CONFIG_CATEGORY_DESCRIPTION = "Kafka North Plugin"

_DEFAULT_CONFIG = {
    'plugin': {
         'description': 'Kafka North Plugin - Python',
         'type': 'string',
         'default': 'kafka_python',
         'readonly': 'true'
    },
    "source": {
         "description": "Source of data to be sent on the stream. May be either readings or statistics.",
         "type": "enumeration",
         "default": "readings",
         "options": [ "readings", "statistics" ],
         'order': '1',
         'displayName': 'Source'
    },
    'bootstrap_servers': {
        'description': 'Kafka Bootstrap Server',
        'type': 'string',
        'default': '10.100.41.193:9093',
        'order': '2',
        'displayName': 'Boostrap Server'
    },
    'pem_file': {
        'description': 'Client PEM File Path',
        'type': 'string',
        'default': '/etc/ssl/certs/testkafka.pem',
        'order': '3',
        'displayName': 'Client PEM File Path'
    },
    'cer_file': {
        'description': 'Root CA CER File Path',
        'type': 'string',
        'default': '/etc/ssl/certs/jearootca.cer',
        'order': '4',
        'displayName': 'Root CA CER File Path'
    },
    'ssl_password': {
        'description': 'SSL key password for kafka certificate',
        'type': 'string',
        'default': 'changeme',
        'order': '5',
        'displayName': 'SSL Password'
    },
    'kafka_topic': {
        'description': 'Kafka Topic',
        'type': 'string',
        'default': 'iot-readings',
        'order': '6',
        'displayName': 'Kafka Topic'
    },
}


def plugin_info():
    return {
        'name': 'kafka_python',
        'version': '1.0',
        'type': 'north',
        'interface': '1.0',
        'config': _DEFAULT_CONFIG
    }


def plugin_init(data):
    _LOGGER.info('Initializing Kafka North Python Plugin')
    global kafka_north, config
    kafka_north = KafkaNorthPlugin()
    config = data
    
    ssl_cafile_path = config["cer_file"]["value"]
    pem_file_path = config["pem_file"]["value"]
    
    _LOGGER.info(f'Initializing plugin with boostrap servers: {config["bootstrap_servers"]["value"]} and topic: {config["kafka_topic"]["value"]} password: {config["ssl_password"]["value"]}')
    _LOGGER.info(f'Testing SSL cafile exists: {str(path.exists(ssl_cafile_path))}')
    _LOGGER.info(f'Testing SSL pemfile exists: {str(path.exists(pem_file_path))}')
        
    return config


async def plugin_send(data, payload, stream_id):
    # stream_id (log?)
    try:
        # _LOGGER.info(f'Kafka North Python - plugin_send: {stream_id}')
        is_data_sent, new_last_object_id, num_sent = await kafka_north.send_payloads(payload)
    except asyncio.CancelledError as ex:
        _LOGGER.exception(f'Exception occurred in plugin_send: {ex}')
    else:
        _LOGGER.info('payload sent successfully')
        return is_data_sent, new_last_object_id, num_sent


def plugin_shutdown(data):
    pass


# TODO: North plugin can not be reconfigured? (per callback mechanism)
def plugin_reconfigure():
    pass


class KafkaNorthPlugin(object):
    """ North Kafka Plugin """

    def __init__(self):
        self.event_loop = asyncio.get_event_loop()
        
            
    def kafka_error(self, error):
        _LOGGER.error(f'Kafka callback with error: {error}')

    async def send_payloads(self, payloads):
        is_data_sent = False
        last_object_id = 0
        num_sent = 0

        try:
            _LOGGER.info('processing payloads')
            payload_block = list()

            for p in payloads:
                last_object_id = p["id"]
                read = dict()
                read["asset"] = p['asset_code']
                read["readings"] = p['reading']
                read["timestamp"] = p['user_ts']
                read["key"] = str(uuid.uuid4())  # p['read_key']
                payload_block.append(read)

            num_sent = await self._send_payloads(payload_block)
            _LOGGER.info(f'payloads sent: {num_sent}')
            is_data_sent = True
        except Exception as ex:
            _LOGGER.exception("Data could not be sent, %s", str(ex))

        return is_data_sent, last_object_id, num_sent

    async def _send_payloads(self, payload_block):
        """ send a list of block payloads"""

        num_count = 0
        try:
            ssl_cafile_path = config["cer_file"]["value"]
            pem_file_path = config["pem_file"]["value"]
            password = config['ssl_password']['value']
            bootstrap_servers = config["bootstrap_servers"]["value"]
            
            _LOGGER.info(f'server: {bootstrap_servers} cafile: {ssl_cafile_path}  pemfile: {pem_file_path} password: {password}')

            producer = KafkaProducer(bootstrap_servers=bootstrap_servers, 
                # security_protocol='SSL',
                # ssl_cafile=ssl_cafile_path,
                # ssl_certfile=pem_file_path,
                # ssl_keyfile=pem_file_path,
                # ssl_password=password,
                value_serializer=lambda x: json.dumps(x).encode('utf-8'))

            await self._send(producer, payload_block)
        except Exception as ex:
            _LOGGER.exception(f'Exception sending payload: {ex}')
        else: 
            num_count += len(payload_block)
        return num_count

    async def _send(self, producer, payload):
        """ Send the payload, using provided producer """
        topic = config["kafka_topic"]["value"]
        _LOGGER.info(f'topic: {topic}')
        producer.send(topic, value=payload).add_errback(self.kafka_error)
        producer.flush()