import 'dart:io';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:google_fonts/google_fonts.dart';

/// Visor interactivo para hojas de cálculo Excel (.xlsx, .xls) y archivos CSV (.csv).
/// Presenta los datos organizados en tablas con pestañas por hoja de trabajo.
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

  Map<String, List<List<String>>> _hojasDatos = {};
  String _hojaSeleccionada = '';

  @override
  void initState() {
    super.initState();
    _cargarExcel();
  }

  Future<void> _cargarExcel() async {
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
        throw Exception('El archivo de hoja de cálculo no se encuentra en el dispositivo.');
      }

      final bytes = await f.readAsBytes();
      final extension = widget.nombreArchivo.toLowerCase();

      final resultHojas = <String, List<List<String>>>{};

      if (extension.endsWith('.csv')) {
        // Parsear CSV por líneas
        final content = String.fromCharCodes(bytes);
        final lines = content.split(RegExp(r'\r?\n'));
        final rows = <List<String>>[];
        for (final l in lines) {
          if (l.trim().isEmpty) continue;
          rows.add(l.split(',').map((e) => e.replaceAll('"', '').trim()).toList());
        }
        resultHojas['Hoja1'] = rows;
      } else {
        // Parsear .xlsx con paquete excel
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
        setState(() {
          _hojasDatos = resultHojas;
          _hojaSeleccionada = resultHojas.keys.first;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _mensajeError = 'Error al leer la hoja de cálculo: $e';
          _cargando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return Container(
        height: 280,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF107C41)),
            const SizedBox(height: 16),
            Text(
              'Procesando hoja de cálculo...',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    if (_mensajeError != null || _hojasDatos.isEmpty) {
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
              _mensajeError ?? 'Archivo vacío o no soportado.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.red.shade700),
            ),
          ],
        ),
      );
    }

    final filasActuales = _hojasDatos[_hojaSeleccionada] ?? [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ENCABEZADO EXCEL
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFF107C41), // Verde de Microsoft Excel
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
              ],
            ),
          ),

          // PESTAÑAS DE HOJAS SI HAY MÁS DE UNA
          if (_hojasDatos.length > 1)
            Container(
              color: Colors.grey.shade100,
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

          // VISTA DE TABLA CON SCROLL BIDIRECCIONAL
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Table(
                  defaultColumnWidth: const IntrinsicColumnWidth(),
                  border: TableBorder.all(color: Colors.grey.shade300, width: 1),
                  children: filasActuales.asMap().entries.map((entry) {
                    final rowIndex = entry.key;
                    final fila = entry.value;
                    final esEncabezado = rowIndex == 0;

                    return TableRow(
                      decoration: BoxDecoration(
                        color: esEncabezado
                            ? const Color(0xFFF1F5F9)
                            : (rowIndex % 2 == 0 ? Colors.white : const Color(0xFFF8FAFC)),
                      ),
                      children: fila.map((celda) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Text(
                            celda,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: esEncabezado ? FontWeight.bold : FontWeight.normal,
                              color: esEncabezado ? const Color(0xFF1E293B) : const Color(0xFF334155),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
