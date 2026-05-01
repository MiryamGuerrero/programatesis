class Ingrediente {
  final int id;
  final String nombre;
  final String? categoria;
  final int? idGrupoAlimentario;
  final List<String> etiquetas;
  final double energiaKcal;
  final double proteinasG;
  final double carbohidratosG;
  final double grasasG;
  final double fibraG;
  final double sodioMg;
  final double calcioMg;
  final double hierroMg;
  final String? descripcion;
  final bool activo;
  final int usoEnRecetas;

  Ingrediente({
    required this.id,
    required this.nombre,
    this.categoria,
    this.idGrupoAlimentario,
    required this.etiquetas,
    this.energiaKcal = 0,
    this.proteinasG = 0,
    this.carbohidratosG = 0,
    this.grasasG = 0,
    this.fibraG = 0,
    this.sodioMg = 0,
    this.calcioMg = 0,
    this.hierroMg = 0,
    this.descripcion,
    this.activo = true,
    this.usoEnRecetas = 0,
  });

  factory Ingrediente.fromJson(Map<String, dynamic> json) {
    return Ingrediente(
      id: json['id'],
      nombre: json['nombre'],
      categoria: json['subgrupo_alimentario'] ?? json['categoria_nombre'],
      idGrupoAlimentario: json['grupo_alimentario_id'],
      etiquetas: (json['etiquetas'] as List?)?.map((e) => e.toString()).toList() ?? [],
      energiaKcal: (json['energia_kcal'] ?? 0).toDouble(),
      proteinasG: (json['proteinas_g'] ?? 0).toDouble(),
      carbohidratosG: (json['carbohidratos_g'] ?? 0).toDouble(),
      grasasG: (json['grasa_total_g'] ?? 0).toDouble(),
      fibraG: (json['fibra_vegetal_g'] ?? 0).toDouble(),
      sodioMg: (json['sodio_mg'] ?? 0).toDouble(),
      calcioMg: (json['calcio_mg'] ?? 0).toDouble(),
      hierroMg: (json['hierro_mg'] ?? 0).toDouble(),
      descripcion: json['descripcion'],
      activo: json['activo'] ?? true,
      usoEnRecetas: json['uso_en_recetas'] ?? 0,
    );
  }

  Ingrediente copyWith({String? nombre, bool? activo}) {
    return Ingrediente(
      id: id,
      nombre: nombre ?? this.nombre,
      categoria: categoria,
      idGrupoAlimentario: idGrupoAlimentario,
      etiquetas: List.from(etiquetas),
      energiaKcal: energiaKcal,
      proteinasG: proteinasG,
      carbohidratosG: carbohidratosG,
      grasasG: grasasG,
      fibraG: fibraG,
      sodioMg: sodioMg,
      calcioMg: calcioMg,
      hierroMg: hierroMg,
      descripcion: descripcion,
      activo: activo ?? this.activo,
      usoEnRecetas: usoEnRecetas,
    );
  }
}
