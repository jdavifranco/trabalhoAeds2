import 'dart:io';

import 'package:faker/faker.dart';

import 'aluno.dart';

class GenerateFixedDatabase {
  List<Aluno> generate(int size) {
    final alunos = <Aluno>[];

    for (int i = 0; i < size; i++) {
      // 9 dígitos
      final matricula = faker.randomGenerator.integer(900000000);

      // 50 caracteres
      final nome = _padString(faker.person.name(), 50);

      // 11 caracteres
      final cpf = _generateCPF();

      // 30 caracteres
      final curso = _padString(faker.lorem.word(), 30);

      // 30 caracteres
      final nomeMae = _padString(faker.person.name(), 30);

      // 30 caracteres
      final nomePai = _padString(faker.person.name(), 30);

      // 4 dígitos
      final anoIngresso = 2000 + faker.randomGenerator.integer(25);

      // 2 casas decimais
      final ca = (faker.randomGenerator.integer(1000) / 100).toStringAsFixed(2);

      alunos.add(
        Aluno(
          matricula: matricula,
          nome: nome,
          cpf: cpf,
          curso: curso,
          nomeMae: nomeMae,
          nomePai: nomePai,
          anoIngresso: anoIngresso,
          ca: double.parse(ca),
        ),
      );
    }

    return alunos;
  }

  String _padString(String text, int length) {
    if (text.length > length) {
      return text.substring(0, length);
    }
    return text.padRight(length, ' ');
  }

  String _generateCPF() {
    final cpf = StringBuffer();
    for (int i = 0; i < 11; i++) {
      cpf.write(faker.randomGenerator.integer(10));
    }
    return cpf.toString();
  }

  Future<void> saveToFile(String filePath, List<Aluno> alunos) async {
    final file = File(filePath);
    final raf = await file.open(mode: FileMode.write);

    // Escrever cada registro sequencialmente
    for (final aluno in alunos) {
      final recordBytes = aluno.toBytes();
      await raf.writeFrom(recordBytes);
    }

    await raf.close();
  }
}
