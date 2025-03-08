import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:flutter_gemini/services/embedding_service.dart';
import 'dart:typed_data';
import 'dart:convert'; // For JSON serialization
import 'dart:async'; // For Completer usage

class PDFDatabaseService {
  static Database? _database;
  static final Completer<void> _dbInitCompleter = Completer<void>();

  // Inicializa la base de datos de manera segura
  static Future<void> initDatabase() async {
    if (_database != null) return _dbInitCompleter.future;

    _database = await openDatabase(
      join(await getDatabasesPath(), 'pdfs_database.db'),
      onCreate: (db, version) {
        return db.execute(
            '''
          CREATE TABLE pdfs(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            fileName TEXT,
            filePath TEXT,
            extractedText TEXT,
            embedding TEXT
          )
          '''
        );
      },
      version: 1,
    );
    _dbInitCompleter.complete();
  }

  // Extraer texto de un PDF usando Syncfusion
  static Future<String> extractTextFromPDF(String filePath) async {
    try {
      final File file = File(filePath);
      if (!await file.exists()) {
        print('El archivo PDF no existe en la ruta proporcionada: $filePath');
        return '';
      }

      final Uint8List bytes = await file.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      final String extractedText = PdfTextExtractor(document).extractText();
      document.dispose(); // Liberar memoria

      // Limpiar y unificar el texto extraído
      final cleanedText = extractedText.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      return cleanedText;
    } catch (e) {
      print('Error extrayendo texto del PDF: $e');
      return '';
    }
  }

  // Insertar un nuevo PDF con texto extraído y embeddings
  static Future<void> insertPDF(String fileName, String filePath, String extractedText) async {
    await initDatabase();

    try {
      if (extractedText.isEmpty) {
        print('No se pudo extraer texto del PDF.');
        return;
      }

      final embeddingService = EmbeddingService(); // Instancia del servicio

      // Esperar a que el servicio de embeddings esté listo
      while (!embeddingService.isReady()) {
        print('Esperando a que el servicio de embeddings esté listo...');
        await Future.delayed(Duration(seconds: 1));
      }

      // Normalizar el texto: eliminar puntuación y convertir a minúsculas
      final normalizedText = extractedText
          .replaceAll(RegExp(r'[^\w\s]'), ' ') // Eliminar puntuación
          .toLowerCase() // Convertir a minúsculas
          .replaceAll(RegExp(r'\s+'), ' ') // Eliminar espacios múltiples
          .trim(); // Eliminar espacios al inicio y al final

      // Limitar el tamaño del texto para evitar exceder el tamaño de entrada del modelo
      const maxTokens = 512; // Tamaño máximo de entrada del modelo (ajusta según tu modelo)
      final truncatedText = normalizedText.split(' ').take(maxTokens).join(' ');

      print('Generando embedding para el texto extraído...');
      final embedding = await embeddingService.generateEmbedding(truncatedText);
      print('Embedding generado correctamente.');

      // Serializar el embedding a JSON
      final embeddingJson = jsonEncode(embedding);

      await _database!.insert(
        'pdfs',
        {
          'fileName': fileName,
          'filePath': filePath,
          'extractedText': extractedText,
          'embedding': embeddingJson, // Almacenar como JSON
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('PDF insertado en la base de datos.');
    } catch (e) {
      print('Error al procesar el PDF: $e');
    }
  }

  // Obtener todos los PDFs almacenados
  static Future<List<Map<String, dynamic>>> getAllPDFs() async {
    await initDatabase();
    return await _database!.query('pdfs');
  }

  // Obtener los embeddings de los PDFs
  static Future<List<Map<String, dynamic>>> getAllEmbeddings() async {
    await initDatabase();
    return await _database!.query('pdfs', columns: ['id', 'filePath', 'embedding']);
  }

  // Obtener el ID de un PDF dado su filePath
  static Future<int?> getPDFIdByFilePath(String filePath) async {
    await initDatabase();

    final pdfs = await _database!.query(
      'pdfs',
      columns: ['id'],
      where: 'filePath = ?',
      whereArgs: [filePath],
    );
    if (pdfs.isNotEmpty) {
      return pdfs.first['id'] as int;
    }
    return null;
  }

  // Eliminar un PDF específico por ID
  static Future<void> deletePDF(int id) async {
    await initDatabase();
    final deletedRows = await _database!.delete('pdfs', where: 'id = ?', whereArgs: [id]);
    if (deletedRows > 0) {
      print('PDF eliminado correctamente.');
    } else {
      print('No se encontró el PDF con el ID: $id');
    }
  }

  // Obtener el texto de todos los PDFs almacenados
  static Future<List<String>> getAllPdfsText() async {
    await initDatabase();
    final pdfs = await _database!.query('pdfs', columns: ['extractedText']);
    return pdfs.map((pdf) => pdf['extractedText'] as String).toList();
  }

  // Deserializar el embedding desde JSON
  static List<double> deserializeEmbedding(String embeddingJson) {
    return List<double>.from(jsonDecode(embeddingJson));
  }

  // Obtener la última interacción de un PDF en base a su ID
  static Future<Map<String, dynamic>?> getLatestInteraction() async {
    await initDatabase();
    final List<Map<String, dynamic>> result = await _database!.query(
      'pdfs',
      orderBy: 'id DESC',
      limit: 1,
    );
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }
}
