# Test program for kafka

from kafka import KafkaProducer
from kafka.errors import KafkaError
import asyncio
import json
import uuid
import logging
import sys

BOOTSTRAP_SERVERS = ['seeeduino1:9092']
KAFKA_TOPIC = 'iot-readings'

_LOGGER = logging.getLogger(__name__)
_LOGGER.setLevel(logging.DEBUG)
handler = logging.StreamHandler(sys.stdout)
handler.setLevel(logging.DEBUG)
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
handler.setFormatter(formatter)
_LOGGER.addHandler(handler)

readings = [
    {
        "id":"1",
        "key": "d5ff3bb6-a1d5-4c10-bd16-82baf51537db",
        "reading": {
            "random": -45
        },
        "user_ts": "2019-03-18 17:33:21.348478+00",
        "asset_code": "python-test"
    },
    {
        "id":"2",
        "key": "c0a00cbb-07f4-46fd-8679-ff4a8e19f317",
        "reading": {
            "random": -49
        },
        "user_ts": "2019-03-18 17:33:22.348423+00",
        "asset_code": "python-test"
    }
]

class KafkaNorthPlugin(object):

    def __init__(self):
        _LOGGER.info('init')

    def kafka_error(self, error):
        _LOGGER.error(f'Kafka error: {error}')

    async def send_payloads(self, payloads):
        _LOGGER.info('sending_payloads')
        is_data_sent = False
        last_object_id = 0
        num_sent = 0
        try:
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
            is_data_sent = True
        except Exception as ex:
            _LOGGER.exception("Data could not be sent, %s", str(ex))

        return is_data_sent, last_object_id, num_sent

    async def _send_payloads(self, payload_block):
        """ send a list of block payloads"""

        num_count = 0
        try:
            producer = KafkaProducer(bootstrap_servers=BOOTSTRAP_SERVERS,
                api_version=(2,1),
                value_serializer=lambda m: json.dumps(m).encode('utf-8'))

            await self._send(producer, payload_block)

        except Exception as ex:
            _LOGGER.exception(f'Could not send payload, {ex}')
        else: 
            num_count += len(payload_block)
        return num_count

    async def _send(self, producer, payload):
        """ Send the payload, using provided producer """
       
        producer.send(KAFKA_TOPIC, value=payload).add_errback(self.kafka_error)
        producer.flush()


_LOGGER.info('starting')
kn = KafkaNorthPlugin()
loop = asyncio.get_event_loop()
loop.run_until_complete(kn.send_payloads(readings))
_LOGGER.info('done')