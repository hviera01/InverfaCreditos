import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inverfa_creditos/data/formato.dart';
import 'package:inverfa_creditos/data/modelos.dart';
import 'package:inverfa_creditos/db/db.dart';
import 'package:inverfa_creditos/ui/login.dart';
import 'package:inverfa_creditos/ui/principal.dart';
import 'package:inverfa_creditos/ui/tema.dart';

Future<void> _fuente(String familia, List<String> rutas) async {
  final l = FontLoader(familia);
  for (final r in rutas) {
    l.addFont(Future.value(ByteData.sublistView(File(r).readAsBytesSync())));
  }
  await l.load();
}

Widget _app(Widget home) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: construirTema(),
  locale: const Locale('es'),
  supportedLocales: const [Locale('es')],
  localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
  home: home,
);

Future<void> _hasta(WidgetTester t, Finder f, {int ms = 15000}) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await t.pump(const Duration(milliseconds: 30));
    if (f.evaluate().isNotEmpty) return;
  }
  fail('No apareció: $f');
}

Future<void> _calma(WidgetTester t, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await t.pump(const Duration(milliseconds: 30));
  }
  await t.pump(const Duration(seconds: 3));
}

Future<List<String?>> _fila(String sql) async {
  late Tabla r;
  await Future.sync(() async => r = await Db.consulta('SET NOCOUNT ON; $sql'));
  return r.filas.isEmpty ? <String?>[] : r.filas.first;
}

Finder _campo(String etiqueta) => find.descendant(
  of: find.ancestor(of: find.text(etiqueta), matching: find.byType(Column)).first,
  matching: find.byType(TextField),
);

void main() {
  final usuario = Usuario(
    id: 1,
    documento: '1',
    nombre: 'Administrador de Prueba',
    idRol: 1,
    rol: 'Administrador',
    permisos: {'menucreditos', 'toolstripmenuitem3', 'iconmenuitmenuclientesem6', 'menuacercade'},
  );

  setUpAll(() async {
    expect(Db.config.base, isNot('DB_INVERFA'));
    await _fuente('Plex', ['assets/fonts/IBMPlexSans-Regular.ttf', 'assets/fonts/IBMPlexSans-SemiBold.ttf']);
    await _fuente('PlexMono', ['assets/fonts/IBMPlexMono-Regular.ttf']);
    await _fuente('Fraunces', ['assets/fonts/Fraunces.ttf']);
  });

  testWidgets('login real: clave mala y clave buena', (t) async {
    t.view.physicalSize = const Size(1366, 768);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    List<String?> u = [];
    await t.runAsync(() async => u = await _fila("SELECT TOP 1 Documento, Clave FROM USUARIO WHERE Documento NOT LIKE '%[^0-9]%' ORDER BY IdUsuario"));
    expect(u, isNotEmpty);
    await t.pumpWidget(_app(const PantallaLogin()));
    await _calma(t, 1500);
    final campos = find.byType(TextField);
    await t.enterText(campos.at(0), u[0]!);
    await t.enterText(campos.at(1), '${u[1]}x');
    await t.tap(find.text('Ingresar'));
    await _hasta(t, find.text('Usuario o clave incorrectos.'));
    await t.tap(find.text('Aceptar'));
    await _calma(t);
    expect((t.widget(campos.at(0)) as TextField).controller!.text, '');
    await t.enterText(campos.at(0), u[0]!);
    await t.enterText(campos.at(1), u[1]!);
    await t.testTextInput.receiveAction(TextInputAction.done);
    await _hasta(t, find.text('VENTAS A CREDITO'));
    await _calma(t, 3000);
  });

  testWidgets('flujo completo de crédito y abonos por la interfaz', (t) async {
    t.view.physicalSize = const Size(1366, 768);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.runAsync(() async {
      await Db.ejecutar("SET NOCOUNT ON; DELETE FROM CLIENTE WHERE Documento IN ('555111222','555333444');");
    });
    await t.pumpWidget(_app(PantallaPrincipal(usuario: usuario)));
    await _hasta(t, find.text('TOTAL CREDITO PENDIENTE'));
    await _calma(t, 4000);

    await t.tap(find.text('Registrar credito'));
    await _hasta(t, find.text('INGRESAR NUEVO CREDITO'));
    await _calma(t);
    await t.tap(find.text('Registrar Credito'));
    await _hasta(t, find.text('Ingrese el nombre del cliente.'));
    await t.tap(find.text('Aceptar'));
    await _calma(t);
    await t.enterText(_campo('No. de factura:'), 'UI-777');
    await t.enterText(_campo('Descripcion:'), 'PRUEBA UI');
    await t.enterText(_campo('Monto total:'), '1200');
    await t.enterText(_campo('Prima:'), '200');
    await t.enterText(_campo('No. Cuotas:'), '4');
    await t.tap(find.text('Semanal'));
    await _calma(t, 300);
    await t.tap(find.text('Mensual').last);
    await _calma(t, 300);
    await t.enterText(_campo('Cliente:'), 'CLIENTE FLUJO UI');
    await t.enterText(_campo('Identidad / RTN:'), '555111222');
    await _calma(t, 300);
    expect(find.text('1000.00'), findsOneWidget);
    expect(find.text('250.00'), findsOneWidget);
    await t.tap(find.text('Registrar Credito'));
    await _hasta(t, find.text('Crédito registrado correctamente.'));
    await _calma(t, 4000);

    List<String?> v = [];
    await t.runAsync(() async {
      v = await _fila(
        "SELECT IdVenta, SaldoPendiente, (SELECT COUNT(*) FROM CUOTA_CREDITO c WHERE c.IdVenta=v.IdVenta AND c.MontoCuota=250), "
        "CONVERT(char(10), FechaVencimiento, 23), Descripcion FROM VENTA v WHERE NumeroDocumento='UI-777'",
      );
    });
    expect(parseDecimal(v[1]), 1000);
    expect(v[2], '4');
    expect(v[4], 'PRUEBA UI');
    final idVenta = int.parse(v[0]!);

    await t.enterText(find.byType(TextField).first, 'UI-777');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await _calma(t, 800);
    await t.tap(find.text('CLIENTE FLUJO UI'));
    await _calma(t, 300);
    await t.tap(find.text('Registrar abono').first);
    await _hasta(t, find.text('ABONOS DE FACTURAS A CREDITO'));
    await _calma(t, 1500);
    final monto = find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == '0.00');
    await t.enterText(monto, '5000');
    await t.tap(find.text('Registrar abono').last);
    await _hasta(t, find.text('El monto del abono no puede ser mayor que el saldo base.'));
    await t.tap(find.text('Aceptar'));
    await _calma(t);
    await t.enterText(monto, '300');
    await t.tap(find.text('Registrar abono').last);
    await _hasta(t, find.text('Abono registrado correctamente.'));
    await _calma(t, 2000);
    await t.runAsync(() async => v = await _fila("SELECT SaldoPendiente FROM VENTA WHERE IdVenta=$idVenta"));
    expect(parseDecimal(v[0]), 700);
    await t.runAsync(
      () async => v = await _fila(
        "SELECT (SELECT Estado FROM CUOTA_CREDITO WHERE IdVenta=$idVenta AND NumeroCuota=1), (SELECT CONCAT(Estado,'|',MontoPagado) FROM CUOTA_CREDITO WHERE IdVenta=$idVenta AND NumeroCuota=2)",
      ),
    );
    expect(v[0], 'Pagada');
    expect(v[1], 'Parcial|50.00');

    final filaAbono = find.text('L.300.00').last;
    await t.tap(filaAbono);
    await t.pump(const Duration(milliseconds: 60));
    await t.tap(filaAbono);
    await _hasta(t, find.text('Actualizar abono'));
    await t.enterText(monto, '250');
    await t.tap(find.text('Actualizar abono'));
    await _hasta(t, find.text('Abono actualizado correctamente.'));
    await _calma(t, 2000);
    await t.runAsync(() async => v = await _fila("SELECT SaldoPendiente FROM VENTA WHERE IdVenta=$idVenta"));
    expect(parseDecimal(v[0]), 750);

    final filaEditada = find.text('L.250.00').last;
    await t.tap(filaEditada);
    await t.pump(const Duration(milliseconds: 60));
    await t.tap(filaEditada);
    await _hasta(t, find.text('Eliminar abono'));
    await t.tap(find.text('Eliminar abono'));
    await _hasta(t, find.text('¿Seguro que desea eliminar este abono?'));
    await t.tap(find.text('Sí'));
    await _hasta(t, find.text('Abono eliminado correctamente.'));
    await _calma(t, 2000);
    await t.runAsync(() async => v = await _fila("SELECT SaldoPendiente, (SELECT COUNT(*) FROM Abonos WHERE IdVenta=$idVenta) FROM VENTA WHERE IdVenta=$idVenta"));
    expect(parseDecimal(v[0]), 1000);
    expect(v[1], '0');

    await t.tap(find.text('Cancelar').last);
    await _calma(t, 2500);
    await t.tap(find.text('CLIENTE FLUJO UI'));
    await _calma(t, 300);
    await t.tap(find.text('Eliminar Credito'));
    await _hasta(t, find.text('Eliminar crédito'));
    await t.tap(find.text('Sí, eliminar'));
    await _hasta(t, find.text('Crédito eliminado correctamente.'));
    await _calma(t, 3000);
    await t.runAsync(() async => v = await _fila("SELECT COUNT(*) FROM VENTA WHERE IdVenta=$idVenta"));
    expect(v[0], '0');

    await t.tap(find.text('CLIENTES'));
    await _hasta(t, find.text('DETALLE CLIENTE'));
    await _calma(t, 3000);
    await t.enterText(_campo('DNI:'), '555333444');
    await t.enterText(_campo('Nombre:'), 'CLIENTE PANTALLA');
    await t.enterText(_campo('Profesion u Oficio'), 'CARPINTERO');
    await t.tap(find.text('GUARDAR'));
    await _hasta(t, find.text('Cliente registrado correctamente'));
    await _calma(t, 3000);
    await t.enterText(_campo('DNI:'), '555333444');
    await t.enterText(_campo('Nombre:'), 'DUPLICADO');
    await t.tap(find.text('GUARDAR'));
    await _hasta(t, find.textContaining('documento ya existe'));
    await t.tap(find.text('Aceptar'));
    await _calma(t);
    await t.tap(find.text('LIMPIAR'));
    await _calma(t);
    await t.enterText(find.byType(TextField).last, 'CLIENTE PANTALLA');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await _calma(t, 800);
    await t.tap(find.text('CLIENTE PANTALLA').last);
    await _calma(t, 300);
    expect((t.widget(_campo('DNI:')) as TextField).controller!.text, '555333444');
    await t.enterText(_campo('Nombre:'), 'CLIENTE PANTALLA EDITADO');
    await t.tap(find.text('GUARDAR'));
    await _hasta(t, find.text('Cliente actualizado correctamente'));
    await _calma(t, 3000);
    await t.runAsync(() async => v = await _fila("SELECT NombreCompleto, Correo, CodCliente FROM CLIENTE WHERE Documento='555333444'"));
    expect(v[0], 'CLIENTE PANTALLA EDITADO');
    expect(v[1], 'CARPINTERO');
    expect(int.parse(v[2]!), greaterThan(0));

    await t.enterText(find.byType(TextField).last, '555333444');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await _calma(t, 800);
    await t.tap(find.text('CLIENTE PANTALLA EDITADO').last);
    await _calma(t, 300);
    await t.tap(find.text('ELIMINAR'));
    await _hasta(t, find.text('¿Desea eliminar el cliente?'));
    await t.tap(find.text('Sí'));
    await _hasta(t, find.text('Cliente eliminado correctamente'));
    await _calma(t, 3000);
    await t.runAsync(() async => v = await _fila("SELECT COUNT(*) FROM CLIENTE WHERE Documento='555333444'"));
    expect(v[0], '0');
    await t.runAsync(() async {
      await Db.ejecutar("SET NOCOUNT ON; DELETE FROM CLIENTE WHERE Documento='555111222';");
    });
  });

  testWidgets('buscadores filtran solo con Enter y clientes muestra máximo 300', (t) async {
    t.view.physicalSize = const Size(1366, 768);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    List<String?> c = [];
    await t.runAsync(() async {
      c = await _fila("SELECT TOP 1 Documento, (SELECT COUNT(*) FROM CLIENTE) FROM CLIENTE WHERE LEN(Documento) >= 8 AND Documento NOT LIKE '%[^0-9]%' GROUP BY Documento HAVING COUNT(*) = 1 ORDER BY Documento");
    });
    final dni = c[0]!;
    final totalClientes = int.parse(c[1]!);
    expect(totalClientes, greaterThan(300));

    await t.pumpWidget(_app(PantallaPrincipal(usuario: usuario)));
    await _hasta(t, find.text('TOTAL CREDITO PENDIENTE'));
    await _hasta(t, find.textContaining(' créditos'));
    await _calma(t, 2000);
    String pie(String sufijo) => (t.widget(find.textContaining(sufijo).first) as Text).data!;
    final antes = pie(' créditos');
    expect(antes.startsWith('0 de'), isFalse);

    await t.enterText(find.byType(TextField).first, 'ZZQXNOEXISTE');
    await _calma(t, 1500);
    expect(pie(' créditos'), antes);
    await t.testTextInput.receiveAction(TextInputAction.done);
    await _calma(t, 500);
    expect(pie(' créditos'), startsWith('0 de'));
    expect(find.text('No hay créditos para mostrar'), findsOneWidget);
    await t.enterText(find.byType(TextField).first, '');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await _calma(t, 500);
    expect(pie(' créditos'), antes);

    await t.tap(find.text('CLIENTES'));
    await _hasta(t, find.text('DETALLE CLIENTE'));
    await _hasta(t, find.textContaining('Mostrando 300 de $totalClientes clientes'));
    await t.enterText(find.byType(TextField).last, dni);
    await _calma(t, 1500);
    expect(find.textContaining('Mostrando 300 de $totalClientes clientes'), findsOneWidget);
    await t.testTextInput.receiveAction(TextInputAction.done);
    await _calma(t, 500);
    expect(find.text('1 de $totalClientes clientes'), findsOneWidget);
    await t.tap(find.byIcon(Icons.backspace_outlined).last);
    await _calma(t, 500);
    expect(find.textContaining('Mostrando 300 de $totalClientes clientes'), findsOneWidget);
    await t.enterText(find.byType(TextField).last, dni);
    await t.tap(find.byIcon(Icons.search_rounded).last);
    await _calma(t, 500);
    expect(find.text('1 de $totalClientes clientes'), findsOneWidget);
  });
}
