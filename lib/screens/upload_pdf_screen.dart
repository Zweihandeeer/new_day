import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:flutter_gemini/utility/pdf_database_service.dart';

class UploadPdfScreen extends StatefulWidget {
  const UploadPdfScreen({super.key});

  @override
  State<UploadPdfScreen> createState() => _UploadPdfScreenState();
}

class _UploadPdfScreenState extends State<UploadPdfScreen> {
  late Future<List<Map<String, dynamic>>> _pdfsFuture;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _pdfsFuture = _loadPdfs();
  }

  /// Cargar PDFs desde la base de datos
  Future<List<Map<String, dynamic>>> _loadPdfs() async {
    return await PDFDatabaseService.getAllPDFs();
  }

  /// Seleccionar, extraer texto y guardar un PDF
  Future<void> _pickAndSavePdf() async {
    try {
      setState(() => _isLoading = true);

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || result.files.single.path == null) {
        setState(() => _isLoading = false);
        return;
      }

      final file = File(result.files.single.path!);
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = result.files.single.name;
      final savedFile = await file.copy('${appDir.path}/$fileName');

      // Extraer texto del PDF usando Syncfusion
      final PdfDocument document =
      PdfDocument(inputBytes: savedFile.readAsBytesSync());
      String extractedText = PdfTextExtractor(document).extractText();
      print('Texto extraído del PDF:');
      print(extractedText);
      document.dispose();

      // Guardar en la base de datos con extractedText
      await PDFDatabaseService.insertPDF(fileName, savedFile.path, extractedText);

      setState(() {
        _pdfsFuture = _loadPdfs();
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF "$fileName" cargado exitosamente.')),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al procesar el PDF: $e')),
      );
    }
  }

  /// Eliminar un PDF
  Future<void> _deletePdf(int id, String filePath) async {
    try {
      await PDFDatabaseService.deletePDF(id);

      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      setState(() {
        _pdfsFuture = _loadPdfs();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF eliminado correctamente.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar el PDF: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center( // Centrar el título
          child: Text('Subir PDFs'),
        ),
        centerTitle: true, // Asegurar que el título esté centrado
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: _pickAndSavePdf,
              icon: const Icon(Icons.upload_file),
              label: const Text('Seleccionar PDF'),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _pdfsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(
                        child: Text('Error: ${snapshot.error}'));
                  } else if (!snapshot.hasData ||
                      snapshot.data!.isEmpty) {
                    return const Center(
                        child: Text('No hay PDFs cargados.'));
                  }
                  final pdfs = snapshot.data!;
                  return ListView.builder(
                    itemCount: pdfs.length,
                    itemBuilder: (context, index) {
                      final pdf = pdfs[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.picture_as_pdf),
                          title: Text(pdf['fileName']),
                          subtitle: Text(
                            '${(File(pdf['filePath']).lengthSync() / 1024).toStringAsFixed(2)} KB',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete,
                                color: Colors.red),
                            onPressed: () => _deletePdf(
                                pdf['id'] as int, pdf['filePath']),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}