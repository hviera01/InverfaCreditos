class Usuario {
  final int id;
  final String documento;
  final String nombre;
  final int idRol;
  final String rol;
  final Set<String> permisos;
  Usuario({required this.id, required this.documento, required this.nombre, required this.idRol, required this.rol, required this.permisos});

  bool puede(String menu) => permisos.contains(menu.toLowerCase());
}

class CreditoResumen {
  final int idVenta;
  final DateTime? fechaRegistro;
  final String numeroDocumento;
  final int codCliente;
  final String nombreCliente;
  final double montoTotal;
  final double saldoPendiente;
  final DateTime? fechaVencimiento;
  final String estado;
  final String vencida;
  final String descripcion;
  final int numeroCuotas;
  final DateTime? proximoPago;
  final String mora;

  CreditoResumen({
    required this.idVenta,
    required this.fechaRegistro,
    required this.numeroDocumento,
    required this.codCliente,
    required this.nombreCliente,
    required this.montoTotal,
    required this.saldoPendiente,
    required this.fechaVencimiento,
    required this.estado,
    required this.vencida,
    required this.descripcion,
    required this.numeroCuotas,
    required this.proximoPago,
    required this.mora,
  });

  bool get enMora => mora.trim().toLowerCase() == 'si' || mora.trim().toLowerCase() == 'sí';
}

class Cuota {
  final int idCuota;
  final int numeroCuota;
  final DateTime fechaPago;
  final double montoCuota;
  final double montoPagado;
  final String estado;
  Cuota({
    required this.idCuota,
    required this.numeroCuota,
    required this.fechaPago,
    required this.montoCuota,
    required this.montoPagado,
    required this.estado,
  });
}

class ResumenCuotas {
  final int numeroCuotas;
  final int cuotaActual;
  final DateTime? proximoPago;
  final double montoCuota;
  final bool enMora;
  ResumenCuotas({required this.numeroCuotas, required this.cuotaActual, required this.proximoPago, required this.montoCuota, required this.enMora});
}

class DetalleAbonoCuota {
  final int idAbono;
  final int idCuota;
  final double montoAplicado;
  final int numeroCuota;
  final double montoCuota;
  DetalleAbonoCuota({required this.idAbono, required this.idCuota, required this.montoAplicado, required this.numeroCuota, required this.montoCuota});
}

class Abono {
  final int idAbono;
  final DateTime fechaAbono;
  final double montoAbono;
  final double nuevoSaldoPendiente;
  final double interesAplicado;
  final String? metodoPago;
  final String? noRecibo;
  final double saldoAnterior;
  final List<DetalleAbonoCuota> detalle;
  Abono({
    required this.idAbono,
    required this.fechaAbono,
    required this.montoAbono,
    required this.nuevoSaldoPendiente,
    required this.interesAplicado,
    required this.metodoPago,
    required this.noRecibo,
    required this.saldoAnterior,
    required this.detalle,
  });

  String get cuotasTexto =>
      detalle.map((d) => d.montoAplicado >= d.montoCuota ? 'Cuota ${d.numeroCuota} completa' : 'Cuota ${d.numeroCuota} parcial').join(', ');
}

class DetalleCredito {
  final List<Cuota> cuotas;
  final ResumenCuotas resumen;
  final List<Abono> abonos;
  DetalleCredito(this.cuotas, this.resumen, this.abonos);

  double get totalCuotas => cuotas.fold(0, (a, c) => a + c.montoCuota);
  double get totalPagadoCuotas => cuotas.fold(0, (a, c) => a + c.montoPagado);
  double get sumaAbonos => abonos.fold(0, (a, x) => a + x.montoAbono);
  double get sumaInteres => abonos.fold(0, (a, x) => a + x.interesAplicado);
}

class Cliente {
  int idCliente;
  int codCliente;
  String documento;
  String nombreCompleto;
  String correo;
  String telefono;
  String direccion;
  bool estado;
  Cliente({
    this.idCliente = 0,
    this.codCliente = 0,
    this.documento = '',
    this.nombreCompleto = '',
    this.correo = '',
    this.telefono = '',
    this.direccion = '',
    this.estado = true,
  });
}

class ResultadoOperacion {
  final bool ok;
  final String mensaje;
  final int id;
  final int codigo;
  ResultadoOperacion(this.ok, this.mensaje, {this.id = 0, this.codigo = 0});
}
