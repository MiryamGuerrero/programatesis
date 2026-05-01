from typing import Optional, Dict, Any, List
from .base import RepositorioBasePostgres
from ...domain.repositorios.interfaces import IRepositorioPerfil
from ...domain.modelos.usuario import PerfilUsuario
from ...core.supabase_client import get_supabase_admin_client

class RepositorioPerfilPostgres(RepositorioBasePostgres, IRepositorioPerfil):
    def obtener_por_auth_id(self, auth_id: str) -> Optional[PerfilUsuario]:
        sql = """
            select u.id, u.email, u.nombre_completo, r.nombre as rol_nombre, r.codigo as rol_codigo,
                   u.cedula, u.telefono, u.direccion
            from usuarios.usuario u
            join usuarios.rol r on r.id = u.id_rol
            where u.auth_user_id::text = %s
            limit 1
        """
        datos = self.ejecutar_uno(sql, (auth_id,))
        if not datos:
            return None
            
        return PerfilUsuario(
            id=str(datos["id"]),
            nombre_completo=datos["nombre_completo"],
            email=datos["email"],
            rol_nombre=datos["rol_nombre"],
            rol_codigo=datos["rol_codigo"],
            cedula=datos.get("cedula"),
            telefono=datos.get("telefono"),
            direccion=datos.get("direccion")
        )

    def actualizar_datos_perfil(self, auth_id: str, datos: dict) -> bool:
        """Actualiza los datos del perfil filtrando por auth_id."""
        return self.actualizar_usuario(auth_id, datos)

    def buscar_tutor_por_cedula(self, cedula: str) -> Optional[dict]:
        sql = """
            select id, nombre_completo, email, cedula, id_rol, telefono, direccion
            from usuarios.usuario
            where cedula = %s and id_rol = 4
            limit 1
        """
        return self.ejecutar_uno(sql, (cedula,))

    # --- Métodos de compatibilidad (Legacy) ---
    def obtener_perfil_usuario(self, user_id: str) -> Optional[Dict[str, Any]]:
        sql = """
            select u.id, u.email, u.nombre_completo, u.cedula, r.nombre as rol_nombre, r.codigo as rol_codigo, u.id_rol, u.telefono, u.direccion
            from usuarios.usuario u
            join usuarios.rol r on r.id = u.id_rol
            where u.auth_user_id::text = %s or u.id::text = %s
            limit 1
        """
        d = self.ejecutar_uno(sql, (user_id, user_id))
        if d:
            d["id"] = str(d["id"])
            d["rol"] = str(d.pop("rol_nombre")) # Priorizamos el nombre para el frontend
        return d

    def listar_usuarios(self) -> List[dict]:
        sql = """
            select 
                u.id, u.cedula, u.email, u.nombre_completo, 
                r.nombre as rol_nombre, r.codigo as rol_codigo,
                u.id_rol, u.activo, u.telefono, u.direccion
            from usuarios.usuario u
            join usuarios.rol r on r.id = u.id_rol
            order by u.nombre_completo
        """
        return self.ejecutar_consulta(sql)

    def crear_usuario(self, datos: dict) -> str:
        email = datos["email"].lower().strip()
        password = datos["password"]
        
        res_rol = self.ejecutar_uno("select codigo from usuarios.rol where id = %s", (datos["id_rol"],))
        rol_code = res_rol["codigo"] if res_rol else "tutor"

        admin_client = get_supabase_admin_client()
        auth_response = admin_client.auth.admin.create_user({
            "email": email,
            "password": password,
            "email_confirm": True,
            "user_metadata": {"full_name": datos["nombre_completo"], "role": rol_code},
            "app_metadata": {"role": rol_code}
        })
        auth_user_id = auth_response.user.id

        # Manejo de cédula vacía para evitar UniqueViolation
        cedula = datos.get("cedula")
        if cedula == "": cedula = None

        sql = """
            insert into usuarios.usuario (email, nombre_completo, cedula, id_rol, telefono, direccion, activo, auth_user_id)
            values (%s, %s, %s, %s, %s, %s, true, %s)
            returning id
        """
        params = (email, datos["nombre_completo"].strip(), cedula, datos["id_rol"],
                 datos.get("telefono"), datos.get("direccion"), auth_user_id)
        return str(self.ejecutar_comando(sql, params))

    def registrar_tutor_solo(self, datos: dict) -> str:
        from ...core.auth_onboarding import provision_auth_user_with_password_setup
        
        email = datos["email"].lower().strip()
        nombre = datos["nombre_completo"].strip()
        cedula = datos.get("cedula")
        if cedula == "": cedula = None
        
        # --- Lógica de Upsert: Buscar si ya existe por email ---
        existente = self.ejecutar_uno("select id from usuarios.usuario where email = %s limit 1", (email,))
        if existente:
            self.actualizar_usuario(str(existente["id"]), {
                "nombre_completo": nombre,
                "cedula": cedula,
                "telefono": datos.get("telefono"),
                "direccion": datos.get("direccion")
            })
            return str(existente["id"])
        
        # 1. Provisionar en Supabase Auth y enviar correo de bienvenida/contraseña
        auth_user_id, _ = provision_auth_user_with_password_setup(
            email=email,
            nombre_completo=nombre,
            role_code="tutor"
        )
        
        # 2. Insertar en nuestra tabla de usuarios (id_rol = 4 para tutor)
        sql = """
            insert into usuarios.usuario (
                email, nombre_completo, cedula, id_rol, 
                telefono, direccion, activo, auth_user_id
            )
            values (%s, %s, %s, 4, %s, %s, true, %s)
            returning id
        """
        params = (
            email, nombre, cedula, 
            datos.get("telefono"), datos.get("direccion"), auth_user_id
        )
        return str(self.ejecutar_comando(sql, params))

    def actualizar_usuario(self, user_id: str, datos: dict) -> bool:
        if not datos: return False
        campos_validos = {"nombre_completo", "cedula", "email", "id_rol", "activo", "telefono", "direccion"}
        items = {k: v for k, v in datos.items() if k in campos_validos}
        if not items: return False
        
        # Corrección crítica para Cédula: si viene vacía, poner NULL para evitar conflicto de unicidad
        if "cedula" in items and (items["cedula"] == "" or items["cedula"] is None):
            items["cedula"] = None

        columnas = ", ".join([f"{k} = %s" for k in items.keys()])
        sql = f"update usuarios.usuario set {columnas}, updated_at = now() where id = %s or auth_user_id::text = %s"
        
        from ...core.db import db_cursor
        with db_cursor() as cur:
            cur.execute(sql, list(items.values()) + [user_id, user_id])
            return cur.rowcount > 0

    def obtener_catalogo(self, esquema: str, tabla: str) -> List[dict]:
        esquemas_permitidos = {"usuarios", "nutricion", "clinico", "seguridad", "heuristico"}
        if esquema not in esquemas_permitidos: raise ValueError(f"Esquema {esquema} no permitido")
        sql = f"select * from {esquema}.{tabla}"
        return self.ejecutar_consulta(sql)

    # --- GESTIÓN DE CONDICIONES (PATOLOGÍAS/TEMPORALES) ---
    def crear_condicion(self, datos: dict) -> int:
        sql = """
            insert into heuristico.condicion (nombre, descripcion, id_tipo_condicion, activa)
            values (%s, %s, %s, true) returning id
        """
        return self.ejecutar_comando(sql, (datos["nombre"], datos["descripcion"], datos["id_tipo_condicion"]))

    def actualizar_condicion(self, id_condicion: int, datos: dict) -> bool:
        sql = "update heuristico.condicion set nombre = %s, descripcion = %s, id_tipo_condicion = %s, activa = %s where id = %s"
        return self.ejecutar_comando(sql, (datos["nombre"], datos["descripcion"], datos["id_tipo_condicion"], datos.get("activa", True), id_condicion))

    def eliminar_condicion(self, id_condicion: int) -> bool:
        sql = "delete from heuristico.condicion where id = %s"
        return self.ejecutar_comando(sql, (id_condicion,))
