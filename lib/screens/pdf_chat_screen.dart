import 'package:flutter/material.dart';
import 'package:flutter_gemini/utility/pdf_database_service.dart';
import 'package:flutter_gemini/services/gemini_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class PdfChatScreen extends StatefulWidget {
  const PdfChatScreen({super.key});

  @override
  State<PdfChatScreen> createState() => _PdfChatScreenState();
}

class _PdfChatScreenState extends State<PdfChatScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  final GeminiService _geminiService = GeminiService();

  // Variables para métricas
  String _hit = "-";
  String _precision = "-";
  String _correctness = "-";

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? chatHistory = prefs.getString('pdf_chat_history');

    if (chatHistory != null) {
      try {
        final decodedMessages = List<Map<String, dynamic>>.from(jsonDecode(chatHistory));
        setState(() {
          _messages = decodedMessages.map((msg) => msg.map((key, value) => MapEntry(key, value.toString()))).toList();
        });
      } catch (e) {
        print('Error al cargar el historial de chat: $e');
      }
    }
  }

  Future<void> _saveChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pdf_chat_history', jsonEncode(_messages));
  }

  Future<void> _sendMessage() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': query});
      _isLoading = true;
    });
    await _saveChatHistory();

    try {
      final response = await _generateResponse(query);
      setState(() {
        _messages.add({'sender': 'bot', 'text': response["answer"]});
        _hit = response["hit"];
        _precision = "${(response["precision"] * 100).toStringAsFixed(2)}%";
        _correctness = response["correct"] ? "Correct" : "Wrong";
      });
      await _saveChatHistory();
    } catch (e) {
      setState(() {
        _messages.add({'sender': 'bot', 'text': '❌ Ocurrió un error al procesar la consulta.'});
      });
      print('Error en _sendMessage: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }

    _controller.clear();
  }

  Future<Map<String, dynamic>> _generateResponse(String query) async {
    try {
      final List<Map<String, dynamic>> pdfs = await PDFDatabaseService.getAllPDFs();
      if (pdfs.isEmpty) {
        return {"answer": '⚠️ No hay PDFs cargados. Sube un PDF para comenzar.', "hit": "-", "precision": 0.0, "correct": false};
      }

      String context = pdfs.map((pdf) => pdf['extractedText']?.toString() ?? '').join('\n\n');
      if (context.trim().isEmpty) {
        return {"answer": '⚠️ No hay información en los PDFs cargados.', "hit": "-", "precision": 0.0, "correct": false};
      }

      print('Generando respuesta para la consulta: $query');
      final response = await _geminiService.generateResponseWithMetrics(query, context);
      return response;
    } catch (e) {
      print('Error en _generateResponse: $e');
      return {"answer": '❌ Error al generar respuesta: $e', "hit": "-", "precision": 0.0, "correct": false};
    }
  }

  Future<void> _clearChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pdf_chat_history');
    setState(() {
      _messages.clear();
      _hit = "-";
      _precision = "-";
      _correctness = "-";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat con PDFs'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final confirm = await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Borrar historial'),
                  content: const Text('¿Estás seguro de que quieres borrar el historial de chat?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Borrar'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await _clearChatHistory();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(
              child: Text('Hazme consultas sobre tus documentos.'),
            )
                : ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['sender'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue[200] : Colors.indigoAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(msg['text']!),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Text('HIT: $_hit | Precision: $_precision | Result: $_correctness',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(hintText: 'Escribe tu pregunta...'),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _isLoading ? null : _sendMessage,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
