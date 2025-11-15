import 'dart:convert';
import 'dart:typed_data';

class Aluno {
  final int matricula; // 9 dígitos
  final String? nome; // até 50 caracteres
  final String? cpf; // 11 caracteres
  final String? curso; // até 30 caracteres
  final String? nomeMae; // até 30 caracteres
  final String? nomePai; // até 30 caracteres
  final int? anoIngresso; // 4 dígitos
  final double? ca; // 2 casas decimais

  Aluno({
    required this.matricula,
    this.nome,
    this.cpf,
    this.curso,
    this.nomeMae,
    this.nomePai,
    this.anoIngresso,
    this.ca,
  });

  Map<String, dynamic> toJson() => {
    'matricula': matricula,
    'nome': nome,
    'cpf': cpf,
    'curso': curso,
    'nomeMae': nomeMae,
    'nomePai': nomePai,
    'anoIngresso': anoIngresso,
    'ca': ca,
  };

  factory Aluno.fromJson(Map<String, dynamic> json) {
    return Aluno(
      matricula: json['matricula'] as int,
      nome: json['nome'] as String?,
      cpf: json['cpf'] as String?,
      curso: json['curso'] as String?,
      nomeMae: json['nomeMae'] as String?,
      nomePai: json['nomePai'] as String?,
      anoIngresso: json['anoIngresso'] as int?,
      ca: (json['ca'] as num?)?.toDouble(),
    );
  }

  Uint8List toBytes() {
    return utf8.encode(jsonEncode(toJson()));
  }
}
