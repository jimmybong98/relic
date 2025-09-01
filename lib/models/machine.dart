class Machine {
  final String codigo;
  final String categoria;

  Machine({required this.codigo, required this.categoria});

  factory Machine.fromJson(Map<String, dynamic> json) {
    return Machine(
      codigo: json['codigo'] as String,
      categoria: json['categoria'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'codigo': codigo,
      'categoria': categoria,
    };
  }
}
