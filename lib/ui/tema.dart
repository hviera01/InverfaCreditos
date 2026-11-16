import 'package:flutter/material.dart';

class C {
  static const papel = Color(0xFFF3EEE4);
  static const superficie = Color(0xFFFBF9F4);
  static const blanco = Color(0xFFFFFEFB);
  static const linea = Color(0xFFDAD0BC);
  static const lineaSuave = Color(0xFFE9E2D3);
  static const tinta = Color(0xFF1C221E);
  static const tintaSuave = Color(0xFF66655A);
  static const tintaTenue = Color(0xFF8E8B7D);
  static const verde = Color(0xFF17392C);
  static const verdeMedio = Color(0xFF245441);
  static const verdeClaro = Color(0xFFDDE8DF);
  static const laton = Color(0xFFB07D27);
  static const latonSuave = Color(0xFFF2E6CC);
  static const rojo = Color(0xFF9E3426);
  static const rojoSuave = Color(0xFFF5E0DA);
  static const rojoFila = Color(0xFFFBEDE9);
  static const ok = Color(0xFF1B8A4B);
  static const okSuave = Color(0xFFDDF0E3);
  static const seleccion = Color(0xFFE6EDE3);
}

class T {
  static const sans = 'Plex';
  static const mono = 'PlexMono';
  static const serif = 'Fraunces';

  static TextStyle titulo(double size, {Color color = C.tinta, double peso = 600}) => TextStyle(
    fontFamily: serif,
    fontSize: size,
    color: color,
    height: 1.1,
    fontVariations: [FontVariation('wght', peso), FontVariation('opsz', size.clamp(9, 144)), const FontVariation('SOFT', 30)],
  );

  static TextStyle texto(double size, {Color color = C.tinta, FontWeight peso = FontWeight.w400, double? tracking}) =>
      TextStyle(fontFamily: sans, fontSize: size, color: color, fontWeight: peso, letterSpacing: tracking, height: 1.25);

  static TextStyle cifra(double size, {Color color = C.tinta, FontWeight peso = FontWeight.w500}) =>
      TextStyle(fontFamily: mono, fontSize: size, color: color, fontWeight: peso, height: 1.2, fontFeatures: const [FontFeature.tabularFigures()]);

  static TextStyle etiqueta({Color color = C.tintaSuave}) =>
      TextStyle(fontFamily: sans, fontSize: 11.5, color: color, fontWeight: FontWeight.w600, letterSpacing: 0.6, height: 1.2);
}

ThemeData construirTema() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: T.sans,
    colorScheme: ColorScheme.fromSeed(seedColor: C.verde, primary: C.verde, secondary: C.laton, surface: C.superficie, error: C.rojo),
    scaffoldBackgroundColor: C.papel,
  );
  return base.copyWith(
    textSelectionTheme: const TextSelectionThemeData(cursorColor: C.verde, selectionColor: Color(0x3317392C), selectionHandleColor: C.verde),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: C.tinta, borderRadius: BorderRadius.circular(3)),
      textStyle: T.texto(12.5, color: C.blanco),
      waitDuration: const Duration(milliseconds: 400),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.all(const Color(0x5517392C)),
      thickness: WidgetStateProperty.all(8),
      radius: const Radius.circular(2),
      thumbVisibility: WidgetStateProperty.all(true),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: C.superficie,
      headerBackgroundColor: C.verde,
      headerForegroundColor: C.blanco,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: C.superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: C.blanco,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: C.linea),
      ),
      textStyle: T.texto(13.5),
    ),
  );
}
