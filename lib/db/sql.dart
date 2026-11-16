String sqlTexto(String? v) {
  if (v == null) return 'NULL';
  final limpio = v.replaceAll('\u0000', '').replaceAll("'", "''");
  return "N'$limpio'";
}

String sqlDecimal(double v) => v.toStringAsFixed(2);

String sqlEntero(int v) => v.toString();

String _d2(int v) => v.toString().padLeft(2, '0');

String sqlFecha(DateTime d) => "'${d.year.toString().padLeft(4, '0')}${_d2(d.month)}${_d2(d.day)}'";

String sqlFechaHora(DateTime d) =>
    "'${d.year.toString().padLeft(4, '0')}-${_d2(d.month)}-${_d2(d.day)}T${_d2(d.hour)}:${_d2(d.minute)}:${_d2(d.second)}.${d.millisecond.toString().padLeft(3, '0')}'";

String transaccion(String cuerpo) =>
    '''
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
  BEGIN TRAN;
$cuerpo
  IF @@TRANCOUNT > 0 COMMIT TRAN;
END TRY
BEGIN CATCH
  IF @@TRANCOUNT > 0 ROLLBACK TRAN;
  THROW;
END CATCH;
''';
