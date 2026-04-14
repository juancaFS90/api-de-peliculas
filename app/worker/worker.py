import pika
import json
import time
import os
from worker.tasks import process_task

RABBITMQ_HOST = os.getenv("RABBITMQ_HOST", "rabbitmq")
RABBITMQ_PORT = int(os.getenv("RABBITMQ_PORT", "5672"))
RABBITMQ_QUEUE = os.getenv("RABBITMQ_QUEUE", "peliculas")
RABBITMQ_USER= os.getenv("RABBITMQ_USER", "guest")
RABBITMQ_PASSWORD = os.getenv("RABBITMQ_PASSWOR", "guest")



def connect_to_rabbit():
    while True:
        try:
            credentials = pika.PlainCredentials(RABBITMQ_USER,RABBITMQ_PASSWORD)
            parameters = pika.ConnectionParameters(
                host=RABBITMQ_HOST,
                port=RABBITMQ_PORT,
                credentials=credentials
            )

            connection = pika.BlockingConnection(parameters)
            print("✅ Conectado a RabbitMQ")
            return connection

        except pika.exceptions.AMQPConnectionError:
            print("RabbitMQ no está listo, reintentando en 5 segundos...")
            time.sleep(5)


def callback(ch, method, properties, body):

    print("Mensaje recibido:", body)
    data = json.loads(body)
    process_task(data)
    ch.basic_ack(delivery_tag=method.delivery_tag)


connection=connect_to_rabbit()
channel=connection.channel()

channel.queue_declare(queue=RABBITMQ_QUEUE)

channel.basic_consume(
    queue=RABBITMQ_QUEUE,
    on_message_callback=callback
)

print("Worker esperando mensajes...")
channel.start_consuming()