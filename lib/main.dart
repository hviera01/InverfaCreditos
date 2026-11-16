import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_manager/window_manager.dart';

import 'ui/login.dart';
import 'ui/tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  const opciones = WindowOptions(
    title: 'COMERCIAL INVERFA - Créditos',
    minimumSize: Size(1280, 720),
    size: Size(1440, 860),
    center: true,
    backgroundColor: C.papel,
  );
  await windowManager.waitUntilReadyToShow(opciones, () async {
    await windowManager.maximize();
    await windowManager.show();
    await windowManager.focus();
  });
  runApp(const AppInverfa());
}

class AppInverfa extends StatelessWidget {
  const AppInverfa({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'COMERCIAL INVERFA',
      debugShowCheckedModeBanner: false,
      theme: construirTema(),
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.f11): () async {
            final f = await windowManager.isFullScreen();
            await windowManager.setFullScreen(!f);
          },
        },
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
          child: child!,
        ),
      ),
      home: const PantallaLogin(),
    );
  }
}
