import os
import sys
from io import BytesIO
from PIL import Image
from supabase import create_client, Client
from dotenv import dotenv_values
import requests

# Configuración
MAX_SIDE = 900
QUALITY = 68
BUCKETS = ["receta_imagenes", "imagenes_recetas"]

def list_all_files(supabase, bucket_name, path=""):
    files = []
    try:
        res = supabase.storage.from_(bucket_name).list(path)
        for obj in res:
            full_path = f"{path}/{obj['name']}" if path else obj['name']
            if obj.get('id') is None: # Es una carpeta
                files.extend(list_all_files(supabase, bucket_name, full_path))
            else:
                files.append(full_path)
    except Exception as e:
        print(f"Error listando {bucket_name}/{path}: {e}")
    return files

def migrate_images():
    # 1. Cargar variables de entorno
    env_path = os.path.join(os.path.dirname(__file__), "..", ".env")
    env = dotenv_values(env_path)
    
    url = env.get("SUPABASE_URL")
    key = env.get("SUPABASE_SERVICE_ROLE_KEY")
    
    if not url or not key:
        print("Error: SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY no encontrados en .env")
        return

    supabase: Client = create_client(url, key)

    for bucket_name in BUCKETS:
        print(f"\n--- Procesando Bucket: {bucket_name} ---")
        files = list_all_files(supabase, bucket_name)
        
        for name in files:
            if name.lower().endswith(('.jpg', '.jpeg', '.png')):
                print(f"Optimizando: {name}...")
                
                try:
                    # 1. Descargar
                    response = supabase.storage.from_(bucket_name).download(name)
                    
                    # 2. Convertir y Optimizar
                    img = Image.open(BytesIO(response))
                    
                    # Redimensionar si es necesario
                    if img.width > MAX_SIDE or img.height > MAX_SIDE:
                        scale = MAX_SIDE / max(img.width, img.height)
                        new_size = (int(img.width * scale), int(img.height * scale))
                        img = img.resize(new_size, Image.Resampling.LANCZOS)
                    
                    # Guardar como WebP en memoria
                    output = BytesIO()
                    img.save(output, format="WEBP", quality=QUALITY)
                    webp_data = output.getvalue()
                    
                    # 3. Subir nuevo archivo .webp
                    new_name = os.path.splitext(name)[0] + ".webp"
                    supabase.storage.from_(bucket_name).upload(
                        path=new_name,
                        file=webp_data,
                        file_options={"content-type": "image/webp", "x-upsert": "true"}
                    )
                    
                    new_url = supabase.storage.from_(bucket_name).get_public_url(new_name)
                    old_url = supabase.storage.from_(bucket_name).get_public_url(name)
                    
                    # 4. Actualizar Base de Datos
                    # Actualizar en tabla receta (esquema nutricion)
                    try:
                        supabase.schema("nutricion").table("receta").update({"imagen_url": new_url}).eq("imagen_url", old_url).execute()
                    except Exception as db_e:
                        print(f"  [DB Warning] No se pudo actualizar nutricion.receta: {db_e}")

                    # Actualizar en tabla receta_imagen (esquema public por defecto)
                    try:
                        supabase.table("receta_imagen").update({"imagen_url": new_url}).eq("imagen_url", old_url).execute()
                    except Exception as db_e:
                        print(f"  [DB Warning] No se pudo actualizar receta_imagen: {db_e}")

                    # 5. Borrar original si el nuevo es diferente
                    if new_name != name:
                        supabase.storage.from_(bucket_name).remove(name)
                        print(f"  [OK] Convertido a WebP y borrado original.")
                    else:
                        print(f"  [OK] Optimizado WebP existente.")

                except Exception as e:
                    print(f"  [Error] Falló proceso para {name}: {e}")

if __name__ == "__main__":
    migrate_images()
