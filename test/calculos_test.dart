import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inverfa_creditos/data/calculo.dart';
import 'package:inverfa_creditos/data/formato.dart';
import 'package:inverfa_creditos/data/repo.dart';

String _f(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  const casos = String.fromEnvironment('CASOS');

  test('plan de cuotas e interés idénticos al sistema viejo (C# decimal)', () {
    final lineas = File(casos).readAsLinesSync().where((l) => l.trim().isNotEmpty).toList();
    expect(lineas.length, 5000);
    var errores = 0;
    for (final l in lineas) {
      final p = l.split('|');
      final saldo = double.parse(p[0]);
      final n = int.parse(p[1]);
      final f = p[2];
      final ini = DateTime.parse(p[3]);
      final venc = Plan.fechaUltimoPago(ini, f, n);
      final plan = Plan.generar(saldo, n, f, ini).map((c) => '${_f(c.fecha)}=${plano2(c.monto)};').join();
      final calc = CalculoAbono.calcular(
        base: double.parse(p[6]),
        montoTotalCredito: 0,
        montoTexto: '0',
        aplicarInteres: true,
        porcentajeTexto: p[7],
        sobreMontoTotal: false,
      );
      final okVenc = _f(venc) == p[4];
      final okPlan = plan == p[5];
      final okInt = plano2(calc.interes) == p[8];
      if (!okVenc || !okPlan || !okInt) {
        errores++;
        if (errores < 5) {
          // ignore: avoid_print
          print('DIFERENCIA: $l\n  venc=${_f(venc)} plan=$plan int=${plano2(calc.interes)}');
        }
      }
    }
    expect(errores, 0);
  });

  test('formatos de moneda', () {
    expect(lempiras(1234567.5), 'L.1,234,567.50');
    expect(lempiras(0), 'L.0.00');
    expect(lempiras(-12.345), '-L.12.35');
    expect(numero2(999.995), '1,000.00');
    expect(plano2(10.1), '10.10');
  });

  test('sumar meses como DateTime.AddMonths de .NET', () {
    expect(_f(sumarMeses(DateTime(2026, 1, 31), 1)), '2026-02-28');
    expect(_f(sumarMeses(DateTime(2024, 1, 31), 1)), '2024-02-29');
    expect(_f(sumarMeses(DateTime(2026, 12, 31), 2)), '2027-02-28');
    expect(_f(sumarMeses(DateTime(2026, 3, 15), -3)), '2025-12-15');
  });

  test('montos con texto inválido no se aceptan', () {
    expect(decimalExacto(''), isNull);
    expect(decimalExacto('.'), isNull);
    expect(decimalExacto('1.2.3'), isNull);
    expect(decimalExacto('abc'), isNull);
    expect(decimalExacto('0'), isNotNull);
    expect(decimalExacto('.5'), isNotNull);
    expect(decimalExacto('5.'), isNotNull);
  });
}
