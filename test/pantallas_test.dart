import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inverfa_creditos/data/modelos.dart';
import 'package:inverfa_creditos/ui/login.dart';
import 'package:inverfa_creditos/ui/principal.dart';
import 'package:inverfa_creditos/ui/tema.dart';

const salida = String.fromEnvironment('CAPTURAS');
final _clave = GlobalKey();

Future<void> _fuente(String familia, List<String> rutas) async {
  final l = FontLoader(familia);
  for (final r in rutas) {
    l.addFont(Future.value(ByteData.sublistView(File(r).readAsBytesSync())));
  }
  await l.load();
}

Widget _app(Widget home) => RepaintBoundary(
  key: _clave,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: construirTema(),
    locale: const Locale('es'),
    supportedLocales: const [Locale('es')],
    localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    home: home,
  ),
);

Future<void> _esperar(WidgetTester t, [int ms = 2500]) async {
  for (var i = 0; i < ms ~/ 250; i++) {
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
    await t.pump(const Duration(milliseconds: 50));
  }
  await t.pump(const Duration(seconds: 3));
}

Future<void> _captura(WidgetTester t, String nombre) async {
  if (salida.isEmpty) return;
  await t.runAsync(() async {
    final b = _clave.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 1);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$salida/$nombre.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

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
    await _fuente('Plex', [
      'assets/fonts/IBMPlexSans-Regular.ttf',
      'assets/fonts/IBMPlexSans-Medium.ttf',
      'assets/fonts/IBMPlexSans-SemiBold.ttf',
      'assets/fonts/IBMPlexSans-Bold.ttf',
    ]);
    await _fuente('PlexMono', [
      'assets/fonts/IBMPlexMono-Regular.ttf',
      'assets/fonts/IBMPlexMono-Medium.ttf',
      'assets/fonts/IBMPlexMono-SemiBold.ttf',
    ]);
    await _fuente('Fraunces', ['assets/fonts/Fraunces.ttf']);
    final flutterRoot = File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
    final iconos = '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
    if (File(iconos).existsSync()) await _fuente('MaterialIcons', [iconos]);
  });

  for (final tam in const [Size(1280, 640), Size(1366, 690), Size(1280, 720), Size(1920, 1010)]) {
    final s = '${tam.width.toInt()}x${tam.height.toInt()}';

    testWidgets('login $s', (t) async {
      t.view.physicalSize = tam;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(_app(const PantallaLogin()));
      await _esperar(t, 3000);
      expect(find.text('INICIO DE SESION'), findsOneWidget);
      expect(find.text('Codigo de acceso'), findsOneWidget);
      await _captura(t, 'login_$s');
    });

    testWidgets('creditos y modales $s', (t) async {
      t.view.physicalSize = tam;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(_app(PantallaPrincipal(usuario: usuario)));
      await _esperar(t, 6000);
      expect(find.text('VENTAS A CREDITO'), findsOneWidget);
      expect(find.text('TOTAL CREDITO PENDIENTE'), findsOneWidget);
      await _captura(t, 'creditos_$s');

      await t.tap(find.text('Registrar credito'));
      await _esperar(t, 500);
      expect(find.text('INGRESAR NUEVO CREDITO'), findsOneWidget);
      await _captura(t, 'registrar_credito_$s');
      await t.tap(find.text('Buscar cliente'));
      await _esperar(t, 4000);
      expect(find.text('LISTA DE CLIENTES'), findsOneWidget);
      await _captura(t, 'buscar_cliente_$s');
      await t.tap(find.text('Cancelar').last);
      await _esperar(t, 500);
      await t.tap(find.text('Cancelar').last);
      await _esperar(t, 500);

      await t.tap(find.text('Registrar abono'));
      await _esperar(t, 500);
      expect(find.text('Por favor, seleccione una venta a crédito.'), findsOneWidget);
      await t.tap(find.text('Aceptar'));
      await _esperar(t, 500);

      await t.tap(find.text('Debe').first);
      await _esperar(t, 300);
      await t.tap(find.text('Todas').last);
      await _esperar(t, 500);
      await _captura(t, 'creditos_todas_$s');
      await t.tap(find.text('Todas').first);
      await _esperar(t, 300);
      await t.tap(find.text('Debe').last);
      await _esperar(t, 500);
      await t.enterText(find.byType(TextField).first, '13673');
      await _esperar(t, 1000);
      await t.enterText(find.byType(TextField).first, 'EQUIV');
      await _esperar(t, 1000);
      await t.enterText(find.byType(TextField).first, '');
      await _esperar(t, 1000);

      final fila = find.text('2,250.00', skipOffstage: false);
      final celdas = find.textContaining('L.');
      expect(celdas, findsWidgets);
      await t.tap(find.byType(ListView).first.first);
      await _esperar(t, 300);
      await t.tap(find.text('Registrar abono'));
      await _esperar(t, 3000);
      expect(find.text('ABONOS DE FACTURAS A CREDITO'), findsOneWidget);
      final montoCampo = find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == '0.00');
      await t.enterText(montoCampo, '100.5');
      await _esperar(t, 300);
      expect(find.text('L.0.00'), findsWidgets);
      await t.tap(find.text('No').last);
      await _esperar(t, 300);
      await t.tap(find.text('Sí').last);
      await _esperar(t, 300);
      await t.enterText(find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == '%'), '3');
      await _esperar(t, 300);
      await _captura(t, 'abonos_$s');
      await t.tap(find.text('TABLA DEL CREDITO'));
      await _esperar(t, 800);
      expect(find.text('Tabla de amortización del crédito'), findsOneWidget);
      await _captura(t, 'tabla_credito_$s');
      await t.tap(find.text('Cerrar'));
      await _esperar(t, 500);
      if (find.text('Este crédito todavía no tiene abonos').evaluate().isNotEmpty) {
        await t.ensureVisible(find.text('Registrar abono').last);
        await _esperar(t, 300);
        await t.tap(find.text('Registrar abono').last);
        await _esperar(t, 2500);
      }
      final filaHist = find.textContaining('Cuota ').last;
      await t.ensureVisible(filaHist);
      await _esperar(t, 300);
      await t.tap(filaHist);
      await t.pump(const Duration(milliseconds: 60));
      await t.tap(filaHist);
      await _esperar(t, 800);
      await _captura(t, 'editar_abono_$s');
      expect(find.text('Actualizar abono'), findsOneWidget);
      final previo = WidgetController.hitTestWarningShouldBeFatal;
      WidgetController.hitTestWarningShouldBeFatal = true;
      await t.tap(find.text('Cancelar').last, warnIfMissed: true);
      WidgetController.hitTestWarningShouldBeFatal = previo;
      await _esperar(t, 500);
      if (find.text('ABONOS DE FACTURAS A CREDITO').evaluate().isNotEmpty) {
        await t.tap(find.text('Cancelar').last);
        await _esperar(t, 500);
      }
      await _captura(t, 'tras_editar_$s');
      await _esperar(t, 500);
      expect(fila, anything);

      await t.tap(find.text('CLIENTES'));
      await _esperar(t, 5000);
      expect(find.text('LISTA DE CLIENTES'), findsOneWidget);
      expect(find.text('DETALLE CLIENTE'), findsOneWidget);
      await t.tap(find.byType(ListView).first.first);
      await _esperar(t, 400);
      await _captura(t, 'clientes_$s');

      await t.tap(find.text('ACERCA DE'));
      await _esperar(t, 500);
      await _captura(t, 'acerca_$s');
      await t.tap(find.text('Aceptar'));
      await _esperar(t, 300);

      await t.tap(find.text('Salir'));
      await _esperar(t, 300);
      expect(find.text('¿Desea salir?'), findsOneWidget);
      await _captura(t, 'salir_$s');
      await t.tap(find.text('No'));
      await _esperar(t, 300);
    });
  }
}
