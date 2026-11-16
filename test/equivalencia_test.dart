import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inverfa_creditos/data/calculo.dart';
import 'package:inverfa_creditos/data/formato.dart';
import 'package:inverfa_creditos/data/modelos.dart';
import 'package:inverfa_creditos/data/repo.dart';
import 'package:inverfa_creditos/db/db.dart';

void main() {
  const escenario = String.fromEnvironment('ESCENARIO');
  const salida = String.fromEnvironment('SALIDA');

  test('escenario de equivalencia', () async {
    expect(Db.config.base, isNot('DB_INVERFA'));
    final ops = (jsonDecode(File(escenario).readAsStringSync()) as List).cast<Map<String, dynamic>>();
    final ventas = <String, int>{};
    final abonos = <String, int>{};
    final clientes = <String, int>{};
    final log = StringBuffer();
    int venta(dynamic v) => v is int ? v : ventas[v as String]!;

    Future<Abono> abonoRef(int idVenta, Map<String, dynamic> op) async {
      final d = await Repo.detalleCredito(idVenta);
      if (op.containsKey('abono')) return d.abonos.firstWhere((a) => a.idAbono == abonos[op['abono']]);
      return d.abonos[op['abonoIndex'] as int];
    }

    Future<String> estado(int idVenta) async => (await Repo.listarCreditos()).firstWhere((c) => c.idVenta == idVenta).estado;
    Future<double> montoTotal(int idVenta) async => (await Repo.listarCreditos()).firstWhere((c) => c.idVenta == idVenta).montoTotal;

    var n = 0;
    for (final op in ops) {
      n++;
      final tipo = op['op'] as String;
      try {
        if (tipo == 'credito') {
          Cliente cliente;
          int? idExistente;
          if (op.containsKey('idCliente')) {
            final c = (await Repo.listarClientes()).firstWhere((x) => x.idCliente == op['idCliente']);
            idExistente = c.idCliente;
            cliente = Cliente(
              idCliente: c.idCliente,
              codCliente: c.codCliente,
              documento: c.documento.trim().isEmpty ? 'N/A' : c.documento.trim(),
              nombreCompleto: c.nombreCompleto.trim(),
            );
          } else {
            final d = op['cliente'] as Map<String, dynamic>;
            cliente = Cliente(
              codCliente: int.tryParse((d['cod'] as String).trim()) ?? 0,
              documento: (d['doc'] as String).trim().isEmpty ? 'N/A' : (d['doc'] as String).trim(),
              nombreCompleto: (d['nombre'] as String).trim(),
              correo: (d['prof'] as String).trim(),
              telefono: (d['tel'] as String).trim(),
              direccion: (d['dir'] as String).trim(),
            );
          }
          final monto = leerMonto(op['monto'] as String)!;
          final prima = (op['prima'] as String).trim().isEmpty ? 0.0 : leerMonto(op['prima'] as String)!;
          final cuotas = op['cuotas'] as int;
          final inicio = DateTime.parse(op['inicio'] as String);
          final r = await Repo.registrarCredito(
            NuevoCredito(
              idClienteExistente: idExistente,
              cliente: cliente,
              numeroDocumento: (op['factura'] as String).trim().isEmpty ? 'N/A' : (op['factura'] as String).trim(),
              montoTotal: r2(monto),
              saldoPendiente: r2(monto - prima),
              fechaVencimiento: Plan.fechaUltimoPago(inicio, op['frecuencia'] as String, cuotas),
              fechaRegistro: DateTime.now(),
              descripcion: (op['descripcion'] as String).trim().isEmpty ? 'N/A' : (op['descripcion'] as String).trim(),
              numeroCuotas: cuotas,
              frecuencia: op['frecuencia'] as String,
              fechaInicio: inicio,
            ),
          );
          if (!r.ok) throw Exception(r.mensaje);
          ventas[op['label'] as String] = r.id;
          log.writeln('credito ${op['label']} OK ${r.id}');
        } else if (tipo == 'abono' || tipo == 'editar') {
          final idVenta = venta(op['venta']);
          final det = await Repo.detalleCredito(idVenta);
          Abono? editando;
          if (tipo == 'editar') editando = await abonoRef(idVenta, op);
          if (await estado(idVenta) == 'Liquidada') {
            log.writeln('$n RECHAZADO liquidada');
            continue;
          }
          final base = editando?.saldoAnterior ?? CalculoAbono.saldoActual(det);
          final interes = op['interes'] as Map<String, dynamic>?;
          final calc = CalculoAbono.calcular(
            base: base,
            montoTotalCredito: await montoTotal(idVenta),
            montoTexto: op['monto'] as String,
            aplicarInteres: interes != null,
            porcentajeTexto: interes?['pct'] as String? ?? '',
            sobreMontoTotal: interes?['a'] == 'Monto Total',
          );
          if (calc.montoCent > calc.baseCent) {
            log.writeln('$n RECHAZADO mayor');
            continue;
          }
          final reciboOp = op['recibo'] as String?;
          var recibo = reciboOp ?? (editando == null || (editando.noRecibo ?? '').trim().isEmpty ? 'N/A' : editando.noRecibo!);
          if (recibo.trim().isEmpty) recibo = 'N/A';
          final fecha = op['fecha'] == null ? soloFecha(editando!.fechaAbono) : DateTime.parse(op['fecha'] as String);
          final metodo = op['metodo'] as String? ?? editando?.metodoPago ?? 'Efectivo';
          await Repo.guardarAbono(
            idVenta: idVenta,
            idAbono: editando?.idAbono,
            monto: calc.monto,
            fecha: fecha,
            nuevoSaldo: calc.nuevoSaldoGuardado,
            interes: calc.interes,
            metodoPago: metodo,
            recibo: recibo,
            saldoAnterior: calc.base,
          );
          if (tipo == 'abono') {
            final d2 = await Repo.detalleCredito(idVenta);
            abonos[op['label'] as String] = d2.abonos.map((a) => a.idAbono).reduce((a, b) => a > b ? a : b);
          }
          log.writeln('$n OK $tipo');
        } else if (tipo == 'eliminar') {
          final idVenta = venta(op['venta']);
          final a = await abonoRef(idVenta, op);
          await Repo.eliminarAbono(idVenta, a.idAbono);
          log.writeln('$n OK eliminar');
        } else if (tipo == 'eliminarCredito') {
          await Repo.eliminarCredito(venta(op['venta']));
          log.writeln('$n OK eliminarCredito');
        } else if (tipo == 'cliente') {
          final accion = op['accion'] as String;
          final c = Cliente(
            codCliente: int.tryParse((op['cod'] as String? ?? '').trim()) ?? 0,
            documento: op['doc'] as String? ?? '',
            nombreCompleto: op['nombre'] as String? ?? '',
            correo: op['prof'] as String? ?? '',
            telefono: op['tel'] as String? ?? '',
            direccion: op['dir'] as String? ?? '',
            estado: op['activo'] as bool? ?? true,
          );
          if (accion == 'registrar') {
            final r = await Repo.registrarCliente(c);
            if (r.ok) clientes[op['label'] as String] = r.id;
            log.writeln('$n ${r.ok ? 'OK' : 'FALLO'} ${r.mensaje}');
          } else if (accion == 'editar') {
            c.idCliente = clientes[op['ref']]!;
            final r = await Repo.editarCliente(c);
            log.writeln('$n ${r.ok ? 'OK' : 'FALLO'} ${r.mensaje}');
          } else {
            final ok = await Repo.eliminarCliente(clientes[op['ref']]!);
            log.writeln('$n ${ok ? 'OK eliminado' : 'FALLO'}');
          }
        }
      } on OdbcError catch (e) {
        log.writeln('$n ERROR ${e.mensaje}');
      } catch (e) {
        log.writeln('$n ERROR $e');
      }
    }
    File(salida).writeAsStringSync(log.toString());
  }, timeout: const Timeout(Duration(minutes: 10)));
}
