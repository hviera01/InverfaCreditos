double r2(double v) => (v * 100).roundToDouble() / 100;

int centavos(double v) => (v * 100).round();

double deCentavos(int c) => c / 100;

String _miles(int entero) {
  final s = entero.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

String numero2(double v) {
  final c = centavos(v);
  final neg = c < 0;
  final a = c.abs();
  return '${neg ? '-' : ''}${_miles(a ~/ 100)}.${(a % 100).toString().padLeft(2, '0')}';
}

String lempiras(double v) {
  final c = centavos(v);
  final t = numero2(c.abs() / 100);
  return c < 0 ? '-L.$t' : 'L.$t';
}

String plano2(double v) => (centavos(v) / 100).toStringAsFixed(2);

String fechaCorta(DateTime? d) {
  if (d == null) return '';
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year.toString().padLeft(4, '0')}';
}

String fechaHora(DateTime d) => '${fechaCorta(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

DateTime? parseFecha(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  return DateTime.tryParse(s.trim());
}

double parseDecimal(String? s) {
  if (s == null) return 0;
  return double.tryParse(s.trim()) ?? 0;
}

int parseEntero(String? s) {
  if (s == null) return 0;
  final t = s.trim();
  return int.tryParse(t) ?? double.tryParse(t)?.truncate() ?? 0;
}

bool parseBit(String? s) {
  if (s == null) return false;
  final t = s.trim().toLowerCase();
  return t == '1' || t == 'true';
}

double? leerMonto(String texto) {
  final t = texto.trim().replaceAll(',', '');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

DateTime soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

int diasDelMes(int anio, int mes) => DateTime(anio, mes + 1, 0).day;

DateTime sumarMeses(DateTime d, int meses) {
  final total = d.year * 12 + (d.month - 1) + meses;
  final anio = total ~/ 12;
  final mes = total % 12 + 1;
  final dia = d.day > diasDelMes(anio, mes) ? diasDelMes(anio, mes) : d.day;
  return DateTime(anio, mes, dia, d.hour, d.minute, d.second, d.millisecond);
}

int dividirRedondeoBancario(int centavosTotal, int partes) {
  final base = centavosTotal ~/ partes;
  final resto = centavosTotal - base * partes;
  final doble = resto * 2;
  if (doble > partes) return base + 1;
  if (doble < partes) return base;
  return base.isOdd ? base + 1 : base;
}
