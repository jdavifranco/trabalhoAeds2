import 'dart:io';

import 'aluno.dart';
import 'datasources/aluno_datasource.dart';
import 'datasources/storage_strategy.dart';

class AlunosCLI {
  late AlunoDataSource _datasource;

  Future<void> start() async {
    print('\n=== SISTEMA DE GERENCIAMENTO DE ALUNOS ===\n');
    await _configurarSistema();
    await _menuPrincipal();
  }

  Future<void> _configurarSistema() async {
    print('1. Registros FIXO\n2. Registros VARIÁVEL');
    stdout.write('Modo: ');
    final modoOpcao = stdin.readLineSync() ?? '1';

    stdout.flush();

    final strategy = modoOpcao == '2'
        ? VariableRecordStorageStrategy()
        : FixedRecordStorageStrategy();

    stdout.write('Tamanho do bloco (padrão 400): ');
    final tamanhoBlocoStr = stdin.readLineSync();
    final tamanhoBloco = int.tryParse(tamanhoBlocoStr ?? '') ?? 400;

    final outputFolder =
        'lib/output_database/${modoOpcao == '2' ? 'variable' : 'fixed'}';

    _datasource = AlunoDataSource(
      outputFolder: outputFolder,
      maxSizeInBytes: tamanhoBloco,
      strategy: strategy,
    );

    await _datasource.loadMetadata();
    print('\n✅ Sistema pronto!\n');
  }

  Future<void> _menuPrincipal() async {
    while (true) {
      print('\n=== MENU ===');
      print('1. Inserir\n2. Buscar\n3. Editar\n4. Excluir');
      print('5. Listar\n6. Reorganizar\n7. Estatísticas\n8. Mapa\n9. Sair');
      stdout.write('Opção: ');

      final opcao = stdin.readLineSync();

      switch (opcao) {
        case '1':
          await _inserirAluno();
          break;
        case '2':
          await _buscarAluno();
          break;
        case '3':
          await _editarAluno();
          break;
        case '4':
          await _excluirAluno();
          break;
        case '5':
          await _listarAlunos();
          break;
        case '6':
          await _reorganizarArquivo();
          break;
        case '7':
          await _exibirEstatisticas();
          break;
        case '8':
          await _exibirMapaBlocos();
          break;
        case '9':
          print('\nEncerrando...\n');
          exit(0);
        default:
          print('\nOpção inválida!\n');
      }
    }
  }

  Future<void> _inserirAluno() async {
    print('\n=== INSERIR ===\n');

    try {
      stdout.write('Matrícula: ');
      final matricula = int.parse(stdin.readLineSync() ?? '0');

      final existente = await _datasource.findByMatricula(matricula);
      if (existente != null) {
        print('\n❌ Matrícula já existe!\n');
        return;
      }

      stdout.write('Nome: ');
      final nome = stdin.readLineSync() ?? '';
      stdout.write('CPF: ');
      final cpf = stdin.readLineSync() ?? '';
      stdout.write('Curso: ');
      final curso = stdin.readLineSync() ?? '';
      stdout.write('Nome da mãe: ');
      final nomeMae = stdin.readLineSync() ?? '';
      stdout.write('Nome do pai: ');
      final nomePai = stdin.readLineSync() ?? '';
      stdout.write('Ano de ingresso: ');
      final anoIngresso = int.parse(stdin.readLineSync() ?? '2024');
      stdout.write('CA: ');
      final ca = double.parse(stdin.readLineSync() ?? '0.0');

      final aluno = Aluno(
        matricula: matricula,
        nome: nome,
        cpf: cpf,
        curso: curso,
        nomeMae: nomeMae,
        nomePai: nomePai,
        anoIngresso: anoIngresso,
        ca: ca,
      );

      final blockIndex = await _datasource.insertRecord(aluno);
      print('\n✅ Inserido no bloco $blockIndex\n');
    } catch (e) {
      print('\n❌ Erro: $e\n');
    }
  }

  Future<void> _buscarAluno() async {
    print('\n=== BUSCAR ===\n');

    try {
      stdout.write('Matrícula: ');
      final matricula = int.parse(stdin.readLineSync() ?? '0');

      final aluno = await _datasource.findByMatricula(matricula);

      if (aluno == null) {
        print('\n❌ Não encontrado\n');
        return;
      }

      print('\n✅ Encontrado:\n');
      _exibirDadosAluno(aluno);
    } catch (e) {
      print('\n❌ Erro: $e\n');
    }
  }

  Future<void> _editarAluno() async {
    print('\n=== EDITAR ===\n');

    try {
      stdout.write('Matrícula: ');
      final matricula = int.parse(stdin.readLineSync() ?? '0');

      final alunoAtual = await _datasource.findByMatricula(matricula);

      if (alunoAtual == null) {
        print('\n❌ Não encontrado\n');
        return;
      }

      print('\nDados atuais:');
      _exibirDadosAluno(alunoAtual);

      print('\nNovos dados (vazio = manter):\n');

      stdout.write('Nome [${alunoAtual.nome}]: ');
      final nome = stdin.readLineSync();
      final novoNome = nome?.isNotEmpty == true ? nome! : alunoAtual.nome;

      stdout.write('CPF [${alunoAtual.cpf}]: ');
      final cpf = stdin.readLineSync();
      final novoCpf = cpf?.isNotEmpty == true ? cpf! : alunoAtual.cpf;

      stdout.write('Curso [${alunoAtual.curso}]: ');
      final curso = stdin.readLineSync();
      final novoCurso = curso?.isNotEmpty == true ? curso! : alunoAtual.curso;

      stdout.write('Nome da mãe [${alunoAtual.nomeMae}]: ');
      final nomeMae = stdin.readLineSync();
      final novoNomeMae = nomeMae?.isNotEmpty == true
          ? nomeMae!
          : alunoAtual.nomeMae;

      stdout.write('Nome do pai [${alunoAtual.nomePai}]: ');
      final nomePai = stdin.readLineSync();
      final novoNomePai = nomePai?.isNotEmpty == true
          ? nomePai!
          : alunoAtual.nomePai;

      stdout.write('Ano [${alunoAtual.anoIngresso}]: ');
      final anoStr = stdin.readLineSync();
      final novoAno = anoStr?.isNotEmpty == true
          ? int.parse(anoStr!)
          : alunoAtual.anoIngresso;

      stdout.write('CA [${alunoAtual.ca}]: ');
      final caStr = stdin.readLineSync();
      final novoCa = caStr?.isNotEmpty == true
          ? double.parse(caStr!)
          : alunoAtual.ca;

      final alunoAtualizado = Aluno(
        matricula: matricula,
        nome: novoNome,
        cpf: novoCpf,
        curso: novoCurso,
        nomeMae: novoNomeMae,
        nomePai: novoNomePai,
        anoIngresso: novoAno,
        ca: novoCa,
      );

      final sucesso = await _datasource.updateRecord(
        matricula,
        alunoAtualizado,
      );

      print(sucesso ? '\n✅ Atualizado\n' : '\n❌ Erro\n');
    } catch (e) {
      print('\n❌ Erro: $e\n');
    }
  }

  Future<void> _excluirAluno() async {
    print('\n=== EXCLUIR ===\n');

    try {
      stdout.write('Matrícula: ');
      final matricula = int.parse(stdin.readLineSync() ?? '0');

      final aluno = await _datasource.findByMatricula(matricula);

      if (aluno == null) {
        print('\n❌ Não encontrado\n');
        return;
      }

      _exibirDadosAluno(aluno);

      stdout.write('\nConfirmar? (S/N): ');
      final confirmacao = stdin.readLineSync()?.toUpperCase();

      if (confirmacao != 'S') {
        print('\nCancelado\n');
        return;
      }

      final sucesso = await _datasource.deleteRecord(matricula);
      print(sucesso ? '\n✅ Excluído\n' : '\n❌ Erro\n');
    } catch (e) {
      print('\n❌ Erro: $e\n');
    }
  }

  Future<void> _listarAlunos() async {
    print('\n=== ALUNOS ATIVOS ===\n');

    try {
      final alunos = await _datasource.listActiveRecords();

      if (alunos.isEmpty) {
        print('Nenhum aluno cadastrado\n');
        return;
      }

      print('Total: ${alunos.length}\n');

      for (var i = 0; i < alunos.length; i++) {
        final aluno = alunos[i];
        print('${i + 1}. ${aluno.matricula} - ${aluno.nome}');
        print('   ${aluno.curso} | CA: ${aluno.ca!.toStringAsFixed(2)}');
      }

      print('');
    } catch (e) {
      print('\n❌ Erro: $e\n');
    }
  }

  Future<void> _reorganizarArquivo() async {
    print('\n=== REORGANIZAR ===\n');

    try {
      stdout.write('Confirmar? (S/N): ');
      final confirmacao = stdin.readLineSync()?.toUpperCase();

      if (confirmacao != 'S') {
        print('\nCancelado\n');
        return;
      }

      final resultado = await _datasource.reorganize();

      stdout.write('\nAplicar? (S/N): ');
      final aplicar = stdin.readLineSync()?.toUpperCase();

      if (aplicar == 'S') {
        await _datasource.applyReorganization(
          resultado['reorganizedFolder'] as String,
        );
        print('\n✅ Aplicado\n');
      } else {
        print('\nNão aplicado\n');
      }
    } catch (e) {
      print('\n❌ Erro: $e\n');
    }
  }

  Future<void> _exibirEstatisticas() async {
    print('');
    await _datasource.printStatistics();
  }

  Future<void> _exibirMapaBlocos() async {
    print('');
    await _datasource.printBlockMap();
  }

  void _exibirDadosAluno(Aluno aluno) {
    print('Matrícula: ${aluno.matricula}');
    print('Nome: ${aluno.nome}');
    print('CPF: ${aluno.cpf}');
    print('Curso: ${aluno.curso}');
    print('Mãe: ${aluno.nomeMae}');
    print('Pai: ${aluno.nomePai}');
    print('Ano: ${aluno.anoIngresso}');
    print('CA: ${aluno.ca!.toStringAsFixed(2)}');
  }
}
