import 'dart:async';
import 'dart:math';
import 'package:sqflite/sqflite.dart';
import 'package:vector_math/vector_math.dart' as vector;
import 'package:flutter_gemini/utility/pdf_database_service.dart';

class MetricsService {
  final Database db;
  final StreamController<Map<String, double>> _metricsController =
  StreamController.broadcast();

  Stream<Map<String, double>> get streamRetrievalMetrics =>
      _metricsController.stream;

  MetricsService(this.db);

  Future<List<Map<String, dynamic>>> getStoredEmbeddings() async {
    var embeddings = await db.query('embeddings');
    print("Embeddings recuperados: ${embeddings.length}");
    return embeddings;
  }

  double cosineSimilarity(List<double> a, List<double> b) {
    if (a.isEmpty || b.isEmpty || a.length != b.length) {
      throw ArgumentError("Los embeddings deben tener la misma longitud y no estar vacíos.");
    }

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  double euclideanDistance(List<double> a, List<double> b) {
    if (a.isEmpty || b.isEmpty || a.length != b.length) {
      throw ArgumentError("Los embeddings deben tener la misma longitud y no estar vacíos.");
    }

    double sum = 0.0;
    for (int i = 0; i < a.length; i++) {
      sum += pow(a[i] - b[i], 2);
    }
    return sqrt(sum);
  }

  Future<Map<String, double>> calculateRetrievalMetrics() async {
    List<Map<String, dynamic>> embeddings = await getStoredEmbeddings();
    if (embeddings.isEmpty) {
      return {"precision@5": 0.0, "recall@5": 0.0, "mrr": 0.0, "precision@4": 0.0, "hit@5": 0.0};
    }

    var latestInteraction = await PDFDatabaseService.getLatestInteraction();
    print("Última interacción recuperada: $latestInteraction");
    if (latestInteraction == null || latestInteraction['embedding'] == null) {
      print("Error: No se encontró una interacción válida.");
      return {"precision@5": 0.0, "recall@5": 0.0, "mrr": 0.0, "precision@4": 0.0, "hit@5": 0.0};
    }

    List<double> queryEmbedding = List<double>.from(latestInteraction['embedding']);
    var rankedResults = embeddings.map((e) {
      if (e['vector'] == null || e['vector'] is! List) return null;
      List<double> vector = List<double>.from(e['vector']);
      return {
        "id": e['id'],
        "similarity": cosineSimilarity(queryEmbedding, vector)
      };
    }).where((e) => e != null).toList();

    rankedResults.sort((a, b) => b!["similarity"].compareTo(a!["similarity"]));

    int k = 5;
    int relevantDocs = embeddings.length;
    int retrievedRelevant = rankedResults.take(k).where((e) => isRelevant(e!['id'])).length;
    int retrievedRelevant4 = rankedResults.take(4).where((e) => isRelevant(e!['id'])).length;
    bool hitAt5 = rankedResults.take(5).any((e) => isRelevant(e!['id']));

    double precisionAtK = retrievedRelevant / k;
    double recallAtK = relevantDocs > 0 ? retrievedRelevant / relevantDocs : 0.0;
    double precisionAt4 = retrievedRelevant4 / 4;
    double hitAt5Score = hitAt5 ? 1.0 : 0.0;
    int firstRelevantIndex = rankedResults.indexWhere((e) => isRelevant(e!['id']));
    double mrr = firstRelevantIndex == -1 ? 0.0 : 1 / (firstRelevantIndex + 1);

    final metrics = {
      "precision@5": precisionAtK,
      "recall@5": recallAtK,
      "mrr": mrr,
      "precision@4": precisionAt4,
      "hit@5": hitAt5Score
    };

    _metricsController.add(metrics);
    return metrics;
  }

  bool isRelevant(int id) {
    return id % 2 == 0;
  }

  double calculateBLEU(String generated, String expected) {
    if (generated.isEmpty || expected.isEmpty) return 0.0;

    List<String> generatedWords = generated.split(" ");
    List<String> expectedWords = expected.split(" ");
    int matches = generatedWords.where((word) => expectedWords.contains(word)).length;

    return matches / max(generatedWords.length, 1);
  }

  double calculateROUGE(String generated, String expected) {
    if (generated.isEmpty || expected.isEmpty) return 0.0;

    Set<String> generatedWords = generated.split(" ").toSet();
    Set<String> expectedWords = expected.split(" ").toSet();
    int intersection = generatedWords.intersection(expectedWords).length;
    int union = generatedWords.union(expectedWords).length;

    return intersection / max(union, 1);
  }

  double calculateF1Score(String generated, String expected) {
    double precision = calculateBLEU(generated, expected);
    double recall = calculateROUGE(generated, expected);
    return (precision + recall) == 0.0 ? 0.0 : (2 * precision * recall) / (precision + recall);
  }

  Future<Map<String, double>> evaluateResponseQuality(String generated, String expected) async {
    double bleuScore = calculateBLEU(generated, expected);
    double rougeScore = calculateROUGE(generated, expected);
    double f1Score = calculateF1Score(generated, expected);

    return {"bleu": bleuScore, "rouge": rougeScore, "f1": f1Score};
  }

  void dispose() {
    _metricsController.close();
  }
}
