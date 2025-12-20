import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../aluno.dart';

abstract class StorageStrategy {
  Future<List<Aluno>> loadAlunosFromBlock(File file);
  Future<void> writeRecord(File file, Aluno aluno);
  Future<void> rewriteBlock(File file, List<Aluno> alunos);
  int calculateRecordSize(Aluno aluno);
}

class FixedRecordStorageStrategy implements StorageStrategy {
  @override
  Future<List<Aluno>> loadAlunosFromBlock(File file) async {
    final bytes = await file.readAsBytes();
    final alunos = <Aluno>[];

    int offset = 0;
    while (offset < bytes.length) {
      int jsonEnd = offset;
      int braceCount = 0;
      bool inString = false;

      for (int i = offset; i < bytes.length; i++) {
        if (bytes[i] == 34 && (i == 0 || bytes[i - 1] != 92)) {
          inString = !inString;
        } else if (!inString) {
          if (bytes[i] == 123) {
            braceCount++;
          } else if (bytes[i] == 125) {
            braceCount--;
            if (braceCount == 0) {
              jsonEnd = i + 1;
              break;
            }
          }
        }
      }

      if (jsonEnd > offset) {
        final jsonBytes = bytes.sublist(offset, jsonEnd);
        final jsonString = utf8.decode(jsonBytes);
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        alunos.add(Aluno.fromJson(json));
        offset = jsonEnd;
      } else {
        break;
      }
    }

    return alunos;
  }

  @override
  Future<void> writeRecord(File file, Aluno aluno) async {
    final recordBytes = aluno.toBytes();
    final raf = await file.open(mode: FileMode.append);
    await raf.writeFrom(recordBytes);
    await raf.close();
  }

  @override
  Future<void> rewriteBlock(File file, List<Aluno> alunos) async {
    final raf = await file.open(mode: FileMode.write);
    for (final aluno in alunos) {
      final recordBytes = aluno.toBytes();
      await raf.writeFrom(recordBytes);
    }
    await raf.close();
  }

  @override
  int calculateRecordSize(Aluno aluno) {
    return aluno.toBytes().length;
  }
}

class VariableRecordStorageStrategy implements StorageStrategy {
  @override
  Future<List<Aluno>> loadAlunosFromBlock(File file) async {
    final bytes = await file.readAsBytes();
    final alunos = <Aluno>[];

    int offset = 0;
    while (offset < bytes.length) {
      int newlineIndex = bytes.indexOf(10, offset);
      if (newlineIndex == -1) newlineIndex = bytes.length;

      if (newlineIndex > offset) {
        final jsonBytes = bytes.sublist(offset, newlineIndex);
        final jsonString = utf8.decode(jsonBytes);
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        alunos.add(Aluno.fromJson(json));
        offset = newlineIndex + 1;
      } else {
        break;
      }
    }

    return alunos;
  }

  @override
  Future<void> writeRecord(File file, Aluno aluno) async {
    final recordBytes = aluno.toBytes();
    final recordWithSeparator = Uint8List.fromList([...recordBytes, 10]);
    final raf = await file.open(mode: FileMode.append);
    await raf.writeFrom(recordWithSeparator);
    await raf.close();
  }

  @override
  Future<void> rewriteBlock(File file, List<Aluno> alunos) async {
    final raf = await file.open(mode: FileMode.write);
    for (final aluno in alunos) {
      final recordBytes = aluno.toBytes();
      final recordWithSeparator = Uint8List.fromList([...recordBytes, 10]);
      await raf.writeFrom(recordWithSeparator);
    }
    await raf.close();
  }

  @override
  int calculateRecordSize(Aluno aluno) {
    return aluno.toBytes().length + 1;
  }
}
