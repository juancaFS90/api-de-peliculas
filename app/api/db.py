from pymongo import MongoClient
import os


MONGO_USER = os.getenv("MONGO_USER", "admin")
MONGO_PASSWORD = os.getenv("MONGO_PASSWOR", "password123")
MONGO_HOST = os.getenv("MONGO_HOST", "mongodb")
MONGO_PORT = os.getenv("MONGO_PORT", "27017")
MONGO_DB = os.getenv("MONGO_DB", "cartelera")
MONGO_AUTH_SOURCE = os.getenv("MONGO_AUTH_SOURCE", "admin")

mongo_uri = (f"mongodb://{MONGO_USER}:{MONGO_PASSWORD}"f"@{MONGO_HOST}:{MONGO_PORT}/?authSource={MONGO_AUTH_SOURCE}")


client = MongoClient(mongo_uri)
db = client[MONGO_DB]
collection = db["peliculas"]
task_collection = db["tasks"]