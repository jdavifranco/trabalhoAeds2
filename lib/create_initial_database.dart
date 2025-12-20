import 'package:faker/faker.dart';

import 'aluno.dart';
import 'datasources/aluno_datasource.dart';
import 'datasources/storage_strategy.dart';

Future<void> createInitialDatabase({
  required String outputFolder,
  required int maxSizeInBytes,
  required StorageStrategy strategy,
  int numberOfStudents = 10,
}) async {
  print('\n=== CRIANDO BANCO DE DADOS INICIAL ===\n');

  final datasource = AlunoDataSource(
    outputFolder: outputFolder,
    maxSizeInBytes: maxSizeInBytes,
    strategy: strategy,
  );

  final faker = Faker();
  final alunos = <Aluno>[];

  for (var i = 0; i < numberOfStudents; i++) {
    alunos.add(
      Aluno(
        matricula: 2024000 + i + 1,
        nome: faker.person.name(),
        cpf: _generateCPF(faker),
        curso: _getCurso(i % 5),
        nomeMae: faker.person.name(),
        nomePai: faker.person.name(),
        anoIngresso: 2020 + (i % 5),
        ca: faker.randomGenerator.decimal(scale: 10, min: 5),
      ),
    );
  }

  for (var i = 0; i < alunos.length; i++) {
    await datasource.insertRecord(alunos[i]);
    print('  ✓ ${i + 1}/$numberOfStudents: ${alunos[i].nome}');
  }

  print('');
  await datasource.printStatistics();
  print('✅ Banco criado: $outputFolder\n');
}

String _generateCPF(Faker faker) {
  return '${faker.randomGenerator.integer(99999, min: 10000)}'
      '${faker.randomGenerator.integer(999999, min: 100000)}';
}

String _getCurso(int index) {
  const cursos = [
    'Ciência da Computação',
    'Engenharia de Software',
    'Sistemas de Informação',
    'Engenharia da Computação',
    'Análise e Desenvolvimento de Sistemas',
  ];
  return cursos[index];
}

Future<void> main() async {
  const modoOpcao = '1';

  final strategy = modoOpcao == '2'
      ? VariableRecordStorageStrategy()
      : FixedRecordStorageStrategy();

  final outputFolder =
      'lib/output_database/${modoOpcao == '2' ? 'variable' : 'fixed'}';

  await createInitialDatabase(
    outputFolder: outputFolder,
    maxSizeInBytes: 400,
    strategy: strategy,
    numberOfStudents: 15,
  );
}
