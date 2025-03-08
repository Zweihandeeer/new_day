import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

class EmbeddingDatabaseService {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'embeddings.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE embeddings (id INTEGER PRIMARY KEY, filePath TEXT UNIQUE, embedding TEXT)'
        );
      },
    );
  }

  static Future<void> saveEmbedding(String filePath, List<double> embedding) async {
    final db = await database;
    final embeddingJson = jsonEncode(embedding);
    await db.insert(
      'embeddings',
      {'filePath': filePath, 'embedding': embeddingJson},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<double>?> getEmbedding(String filePath) async {
    final db = await database;
    final result = await db.query(
      'embeddings',
      where: 'filePath = ?',
      whereArgs: [filePath],
    );
    if (result.isNotEmpty) {
      return List<double>.from(jsonDecode(result.first['embedding'] as String));
    }
    return null;
  }
}
