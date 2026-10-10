import 'dart:io';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Visor interactivo para hojas de cálculo Excel (.xlsx, .xls) y archivos CSV (.csv)
/// diseñado con la interfaz oficial de Microsoft Excel Mobile (barra verde, encabezados A/B/C y 1/2/3, barra fx).
class VisorExcel extends StatefulWidget {
  final File? archivoLocal;
  final String urlRemota;
  final String nombreArchivo;

  const VisorExcel({
    super.key,
    this.archivoLocal,
    required this.urlRemota,
    required this.nombreArchivo,
  });

  @override
  State<VisorExcel> createState() => _VisorExcelState();
}

class _VisorExcelState extends State<VisorExcel> {
  bool _cargando = true;
  String? _mensajeError;
  bool _usarVisorWeb = false;
  WebViewController? _webViewController;

  Map<String, List<List<String>>> _hojasDatos = {};
  String _hojaSeleccionada = '';
  String _celdaSeleccionadaRef = 'A1';
  String _celdaSeleccionadaValor = '';

  @override
  void initState() {
    super.initState();
    _evaluarYCargar();
  }

  void _evaluarYCargar() {
    final url = widget.urlRemota.trim();
    final esUrlPublica = url.startsWith('http://') || url.startsWith('https://');

    if (esUrlPublica) {
      _usarVisorWeb = true;
      final urlOficialOffice = 'https://view.officeapps.live.com/op/embed.aspx?src=${Uri.encodeComponent(url)}';
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFF107C41))
        ..loadRequest(Uri.parse(urlOficialOffice));
      setState(() => _cargando = false);
    } else {
      _usarVisorWeb = false;
      _cargarExcelLocal();
    }
  }

  Future<void> _cargarExcelLocal() async {
    setState(() {
      _cargando = true;
      _mensajeError = null;
    });

    try {
      File? f = widget.archivoLocal;
      if (f == null || !f.existsSync()) {
        final url = widget.urlRemota.trim();
        if (url.isNotEmpty && !url.startsWith('http') && File(url).existsSync()) {
          f = File(url);
        }
      }

      if (f == null || !f.existsSync()) {
        throw Exception('El archivo de hoja de cálculo no existe localmente.');
      }

      final bytes = await f.readAsBytes();
      final extension = widget.nombreArchivo.toLowerCase();

      final resultHojas = <String, List<List<String>>>{};

      if (extension.endsWith('.csv')) {
        final content = String.fromCharCodes(bytes);
        final lines = content.split(RegExp(r'\r?\n'));
        final rows = <List<String>>[];
        for (final l in lines) {
          if (l.trim().isEmpty) continue;
          rows.add(l.split(',').map((e) => e.replaceAll('"', '').trim()).toList());
        }
        resultHojas['Hoja1'] = rows;
      } else {
        final excel = Excel.decodeBytes(bytes);
        for (final table in excel.tables.keys) {
          final sheet = excel.tables[table];
          if (sheet != null) {
            final rows = <List<String>>[];
            for (final row in sheet.rows) {
              final rowCells = <String>[];
              for (final cell in row) {
                rowCells.add(cell?.value?.toString() ?? '');
              }
              if (rowCells.any((c) => c.trim().isNotEmpty)) {
                rows.add(rowCells);
              }
            }
            if (rows.isNotEmpty) {
              resultHojas[table] = rows;
            }
          }
        }
      }

      if (resultHojas.isEmpty) {
        throw Exception('La hoja de cálculo está vacía.');
      }

      if (mounted) {
        final primeraHoja = resultHojas.keys.first;
        final primerFila = resultHojas[primeraHoja]?.firstOrNull;
        setState(() {
          _hojasDatos = resultHojas;
          _hojaSeleccionada = primeraHoja;
          _celdaSeleccionadaRef = 'A1';
          _celdaSeleccionadaValor = (primerFila != null && primerFila.isNotEmpty) ? primerFila.first : '';
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _mensajeError = 'Error al procesar hoja de cálculo: $e';
          _cargando = false;
        });
      }
    }
  }

  Future<void> _abrirEnAppExterna() async {
    final path = widget.archivoLocal?.path ?? widget.urlRemota;
    if (path.isNotEmpty) {
      await OpenFilex.open(path);
    }
  }

  String _obtenerLetraColumna(int index) {
    String res = '';
    while (index >= 0) {
      res = String.fromCharCode((index % 26) + 65) + res;
      index = (index ~/ 26) - 1;
    }
    return res;
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return Container(
        height: 300,
        alignment: Alignment.center,
        color: const Color(0xFFE8F5E9),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF107C41)),
            const SizedBox(height: 16),
            Text(
              'Cargando hoja de cálculo Excel...',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1B5E20), fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    if (_mensajeError != null || (!_usarVisorWeb && _hojasDatos.isEmpty)) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          children: [
            const Icon(Icons.table_chart_outlined, color: Colors.redAccent, size: 40),
            const SizedBox(height: 12),
            Text(
              'No se pudo abrir la hoja de cálculo',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red.shade900),
            ),
            const SizedBox(height: 6),
            Text(
              _mensajeError ?? 'Archivo sin datos.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.red.shade700),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFA5D6A7), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade900.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // BARRA VERDE CARACTERÍSTICA MICROSOFT EXCEL
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: const Color(0xFF107C41),
            child: Row(
              children: [
                const Icon(Icons.table_view_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.nombreArchivo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 20),
                  tooltip: 'Abrir en Microsoft Excel',
                  onPressed: _abrirEnAppExterna,
                ),
              ],
            ),
          ),

          if (_usarVisorWeb && _webViewController != null)
            Expanded(child: WebViewWidget(controller: _webViewController!))
          else ...[
            // BARRA DE FÓRMULA FX EXCEL CON ESTILO VERDE Y BLANCO
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: const Color(0xFFE8F5E9),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFA5D6A7)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _celdaSeleccionadaRef,
                      style: GoogleFonts.firaCode(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF107C41)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'fx',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF107C41), fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFA5D6A7)),
                      ),
                      child: Text(
                        _celdaSeleccionadaValor,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // PESTAÑAS DE HOJAS SI HAY MÁS DE UNA
            if (_hojasDatos.length > 1)
              Container(
                color: const Color(0xFFE2E8F0),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _hojasDatos.keys.map((nombreHoja) {
                      final seleccionada = nombreHoja == _hojaSeleccionada;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: ChoiceChip(
                          label: Text(nombreHoja, style: TextStyle(fontSize: 12, color: seleccionada ? Colors.white : Colors.grey.shade800)),
                          selected: seleccionada,
                          selectedColor: const Color(0xFF107C41),
                          backgroundColor: Colors.white,
                          onSelected: (val) {
                            if (val) setState(() => _hojaSeleccionada = nombreHoja);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

            // CUADRÍCULA CON ENCABEZADOS DE COLUMNAS (A,B,C) Y FILAS (1,2,3)
            Expanded(
              child: _buildCuadriculaExcel(_hojasDatos[_hojaSeleccionada] ?? []),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCuadriculaExcel(List<List<String>> filas) {
    if (filas.isEmpty) {
      return const Center(child: Text('Hoja vacía.'));
    }

    int maxCols = 0;
    for (final r in filas) {
      if (r.length > maxCols) maxCols = r.length;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ENCABEZADO DE COLUMNAS (A, B, C, D...)
            Row(
              children: [
                // Esquina vacía 0x0
                Container(
                  width: 36,
                  height: 28,
                  color: const Color(0xFFE2E8F0),
                  alignment: Alignment.center,
                  child: const Icon(Icons.grid_on, size: 14, color: Colors.grey),
                ),
                ...List.generate(maxCols, (colIdx) {
                  return Container(
                    width: 110,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      border: Border.all(color: const Color(0xFFCBD5E1), width: 0.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _obtenerLetraColumna(colIdx),
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                    ),
                  );
                }),
              ],
            ),

            // FILAS CON NÚMERO DE FILA (1, 2, 3...) Y CELDAS
            ...filas.asMap().entries.map((rowEntry) {
              final rowIdx = rowEntry.key;
              final rowCells = rowEntry.value;

              return Row(
                children: [
                  // Número de fila
                  Container(
                    width: 36,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      border: Border.all(color: const Color(0xFFCBD5E1), width: 0.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${rowIdx + 1}',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                    ),
                  ),

                  // Celdas de la fila
                  ...List.generate(maxCols, (colIdx) {
                    final valorCelda = colIdx < rowCells.length ? rowCells[colIdx] : '';
                    final refCelda = '${_obtenerLetraColumna(colIdx)}${rowIdx + 1}';
                    final esSeleccionada = refCelda == _celdaSeleccionadaRef;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _celdaSeleccionadaRef = refCelda;
                          _celdaSeleccionadaValor = valorCelda;
                        });
                      },
                      child: Container(
                        width: 110,
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: esSeleccionada ? const Color(0xFF107C41).withValues(alpha: 0.1) : Colors.white,
                          border: Border.all(
                            color: esSeleccionada ? const Color(0xFF107C41) : const Color(0xFFE2E8F0),
                            width: esSeleccionada ? 2.0 : 0.5,
                          ),
                        ),
                        child: Text(
                          valorCelda,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: rowIdx == 0 ? FontWeight.bold : FontWeight.normal,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}
