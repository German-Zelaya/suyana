import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
// NO 'package:firebase_storage/firebase_storage.dart'; needed for this version
import '../models/work_order.dart';

class PdfService {
  static Uint8List? _logoBytes;
  static Uint8List? _titleImageBytes;

  // No Firebase Storage instance needed here
  // static final FirebaseStorage _storage = FirebaseStorage.instance;

  static Future<void> _loadAssets() async {
    // Sticking to local asset loading
    if (_logoBytes == null) {
      final byteData = await rootBundle.load('assets/images/t2.png');
      _logoBytes = byteData.buffer.asUint8List();
    }
    if (_titleImageBytes == null) {
      // Reemplaza 'assets/images/nombre_de_tu_imagen_de_titulo.png' con la ruta real
      final byteData = await rootBundle.load('assets/images/su.png');
      _titleImageBytes = byteData.buffer.asUint8List();
    }
  }

  static Future<Uint8List> generateOrderPdf(WorkOrder order) async {
    await _loadAssets();
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          if (context.pageNumber > 1) {
            return pw.Container(
                alignment: pw.Alignment.centerRight,
                margin: pw.EdgeInsets.only(bottom: 10.0),
                child: pw.Text(
                    'Orden de Trabajo #${order.id.toString().padLeft(6, '0')} - Pág. ${context.pageNumber}',
                    style: pw.Theme.of(context)
                        .defaultTextStyle
                        .copyWith(color: PdfColors.grey, fontSize: 10)));
          }
          return pw.Container();
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: pw.EdgeInsets.only(top: 10.0),
            child: pw.Text(
              'Página ${context.pageNumber} de ${context.pagesCount}',
              style: pw.Theme.of(context)
                  .defaultTextStyle
                  .copyWith(color: PdfColors.grey, fontSize: 10),
            ),
          );
        },
        build: (pw.Context context) => <pw.Widget>[
          _buildHeaderPdf(),
          pw.SizedBox(height: 20),
          _buildOrderInfo(order),
          pw.SizedBox(height: 20),
          _buildClientInfo(order),
          pw.SizedBox(height: 20),
          _buildVehicleInfo(order),
          pw.SizedBox(height: 20),
          _buildSpareParts(order),
          pw.SizedBox(height: 20),
          _buildLaborDetails(order),
          pw.SizedBox(height: 20),
          _buildTotals(order),
          pw.SizedBox(height: 30),
          _buildFooter(order),
        ],
      ),
    );

    return pdf.save();
  }

  // --- Firebase Storage specific method REMOVED ---
  // static Future<String?> generateAndUploadOrderPdf(WorkOrder order) async { ... }


  static pw.Widget _buildHeaderPdf() {
    if (_logoBytes == null) { // Simplified check as we are not loading title image from storage in this version
      return pw.Container(
        padding: pw.EdgeInsets.all(20),
        color: PdfColor.fromHex('#DDDDDD'),
        child: pw.Text('Logo no disponible', style: pw.TextStyle(fontSize: 18)),
      );
    }
    final logoImage = pw.Image(pw.MemoryImage(_logoBytes!), width: 60, height: 60 * 1.2, fit: pw.BoxFit.contain);

    pw.Widget titleWidget;
    if (_titleImageBytes != null) {
      titleWidget = pw.Image(
        pw.MemoryImage(_titleImageBytes!),
        height: 25,
        fit: pw.BoxFit.contain,
      );
    } else {
      titleWidget = pw.Text(
        'Suyana',
        style: pw.TextStyle(
          fontSize: 16,
          fontWeight: pw.FontWeight.bold,
        ),
      );
    }
    return pw.Container(
      padding: pw.EdgeInsets.all(16),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          logoImage, // logoBytes is checked for null at the start of the method now
          pw.SizedBox(width: 16),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                titleWidget,
                pw.SizedBox(height: 4),
                pw.Text('Servicios de Ambulancia', style: pw.TextStyle(color: PdfColors.grey600, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildOrderInfo(WorkOrder order) {
    return pw.Container(
      padding: pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('ORDEN DE TRABAJO #${order.id.toString().padLeft(6, '0')}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#00382B'))),
          pw.Text('Fecha: ${DateFormat('dd/MM/yyyy').format(order.dateAsDateTime)}', style: pw.TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  static pw.Widget _buildClientInfo(WorkOrder order) {
    return _buildSection('DATOS DEL CLIENTE', [
      _buildInfoRow('Nombre:', order.clientName),
      _buildInfoRow('Dirección:', order.address),
      _buildInfoRow('Teléfono:', order.phone),
    ]);
  }

  static pw.Widget _buildVehicleInfo(WorkOrder order) {
    return _buildSection('INFORMACIÓN DEL VEHÍCULO', [
      _buildInfoRow('Número de Motor:', order.engineNumber),
      _buildInfoRow('Año:', order.year),
      _buildInfoRow('Marca:', order.brand),
      _buildInfoRow('Modelo:', order.model),
      _buildInfoRow('Placa:', order.plate),
    ]);
  }

  static pw.Widget _buildSpareParts(WorkOrder order) {
    if (order.spareParts.isEmpty) {
      return pw.Container();
    }
    return _buildSection('REPUESTOS', [
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300),
        children: [
          pw.TableRow(decoration: pw.BoxDecoration(color: PdfColor.fromHex('#FF5C0C')), children: [
            _buildTableHeader('Descripción'),
            _buildTableHeader('Cantidad'),
            _buildTableHeader('Precio Unit.'),
            _buildTableHeader('Total'),
          ]),
          ...order.spareParts.map((part) => pw.TableRow(children: [
            _buildTableCell(part.description),
            _buildTableCell(part.quantity.toString(), align: pw.TextAlign.center),
            _buildTableCell('\$${part.price.toStringAsFixed(2)}', align: pw.TextAlign.right),
            _buildTableCell('\$${(part.price * part.quantity).toStringAsFixed(2)}', align: pw.TextAlign.right),
          ])),
        ],
      ),
    ]);
  }

  static pw.Widget _buildLaborDetails(WorkOrder order) {
    if (order.laborDetails.isEmpty) {
      return pw.Container();
    }
    return _buildSection('MANO DE OBRA', [
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300),
        children: [
          pw.TableRow(decoration: pw.BoxDecoration(color:  PdfColor.fromHex('#FF5C0C')), children: [
            _buildTableHeader('Descripción'),
            _buildTableHeader('Precio'),
          ]),
          ...order.laborDetails.map((labor) => pw.TableRow(children: [
            _buildTableCell(labor.description),
            _buildTableCell('\$${labor.price.toStringAsFixed(2)}', align: pw.TextAlign.right),
          ])),
        ],
      ),
    ]);
  }

  static pw.Widget _buildTotals(WorkOrder order) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 250,
        padding: pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(color: PdfColor.fromHex('#FFEDD5'), borderRadius: pw.BorderRadius.circular(4)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          _buildTotalRow('Total Repuestos:', '\$${order.totalSpareParts.toStringAsFixed(2)}'),
          pw.SizedBox(height: 5),
          _buildTotalRow('Total Mano de Obra:', '\$${order.totalLabor.toStringAsFixed(2)}'),
          pw.Divider(color: PdfColor.fromHex('#FF5C0C'), height: 10),
          _buildTotalRow('TOTAL GENERAL:', '\$${order.total.toStringAsFixed(2)}', bold: true, fontSize: 16),
        ]),
      ),
    );
  }

  static pw.Widget _buildFooter(WorkOrder order) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      if (order.observations.isNotEmpty) ...[
        _buildSection('OBSERVACIONES', [pw.Text(order.observations)]),
        pw.SizedBox(height: 20),
      ],
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('Autorizado por:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
          pw.Text(order.authorizedBy.isNotEmpty ? order.authorizedBy : '_________________________'),
          pw.SizedBox(height: 30),
          pw.Container(
              width: 200,
              decoration: pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.black, width: 0.5))),
              padding: pw.EdgeInsets.only(top: 4),
              alignment: pw.Alignment.center,
              child: pw.Text('Firma del Cliente', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700))),
        ]),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('Técnico Responsable:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
          pw.Text(order.userName?.isNotEmpty == true ? order.userName! : '_________________________'),
          pw.SizedBox(height: 30),
          pw.Container(
              width: 200,
              decoration: pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.black, width: 0.5))),
              padding: pw.EdgeInsets.only(top: 4),
              alignment: pw.Alignment.center,
              child: pw.Text('Firma del Técnico', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700))),
          pw.SizedBox(height: 20),
          pw.Text('Generado el ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
        ]),
      ]),
    ]);
  }

  static pw.Widget _buildSection(String title, List<pw.Widget> children) {
    return pw.Container(
      // ... (resto del método sin cambios)
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Container(
              width: double.infinity,
              padding: pw.EdgeInsets.symmetric(vertical: 5, horizontal: 10),
              decoration: pw.BoxDecoration(color: PdfColor.fromHex('#00382B'), borderRadius: pw.BorderRadius.circular(4)),
              child: pw.Text(title, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 14))),
          pw.SizedBox(height: 10),
          ...children,
        ]));
  }

  static pw.Widget _buildInfoRow(String label, String value) {
    // ... (resto del método sin cambios)
    return pw.Padding(
        padding: pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.SizedBox(width: 120, child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          pw.Expanded(child: pw.Text(value)),
        ]));
  }

  static pw.Widget _buildTableHeader(String text) {
    // ... (resto del método sin cambios)
    return pw.Padding(
        padding: pw.EdgeInsets.all(5),
        child: pw.Text(text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center));
  }

  static pw.Widget _buildTableCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    // ... (resto del método sin cambios)
    return pw.Padding(padding: pw.EdgeInsets.all(5), child: pw.Text(text, textAlign: align));
  }

  static pw.Widget _buildTotalRow(String label, String value, {bool bold = false, double fontSize = 12}) {
    // ... (resto del método sin cambios)
    return pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(label, style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, fontSize: fontSize)),
      pw.Text(value, style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, fontSize: fontSize, color: bold ? PdfColor.fromHex('#00382B') : PdfColors.black)),
    ]);
  }


  // --- Methods using the PDF data (NO Firebase Storage involved) ---
  static Future<void> printOrder(WorkOrder order) async {
    final pdfData = await generateOrderPdf(order);
    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfData, name: 'orden_${order.id}_${order.clientName.replaceAll(' ', '_')}.pdf');
  }

  static Future<void> shareOrder(WorkOrder order) async {
    final pdfData = await generateOrderPdf(order);
    await Printing.sharePdf(bytes: pdfData, filename: 'orden_${order.id}_${order.clientName.replaceAll(' ', '_')}.pdf');
  }
}