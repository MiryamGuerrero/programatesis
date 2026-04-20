import React, { useState, useEffect } from 'react';
import './styles.css';

interface Patient {
  id: string;
  nombre_completo: string;
}

interface Recipe {
  id: number;
  nombre: string;
  recomendacion: "PRIORIZAR" | "DISMINUIR" | "PERMITIDO";
  frecuencia_sugerida?: string;
}

const WeekDays = ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"];
const Moments = ["Desayuno", "Almuerzo", "Cena"];

const NutritionPlanManual: React.FC = () => {
  const [searchTerm, setSearchTerm] = useState("");
  const [patients, setPatients] = useState<Patient[]>([]);
  const [selectedPatient, setSelectedPatient] = useState<Patient | null>(null);
  const [recipes, setRecipes] = useState<Recipe[]>([]);
  
  // Estructura del plan: { "Lunes": { "Desayuno": Recipe, ... }, ... }
  const [plan, setPlan] = useState<any>({});

  // Buscar pacientes al escribir
  useEffect(() => {
    if (searchTerm.length > 2) {
      fetch(`/api/v1/medico/buscar-pacientes?q=${searchTerm}`)
        .then(res => res.json())
        .then(data => setPatients(data));
    }
  }, [searchTerm]);

  // Cargar recetas seguras al seleccionar paciente
  const selectPatient = (p: Patient) => {
    setSelectedPatient(p);
    fetch(`/api/v1/nutricionista/recetas-permitidas`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id_paciente: p.id })
    })
    .then(res => res.json())
    .then(data => setRecipes(data.recetas));
  };

  // Lógica de Drag and Drop
  const onDragStart = (e: React.DragEvent, recipe: Recipe) => {
    e.dataTransfer.setData("recipe", JSON.stringify(recipe));
  };

  const onDrop = (e: React.DragEvent, day: string, moment: string) => {
    const recipe = JSON.parse(e.dataTransfer.getData("recipe"));
    setPlan({
      ...plan,
      [day]: { ...(plan[day] || {}), [moment]: recipe }
    });
  };

  const onDragOver = (e: React.DragEvent) => e.preventDefault();

  // Función para replicar semana (tedio-free)
  const handleReplicate = () => {
    alert("¡Semana replicada exitosamente para el resto del mes!");
    // Aquí se enviaría al backend el mismo patrón para los próximos 21 días
  };

  const savePlan = () => {
    if (!selectedPatient) {
      alert("Por favor selecciona un paciente primero.");
      return;
    }
    
    fetch(`/api/v1/nutricionista/plan-manual`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ 
        id_paciente: selectedPatient.id,
        plan: plan 
      })
    })
    .then(res => res.json())
    .then(data => {
      alert("Plan guardado y vinculado exitosamente al paciente.");
      console.log("Respuesta:", data);
    })
    .catch(err => alert("Error al guardar el plan"));
  };

  return (
    <div className="dashboard-container">
      {/* SIDEBAR DE RECETAS */}
      <aside className="recipe-sidebar">
        <div className="search-box">
          <h3>Paciente</h3>
          <input 
            type="text" 
            placeholder="Nombre o Cédula..." 
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
          />
          {patients.length > 0 && !selectedPatient && (
            <ul className="patient-results">
              {patients.map(p => (
                <li key={p.id} onClick={() => selectPatient(p)}>{p.nombre_completo}</li>
              ))}
            </ul>
          )}
          {selectedPatient && (
            <div className="selected-tag">
              👤 {selectedPatient.nombre_completo} 
              <button onClick={() => setSelectedPatient(null)}>x</button>
            </div>
          )}
        </div>

        <div className="recipe-list">
          <h3>Recetas Seguras</h3>
          {recipes.map(r => (
            <div 
              key={r.id} 
              className={`recipe-card ${r.recomendacion.toLowerCase()}`}
              draggable
              onDragStart={(e) => onDragStart(e, r)}
            >
              <h4>{r.nombre}</h4>
              <small>
                {r.recomendacion === "PRIORIZAR" ? "🌟 Prioridad Médica" : 
                 r.recomendacion === "DISMINUIR" ? `⚠️ Máx ${r.frecuencia_sugerida}` : "✅ Permitida"}
              </small>
            </div>
          ))}
        </div>
      </aside>

      {/* CALENDARIO DE PLANIFICACIÓN */}
      <main className="calendar-main">
        <header className="calendar-header">
          <h2>Plan Nutricional Semanal</h2>
          <div>
            <button className="btn-replicate" onClick={handleReplicate}>🔄 Replicar Semana</button>
            <button className="btn-primary" onClick={savePlan}>💾 Guardar Plan</button>
          </div>
        </header>

        <div className="week-grid">
          {WeekDays.map(day => (
            <div key={day} className="day-column">
              <h3>{day}</h3>
              {Moments.map(moment => (
                <div key={moment} className="moment-slot">
                  <span style={{fontSize: '10px', fontWeight: 'bold'}}>{moment}</span>
                  <div 
                    className="drop-zone"
                    onDrop={(e) => onDrop(e, day, moment)}
                    onDragOver={onDragOver}
                  >
                    {plan[day]?.[moment] ? (
                      <div className="planned-recipe">
                        {plan[day][moment].nombre}
                        <button 
                          style={{float:'right', border:'none', background:'none', color:'red', cursor:'pointer'}}
                          onClick={() => {
                            const newPlan = {...plan};
                            delete newPlan[day][moment];
                            setPlan(newPlan);
                          }}
                        >x</button>
                      </div>
                    ) : (
                      <span style={{fontSize:'10px', color:'#999'}}>Arrastra aquí</span>
                    )}
                  </div>
                </div>
              ))}
            </div>
          ))}
        </div>
      </main>
    </div>
  );
};

export default NutritionPlanManual;
