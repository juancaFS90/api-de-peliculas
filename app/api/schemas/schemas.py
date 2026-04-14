from marshmallow import Schema, fields

class PeliculaSch(Schema):
    titulo = fields.Str(required=True)
    fecha = fields.Str(required=True)
    director = fields.Str(required=True)


class PeliculaUpdate(Schema):
    titulo = fields.Str(required=False)
    fecha = fields.Str(required=False)
    director = fields.Str(required=False)