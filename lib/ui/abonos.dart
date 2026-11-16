import 'package:flutter/material.dart';

import '../data/calculo.dart';
import '../data/formato.dart';
import '../data/modelos.dart';
import '../data/repo.dart';
import '../db/db.dart';
import 'tema.dart';
import 'widgets.dart';

class DialogoAbonos extends StatefulWidget {
  final CreditoResumen credito;
  const DialogoAbonos({super.key, required this.credito});
  @override
  State<DialogoAbonos> createState() => _DialogoAbonosState();
}

class _DialogoAbonosState extends State<DialogoAbonos> {
  DetalleCredito? _det;
  String? _error;
  bool _guardando = false;
  bool _huboCambios = false;
  late String _estado = widget.credito.estado;

  double _saldoActual = 0;
  double _prima = 0;

  DateTime _fechaAbono = soloFecha(DateTime.now());
  final _monto = TextEditingController();
  final _recibo = TextEditingController();
  final _porcentaje = TextEditingController();
  final _focusMonto = FocusNode();
  String _metodo = 'Efectivo';
  String _aplicarInteres = 'No';
  String _interesA = 'Saldo Pendiente';

  Abono? _editando;
  int? _selHistorial;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _monto.dispose();
    _recibo.dispose();
    _porcentaje.dispose();
    _focusMonto.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final d = await Repo.detalleCredito(widget.credito.idVenta);
      if (!mounted) return;
      setState(() {
        _det = d;
        _prima = CalculoAbono.prima(widget.credito.montoTotal, d);
        _saldoActual = CalculoAbono.saldoActual(d);
        _error = null;
        if (_huboCambios) _estado = _saldoActual > 0 ? 'Debe' : 'Liquidada';
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusMonto.requestFocus());
    } on OdbcError catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    }
  }

  bool get _conInteres => _aplicarInteres == 'Sí';

  double get _base => _editando != null ? _editando!.saldoAnterior : _saldoActual;

  CalculoAbono get _calc => CalculoAbono.calcular(
    base: _base,
    montoTotalCredito: widget.credito.montoTotal,
    montoTexto: _monto.text,
    aplicarInteres: _conInteres,
    porcentajeTexto: _porcentaje.text,
    sobreMontoTotal: _interesA == 'Monto Total',
  );

  void _limpiar() {
    _monto.clear();
    _recibo.clear();
    _porcentaje.clear();
    _metodo = 'Efectivo';
    _fechaAbono = soloFecha(DateTime.now());
    _editando = null;
    _selHistorial = null;
    _focusMonto.requestFocus();
  }

  void _editar(int i) {
    final a = _det!.abonos[i];
    setState(() {
      _selHistorial = i;
      _editando = a;
      _fechaAbono = soloFecha(a.fechaAbono);
      _monto.text = plano2(a.montoAbono);
      final m = a.metodoPago ?? 'Efectivo';
      _metodo = const ['Efectivo', 'Tarjeta', 'Transferencia'].contains(m) ? m : _metodo;
      _recibo.text = (a.noRecibo == null || a.noRecibo!.trim().isEmpty) ? 'N/A' : a.noRecibo!;
    });
    _focusMonto.requestFocus();
  }

  Future<void> _registrar() async {
    if (_det == null || _guardando) return;
    if (_monto.text.trim().isEmpty) {
      await avisar(context, 'Por favor, ingrese un monto de abono.', titulo: 'Campo Obligatorio');
      _focusMonto.requestFocus();
      return;
    }
    if (_estado == 'Liquidada') {
      await avisar(context, 'No se puede registrar un abono en una factura liquidada.', titulo: 'Error');
      return;
    }
    if (decimalExacto(_monto.text) == null) {
      await avisar(context, 'Ingrese un monto válido para el abono.', titulo: 'Error', tipo: TipoAviso.error);
      return;
    }
    if (_recibo.text.trim().isEmpty) _recibo.text = 'N/A';
    final calc = _calc;
    if (calc.montoCent > calc.baseCent) {
      await avisar(context, 'El monto del abono no puede ser mayor que el saldo base.', titulo: 'Error', tipo: TipoAviso.error);
      return;
    }
    if (_conInteres && decimalExacto(_porcentaje.text) == null) {
      await avisar(context, 'Ingrese un porcentaje de interés válido.', titulo: 'Error', tipo: TipoAviso.error);
      return;
    }
    final esEdicion = _editando != null;
    setState(() => _guardando = true);
    try {
      await Repo.guardarAbono(
        idVenta: widget.credito.idVenta,
        idAbono: _editando?.idAbono,
        monto: calc.monto,
        fecha: _fechaAbono,
        nuevoSaldo: calc.nuevoSaldoGuardado,
        interes: calc.interes,
        metodoPago: _metodo,
        recibo: _recibo.text.trim(),
        saldoAnterior: calc.base,
      );
      _huboCambios = true;
      if (!mounted) return;
      exito(context, esEdicion ? 'Abono actualizado correctamente.' : 'Abono registrado correctamente.');
      setState(_limpiar);
      await _cargar();
    } on OdbcError catch (e) {
      if (mounted) {
        await avisar(
          context,
          '${esEdicion ? 'Error al actualizar el abono: ' : 'Error al registrar el abono: '}${e.mensaje}',
          titulo: 'Error',
          tipo: TipoAviso.error,
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _eliminarAbono() async {
    final a = _editando;
    if (a == null) {
      await avisar(context, 'Seleccione un abono del historial para eliminar.', titulo: 'Aviso');
      return;
    }
    if (!await confirmar(context, '¿Seguro que desea eliminar este abono?', titulo: 'Confirmar eliminación', peligro: true)) return;
    setState(() => _guardando = true);
    try {
      await Repo.eliminarAbono(widget.credito.idVenta, a.idAbono);
      _huboCambios = true;
      if (!mounted) return;
      exito(context, 'Abono eliminado correctamente.');
      setState(_limpiar);
      await _cargar();
    } on OdbcError catch (e) {
      if (mounted) await avisar(context, 'Error al eliminar el abono: ${e.mensaje}', titulo: 'Error', tipo: TipoAviso.error);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _cerrar() => Navigator.of(context).pop(_huboCambios);

  @override
  Widget build(BuildContext context) {
    return Modal(
      titulo: 'ABONOS DE FACTURAS A CREDITO',
      ancho: 1340,
      alto: 900,
      onCerrar: _cerrar,
      child: _error != null
          ? Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Error al cargar el crédito: $_error', textAlign: TextAlign.center, style: T.texto(14.5)),
                  const SizedBox(height: 16),
                  Boton('Reintentar', tipo: TipoBoton.primario, onPressed: _cargar),
                ],
              ),
            )
          : _det == null
          ? const SizedBox(height: 420, child: Cargando(texto: 'Cargando crédito...'))
          : Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _infoFactura(),
                  const SizedBox(height: 12),
                  _infoAbono(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('HISTORIAL DE ABONOS', style: T.etiqueta(color: C.verde).copyWith(letterSpacing: 1.1)),
                      const SizedBox(width: 12),
                      Text('Doble clic sobre un abono para editarlo o eliminarlo', style: T.texto(12.5, color: C.tintaTenue)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(child: _historial()),
                ],
              ),
            ),
    );
  }

  Widget _ro(String etiqueta, String valor, {bool cifra = false, Color? color}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Etiqueta(etiqueta),
      Tooltip(
        message: valor.length > 22 ? valor : '',
        child: Container(
          height: 38,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: C.papel,
            border: Border.all(color: C.lineaSuave),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            valor,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: cifra ? T.cifra(14, color: color ?? C.tinta) : T.texto(14, color: color ?? C.tinta, peso: FontWeight.w500),
          ),
        ),
      ),
    ],
  );

  Widget _infoFactura() {
    final d = _det!;
    final c = widget.credito;
    Widget col(List<Widget> hijos, {int flex = 1}) => Expanded(
      flex: flex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [hijos[0], const SizedBox(height: 10), if (hijos.length > 1) hijos[1] else const SizedBox(height: 59)],
      ),
    );
    const g = SizedBox(width: 14);
    return Seccion(
      titulo: 'INFORMACION DE LA FACTURA',
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          col([_ro('No. de factura:', c.numeroDocumento), _ro('Cliente:', c.nombreCliente)], flex: 8),
          g,
          col([
            _ro('Monto total:', lempiras(c.montoTotal), cifra: true),
            _ro('Saldo pendiente:', lempiras(_saldoActual), cifra: true, color: C.verde),
          ], flex: 5),
          g,
          col([
            _ro('Fecha de vencimiento:', c.fechaVencimiento == null ? 'Sin fecha' : fechaCorta(c.fechaVencimiento), cifra: true),
            _ro('Estado:', _estado, color: _estado == 'Liquidada' ? C.ok : C.tinta),
          ], flex: 4),
          g,
          col([_ro('No. Cuotas:', d.resumen.numeroCuotas.toString(), cifra: true), _ro('Descripcion:', c.descripcion)], flex: 5),
          g,
          col([_ro('Cuota en curso:', d.resumen.cuotaActual.toString(), cifra: true), _ro('Monto prima:', lempiras(_prima), cifra: true)], flex: 4),
          g,
          Expanded(
            flex: 7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ro('Monto Cuota:', lempiras(d.resumen.montoCuota), cifra: true),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Boton('TABLA DEL CREDITO', icono: Icons.view_list_rounded, alto: 40, tipo: TipoBoton.laton, onPressed: _tablaCredito),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoAbono() {
    final calc = _calc;
    final hayMonto = decimalExacto(_monto.text) != null;
    final interes = calc.interes;
    final nuevo = calc.nuevoSaldoMostrado;
    final total = calc.totalConInteres;
    const g = SizedBox(width: 14);
    return Seccion(
      titulo: 'INFORMACION DEL ABONO:',
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 4,
                child: CampoFecha(
                  etiqueta: 'Fecha de abono:',
                  valor: _fechaAbono,
                  onChanged: _guardando ? null : (f) => setState(() => _fechaAbono = soloFecha(f)),
                ),
              ),
              g,
              Expanded(
                flex: 5,
                child: Campo(
                  etiqueta: 'Monto de abono:',
                  controller: _monto,
                  focus: _focusMonto,
                  cifra: true,
                  formatos: [montoFormato],
                  maxLength: 15,
                  hint: '0.00',
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _registrar(),
                ),
              ),
              g,
              Expanded(
                flex: 5,
                child: Combo<String>(
                  etiqueta: 'Metodo de pago:',
                  valor: _metodo,
                  opciones: const [('Efectivo', 'Efectivo'), ('Tarjeta', 'Tarjeta'), ('Transferencia', 'Transferencia')],
                  onChanged: (v) => setState(() => _metodo = v ?? 'Efectivo'),
                ),
              ),
              g,
              Expanded(
                flex: 5,
                child: Campo(etiqueta: 'No de recibo:', controller: _recibo, maxLength: 50),
              ),
              g,
              Expanded(
                flex: 3,
                child: Combo<String>(
                  etiqueta: 'Aplicar Interes',
                  valor: _aplicarInteres,
                  opciones: const [('Sí', 'Sí'), ('No', 'No')],
                  onChanged: (v) => setState(() => _aplicarInteres = v ?? 'No'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(flex: 4, child: _ro('Interes generado:', lempiras(interes), cifra: true)),
              g,
              Expanded(flex: 5, child: _ro('Total a pagar con interes:', hayMonto ? lempiras(total) : '', cifra: true, color: C.verde)),
              g,
              Expanded(flex: 5, child: _ro('Nuevo saldo pendiente:', hayMonto ? lempiras(nuevo) : '', cifra: true)),
              g,
              Expanded(
                flex: 5,
                child: Campo(
                  etiqueta: 'Porcentaje de interes:',
                  controller: _porcentaje,
                  habilitado: _conInteres,
                  cifra: true,
                  formatos: [porcentajeFormato],
                  maxLength: 9,
                  hint: _conInteres ? '%' : '',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              g,
              Expanded(
                flex: 3,
                child: Combo<String>(
                  etiqueta: 'Interes aplicado a:',
                  valor: _interesA,
                  opciones: const [('Saldo Pendiente', 'Saldo Pendiente'), ('Monto Total', 'Monto Total')],
                  onChanged: _conInteres ? (v) => setState(() => _interesA = v ?? 'Saldo Pendiente') : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (_editando != null)
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                  decoration: BoxDecoration(color: C.latonSuave, borderRadius: BorderRadius.circular(4)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit_note_rounded, size: 18, color: C.laton),
                      const SizedBox(width: 8),
                      Text(
                        'Editando abono del ${fechaCorta(_editando!.fechaAbono)} · saldo anterior ${lempiras(_editando!.saldoAnterior)}',
                        style: T.texto(13, peso: FontWeight.w600),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: 'Dejar de editar',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(_limpiar),
                        icon: const Icon(Icons.close_rounded, size: 17, color: C.tintaSuave),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              if (_editando != null) ...[
                Boton('Eliminar abono', icono: Icons.delete_outline_rounded, tipo: TipoBoton.peligro, onPressed: _guardando ? null : _eliminarAbono),
                const SizedBox(width: 10),
              ],
              Boton(
                _editando != null ? 'Actualizar abono' : 'Registrar abono',
                icono: Icons.check_rounded,
                tipo: TipoBoton.primario,
                cargando: _guardando,
                onPressed: _guardando ? null : _registrar,
              ),
              const SizedBox(width: 10),
              Boton('Cancelar', icono: Icons.close_rounded, onPressed: _guardando ? null : _cerrar),
            ],
          ),
        ],
      ),
    );
  }

  Widget _historial() {
    final abonos = _det!.abonos;
    return TablaDatos<Abono>(
      filas: abonos,
      seleccion: _selHistorial,
      onSeleccion: (i) => setState(() => _selHistorial = i),
      onActivar: _editar,
      vacio: 'Este crédito todavía no tiene abonos',
      columnas: [
        Columna('Fecha abono', texto: (a) => fechaCorta(a.fechaAbono), cifra: true),
        Columna('Monto abonado', texto: (a) => lempiras(a.montoAbono), cifra: true, alineacion: TextAlign.right),
        Columna('Saldo anterior', texto: (a) => lempiras(a.saldoAnterior), cifra: true, alineacion: TextAlign.right),
        Columna('Saldo pendiente', texto: (a) => lempiras(a.nuevoSaldoPendiente), cifra: true, alineacion: TextAlign.right),
        Columna('Interés aplicado', texto: (a) => lempiras(a.interesAplicado), cifra: true, alineacion: TextAlign.right),
        Columna('Método de pago', texto: (a) => a.metodoPago ?? 'No especificado'),
        Columna('No. Recibo', texto: (a) => (a.noRecibo == null || a.noRecibo!.trim().isEmpty) ? 'N/A' : a.noRecibo!),
        Columna('Cuotas', texto: (a) => a.cuotasTexto, minimo: 200, maximo: 520, flex: 1),
      ],
    );
  }

  void _tablaCredito() {
    final d = _det!;
    final r = d.resumen;
    final totalCuotas = d.totalCuotas;
    final totalPagado = d.totalPagadoCuotas;
    final totalSaldo = totalCuotas - totalPagado;
    showDialog<void>(
      context: context,
      builder: (ctx) => Modal(
        titulo: 'Tabla de amortización del crédito',
        ancho: 860,
        alto: 640,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _dato('N° cuotas', r.numeroCuotas.toString()),
                  _dato('Cuota actual', r.cuotaActual.toString()),
                  _dato('Próximo pago', r.proximoPago == null ? '---' : fechaCorta(r.proximoPago)),
                  _dato('Total cuotas', lempiras(totalCuotas)),
                  _dato('Pagado', lempiras(totalPagado)),
                  _dato('Saldo', lempiras(totalSaldo)),
                  if (r.enMora)
                    Container(
                      height: 54,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: C.rojo, borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        '*** EN MORA ***',
                        style: T.texto(13.5, color: C.blanco, peso: FontWeight.w700, tracking: 0.6),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: TablaDatos<Cuota>(
                  filas: d.cuotas,
                  vacio: 'Este crédito no tiene cuotas',
                  colorFila: (c) => c.estado == 'Pagada' ? const Color(0xFFF1F8F3) : null,
                  columnas: [
                    Columna('Cuota', texto: (c) => c.numeroCuota.toString(), cifra: true, alineacion: TextAlign.right),
                    Columna('Fecha pago', texto: (c) => fechaCorta(c.fechaPago), cifra: true),
                    Columna('Monto cuota', texto: (c) => lempiras(c.montoCuota), cifra: true, alineacion: TextAlign.right, flex: 1),
                    Columna('Pagado', texto: (c) => lempiras(c.montoPagado), cifra: true, alineacion: TextAlign.right, flex: 1),
                    Columna('Saldo', texto: (c) => lempiras(c.montoCuota - c.montoPagado), cifra: true, alineacion: TextAlign.right, flex: 1),
                    Columna(
                      'Estado',
                      texto: (c) => c.estado,
                      ancho: 120,
                      celda: (c, _) => c.estado == 'Pagada'
                          ? const Insignia('Pagada', fondo: C.okSuave, color: C.ok)
                          : c.estado == 'Parcial'
                          ? const Insignia('Parcial', fondo: C.latonSuave, color: Color(0xFF7A5414))
                          : Text(c.estado, style: T.texto(13.5, color: C.tintaSuave)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: Boton('Cerrar', tipo: TipoBoton.primario, onPressed: () => Navigator.of(ctx).pop()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dato(String k, String v) => Container(
    height: 54,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: C.blanco,
      border: Border.all(color: C.linea),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(k.toUpperCase(), style: T.etiqueta().copyWith(fontSize: 10.5)),
        const SizedBox(height: 3),
        Text(v, style: T.cifra(15, peso: FontWeight.w600)),
      ],
    ),
  );
}
