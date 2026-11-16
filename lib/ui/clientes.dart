import 'package:flutter/material.dart';

import '../data/modelos.dart';
import '../data/repo.dart';
import '../db/db.dart';
import 'archivos.dart';
import 'buscar_cliente.dart';
import 'importar.dart';
import 'tema.dart';
import 'widgets.dart';

const maxFilasClientes = 300;

class PantallaClientes extends StatefulWidget {
  const PantallaClientes({super.key});
  @override
  State<PantallaClientes> createState() => _PantallaClientesState();
}

class _PantallaClientesState extends State<PantallaClientes> {
  List<Cliente> _todos = [];
  List<Cliente> _visibles = [];
  List<Cliente> _coincidencias = [];
  int? _sel;
  bool _cargando = false;
  bool _guardando = false;
  bool _importando = false;
  String? _error;
  String _campoBusqueda = 'Todo';
  final _busqueda = TextEditingController();

  int _id = 0;
  final _cod = TextEditingController();
  final _dni = TextEditingController();
  final _nombre = TextEditingController();
  final _profesion = TextEditingController();
  final _telefono = TextEditingController();
  final _direccion = TextEditingController();
  final _focusDni = FocusNode();
  bool _activo = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    for (final c in [_busqueda, _cod, _dni, _nombre, _profesion, _telefono, _direccion]) {
      c.dispose();
    }
    _focusDni.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    if (_cargando) return;
    final idSel = _sel != null && _sel! < _visibles.length ? _visibles[_sel!].idCliente : null;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final l = await Repo.listarClientes();
      if (!mounted) return;
      setState(() {
        _todos = l;
        _filtrar(mantenerId: idSel);
      });
    } on OdbcError catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _filtrar({int? mantenerId}) {
    final texto = _busqueda.text.trim();
    if (texto.isEmpty) {
      _visibles = _todos;
    } else {
      final t = texto.split(' ').where((x) => x.isNotEmpty).map((x) => x.toUpperCase()).toList();
      switch (_campoBusqueda) {
        case 'CodCliente':
          final cod = int.tryParse(texto);
          _visibles = cod == null ? [] : _todos.where((c) => c.codCliente == cod).toList();
          break;
        case 'Documento':
          _visibles = _todos.where((c) => contieneTodas(c.documento, t)).toList();
          break;
        case 'NombreCompleto':
          _visibles = _todos.where((c) => contieneTodas(c.nombreCompleto, t)).toList();
          break;
        case 'Correo':
          _visibles = _todos.where((c) => contieneTodas(c.correo, t)).toList();
          break;
        case 'Direccion':
          _visibles = _todos.where((c) => contieneTodas(c.direccion, t)).toList();
          break;
        case 'Telefono':
          _visibles = _todos.where((c) => contieneTodas(c.telefono, t)).toList();
          break;
        case 'Estado':
          _visibles = _todos.where((c) => contieneTodas(c.estado ? 'ACTIVO' : 'NO ACTIVO', t)).toList();
          break;
        default:
          final l = texto.toLowerCase();
          _visibles = _todos
              .where(
                (c) =>
                    contieneTodas(c.documento, t) ||
                    contieneTodas(c.nombreCompleto, t) ||
                    contieneTodas(c.correo, t) ||
                    contieneTodas(c.direccion, t) ||
                    contieneTodas(c.telefono, t) ||
                    c.codCliente.toString().toLowerCase().contains(l),
              )
              .toList();
      }
    }
    _coincidencias = _visibles;
    if (_visibles.length > maxFilasClientes) _visibles = _visibles.sublist(0, maxFilasClientes);
    if (mantenerId != null) {
      final i = _visibles.indexWhere((c) => c.idCliente == mantenerId);
      _sel = i >= 0 ? i : null;
    } else {
      _sel = null;
    }
  }

  void _seleccionar(int i) {
    final c = _visibles[i];
    setState(() {
      _sel = i;
      _id = c.idCliente;
      _cod.text = c.codCliente.toString();
      _dni.text = c.documento;
      _nombre.text = c.nombreCompleto;
      _profesion.text = c.correo;
      _telefono.text = c.telefono;
      _direccion.text = c.direccion;
      _activo = c.estado;
    });
  }

  void _limpiar() {
    setState(() {
      _id = 0;
      _sel = null;
      for (final c in [_cod, _dni, _nombre, _profesion, _telefono, _direccion]) {
        c.clear();
      }
      _activo = true;
    });
    _focusDni.requestFocus();
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    final c = Cliente(
      idCliente: _id,
      codCliente: int.tryParse(_cod.text.trim()) ?? 0,
      documento: _dni.text,
      nombreCompleto: _nombre.text,
      correo: _profesion.text,
      telefono: _telefono.text,
      direccion: _direccion.text,
      estado: _activo,
    );
    setState(() => _guardando = true);
    try {
      final r = _id == 0 ? await Repo.registrarCliente(c) : await Repo.editarCliente(c);
      if (!mounted) return;
      if (!r.ok) {
        await avisar(context, r.mensaje.isEmpty ? 'No se pudo guardar el cliente.' : r.mensaje);
        return;
      }
      exito(context, _id == 0 ? 'Cliente registrado correctamente' : 'Cliente actualizado correctamente');
      _limpiar();
      await _cargar();
    } on OdbcError catch (e) {
      if (mounted) await avisar(context, e.mensaje, tipo: TipoAviso.error);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _eliminar() async {
    if (_id == 0) return;
    if (!await confirmar(context, '¿Desea eliminar el cliente?', titulo: 'Mensaje', peligro: true)) return;
    setState(() => _guardando = true);
    try {
      final ok = await Repo.eliminarCliente(_id);
      if (!mounted) return;
      if (ok) {
        exito(context, 'Cliente eliminado correctamente');
        _limpiar();
        await _cargar();
      } else {
        await avisar(context, 'No se pudo eliminar el cliente.');
      }
    } on OdbcError catch (e) {
      if (mounted) await avisar(context, e.mensaje, tipo: TipoAviso.error);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _importar() async {
    final ruta = await elegirExcel('Seleccionar archivo de clientes (Clientes_Excel.xlsx)');
    if (ruta == null) return;
    setState(() => _importando = true);
    try {
      final (imp, fal) = await importarClientes(ruta);
      if (!mounted) return;
      await avisar(
        context,
        'Importación finalizada.\nClientes importados: $imp\nRegistros omitidos / fallidos: $fal',
        titulo: 'Importar clientes',
        tipo: TipoAviso.info,
      );
      await _cargar();
    } catch (e) {
      if (mounted) await avisar(context, 'Ocurrió un error al importar: $e', titulo: 'Error', tipo: TipoAviso.error);
    } finally {
      if (mounted) setState(() => _importando = false);
    }
  }

  static const _encabezados = ['Codigo Cliente', 'DNI', 'Nombre ', 'Profesion / Oficio', 'Direccion', 'Telefono', 'Estado'];

  List<Object?> _fila(Cliente c) => [
    c.codCliente,
    c.documento,
    c.nombreCompleto,
    c.correo,
    c.direccion,
    c.telefono,
    c.estado ? 'Activo' : 'No activo',
  ];

  Future<void> _excel() async {
    if (_coincidencias.isEmpty) {
      await avisar(context, 'No hay registros para exportar');
      return;
    }
    try {
      final r = await exportarExcel(
        nombreArchivo: 'Clientes_ComercialInverfa_${marcaTiempo()}.xlsx',
        hoja: 'Clientes',
        encabezados: _encabezados,
        filas: [for (final c in _coincidencias) _fila(c)],
      );
      if (r != null && mounted) exito(context, 'Reporte generado correctamente');
    } catch (e) {
      if (mounted) await avisar(context, 'Error al generar reporte: $e', tipo: TipoAviso.error);
    }
  }

  Future<void> _pdf() async {
    if (_coincidencias.isEmpty) {
      await avisar(context, 'No hay registros para exportar');
      return;
    }
    try {
      final r = await exportarPdf(
        nombreArchivo: 'Clientes_ComercialInverfa_${marcaTiempo()}.pdf',
        subtitulo: 'REPORTE DE CLIENTES',
        encabezados: _encabezados,
        filas: [for (final c in _coincidencias) _fila(c).map((e) => e.toString()).toList()],
        horizontal: false,
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 350, child: _detalle()),
          const SizedBox(width: 20),
          Expanded(child: _lista()),
        ],
      ),
    );
  }

  Widget _detalle() {
    const v = SizedBox(height: 12);
    return Container(
      decoration: BoxDecoration(
        color: C.blanco,
        border: Border.all(color: C.linea),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 11),
            color: C.verde,
            child: Row(
              children: [
                Text('DETALLE CLIENTE', style: T.titulo(19, color: C.papel)),
                const Spacer(),
                if (_id != 0) const Insignia('Editando', fondo: C.laton, color: C.blanco),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 4,
                        child: Campo(etiqueta: 'Cod Cliente', controller: _cod, cifra: true, formatos: [soloDigitos], maxLength: 9, hint: 'Auto'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 6,
                        child: Campo(etiqueta: 'DNI:', controller: _dni, focus: _focusDni, cifra: true, formatos: [digitosTecleados(14)]),
                      ),
                    ],
                  ),
                  v,
                  Campo(etiqueta: 'Nombre:', controller: _nombre, maxLength: 50),
                  v,
                  Campo(etiqueta: 'Profesion u Oficio', controller: _profesion, maxLength: 50),
                  v,
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 7,
                        child: Campo(etiqueta: 'Telefono:', controller: _telefono, maxLength: 50),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 4,
                        child: Combo<bool>(
                          etiqueta: 'Estado:',
                          valor: _activo,
                          opciones: const [(true, 'Activo'), (false, 'No activo')],
                          onChanged: (x) => setState(() => _activo = x ?? true),
                        ),
                      ),
                    ],
                  ),
                  v,
                  Campo(etiqueta: 'Direccion:', controller: _direccion, maxLength: 200, lineas: 2),
                  const SizedBox(height: 16),
                  Boton('GUARDAR', icono: Icons.save_outlined, tipo: TipoBoton.primario, cargando: _guardando, onPressed: _guardar),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Boton('LIMPIAR', icono: Icons.cleaning_services_outlined, onPressed: _guardando ? null : _limpiar),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Boton(
                          'ELIMINAR',
                          icono: Icons.delete_outline_rounded,
                          tipo: TipoBoton.peligro,
                          onPressed: (_guardando || _id == 0) ? null : _eliminar,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lista() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 44,
          child: Row(
            children: [
              Boton('IMPORTAR', icono: Icons.file_upload_outlined, cargando: _importando, onPressed: _importando ? null : _importar),
              const SizedBox(width: 12),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('LISTA DE CLIENTES', maxLines: 1, softWrap: false, style: T.titulo(28)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Boton('Descargar Excel', icono: Icons.grid_on_rounded, onPressed: _excel),
              const SizedBox(width: 8),
              Boton('Descargar PDF', icono: Icons.picture_as_pdf_outlined, onPressed: _pdf),
              const SizedBox(width: 8),
              Boton('REFRESCAR', icono: Icons.refresh_rounded, cargando: _cargando, onPressed: _cargar),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Spacer(),
            Text('Buscar por', style: T.texto(13.5, color: C.tintaSuave)),
            const SizedBox(width: 10),
            SizedBox(
              width: 190,
              child: Combo<String>(
                valor: _campoBusqueda,
                opciones: const [
                  ('Todo', 'Buscar en todo'),
                  ('CodCliente', 'Codigo Cliente'),
                  ('Documento', 'DNI'),
                  ('NombreCompleto', 'Nombre'),
                  ('Correo', 'Profesion / Oficio'),
                  ('Direccion', 'Direccion'),
                  ('Telefono', 'Telefono'),
                  ('Estado', 'Estado'),
                ],
                onChanged: (x) => setState(() => _campoBusqueda = x ?? 'Todo'),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 220,
              child: Campo(
                controller: _busqueda,
                hint: 'Escriba y presione Enter',
                onSubmitted: (_) => setState(() => _filtrar()),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Buscar',
              child: Boton(
                '',
                icono: Icons.search_rounded,
                tipo: TipoBoton.primario,
                alto: 40,
                onPressed: () => setState(() => _filtrar()),
              ),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message: 'Limpiar búsqueda',
              child: Boton(
                '',
                icono: Icons.backspace_outlined,
                alto: 40,
                onPressed: () {
                  _busqueda.clear();
                  setState(() {
                    _campoBusqueda = 'Todo';
                    _filtrar();
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Boton('REFRESCAR', icono: Icons.refresh_rounded, alto: 40, onPressed: _cargar),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(child: _tabla()),
        const SizedBox(height: 6),
        Text(
          _cargando && _todos.isEmpty
              ? ''
              : _coincidencias.length > _visibles.length
              ? 'Mostrando ${_visibles.length} de ${_coincidencias.length} clientes · escriba y presione Enter para buscar'
              : '${_visibles.length} de ${_todos.length} clientes',
          maxLines: 1,
          style: T.texto(12.5, color: C.tintaSuave),
        ),
      ],
    );
  }

  Widget _tabla() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Error al cargar clientes: $_error', textAlign: TextAlign.center, style: T.texto(14.5)),
            const SizedBox(height: 14),
            Boton('Reintentar', tipo: TipoBoton.primario, onPressed: _cargar),
          ],
        ),
      );
    }
    if (_cargando && _todos.isEmpty) return const Cargando(texto: 'Cargando clientes...');
    return TablaDatos<Cliente>(
      filas: _visibles,
      seleccion: _sel,
      onSeleccion: _seleccionar,
      onActivar: _seleccionar,
      vacio: 'No hay clientes para mostrar',
      columnas: [
        Columna(
          '',
          texto: (_) => '',
          ancho: 44,
          celda: (c, sel) => Icon(Icons.edit_outlined, size: 17, color: sel ? C.laton : C.tintaTenue),
        ),
        Columna('Codigo Cliente', texto: (c) => c.codCliente.toString(), cifra: true, alineacion: TextAlign.right),
        Columna('DNI', texto: (c) => c.documento, cifra: true, maximo: 200),
        Columna('Nombre ', texto: (c) => c.nombreCompleto, minimo: 220, maximo: 320, flex: 3),
        Columna('Profesion / Oficio', texto: (c) => c.correo, maximo: 220, flex: 1),
        Columna('Direccion', texto: (c) => c.direccion, minimo: 160, maximo: 320, flex: 2),
        Columna('Telefono', texto: (c) => c.telefono, maximo: 220),
        Columna(
          'Estado',
          texto: (c) => c.estado ? 'Activo' : 'No activo',
          ancho: 110,
          celda: (c, _) => c.estado
              ? const Insignia('Activo', fondo: C.okSuave, color: C.ok)
              : const Insignia('No activo', fondo: C.lineaSuave, color: C.tintaSuave),
        ),
      ],
    );
  }
}
