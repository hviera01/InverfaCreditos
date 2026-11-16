import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/formato.dart';
import 'tema.dart';

enum TipoBoton { primario, secundario, peligro, suave, laton }

class Boton extends StatefulWidget {
  final String texto;
  final IconData? icono;
  final VoidCallback? onPressed;
  final TipoBoton tipo;
  final double alto;
  final bool cargando;
  final double? ancho;
  const Boton(
    this.texto, {
    super.key,
    this.icono,
    this.onPressed,
    this.tipo = TipoBoton.secundario,
    this.alto = 38,
    this.cargando = false,
    this.ancho,
  });

  @override
  State<Boton> createState() => _BotonState();
}

class _BotonState extends State<Boton> {
  bool _hover = false;
  bool _abajo = false;

  @override
  Widget build(BuildContext context) {
    final activo = widget.onPressed != null && !widget.cargando;
    late Color fondo, texto, borde;
    switch (widget.tipo) {
      case TipoBoton.primario:
        fondo = _hover ? C.verdeMedio : C.verde;
        texto = C.blanco;
        borde = fondo;
        break;
      case TipoBoton.peligro:
        fondo = _hover ? C.rojoSuave : C.blanco;
        texto = C.rojo;
        borde = const Color(0xFFD9A79D);
        break;
      case TipoBoton.suave:
        fondo = _hover ? C.lineaSuave : Colors.transparent;
        texto = C.tinta;
        borde = Colors.transparent;
        break;
      case TipoBoton.laton:
        fondo = _hover ? const Color(0xFF9A6C1F) : C.laton;
        texto = C.blanco;
        borde = fondo;
        break;
      case TipoBoton.secundario:
        fondo = _hover ? C.lineaSuave : C.blanco;
        texto = C.tinta;
        borde = C.linea;
        break;
    }
    if (!activo) {
      fondo = fondo == Colors.transparent ? fondo : C.lineaSuave;
      texto = C.tintaTenue;
      borde = C.lineaSuave;
    }
    final contenido = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.cargando)
          SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: texto))
        else if (widget.icono != null)
          Icon(widget.icono, size: 17, color: texto),
        if ((widget.icono != null || widget.cargando) && widget.texto.isNotEmpty) const SizedBox(width: 8),
        if (widget.texto.isNotEmpty)
          Text(
            widget.texto,
            maxLines: 1,
            softWrap: false,
            style: T.texto(13.5, color: texto, peso: FontWeight.w600, tracking: 0.2),
          ),
      ],
    );
    return MouseRegion(
      cursor: activo ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _abajo = false;
      }),
      child: GestureDetector(
        onTapDown: activo ? (_) => setState(() => _abajo = true) : null,
        onTapUp: activo ? (_) => setState(() => _abajo = false) : null,
        onTapCancel: () => setState(() => _abajo = false),
        onTap: activo ? widget.onPressed : null,
        child: AnimatedScale(
          scale: _abajo ? 0.97 : 1,
          duration: const Duration(milliseconds: 90),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: widget.alto,
            width: widget.ancho,
            padding: EdgeInsets.symmetric(horizontal: widget.texto.isEmpty ? 11 : 16),
            decoration: BoxDecoration(
              color: fondo,
              border: Border.all(color: borde),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              widthFactor: 1,
              child: FittedBox(fit: BoxFit.scaleDown, child: contenido),
            ),
          ),
        ),
      ),
    );
  }
}

class Etiqueta extends StatelessWidget {
  final String texto;
  const Etiqueta(this.texto, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Text(texto, maxLines: 1, softWrap: false, overflow: TextOverflow.visible, style: T.etiqueta()),
  );
}

InputDecoration decoracionCampo({String? hint, Widget? sufijo, Widget? prefijo, bool soloLectura = false}) {
  OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(4),
    borderSide: BorderSide(color: c, width: w),
  );
  return InputDecoration(
    isDense: true,
    hintText: hint,
    hintStyle: T.texto(13.5, color: C.tintaTenue),
    filled: true,
    fillColor: soloLectura ? C.papel : C.blanco,
    contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
    border: b(C.linea),
    enabledBorder: b(C.linea),
    disabledBorder: b(C.lineaSuave),
    focusedBorder: b(soloLectura ? C.linea : C.verde, soloLectura ? 1 : 1.6),
    suffixIcon: sufijo,
    suffixIconConstraints: const BoxConstraints(minWidth: 34, minHeight: 34),
    prefixIcon: prefijo,
    prefixIconConstraints: const BoxConstraints(minWidth: 34, minHeight: 34),
  );
}

class Campo extends StatelessWidget {
  final String? etiqueta;
  final TextEditingController controller;
  final FocusNode? focus;
  final bool soloLectura;
  final bool cifra;
  final bool oculto;
  final int? maxLength;
  final List<TextInputFormatter>? formatos;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? hint;
  final int lineas;
  final bool habilitado;
  final Widget? sufijo;
  final TextAlign alineacion;
  final bool autofocus;
  const Campo({
    super.key,
    this.etiqueta,
    required this.controller,
    this.focus,
    this.soloLectura = false,
    this.cifra = false,
    this.oculto = false,
    this.maxLength,
    this.formatos,
    this.onChanged,
    this.onSubmitted,
    this.hint,
    this.lineas = 1,
    this.habilitado = true,
    this.sufijo,
    this.alineacion = TextAlign.start,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final campo = TextField(
      controller: controller,
      focusNode: focus,
      readOnly: soloLectura,
      enabled: habilitado,
      obscureText: oculto,
      autofocus: autofocus,
      maxLines: lineas,
      minLines: lineas,
      textAlign: alineacion,
      inputFormatters: [if (maxLength != null) LengthLimitingTextInputFormatter(maxLength), ...?formatos],
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: cifra ? T.cifra(14, color: habilitado ? C.tinta : C.tintaTenue) : T.texto(14, color: habilitado ? C.tinta : C.tintaTenue),
      decoration: decoracionCampo(hint: hint, soloLectura: soloLectura || !habilitado, sufijo: sufijo),
    );
    if (etiqueta == null) return campo;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Etiqueta(etiqueta!), campo]);
  }
}

final soloDigitos = FilteringTextInputFormatter.digitsOnly;

TextInputFormatter digitosTecleados(int maximo) => TextInputFormatter.withFunction((viejo, nuevo) {
  if (nuevo.text.length <= viejo.text.length) return nuevo;
  if (nuevo.text.length > maximo) return viejo;
  final insertado = nuevo.text.length - viejo.text.length;
  final fin = (nuevo.selection.end < 0 ? nuevo.text.length : nuevo.selection.end).clamp(0, nuevo.text.length);
  final ini = (fin - insertado).clamp(0, fin);
  if (!RegExp(r'^\d*$').hasMatch(nuevo.text.substring(ini, fin))) return viejo;
  return nuevo;
});
final montoFormato = TextInputFormatter.withFunction((viejo, nuevo) {
  final t = nuevo.text;
  if (t.isEmpty) return nuevo;
  if (!RegExp(r'^\d*\.?\d{0,2}$').hasMatch(t)) return viejo;
  return nuevo;
});
final porcentajeFormato = TextInputFormatter.withFunction((viejo, nuevo) {
  final t = nuevo.text;
  if (t.isEmpty) return nuevo;
  if (!RegExp(r'^\d*\.?\d{0,4}$').hasMatch(t)) return viejo;
  return nuevo;
});

class Combo<V> extends StatelessWidget {
  final String? etiqueta;
  final V? valor;
  final List<(V, String)> opciones;
  final ValueChanged<V?>? onChanged;
  const Combo({super.key, this.etiqueta, required this.valor, required this.opciones, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final habilitado = onChanged != null;
    final caja = Container(
      height: 40,
      padding: const EdgeInsets.only(left: 11, right: 6),
      decoration: BoxDecoration(
        color: habilitado ? C.blanco : C.papel,
        border: Border.all(color: habilitado ? C.linea : C.lineaSuave),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<V>(
          value: valor,
          isExpanded: true,
          focusColor: Colors.transparent,
          dropdownColor: C.blanco,
          borderRadius: BorderRadius.circular(4),
          icon: Icon(Icons.expand_more_rounded, color: habilitado ? C.tintaSuave : C.tintaTenue),
          style: T.texto(14, color: habilitado ? C.tinta : C.tintaTenue),
          items: [
            for (final o in opciones)
              DropdownMenuItem<V>(
                value: o.$1,
                child: Text(o.$2, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
    if (etiqueta == null) return caja;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Etiqueta(etiqueta!), caja]);
  }
}

class CampoFecha extends StatelessWidget {
  final String? etiqueta;
  final DateTime valor;
  final ValueChanged<DateTime>? onChanged;
  const CampoFecha({super.key, this.etiqueta, required this.valor, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final habilitado = onChanged != null;
    final caja = MouseRegion(
      cursor: habilitado ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: !habilitado
            ? null
            : () async {
                final f = await showDatePicker(
                  context: context,
                  initialDate: valor,
                  firstDate: DateTime(1990),
                  lastDate: DateTime(2100),
                  locale: const Locale('es'),
                );
                if (f != null) onChanged!(f);
              },
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: habilitado ? C.blanco : C.papel,
            border: Border.all(color: habilitado ? C.linea : C.lineaSuave),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Text(fechaCorta(valor), style: T.cifra(14, color: habilitado ? C.tinta : C.tintaSuave)),
              const Spacer(),
              Icon(Icons.calendar_today_outlined, size: 16, color: habilitado ? C.verde : C.tintaTenue),
            ],
          ),
        ),
      ),
    );
    if (etiqueta == null) return caja;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Etiqueta(etiqueta!), caja]);
  }
}

class Insignia extends StatelessWidget {
  final String texto;
  final Color fondo;
  final Color color;
  const Insignia(this.texto, {super.key, required this.fondo, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(3)),
    child: Text(
      texto,
      maxLines: 1,
      softWrap: false,
      style: T.texto(12, color: color, peso: FontWeight.w600, tracking: 0.3),
    ),
  );
}

class Columna<R> {
  final String titulo;
  final double? ancho;
  final double minimo;
  final double maximo;
  final int flex;
  final TextAlign alineacion;
  final String Function(R fila) texto;
  final Widget Function(R fila, bool seleccionada)? celda;
  final bool cifra;
  const Columna(
    this.titulo, {
    required this.texto,
    this.ancho,
    this.minimo = 60,
    this.maximo = 360,
    this.flex = 0,
    this.alineacion = TextAlign.left,
    this.celda,
    this.cifra = false,
  });
}

class TablaDatos<R> extends StatefulWidget {
  final List<Columna<R>> columnas;
  final List<R> filas;
  final int? seleccion;
  final ValueChanged<int>? onSeleccion;
  final ValueChanged<int>? onActivar;
  final Color? Function(R fila)? colorFila;
  final String vacio;
  final FocusNode? focus;
  const TablaDatos({
    super.key,
    required this.columnas,
    required this.filas,
    this.seleccion,
    this.onSeleccion,
    this.onActivar,
    this.colorFila,
    this.vacio = 'Sin registros',
    this.focus,
  });

  @override
  State<TablaDatos<R>> createState() => _TablaDatosState<R>();
}

class _TablaDatosState<R> extends State<TablaDatos<R>> {
  static const altoFila = 36.0;
  static const altoCabecera = 40.0;
  final _vertical = ScrollController();
  final _horizontal = ScrollController();
  late final FocusNode _focus = widget.focus ?? FocusNode();
  List<double>? _anchosCache;
  Object? _claveCache;

  @override
  void dispose() {
    _vertical.dispose();
    _horizontal.dispose();
    if (widget.focus == null) _focus.dispose();
    super.dispose();
  }

  double _medir(String t, TextStyle s) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: s),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return tp.width;
  }

  List<double> _anchosNaturales() {
    final clave = Object.hash(identityHashCode(widget.filas), widget.filas.length, widget.columnas.length);
    if (_anchosCache != null && clave == _claveCache) return _anchosCache!;
    final estiloCab = T.etiqueta();
    final res = <double>[];
    for (final c in widget.columnas) {
      if (c.ancho != null) {
        res.add(math.max(c.ancho!, _medir(c.titulo.toUpperCase(), estiloCab) + 28));
        continue;
      }
      var m = _medir(c.titulo.toUpperCase(), estiloCab) + 28;
      final estilo = c.cifra ? T.cifra(13.5) : T.texto(13.5);
      final muestras = widget.filas.length > 4000 ? widget.filas.take(4000) : widget.filas;
      var maxLen = 0;
      String? masLargo;
      for (final f in muestras) {
        final t = c.texto(f);
        if (t.length > maxLen) {
          maxLen = t.length;
          masLargo = t;
        }
      }
      if (masLargo != null) m = math.max(m, _medir(masLargo, estilo) * 1.04 + 30);
      res.add(m.clamp(c.minimo, math.max(c.maximo, c.minimo)));
    }
    _anchosCache = res;
    _claveCache = clave;
    return res;
  }

  List<double> _anchos(double disponible) {
    final base = List<double>.from(_anchosNaturales());
    final total = base.fold<double>(0, (a, b) => a + b);
    if (total < disponible) {
      final flexTotal = widget.columnas.fold<int>(0, (a, c) => a + c.flex);
      final extra = disponible - total;
      for (var i = 0; i < base.length; i++) {
        if (flexTotal > 0) {
          base[i] += extra * widget.columnas[i].flex / flexTotal;
        } else {
          base[i] += extra / base.length;
        }
      }
    }
    return base;
  }

  void _mover(int delta) {
    if (widget.filas.isEmpty || widget.onSeleccion == null) return;
    final actual = widget.seleccion ?? -1;
    final nuevo = (actual + delta).clamp(0, widget.filas.length - 1);
    widget.onSeleccion!(nuevo);
    final alto = _vertical.position.viewportDimension;
    final top = nuevo * altoFila;
    if (top < _vertical.offset) {
      _vertical.jumpTo(top);
    } else if (top + altoFila > _vertical.offset + alto) {
      _vertical.jumpTo(top + altoFila - alto);
    }
  }

  KeyEventResult _tecla(FocusNode n, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
      _mover(1);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
      _mover(-1);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.pageDown) {
      _mover(12);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.pageUp) {
      _mover(-12);
      return KeyEventResult.handled;
    }
    if ((e.logicalKey == LogicalKeyboardKey.enter || e.logicalKey == LogicalKeyboardKey.numpadEnter) &&
        widget.seleccion != null &&
        widget.onActivar != null) {
      widget.onActivar!(widget.seleccion!);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      onKeyEvent: _tecla,
      child: Container(
        decoration: BoxDecoration(
          color: C.blanco,
          border: Border.all(color: C.linea),
          borderRadius: BorderRadius.circular(4),
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, cons) {
            final anchos = _anchos(cons.maxWidth - 2);
            final total = anchos.fold<double>(0, (a, b) => a + b);
            return Scrollbar(
              controller: _horizontal,
              notificationPredicate: (n) => n.depth == 0,
              child: SingleChildScrollView(
                controller: _horizontal,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: math.max(total, cons.maxWidth - 2),
                  child: Column(
                    children: [
                      _cabecera(anchos),
                      Expanded(
                        child: widget.filas.isEmpty
                            ? Center(
                                child: Text(widget.vacio, style: T.texto(14, color: C.tintaTenue)),
                              )
                            : Scrollbar(
                                controller: _vertical,
                                child: ListView.builder(
                                  controller: _vertical,
                                  itemExtent: altoFila,
                                  itemCount: widget.filas.length,
                                  itemBuilder: (context, i) => _fila(i, anchos),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _cabecera(List<double> anchos) => Container(
    height: altoCabecera,
    decoration: const BoxDecoration(color: C.verde),
    child: Row(
      children: [
        for (var i = 0; i < widget.columnas.length; i++)
          Container(
            width: anchos[i],
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: _alinear(widget.columnas[i].alineacion),
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: i == widget.columnas.length - 1 ? Colors.transparent : const Color(0x22FFFFFF))),
            ),
            child: Text(
              widget.columnas[i].titulo.toUpperCase(),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: T.etiqueta(color: const Color(0xFFE9E1CC)),
            ),
          ),
      ],
    ),
  );

  Alignment _alinear(TextAlign a) => a == TextAlign.right
      ? Alignment.centerRight
      : a == TextAlign.center
      ? Alignment.center
      : Alignment.centerLeft;

  Widget _fila(int i, List<double> anchos) {
    final f = widget.filas[i];
    final sel = widget.seleccion == i;
    final colorBase = widget.colorFila?.call(f);
    final fondo = sel ? C.seleccion : (colorBase ?? (i.isOdd ? const Color(0xFFF8F5EE) : C.blanco));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _focus.requestFocus();
        widget.onSeleccion?.call(i);
      },
      onDoubleTap: widget.onActivar == null ? null : () => widget.onActivar!(i),
      child: Container(
        decoration: BoxDecoration(
          color: fondo,
          border: Border(
            bottom: const BorderSide(color: C.lineaSuave),
            left: BorderSide(color: sel ? C.laton : Colors.transparent, width: 3),
          ),
        ),
        child: Row(
          children: [
            for (var c = 0; c < widget.columnas.length; c++)
              SizedBox(
                width: c == 0 ? anchos[c] - 3 : anchos[c],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Align(
                    alignment: _alinear(widget.columnas[c].alineacion),
                    child: widget.columnas[c].celda?.call(f, sel) ?? _texto(widget.columnas[c], f),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _texto(Columna<R> c, R f) {
    final t = c.texto(f);
    final w = Text(
      t,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      textAlign: c.alineacion,
      style: c.cifra ? T.cifra(13.5) : T.texto(13.5),
    );
    return Tooltip(message: t.length > 28 ? t : '', child: w);
  }
}

class PintorHexagonos extends CustomPainter {
  final Color color;
  final double lado;
  PintorHexagonos({required this.color, this.lado = 34});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final w = math.sqrt(3) * lado;
    final h = 1.5 * lado;
    for (var fila = -1; fila * h < size.height + lado; fila++) {
      for (var col = -1; col * w < size.width + w; col++) {
        final cx = col * w + (fila.isOdd ? w / 2 : 0);
        final cy = fila * h;
        canvas.drawPath(hexagono(Offset(cx, cy), lado), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PintorHexagonos old) => old.color != color || old.lado != lado;
}

Path hexagono(Offset c, double r) {
  final path = Path();
  for (var i = 0; i < 6; i++) {
    final a = math.pi / 180 * (60 * i - 90);
    final pt = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
    if (i == 0) {
      path.moveTo(pt.dx, pt.dy);
    } else {
      path.lineTo(pt.dx, pt.dy);
    }
  }
  return path..close();
}

class Modal extends StatelessWidget {
  final String titulo;
  final Widget child;
  final double ancho;
  final double? alto;
  final VoidCallback? onCerrar;
  const Modal({super.key, required this.titulo, required this.child, required this.ancho, this.alto, this.onCerrar});

  @override
  Widget build(BuildContext context) {
    final pantalla = MediaQuery.of(context).size;
    return Dialog(
      backgroundColor: C.superficie,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: math.min(ancho, pantalla.width - 40), maxHeight: pantalla.height - 40),
        child: SizedBox(
          width: ancho,
          height: alto == null ? null : math.min(alto!, pantalla.height - 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 56,
                color: C.verde,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.5,
                        child: CustomPaint(painter: PintorHexagonos(color: const Color(0x1FFFFFFF), lado: 18)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 22, right: 8),
                      child: Row(
                        children: [
                          Container(width: 4, height: 22, color: C.laton),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              titulo,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: T.titulo(20, color: C.blanco),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Cerrar',
                            onPressed: onCerrar ?? () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded, color: C.blanco),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class Seccion extends StatelessWidget {
  final String titulo;
  final Widget child;
  final EdgeInsets padding;
  const Seccion({super.key, required this.titulo, required this.child, this.padding = const EdgeInsets.fromLTRB(18, 16, 18, 18)});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: C.blanco,
      border: Border.all(color: C.linea),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 11, 18, 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: C.lineaSuave)),
          ),
          child: Row(
            children: [
              CustomPaint(size: const Size(12, 12), painter: _MiniHex()),
              const SizedBox(width: 9),
              Text(titulo, maxLines: 1, softWrap: false, style: T.etiqueta(color: C.verde).copyWith(fontSize: 12.5, letterSpacing: 1.1)),
            ],
          ),
        ),
        Padding(padding: padding, child: child),
      ],
    ),
  );
}

class _MiniHex extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      hexagono(Offset(size.width / 2, size.height / 2), size.width / 2),
      Paint()
        ..color = C.laton
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

enum TipoAviso { info, advertencia, error }

Future<void> avisar(BuildContext context, String mensaje, {String titulo = 'Mensaje', TipoAviso tipo = TipoAviso.advertencia}) {
  final color = tipo == TipoAviso.error ? C.rojo : (tipo == TipoAviso.info ? C.verde : C.laton);
  final icono = tipo == TipoAviso.error
      ? Icons.error_outline_rounded
      : (tipo == TipoAviso.info ? Icons.info_outline_rounded : Icons.warning_amber_rounded);
  return showDialog<void>(
    context: context,
    builder: (ctx) => _DialogoSimple(
      color: color,
      icono: icono,
      titulo: titulo,
      mensaje: mensaje,
      acciones: [Boton('Aceptar', tipo: TipoBoton.primario, onPressed: () => Navigator.of(ctx).pop())],
    ),
  );
}

Future<bool> confirmar(
  BuildContext context,
  String mensaje, {
  String titulo = 'Confirmar',
  String si = 'Sí',
  String no = 'No',
  bool peligro = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => _DialogoSimple(
      color: peligro ? C.rojo : C.verde,
      icono: peligro ? Icons.delete_forever_outlined : Icons.help_outline_rounded,
      titulo: titulo,
      mensaje: mensaje,
      acciones: [
        Boton(no, onPressed: () => Navigator.of(ctx).pop(false)),
        const SizedBox(width: 10),
        Boton(si, tipo: peligro ? TipoBoton.peligro : TipoBoton.primario, onPressed: () => Navigator.of(ctx).pop(true)),
      ],
    ),
  );
  return r ?? false;
}

class _DialogoSimple extends StatelessWidget {
  final Color color;
  final IconData icono;
  final String titulo;
  final String mensaje;
  final List<Widget> acciones;
  const _DialogoSimple({required this.color, required this.icono, required this.titulo, required this.mensaje, required this.acciones});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: C.superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, minWidth: 380),
        child: CallbackShortcuts(
          bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).pop()},
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(height: 5, color: color),
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 24, 26, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icono, color: color, size: 30),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(titulo, style: T.titulo(21)),
                          const SizedBox(height: 10),
                          Text(mensaje, style: T.texto(14.5, color: C.tinta).copyWith(height: 1.45)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 18, 26, 22),
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: acciones),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void exito(BuildContext context, String mensaje) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entrada;
  entrada = OverlayEntry(
    builder: (_) => _CheckExito(mensaje: mensaje, alTerminar: () => entrada.remove()),
  );
  overlay.insert(entrada);
}

class _CheckExito extends StatefulWidget {
  final String mensaje;
  final VoidCallback alTerminar;
  const _CheckExito({required this.mensaje, required this.alTerminar});
  @override
  State<_CheckExito> createState() => _CheckExitoState();
}

class _CheckExitoState extends State<_CheckExito> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2300));

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(() {
      if (mounted) widget.alTerminar();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final entrada = Curves.easeOutBack.transform((t / 0.18).clamp(0.0, 1.0));
          final salida = 1 - Curves.easeIn.transform(((t - 0.82) / 0.18).clamp(0.0, 1.0));
          final trazo = Curves.easeOutCubic.transform(((t - 0.12) / 0.22).clamp(0.0, 1.0));
          return Opacity(
            opacity: salida.clamp(0.0, 1.0),
            child: Container(
              color: Color.fromRGBO(23, 57, 44, 0.10 * salida),
              alignment: Alignment.center,
              child: Transform.scale(
                scale: 0.85 + 0.15 * entrada,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 300, maxWidth: 460),
                  padding: const EdgeInsets.fromLTRB(36, 30, 36, 28),
                  decoration: BoxDecoration(
                    color: C.blanco,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFBFDCC8)),
                    boxShadow: const [BoxShadow(color: Color(0x2917392C), blurRadius: 40, offset: Offset(0, 14))],
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 86, height: 86, child: CustomPaint(painter: _PintorCheck(trazo, entrada))),
                        const SizedBox(height: 18),
                        Text(
                          widget.mensaje,
                          textAlign: TextAlign.center,
                          style: T.titulo(19, color: C.tinta),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PintorCheck extends CustomPainter {
  final double trazo;
  final double escala;
  _PintorCheck(this.trazo, this.escala);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    canvas.drawPath(hexagono(c, r * escala.clamp(0.0, 1.2)), Paint()..color = C.okSuave);
    canvas.drawPath(
      hexagono(c, r * escala.clamp(0.0, 1.2)),
      Paint()
        ..color = C.ok
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    final path = Path()
      ..moveTo(size.width * 0.29, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.66)
      ..lineTo(size.width * 0.72, size.height * 0.37);
    final metrica = path.computeMetrics().first;
    final parcial = metrica.extractPath(0, metrica.length * trazo);
    canvas.drawPath(
      parcial,
      Paint()
        ..color = C.ok
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _PintorCheck old) => old.trazo != trazo || old.escala != escala;
}

class Antirrebote {
  final Duration espera;
  Timer? _t;
  Antirrebote([this.espera = const Duration(milliseconds: 250)]);
  void call(VoidCallback f) {
    _t?.cancel();
    _t = Timer(espera, f);
  }

  void cancelar() => _t?.cancel();
}

class Cargando extends StatelessWidget {
  final String texto;
  const Cargando({super.key, this.texto = 'Cargando...'});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 34, height: 34, child: CircularProgressIndicator(strokeWidth: 2.6, color: C.verde)),
        const SizedBox(height: 14),
        Text(texto, style: T.texto(14, color: C.tintaSuave)),
      ],
    ),
  );
}
