import '../data/modelos.dart';
import '../data/repo.dart';
import '../db/db.dart';
import 'archivos.dart';

const _profesiones = {
  '1': 'MAESTRO DE EDUCACION',
  '2': 'INGENIERO',
  '3': 'PERITO MERCANTIL',
  '4': 'COMERCIANTE',
  '5': 'MAESTRO',
  '6': 'CAFETALERO',
  '7': 'COMERCIANTE',
  '8': 'BACHILLER CIENCIAS',
  '9': 'AMA DE CASA',
  '10': 'POLICIA',
  '11': 'SECA PELO',
  '12': 'ENFERMERA',
  '13': 'CAMPESINO',
  '14': 'IGLESIA',
  '15': 'MECANICO',
  '16': 'CARNICERO',
  '17': 'COMEDOR',
  '18': 'BANCO',
  '19': 'TABACALERO',
  '20': 'BRIGADA 110',
  '21': 'PERIODISTA',
  '22': 'AGRICULTOR',
  '23': 'estudiante',
  '24': 'gerente',
  '25': '0FTALMOLOGO',
  '26': 'VIGILANTE',
  '27': 'DOCTOR',
  '28': 'INVERFAM',
  '29': 'ABOGADO',
  '30': 'GUARDIA',
  '31': 'SANTA FE',
  '32': 'AMA DE CASA',
  '33': 'ASEADORA',
  '34': 'AMA DE CASA',
};

String _profesion(String codigo) {
  final c = codigo.trim();
  if (c.isEmpty) return 'N/A';
  final clave = double.tryParse(c) != null && double.parse(c) == double.parse(c).truncateToDouble() ? double.parse(c).toInt().toString() : c;
  final d = _profesiones[clave];
  return (d == null || d.trim().isEmpty) ? 'N/A' : d;
}

double _decimal(String t) {
  if (t.trim().isEmpty) return 0;
  final v = double.tryParse(t.trim().replaceAll(',', ''));
  if (v == null) throw Exception("No se pudo convertir a decimal el valor '$t'.");
  return v;
}

String _sufijoAleatorio() {
  final n = DateTime.now().microsecondsSinceEpoch;
  return (n & 0xFFFF).toRadixString(16).padLeft(4, '0');
}

Future<String> importarCreditos(String ruta) async {
  final hoja = await HojaExcel.leer(ruta);
  final usados = <String>{
    for (final c in await Repo.listarClientes())
      if (c.documento.trim().isNotEmpty) c.documento.trim().toLowerCase(),
  };
  var fila = 2;
  var leidas = 0, ok = 0, errores = 0;
  final detalle = StringBuffer();
  while (hoja.celda(fila, 1).trim().isNotEmpty) {
    leidas++;
    try {
      final codRaw = hoja.celda(fila, 1);
      final nombre = hoja.celda(fila, 2);
      final docRaw = hoja.celda(fila, 3);
      final codProf = hoja.celda(fila, 7);
      final tel = hoja.celda(fila, 8);
      final cel = hoja.celda(fila, 9);
      final direccion = hoja.celda(fila, 11);
      final montoTotal = _decimal(hoja.celda(fila, 15));
      final saldo = _decimal(hoja.celda(fila, 16));
      final cod = double.tryParse(codRaw.trim().replaceAll(',', ''))?.truncate() ?? 0;
      String base;
      if (docRaw.trim().isEmpty) {
        base = 'SIN-DOC-${fila.toString().padLeft(4, '0')}';
      } else {
        base = docRaw.trim();
        if (base.length <= 4) base = '$base-${_sufijoAleatorio()}';
      }
      var docFinal = base;
      var intento = 1;
      while (usados.contains(docFinal.toLowerCase())) {
        docFinal = '$base-$intento';
        intento++;
      }
      usados.add(docFinal.toLowerCase());
      String telefono = '';
      if (tel.trim().isNotEmpty && cel.trim().isNotEmpty) {
        telefono = '$tel / $cel';
      } else if (tel.trim().isNotEmpty) {
        telefono = tel;
      } else if (cel.trim().isNotEmpty) {
        telefono = cel;
      }
      final cliente = Cliente(
        codCliente: cod,
        documento: docFinal,
        nombreCompleto: nombre,
        correo: _profesion(codProf),
        telefono: telefono,
        direccion: direccion,
        estado: true,
      );
      final venc = DateTime.now().add(const Duration(days: 30));
      final r = await Repo.registrarCredito(
        NuevoCredito(
          idClienteExistente: null,
          cliente: cliente,
          numeroDocumento: 'N/A',
          montoTotal: montoTotal,
          saldoPendiente: saldo,
          fechaVencimiento: venc,
          fechaRegistro: DateTime.now(),
          descripcion: 'N/A',
          numeroCuotas: 1,
          frecuencia: 'mensual',
          fechaInicio: venc,
        ),
      );
      if (!r.ok) throw Exception(r.mensaje);
      ok++;
    } on OdbcError catch (e) {
      errores++;
      detalle.writeln('Fila $fila: ${e.mensaje}');
    } catch (e) {
      errores++;
      detalle.writeln('Fila $fila: ${e.toString().replaceFirst('Exception: ', '')}');
    }
    fila++;
  }
  final sb = StringBuffer()
    ..writeln('Importación finalizada.')
    ..writeln('Filas leídas   : $leidas')
    ..writeln('Filas correctas: $ok')
    ..writeln('Filas con error: $errores');
  if (errores > 0) {
    sb
      ..writeln()
      ..writeln('Detalle de errores:')
      ..write(detalle.toString());
  }
  return sb.toString().trimRight();
}

Future<(int, int)> importarClientes(String ruta) async {
  final hoja = await HojaExcel.leer(ruta);
  final usados = <String>{
    for (final c in await Repo.listarClientes())
      if (c.documento.trim().isNotEmpty) c.documento.trim().toLowerCase(),
  };
  var importados = 0, fallidos = 0;
  var ultima = hoja.filas.length;
  while (ultima > 0 && hoja.filas[ultima - 1].every((c) => c.trim().isEmpty)) {
    ultima--;
  }
  var primera = 1;
  while (primera <= ultima && hoja.filas[primera - 1].every((c) => c.trim().isEmpty)) {
    primera++;
  }
  for (var fila = primera + 1; fila <= ultima; fila++) {
    if (hoja.filas[fila - 1].every((c) => c.trim().isEmpty)) continue;
    final cuenta = hoja.celda(fila, 1).trim();
    final nombre = hoja.celda(fila, 2).trim();
    final identidad = hoja.celda(fila, 3).trim();
    final profesion = hoja.celda(fila, 4).trim();
    final direccion = hoja.celda(fila, 5).trim();
    final celular = hoja.celda(fila, 6).trim();
    if (nombre.isEmpty) {
      fallidos++;
      continue;
    }
    final base = identidad.isNotEmpty ? identidad : cuenta;
    if (base.isEmpty) {
      fallidos++;
      continue;
    }
    var docFinal = base;
    var sufijo = 1;
    while (usados.contains(docFinal.toLowerCase())) {
      docFinal = '$base-${sufijo.toString().padLeft(3, '0')}';
      sufijo++;
    }
    try {
      final r = await Repo.registrarCliente(
        Cliente(documento: docFinal, nombreCompleto: nombre, correo: profesion, direccion: direccion, telefono: celular, estado: true),
      );
      if (r.ok) {
        usados.add(docFinal.toLowerCase());
        importados++;
      } else {
        fallidos++;
      }
    } catch (_) {
      fallidos++;
    }
  }
  return (importados, fallidos);
}
