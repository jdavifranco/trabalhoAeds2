import 'package:tp01/cli.dart';

/// Trabalho Prático II - AEDS II
/// Manipulação e Reorganização de Arquivos de Dados
/// Sistema de gerenciamento de registros de alunos com operações CRUD
Future<void> main() async {
  final cli = AlunosCLI();
  await cli.start();
}
