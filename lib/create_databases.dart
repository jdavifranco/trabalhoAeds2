import 'generate_fixed_database.dart';
import 'generate_variable_database.dart';

/// Script para criar as duas bases de dados originais
void main() async {
  final fixedGenerator = GenerateFixedDatabase();
  final fixedAlunos = fixedGenerator.generate(100);
  await fixedGenerator.saveToFile('lib/input_database/fixed.dat', fixedAlunos);

  final variableGenerator = GenerateVariableDatabase();
  final variableAlunos = variableGenerator.generate(100);
  await variableGenerator.saveToFile(
    'lib/input_database/variable.dat',
    variableAlunos,
  );
}
