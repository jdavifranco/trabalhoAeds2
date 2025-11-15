import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'modes.dart';
import 'aluno.dart';

class PopulateDatabase {
  void call({
    int maxSizeInBytes = 400,
    required StorageMode storageMode,
    required RegisterMode registerMode,
  }) async {
    final databaseFile = storageMode == StorageMode.fixed
        ? 'lib/input_database/fixed.dat'
        : 'lib/input_database/variable.dat';

    final outputFolder = storageMode == StorageMode.fixed
        ? 'lib/output_database/fixed'
        : 'lib/output_database/variable';

    // Ler alunos do arquivo
    final alunos = await _loadAlunosFromFile(databaseFile);

    final isScattered =
        storageMode == StorageMode.dynamic &&
        registerMode == RegisterMode.scattered;

    int blockIndex = 0;
    File blocFile = _getBlockFile(blockIndex, storageMode);

    // Criar diretório se não existir
    final directory = blocFile.parent;
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    for (int i = 0; i < alunos.length; i++) {
      final aluno = alunos[i];

      if (isScattered) {
        // Registros espalhados: pode dividir registro entre blocos
        final result = await _writeRecordScattered(
          blocFile,
          aluno,
          maxSizeInBytes,
          blockIndex,
          storageMode,
        );
        // Atualizar bloco atual para próximo registro
        blocFile = result;
        blockIndex = _extractBlockIndex(blocFile.path);
      } else {
        // Registros contínuos: só escreve se couber inteiro
        final recordSize = aluno.toBytes().length;
        final recordSizeWithSeparator = storageMode == StorageMode.dynamic
            ? recordSize +
                  1 // +1 para \n
            : recordSize;

        // Verificar tamanho atual do bloco
        int currentSize = 0;
        if (await blocFile.exists()) {
          currentSize = await blocFile.length();
        }
        // Se não cabe no bloco atual, criar novo bloco
        if (currentSize + recordSizeWithSeparator > maxSizeInBytes) {
          blockIndex++;
          blocFile = _getBlockFile(blockIndex, storageMode);
        }

        // Escrever registro completo
        await _writeRecord(blocFile, aluno, storageMode);
      }
    }

    // Calcular e exibir estatísticas
    await _displayStatistics(outputFolder, maxSizeInBytes);
  }

  Future<void> _displayStatistics(
    String outputFolder,
    int maxSizeInBytes,
  ) async {
    final folder = Directory(outputFolder);
    if (!await folder.exists()) {
      return;
    }

    final blocFiles = await folder
        .list()
        .where((entity) => entity.path.endsWith('.dat'))
        .cast<File>()
        .toList();

    int totalBlocks = blocFiles.length;
    int totalBytesUsed = 0;
    int totalBytesAvailable = totalBlocks * maxSizeInBytes;
    int partiallyUsedBlocks = 0;
    final blockStats = <Map<String, dynamic>>[];

    print('\n=== ESTATÍSTICAS DE ARMAZENAMENTO ===\n');

    for (final blocFile in blocFiles) {
      final size = await blocFile.length();
      final percentage = (size / maxSizeInBytes * 100);
      final isPartiallyUsed = size < maxSizeInBytes && size > 0;

      if (isPartiallyUsed) {
        partiallyUsedBlocks++;
      }

      totalBytesUsed += size;

      final blockIndex = _extractBlockIndex(blocFile.path);
      blockStats.add({
        'index': blockIndex,
        'size': size,
        'percentage': percentage,
      });

      print(
        'Bloco ${blockIndex + 1}: $size bytes (${percentage.toStringAsFixed(1)}% cheio)',
      );
    }

    final averageOccupancy = blockStats.isEmpty
        ? 0.0
        : blockStats
                  .map((s) => s['percentage'] as double)
                  .reduce((a, b) => a + b) /
              blockStats.length;

    final efficiency = totalBytesAvailable > 0
        ? (totalBytesUsed / totalBytesAvailable * 100)
        : 0.0;

    print('\n--- Resumo ---');
    print('Total de blocos: $totalBlocks');
    print(
      'Percentual médio de ocupação: ${averageOccupancy.toStringAsFixed(1)}%',
    );
    print('Blocos parcialmente utilizados: $partiallyUsedBlocks');
    print('Eficiência total: ${efficiency.toStringAsFixed(1)}%');
  }

  File _getBlockFile(int index, StorageMode storageMode) {
    final folder = storageMode == StorageMode.fixed ? 'fixed' : 'variable';
    return File('lib/output_database/$folder/bloc_$index.dat');
  }

  int _extractBlockIndex(String filePath) {
    // Extrai o índice do bloco do nome do arquivo
    final match = RegExp(r'bloc_(\d+)\.dat').firstMatch(filePath);
    return match != null ? int.parse(match.group(1)!) : 0;
  }

  Future<void> _writeRecord(
    File file,
    Aluno aluno,
    StorageMode storageMode,
  ) async {
    var recordBytes = aluno.toBytes();

    // Adicionar separador de registro para modo variável
    if (storageMode == StorageMode.dynamic) {
      // 10 = \n
      recordBytes = Uint8List.fromList([...recordBytes, 10]);
    }

    final raf = await file.open(mode: FileMode.append);
    await raf.writeFrom(recordBytes);
    await raf.close();
  }

  Future<File> _writeRecordScattered(
    File startFile,
    Aluno aluno,
    int maxSizeInBytes,
    int startBlockIndex,
    StorageMode storageMode,
  ) async {
    var recordBytes = aluno.toBytes();
    recordBytes = Uint8List.fromList([...recordBytes, 10]); // Adicionar \n

    int bytesWritten = 0;
    File currentFile = startFile;
    int currentBlockIndex = startBlockIndex;

    while (bytesWritten < recordBytes.length) {
      // Verificar espaço disponível no bloco atual
      int availableSpace = maxSizeInBytes;
      if (await currentFile.exists()) {
        final currentSize = await currentFile.length();
        availableSpace = maxSizeInBytes - currentSize;
      }

      if (availableSpace <= 0) {
        // Bloco cheio, ir para próximo
        currentBlockIndex++;
        currentFile = _getBlockFile(currentBlockIndex, storageMode);
        continue;
      }

      // Calcular quantos bytes podem ser escritos neste bloco
      final bytesToWrite = availableSpace < (recordBytes.length - bytesWritten)
          ? availableSpace
          : (recordBytes.length - bytesWritten);

      // Escrever parte do registro
      final partialBytes = recordBytes.sublist(
        bytesWritten,
        bytesWritten + bytesToWrite,
      );

      final raf = await currentFile.open(mode: FileMode.append);
      await raf.writeFrom(partialBytes);
      await raf.close();

      bytesWritten += bytesToWrite;

      // Se ainda há bytes para escrever, ir para próximo bloco
      if (bytesWritten < recordBytes.length) {
        currentBlockIndex++;
        currentFile = _getBlockFile(currentBlockIndex, storageMode);
      }
    }

    // Retornar o arquivo onde terminou de escrever
    return currentFile;
  }

  Future<List<Aluno>> _loadAlunosFromFile(String filePath) async {
    final file = File(filePath);

    if (!await file.exists()) {
      throw Exception(
        'Arquivo de base de dados não encontrado: $filePath\n'
        'Execute: dart run lib/create_databases.dart',
      );
    }

    final bytes = await file.readAsBytes();
    final alunos = <Aluno>[];

    // Determinar se é fixed ou variable pelo caminho do arquivo
    final isFixed = filePath.contains('fixed');

    if (isFixed) {
      // Modo fixed: ler registros sequencialmente
      int offset = 0;
      while (offset < bytes.length) {
        int jsonEnd = offset;
        int braceCount = 0;
        bool inString = false;

        for (int i = offset; i < bytes.length; i++) {
          if (bytes[i] == 34 && (i == 0 || bytes[i - 1] != 92)) {
            // Aspas não escapadas
            inString = !inString;
          } else if (!inString) {
            if (bytes[i] == 123) {
              // {
              braceCount++;
            } else if (bytes[i] == 125) {
              // }
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
    } else {
      // Modo variable: registros separados por \n
      int offset = 0;
      while (offset < bytes.length) {
        // Encontrar o próximo \n
        int newlineIndex = bytes.indexOf(10, offset);
        if (newlineIndex == -1) {
          // Último registro (sem \n final)
          newlineIndex = bytes.length;
        }

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
    }

    return alunos;
  }
}
