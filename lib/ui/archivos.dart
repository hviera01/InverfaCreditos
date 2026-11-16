import 'dart:io';
import 'dart:isolate';

import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/formato.dart';

String marcaTiempo() {
  final n = DateTime.now();
  String d(int v) => v.toString().padLeft(2, '0');
  return '${d(n.day)}${d(n.month)}${n.year}${d(n.hour)}${d(n.minute)}${d(n.second)}';
}

Future<String?> guardarArchivo(String nombre, List<int> bytes, String extension) async {
  final uri = await FilePicker.saveFile(fileName: nombre, bytes: Uint8List.fromList(bytes), dialogTitle: 'Guardar archivo');
  if (uri == null) return null;
  var ruta = uri.toFilePath();
  if (!ruta.toLowerCase().endsWith('.$extension')) {
    final nueva = '$ruta.$extension';
    await File(ruta).rename(nueva);
    ruta = nueva;
  }
  return ruta;
}

List<int> generarExcel(String hoja, List<String> encabezados, List<List<Object?>> filas) {
  final libro = xl.Excel.createExcel();
  final defecto = libro.getDefaultSheet() ?? 'Sheet1';
  libro.rename(defecto, hoja);
  final s = libro[hoja];
  final estiloCab = xl.CellStyle(bold: true, backgroundColorHex: xl.ExcelColor.fromHexString('#17392C'), fontColorHex: xl.ExcelColor.white);
  s.appendRow([for (final e in encabezados) xl.TextCellValue(e)]);
  for (var c = 0; c < encabezados.length; c++) {
    s.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)).cellStyle = estiloCab;
  }
  for (final f in filas) {
    s.appendRow([
      for (final v in f)
        v == null
            ? xl.TextCellValue('')
            : v is int
            ? xl.IntCellValue(v)
            : v is double
            ? xl.DoubleCellValue(r2(v))
            : xl.TextCellValue(v.toString()),
    ]);
  }
  for (var c = 0; c < encabezados.length; c++) {
    var largo = encabezados[c].length;
    for (final f in filas) {
      final t = f[c] is double ? numero2(f[c] as double) : (f[c]?.toString() ?? '');
      if (t.length > largo) largo = t.length;
    }
    s.setColumnWidth(c, (largo + 3).clamp(8, 60).toDouble());
  }
  final bytes = libro.encode();
  if (bytes == null) throw Exception('No se pudo generar el archivo de Excel.');
  return bytes;
}

Future<Uint8List> generarPdf({
  required String subtitulo,
  required List<String> encabezados,
  required List<List<String>> filas,
  required bool horizontal,
  required Uint8List fuenteRegular,
  required Uint8List fuenteNegrita,
  List<int> columnasDerecha = const [],
}) {
  final regular = pw.Font.ttf(ByteData.sublistView(fuenteRegular));
  final negrita = pw.Font.ttf(ByteData.sublistView(fuenteNegrita));
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: regular, bold: negrita),
  );
  final formato = horizontal ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;
  final generado = 'Generado: ${fechaHora(DateTime.now())}';
  final porPagina = horizontal ? 30 : 46;
  final bloques = <List<List<String>>>[for (var i = 0; i < filas.length; i += porPagina) filas.sublist(i, (i + porPagina).clamp(0, filas.length))];
  if (bloques.isEmpty) bloques.add(const []);
  final anchos = <int, pw.TableColumnWidth>{};
  for (var c = 0; c < encabezados.length; c++) {
    var largo = encabezados[c].length;
    for (final f in filas) {
      if (c < f.length && f[c].length > largo) largo = f[c].length;
    }
    anchos[c] = pw.FlexColumnWidth(largo.clamp(4, 40).toDouble());
  }
  doc.addPage(
    pw.MultiPage(
      maxPages: 100000,
      pageFormat: formato.copyWith(marginLeft: 25, marginRight: 25, marginTop: 30, marginBottom: 30),
      header: (ctx) => ctx.pageNumber == 1
          ? pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(
                  'COMERCIAL INVERFA',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: negrita, fontSize: 14),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  subtitulo,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: negrita, fontSize: 11),
                ),
                pw.SizedBox(height: 4),
                pw.Text(generado, textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8)),
                pw.SizedBox(height: 8),
              ],
            )
          : pw.SizedBox(),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
      ),
      build: (ctx) => [
        for (var b = 0; b < bloques.length; b++) ...[
          if (b > 0) pw.NewPage(),
          pw.TableHelper.fromTextArray(
            headers: encabezados,
            data: bloques[b],
            columnWidths: anchos,
            headerStyle: pw.TextStyle(font: negrita, fontSize: horizontal ? 7.5 : 8.5),
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE6E6E6)),
            cellStyle: pw.TextStyle(fontSize: horizontal ? 7 : 8),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            headerAlignment: pw.Alignment.center,
            cellAlignments: {for (final c in columnasDerecha) c: pw.Alignment.centerRight},
            border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.4),
          ),
        ],
      ],
    ),
  );
  return doc.save();
}

Future<String?> exportarExcel({
  required String nombreArchivo,
  required String hoja,
  required List<String> encabezados,
  required List<List<Object?>> filas,
}) async {
  final bytes = await Isolate.run(() => generarExcel(hoja, encabezados, filas));
  return guardarArchivo(nombreArchivo, bytes, 'xlsx');
}

Future<String?> exportarPdf({
  required String nombreArchivo,
  required String subtitulo,
  required List<String> encabezados,
  required List<List<String>> filas,
  required bool horizontal,
  List<int> columnasDerecha = const [],
}) async {
  final regular = (await rootBundle.load('assets/fonts/IBMPlexSans-Regular.ttf')).buffer.asUint8List();
  final negrita = (await rootBundle.load('assets/fonts/IBMPlexSans-Bold.ttf')).buffer.asUint8List();
  final bytes = await Isolate.run(
    () => generarPdf(
      subtitulo: subtitulo,
      encabezados: encabezados,
      filas: filas,
      horizontal: horizontal,
      fuenteRegular: regular,
      fuenteNegrita: negrita,
      columnasDerecha: columnasDerecha,
    ),
  );
  return guardarArchivo(nombreArchivo, bytes, 'pdf');
}

Future<String?> elegirExcel(String titulo) async {
  final f = await FilePicker.pickFile(dialogTitle: titulo, type: FileType.custom, allowedExtensions: ['xlsx']);
  return f?.path;
}

class HojaExcel {
  final List<List<String>> filas;
  HojaExcel(this.filas);

  String celda(int fila, int columna) {
    if (fila < 1 || fila > filas.length) return '';
    final f = filas[fila - 1];
    if (columna < 1 || columna > f.length) return '';
    return f[columna - 1];
  }

  static String texto(xl.CellValue? v) {
    if (v == null) return '';
    if (v is xl.TextCellValue) return v.value.toString();
    if (v is xl.IntCellValue) return v.value.toString();
    if (v is xl.DoubleCellValue) {
      final d = v.value;
      if (d == d.truncateToDouble() && d.abs() < 1e15) return d.toInt().toString();
      return d.toString();
    }
    if (v is xl.DateCellValue) return fechaCorta(DateTime(v.year, v.month, v.day));
    if (v is xl.DateTimeCellValue) return fechaCorta(DateTime(v.year, v.month, v.day));
    if (v is xl.BoolCellValue) return v.value ? 'TRUE' : 'FALSE';
    if (v is xl.FormulaCellValue) return '';
    return v.toString();
  }

  static Future<HojaExcel> leer(String ruta) async {
    final bytes = await File(ruta).readAsBytes();
    final libro = xl.Excel.decodeBytes(bytes);
    if (libro.tables.isEmpty) return HojaExcel(const []);
    final hoja = libro.tables[libro.tables.keys.first]!;
    return HojaExcel([
      for (final f in hoja.rows) [for (final c in f) texto(c?.value)],
    ]);
  }
}
