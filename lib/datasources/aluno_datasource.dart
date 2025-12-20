import 'dart:convert';
import 'dart:io';

import '../aluno.dart';
import '../models/block_metadata.dart';
import 'storage_strategy.dart';

class AlunoDataSource {
  final String outputFolder;
  final int maxSizeInBytes;
  final StorageStrategy strategy;
  final Map<int, BlockMetadata> _blockMetadata = {};

  AlunoDataSource({
    required this.outputFolder,
    required this.maxSizeInBytes,
    required this.strategy,
  });

  Future<void> loadMetadata() async {
    final folder = Directory(outputFolder);
    if (!await folder.exists()) return;

    final metadataLoaded = await _loadMetadataFromFile();
    if (metadataLoaded) return;

    final blocFiles = await folder
        .list()
        .where((entity) => entity.path.endsWith('.dat'))
        .cast<File>()
        .toList();

    for (final file in blocFiles) {
      await _updateBlockMetadata(_extractBlockIndex(file.path));
    }

    await _saveMetadataToFile();
  }

  Future<void> _saveMetadataToFile() async {
    final metadataFile = File('$outputFolder/metadata.json');
    final metadataJson = {
      'blocks': _blockMetadata.values.map((m) => m.toJson()).toList(),
      'lastUpdate': DateTime.now().toIso8601String(),
    };
    await metadataFile.writeAsString(jsonEncode(metadataJson));
  }

  Future<bool> _loadMetadataFromFile() async {
    try {
      final metadataFile = File('$outputFolder/metadata.json');
      if (!await metadataFile.exists()) return false;

      final metadataJson = jsonDecode(await metadataFile.readAsString());
      final blocks = metadataJson['blocks'] as List<dynamic>;

      _blockMetadata.clear();
      for (final blockJson in blocks) {
        final metadata =
            BlockMetadata.fromJson(blockJson as Map<String, dynamic>);
        _blockMetadata[metadata.blockIndex] = metadata;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _updateBlockMetadata(int blockIndex) async {
    final file = _getBlockFile(blockIndex);
    if (!await file.exists()) return;

    final alunos = await strategy.loadAlunosFromBlock(file);

    int usedBytes = 0;
    final deletedRecords = <DeletedRecordInfo>[];

    int offset = 0;
    for (final aluno in alunos) {
      final recordSize = strategy.calculateRecordSize(aluno);

      if (aluno.matricula < 0) {
        deletedRecords.add(DeletedRecordInfo(offset: offset, size: recordSize));
      }

      usedBytes += recordSize;
      offset += recordSize;
    }

    final freeBytes = maxSizeInBytes - usedBytes;

    _blockMetadata[blockIndex] = BlockMetadata(
      blockIndex: blockIndex,
      usedBytes: usedBytes,
      freeBytes: freeBytes,
      deletedRecords: deletedRecords,
    );
  }

  Future<int> insertRecord(Aluno aluno) async {
    final recordSize = strategy.calculateRecordSize(aluno);

    final blockWithDeletedSpace = _findBlockWithDeletedSpace(recordSize);
    if (blockWithDeletedSpace != null) {
      await _insertInDeletedSpace(blockWithDeletedSpace, aluno);
      return blockWithDeletedSpace;
    }

    final blockWithSpace = _findBlockWithSpace(recordSize);
    if (blockWithSpace != null) {
      await _appendToBlock(blockWithSpace, aluno);
      return blockWithSpace;
    }

    final lastBlockIndex = await _findLastBlockIndex();
    final lastBlockFile = _getBlockFile(lastBlockIndex);

    if (await lastBlockFile.exists()) {
      final metadata = _blockMetadata[lastBlockIndex];
      if (metadata != null && metadata.availableSpace >= recordSize) {
        await _appendToBlock(lastBlockIndex, aluno);
        return lastBlockIndex;
      }
    }

    final newBlockIndex = lastBlockIndex + 1;
    await _appendToBlock(newBlockIndex, aluno);
    return newBlockIndex;
  }

  int? _findBlockWithDeletedSpace(int recordSize) {
    for (final metadata in _blockMetadata.values) {
      if (metadata.hasDeletedRecords) {
        for (final deleted in metadata.deletedRecords) {
          if (deleted.size >= recordSize) {
            return metadata.blockIndex;
          }
        }
      }
    }
    return null;
  }

  int? _findBlockWithSpace(int recordSize) {
    for (final metadata in _blockMetadata.values) {
      if (metadata.hasSpace && metadata.availableSpace >= recordSize) {
        return metadata.blockIndex;
      }
    }
    return null;
  }

  Future<void> _insertInDeletedSpace(int blockIndex, Aluno aluno) async {
    final file = _getBlockFile(blockIndex);
    final alunos = await strategy.loadAlunosFromBlock(file);

    for (int i = 0; i < alunos.length; i++) {
      if (alunos[i].matricula < 0) {
        alunos[i] = aluno;
        break;
      }
    }

    await strategy.rewriteBlock(file, alunos);
    await _updateBlockMetadata(blockIndex);
    await _saveMetadataToFile();
  }

  Future<void> _appendToBlock(int blockIndex, Aluno aluno) async {
    final file = _getBlockFile(blockIndex);
    await strategy.writeRecord(file, aluno);
    await _updateBlockMetadata(blockIndex);
    await _saveMetadataToFile();
  }

  Future<bool> deleteRecord(int matricula) async {
    final result = await _findRecordLocation(matricula);
    if (result == null) return false;

    final blockIndex = result['blockIndex'] as int;
    final aluno = result['aluno'] as Aluno;

    final alunoExcluido = Aluno(
      matricula: -aluno.matricula,
      nome: aluno.nome,
      cpf: aluno.cpf,
      curso: aluno.curso,
      nomeMae: aluno.nomeMae,
      nomePai: aluno.nomePai,
      anoIngresso: aluno.anoIngresso,
      ca: aluno.ca,
    );

    await _replaceRecordInBlock(blockIndex, matricula, alunoExcluido);
    await _updateBlockMetadata(blockIndex);
    await _saveMetadataToFile();

    return true;
  }

  Future<Map<String, dynamic>?> _findRecordLocation(int matricula) async {
    final folder = Directory(outputFolder);
    if (!await folder.exists()) return null;

    final blocFiles = await folder
        .list()
        .where((entity) => entity.path.endsWith('.dat'))
        .cast<File>()
        .toList();

    for (final file in blocFiles) {
      final alunos = await strategy.loadAlunosFromBlock(file);
      for (final aluno in alunos) {
        if (aluno.matricula.abs() == matricula && aluno.matricula > 0) {
          return {'blockIndex': _extractBlockIndex(file.path), 'aluno': aluno};
        }
      }
    }

    return null;
  }

  Future<bool> updateRecord(int matricula, Aluno novoAluno) async {
    final result = await _findRecordLocation(matricula);
    if (result == null) return false;

    final blockIndex = result['blockIndex'] as int;
    final alunoAntigo = result['aluno'] as Aluno;

    final oldSize = strategy.calculateRecordSize(alunoAntigo);
    final newSize = strategy.calculateRecordSize(novoAluno);

    if (newSize <= oldSize) {
      await _replaceRecordInBlock(blockIndex, matricula, novoAluno);
      await _updateBlockMetadata(blockIndex);
      await _saveMetadataToFile();
      return true;
    }

    await deleteRecord(matricula);
    await insertRecord(novoAluno);
    return true;
  }

  Future<void> _replaceRecordInBlock(
    int blockIndex,
    int matricula,
    Aluno novoAluno,
  ) async {
    final file = _getBlockFile(blockIndex);
    final alunos = await strategy.loadAlunosFromBlock(file);

    for (int i = 0; i < alunos.length; i++) {
      if (alunos[i].matricula.abs() == matricula) {
        alunos[i] = novoAluno;
        break;
      }
    }

    await strategy.rewriteBlock(file, alunos);
  }

  Future<Aluno?> findByMatricula(int matricula) async {
    final result = await _findRecordLocation(matricula);
    return result?['aluno'] as Aluno?;
  }

  Future<List<Aluno>> listActiveRecords() async {
    final folder = Directory(outputFolder);
    if (!await folder.exists()) return [];

    final blocFiles = await folder
        .list()
        .where((entity) => entity.path.endsWith('.dat'))
        .cast<File>()
        .toList();

    final alunos = <Aluno>[];

    for (final file in blocFiles) {
      final alunosDoBloco = await strategy.loadAlunosFromBlock(file);
      alunos.addAll(alunosDoBloco.where((aluno) => aluno.matricula > 0));
    }

    return alunos;
  }

  Future<int> _findLastBlockIndex() async {
    final folder = Directory(outputFolder);

    if (!await folder.exists()) {
      await folder.create(recursive: true);
      return 0;
    }

    final blocFiles = await folder
        .list()
        .where((entity) => entity.path.endsWith('.dat'))
        .cast<File>()
        .toList();

    if (blocFiles.isEmpty) return 0;

    int maxIndex = 0;
    for (final file in blocFiles) {
      final index = _extractBlockIndex(file.path);
      if (index > maxIndex) maxIndex = index;
    }

    return maxIndex;
  }

  File _getBlockFile(int index) {
    return File('$outputFolder/bloc_$index.dat');
  }

  int _extractBlockIndex(String filePath) {
    final match = RegExp(r'bloc_(\d+)\.dat').firstMatch(filePath);
    return match != null ? int.parse(match.group(1)!) : 0;
  }

  Future<Map<String, dynamic>> getStatistics() async {
    await loadMetadata();

    if (_blockMetadata.isEmpty) {
      return {
        'totalBlocks': 0,
        'totalBytes': 0,
        'totalFreeBytes': 0,
        'averageOccupancy': 0.0,
        'efficiency': 0.0,
        'activeRecords': 0,
        'deletedRecords': 0,
      };
    }

    int totalBytes = 0;
    int totalFreeBytes = 0;
    double totalOccupancy = 0;
    int totalDeleted = 0;

    for (final metadata in _blockMetadata.values) {
      totalBytes += metadata.usedBytes;
      totalFreeBytes += metadata.freeBytes;
      totalOccupancy += (metadata.usedBytes / maxSizeInBytes) * 100;
      totalDeleted += metadata.deletedRecords.length;
    }

    final totalBlocks = _blockMetadata.length;
    final averageOccupancy = totalOccupancy / totalBlocks;
    final totalAvailableSpace = totalBlocks * maxSizeInBytes;
    final efficiency = (totalBytes / totalAvailableSpace) * 100;
    final activeRecords = (await listActiveRecords()).length;

    return {
      'totalBlocks': totalBlocks,
      'totalBytes': totalBytes,
      'totalFreeBytes': totalFreeBytes,
      'averageOccupancy': averageOccupancy,
      'efficiency': efficiency,
      'activeRecords': activeRecords,
      'deletedRecords': totalDeleted,
    };
  }

  Future<void> printStatistics() async {
    final stats = await getStatistics();

    print('\n=== ESTATÍSTICAS ===');
    print('Blocos: ${stats['totalBlocks']}');
    print('Bytes usados: ${stats['totalBytes']}');
    print('Bytes livres: ${stats['totalFreeBytes']}');
    print('Ativos: ${stats['activeRecords']}');
    print('Excluídos: ${stats['deletedRecords']}');
    print('Ocupação: ${stats['averageOccupancy'].toStringAsFixed(1)}%');
    print('Eficiência: ${stats['efficiency'].toStringAsFixed(1)}%');
    print('====================\n');
  }

  Future<void> printBlockMap() async {
    await loadMetadata();

    print('\n=== MAPA DE BLOCOS ===');
    for (final metadata in _blockMetadata.values) {
      final occupancy =
          (metadata.usedBytes / maxSizeInBytes * 100).toStringAsFixed(1);
      print(
        'Bloco ${metadata.blockIndex}: ${metadata.usedBytes}/$maxSizeInBytes ($occupancy%) - ${metadata.deletedRecords.length} excl',
      );
    }
    print('======================\n');
  }

  Future<Map<String, dynamic>> reorganize() async {
    print('\n=== REORGANIZANDO ===\n');

    final statsBefore = await getStatistics();
    print('ANTES:');
    print(
      '  Blocos: ${statsBefore['totalBlocks']} | Eficiência: ${statsBefore['efficiency'].toStringAsFixed(1)}%\n',
    );

    final activeRecords = await listActiveRecords();

    final reorganizedFolder = '${outputFolder}_reorg';
    final reorganizedDir = Directory(reorganizedFolder);
    if (await reorganizedDir.exists()) {
      await reorganizedDir.delete(recursive: true);
    }
    await reorganizedDir.create(recursive: true);

    int blockIndex = 0;
    File currentBlock = File('$reorganizedFolder/bloc_$blockIndex.dat');
    int currentBlockSize = 0;

    for (final aluno in activeRecords) {
      final recordSize = strategy.calculateRecordSize(aluno);

      if (currentBlockSize + recordSize > maxSizeInBytes) {
        blockIndex++;
        currentBlock = File('$reorganizedFolder/bloc_$blockIndex.dat');
        currentBlockSize = 0;
      }

      await strategy.writeRecord(currentBlock, aluno);
      currentBlockSize += recordSize;
    }

    final reorganizedDataSource = AlunoDataSource(
      outputFolder: reorganizedFolder,
      maxSizeInBytes: maxSizeInBytes,
      strategy: strategy,
    );
    await reorganizedDataSource.loadMetadata();
    final statsAfter = await reorganizedDataSource.getStatistics();

    final blocksFreed =
        (statsBefore['totalBlocks'] as int) -
        (statsAfter['totalBlocks'] as int);
    final efficiencyGain =
        (statsAfter['efficiency'] as double) -
        (statsBefore['efficiency'] as double);

    print('DEPOIS:');
    print(
      '  Blocos: ${statsAfter['totalBlocks']} | Eficiência: ${statsAfter['efficiency'].toStringAsFixed(1)}%\n',
    );
    print('GANHOS:');
    print(
      '  Eficiência: ${efficiencyGain >= 0 ? '+' : ''}${efficiencyGain.toStringAsFixed(1)}% | Blocos liberados: $blocksFreed\n',
    );

    return {
      'before': statsBefore,
      'after': statsAfter,
      'blocksFreed': blocksFreed,
      'efficiencyGain': efficiencyGain,
      'reorganizedFolder': reorganizedFolder,
    };
  }

  Future<void> applyReorganization(String reorganizedFolder) async {
    final oldDir = Directory(outputFolder);
    if (await oldDir.exists()) {
      await oldDir.delete(recursive: true);
    }

    await oldDir.create(recursive: true);

    final newDir = Directory(reorganizedFolder);
    final files = await newDir
        .list()
        .where((entity) => entity.path.endsWith('.dat'))
        .cast<File>()
        .toList();

    for (final file in files) {
      final fileName = file.path.split(Platform.pathSeparator).last;
      await file.copy('$outputFolder/$fileName');
    }

    await newDir.delete(recursive: true);

    _blockMetadata.clear();
    await loadMetadata();
  }
}

