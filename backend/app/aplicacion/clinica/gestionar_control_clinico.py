from typing import Dict, Any
from ...infraestructura.repositorios.repositorio_clinico import RepositorioClinicoPostgres

class CasoUsoGestionarControlClinico:
    def __init__(self, repo_clinico: RepositorioClinicoPostgres):
        self.repo_clinico = repo_clinico

    def calcular_estado_nutricional(self, peso: float, talla: float, edad_meses: int, id_sexo: int) -> Dict[str, Any]:
        imc = round(peso / ((talla / 100) ** 2), 2)
        ref = self.repo_clinico.obtener_datos_referencia_oms(id_sexo, edad_meses)
        
        if not ref:
            return {
                "imc": imc,
                "id_condicion_nutricional": 0,
                "diagnostico_nutri_texto": "Sin referencia OMS para esta edad/sexo"
            }
            
        l, m, s = ref["l"], ref["m"], ref["s"]
        z_score = round((((imc / m)**l) - 1) / (l * s), 2) if l != 0 else round((imc/m - 1)/s, 2)

        return {
            "imc": imc,
            "z_score": z_score,
            "id_condicion_nutricional": ref["id_condicion"],
            "diagnostico_nutri_texto": ref["diagnostico"]
        }
