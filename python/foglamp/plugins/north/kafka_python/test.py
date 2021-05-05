from kafka import KafkaProducer
from kafka import KafkaConsumer
import json


print('Producing')
producer = KafkaProducer(bootstrap_servers='jeainnova2d1:9093', 
                security_protocol='SSL',
                ssl_cafile='/etc/ssl/certs/jearootca.cer',
                ssl_certfile='/etc/ssl/certs/testkafka.pem',
                ssl_keyfile='/etc/ssl/certs/testkafka.pem',
                ssl_password='changeit',
                value_serializer=lambda x: json.dumps(x).encode('utf-8'))

producer.send('iot-readings', {'foo999aabbb': 'bar'})
producer.send('iot-readings', {'foo222aabbb': 'bar'})
producer.flush()



print('Consuming')
consumer = KafkaConsumer('iot-readings',
                bootstrap_servers='jeainnova2d1:9093', 
                client_id = 'test_client',
                group_id = "pi-group",
                security_protocol='SSL',
                ssl_cafile='/etc/ssl/certs/jearootca.cer',
                ssl_certfile='/etc/ssl/certs/testkafka.pem',
                ssl_keyfile='/etc/ssl/certs/testkafka.pem',
                ssl_password='changeit',
                auto_offset_reset='earliest',
                value_deserializer=lambda x: json.loads(x.decode('utf-8')))

for message in consumer:
    message = message.value
    print(f'message: {message}')