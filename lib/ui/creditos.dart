import 'package:flutter/material.dart';

import '../data/formato.dart';
import '../data/modelos.dart';
import '../data/repo.dart';
import '../db/db.dart';
import 'abonos.dart';
import 'archivos.dart';
import 'importar.dart';
import 'registrar_credito.dart';
import 'tema.dart';
import 'widgets.dart';

class PantallaCreditos extends StatefulWidget {
  const PantallaCreditos({super.key});
  @override
  State<PantallaCreditos> createState() => _PantallaCreditosState();
}

class _PantallaCreditosState extends State<PantallaCreditos> {
  List<CreditoResumen> _todos = [];
  List<CreditoResumen> _visibles = [];
  final Map<int, List<String>> _indice = {};
  int? _sel;
  bool _cargando = false;
  bool _ocupado = false;
  String? _error;
  String _estado = 'Debe';
  final _busqueda = TextEditingController();
  final _focusBusqueda = FocusNode();
  final _rebote = Antirrebote();

  @override
  void initState() {
    super.initState();
    _cargar();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusBusqueda.requestFocus());
  }

  @override
  void dispose() {
    _rebote.cancelar();
    _busqueda.dispose();
    _focusBusqueda.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    if (_cargando) return;
    final idSel = _seleccionado?.idVenta;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final l = await Repo.listarCreditos();
      _indice.clear();
      for (final c in l) {
        _indice[c.idVenta] = [
          c.fechaRegistro == null ? 'N/A' : fechaCorta(c.fechaRegistro),
          c.numeroDocumento,
          c.nombreCliente,
          plano2(c.montoTotal),
          numero2(c.montoTotal),
          plano2(c.saldoPendiente),
          numero2(c.saldoPendiente),
          c.fechaVencimiento == null ? 'Sin fecha' : fechaCorta(c.fechaVencimiento),
          c.estado,
          c.vencida,
          c.descripcion,
          c.numeroCuotas.toString(),
          c.proximoPago == null ? 'Sin fecha' : fechaCorta(c.proximoPago),
          c.mora,
        ].map((s) => s.toLowerCase()).toList();
      }
      if (!mounted) return;
      setState(() {
        _todos = l;
        _aplicarFiltro(mantenerId: idSel);
      });
    } on OdbcError catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  CreditoResumen? get _seleccionado => (_sel != null && _sel! < _visibles.length) ? _visibles[_sel!] : null;

  void _aplicarFiltro({int? mantenerId}) {
    final texto = _busqueda.text.trim();
    final tokens = texto.toLowerCase().split(' ').where((t) => t.isNotEmpty).toList();
    final codigo = int.tryParse(texto);
    _visibles = _todos.where((c) {
      if (texto.isNotEmpty) {
        if (codigo != null) {
          if (c.codCliente != codigo) return false;
        } else {
          final valores = _indice[c.idVenta]!;
          if (!valores.any((v) => tokens.every((t) => v.contains(t)))) return false;
        }
      }
      if (_estado != 'Todas' && c.estado != _estado) return false;
      return true;
    }).toList();
    if (mantenerId != null) {
      final i = _visibles.indexWhere((c) => c.idVenta == mantenerId);
      _sel = i >= 0 ? i : null;
    } else {
      _sel = null;
    }
  }

  double get _totalPendiente => deCentavos(_visibles.fold<int>(0, (a, c) => a + centavos(c.saldoPendiente)));

  Future<void> _registrarAbono([int? indice]) async {
    if (indice != null) setState(() => _sel = indice);
    final c = _seleccionado;
    if (c == null) {
      await avisar(context, 'Por favor, seleccione una venta a crédito.');
      return;
    }
    final cambio = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogoAbonos(credito: c),
    );
    if (cambio == true) await _cargar();
    _focusBusqueda.requestFocus();
  }

  Future<void> _registrarCredito() async {
    final ok = await showDialog<bool>(context: context, barrierDismissible: false, builder: (_) => const DialogoRegistrarCredito());
    if (ok == true) {
      if (mounted) exito(context, 'Crédito registrado correctamente.');
      await _cargar();
    }
  }

  Future<void> _eliminar() async {
    final c = _seleccionado;
    if (c == null) {
      await avisar(context, 'Seleccione un crédito para eliminar.', titulo: 'Aviso');
      return;
    }
    final si = await confirmar(
      context,
      'ATENCIÓN:\n\nSe eliminará DEFINITIVAMENTE el crédito seleccionado, TODAS sus cuotas y TODOS los abonos registrados.\n\n'
      'Esta acción es IRREVERSIBLE y no existe forma de recuperar la información.\n\n'
      'Crédito: ${c.numeroDocumento} - ${c.nombreCliente}\n\n¿Está completamente seguro de continuar?',
      titulo: 'Eliminar crédito',
      peligro: true,
      si: 'Sí, eliminar',
    );
    if (!si) return;
    setState(() => _ocupado = true);
    try {
      await Repo.eliminarCredito(c.idVenta);
      if (!mounted) return;
      exito(context, 'Crédito eliminado correctamente.');
      await _cargar();
    } on OdbcError catch (e) {
      if (mounted) await avisar(context, 'Error al eliminar el crédito: ${e.mensaje}', titulo: 'Error', tipo: TipoAviso.error);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _importar() async {
    final ruta = await elegirExcel('Seleccionar archivo de créditos');
    if (ruta == null) return;
    setState(() => _ocupado = true);
    try {
      final resumen = await importarCreditos(ruta);
      if (!mounted) return;
      await avisar(context, resumen, titulo: 'Importar', tipo: TipoAviso.info);
      await _cargar();
    } catch (e) {
      if (mounted) await avisar(context, 'Error general en la importación: $e', titulo: 'Importar', tipo: TipoAviso.error);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  static const _encabezados = [
    'Fecha de Registro',
    'No.Factura',
    'Cod Cliente',
    'Cliente',
    'Monto Total',
    'Saldo Pendiente',
    'Fecha de Vencimiento',
    'Estado',
    'Vencida',
    'Descripción',
    '# Cuotas',
    'Próximo pago',
    'Mora',
  ];

  List<Object?> _filaExport(CreditoResumen c, {bool texto = false}) => [
    c.fechaRegistro == null ? 'N/A' : fechaCorta(c.fechaRegistro),
    c.numeroDocumento,
    texto ? c.codCliente.toString() : c.codCliente,
    c.nombreCliente,
    texto ? lempiras(c.montoTotal) : c.montoTotal,
    texto ? lempiras(c.saldoPendiente) : c.saldoPendiente,
    c.fechaVencimiento == null ? 'Sin fecha' : fechaCorta(c.fechaVencimiento),
    c.estado,
    c.vencida,
    c.descripcion,
    texto ? c.numeroCuotas.toString() : c.numeroCuotas,
    c.proximoPago == null ? 'Sin fecha' : fechaCorta(c.proximoPago),
    c.mora,
  ];

  Future<void> _excel() async {
    if (_visibles.isEmpty) {
      await avisar(context, 'No hay registros para exportar');
      return;
    }
    try {
      final r = await exportarExcel(
        nombreArchivo: 'Creditos_ComercialInverfa_${marcaTiempo()}.xlsx',
        hoja: 'Creditos',
        encabezados: _encabezados,
        filas: [for (final c in _visibles) _filaExport(c)],
      );
      if (r != null && mounted) exito(context, 'Reporte generado correctamente');
    } catch (e) {
      if (mounted) await avisar(context, 'Error al generar reporte: $e', tipo: TipoAviso.error);
    }
  }

  Future<void> _pdf() async {
    if (_visibles.isEmpty) {
      await avisar(context, 'No hay registros para exportar');
      return;
    }
    try {
      final r = await exportarPdf(
        nombreArchivo: 'Creditos_ComercialInverfa_${marcaTiempo()}.pdf',
        subtitulo: 'REPORTE DE CRÉDITOS',
        encabezados: _encabezados,
        filas: [for (final c in _visibles) _filaExport(c, texto: true).map((e) => e.toString()).toList()],
        horizontal: true,
        columnasDerecha: const [2, 4, 5, 10],
      );
      if (r != null && mounted) exito(context, 'Reporte PDF generado correctamente');
    } catch (e) {
      if (mounted) await avisar(context, 'Error al generar PDF: $e', tipo: TipoAviso.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 44,
            child: Row(
              children: [
                Boton('Importar', icono: Icons.file_upload_outlined, onPressed: _ocupado ? null : _importar),
                const SizedBox(width: 12),
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('VENTAS A CREDITO', maxLines: 1, softWrap: false, style: T.titulo(28)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text('Filtrar creditos por', maxLines: 1, softWrap: false, style: T.texto(13.5, color: C.tintaSuave)),
                const SizedBox(width: 10),
                SizedBox(
                  width: 140,
                  child: Combo<String>(
                    valor: _estado,
                    opciones: const [('Debe', 'Debe'), ('Liquidada', 'Liquidada'), ('Todas', 'Todas')],
                    onChanged: (v) => setState(() {
                      _estado = v ?? 'Todas';
                      _aplicarFiltro(mantenerId: _seleccionado?.idVenta);
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Boton('REFRESCAR', icono: Icons.refresh_rounded, cargando: _cargando, onPressed: _cargar),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IntrinsicWidth(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Boton('Descargar Excel', icono: Icons.grid_on_rounded, alto: 34, onPressed: _excel),
                    const SizedBox(height: 8),
                    Boton('Descargar PDF', icono: Icons.picture_as_pdf_outlined, alto: 34, onPressed: _pdf),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Boton(
                'Registrar abono',
                icono: Icons.payments_outlined,
                tipo: TipoBoton.primario,
                alto: 46,
                onPressed: _ocupado ? null : _registrarAbono,
              ),
              const SizedBox(width: 10),
              Boton(
                'Registrar credito',
                icono: Icons.add_card_outlined,
                tipo: TipoBoton.laton,
                alto: 46,
                onPressed: _ocupado ? null : _registrarCredito,
              ),
              const SizedBox(width: 10),
              Boton(
                'Eliminar Credito',
                icono: Icons.delete_outline_rounded,
                tipo: TipoBoton.peligro,
                alto: 46,
                cargando: _ocupado,
                onPressed: _ocupado ? null : _eliminar,
              ),
              const Spacer(),
              _total(),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  _cargando && _todos.isEmpty ? '' : '${_visibles.length} de ${_todos.length} créditos',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: T.texto(13, color: C.tintaSuave),
                ),
              ),
              Text('Buscar:', style: T.texto(13.5, color: C.tintaSuave)),
              const SizedBox(width: 10),
              SizedBox(
                width: 320,
                child: Campo(
                  controller: _busqueda,
                  focus: _focusBusqueda,
                  hint: 'Cliente, factura, código...',
                  onChanged: (_) => _rebote(() => setState(() => _aplicarFiltro())),
                  onSubmitted: (_) {
                    _rebote.cancelar();
                    setState(() => _aplicarFiltro());
                  },
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Limpiar búsqueda',
                child: Boton(
                  '',
                  icono: Icons.backspace_outlined,
                  alto: 40,
                  onPressed: () {
                    _rebote.cancelar();
                    _busqueda.clear();
                    setState(() => _aplicarFiltro());
                    _focusBusqueda.requestFocus();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(child: _tabla()),
        ],
      ),
    );
  }

  Widget _total() => Container(
    padding: const EdgeInsets.fromLTRB(20, 10, 22, 10),
    decoration: BoxDecoration(
      color: C.blanco,
      border: Border.all(color: C.linea),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 4, height: 54, color: C.laton),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('TOTAL CREDITO PENDIENTE', style: T.etiqueta().copyWith(letterSpacing: 1.2)),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  lempiras(_totalPendiente),
                  style: T.cifra(34, color: C.verde, peso: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _tabla() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 40, color: C.rojo),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Text('Error al cargar las facturas a crédito: $_error', textAlign: TextAlign.center, style: T.texto(14.5)),
            ),
            const SizedBox(height: 16),
            Boton('Reintentar', icono: Icons.refresh_rounded, tipo: TipoBoton.primario, onPressed: _cargar),
          ],
        ),
      );
    }
    if (_cargando && _todos.isEmpty) return const Cargando(texto: 'Cargando créditos...');
    return TablaDatos<CreditoResumen>(
      filas: _visibles,
      seleccion: _sel,
      onSeleccion: (i) => setState(() => _sel = i),
      onActivar: _registrarAbono,
      vacio: 'No hay créditos para mostrar',
      colorFila: (c) => c.enMora ? C.rojoFila : null,
      columnas: [
        Columna('Fecha de Registro', texto: (c) => c.fechaRegistro == null ? 'N/A' : fechaCorta(c.fechaRegistro), cifra: true),
        Columna('No.Factura', texto: (c) => c.numeroDocumento, maximo: 160),
        Columna('Cod Cliente', texto: (c) => c.codCliente.toString(), alineacion: TextAlign.right, cifra: true),
        Columna('Cliente', texto: (c) => c.nombreCliente, minimo: 200, maximo: 290, flex: 3),
        Columna('Monto Total', texto: (c) => lempiras(c.montoTotal), alineacion: TextAlign.right, cifra: true),
        Columna('Saldo Pendiente', texto: (c) => lempiras(c.saldoPendiente), alineacion: TextAlign.right, cifra: true),
        Columna('Fecha de Vencimiento', texto: (c) => c.fechaVencimiento == null ? 'Sin fecha' : fechaCorta(c.fechaVencimiento), cifra: true),
        Columna(
          'Estado',
          texto: (c) => c.estado,
          ancho: 104,
          celda: (c, _) => c.estado == 'Liquidada' ? const Insignia('Liquidada', fondo: C.ok, color: C.blanco) : Text(c.estado, style: T.texto(13.5)),
        ),
        Columna(
          'Vencida',
          texto: (c) => c.vencida,
          ancho: 100,
          celda: (c, _) => c.vencida == 'Vencida'
              ? const Insignia('Vencida', fondo: C.rojo, color: C.blanco)
              : Text(c.vencida, style: T.texto(13.5, color: C.tintaSuave)),
        ),
        Columna('Descripción', texto: (c) => c.descripcion, minimo: 140, maximo: 240, flex: 2),
        Columna('# Cuotas', texto: (c) => c.numeroCuotas.toString(), alineacion: TextAlign.right, cifra: true),
        Columna('Próximo pago', texto: (c) => c.proximoPago == null ? 'Sin fecha' : fechaCorta(c.proximoPago), cifra: true),
        Columna(
          'Mora',
          texto: (c) => c.mora,
          ancho: 76,
          alineacion: TextAlign.center,
          celda: (c, _) =>
              c.enMora ? const Insignia('Si', fondo: Color(0xFF7A1F14), color: C.blanco) : Text(c.mora, style: T.texto(13.5, color: C.tintaSuave)),
        ),
      ],
    );
  }
}
