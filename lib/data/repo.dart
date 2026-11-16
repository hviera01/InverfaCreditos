import '../db/db.dart';
import '../db/sql.dart';
import 'formato.dart';
import 'modelos.dart';

class CuotaPlan {
  final int numero;
  final DateTime fecha;
  final double monto;
  CuotaPlan(this.numero, this.fecha, this.monto);
}

class Plan {
  static DateTime fechaUltimoPago(DateTime fechaInicio, String frecuencia, int numeroCuotas) {
    final inicio = soloFecha(fechaInicio);
    if (numeroCuotas <= 0) return inicio;
    switch (frecuencia.trim().toLowerCase()) {
      case 'semanal':
        return inicio.add(Duration(days: 7 * (numeroCuotas - 1)));
      case 'quincenal':
        return inicio.add(Duration(days: 15 * (numeroCuotas - 1)));
      default:
        return sumarMeses(inicio, numeroCuotas - 1);
    }
  }

  static double montoCuota(double saldo, int numeroCuotas) {
    if (numeroCuotas <= 0 || saldo <= 0) return 0;
    return deCentavos(dividirRedondeoBancario(centavos(saldo), numeroCuotas));
  }

  static List<CuotaPlan> generar(double saldoPendiente, int numeroCuotas, String frecuencia, DateTime fechaInicio) {
    if (numeroCuotas <= 0 || saldoPendiente <= 0) return const [];
    final f = frecuencia.trim().toLowerCase();
    final saldoC = centavos(saldoPendiente);
    final baseC = dividirRedondeoBancario(saldoC, numeroCuotas);
    var acumulado = 0;
    var fecha = soloFecha(fechaInicio);
    final res = <CuotaPlan>[];
    for (var n = 1; n <= numeroCuotas; n++) {
      if (n > 1) {
        switch (f) {
          case 'semanal':
            fecha = fecha.add(const Duration(days: 7));
            break;
          case 'quincenal':
            fecha = fecha.add(const Duration(days: 15));
            break;
          default:
            fecha = sumarMeses(fecha, 1);
        }
      }
      int montoC;
      if (n < numeroCuotas) {
        montoC = baseC;
        acumulado += baseC;
      } else {
        montoC = saldoC - acumulado;
        if (montoC < 0) montoC = 0;
      }
      res.add(CuotaPlan(n, fecha, deCentavos(montoC)));
    }
    return res;
  }
}

class NuevoCredito {
  final int? idClienteExistente;
  final Cliente cliente;
  final String numeroDocumento;
  final double montoTotal;
  final double saldoPendiente;
  final DateTime fechaVencimiento;
  final DateTime fechaRegistro;
  final String descripcion;
  final int numeroCuotas;
  final String frecuencia;
  final DateTime fechaInicio;
  NuevoCredito({
    required this.idClienteExistente,
    required this.cliente,
    required this.numeroDocumento,
    required this.montoTotal,
    required this.saldoPendiente,
    required this.fechaVencimiento,
    required this.fechaRegistro,
    required this.descripcion,
    required this.numeroCuotas,
    required this.frecuencia,
    required this.fechaInicio,
  });
}

class Repo {
  static Future<Usuario?> login(String documento, String clave) async {
    final t = await Db.consulta('''
SET NOCOUNT ON;
SELECT u.IdUsuario, u.Documento, u.NombreCompleto, u.Clave, r.IdRol, r.Descripcion
FROM USUARIO u INNER JOIN ROL r ON r.IdRol = u.IdRol
WHERE u.Documento = ${sqlTexto(documento)}''');
    for (final f in t.filas) {
      if ((f[3] ?? '') == clave && (f[1] ?? '') == documento) {
        final id = parseEntero(f[0]);
        final p = await Db.consulta('''
SET NOCOUNT ON;
SELECT p.NombreMenu FROM PERMISO p
INNER JOIN ROL r ON r.IdRol = p.IdRol
INNER JOIN USUARIO u ON u.IdRol = r.IdRol
WHERE u.IdUsuario = $id''');
        return Usuario(
          id: id,
          documento: f[1] ?? '',
          nombre: f[2] ?? '',
          idRol: parseEntero(f[4]),
          rol: f[5] ?? '',
          permisos: {for (final x in p.filas) (x[0] ?? '').trim().toLowerCase()},
        );
      }
    }
    return null;
  }

  static Future<List<CreditoResumen>> listarCreditos() async {
    final t = await Db.consulta('SET NOCOUNT ON; EXEC dbo.sp_Venta_ObtenerFacturasCredito;');
    final iId = t.indice('IdVenta'),
        iFr = t.indice('FechaRegistro'),
        iNd = t.indice('NumeroDocumento'),
        iCod = t.indice('CodCliente'),
        iNom = t.indice('NombreCliente'),
        iMt = t.indice('MontoTotal'),
        iSp = t.indice('SaldoPendiente'),
        iFv = t.indice('FechaVencimiento'),
        iEs = t.indice('Estado'),
        iVe = t.indice('Vencida'),
        iDe = t.indice('Descripcion'),
        iNc = t.indice('NumeroCuotas'),
        iPp = t.indice('ProximoPago'),
        iMo = t.indice('Mora');
    final lista = <CreditoResumen>[
      for (final f in t.filas)
        CreditoResumen(
          idVenta: parseEntero(f[iId]),
          fechaRegistro: parseFecha(f[iFr]),
          numeroDocumento: (f[iNd] ?? '').trim().isEmpty ? 'S/N' : f[iNd]!,
          codCliente: parseEntero(f[iCod]),
          nombreCliente: (f[iNom] ?? '').trim().isEmpty ? 'N/A' : f[iNom]!,
          montoTotal: parseDecimal(f[iMt]),
          saldoPendiente: parseDecimal(f[iSp]),
          fechaVencimiento: parseFecha(f[iFv]),
          estado: f[iEs] ?? '',
          vencida: f[iVe] ?? '',
          descripcion: (f[iDe] ?? '').trim().isEmpty ? 'N/A' : f[iDe]!,
          numeroCuotas: parseEntero(f[iNc]),
          proximoPago: parseFecha(f[iPp]),
          mora: (f[iMo] ?? '').trim().isEmpty ? 'No' : f[iMo]!,
        ),
    ];
    final orden = <CreditoResumen, int>{for (var i = 0; i < lista.length; i++) lista[i]: i};
    lista.sort((a, b) {
      final fa = a.proximoPago, fb = b.proximoPago;
      if (fa == null && fb == null) return orden[a]!.compareTo(orden[b]!);
      if (fa == null) return 1;
      if (fb == null) return -1;
      final c = soloFecha(fa).compareTo(soloFecha(fb));
      return c != 0 ? c : orden[a]!.compareTo(orden[b]!);
    });
    return lista;
  }

  static Future<DetalleCredito> detalleCredito(int idVenta) async {
    final r = await Db.ejecutar('''
SET NOCOUNT ON;
EXEC dbo.sp_CuotaCredito_ObtenerPorVenta @IdVenta = $idVenta;
EXEC dbo.sp_CuotaCredito_ObtenerResumen @IdVenta = $idVenta;
SELECT IdAbono, FechaAbono, MontoAbono, NuevoSaldoPendiente, ISNULL(InteresAplicado, 0) AS InteresAplicado,
       MetodoPago, NoRecibo, ISNULL(SaldoAnterior, 0) AS SaldoAnterior
FROM Abonos WHERE IdVenta = $idVenta ORDER BY FechaAbono ASC, IdAbono ASC;
SELECT ac.IdAbono, ac.IdCuota, ac.MontoAplicado, c.NumeroCuota, c.MontoCuota
FROM dbo.AbonoCuota ac
INNER JOIN dbo.CUOTA_CREDITO c ON c.IdCuota = ac.IdCuota
INNER JOIN dbo.Abonos a ON a.IdAbono = ac.IdAbono
WHERE a.IdVenta = $idVenta
ORDER BY ac.IdAbonoCuota;''');
    final tc = r[0], tr = r[1], ta = r[2], td = r[3];
    final cuotas = [
      for (final f in tc.filas)
        Cuota(
          idCuota: parseEntero(f[tc.indice('IdCuota')]),
          numeroCuota: parseEntero(f[tc.indice('NumeroCuota')]),
          fechaPago: parseFecha(f[tc.indice('FechaPago')]) ?? DateTime(2000),
          montoCuota: parseDecimal(f[tc.indice('MontoCuota')]),
          montoPagado: parseDecimal(f[tc.indice('MontoPagado')]),
          estado: f[tc.indice('Estado')] ?? '',
        ),
    ]..sort((a, b) => a.numeroCuota.compareTo(b.numeroCuota));
    ResumenCuotas resumen;
    if (tr.filas.isNotEmpty) {
      final f = tr.filas.first;
      resumen = ResumenCuotas(
        numeroCuotas: parseEntero(f[tr.indice('NumeroCuotas')]),
        cuotaActual: parseEntero(f[tr.indice('CuotaActual')]),
        proximoPago: parseFecha(f[tr.indice('ProximoPago')]),
        montoCuota: parseDecimal(f[tr.indice('MontoCuota')]),
        enMora: parseEntero(f[tr.indice('EnMora')]) == 1,
      );
    } else {
      resumen = ResumenCuotas(numeroCuotas: 0, cuotaActual: 0, proximoPago: null, montoCuota: 0, enMora: false);
    }
    final detalles = <int, List<DetalleAbonoCuota>>{};
    for (final f in td.filas) {
      final d = DetalleAbonoCuota(
        idAbono: parseEntero(f[0]),
        idCuota: parseEntero(f[1]),
        montoAplicado: parseDecimal(f[2]),
        numeroCuota: parseEntero(f[3]),
        montoCuota: parseDecimal(f[4]),
      );
      detalles.putIfAbsent(d.idAbono, () => []).add(d);
    }
    final abonos = [
      for (final f in ta.filas)
        Abono(
          idAbono: parseEntero(f[0]),
          fechaAbono: parseFecha(f[1]) ?? DateTime(2000),
          montoAbono: parseDecimal(f[2]),
          nuevoSaldoPendiente: parseDecimal(f[3]),
          interesAplicado: parseDecimal(f[4]),
          metodoPago: f[5],
          noRecibo: f[6],
          saldoAnterior: parseDecimal(f[7]),
          detalle: detalles[parseEntero(f[0])] ?? const [],
        ),
    ];
    return DetalleCredito(cuotas, resumen, abonos);
  }

  static String _recalculo(int idVenta) =>
      '''
  DECLARE @IdVentaR INT = $idVenta;
  DECLARE @c TABLE (IdCuota INT PRIMARY KEY, NumeroCuota INT, MontoCuota DECIMAL(18,2), Pagado DECIMAL(18,2));
  INSERT @c (IdCuota, NumeroCuota, MontoCuota, Pagado)
    SELECT IdCuota, NumeroCuota, MontoCuota, 0 FROM dbo.CUOTA_CREDITO WHERE IdVenta = @IdVentaR;
  DELETE ac FROM dbo.AbonoCuota ac INNER JOIN dbo.Abonos a ON a.IdAbono = ac.IdAbono WHERE a.IdVenta = @IdVentaR;
  DECLARE @det TABLE (Orden INT IDENTITY(1,1), IdAbono INT, IdCuota INT, Monto DECIMAL(18,2));
  DECLARE @IdAb INT, @Restante DECIMAL(18,2), @IdCu INT, @SaldoCu DECIMAL(18,2), @Aplicar DECIMAL(18,2);
  DECLARE curAbonos CURSOR LOCAL FAST_FORWARD FOR
    SELECT IdAbono, MontoAbono FROM dbo.Abonos WHERE IdVenta = @IdVentaR ORDER BY FechaAbono ASC, IdAbono ASC;
  OPEN curAbonos;
  FETCH NEXT FROM curAbonos INTO @IdAb, @Restante;
  WHILE @@FETCH_STATUS = 0
  BEGIN
    WHILE @Restante > 0
    BEGIN
      SET @IdCu = NULL;
      SELECT TOP 1 @IdCu = IdCuota, @SaldoCu = MontoCuota - Pagado FROM @c WHERE MontoCuota - Pagado > 0 ORDER BY NumeroCuota, IdCuota;
      IF @IdCu IS NULL BREAK;
      SET @Aplicar = CASE WHEN @SaldoCu < @Restante THEN @SaldoCu ELSE @Restante END;
      INSERT @det (IdAbono, IdCuota, Monto) VALUES (@IdAb, @IdCu, @Aplicar);
      UPDATE @c SET Pagado = Pagado + @Aplicar WHERE IdCuota = @IdCu;
      SET @Restante = @Restante - @Aplicar;
    END
    FETCH NEXT FROM curAbonos INTO @IdAb, @Restante;
  END
  CLOSE curAbonos;
  DEALLOCATE curAbonos;
  INSERT dbo.AbonoCuota (IdAbono, IdCuota, MontoAplicado) SELECT IdAbono, IdCuota, Monto FROM @det ORDER BY Orden;
  UPDATE cc SET MontoPagado = c.Pagado,
    Estado = CASE WHEN c.Pagado > 0 AND c.Pagado >= c.MontoCuota THEN 'Pagada' WHEN c.Pagado > 0 THEN 'Parcial' ELSE 'Pendiente' END
  FROM dbo.CUOTA_CREDITO cc INNER JOIN @c c ON c.IdCuota = cc.IdCuota;
  DECLARE @SaldoR DECIMAL(18,2) =
      ISNULL((SELECT SUM(MontoCuota) FROM @c), 0)
    - ISNULL((SELECT SUM(MontoAbono) FROM dbo.Abonos WHERE IdVenta = @IdVentaR), 0)
    + ISNULL((SELECT SUM(ISNULL(InteresAplicado, 0)) FROM dbo.Abonos WHERE IdVenta = @IdVentaR), 0);
  IF @SaldoR < 0 SET @SaldoR = 0;
  UPDATE dbo.VENTA SET SaldoPendiente = @SaldoR WHERE IdVenta = @IdVentaR;
''';

  static Future<void> guardarAbono({
    required int idVenta,
    int? idAbono,
    required double monto,
    required DateTime fecha,
    required double nuevoSaldo,
    required double interes,
    required String metodoPago,
    required String recibo,
    required double saldoAnterior,
  }) async {
    final f = sqlFechaHora(soloFecha(fecha));
    final escritura = idAbono == null
        ? '''
  INSERT INTO dbo.Abonos (IdVenta, MontoAbono, FechaAbono, NuevoSaldoPendiente, InteresAplicado, MetodoPago, FechaUltimoInteres, NoRecibo, SaldoAnterior)
  VALUES ($idVenta, ${sqlDecimal(monto)}, $f, ${sqlDecimal(nuevoSaldo)}, ${sqlDecimal(interes)}, ${sqlTexto(metodoPago)}, NULL, ${sqlTexto(recibo)}, ${sqlDecimal(saldoAnterior)});
'''
        : '''
  UPDATE dbo.Abonos SET MontoAbono = ${sqlDecimal(monto)}, FechaAbono = $f, NuevoSaldoPendiente = ${sqlDecimal(nuevoSaldo)},
    InteresAplicado = ${sqlDecimal(interes)}, MetodoPago = ${sqlTexto(metodoPago)}, FechaUltimoInteres = NULL, NoRecibo = ${sqlTexto(recibo)}
  WHERE IdAbono = $idAbono AND IdVenta = $idVenta;
  IF @@ROWCOUNT = 0 THROW 50001, 'El abono ya no existe.', 1;
''';
    await Db.ejecutar(transaccion(escritura + _recalculo(idVenta)));
  }

  static Future<void> eliminarAbono(int idVenta, int idAbono) async {
    await Db.ejecutar(
      transaccion('''
  DELETE FROM dbo.AbonoCuota WHERE IdAbono = $idAbono;
  DELETE FROM dbo.Abonos WHERE IdAbono = $idAbono AND IdVenta = $idVenta;
${_recalculo(idVenta)}'''),
    );
  }

  static String _sqlRegistrarCliente(Cliente c, String varRes, String varMsg, String varCod) =>
      '''
  DECLARE $varRes INT, $varMsg VARCHAR(500), $varCod INT = ${sqlEntero(c.codCliente)};
  EXEC dbo.sp_RegistrarCliente
    @Documento = ${sqlTexto(c.documento)},
    @NombreCompleto = ${sqlTexto(c.nombreCompleto)},
    @Correo = ${sqlTexto(c.correo)},
    @Telefono = ${sqlTexto(c.telefono)},
    @Direccion = ${sqlTexto(c.direccion)},
    @Estado = ${c.estado ? 1 : 0},
    @Resultado = $varRes OUTPUT,
    @Mensaje = $varMsg OUTPUT,
    @CodCliente = $varCod OUTPUT;
''';

  static Future<ResultadoOperacion> registrarCredito(NuevoCredito n) async {
    final b = StringBuffer();
    if (n.idClienteExistente == null) {
      b.write(_sqlRegistrarCliente(n.cliente, '@ResCli', '@MsgCli', '@CodCli'));
      b.write('''
  IF ISNULL(@ResCli, 0) = 0
  BEGIN
    ROLLBACK TRAN;
    SELECT 0 AS Ok, 'Error al registrar el cliente: ' + ISNULL(@MsgCli, '') AS Mensaje, 0 AS IdVenta, 0 AS Cod;
    RETURN;
  END
''');
    } else {
      b.write('  DECLARE @CodCli INT = 0;\n');
    }
    final numDoc = n.numeroDocumento.trim().isEmpty ? 'N/A' : n.numeroDocumento;
    b.write('''
  DECLARE @rc INT;
  EXEC @rc = dbo.sp_RegistrarVentaCredito
    @NumeroDocumento = ${sqlTexto(numDoc)},
    @DocumentoCliente = ${sqlTexto(n.cliente.documento.trim().isEmpty ? 'N/A' : n.cliente.documento)},
    @NombreCliente = ${sqlTexto(n.cliente.nombreCompleto.trim().isEmpty ? 'N/A' : n.cliente.nombreCompleto)},
    @MontoTotal = ${sqlDecimal(n.montoTotal)},
    @SaldoPendiente = ${sqlDecimal(n.saldoPendiente)},
    @FechaVencimiento = ${sqlFechaHora(soloFecha(n.fechaVencimiento))},
    @MetodoPago = N'N/A',
    @Condicion = N'Credito',
    @FechaRegistro = ${sqlFechaHora(n.fechaRegistro)},
    @TipoDocumento = N'Factura',
    @Descripcion = ${sqlTexto(n.descripcion.trim().isEmpty ? 'N/A' : n.descripcion)};
  IF ISNULL(@rc, 0) <> 0 THROW 50002, 'El procedimiento de registro de crédito devolvió un error.', 1;
  DECLARE @IdVenta INT = (SELECT TOP 1 IdVenta FROM dbo.VENTA WHERE NumeroDocumento = ${sqlTexto(numDoc)} ORDER BY IdVenta DESC);
''');
    for (final c in Plan.generar(n.saldoPendiente, n.numeroCuotas, n.frecuencia, n.fechaInicio)) {
      b.write(
        "  INSERT INTO dbo.CUOTA_CREDITO (IdVenta, NumeroCuota, FechaPago, MontoCuota, MontoPagado, Estado) VALUES (@IdVenta, ${c.numero}, ${sqlFecha(c.fecha)}, ${sqlDecimal(c.monto)}, 0, 'Pendiente');\n",
      );
    }
    b.write("  COMMIT TRAN;\n  SELECT 1 AS Ok, 'OK' AS Mensaje, @IdVenta AS IdVenta, @CodCli AS Cod;\n");
    final r = await Db.ejecutar(transaccion(b.toString()));
    final t = r.isNotEmpty ? r.last : null;
    if (t == null || t.filas.isEmpty) return ResultadoOperacion(false, 'No se obtuvo respuesta de la base de datos.');
    final f = t.filas.first;
    return ResultadoOperacion(parseEntero(f[0]) == 1, f[1] ?? '', id: parseEntero(f[2]), codigo: parseEntero(f[3]));
  }

  static Future<void> eliminarCredito(int idVenta) async {
    await Db.ejecutar('SET NOCOUNT ON; EXEC dbo.sp_Venta_EliminarCreditoCompleto @IdVenta = $idVenta;');
  }

  static Future<List<Cliente>> listarClientes() async {
    final t = await Db.consulta('''
SET NOCOUNT ON;
SELECT IdCliente, CodCliente, Documento, NombreCompleto, Correo, Telefono, Direccion, ISNULL(Estado, 0) AS Estado
FROM CLIENTE ORDER BY IdCliente''');
    return [
      for (final f in t.filas)
        Cliente(
          idCliente: parseEntero(f[0]),
          codCliente: parseEntero(f[1]),
          documento: f[2] ?? '',
          nombreCompleto: f[3] ?? '',
          correo: f[4] ?? '',
          telefono: f[5] ?? '',
          direccion: f[6] ?? '',
          estado: parseBit(f[7]),
        ),
    ];
  }

  static Future<ResultadoOperacion> registrarCliente(Cliente c) async {
    final r = await Db.ejecutar('SET NOCOUNT ON;\n${_sqlRegistrarCliente(c, '@Res', '@Msg', '@Cod')}SELECT @Res, @Msg, @Cod;');
    final f = r.last.filas.first;
    final id = parseEntero(f[0]);
    return ResultadoOperacion(id != 0, f[1] ?? '', id: id, codigo: parseEntero(f[2]));
  }

  static Future<ResultadoOperacion> editarCliente(Cliente c) async {
    final r = await Db.ejecutar('''
SET NOCOUNT ON;
DECLARE @Res INT, @Msg VARCHAR(500);
EXEC dbo.sp_ModificarCliente
  @IdCliente = ${c.idCliente},
  @Documento = ${sqlTexto(c.documento)},
  @NombreCompleto = ${sqlTexto(c.nombreCompleto)},
  @Correo = ${sqlTexto(c.correo)},
  @Telefono = ${sqlTexto(c.telefono)},
  @Direccion = ${sqlTexto(c.direccion)},
  @Estado = ${c.estado ? 1 : 0},
  @CodCliente = ${c.codCliente},
  @Resultado = @Res OUTPUT,
  @Mensaje = @Msg OUTPUT;
SELECT @Res, @Msg;''');
    final f = r.last.filas.first;
    return ResultadoOperacion(parseEntero(f[0]) == 1, f[1] ?? '');
  }

  static Future<bool> eliminarCliente(int idCliente) async {
    final t = await Db.consulta('SET NOCOUNT ON; DELETE FROM CLIENTE WHERE IdCliente = $idCliente; SELECT @@ROWCOUNT;');
    return t.filas.isNotEmpty && parseEntero(t.filas.first[0]) > 0;
  }
}
