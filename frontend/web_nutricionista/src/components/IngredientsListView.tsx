import React, { useState, useEffect } from 'react';

// --- TIPOS ---
interface Ingredient {
  id: string;
  name: string;
  category: string;
  subgroup: string;
  tags: string[];
  calories: number;
  protein: number;
  isActive: boolean;
}

// --- DATOS MOCK (Para pruebas visuales) ---
const categories = ["Cereales y Granos", "Proteínas Animales", "Lácteos", "Frutas", "Verduras", "Legumbres", "Grasas Saludables"];
const subgroups = ["Grupo A", "Grupo B", "Grupo C", "Grupo D"];

const IngredientsListView: React.FC = () => {
  const [loading, setLoading] = useState(true);
  const [ingredients, setIngredients] = useState<Ingredient[]>([]);
  const [search, setSearch] = useState("");
  const [filterCategory, setFilterCategory] = useState("Todas");
  const [filterSubgroup, setFilterSubgroup] = useState("Todos");
  const [filterTag, setFilterTag] = useState("Todas");
  const [page, setPage] = useState(1);

  useEffect(() => {
    // Simular carga de datos con el loader solicitado
    const timer = setTimeout(() => {
      setIngredients([
        { id: "ing-001", name: "Arroz Integral", category: "Cereales y Granos", subgroup: "Grupo A", tags: ["Vegano", "Sin Gluten", "Integral", "Alto en Fibra"], calories: 370, protein: 8, isActive: true },
        { id: "ing-002", name: "Pollo Pechuga", category: "Proteínas Animales", subgroup: "Grupo B", tags: ["Alto en Proteína", "Bajo en Grasa"], calories: 165, protein: 31, isActive: true },
        { id: "ing-003", name: "Leche Deslactosada", category: "Lácteos", subgroup: "Grupo C", tags: ["Sin Lactosa", "Fuente de Calcio"], calories: 46, protein: 3.4, isActive: false },
        { id: "ing-004", name: "Espinaca", category: "Verduras", subgroup: "Grupo A", tags: ["Vegano", "Antioxidantes", "Bajo en Sodio"], calories: 23, protein: 2.9, isActive: true },
        { id: "ing-005", name: "Lentejas", category: "Legumbres", subgroup: "Grupo B", tags: ["Vegano", "Alto en Proteína", "Fuente de Hierro"], calories: 116, protein: 9, isActive: true },
        { id: "ing-006", name: "Salmón", category: "Proteínas Animales", subgroup: "Grupo D", tags: ["Omega 3", "Alto en Proteína"], calories: 208, protein: 20, isActive: true },
        { id: "ing-007", name: "Yogur Griego", category: "Lácteos", subgroup: "Grupo B", tags: ["Probióticos", "Sin Azúcar"], calories: 59, protein: 10, isActive: true },
        { id: "ing-008", name: "Aguacate", category: "Grasas Saludables", subgroup: "Grupo A", tags: ["Vegano", "Grasas Monoinsaturadas"], calories: 160, protein: 2, isActive: true },
        { id: "ing-009", name: "Quinoa", category: "Cereales y Granos", subgroup: "Grupo A", tags: ["Vegano", "Proteína Completa"], calories: 120, protein: 4.4, isActive: true },
        { id: "ing-010", name: "Huevo", category: "Proteínas Animales", subgroup: "Grupo B", tags: ["Alto en Proteína", "Fuente de Vitaminas"], calories: 155, protein: 13, isActive: true },
      ]);
      setLoading(false);
    }, 2000);
    return () => clearTimeout(timer);
  }, []);

  const capitalize = (s: string) => s.charAt(0).toUpperCase() + s.slice(1).toLowerCase();

  // --- COMPONENTES INTERNOS ---

  const KPI = ({ label, value, icon, color }: any) => (
    <div className="bg-white p-6 rounded-xl border border-gray-200 shadow-sm flex flex-col items-center transition-all hover:shadow-md">
      <span className={`text-4xl mb-3 ${color}`}>{icon}</span>
      <span className="text-3xl font-bold text-gray-900">{value}</span>
      <span className="text-sm text-gray-500 font-medium uppercase tracking-wider">{label}</span>
    </div>
  );

  const TagBadge = ({ name, type }: { name: string, type?: string }) => {
    let styles = "bg-gray-100 text-gray-700";
    if (name.includes("Vegano")) styles = "bg-green-100 text-green-700";
    if (name.includes("Gluten")) styles = "bg-yellow-100 text-yellow-700";
    if (name.includes("Proteína")) styles = "bg-blue-100 text-blue-700";
    if (name.includes("Integral")) styles = "bg-amber-100 text-amber-700";
    
    if (type === "more") styles = "bg-gray-200 text-gray-600 font-bold";

    return (
      <span className={`text-xs px-2.5 py-0.5 rounded-full font-semibold ${styles}`}>
        {name}
      </span>
    );
  };

  const SubgroupBadge = ({ group }: { group: string }) => {
    let styles = "bg-blue-100 text-blue-700";
    if (group.includes("B")) styles = "bg-purple-100 text-purple-700";
    if (group.includes("C")) styles = "bg-pink-100 text-pink-700";
    if (group.includes("D")) styles = "bg-orange-100 text-orange-700";

    return (
      <span className={`text-xs px-3 py-1 rounded-full font-bold ${styles}`}>
        {group}
      </span>
    );
  };

  if (loading) {
    return (
      <div className="flex flex-col items-center justify-center min-h-screen bg-slate-50">
        <div className="relative w-24 h-24 mb-6">
          <div className="absolute inset-0 border-4 border-green-200 rounded-full animate-ping"></div>
          <div className="absolute inset-0 flex items-center justify-center text-5xl animate-bounce">
            🥗
          </div>
        </div>
        <p className="text-xl font-bold text-slate-700 animate-pulse">Cargando nutrientes...</p>
        <div className="flex gap-4 mt-4 text-3xl">
          <span className="animate-bounce delay-75">🍎</span>
          <span className="animate-bounce delay-150">🥦</span>
          <span className="animate-bounce delay-300">🥕</span>
          <span className="animate-bounce delay-500">🥑</span>
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col min-h-screen bg-slate-50 p-8 font-inter">
      {/* HEADER */}
      <header className="flex justify-between items-center mb-8">
        <div>
          <h1 className="text-3xl font-extrabold text-slate-900 tracking-tight">Ingredientes</h1>
          <p className="text-slate-500 font-medium">Gestión profesional del catálogo nutricional</p>
        </div>
        <button className="bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-xl font-bold shadow-lg shadow-blue-200 transition-all flex items-center gap-2">
          <span>+</span> Nuevo Ingrediente
        </button>
      </header>

      {/* KPIs */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-10">
        <KPI label="Total Ingred." value="156" icon="📊" color="text-indigo-500" />
        <KPI label="Categorías" value="12" icon="🥗" color="text-emerald-500" />
        <KPI label="Activos" value="142" icon="✅" color="text-green-500" />
        <KPI label="Inactivos" value="14" icon="❌" color="text-red-500" />
      </div>

      {/* FILTROS */}
      <div className="bg-white p-6 rounded-2xl shadow-sm border border-slate-200 mb-6">
        <div className="flex flex-col md:flex-row gap-4">
          <div className="relative flex-1">
            <span className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400 text-xl">🔍</span>
            <input 
              type="text" 
              placeholder="Buscar ingrediente por nombre..." 
              className="w-full pl-12 pr-4 py-3 bg-slate-50 border border-slate-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all font-medium"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>
          <div className="flex gap-3 overflow-x-auto pb-2 md:pb-0">
            <select 
              className="bg-white border border-slate-200 px-4 py-3 rounded-xl outline-none focus:ring-2 focus:ring-blue-500 font-semibold text-slate-700 min-w-[160px]"
              value={filterCategory}
              onChange={(e) => setFilterCategory(e.target.value)}
            >
              <option>Categoría: Todas</option>
              {categories.map(c => <option key={c}>{c}</option>)}
            </select>
            <select 
              className="bg-white border border-slate-200 px-4 py-3 rounded-xl outline-none focus:ring-2 focus:ring-blue-500 font-semibold text-slate-700 min-w-[160px]"
              value={filterSubgroup}
              onChange={(e) => setFilterSubgroup(e.target.value)}
            >
              <option>Subgrupo: Todos</option>
              {subgroups.map(s => <option key={s}>{s}</option>)}
            </select>
            <button 
              className="text-slate-500 hover:text-red-500 font-bold px-4 transition-colors"
              onClick={() => { setSearch(""); setFilterCategory("Todas"); setFilterSubgroup("Todos"); }}
            >
              Limpiar
            </button>
          </div>
        </div>
      </div>

      {/* TABLA - OCUPA EL ESPACIO RESTANTE */}
      <div className="flex-1 bg-white rounded-2xl shadow-sm border border-slate-200 overflow-hidden flex flex-col">
        <div className="overflow-x-auto flex-1">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="bg-slate-50 border-bottom border-slate-100">
                <th className="px-6 py-4 text-xs font-bold text-slate-500 uppercase tracking-widest">Nombre</th>
                <th className="px-6 py-4 text-xs font-bold text-slate-500 uppercase tracking-widest">Categoría</th>
                <th className="px-6 py-4 text-xs font-bold text-slate-500 uppercase tracking-widest">Subgrupo</th>
                <th className="px-6 py-4 text-xs font-bold text-slate-500 uppercase tracking-widest">Etiquetas</th>
                <th className="px-6 py-4 text-xs font-bold text-slate-500 uppercase tracking-widest text-right">Kcal (100g)</th>
                <th className="px-6 py-4 text-xs font-bold text-slate-500 uppercase tracking-widest text-right">Proteína</th>
                <th className="px-6 py-4 text-xs font-bold text-slate-500 uppercase tracking-widest text-center">Acciones</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {ingredients.map((ing) => (
                <tr key={ing.id} className="hover:bg-blue-50/30 transition-colors group">
                  <td className="px-6 py-4">
                    <span className="font-bold text-blue-600 block">{ing.name}</span>
                  </td>
                  <td className="px-6 py-4 text-slate-600 font-medium">
                    {capitalize(ing.category)}
                  </td>
                  <td className="px-6 py-4">
                    <SubgroupBadge group={ing.subgroup} />
                  </td>
                  <td className="px-6 py-4">
                    <div className="flex gap-2 items-center">
                      {ing.tags.slice(0, 2).map(tag => <TagBadge key={tag} name={tag} />)}
                      {ing.tags.length > 2 && (
                        <div className="relative group/tooltip">
                          <TagBadge name={`+${ing.tags.length - 2}`} type="more" />
                          <div className="absolute bottom-full left-1/2 -translate-x-1/2 mb-2 hidden group-hover/tooltip:block bg-slate-900 text-white text-[10px] py-1 px-2 rounded whitespace-nowrap z-50 shadow-xl">
                            {ing.tags.slice(2).join(", ")}
                          </div>
                        </div>
                      )}
                    </div>
                  </td>
                  <td className="px-6 py-4 text-right font-bold text-slate-700">
                    {ing.calories}
                  </td>
                  <td className="px-6 py-4 text-right font-bold text-slate-700">
                    {ing.protein}g
                  </td>
                  <td className="px-6 py-4">
                    <div className="flex items-center justify-center gap-3">
                      <button className="text-blue-500 hover:scale-110 transition-transform text-xl" title="Ver">👁️</button>
                      <button className="text-slate-400 hover:text-slate-600 hover:scale-110 transition-transform text-xl" title="Editar">✏️</button>
                      <button className={`w-8 h-8 rounded-full flex items-center justify-center transition-all ${ing.isActive ? 'bg-green-500 shadow-green-100' : 'bg-red-500 shadow-red-100'} text-white shadow-lg hover:brightness-110 active:scale-95`}>
                        {ing.isActive ? "🟢" : "🔴"}
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
              {/* Relleno para asegurar que siempre se vean 10 filas o el espacio completo */}
              {[...Array(Math.max(0, 10 - ingredients.length))].map((_, i) => (
                <tr key={`empty-${i}`} className="h-[64px] border-none">
                  <td colSpan={7}></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {/* PAGINACIÓN */}
        <footer className="bg-slate-50 border-t border-slate-100 px-8 py-4 flex justify-between items-center">
          <span className="text-sm text-slate-500 font-bold">
            Mostrando 1-10 de 156 ingredientes
          </span>
          <div className="flex items-center gap-1">
            <button className="p-2 text-slate-400 hover:text-slate-900 font-black disabled:opacity-30" disabled>&lt; Anterior</button>
            {[1, 2, 3].map(p => (
              <button 
                key={p} 
                className={`w-9 h-9 rounded-lg font-bold transition-all ${p === 1 ? 'bg-blue-600 text-white shadow-md shadow-blue-200' : 'text-slate-600 hover:bg-slate-200'}`}
              >
                {p}
              </button>
            ))}
            <span className="px-2 text-slate-400 font-bold">...</span>
            <button className="w-9 h-9 rounded-lg font-bold text-slate-600 hover:bg-slate-200">16</button>
            <button className="p-2 text-slate-400 hover:text-slate-900 font-black">Siguiente &gt;</button>
          </div>
        </footer>
      </div>
    </div>
  );
};

export default IngredientsListView;
