class ErrorDominio(Exception):
    """Clase base para todas las excepciones del dominio."""
    def __init__(self, mensaje: str, detalle: str = None):
        self.mensaje = mensaje
        self.detalle = detalle
        super().__init__(self.mensaje)

class ErrorValidacion(ErrorDominio):
    """Excepción lanzada cuando un modelo de dominio no cumple con sus reglas de validación."""
    pass

class ErrorRecursoNoEncontrado(ErrorDominio):
    """Excepción lanzada cuando un recurso (Paciente, Receta, etc.) no existe."""
    pass

class ErrorReglaNegocio(ErrorDominio):
    """Excepción lanzada cuando se intenta realizar una operación que viola una regla clínica o de negocio."""
    pass

class ErrorConflictoReglas(ErrorReglaNegocio):
    """Excepción específica para cuando hay reglas clínicas contradictorias."""
    pass
