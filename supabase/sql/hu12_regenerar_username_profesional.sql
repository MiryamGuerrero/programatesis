-- ==============================================================================
-- HU12: Regeneración automática de nombre de usuario profesional al actualizar
-- ==============================================================================
-- Corrige la función usuarios.generar_username_profesional() para que, cuando
-- se actualice el nombre completo o el rol de un profesional de la salud y no
-- se envíe un username manual, el sistema vuelva a generar el username
-- automáticamente con el prefijo profesional correspondiente (Dr. o Lic.)
-- y el nuevo nombre y apellido.
-- ==============================================================================

CREATE OR REPLACE FUNCTION usuarios.generar_username_profesional()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_prefijo TEXT;
    v_nombre_procesado TEXT;
    v_partes TEXT[];
    v_len INTEGER;
    v_nombre TEXT;
    v_apellido TEXT;
BEGIN
    -- 1. Si es UPDATE y se envió un username explícito y diferente al anterior, respetarlo
    IF (TG_OP = 'UPDATE' AND NEW.username IS DISTINCT FROM OLD.username AND NEW.username IS NOT NULL AND trim(NEW.username) <> '') THEN
        RETURN NEW;
    END IF;

    -- 2. Si es INSERT y ya viene con prefijo explícito (Dr. o Lic.), respetarlo
    IF (TG_OP = 'INSERT' AND NEW.username ~* '^(Dr\.|Lic\.)') THEN
        RETURN NEW;
    END IF;

    -- 3. Si es UPDATE y NO cambió el nombre_completo ni el id_rol, y ya tiene username, no modificarlo
    IF (TG_OP = 'UPDATE' 
        AND NEW.nombre_completo IS NOT DISTINCT FROM OLD.nombre_completo 
        AND NEW.id_rol IS NOT DISTINCT FROM OLD.id_rol
        AND NEW.username IS NOT NULL
        AND trim(NEW.username) <> '') THEN
        RETURN NEW;
    END IF;

    -- 4. Determinar prefijo según rol
    -- Roles: 2=MEDICO, 3=NUTRICIONISTA
    IF NEW.id_rol = 2 THEN
        v_prefijo := 'Dr. ';
    ELSIF NEW.id_rol = 3 THEN
        v_prefijo := 'Lic. ';
    ELSIF EXISTS (SELECT 1 FROM usuarios.usuario_rol ur WHERE ur.id_usuario = NEW.id AND ur.id_rol = 2) THEN
        v_prefijo := 'Dr. ';
    ELSIF EXISTS (SELECT 1 FROM usuarios.usuario_rol ur WHERE ur.id_usuario = NEW.id AND ur.id_rol = 3) THEN
        v_prefijo := 'Lic. ';
    ELSE
        -- No es médico ni nutricionista
        IF NEW.username IS NULL OR trim(NEW.username) = '' THEN
            NEW.username := SPLIT_PART(NEW.email, '@', 1);
        END IF;
        RETURN NEW;
    END IF;

    -- 5. Extraer nombre y apellido limpios
    v_nombre_procesado := regexp_replace(COALESCE(NEW.nombre_completo, ''), '^(Dr\.|Lic\.)\s*', '', 'i');
    v_partes := regexp_split_to_array(trim(v_nombre_procesado), '\s+');
    v_len := array_length(v_partes, 1);

    IF v_len IS NULL OR v_len = 0 THEN
        NEW.username := v_prefijo || SPLIT_PART(NEW.email, '@', 1);
        RETURN NEW;
    END IF;

    v_nombre := v_partes[1];
    v_apellido := '';

    IF v_len = 2 THEN
        -- Ejemplo: José López -> Dr. José López
        v_apellido := v_partes[2];
    ELSIF v_len = 3 THEN
        -- Ejemplo: Urbano Solis Cartas -> Dr. Urbano Solis
        -- o Juan de la Cruz -> Dr. Juan de la Cruz
        IF lower(v_partes[2]) IN ('de', 'del') THEN
            v_apellido := v_partes[2] || ' ' || v_partes[3];
        ELSE
            v_apellido := v_partes[2];
        END IF;
    ELSIF v_len >= 4 THEN
        -- Ejemplo: Carlos Andrés Mendoza Silva -> Dr. Carlos Mendoza
        -- Ejemplo: Jhoanna Belén Zúñiga Díaz -> Lic. Jhoanna Zúñiga
        IF lower(v_partes[2]) IN ('de', 'del', 'de la') THEN
            v_apellido := v_partes[v_len - 1];
        ELSE
            v_apellido := v_partes[3];
        END IF;
    END IF;

    NEW.username := v_prefijo || v_nombre || (CASE WHEN v_apellido <> '' THEN ' ' || v_apellido ELSE '' END);

    RETURN NEW;
END;
$function$;
