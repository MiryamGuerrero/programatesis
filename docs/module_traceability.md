# Trazabilidad de Requisitos

## Roles

- Admin: gestion de usuarios y catalogos
- Medico: registro clinico, diagnostico OMS, reglas medicas
- Nutricionista: ingredientes, recetas, plan manual, reglas nutricionales
- Tutor: ver plan, consumo, reemplazos, calificacion

## Modulos del sistema

1. Gestion de usuarios
   - Flutter: features/admin/presentation/admin_users_page.dart
   - Supabase: usuarios.usuario

2. Gestion de pacientes (uno o varios por tutor)
   - Supabase: usuarios.paciente + usuarios.tutor_paciente
   - RLS: supabase/rls_policies.sql (funcion is_tutor_of_patient)

3. Registro clinico
   - Flutter: features/medico/presentation/registro_clinico_page.dart
   - Supabase: clinico.control_paciente

4. Diagnostico OMS automatico (Z-score)
   - FastAPI: POST /diagnostico-oms
   - Servicio: backend/app/services/admin_medico/anthropometry_service.py

5. Gestion de condiciones
   - Supabase: heuristico.condicion + clinico.diagnostico_paciente
   - FastAPI: usado en reglas-evaluacion e ingredientes-permitidos

6. Motor de reglas (Eliminar, Reducir, Priorizar)
   - FastAPI: POST /reglas-evaluacion
   - Servicio: backend/app/services/compartido/rules_engine_service.py

7. Gestion de ingredientes, grupos y etiquetas
   - Flutter: features/nutricionista/presentation/ingredientes_page.dart
   - Supabase: nutricion.ingrediente, grupo_alimentario, etiqueta_nutricional

8. Repositorio de recetas
   - Flutter: features/nutricionista/presentation/recetas_page.dart
   - Supabase: nutricion.receta

9. Calculo nutricional automatico
   - FastAPI: dentro de POST /recetas-permitidas
   - Repositorio: list_recipe_nutrient_totals

10. Generacion de recetas permitidas
   - FastAPI: POST /recetas-permitidas

11. Planificacion nutricional manual (semana tipo + replicacion)
   - Flutter: features/nutricionista/presentation/plan_manual_page.dart

12. Plan automatico
   - FastAPI: POST /plan-automatico

13. Reemplazo por equivalentes
   - FastAPI: POST /reemplazo-equivalente
   - Flutter: features/tutor/presentation/reemplazo_page.dart

14. Registro de consumo (adherencia)
   - Flutter: features/tutor/presentation/consumo_page.dart
   - Supabase: interaccion.seguimiento_plan_item

15. Recomendacion puntual
   - Base de datos preparada: interaccion.recomendacion_puntual
   - Punto de extension recomendado en FastAPI sobre recetas-permitidas

16. Calificacion de recetas
   - Flutter: features/tutor/presentation/calificacion_page.dart
   - Supabase: interaccion.evaluacion_receta

17. Aprendizaje de preferencias
   - FastAPI: POST /preferencias-aprendidas

18. Comparacion adherencia vs dolor
   - FastAPI: POST /adherencia-calculo
   - Servicio: backend/app/services/admin_medico/adherence_service.py
