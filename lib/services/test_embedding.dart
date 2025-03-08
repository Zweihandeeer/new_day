import 'package:flutter/material.dart';
import 'embedding_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  EmbeddingService embeddingService = EmbeddingService();
  await embeddingService.loadModel();

  List<double> embedding = embeddingService.generateEmbedding("Ferrari es una empresa automotriz.");
  print("Embedding generado: $embedding");
}
