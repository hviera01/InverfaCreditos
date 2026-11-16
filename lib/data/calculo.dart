import 'formato.dart';
import 'modelos.dart';

int dividirRedondeando(BigInt n, BigInt d) {
  final neg = n.isNegative != d.isNegative && n != BigInt.zero;
  final a = n.abs(), b = d.abs();
  var q = a ~/ b;
  if ((a - q * b) * BigInt.two >= b) q += BigInt.one;
  return (neg ? -q : q).toInt();
}

(BigInt, BigInt)? decimalExacto(String texto) {
  final t = texto.trim().replaceAll(',', '');
  if (t.isEmpty || t == '.' || !RegExp(r'^\d*\.?\d*$').hasMatch(t)) return null;
  final partes = t.split('.');
  final entero = partes[0].isEmpty ? '0' : partes[0];
  final dec = partes.length > 1 ? partes[1] : '';
  return (BigInt.parse('$entero$dec'), BigInt.from(10).pow(dec.length));
}

class CalculoAbono {
  final int baseCent;
  final int montoCent;
  final int interesCent;
  CalculoAbono(this.baseCent, this.montoCent, this.interesCent);

  double get base => deCentavos(baseCent);
  double get monto => deCentavos(montoCent);
  double get interes => deCentavos(interesCent);
  double get nuevoSaldoMostrado => deCentavos(baseCent - montoCent);
  double get totalConInteres => deCentavos(baseCent - montoCent + interesCent);
  double get nuevoSaldoGuardado => deCentavos(baseCent - montoCent + interesCent);

  static double saldoActual(DetalleCredito d) {
    final c =
        d.cuotas.fold<int>(0, (a, x) => a + centavos(x.montoCuota)) -
        d.abonos.fold<int>(0, (a, x) => a + centavos(x.montoAbono)) +
        d.abonos.fold<int>(0, (a, x) => a + centavos(x.interesAplicado));
    return deCentavos(c < 0 ? 0 : c);
  }

  static double prima(double montoTotal, DetalleCredito d) {
    final c = centavos(montoTotal) - d.cuotas.fold<int>(0, (a, x) => a + centavos(x.montoCuota));
    return deCentavos(c < 0 ? 0 : c);
  }

  static CalculoAbono calcular({
    required double base,
    required double montoTotalCredito,
    required String montoTexto,
    required bool aplicarInteres,
    required String porcentajeTexto,
    required bool sobreMontoTotal,
  }) {
    final baseCent = centavos(base);
    final m = decimalExacto(montoTexto);
    final montoCent = m == null ? 0 : dividirRedondeando(m.$1 * BigInt.from(100), m.$2);
    var interesCent = 0;
    if (aplicarInteres) {
      final p = decimalExacto(porcentajeTexto);
      if (p != null) {
        final sobre = BigInt.from(sobreMontoTotal ? centavos(montoTotalCredito) : baseCent);
        interesCent = dividirRedondeando(sobre * p.$1, BigInt.from(100) * p.$2);
      }
    }
    return CalculoAbono(baseCent, montoCent, interesCent);
  }
}
