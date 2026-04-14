from api.db import collection, task_collection
from bson import ObjectId

def process_task(data):
    print("Procesando:",data)

    task_id = data.get("task_id")
    action = data.get("action")

    task_collection.update_one({"task_id": task_id, 
                                "$set": {"status": "processing"}}
    )

    try:
        if action == "create":

            movie_data = data.get("data",{})

            result = collection.insert_one(movie_data)

            task_collection.update_one({"task_id": task_id},
                                        {"$set": {"status": "completed", "movie_id": str(result.inserted_id)}}
            )

        elif action == "delete":

            movie_id = data.get("movie_id")
            result = collection.delete_one({"_id": ObjectId(movie_id)})

            if result.deleted_count == 0:
                task_collection.update_one({"task_id": task_id},
                                           {"$set": {"status": "failed", "error": "Pelicula no encontrada"}}
                )
            else:
                task_collection.update_one({"task_id": task_id}, {"$set": {"status": "completed"}})
        else:

            task_collection.update_one({"task_id": task_id}, {"$set": {"status": "failed", "error": "pelicula no soportada"}})

    except Exception as e:

        task_collection.update_one({"task_id":task_id}, {"$set": {"status": "failed", "error": str(e)}})
    

                