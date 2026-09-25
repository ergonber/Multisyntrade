class ActivoModel {
  final String id;
  final String nombre;
  final String derivSymbol;
  final String tipo;
  final List<double> multiplicadores;
  final bool habilitado;

  const ActivoModel({
    required this.id,
    required this.nombre,
    required this.derivSymbol,
    required this.tipo,
    required this.multiplicadores,
    this.habilitado = true,
  });

  bool get isBoom =>
      tipo == 'boom' ||
      derivSymbol.toUpperCase().startsWith('BOOM') ||
      nombre.toLowerCase().startsWith('boom');
  bool get isCrash =>
      tipo == 'crash' ||
      derivSymbol.toUpperCase().startsWith('CRASH') ||
      nombre.toLowerCase().startsWith('crash');
  bool get isVolatility => tipo == 'volatility';
  bool get isStep => tipo == 'step';
  bool get isJump => tipo == 'jump';
  bool get isRangeBreak => tipo == 'range_break';

  factory ActivoModel.fromMap(Map<String, dynamic> map) {
    return ActivoModel(
      id: map['id'] ?? '',
      nombre: map['nombre'] ?? '',
      derivSymbol: map['deriv_symbol'] ?? '',
      tipo: map['tipo'] ?? '',
      multiplicadores: (map['multiplicadores'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [1, 2, 5, 10, 20, 50, 100, 200, 400, 600, 800, 1000],
      habilitado: map['habilitado'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'nombre': nombre,
    'deriv_symbol': derivSymbol,
    'tipo': tipo,
    'multiplicadores': multiplicadores,
    'habilitado': habilitado,
  };
}
