import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../data/repo.dart';
import '../db/db.dart';
import 'principal.dart';
import 'tema.dart';
import 'widgets.dart';

class PantallaLogin extends StatefulWidget {
  const PantallaLogin({super.key});
  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

enum _EstadoConexion { probando, ok, error }

class _PantallaLoginState extends State<PantallaLogin> with SingleTickerProviderStateMixin {
  final _doc = TextEditingController();
  final _clave = TextEditingController();
  final _focusDoc = FocusNode();
  final _focusClave = FocusNode();
  bool _verClave = false;
  bool _entrando = false;
  _EstadoConexion _conexion = _EstadoConexion.probando;
  String _errorConexion = '';
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  Timer? _reloj;
  DateTime _ahora = DateTime.now();

  @override
  void initState() {
    super.initState();
    _probarConexion();
    _reloj = Timer.periodic(const Duration(seconds: 20), (_) => setState(() => _ahora = DateTime.now()));
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusDoc.requestFocus());
  }

  @override
  void dispose() {
    _reloj?.cancel();
    _anim.dispose();
    _doc.dispose();
    _clave.dispose();
    _focusDoc.dispose();
    _focusClave.dispose();
    super.dispose();
  }

  Future<void> _probarConexion() async {
    setState(() => _conexion = _EstadoConexion.probando);
    try {
      await Db.consulta('SET NOCOUNT ON; SELECT 1;');
      if (mounted) setState(() => _conexion = _EstadoConexion.ok);
    } on OdbcError catch (e) {
      if (mounted) {
        setState(() {
          _conexion = _EstadoConexion.error;
          _errorConexion = e.mensaje;
        });
      }
    }
  }

  Future<void> _ingresar() async {
    if (_entrando) return;
    setState(() => _entrando = true);
    try {
      final u = await Repo.login(_doc.text, _clave.text);
      if (!mounted) return;
      if (_conexion != _EstadoConexion.ok) setState(() => _conexion = _EstadoConexion.ok);
      if (u == null) {
        await avisar(context, 'Usuario o clave incorrectos.');
        _doc.clear();
        _clave.clear();
        _focusDoc.requestFocus();
        return;
      }
      _doc.clear();
      _clave.clear();
      await Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 380),
          pageBuilder: (_, _, _) => PantallaPrincipal(usuario: u),
          transitionsBuilder: (_, a, _, child) => FadeTransition(
            opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
            child: child,
          ),
        ),
      );
    } on OdbcError catch (e) {
      if (!mounted) return;
      setState(() {
        _conexion = _EstadoConexion.error;
        _errorConexion = e.mensaje;
      });
      await avisar(context, e.mensaje, titulo: 'Sin conexión', tipo: TipoAviso.error);
    } finally {
      if (mounted) setState(() => _entrando = false);
    }
  }

  static const _dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
  static const _meses = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Expanded(flex: 11, child: _panelMarca()),
          Expanded(flex: 9, child: _panelFormulario()),
        ],
      ),
    );
  }

  Widget _panelMarca() {
    final fecha = '${_dias[_ahora.weekday - 1]} ${_ahora.day} de ${_meses[_ahora.month - 1]} de ${_ahora.year}';
    final hora = '${_ahora.hour.toString().padLeft(2, '0')}:${_ahora.minute.toString().padLeft(2, '0')}';
    return Container(
      color: C.verde,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: PintorHexagonos(color: const Color(0x14F3EEE4), lado: 46)),
          ),
          Positioned(
            right: -120,
            bottom: -140,
            child: CustomPaint(size: const Size(520, 520), painter: _HexGrande()),
          ),
          Positioned(left: 0, top: 0, bottom: 0, child: Container(width: 6, color: C.laton)),
          FadeTransition(
            opacity: CurvedAnimation(parent: _anim, curve: Curves.easeOut),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(72, 64, 64, 56),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(color: C.laton, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Text('SISTEMA DE CRÉDITOS', style: T.etiqueta(color: const Color(0xFFCFC6AE)).copyWith(letterSpacing: 2.2)),
                    ],
                  ),
                  const Spacer(),
                  ColorFiltered(
                    colorFilter: const ColorFilter.mode(Color(0xFFF3EEE4), BlendMode.srcIn),
                    child: Image.asset('assets/img/logo.png', width: 132, height: 132, filterQuality: FilterQuality.high),
                  ),
                  const SizedBox(height: 34),
                  Text(
                    'COMERCIAL',
                    style: T.texto(15, color: const Color(0xFFCFC6AE), peso: FontWeight.w600).copyWith(letterSpacing: 7),
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text('Inverfa', style: T.titulo(104, color: C.papel, peso: 560)),
                  ),
                  const SizedBox(height: 18),
                  Container(width: 120, height: 2, color: C.laton),
                  const SizedBox(height: 18),
                  Text('Créditos y clientes', style: T.titulo(26, color: const Color(0xFFE4DCC6), peso: 380)),
                  const Spacer(),
                  Row(
                    children: [
                      Text(
                        hora,
                        style: T.cifra(30, color: C.papel, peso: FontWeight.w500),
                      ),
                      const SizedBox(width: 16),
                      Text(fecha, style: T.texto(15, color: const Color(0xFFCFC6AE))),
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

  Widget _panelFormulario() {
    return Container(
      color: C.papel,
      child: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic)),
                  child: FadeTransition(
                    opacity: _anim,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('INICIO DE SESION', style: T.titulo(34)),
                        const SizedBox(height: 10),
                        Text('Ingrese su código de acceso y contraseña.', style: T.texto(14.5, color: C.tintaSuave)),
                        const SizedBox(height: 34),
                        Campo(
                          etiqueta: 'Codigo de acceso',
                          controller: _doc,
                          focus: _focusDoc,
                          formatos: [soloDigitos],
                          maxLength: 50,
                          cifra: true,
                          onSubmitted: (_) => _ingresar(),
                        ),
                        const SizedBox(height: 18),
                        Campo(
                          etiqueta: 'Contraseña',
                          controller: _clave,
                          focus: _focusClave,
                          oculto: !_verClave,
                          maxLength: 50,
                          onSubmitted: (_) => _ingresar(),
                          sufijo: IconButton(
                            tooltip: _verClave ? 'Ocultar' : 'Mostrar',
                            onPressed: () => setState(() => _verClave = !_verClave),
                            icon: Icon(_verClave ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: C.tintaSuave),
                          ),
                        ),
                        const SizedBox(height: 30),
                        Row(
                          children: [
                            Expanded(
                              child: Boton(
                                'Ingresar',
                                icono: Icons.login_rounded,
                                tipo: TipoBoton.primario,
                                alto: 46,
                                cargando: _entrando,
                                onPressed: _ingresar,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Boton('Cancelar', icono: Icons.close_rounded, alto: 46, onPressed: () => exit(0)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 34),
                        _estadoConexion(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _estadoConexion() {
    final cfg = Db.config;
    late Color color;
    late String texto;
    switch (_conexion) {
      case _EstadoConexion.probando:
        color = C.laton;
        texto = 'Conectando con la base de datos...';
        break;
      case _EstadoConexion.ok:
        color = C.ok;
        texto = 'Base de datos lista · ${cfg.base}';
        break;
      case _EstadoConexion.error:
        color = C.rojo;
        texto = 'Sin conexión con SQL Server';
        break;
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: _conexion == _EstadoConexion.error ? C.rojoSuave : C.superficie,
        border: Border.all(color: _conexion == _EstadoConexion.error ? const Color(0xFFE2B9AF) : C.lineaSuave),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Tooltip(
              message: _conexion == _EstadoConexion.error ? _errorConexion : '${cfg.servidor} · ${cfg.base}',
              child: Text(
                texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: T.texto(13, color: C.tintaSuave),
              ),
            ),
          ),
          if (_conexion == _EstadoConexion.error)
            Boton('Reintentar', alto: 32, tipo: TipoBoton.suave, icono: Icons.refresh_rounded, onPressed: _probarConexion),
        ],
      ),
    );
  }
}

class _HexGrande extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < 4; i++) {
      canvas.drawPath(
        hexagono(c, size.width / 2 - i * 42),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = i == 0 ? 2 : 1
          ..color = i == 0 ? const Color(0x55B07D27) : const Color(0x1FF3EEE4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
