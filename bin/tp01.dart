import 'dart:io';

import 'package:tp01/modes.dart';
import 'package:tp01/populate_database.dart';

void main() {
  receiveUserInput();
}

void receiveUserInput() async {
  final populateDatabase = PopulateDatabase();

  print('Digite o tamanho máximo do bloco em bytes:');
  final maxSizeInBytes = int.parse(stdin.readLineSync()!);

  print(maxSizeInBytes);

  print('Escolha o modo de armazenamento:');
  print('1. Registros de tamanho fixo');
  print('2. Registros de tamanho variável');
  final storageModeChoice = stdin.readLineSync()!;

  StorageMode storageMode;
  RegisterMode registerMode = RegisterMode.continuos;

  if (storageModeChoice == '1') {
    storageMode = StorageMode.fixed;
  } else {
    storageMode = StorageMode.dynamic;

    print('Registros espalhados? (s/n):');
    final scatteringChoice = stdin.readLineSync()!;

    if (scatteringChoice == 's') {
      registerMode = RegisterMode.scattered;
    } else {
      registerMode = RegisterMode.continuos;
    }
  }

  print('\n=== Executando Sistema ===');

  populateDatabase(
    registerMode: registerMode,
    storageMode: storageMode,
    maxSizeInBytes: maxSizeInBytes,
  );
}
