from typing import List, Dict, Any
from ...domain.repositorios.interfaces import IRepositorioPerfil
from ...domain.servicios.restricciones_alimentarias import catalogo_restricciones

class CasoUsoGestionarCatalogos:
    def __init__(self, repo_perfil: IRepositorioPerfil):
        self.repo_perfil = repo_perfil

    def obtener_maestro(self, esquema: str, tabla: str) -> List[Dict[str, Any]]:
        return self.repo_perfil.obtener_catalogo(esquema, tabla)

    def obtener_catalogos_registro_paciente(self) -> Dict[str, List[Dict[str, Any]]]:
        condiciones = self.repo_perfil.obtener_catalogo("heuristico", "condicion")
        ingredientes = self.repo_perfil.obtener_catalogo("nutricion", "ingrediente")
        subgrupos = self.repo_perfil.obtener_catalogo("nutricion", "subgrupo_alimentario")
        restricciones = catalogo_restricciones(subgrupos, ingredientes)
        try:
            catalogo_bd = self.repo_perfil.obtener_catalogo("clinico", "catalogo_restriccion_alimentaria")
            if catalogo_bd:
                restricciones = [
                    {
                        "codigo": r.get("codigo"),
                        "nombre": r.get("nombre") or r.get("codigo"),
                        "ids_subgrupos": [],
                        "ids_ingredientes": [],
                        "etiquetas_bloqueadas": [r.get("etiqueta_bloqueante_codigo")] if r.get("etiqueta_bloqueante_codigo") else [],
                        "etiquetas_positivas": [],
                    }
                    for r in catalogo_bd
                    if r.get("activa", True)
                ]
        except Exception:
            # Fallback al catalogo estático cuando la tabla clínica aún no existe.
            pass
        return {
            "parentescos": self.repo_perfil.obtener_catalogo("usuarios", "parentesco"),
            "sexos": self.repo_perfil.obtener_catalogo("usuarios", "catalogo_sexo"),
            "patologias": [
                c for c in condiciones
                if (c.get("id_tipo") or c.get("id_tipo_condicion")) == 1
            ],
            "condiciones_temporales": [
                c for c in condiciones
                if (c.get("id_tipo") or c.get("id_tipo_condicion")) == 2
            ],
            "ingredientes": ingredientes,
            "cantones": self.repo_perfil.obtener_catalogo("usuarios", "canton"),
            "parroquias": self.repo_perfil.obtener_catalogo("usuarios", "parroquia"),
            "subgrupos": subgrupos,
            "restricciones_alimentarias": restricciones,
        }
