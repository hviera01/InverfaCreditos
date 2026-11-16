import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:inverfa_creditos/data/formato.dart';
import 'package:inverfa_creditos/db/db.dart';
import 'package:inverfa_creditos/main.dart' as app;

Future<void> _pausa(WidgetTester t, [int ms = 400]) async {
  final fin = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(fin)) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await t.pump();
  }
}

Future<void> _hasta(WidgetTester t, Finder f, {int ms = 20000}) async {
  final fin = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(fin)) {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await t.pump();
    if (f.evaluate().isNotEmpty) return;
  }
  final textos = find.byType(Text).evaluate().map((e) => (e.widget as Text).data ?? '').where((x) => x.isNotEmpty).skip(40).take(120).join(' | ');
  fail('No apareció: $f || EN PANTALLA: $textos');
}

Future<void> _tocar(WidgetTester t, Finder f) async {
  await _hasta(t, f);
  await t.ensureVisible(f);
  await _pausa(t, 350);
  await t.tap(f);
  await t.pump();
}

Future<void> _sinOverlay(WidgetTester t) => _pausa(t, 2600);

Future<List<String?>> _fila(String sql) async {
  final r = await Db.consulta('SET NOCOUNT ON; $sql');
  return r.filas.isEmpty ? <String?>[] : r.filas.first;
}

Finder _campo(String etiqueta) =>
    find.descendant(of: find.ancestor(of: find.text(etiqueta), matching: find.byType(Column)).first, matching: find.byType(TextField));

Future<void> _dobleClic(WidgetTester t, Finder base) async {
  await _hasta(t, base);
  final f = base.last;
  await t.ensureVisible(f);
  await _pausa(t, 300);
  await t.tap(f);
  await t.pump(const Duration(milliseconds: 60));
  await t.tap(f);
  await t.pump();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app real compilada: login, créditos, abonos y clientes', (t) async {
    expect(Db.config.base, isNot('DB_INVERFA'));
    await Db.ejecutar('''SET NOCOUNT ON;
DELETE ac FROM AbonoCuota ac JOIN Abonos a ON a.IdAbono = ac.IdAbono JOIN VENTA v ON v.IdVenta = a.IdVenta WHERE v.NumeroDocumento = 'APP-900';
DELETE a FROM Abonos a JOIN VENTA v ON v.IdVenta = a.IdVenta WHERE v.NumeroDocumento = 'APP-900';
DELETE c FROM CUOTA_CREDITO c JOIN VENTA v ON v.IdVenta = c.IdVenta WHERE v.NumeroDocumento = 'APP-900';
DELETE FROM VENTA WHERE NumeroDocumento = 'APP-900';
DELETE FROM CLIENTE WHERE Documento IN ('555111222','555333444');''');
    final u = await _fila("SELECT TOP 1 Documento, Clave FROM USUARIO WHERE Documento NOT LIKE '%[^0-9]%' AND IdRol = 1 ORDER BY IdUsuario");

    await app.main();
    t.testTextInput.register();
    await _hasta(t, find.text('INICIO DE SESION'));
    await _hasta(t, find.textContaining('Base de datos lista'));
    final campos = find.byType(TextField);
    await t.enterText(campos.at(0), u[0]!);
    await t.enterText(campos.at(1), 'incorrecta');
    await t.tap(find.text('Ingresar'));
    await _hasta(t, find.text('Usuario o clave incorrectos.'));
    await t.tap(find.text('Aceptar'));
    await _pausa(t);
    await t.enterText(campos.at(0), u[0]!);
    await t.enterText(campos.at(1), u[1]!);
    await _pausa(t);
    final c0 = (t.widget(campos.at(0)) as TextField).controller!.text;
    final c1 = (t.widget(campos.at(1)) as TextField).controller!.text;
    expect('doc=${c0 == u[0]} len=${c0.length}/${u[0]!.length} clave=${c1 == u[1]} len=${c1.length}/${u[1]!.length}', 'doc=true len=${u[0]!.length}/${u[0]!.length} clave=true len=${u[1]!.length}/${u[1]!.length}');
    await t.tap(find.text('Ingresar'));
    await _hasta(t, find.text('VENTAS A CREDITO'));
    await _hasta(t, find.textContaining('créditos'));
    await _pausa(t, 1500);

    await t.tap(find.text('Registrar credito'));
    await _hasta(t, find.text('INGRESAR NUEVO CREDITO'));
    await _pausa(t);
    await t.enterText(_campo('No. de factura:'), 'APP-900');
    await t.enterText(_campo('Monto total:'), '3000');
    await t.enterText(_campo('Prima:'), '500');
    await t.enterText(_campo('No. Cuotas:'), '3');
    await t.enterText(_campo('Cliente:'), 'CLIENTE APP REAL');
    await t.enterText(_campo('Identidad / RTN:'), '555111222');
    await _pausa(t);
    expect(find.text('2500.00'), findsOneWidget);
    expect(find.text('833.33'), findsOneWidget);
    await t.tap(find.text('Registrar Credito'));
    await _hasta(t, find.text('Crédito registrado correctamente.'));
    await _sinOverlay(t);
    var v = await _fila("SELECT IdVenta, SaldoPendiente, (SELECT SUM(MontoCuota) FROM CUOTA_CREDITO c WHERE c.IdVenta=v.IdVenta) FROM VENTA v WHERE NumeroDocumento='APP-900'");
    final idVenta = int.parse(v[0]!);
    expect(parseDecimal(v[1]), 2500);
    expect(parseDecimal(v[2]), 2500);

    await t.enterText(find.byType(TextField).first, 'APP-900');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await _pausa(t, 800);
    await t.tap(find.text('CLIENTE APP REAL'));
    await _pausa(t);
    await t.tap(find.text('Registrar abono').first);
    await _hasta(t, find.text('ABONOS DE FACTURAS A CREDITO'));
    await _pausa(t, 1200);
    final monto = find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == '0.00');
    await t.enterText(monto, '1000');
    await t.tap(find.text('No').last);
    await _pausa(t);
    await t.tap(find.text('Sí').last);
    await _pausa(t);
    await t.enterText(find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == '%'), '2');
    await _pausa(t);
    expect(find.text('L.50.00'), findsWidgets);
    await _tocar(t, find.text('Registrar abono').last);
    await _hasta(t, find.text('Abono registrado correctamente.'));
    final tam = t.view.physicalSize / t.view.devicePixelRatio;
    debugPrint('VENTANA: ${tam.width}x${tam.height}');
    await _sinOverlay(t);
    v = await _fila("SELECT SaldoPendiente FROM VENTA WHERE IdVenta=$idVenta");
    expect(parseDecimal(v[0]), 1550);

    await _dobleClic(t, find.text('L.1,000.00'));
    await _hasta(t, find.text('Actualizar abono'));
    await t.enterText(monto, '400');
    await _tocar(t, find.text('Actualizar abono'));
    await _hasta(t, find.text('Ingrese un porcentaje de interés válido.'));
    await t.tap(find.text('Aceptar'));
    await _pausa(t);
    await t.tap(find.text('Sí').last);
    await _pausa(t);
    await t.tap(find.text('No').last);
    await _pausa(t);
    await _tocar(t, find.text('Actualizar abono'));
    await _hasta(t, find.text('Abono actualizado correctamente.'));
    await _sinOverlay(t);
    v = await _fila("SELECT SaldoPendiente FROM VENTA WHERE IdVenta=$idVenta");
    expect(parseDecimal(v[0]), 2100);

    await t.ensureVisible(find.text('TABLA DEL CREDITO'));
    await _pausa(t, 300);
    await t.tap(find.text('TABLA DEL CREDITO'));
    await _hasta(t, find.text('Tabla de amortización del crédito'));
    expect(find.text('Parcial'), findsOneWidget);
    await t.tap(find.text('Cerrar'));
    await _pausa(t);

    await _dobleClic(t, find.text('L.400.00'));
    await _hasta(t, find.text('Eliminar abono'));
    await _tocar(t, find.text('Eliminar abono'));
    await _hasta(t, find.text('¿Seguro que desea eliminar este abono?'));
    await t.tap(find.text('Sí'));
    await _hasta(t, find.text('Abono eliminado correctamente.'));
    await _sinOverlay(t);
    v = await _fila("SELECT SaldoPendiente FROM VENTA WHERE IdVenta=$idVenta");
    expect(parseDecimal(v[0]), 2500);
    await t.tap(find.text('Cancelar').last);
    await _pausa(t, 1500);

    await t.tap(find.text('CLIENTE APP REAL'));
    await _pausa(t);
    await t.tap(find.text('Eliminar Credito'));
    await _hasta(t, find.text('Sí, eliminar'));
    await t.tap(find.text('Sí, eliminar'));
    await _hasta(t, find.text('Crédito eliminado correctamente.'));
    await _sinOverlay(t);
    v = await _fila("SELECT COUNT(*) FROM VENTA WHERE IdVenta=$idVenta");
    expect(v[0], '0');

    await t.tap(find.text('CLIENTES'));
    await _hasta(t, find.text('DETALLE CLIENTE'));
    await _hasta(t, find.textContaining('clientes'));
    await _pausa(t, 1000);
    await t.enterText(_campo('DNI:'), '555333444');
    await t.enterText(_campo('Nombre:'), 'CLIENTE APP DOS');
    await t.tap(find.text('GUARDAR'));
    await _hasta(t, find.text('Cliente registrado correctamente'));
    await _sinOverlay(t);
    await t.enterText(find.byType(TextField).last, '555333444');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await _pausa(t, 800);
    await t.tap(find.text('CLIENTE APP DOS').last);
    await _pausa(t);
    await t.tap(find.text('ELIMINAR'));
    await _hasta(t, find.text('¿Desea eliminar el cliente?'));
    await t.tap(find.text('Sí'));
    await _hasta(t, find.text('Cliente eliminado correctamente'));
    await _sinOverlay(t);

    await t.tap(find.text('Salir'));
    await _hasta(t, find.text('¿Desea salir?'));
    await t.tap(find.text('Sí'));
    await _hasta(t, find.text('INICIO DE SESION'));
    await Db.ejecutar("SET NOCOUNT ON; DELETE FROM CLIENTE WHERE Documento IN ('555111222','555333444');");
  });
}
