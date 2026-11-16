import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'odbc.dart';

export 'odbc.dart' show Tabla, OdbcError;

class ConfigConexion {
  final String servidor;
  final String base;
  final String driver;
  const ConfigConexion(this.servidor, this.base, [this.driver = '']);

  static ConfigConexion leer() {
    var servidor = r'(local)\sqlexpress';
    var base = 'DB_INVERFA';
    var driver = '';
    try {
      final dir = File(Platform.resolvedExecutable).parent.path;
      final f = File('$dir${Platform.pathSeparator}conexion.ini');
      if (f.existsSync()) {
        for (final linea in f.readAsLinesSync()) {
          final i = linea.indexOf('=');
          if (i <= 0) continue;
          final k = linea.substring(0, i).trim().toLowerCase();
          final v = linea.substring(i + 1).trim();
          if (v.isEmpty) continue;
          if (k == 'servidor') servidor = v;
          if (k == 'base') base = v;
          if (k == 'driver') driver = v;
        }
      }
    } catch (_) {}
    const servidorDef = String.fromEnvironment('SERVIDOR');
    const baseDef = String.fromEnvironment('BASE');
    const driverDef = String.fromEnvironment('DRIVER');
    if (driverDef.isNotEmpty) driver = driverDef;
    if (servidorDef.isNotEmpty) servidor = servidorDef;
    if (baseDef.isNotEmpty) base = baseDef;
    return ConfigConexion(servidor, base, driver);
  }
}

class _Peticion {
  final String sql;
  final SendPort respuesta;
  _Peticion(this.sql, this.respuesta);
}

class _Trabajador {
  final ConfigConexion config;
  final ConexionOdbc con = ConexionOdbc();
  String? cadenaBuena;
  _Trabajador(this.config);

  static const drivers = [
    'ODBC Driver 18 for SQL Server',
    'ODBC Driver 17 for SQL Server',
    'ODBC Driver 13 for SQL Server',
    'ODBC Driver 11 for SQL Server',
    'SQL Server Native Client 11.0',
    'SQL Server',
  ];

  List<String> _servidores() {
    final servidores = <String>[config.servidor];
    final inst = config.servidor.contains(r'\') ? config.servidor.split(r'\').last : 'SQLEXPRESS';
    final alt = '.\\$inst';
    if (!servidores.any((s) => s.toLowerCase() == alt.toLowerCase())) servidores.add(alt);
    return servidores;
  }

  String _cadena(String driver, String servidor) {
    final extra = driver.startsWith('ODBC Driver') ? 'Encrypt=no;TrustServerCertificate=yes;' : '';
    return 'Driver={$driver};Server=$servidor;Database=${config.base};Trusted_Connection=yes;${extra}APP=Inverfa Creditos;';
  }

  void conectar() {
    if (cadenaBuena != null) {
      try {
        con.abrir(cadenaBuena!);
        return;
      } catch (_) {}
    }
    OdbcError? ultimo;
    for (final s in _servidores()) {
      for (final d in config.driver.isNotEmpty ? [config.driver] : drivers) {
        final c = _cadena(d, s);
        try {
          con.abrir(c);
          cadenaBuena = c;
          return;
        } on OdbcError catch (e) {
          if (e.estado == 'IM002') continue;
          ultimo = e;
          break;
        }
      }
    }
    throw OdbcError(
      'No se pudo conectar con SQL Server (${config.servidor}, base ${config.base}).\n'
          'Verifique que el servicio "SQL Server (SQLEXPRESS)" esté iniciado.'
          '${ultimo != null ? '\n\nDetalle: ${ultimo.mensaje}' : ''}',
      '08001',
    );
  }

  List<List<Object?>> ejecutar(String sql) {
    if (!con.abierta) conectar();
    try {
      return _serializar(con.ejecutar(sql));
    } on OdbcError catch (e) {
      if (!e.conexionPerdida) rethrow;
      con.cerrar();
      conectar();
      return _serializar(con.ejecutar(sql));
    }
  }

  List<List<Object?>> _serializar(List<Tabla> t) => [
    for (final x in t) [x.columnas, x.filas],
  ];
}

void _principal(List<Object> args) {
  final enviar = args[0] as SendPort;
  final config = ConfigConexion(args[1] as String, args[2] as String, args[3] as String);
  final recibir = ReceivePort();
  enviar.send(recibir.sendPort);
  final t = _Trabajador(config);
  recibir.listen((msg) {
    final p = msg as _Peticion;
    try {
      p.respuesta.send(['ok', t.ejecutar(p.sql)]);
    } on OdbcError catch (e) {
      p.respuesta.send(['error', e.mensaje, e.estado]);
    } catch (e) {
      p.respuesta.send(['error', e.toString(), 'HY000']);
    }
  });
}

class Db {
  static SendPort? _puerto;
  static Completer<void>? _iniciando;
  static ConfigConexion config = ConfigConexion.leer();

  static Future<void> _iniciar() async {
    if (_puerto != null) return;
    if (_iniciando != null) return _iniciando!.future;
    _iniciando = Completer<void>();
    final rp = ReceivePort();
    await Isolate.spawn(_principal, <Object>[rp.sendPort, config.servidor, config.base, config.driver]);
    _puerto = await rp.first as SendPort;
    _iniciando!.complete();
  }

  static Future<List<Tabla>> ejecutar(String sql) async {
    await _iniciar();
    final rp = ReceivePort();
    _puerto!.send(_Peticion(sql, rp.sendPort));
    final r = await rp.first as List;
    rp.close();
    if (r[0] == 'error') throw OdbcError(r[1] as String, r[2] as String);
    return [
      for (final t in r[1] as List) Tabla(List<String>.from((t as List)[0] as List), [for (final f in t[1] as List) List<String?>.from(f as List)]),
    ];
  }

  static Future<Tabla> consulta(String sql) async {
    final t = await ejecutar(sql);
    if (t.isEmpty) return Tabla(const [], const []);
    return t.first;
  }
}
