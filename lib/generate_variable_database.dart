import 'dart:io';

import 'package:faker/faker.dart';

import 'aluno.dart';

/// Gera uma base de dados com registros de tamanhos variáveis
class GenerateVariableDatabase {
  List<Aluno> generate(int size) {
    final alunos = <Aluno>[];

    for (int i = 0; i < size; i++) {
      // 9 dígitos
      final matricula = 100000000 + faker.randomGenerator.integer(900000000);

      // 5 a 50 caracteres
      final nomeLength = 5 + faker.randomGenerator.integer(46);
      final nome = faker.person.name();
      final nomeFinal = nome.length > nomeLength
          ? nome.substring(0, nomeLength)
          : nome;

      // 11 caracteres
      final cpf = _generateCPF();

      // (5 a 30 caracteres)
      final cursoLength = 5 + faker.randomGenerator.integer(26);
      final curso = faker.lorem.word();
      final cursoFinal = curso.length > cursoLength
          ? curso.substring(0, cursoLength)
          : curso;

      // (5 a 30 caracteres)
      final maeLength = 5 + faker.randomGenerator.integer(26);
      final nomeMae = faker.person.name();
      final nomeMaeFinal = nomeMae.length > maeLength
          ? nomeMae.substring(0, maeLength)
          : nomeMae;

      // (5 a 30 caracteres)
      final paiLength = 5 + faker.randomGenerator.integer(26);
      final nomePai = faker.person.name();
      final nomePaiFinal = nomePai.length > paiLength
          ? nomePai.substring(0, paiLength)
          : nomePai;

      // 4 dígitos
      final anoIngresso = 2000 + faker.randomGenerator.integer(25);

      // 2 casas decimais
      final ca = (faker.randomGenerator.integer(1000) / 100).toStringAsFixed(2);

      alunos.add(
        Aluno(
          matricula: matricula,
          nome: nomeFinal,
          cpf: cpf,
          curso: cursoFinal,
          nomeMae: nomeMaeFinal,
          nomePai: nomePaiFinal,
          anoIngresso: anoIngresso,
          ca: double.parse(ca),
        ),
      );
    }

    return alunos;
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

    // Escrever cada registro sequencialmente com separador \n
    for (final aluno in alunos) {
      final recordBytes = aluno.toBytes();
      await raf.writeFrom(recordBytes);
      await raf.writeFrom([10]); // \n
    }

    await raf.close();
  }
}
