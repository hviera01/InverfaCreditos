import 'package:flutter/material.dart';

import '../data/modelos.dart';
import '../data/repo.dart';
import '../db/db.dart';
import 'tema.dart';
import 'widgets.dart';

bool contieneTodas(String campo, List<String> terminos) {
  if (campo.trim().isEmpty) return false;
  final v = campo.toUpperCase();
  for (final t in terminos) {
    if (!v.contains(t)) return false;
  }
  return true;
}

class DialogoBuscarCliente extends StatefulWidget {
  const DialogoBuscarCliente({super.key});
  @override
  State<DialogoBuscarCliente> createState() => _DialogoBuscarClienteState();
}

class _DialogoBuscarClienteState extends State<DialogoBuscarCliente> {
  List<Cliente> _todos = [];
  List<Cliente> _visibles = [];
  int? _sel;
  String? _error;
  bool _cargando = true;
  String _campo = 'Todo';
  final _texto = TextEditingController();
  final _focus = FocusNode();
  final _rebote = Antirrebote();

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _rebote.cancelar();
    _texto.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final l = (await Repo.listarClientes()).where((c) => c.estado).toList();
      if (!mounted) return;
      setState(() {
        _todos = l;
        _cargando = false;
        _filtrar();
      });
      _focus.requestFocus();
    } on OdbcError catch (e) {
      if (mounted) {
        setState(() {
          _error = e.mensaje;
          _cargando = false;
        });
      }
    }
  }

  void _filtrar() {
    final texto = _texto.text.trim();
    _sel = null;
    if (texto.isEmpty) {
      _visibles = _todos;
      return;
    }
    final t = texto.split(' ').where((x) => x.isNotEmpty).map((x) => x.toUpperCase()).toList();
    switch (_campo) {
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
      default:
        final l = texto.toLowerCase();
        _visibles = _todos
            .where(
              (c) =>
                  contieneTodas(c.documento, t) ||
                  contieneTodas(c.nombreCompleto, t) ||
                  c.codCliente.toString().contains(l) ||
                  c.idCliente.toString().contains(l),
            )
            .toList();
    }
    if (_visibles.isNotEmpty) _sel = 0;
  }

  void _elegir(int i) => Navigator.of(context).pop(_visibles[i]);

  @override
  Widget build(BuildContext context) {
    return Modal(
      titulo: 'LISTA DE CLIENTES',
      ancho: 860,
      alto: 620,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Buscar por', style: T.texto(13.5, color: C.tintaSuave)),
                const SizedBox(width: 10),
                SizedBox(
                  width: 190,
                  child: Combo<String>(
                    valor: _campo,
                    opciones: const [
                      ('Todo', 'Buscar en todo'),
                      ('CodCliente', 'Codigo Cliente'),
                      ('Documento', 'No. Documento'),
                      ('NombreCompleto', 'Nombre completo'),
                    ],
                    onChanged: (v) => setState(() {
                      _campo = v ?? 'Todo';
                      _filtrar();
                    }),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Campo(
                    controller: _texto,
                    focus: _focus,
                    hint: 'Escriba y presione Enter, o use las flechas',
                    onChanged: (_) => _rebote(() => setState(_filtrar)),
                    onSubmitted: (_) {
                      _rebote.cancelar();
                      setState(_filtrar);
                      if (_visibles.length == 1) _elegir(0);
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
                      _texto.clear();
                      setState(() {
                        _campo = 'Todo';
                        _filtrar();
                      });
                      _focus.requestFocus();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _error != null
                  ? Center(
                      child: Text(_error!, textAlign: TextAlign.center, style: T.texto(14)),
                    )
                  : _cargando
                  ? const Cargando(texto: 'Cargando clientes...')
                  : TablaDatos<Cliente>(
                      filas: _visibles,
                      seleccion: _sel,
                      onSeleccion: (i) => setState(() => _sel = i),
                      onActivar: _elegir,
                      vacio: 'Ningún cliente coincide con la búsqueda',
                      columnas: [
                        Columna('Codigo Cliente', texto: (c) => c.codCliente.toString(), cifra: true, alineacion: TextAlign.right),
                        Columna('No. Documento', texto: (c) => c.documento, maximo: 220),
                        Columna('Nombre completo', texto: (c) => c.nombreCompleto, flex: 1, maximo: 420),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('${_visibles.length} clientes · doble clic o Enter para seleccionar', style: T.texto(13, color: C.tintaSuave)),
                const Spacer(),
                Boton('Cancelar', onPressed: () => Navigator.of(context).pop()),
                const SizedBox(width: 10),
                Boton('Seleccionar', icono: Icons.check_rounded, tipo: TipoBoton.primario, onPressed: _sel == null ? null : () => _elegir(_sel!)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
