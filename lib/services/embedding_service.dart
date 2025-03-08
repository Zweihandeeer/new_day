import 'dart:typed_data';
import 'dart:math';
import 'dart:convert'; // For JSON serialization
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter_gemini/utility/pdf_database_service.dart'; // Importar el servicio de base de datos

class EmbeddingService {
  late Interpreter _interpreter;
  late Int32List _inputBuffer;
  late List<List<List<double>>> _outputBuffer;
  Map<String, int> _vocab = {};
  bool _isModelLoaded = false;

  EmbeddingService() {
    loadModel().catchError((e) {
      print('Error al cargar el modelo o vocabulario: $e');
      throw Exception('Error al cargar el modelo o vocabulario: $e');
    });
  }

  bool isReady() {
    return _isModelLoaded && _vocab.isNotEmpty;
  }

  Future<void> loadModel() async {
    try {
      print('Cargando modelo...');
      _interpreter = await Interpreter.fromAsset('lib/model/minilm_model.tflite');
      print('Modelo cargado, cargando vocabulario...');
      await _loadVocabulary();
      _isModelLoaded = true;
      print('Vocabulario cargado con éxito.');

      print('Forma esperada de entrada: ${_interpreter.getInputTensor(0).shape}');
      print('Forma esperada de salida: ${_interpreter.getOutputTensor(0).shape}');
    } catch (e) {
      print('Error al cargar el modelo o vocabulario: $e');
      throw Exception('Error al cargar el modelo o vocabulario: $e');
    }
  }

  Future<void> _loadVocabulary() async {
    try {
      final vocabFile = await rootBundle.loadString('lib/model/vocab.txt');
      final vocabLines = vocabFile.split('\n');
      for (int i = 0; i < vocabLines.length; i++) {
        final word = vocabLines[i].trim();
        if (word.isNotEmpty) {
          _vocab[word] = i;
        }
      }
      print('Vocabulario cargado con ${_vocab.length} palabras.');
    } catch (e) {
      print('Error al cargar el vocabulario: $e');
      throw Exception('Error al cargar el vocabulario: $e');
    }
  }

  List<double> generateEmbedding(String text) {
    if (!isReady()) {
      throw Exception("Error: el modelo o el vocabulario no han sido cargados.");
    }

    if (text.isEmpty) {
      throw Exception("Error: el texto proporcionado está vacío.");
    }

    // Tokenizar el texto
    List<int> tokenizedText = _tokenize(text);

    print('Tokens generados: $tokenizedText');

    final inputShape = _interpreter.getInputTensor(0).shape;
    print('Formato de entrada del modelo: $inputShape');

    if (inputShape.length != 2) {
      throw Exception("Error: Se esperaba una entrada bidimensional.");
    }

    // Initialize the input buffer with the correct size
    _inputBuffer = Int32List(inputShape[1]);

    // Copy tokens into the input buffer, truncating or padding as needed
    for (int i = 0; i < inputShape[1]; i++) {
      if (i < tokenizedText.length) {
        _inputBuffer[i] = tokenizedText[i];
      } else {
        _inputBuffer[i] = 0; // Pad with zeros if necessary
      }
    }

    final outputShape = _interpreter.getOutputTensor(0).shape;
    print('Formato de salida del modelo: $outputShape');

    // Initialize the output buffer with the correct shape
    _outputBuffer = List.generate(
      outputShape[0],
          (_) => List.generate(
        outputShape[1],
            (_) => List.filled(outputShape[2], 0.0),
      ),
    );

    // 📌 Prueba de buffers antes de la inferencia
    print('Buffer de entrada antes de la inferencia: $_inputBuffer');

    final input = [_inputBuffer];

    try {
      _interpreter.run(input, _outputBuffer);
    } catch (e) {
      print('Error durante la ejecución del modelo: $e');
      throw Exception('Error al ejecutar el modelo: $e');
    }

    print('Embeddings generados: $_outputBuffer');

    // Agregar los embeddings de los tokens en un solo vector
    List<double> aggregatedEmbedding = _aggregateEmbeddings(_outputBuffer[0]);

    return aggregatedEmbedding; // Devolver el embedding agregado
  }

  List<double> _aggregateEmbeddings(List<List<double>> tokenEmbeddings) {
    int embeddingSize = tokenEmbeddings[0].length;
    List<double> aggregated = List.filled(embeddingSize, 0.0);

    for (var embedding in tokenEmbeddings) {
      for (int i = 0; i < embeddingSize; i++) {
        aggregated[i] += embedding[i];
      }
    }

    for (int i = 0; i < embeddingSize; i++) {
      aggregated[i] /= tokenEmbeddings.length;
    }

    return aggregated;
  }

  List<int> _tokenize(String text) {
    if (_vocab.isEmpty) {
      throw Exception("Error: el vocabulario no ha sido cargado.");
    }

    List<String> words = text.toLowerCase().split(RegExp(r'\s+'));
    print('Palabras tokenizadas: $words');

    return words.map((word) => _vocab[word] ?? _vocab['[UNK]'] ?? 0).toList();
  }

  double cosineSimilarity(List<double> vectorA, List<double> vectorB) {
    if (vectorA.isEmpty || vectorB.isEmpty || vectorA.length != vectorB.length) {
      throw Exception("Error: los vectores deben tener la misma longitud y no estar vacíos.");
    }

    double dotProduct = 0.0;
    double magnitudeA = 0.0;
    double magnitudeB = 0.0;

    for (int i = 0; i < vectorA.length; i++) {
      dotProduct += vectorA[i] * vectorB[i];
      magnitudeA += vectorA[i] * vectorA[i];
      magnitudeB += vectorB[i] * vectorB[i];
    }

    magnitudeA = sqrt(magnitudeA);
    magnitudeB = sqrt(magnitudeB);

    return (magnitudeA == 0 || magnitudeB == 0) ? 0 : dotProduct / (magnitudeA * magnitudeB);
  }

  // Nuevo método para generar respuestas
  Future<String> getResponse(String userQuestion) async {
    // 1. Convertir la pregunta en un embedding
    final List<double> questionEmbedding = generateEmbedding(userQuestion);

    // 2. Encontrar el texto más relevante en la base de datos
    final String response = await findMostRelevantText(questionEmbedding);

    // 3. Devolver la respuesta
    return response.isNotEmpty ? response : 'No se encontró una respuesta relevante.';
  }

  Future<String> findMostRelevantText(List<double> questionEmbedding) async {
    final List<Map<String, dynamic>> pdfs = await PDFDatabaseService.getAllPDFs();
    double maxSimilarity = -1;
    String mostRelevantText = '';

    for (var pdf in pdfs) {
      final String embeddingJson = pdf['embedding'] as String;
      final List<double> pdfEmbedding = List<double>.from(jsonDecode(embeddingJson));

      final double similarity = cosineSimilarity(questionEmbedding, pdfEmbedding);
      if (similarity > maxSimilarity) {
        maxSimilarity = similarity;
        mostRelevantText = pdf['extractedText'] as String;
      }
    }

    return mostRelevantText;
  }
}