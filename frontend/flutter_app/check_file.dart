import 'dart:io';

void main() {
  var file = File('lib/features/medico/presentation/registro_paciente_page.dart');
  print('Size: ' + file.lengthSync().toString());
}