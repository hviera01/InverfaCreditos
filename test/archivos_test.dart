import 'dart:io';

import 'package:excel/excel.dart' as xl;
import 'package:flutter_test/flutter_test.dart';
import 'package:inverfa_creditos/data/formato.dart';
import 'package:inverfa_creditos/data/repo.dart';
import 'package:inverfa_creditos/db/db.dart';
import 'package:inverfa_creditos/ui/archivos.dart';
import 'package:inverfa_creditos/ui/importar.dart';

const salida = String.fromEnvironment('SALIDA');

String _xlsx(String nombre, List<List<Object?>> filas) {
  final libro = xl.Excel.createExcel();
  final h = libro[libro.getDefaultSheet()!];
  for (final f in filas) {
    h.appendRow([
      for (final v in f)
        v == null
            ? null
            : v is int
            ? xl.IntCellValue(v)
            : v is double
            ? xl.DoubleCellValue(v)
            : xl.TextCellValue(v.toString()),
    ]);
  }
  final ruta = '$salida/$nombre';
  File(ruta).writeAsBytesSync(libro.encode()!);
  return ruta;
}

Future<List<String?>> _fila(String sql) async {
  final t = await Db.consulta('SET NOCOUNT ON; $sql');
  return t.filas.isEmpty ? [] : t.filas.first;
}

void main() {
  setUpAll(() => expect(Db.config.base, isNot('DB_INVERFA')));

  test('Excel y PDF de todos los créditos', () async {
    final l = await Repo.listarCreditos();
    expect(l.length, greaterThan(9000));
    final enc = ['Fecha de Registro', 'No.Factura', 'Cod Cliente', 'Cliente', 'Monto Total', 'Saldo Pendiente'];
    final filas = [
      for (final c in l) [fechaCorta(c.fechaRegistro), c.numeroDocumento, c.codCliente, c.nombreCliente, c.montoTotal, c.saldoPendiente],
    ];
    final bytes = generarExcel('Creditos', enc, filas);
    File('$salida/creditos.xlsx').writeAsBytesSync(bytes);
    final hoja = await HojaExcel.leer('$salida/creditos.xlsx');
    expect(hoja.filas.length, l.length + 1);
    expect(hoja.celda(1, 1), 'Fecha de Registro');
    expect(hoja.celda(2, 4), l.first.nombreCliente);

    final reg = File('assets/fonts/IBMPlexSans-Regular.ttf').readAsBytesSync();
    final neg = File('assets/fonts/IBMPlexSans-Bold.ttf').readAsBytesSync();
    final pdf = await generarPdf(
      subtitulo: 'REPORTE DE CRÉDITOS',
      encabezados: enc,
      filas: [for (final f in filas) f.map((e) => e is double ? lempiras(e) : e.toString()).toList()],
      horizontal: true,
      fuenteRegular: reg,
      fuenteNegrita: neg,
      columnasDerecha: const [2, 4, 5],
    );
    File('$salida/creditos.pdf').writeAsBytesSync(pdf);
    expect(String.fromCharCodes(pdf.take(4)), '%PDF');
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('Importar créditos con formato del sistema viejo', () async {
    await Db.ejecutar("SET NOCOUNT ON; DELETE FROM CLIENTE WHERE NombreCompleto LIKE 'IMPORT PRUEBA%';");
    final ruta = _xlsx('importar_creditos.xlsx', [
      ['CodCli', 'NomCli', 'IdeCli', 'FchNac', 'Sex', 'EstCiv', 'CodProf', 'TelCli', 'CelCli', 'Correo', 'DirCli', 'LugTra', 'DirTra', 'TelTra', 'ComTotCli', 'SalCli'],
      [990001, 'IMPORT PRUEBA UNO', '0801199000111', '', '', '', 4, '2222', '9999', '', 'COL A', '', '', '', 5000.5, 1200.25],
      [990002.0, 'IMPORT PRUEBA DOS', '07', '', '', '', '', '', '8888', '', '', '', '', '', 100, 0],
      [990003, 'IMPORT PRUEBA TRES', '', '', '', '', 99, '', '', '', '', '', '', '', 'ABC', 10],
      [990001, 'IMPORT PRUEBA CUATRO', '0801199000444', '', '', '', 1, '', '', '', '', '', '', '', 50, 50],
    ]);
    final r = await importarCreditos(ruta);
    expect(r, contains('Filas leídas   : 4'));
    expect(r, contains('Filas correctas: 2'));
    expect(r, contains('Filas con error: 2'));
    expect(r, contains("No se pudo convertir a decimal el valor 'ABC'."));
    expect(r, contains('El código de cliente ya existe'));
    final a = await _fila(
      "SELECT c.Correo, c.Telefono, v.MontoTotal, v.SaldoPendiente, (SELECT COUNT(*) FROM CUOTA_CREDITO q WHERE q.IdVenta=v.IdVenta), v.NumeroDocumento "
      "FROM CLIENTE c JOIN VENTA v ON v.DocumentoCliente=c.Documento WHERE c.CodCliente=990001",
    );
    expect(a[0], 'COMERCIANTE');
    expect(a[1], '2222 / 9999');
    expect(parseDecimal(a[2]), 5000.5);
    expect(parseDecimal(a[3]), 1200.25);
    expect(a[4], '1');
    expect(a[5], 'N/A');
    final b = await _fila("SELECT Documento, Correo, (SELECT COUNT(*) FROM VENTA v WHERE v.DocumentoCliente=c.Documento) FROM CLIENTE c WHERE CodCliente=990002");
    expect(b[0]!.startsWith('07-'), isTrue);
    expect(b[1], 'N/A');
    expect(b[2], '1');
    await Db.ejecutar('''
SET NOCOUNT ON;
DECLARE @v TABLE (IdVenta INT);
INSERT @v SELECT v.IdVenta FROM VENTA v JOIN CLIENTE c ON c.Documento = v.DocumentoCliente WHERE c.NombreCompleto LIKE 'IMPORT PRUEBA%';
DELETE FROM CUOTA_CREDITO WHERE IdVenta IN (SELECT IdVenta FROM @v);
DELETE FROM VENTA WHERE IdVenta IN (SELECT IdVenta FROM @v);
DELETE FROM CLIENTE WHERE NombreCompleto LIKE 'IMPORT PRUEBA%';''');
  });

  test('Importar clientes', () async {
    await Db.ejecutar("SET NOCOUNT ON; DELETE FROM CLIENTE WHERE NombreCompleto LIKE 'IMPCLI%';");
    final ruta = _xlsx('importar_clientes.xlsx', [
      ['Cuenta', 'Nombre', 'Identidad', 'Profesion', 'Direccion', 'Celular', 'Saldo'],
      ['C1', 'IMPCLI UNO', '0703-IMP', 'MAESTRO', 'BARRIO X', '9999', 0],
      ['C2', '', '0703-IMP2', '', '', '', 0],
      ['C3', 'IMPCLI TRES', '0703-IMP', '', '', '', 0],
      ['C4', 'IMPCLI CUATRO', '', '', '', '', 0],
    ]);
    final (imp, fal) = await importarClientes(ruta);
    expect(imp, 3);
    expect(fal, 1);
    final docs = await Db.consulta("SET NOCOUNT ON; SELECT Documento FROM CLIENTE WHERE NombreCompleto LIKE 'IMPCLI%' ORDER BY IdCliente");
    expect(docs.filas.map((f) => f[0]).toList(), ['0703-IMP', '0703-IMP-001', 'C4']);
    await Db.ejecutar("SET NOCOUNT ON; DELETE FROM CLIENTE WHERE NombreCompleto LIKE 'IMPCLI%';");
  });
}
