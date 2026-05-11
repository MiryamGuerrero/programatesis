import 'package:flutter/material.dart';
import 'escala_selector.dart';

class EscalasDemoPage extends StatefulWidget {
  const EscalasDemoPage({super.key});

  @override
  State<EscalasDemoPage> createState() => _EscalasDemoPageState();
}

class _EscalasDemoPageState extends State<EscalasDemoPage> {
  int inflamacion = 3;
  int energia = 2;
  int dolor = 5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escalas Demo')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          EscalaSelector(
            titulo: 'SEVERA / ACTIVA',
            descripcion: 'Inflamación elevada',
            min: 0,
            max: 3,
            value: inflamacion,
            emojis: const ['😊', '😐', '😟', '😡'],
            etiquetas: [
              EscalaEtiqueta('Leve', 1),
              EscalaEtiqueta('Moderada', 2),
              EscalaEtiqueta('Severa / Activa', 1),
            ],
            colorActivo: Colors.deepOrange,
            colorFondoActivo: Colors.deepOrange.shade100,
            onChanged: (v) => setState(() => inflamacion = v),
            puntajeLabel: '$inflamacion/3',
            icon: const Text('🔥', style: TextStyle(fontSize: 32)),
          ),
          EscalaSelector(
            titulo: 'AGOTAMIENTO',
            descripcion: 'Energía muy baja',
            min: 0,
            max: 10,
            value: energia,
            emojis: const ['🤩', '😊', '😐', '😕', '😟', '😞', '😫', '😩', '🥴', '😵', '💀'],
            etiquetas: [
              EscalaEtiqueta('Alta energía', 3),
              EscalaEtiqueta('Intermedio', 5),
              EscalaEtiqueta('Agotamiento', 3),
            ],
            colorActivo: Colors.orange,
            colorFondoActivo: Colors.orange.shade100,
            onChanged: (v) => setState(() => energia = v),
            puntajeLabel: '$energia/10',
            icon: const Text('🔋', style: TextStyle(fontSize: 32)),
          ),
          EscalaSelector(
            titulo: 'MODERADO',
            descripcion: 'Nivel de dolor intermedio',
            min: 0,
            max: 10,
            value: dolor,
            emojis: const ['😊', '😊', '😐', '😕', '😟', '😐', '😕', '😟', '😢', '😭', '😫'],
            etiquetas: [
              EscalaEtiqueta('Leve', 3),
              EscalaEtiqueta('Moderado', 4),
              EscalaEtiqueta('Severo', 4),
            ],
            colorActivo: Colors.amber.shade800,
            colorFondoActivo: Colors.amber.shade100,
            onChanged: (v) => setState(() => dolor = v),
            puntajeLabel: '$dolor/10',
            icon: const Text('😊', style: TextStyle(fontSize: 32)),
          ),
        ],
      ),
    );
  }
}
