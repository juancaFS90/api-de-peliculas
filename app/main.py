from flask import Flask, jsonify
from api.routes.routes import routes
import os

app = Flask(__name__)

app.register_blueprint(routes)

@app.route("/")
def home():
    return jsonify({"message": "Api de peliculas activa", "instance": os.getenv("INSTANCE_NAME", "api")}), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0",port=5000)




