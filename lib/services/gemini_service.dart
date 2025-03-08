import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiService {
  final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  final String _baseUrl = dotenv.env['BASE_URL'] ?? 'https://generativelanguage.googleapis.com';
  final String _endpoint = 'v1/models/gemini-1.5-pro:generateContent';

  Future<String> generateResponse(String query, String context) async {
    if (_apiKey.isEmpty) {
      return 'Error: La API Key de Gemini no está configurada.';
    }

    final Uri url = Uri.parse('$_baseUrl/$_endpoint?key=$_apiKey');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': 'Contexto: $context\n\nPregunta: $query'}
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates']?[0]['content']?['parts']?[0]['text'] ?? 'No se recibió respuesta.';
      } else {
        return 'Error al obtener respuesta: ${response.statusCode} - ${response.body}';
      }
    } catch (e) {
      return 'Error al conectar con la API: $e';
    }
  }

  Future<Map<String, dynamic>> generateResponseWithMetrics(String query, String context) async {
    if (_apiKey.isEmpty) {
      return {
        "answer": 'Error: La API Key de Gemini no está configurada.',
        "hit": "-",
        "precision": 0.0,
        "correct": false
      };
    }

    final Uri url = Uri.parse('$_baseUrl/$_endpoint?key=$_apiKey');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': 'Contexto: $context\n\nPregunta: $query'}
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String answer = data['candidates']?[0]['content']?['parts']?[0]['text'] ?? 'No se recibió respuesta.';
        double precision = (answer.isNotEmpty) ? 1.0 : 0.0;
        bool correct = answer.isNotEmpty;

        return {
          "answer": answer,
          "hit": correct ? "✅" : "❌",
          "precision": precision,
          "correct": correct
        };
      } else {
        return {
          "answer": 'Error al obtener respuesta: ${response.statusCode} - ${response.body}',
          "hit": "-",
          "precision": 0.0,
          "correct": false
        };
      }
    } catch (e) {
      return {
        "answer": 'Error al conectar con la API: $e',
        "hit": "-",
        "precision": 0.0,
        "correct": false
      };
    }
  }
}
