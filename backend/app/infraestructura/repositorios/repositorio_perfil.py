from typing import Optional, Dict, Any, List
import re
import time
from app.infraestructura.database.db import db_cursor
from .base import RepositorioBasePostgres
from ...domain.repositorios.interfaces import IRepositorioPerfil
from ...domain.modelos.usuario import PerfilUsuario
from app.infraestructura.supabase.client import get_supabase_admin_client

class RepositorioPerfilPostgres(RepositorioBasePostgres, IRepositorioPerfil):
    ROL_CODIGO_SQL = """
        case
            when r.id = 1 or lower(r.nombre) in ('admin', 'administrador') then 'admin'
            when r.id = 2 or lower(r.nombre) = 'medico' then 'medico'
            when r.id = 3 or lower(r.nombre) = 'nutricionista' then 'nutricionista'
            when r.id = 4 or lower(r.nombre) = 'tutor' then 'tutor'
            else btrim(
                regexp_replace(
                    lower(r.nombre),
                    '[^a-z0-9]+',
                    '_',
                    'g'
                ),
                '_'
            )
        end
    """

    def obtener_por_auth_id(self, auth_id: str) -> Optional[PerfilUsuario]:
        sql = f"""
            select u.id, u.email, u.nombre_completo, u.username, r.nombre as rol_nombre,
                   {self.ROL_CODIGO_SQL} as rol_codigo, u.id_rol, u.activo,
                   u.cedula, u.telefono, u.direccion,
                   (
                       select string_agg(distinct par.nombre, ', ')
                       from usuarios.tutor_paciente tp
                       join usuarios.parentesco par on par.id = tp.id_parentesco
                       where tp.id_usuario_tutor = u.id and tp.activo = true
                   ) as parentesco
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
            username=datos.get("username"),
            email=datos["email"],
            rol_nombre=datos["rol_nombre"],
            rol_codigo=datos.get("rol_codigo") or "",
            id_rol=datos.get("id_rol"),
            activo=datos.get("activo"),
            cedula=datos.get("cedula"),
            telefono=datos.get("telefono"),
            direccion=datos.get("direccion"),
            parentesco=datos.get("parentesco")
        )

    def actualizar_datos_perfil(self, auth_id: str, datos: dict) -> bool:
        """Actualiza los datos del perfil filtrando por auth_id."""
        return self.actualizar_usuario(auth_id, datos)

    def buscar_tutor_por_cedula(self, cedula: str) -> Optional[dict]:
        # Limpiamos la cédula de espacios para la búsqueda robusta en Python
        cedula_limpia = str(cedula).strip()
        sql = """
            select id, nombre_completo, email, cedula, id_rol, telefono, direccion
            from usuarios.usuario
            where trim(cedula) = %s and id_rol = 4
            limit 1
        """
        res = self.ejecutar_uno(sql, (cedula_limpia,))
        if res and 'id' in res:
            res['id'] = str(res['id']) # Convertir UUID a string para serialización segura
        return res

    # --- Métodos de compatibilidad (Legacy) ---
    def obtener_perfil_usuario(self, user_id: str) -> Optional[Dict[str, Any]]:
        sql = f"""
            select u.id, u.email, u.nombre_completo, u.username, u.cedula,
                   r.nombre as rol_nombre, {self.ROL_CODIGO_SQL} as rol_codigo,
                   u.id_rol, u.telefono, u.direccion, u.activo,
                   (
                       select string_agg(distinct par.nombre, ', ')
                       from usuarios.tutor_paciente tp
                       join usuarios.parentesco par on par.id = tp.id_parentesco
                       where tp.id_usuario_tutor = u.id and tp.activo = true
                   ) as parentesco
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
        sql = f"""
            select 
                u.id, u.cedula, u.email, u.nombre_completo, u.username,
                r.nombre as rol_nombre,
                {self.ROL_CODIGO_SQL} as rol_codigo,
                u.id_rol, u.activo, u.telefono, u.direccion
            from usuarios.usuario u
            join usuarios.rol r on r.id = u.id_rol
            order by u.nombre_completo
        """
        return self.ejecutar_consulta(sql)

    def listar_usuarios_paginado(self, 
                                q: Optional[str] = None, 
                                rol_ids: Optional[List[int]] = None,
                                limit: int = 10, 
                                offset: int = 0,
                                include_total: bool = False) -> Dict[str, Any]:
        where_clauses = []
        params = []
        
        if q:
            where_clauses.append("(u.nombre_completo ilike %s or u.email ilike %s)")
            params.extend([f"%{q}%", f"%{q}%"])
            
        if rol_ids:
            where_clauses.append("u.id_rol = any(%s)")
            params.append(rol_ids)
            
        where_str = f"where {' and '.join(where_clauses)}" if where_clauses else ""
        
        total = 0
        if include_total:
            sql_count = f"select count(*) from usuarios.usuario u {where_str}"
            res_count = self.ejecutar_uno(sql_count, tuple(params))
            total = res_count["count"] if res_count else 0
            
        sql = f"""
            select 
                u.id, u.cedula, u.email, u.nombre_completo, u.username,
                r.nombre as rol_nombre,
                {self.ROL_CODIGO_SQL} as rol_codigo,
                u.id_rol, u.activo, u.telefono, u.direccion
            from usuarios.usuario u
            join usuarios.rol r on r.id = u.id_rol
            {where_str}
            order by u.nombre_completo
            limit %s offset %s
        """
        items = self.ejecutar_consulta(sql, tuple(params + [limit, offset]))
        
        return {"items": items, "total": total}

    def crear_usuario(self, datos: dict) -> str:
        from ...core.auth_onboarding import provision_auth_user_with_password_setup
        
        email = datos["email"].lower().strip()
        username = (datos.get("username") or email.split("@")[0]).lower().strip()
        
        cedula = datos.get("cedula")
        if cedula == "": cedula = None

        # 1. Pre-validación de constraints para dar un mensaje amigable
        existente = self.ejecutar_uno(
            "select email, cedula from usuarios.usuario where email = %s or (cedula = %s and cedula is not null) limit 1",
            (email, cedula)
        )
        if existente:
            if existente["cedula"] == cedula:
                raise ValueError(f"La cédula {cedula} ya está registrada.")
            if existente["email"] == email:
                raise ValueError(f"El correo {email} ya está registrado.")
        
        res_rol = self.ejecutar_uno("select nombre from usuarios.rol where id = %s", (datos["id_rol"],))
        rol_name = res_rol["nombre"].lower() if res_rol else "tutor"

        # 2. Crear en Supabase Auth
        auth_user_id, _ = provision_auth_user_with_password_setup(
            email=email,
            nombre_completo=datos["nombre_completo"],
            role_code=rol_name,
            password=datos.get("password")
        )

        # 3. Intentar insertar en la BD
        sql = """
            insert into usuarios.usuario (email, username, nombre_completo, cedula, id_rol, telefono, direccion, activo, auth_user_id)
            values (%s, %s, %s, %s, %s, %s, %s, true, %s)
            returning id
        """
        params = (email, username, datos["nombre_completo"].strip(), cedula, datos["id_rol"],
                 datos.get("telefono"), datos.get("direccion"), auth_user_id)
        
        try:
            return str(self.ejecutar_comando(sql, params))
        except Exception as e:
            # Rollback: Eliminar al usuario de Supabase Auth si la inserción local falló por cualquier motivo
            from ...core.auth_onboarding import delete_auth_user
            try:
                delete_auth_user(auth_user_id)
            except Exception:
                pass
            raise ValueError(f"No se pudo crear el usuario en la base de datos local: {str(e)}")

    def registrar_tutor_solo(self, datos: dict) -> str:
        from ...core.auth_onboarding import provision_auth_user_with_password_setup
        
        email = datos["email"].lower().strip()
        nombre = datos["nombre_completo"].strip()
        username = (datos.get("username") or email.split("@")[0]).lower().strip()
        cedula = datos.get("cedula")
        if cedula == "": cedula = None
        
        # --- Lógica de Upsert: Buscar si ya existe por email ---
        existente = self.ejecutar_uno("select id from usuarios.usuario where email = %s limit 1", (email,))
        if existente:
            self.actualizar_usuario(str(existente["id"]), {
                "nombre_completo": nombre,
                "username": username,
                "cedula": cedula,
                "telefono": datos.get("telefono"),
                "direccion": datos.get("direccion")
            })
            return str(existente["id"])
            
        # Pre-validar cédula si es provista
        if cedula:
            existe_cedula = self.ejecutar_uno("select id from usuarios.usuario where cedula = %s limit 1", (cedula,))
            if existe_cedula:
                raise ValueError(f"La cédula {cedula} ya está registrada.")
        
        # 1. Provisionar en Supabase Auth y enviar correo de bienvenida/contraseña
        auth_user_id, _ = provision_auth_user_with_password_setup(
            email=email,
            nombre_completo=nombre,
            role_code="tutor"
        )
        
        # 2. Insertar en nuestra tabla de usuarios (id_rol = 4 para tutor)
        sql = """
            insert into usuarios.usuario (
                email, username, nombre_completo, cedula, id_rol,
                telefono, direccion, activo, auth_user_id
            )
            values (%s, %s, %s, %s, 4, %s, %s, true, %s)
            returning id
        """
        params = (
            email, username, nombre, cedula,
            datos.get("telefono"), datos.get("direccion"), auth_user_id
        )
        
        try:
            return str(self.ejecutar_comando(sql, params))
        except Exception as e:
            # Rollback: Eliminar de Supabase si la BD falla
            from ...core.auth_onboarding import delete_auth_user
            try:
                delete_auth_user(auth_user_id)
            except Exception:
                pass
            raise ValueError(f"No se pudo registrar al tutor en la base de datos local: {str(e)}")

    def actualizar_usuario(self, user_id: str, datos: dict) -> bool:
        if not datos: return False
        campos_validos = {"nombre_completo", "cedula", "email", "id_rol", "activo", "telefono", "direccion", "username"}
        items = {k: v for k, v in datos.items() if k in campos_validos}
        if not items: return False
        
        # Corrección crítica para Cédula: si viene vacía, poner NULL para evitar conflicto de unicidad
        if "cedula" in items and (items["cedula"] == "" or items["cedula"] is None):
            items["cedula"] = None

        columnas = ", ".join([f"{k} = %s" for k in items.keys()])
        sql = f"update usuarios.usuario set {columnas}, updated_at = now() where id = %s or auth_user_id::text = %s"
        
        from app.infraestructura.database.db import db_cursor
        with db_cursor() as cur:
            cur.execute(sql, list(items.values()) + [user_id, user_id])
            return cur.rowcount > 0

    def eliminar_usuario(self, user_id: str) -> bool:
        from app.infraestructura.database.db import db_cursor
        from app.infraestructura.supabase.client import get_supabase_admin_client
        
        usuario = self.ejecutar_uno("select auth_user_id from usuarios.usuario where id::text = %s", (user_id,))
        if not usuario:
            return False
            
        auth_id = str(usuario.get("auth_user_id") or "")
        
        with db_cursor() as cur:
            cur.execute("delete from usuarios.usuario where id::text = %s", (user_id,))
            exito = cur.rowcount > 0
            
        if exito and auth_id and auth_id != "None":
            try:
                supa = get_supabase_admin_client()
                supa.auth.admin.delete_user(auth_id)
            except Exception:
                pass
                
        return exito

    def obtener_catalogo_paginado_v2(
        self, esquema: str, tabla: str, limit: int = 10, offset: int = 0, 
        filtro_tipos: List[int] = None, indicador: str = None, 
        q: str = None, include_total: bool = False
    ) -> dict:
        """Versión paginada avanzada con soporte de filtros por indicador y búsqueda."""
        esquemas_permitidos = {"usuarios", "nutricion", "clinico", "seguridad", "heuristico"}
        if esquema not in esquemas_permitidos:
            raise ValueError(f"Esquema {esquema} no permitido")

        where_clauses = []
        params = []
        
        if filtro_tipos:
            if tabla == "condicion":
                where_clauses.append("id_tipo_condicion = ANY(%s)")
                params.append(filtro_tipos)
            elif tabla == "usuario":
                where_clauses.append("id_rol = ANY(%s)")
                params.append(filtro_tipos)

        if indicador and tabla == "condicion":
            if indicador.upper() == "HFA":
                where_clauses.append("upper(indicador_codigo) = 'HFA'")
            else:
                where_clauses.append("upper(indicador_codigo) != 'HFA'")
        
        if q:
            where_clauses.append("nombre ilike %s")
            params.append(f"%{q}%")

        where_sql = ""
        if where_clauses:
            where_sql = " WHERE " + " AND ".join(where_clauses)

        total = 0
        from app.infraestructura.database.db import db_cursor
        with db_cursor() as cur:
            if include_total:
                sql_count = f"SELECT count(*) FROM {esquema}.{tabla} {where_sql}"
                cur.execute(sql_count, tuple(params))
                total = cur.fetchone()[0]
            
            if esquema == "heuristico" and tabla == "condicion":
                sql_items = f"SELECT *, dias_duracion_estandar as duracion_dias_sugerida FROM {esquema}.{tabla} {where_sql} ORDER BY nombre LIMIT %s OFFSET %s"
            else:
                sql_items = f"SELECT * FROM {esquema}.{tabla} {where_sql} ORDER BY id LIMIT %s OFFSET %s"

            params_items = params + [limit, offset]
            cur.execute(sql_items, tuple(params_items))
            cols = [d[0] for d in cur.description]
            items = [dict(zip(cols, row)) for row in cur.fetchall()]

            return {"items": items, "total": total}

    def obtener_catalogo(self, esquema: str, tabla: str, filtro_tipos: List[int] = None) -> List[dict]:
        esquemas_permitidos = {"usuarios", "nutricion", "clinico", "seguridad", "heuristico"}
        if esquema not in esquemas_permitidos: raise ValueError(f"Esquema {esquema} no permitido")
        
        # Especial para tabla condicion: asegurar que el frontend reciba el nombre de campo que espera
        if esquema == "heuristico" and tabla == "condicion":
            sql = "select *, dias_duracion_estandar as duracion_dias_sugerida from heuristico.condicion"
        elif esquema == "nutricion" and tabla == "etiqueta_nutricional":
            sql = "select id, nombre_visible as nombre, nombre_visible, codigo, descripcion, created_at from nutricion.etiqueta_nutricional"
        elif esquema == "nutricion" and tabla == "ingrediente":
            # Realizamos JOIN con grupo_alimentario para obtener el nombre legible de la categoría
            sql = """
                select i.*, g.nombre as categoria 
                from nutricion.ingrediente i
                left join nutricion.grupo_alimentario g on g.id = i.id_grupo_alimentario
            """
        else:
            sql = f"select * from {esquema}.{tabla}"
            
        params = []
        
        if filtro_tipos and tabla == "condicion":
            sql += " where id_tipo_condicion = any(%s)"
            params.append(filtro_tipos)
            
        return self.ejecutar_consulta(sql, params)

    # --- GESTIÓN DE CONDICIONES (PATOLOGÍAS/TEMPORALES) ---
    def crear_condicion(self, datos: dict) -> int:
        nombre = datos.get("nombre")
        if not nombre:
            raise ValueError("El nombre de la condición es requerido")
            
        descripcion = datos.get("descripcion", "")
        
        # Obtener id_tipo de forma segura
        id_tipo_raw = datos.get("id_tipo_condicion") or datos.get("id_tipo")
        try:
            id_tipo = int(id_tipo_raw) if id_tipo_raw is not None and str(id_tipo_raw).strip() != "" else None
        except (ValueError, TypeError):
            id_tipo = None
            
        if not id_tipo:
            raise ValueError("El tipo de condición es requerido y debe ser un número")
            
        # Priorizar duracion_dias_sugerida (usado por el frontend)
        duracion_raw = datos.get("duracion_dias_sugerida")
        if duracion_raw is None or str(duracion_raw).strip() == "":
            duracion_raw = datos.get("dias_duracion_estandar")
            
        # Convertir duracion a int o None de forma segura
        try:
            duracion = int(duracion_raw) if duracion_raw is not None and str(duracion_raw).strip() != "" else None
        except (ValueError, TypeError):
            duracion = None
            
        # Si no es temporal (id=2), forzar duración a null
        if id_tipo != 2:
            duracion = None
            
        activa = datos.get("activa")
        if activa is None:
            activa = True
        else:
            activa = str(activa).lower() == 'true' or activa is True

        # Generar indicador_codigo automáticamente si no se proporciona
        indicador = datos.get("indicador_codigo")
        if not indicador:
            indicador = re.sub(r'[^a-z0-9_]', '', nombre.lower().replace(" ", "_"))
            if not indicador:
                indicador = f"condicion_{int(time.time())}"
        
        # Limitar longitud para seguridad (BD tiene 100 ahora)
        indicador = indicador[:90]
        
        # Verificar si ya existe el indicador para evitar conflicto (solo si se generó automáticamente)
        if not datos.get("indicador_codigo"):
            existente = self.ejecutar_uno("select id from heuristico.condicion where indicador_codigo = %s", (indicador,))
            if existente:
                indicador = f"{indicador[:80]}_{int(time.time())}"

        sql = """
            insert into heuristico.condicion (nombre, descripcion, id_tipo_condicion, activa, dias_duracion_estandar, indicador_codigo)
            values (%s, %s, %s, %s, %s, %s) returning id
        """
        try:
            return self.ejecutar_comando(sql, (
                nombre, 
                descripcion, 
                id_tipo,
                activa,
                duracion,
                indicador
            ))
        except Exception as e:
            # Si hay un error de base de datos, lo relanzamos con un mensaje más claro
            raise ValueError(f"Error de base de datos al crear condición: {str(e)}")

    def actualizar_condicion(self, id_condicion: int, datos: dict) -> bool:
        nombre = datos.get("nombre")
        
        id_tipo_raw = datos.get("id_tipo_condicion") or datos.get("id_tipo")
        try:
            id_tipo = int(id_tipo_raw) if id_tipo_raw is not None and str(id_tipo_raw).strip() != "" else None
        except (ValueError, TypeError):
            id_tipo = None
            
        if not nombre or not id_tipo:
            raise ValueError("Nombre e id_tipo_condicion son requeridos")

        duracion_raw = datos.get("duracion_dias_sugerida")
        if duracion_raw is None or str(duracion_raw).strip() == "":
            duracion_raw = datos.get("dias_duracion_estandar")
            
        try:
            duracion = int(duracion_raw) if duracion_raw is not None and str(duracion_raw).strip() != "" else None
        except (ValueError, TypeError):
            duracion = None
            
        # Si no es temporal (id=2), forzar duración a null
        if id_tipo != 2:
            duracion = None

        activa = datos.get("activa")
        if activa is None:
            activa = True
        else:
            activa = str(activa).lower() == 'true' or activa is True

        # Permitir actualizar el indicador si se proporciona (útil para corregir categorización)
        indicador = datos.get("indicador_codigo")
        
        if indicador:
            sql = """
                update heuristico.condicion 
                set nombre = %s, descripcion = %s, id_tipo_condicion = %s, activa = %s, dias_duracion_estandar = %s, indicador_codigo = %s
                where id = %s
                returning id
            """
            params = (nombre, datos.get("descripcion", ""), id_tipo, activa, duracion, indicador, id_condicion)
        else:
            sql = """
                update heuristico.condicion 
                set nombre = %s, descripcion = %s, id_tipo_condicion = %s, activa = %s, dias_duracion_estandar = %s 
                where id = %s
                returning id
            """
            params = (nombre, datos.get("descripcion", ""), id_tipo, activa, duracion, id_condicion)
            
        try:
            res = self.ejecutar_comando(sql, params)
            return res is not None
        except Exception as e:
            raise ValueError(f"Error de base de datos al actualizar condición: {str(e)}")

    def eliminar_condicion(self, id_condicion: int) -> bool:
        sql = "delete from heuristico.condicion where id = %s"
        return self.ejecutar_comando(sql, (id_condicion,))
