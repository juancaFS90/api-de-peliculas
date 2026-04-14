import pika
import json
import os

RABBITMQ_HOST = os.getenv("RABBITMQ_HOST", "rabbitmq")
RABBITMQ_PORT = int(os.getenv("RABBITMQ_PORT", "5672"))
RABBITMQ_QUEUE = os.getenv("RABBITMQ_QUEUE","peliculas")

def publish_message(message):
    connection = pika.BlockingConnection(
        pika.ConnectionParameters(host= RABBITMQ_HOST,
                                  port= RABBITMQ_PORT
                                  )
    )
    channel = connection.channel()

    channel.queue_declare(queue=RABBITMQ_QUEUE)

    channel.basic_publish(
        exchange="",
        routing_key=RABBITMQ_QUEUE,
        body=json.dumps(message)
    )

    connection.close()