from typing import List, Dict, Tuple
from ..modelos.reglas import Regla, FuenteRegla, TipoAccion
from ..excepciones import ErrorConflictoReglas

class ServicioResolutorConflictos:
    @staticmethod
    def resolver(reglas: List[Regla]) -> List[Regla]:
        """
        Prioriza reglas CLÍNICAS y TEMPORALES sobre NUTRICIONALES.
        Dentro de la misma prioridad, ELIMINAR siempre gana por seguridad.
        """
        if not reglas:
            return []

        # Agrupar por objetivo: (tipo_objetivo, id_objetivo)
        grupos: Dict[Tuple, List[Regla]] = {}
        for r in reglas:
            clave = (r.tipo_objetivo, r.id_objetivo)
            if clave not in grupos: grupos[clave] = []
            grupos[clave].append(r)

        reglas_finales: List[Regla] = []

        for clave, lista_reglas in grupos.items():
            # 1. Separar por importancia de fuente
            medicas = [r for r in lista_reglas if r.fuente in [FuenteRegla.CLINICA, FuenteRegla.TEMPORAL, FuenteRegla.ALERGIA]]
            nutricionales = [r for r in lista_reglas if r.fuente == FuenteRegla.NUTRICIONAL]

            objetivo_reglas = medicas if medicas else nutricionales
            
            # 2. Si hay múltiples reglas para el mismo objetivo, elegir la más restrictiva
            # ELIMINAR > DISMINUIR > PRIORIZAR
            if any(r.accion == TipoAccion.ELIMINAR for r in objetivo_reglas):
                # Si alguna es eliminar, esa es la que queda (tomamos la primera que sea eliminar)
                reglas_finales.append(next(r for r in objetivo_reglas if r.accion == TipoAccion.ELIMINAR))
            else:
                # Si no hay eliminar, tomamos la primera (o podríamos fusionar si fuera necesario)
                reglas_finales.append(objetivo_reglas[0])
                
        return reglas_finales
