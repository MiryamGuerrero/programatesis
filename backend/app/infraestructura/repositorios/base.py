from typing import List, Dict, Any, Optional
from app.infraestructura.database.db import db_cursor

class RepositorioBasePostgres:
    """Clase base para reducir duplicación en repositorios Postgres."""
    
    def ejecutar_consulta(self, sql: str, params: tuple = ()) -> List[dict]:
        with db_cursor() as cur:
            cur.execute(sql, params)
            if cur.description:
                columnas = [desc[0] for desc in cur.description]
                return [dict(zip(columnas, row)) for row in cur.fetchall()]
            return []

    def ejecutar_uno(self, sql: str, params: tuple = ()) -> Optional[dict]:
        resultados = self.ejecutar_consulta(sql, params)
        return resultados[0] if resultados else None

    def ejecutar_comando(self, sql: str, params: tuple = ()) -> Any:
        with db_cursor() as cur:
            cur.execute(sql, params)
            if "returning" in sql.lower():
                return cur.fetchone()[0]
            return None
