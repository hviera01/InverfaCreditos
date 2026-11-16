import 'package:flutter/material.dart';

import '../data/formato.dart';
import '../data/modelos.dart';
import '../data/repo.dart';
import '../db/db.dart';
import 'buscar_cliente.dart';
import 'tema.dart';
import 'widgets.dart';

class DialogoRegistrarCredito extends StatefulWidget {
  const DialogoRegistrarCredito({super.key});
  @override
  State<DialogoRegistrarCredito> createState() => _DialogoRegistrarCreditoState();
}

class _DialogoRegistrarCreditoState extends State<DialogoRegistrarCredito> {
  final _factura = TextEditingController();
  final _descripcion = TextEditingController();
  final _montoTotal = TextEditingController();
  final _prima = TextEditingController();
  final _cuotas = TextEditingController();
  final _cliente = TextEditingController();
  final _rtn = TextEditingController();
  final _codCliente = TextEditingController();
  final _profesion = TextEditingController();
  final _telefono = TextEditingController();
  final _direccion = TextEditingController();
  final _focusFactura = FocusNode();
  DateTime _fechaInicio = soloFecha(DateTime.now());
  String _frecuencia = 'Semanal';
  Cliente? _seleccionado;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusFactura.requestFocus());
  }

  @override
  void dispose() {
    for (final c in [_factura, _descripcion, _montoTotal, _prima, _cuotas, _cliente, _rtn, _codCliente, _profesion, _telefono, _direccion]) {
      c.dispose();
    }
    _focusFactura.dispose();
    super.dispose();
  }

  double get _total => (leerMonto(_montoTotal.text) ?? 0) < 0 ? 0 : (leerMonto(_montoTotal.text) ?? 0);
  double get _primaV => (leerMonto(_prima.text) ?? 0) < 0 ? 0 : (leerMonto(_prima.text) ?? 0);
  int get _nCuotas => int.tryParse(_cuotas.text.trim()) ?? 0;

  double get _saldo {
    final s = _total - _primaV;
    return s < 0 ? 0 : r2(s);
  }

  DateTime get _vencimiento => _nCuotas <= 0 ? _fechaInicio : Plan.fechaUltimoPago(_fechaInicio, _frecuencia, _nCuotas);

  Future<void> _buscarCliente() async {
    final c = await showDialog<Cliente>(context: context, builder: (_) => const DialogoBuscarCliente());
    if (c == null) return;
    setState(() {
      _seleccionado = c;
      _cliente.text = c.nombreCompleto;
      _rtn.text = c.documento;
      _codCliente.text = c.codCliente > 0 ? c.codCliente.toString() : '';
      _profesion.text = c.correo;
      _telefono.text = c.telefono;
      _direccion.text = c.direccion;
    });
  }

  void _quitarCliente() {
    setState(() {
      _seleccionado = null;
      for (final c in [_cliente, _rtn, _codCliente, _profesion, _telefono, _direccion]) {
        c.clear();
      }
    });
  }

  Future<void> _registrar() async {
    if (_guardando) return;
    if (_cliente.text.trim().isEmpty) {
      await avisar(context, 'Ingrese el nombre del cliente.', titulo: 'Cliente');
      return;
    }
    final monto = leerMonto(_montoTotal.text);
    if (monto == null) {
      await avisar(context, 'Ingrese un monto total válido.', titulo: 'Dato requerido');
      return;
    }
    var prima = 0.0;
    if (_prima.text.trim().isNotEmpty) {
      final p = leerMonto(_prima.text);
      if (p == null) {
        await avisar(context, 'La prima no es válida.', titulo: 'Error', tipo: TipoAviso.error);
        return;
      }
      prima = p;
    }
    final n = int.tryParse(_cuotas.text.trim());
    if (n == null || n <= 0) {
      await avisar(context, 'Ingrese un número de cuotas válido.', titulo: 'Error', tipo: TipoAviso.error);
      return;
    }
    final saldo = r2(monto - prima);
    if (saldo < 0) {
      await avisar(context, 'La prima no puede ser mayor que el monto total.', titulo: 'Error', tipo: TipoAviso.error);
      return;
    }
    final nombre = _cliente.text.trim();
    final documento = _rtn.text.trim().isEmpty ? 'N/A' : _rtn.text.trim();
    final cliente = _seleccionado != null
        ? (Cliente(idCliente: _seleccionado!.idCliente, codCliente: _seleccionado!.codCliente, documento: documento, nombreCompleto: nombre))
        : Cliente(
            codCliente: int.tryParse(_codCliente.text.trim()) ?? 0,
            documento: documento,
            nombreCompleto: nombre,
            correo: _profesion.text.trim(),
            telefono: _telefono.text.trim(),
            direccion: _direccion.text.trim(),
            estado: true,
          );
    setState(() => _guardando = true);
    try {
      final r = await Repo.registrarCredito(
        NuevoCredito(
          idClienteExistente: _seleccionado?.idCliente,
          cliente: cliente,
          numeroDocumento: _factura.text.trim().isEmpty ? 'N/A' : _factura.text.trim(),
          montoTotal: r2(monto),
          saldoPendiente: saldo,
          fechaVencimiento: Plan.fechaUltimoPago(_fechaInicio, _frecuencia, n),
          fechaRegistro: DateTime.now(),
          descripcion: _descripcion.text.trim().isEmpty ? 'N/A' : _descripcion.text.trim(),
          numeroCuotas: n,
          frecuencia: _frecuencia,
          fechaInicio: _fechaInicio,
        ),
      );
      if (!mounted) return;
      if (!r.ok) {
        await avisar(context, r.mensaje, titulo: 'Cliente');
        return;
      }
      Navigator.of(context).pop(true);
    } on OdbcError catch (e) {
      if (mounted) await avisar(context, 'Error: ${e.mensaje}', titulo: 'Excepción', tipo: TipoAviso.error);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const g = SizedBox(width: 16);
    const v = SizedBox(height: 14);
    final cuota = Plan.montoCuota(_saldo, _nCuotas);
    final bloqueado = _seleccionado != null;
    return Modal(
      titulo: 'INGRESAR NUEVO CREDITO',
      ancho: 1120,
      onCerrar: _guardando ? () {} : null,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 13,
                  child: Seccion(
                    titulo: 'DATOS DEL CREDITO',
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Campo(etiqueta: 'No. de factura:', controller: _factura, focus: _focusFactura, maxLength: 50, hint: 'N/A'),
                              v,
                              Campo(etiqueta: 'Descripcion:', controller: _descripcion, maxLength: 200),
                              v,
                              Campo(
                                etiqueta: 'Monto total:',
                                controller: _montoTotal,
                                cifra: true,
                                formatos: [montoFormato],
                                maxLength: 15,
                                hint: '0.00',
                                onChanged: (_) => setState(() {}),
                              ),
                              v,
                              Campo(
                                etiqueta: 'Prima:',
                                controller: _prima,
                                cifra: true,
                                formatos: [montoFormato],
                                maxLength: 15,
                                hint: '0.00',
                                onChanged: (_) => setState(() {}),
                              ),
                              v,
                              _soloLectura('Saldo pendiente:', _saldo > 0 ? plano2(_saldo) : ''),
                            ],
                          ),
                        ),
                        g,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              CampoFecha(
                                etiqueta: 'Fecha inicio credito:',
                                valor: _fechaInicio,
                                onChanged: (f) => setState(() => _fechaInicio = soloFecha(f)),
                              ),
                              v,
                              CampoFecha(etiqueta: 'Fecha de vencimiento:', valor: _vencimiento),
                              v,
                              Campo(
                                etiqueta: 'No. Cuotas:',
                                controller: _cuotas,
                                cifra: true,
                                formatos: [soloDigitos],
                                maxLength: 3,
                                onChanged: (_) => setState(() {}),
                              ),
                              v,
                              Combo<String>(
                                etiqueta: 'Frecuencia:',
                                valor: _frecuencia,
                                opciones: const [('Semanal', 'Semanal'), ('Quincenal', 'Quincenal'), ('Mensual', 'Mensual')],
                                onChanged: (x) => setState(() => _frecuencia = x ?? 'Semanal'),
                              ),
                              v,
                              _soloLectura('Monto Cuota:', cuota > 0 ? plano2(cuota) : ''),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                g,
                Expanded(
                  flex: 7,
                  child: Seccion(
                    titulo: 'DATOS DEL CLIENTE',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Boton(
                                bloqueado ? 'Cambiar cliente' : 'Buscar cliente',
                                icono: Icons.search_rounded,
                                tipo: TipoBoton.primario,
                                onPressed: _buscarCliente,
                              ),
                            ),
                            if (bloqueado) ...[
                              const SizedBox(width: 8),
                              Tooltip(
                                message: 'Quitar cliente seleccionado',
                                child: Boton('', icono: Icons.person_remove_outlined, onPressed: _quitarCliente),
                              ),
                            ],
                          ],
                        ),
                        v,
                        Campo(etiqueta: 'Cliente:', controller: _cliente, maxLength: 50, soloLectura: bloqueado),
                        v,
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Campo(
                                etiqueta: 'Cod Cliente',
                                controller: _codCliente,
                                cifra: true,
                                formatos: [soloDigitos],
                                maxLength: 9,
                                soloLectura: bloqueado,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 5,
                              child: Campo(etiqueta: 'Identidad / RTN:', controller: _rtn, maxLength: 50, soloLectura: bloqueado),
                            ),
                          ],
                        ),
                        v,
                        Campo(etiqueta: 'Profesion u Oficio', controller: _profesion, maxLength: 50, soloLectura: bloqueado),
                        v,
                        Campo(etiqueta: 'Telefono:', controller: _telefono, maxLength: 50, soloLectura: bloqueado),
                        v,
                        Campo(etiqueta: 'Direccion:', controller: _direccion, maxLength: 200, lineas: 2, soloLectura: bloqueado),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    bloqueado
                        ? 'Cliente existente seleccionado (Cod ${_seleccionado!.codCliente}).'
                        : 'Si no busca un cliente, se registrará como cliente nuevo.',
                    style: T.texto(13, color: C.tintaSuave),
                  ),
                ),
                Boton('Cancelar', icono: Icons.close_rounded, alto: 48, onPressed: _guardando ? null : () => Navigator.of(context).pop(false)),
                const SizedBox(width: 12),
                Boton(
                  'Registrar Credito',
                  icono: Icons.check_rounded,
                  tipo: TipoBoton.primario,
                  alto: 48,
                  cargando: _guardando,
                  onPressed: _registrar,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _soloLectura(String e, String v) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Etiqueta(e),
      Container(
        height: 40,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: C.papel,
          border: Border.all(color: C.lineaSuave),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          v,
          maxLines: 1,
          style: T.cifra(14, color: C.verde, peso: FontWeight.w600),
        ),
      ),
    ],
  );
}
