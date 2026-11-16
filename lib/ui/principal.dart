import 'package:flutter/material.dart';

import '../data/modelos.dart';
import 'clientes.dart';
import 'creditos.dart';
import 'login.dart';
import 'tema.dart';
import 'widgets.dart';

enum _Vista { ninguna, ventasCredito, clientes }

class PantallaPrincipal extends StatefulWidget {
  final Usuario usuario;
  const PantallaPrincipal({super.key, required this.usuario});
  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  _Vista _vista = _Vista.ninguna;
  final Set<_Vista> _abiertas = {};

  bool get _verCreditos => widget.usuario.puede('menucreditos') && widget.usuario.puede('toolStripMenuItem3');
  bool get _verClientes => widget.usuario.puede('iconMenuItmenuclientesem6');
  bool get _verAcerca => widget.usuario.puede('menuacercade');

  @override
  void initState() {
    super.initState();
    if (_verCreditos) {
      _abrir(_Vista.ventasCredito);
    } else if (_verClientes) {
      _abrir(_Vista.clientes);
    }
  }

  void _abrir(_Vista v) {
    setState(() {
      _vista = v;
      _abiertas.add(v);
    });
  }

  Future<void> _salir() async {
    if (await confirmar(context, '¿Desea salir?', titulo: 'Mensaje')) {
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (_, _, _) => const PantallaLogin(),
          transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
        ),
      );
    }
  }

  void _acercaDe() {
    showDialog<void>(
      context: context,
      builder: (ctx) => Modal(
        titulo: 'ACERCA DE',
        ancho: 520,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Image.asset('assets/img/logo.png', width: 64, height: 64),
                  const SizedBox(width: 16),
                  Expanded(child: Text('COMERCIAL INVERFA', style: T.titulo(24))),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Bienvenido a nuestro Sistema de Ventas, una solución diseñada para optimizar y gestionar de manera eficiente los procesos de ventas de su negocio. Este software fue desarrollado con el objetivo de ofrecer herramientas prácticas, modernas y funcionales para pequeños y medianos emprendedores que desean llevar el control de su inventario, clientes, y transacciones de forma sencilla y efectiva.',
                style: T.texto(14.5).copyWith(height: 1.55),
              ),
              const SizedBox(height: 22),
              Align(
                alignment: Alignment.centerRight,
                child: Boton('Aceptar', tipo: TipoBoton.primario, onPressed: () => Navigator.of(ctx).pop()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _barraSuperior(),
          _menu(),
          Expanded(child: _contenido()),
        ],
      ),
    );
  }

  Widget _barraSuperior() {
    return Container(
      height: 58,
      color: C.verde,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: PintorHexagonos(color: const Color(0x10F3EEE4), lado: 20)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              children: [
                ColorFiltered(
                  colorFilter: const ColorFilter.mode(C.papel, BlendMode.srcIn),
                  child: Image.asset('assets/img/logo.png', width: 34, height: 34, filterQuality: FilterQuality.high),
                ),
                const SizedBox(width: 14),
                Text('COMERCIAL INVERFA', maxLines: 1, softWrap: false, style: T.titulo(22, color: C.papel)),
                const Spacer(),
                Text('Usuario:', style: T.texto(13, color: const Color(0xFFCFC6AE))),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0x1AF3EEE4), borderRadius: BorderRadius.circular(3)),
                  child: Text(
                    widget.usuario.nombre,
                    maxLines: 1,
                    softWrap: false,
                    style: T.texto(14, color: C.papel, peso: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 14),
                _BotonBarra(texto: 'Salir', icono: Icons.logout_rounded, onTap: _salir),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _menu() {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: C.superficie,
        border: Border(bottom: BorderSide(color: C.linea)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          if (_verCreditos)
            _ItemMenu(
              texto: 'CREDITOS',
              icono: Icons.account_balance_wallet_outlined,
              activo: _vista == _Vista.ventasCredito,
              submenu: const ['VENTAS CREDITO'],
              onSubmenu: (_) => _abrir(_Vista.ventasCredito),
            ),
          if (_verClientes)
            _ItemMenu(texto: 'CLIENTES', icono: Icons.people_alt_outlined, activo: _vista == _Vista.clientes, onTap: () => _abrir(_Vista.clientes)),
          if (_verAcerca) _ItemMenu(texto: 'ACERCA DE', icono: Icons.info_outline_rounded, activo: false, onTap: _acercaDe),
        ],
      ),
    );
  }

  Widget _contenido() {
    if (!_verCreditos && !_verClientes) {
      return Center(
        child: Text('Su usuario no tiene permisos para Créditos ni Clientes.', style: T.texto(16, color: C.tintaSuave)),
      );
    }
    return IndexedStack(
      index: _vista == _Vista.clientes ? 1 : 0,
      children: [
        _abiertas.contains(_Vista.ventasCredito) ? const PantallaCreditos() : const SizedBox(),
        _abiertas.contains(_Vista.clientes) ? const PantallaClientes() : const SizedBox(),
      ],
    );
  }
}

class _BotonBarra extends StatefulWidget {
  final String texto;
  final IconData icono;
  final VoidCallback onTap;
  const _BotonBarra({required this.texto, required this.icono, required this.onTap});
  @override
  State<_BotonBarra> createState() => _BotonBarraState();
}

class _BotonBarraState extends State<_BotonBarra> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _h = true),
    onExit: (_) => setState(() => _h = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: _h ? C.laton : Colors.transparent,
          border: Border.all(color: _h ? C.laton : const Color(0x55F3EEE4)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icono, size: 16, color: C.papel),
            const SizedBox(width: 8),
            Text(
              widget.texto,
              style: T.texto(13.5, color: C.papel, peso: FontWeight.w600),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ItemMenu extends StatefulWidget {
  final String texto;
  final IconData icono;
  final bool activo;
  final VoidCallback? onTap;
  final List<String>? submenu;
  final ValueChanged<String>? onSubmenu;
  const _ItemMenu({required this.texto, required this.icono, required this.activo, this.onTap, this.submenu, this.onSubmenu});
  @override
  State<_ItemMenu> createState() => _ItemMenuState();
}

class _ItemMenuState extends State<_ItemMenu> {
  bool _h = false;

  Future<void> _tocar() async {
    if (widget.submenu == null) {
      widget.onTap?.call();
      return;
    }
    final box = context.findRenderObject() as RenderBox;
    final pos = box.localToGlobal(Offset(0, box.size.height));
    final r = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
      items: [
        for (final s in widget.submenu!)
          PopupMenuItem<String>(
            value: s,
            height: 44,
            child: Row(
              children: [
                const Icon(Icons.chevron_right_rounded, size: 18, color: C.laton),
                const SizedBox(width: 8),
                Text(s, style: T.texto(13.5, peso: FontWeight.w600, tracking: 0.4)),
              ],
            ),
          ),
      ],
    );
    if (r != null) widget.onSubmenu?.call(r);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.activo ? C.verde : (_h ? C.tinta : C.tintaSuave);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: _tocar,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: widget.activo ? C.verdeClaro : (_h ? C.lineaSuave : Colors.transparent),
            border: Border(bottom: BorderSide(color: widget.activo ? C.laton : Colors.transparent, width: 3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icono, size: 21, color: color),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.texto,
                    maxLines: 1,
                    softWrap: false,
                    style: T.texto(12.5, color: color, peso: FontWeight.w700, tracking: 0.8),
                  ),
                  if (widget.submenu != null) Icon(Icons.arrow_drop_down_rounded, size: 18, color: color),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
