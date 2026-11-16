import 'dart:ffi';

import 'package:ffi/ffi.dart';

typedef _AllocHandleN = Int16 Function(Int16, Pointer<Void>, Pointer<Pointer<Void>>);
typedef _AllocHandleD = int Function(int, Pointer<Void>, Pointer<Pointer<Void>>);
typedef _SetAttrN = Int16 Function(Pointer<Void>, Int32, Pointer<Void>, Int32);
typedef _SetAttrD = int Function(Pointer<Void>, int, Pointer<Void>, int);
typedef _DriverConnectN = Int16 Function(Pointer<Void>, Pointer<Void>, Pointer<Uint16>, Int16, Pointer<Uint16>, Int16, Pointer<Int16>, Uint16);
typedef _DriverConnectD = int Function(Pointer<Void>, Pointer<Void>, Pointer<Uint16>, int, Pointer<Uint16>, int, Pointer<Int16>, int);
typedef _ExecDirectN = Int16 Function(Pointer<Void>, Pointer<Uint16>, Int32);
typedef _ExecDirectD = int Function(Pointer<Void>, Pointer<Uint16>, int);
typedef _NumColsN = Int16 Function(Pointer<Void>, Pointer<Int16>);
typedef _NumColsD = int Function(Pointer<Void>, Pointer<Int16>);
typedef _DescribeColN =
    Int16 Function(Pointer<Void>, Uint16, Pointer<Uint16>, Int16, Pointer<Int16>, Pointer<Int16>, Pointer<Uint64>, Pointer<Int16>, Pointer<Int16>);
typedef _DescribeColD =
    int Function(Pointer<Void>, int, Pointer<Uint16>, int, Pointer<Int16>, Pointer<Int16>, Pointer<Uint64>, Pointer<Int16>, Pointer<Int16>);
typedef _StmtN = Int16 Function(Pointer<Void>);
typedef _StmtD = int Function(Pointer<Void>);
typedef _GetDataN = Int16 Function(Pointer<Void>, Uint16, Int16, Pointer<Void>, Int64, Pointer<Int64>);
typedef _GetDataD = int Function(Pointer<Void>, int, int, Pointer<Void>, int, Pointer<Int64>);
typedef _FreeHandleN = Int16 Function(Int16, Pointer<Void>);
typedef _FreeHandleD = int Function(int, Pointer<Void>);
typedef _DiagN = Int16 Function(Int16, Pointer<Void>, Int16, Pointer<Uint16>, Pointer<Int32>, Pointer<Uint16>, Int16, Pointer<Int16>);
typedef _DiagD = int Function(int, Pointer<Void>, int, Pointer<Uint16>, Pointer<Int32>, Pointer<Uint16>, int, Pointer<Int16>);

const _handleEnv = 1;
const _handleDbc = 2;
const _handleStmt = 3;
const _success = 0;
const _successInfo = 1;
const _noData = 100;
const _nullData = -1;
const _noTotal = -4;
const _cWchar = -8;

class OdbcError implements Exception {
  final String mensaje;
  final String estado;
  OdbcError(this.mensaje, this.estado);
  bool get conexionPerdida => estado.startsWith('08');
  @override
  String toString() => mensaje;
}

class Tabla {
  final List<String> columnas;
  final List<List<String?>> filas;
  Tabla(this.columnas, this.filas);

  int indice(String col) {
    final i = columnas.indexWhere((c) => c.toLowerCase() == col.toLowerCase());
    if (i < 0) throw StateError('Columna $col no existe');
    return i;
  }
}

class _Api {
  final DynamicLibrary lib = DynamicLibrary.open('odbc32.dll');
  late final allocHandle = lib.lookupFunction<_AllocHandleN, _AllocHandleD>('SQLAllocHandle');
  late final setEnvAttr = lib.lookupFunction<_SetAttrN, _SetAttrD>('SQLSetEnvAttr');
  late final setConnectAttr = lib.lookupFunction<_SetAttrN, _SetAttrD>('SQLSetConnectAttrW');
  late final driverConnect = lib.lookupFunction<_DriverConnectN, _DriverConnectD>('SQLDriverConnectW');
  late final execDirect = lib.lookupFunction<_ExecDirectN, _ExecDirectD>('SQLExecDirectW');
  late final numCols = lib.lookupFunction<_NumColsN, _NumColsD>('SQLNumResultCols');
  late final describeCol = lib.lookupFunction<_DescribeColN, _DescribeColD>('SQLDescribeColW');
  late final fetch = lib.lookupFunction<_StmtN, _StmtD>('SQLFetch');
  late final moreResults = lib.lookupFunction<_StmtN, _StmtD>('SQLMoreResults');
  late final getData = lib.lookupFunction<_GetDataN, _GetDataD>('SQLGetData');
  late final freeHandle = lib.lookupFunction<_FreeHandleN, _FreeHandleD>('SQLFreeHandle');
  late final disconnect = lib.lookupFunction<_StmtN, _StmtD>('SQLDisconnect');
  late final diag = lib.lookupFunction<_DiagN, _DiagD>('SQLGetDiagRecW');
}

class ConexionOdbc {
  static final _Api _api = _Api();
  Pointer<Void> _env = nullptr;
  Pointer<Void> _dbc = nullptr;

  bool get abierta => _dbc != nullptr;

  void abrir(String cadena, {int timeoutSegundos = 8}) {
    cerrar();
    final p = calloc<Pointer<Void>>();
    try {
      _ok(_api.allocHandle(_handleEnv, nullptr, p), _handleEnv, nullptr);
      _env = p.value;
      _ok(_api.setEnvAttr(_env, 200, Pointer.fromAddress(3), 0), _handleEnv, _env);
      _ok(_api.allocHandle(_handleDbc, _env, p), _handleEnv, _env);
      _dbc = p.value;
      _api.setConnectAttr(_dbc, 103, Pointer.fromAddress(timeoutSegundos), 0);
      final cs = cadena.toNativeUtf16().cast<Uint16>();
      final outLen = calloc<Int16>();
      try {
        final rc = _api.driverConnect(_dbc, nullptr, cs, cadena.length, nullptr, 0, outLen, 0);
        _ok(rc, _handleDbc, _dbc);
      } finally {
        calloc.free(cs);
        calloc.free(outLen);
      }
    } catch (_) {
      _liberar();
      rethrow;
    } finally {
      calloc.free(p);
    }
  }

  List<Tabla> ejecutar(String sql) {
    if (!abierta) throw OdbcError('No hay conexión con la base de datos.', '08003');
    final p = calloc<Pointer<Void>>();
    _ok(_api.allocHandle(_handleStmt, _dbc, p), _handleDbc, _dbc);
    final stmt = p.value;
    calloc.free(p);
    final texto = sql.toNativeUtf16().cast<Uint16>();
    final tablas = <Tabla>[];
    try {
      var rc = _api.execDirect(stmt, texto, sql.length);
      if (rc == _noData) return tablas;
      _ok(rc, _handleStmt, stmt);
      while (true) {
        final t = _leerResultado(stmt);
        if (t != null) tablas.add(t);
        rc = _api.moreResults(stmt);
        if (rc == _noData) break;
        _ok(rc, _handleStmt, stmt);
      }
      return tablas;
    } finally {
      calloc.free(texto);
      _api.freeHandle(_handleStmt, stmt);
    }
  }

  Tabla? _leerResultado(Pointer<Void> stmt) {
    final nCols = calloc<Int16>();
    try {
      _ok(_api.numCols(stmt, nCols), _handleStmt, stmt);
      final n = nCols.value;
      if (n <= 0) return null;
      final columnas = <String>[];
      final nombre = calloc<Uint16>(256);
      final largo = calloc<Int16>();
      final tipo = calloc<Int16>();
      final tam = calloc<Uint64>();
      final dec = calloc<Int16>();
      final nul = calloc<Int16>();
      try {
        for (var c = 1; c <= n; c++) {
          _ok(_api.describeCol(stmt, c, nombre, 256, largo, tipo, tam, dec, nul), _handleStmt, stmt);
          columnas.add(String.fromCharCodes(nombre.asTypedList(largo.value.clamp(0, 255))));
        }
      } finally {
        calloc.free(nombre);
        calloc.free(largo);
        calloc.free(tipo);
        calloc.free(tam);
        calloc.free(dec);
        calloc.free(nul);
      }
      const bytes = 8192;
      final buf = calloc<Uint16>(bytes ~/ 2);
      final ind = calloc<Int64>();
      final filas = <List<String?>>[];
      try {
        while (true) {
          final rc = _api.fetch(stmt);
          if (rc == _noData) break;
          _ok(rc, _handleStmt, stmt);
          final fila = List<String?>.filled(n, null);
          for (var c = 1; c <= n; c++) {
            final sb = StringBuffer();
            var esNulo = false;
            while (true) {
              final r = _api.getData(stmt, c, _cWchar, buf.cast(), bytes, ind);
              if (r == _noData) break;
              _ok(r, _handleStmt, stmt);
              final len = ind.value;
              if (len == _nullData) {
                esNulo = true;
                break;
              }
              final truncado = r == _successInfo && (len == _noTotal || len >= bytes - 2);
              final chars = truncado ? (bytes ~/ 2) - 1 : len ~/ 2;
              sb.write(String.fromCharCodes(buf.asTypedList(chars)));
              if (!truncado) break;
            }
            fila[c - 1] = esNulo ? null : sb.toString();
          }
          filas.add(fila);
        }
      } finally {
        calloc.free(buf);
        calloc.free(ind);
      }
      return Tabla(columnas, filas);
    } finally {
      calloc.free(nCols);
    }
  }

  void _ok(int rc, int tipo, Pointer<Void> handle) {
    if (rc == _success || rc == _successInfo) return;
    throw _diagnostico(tipo, handle);
  }

  OdbcError _diagnostico(int tipo, Pointer<Void> handle) {
    final estado = calloc<Uint16>(6);
    final nativo = calloc<Int32>();
    final msg = calloc<Uint16>(2048);
    final largo = calloc<Int16>();
    final mensajes = <String>[];
    var primerEstado = 'HY000';
    try {
      if (handle == nullptr) return OdbcError('Error de ODBC.', primerEstado);
      for (var i = 1; i <= 10; i++) {
        final rc = _api.diag(tipo, handle, i, estado, nativo, msg, 2048, largo);
        if (rc != _success && rc != _successInfo) break;
        if (i == 1) primerEstado = String.fromCharCodes(estado.asTypedList(5));
        final m = String.fromCharCodes(msg.asTypedList(largo.value.clamp(0, 2047)));
        final limpio = m.replaceAll(RegExp(r'^(\[[^\]]*\])+\s*'), '').trim();
        if (limpio.isNotEmpty && !mensajes.contains(limpio)) mensajes.add(limpio);
      }
    } finally {
      calloc.free(estado);
      calloc.free(nativo);
      calloc.free(msg);
      calloc.free(largo);
    }
    return OdbcError(mensajes.isEmpty ? 'Error desconocido de base de datos.' : mensajes.join('\n'), primerEstado);
  }

  void cerrar() {
    if (_dbc != nullptr) _api.disconnect(_dbc);
    _liberar();
  }

  void _liberar() {
    if (_dbc != nullptr) _api.freeHandle(_handleDbc, _dbc);
    if (_env != nullptr) _api.freeHandle(_handleEnv, _env);
    _dbc = nullptr;
    _env = nullptr;
  }
}
