from app.core.db import db_cursor
from app.core.auth_onboarding import delete_auth_user

def purge_orphan_tutors():
    with db_cursor() as cur:
        try:
            print("Iniciando purga de tutores huérfanos...")
            
            # 1. Encontrar tutores (rol 4) que no están en la tabla de vínculos
            cur.execute("""
                SELECT u.id, u.auth_user_id, u.nombre_completo 
                FROM usuarios.usuario u
                WHERE u.id_rol = 4 
                AND NOT EXISTS (
                    SELECT 1 FROM usuarios.tutor_paciente tp 
                    WHERE tp.id_usuario_tutor = u.id
                )
            """)
            orphans = cur.fetchall()
            
            if not orphans:
                print("✅ No se encontraron tutores huérfanos. La tabla ya está limpia.")
                return

            print(f"Se encontraron {len(orphans)} tutores huérfanos. Procediendo a eliminar...")
            
            for tutor_id, auth_id, nombre in orphans:
                # Borrar de la base de datos local
                cur.execute("DELETE FROM usuarios.usuario WHERE id = %s", (tutor_id,))
                print(f"  - Eliminado de DB: {nombre}")
                
                # Borrar de Supabase Auth si tiene cuenta
                if auth_id:
                    try:
                        delete_auth_user(auth_id)
                        print(f"    - Cuenta Auth eliminada para: {nombre}")
                    except Exception as e:
                        print(f"    - ⚠️ No se pudo borrar cuenta Auth (posiblemente ya no existe): {e}")

            print(f"✅ Purga completada. Se eliminaron {len(orphans)} registros.")
        except Exception as e:
            print(f"❌ Error durante la purga: {e}")

if __name__ == "__main__":
    purge_orphan_tutors()
