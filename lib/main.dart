import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_manager/window_manager.dart';

import 'ui/login.dart';
import 'ui/tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await windowManager.setTitle('COMERCIAL INVERFA - Créditos');
  await windowManager.setMinimumSize(const Size(1280, 640));
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
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: child!,
      ),
      home: const PantallaLogin(),
    );
  }
}
