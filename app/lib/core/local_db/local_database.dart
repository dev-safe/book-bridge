import 'package:path/path.dart' as path_pkg;
import 'package:sqflite/sqflite.dart';

/// Singleton wrapper around the app's local SQLite database.
///
/// Responsible for opening the database file, creating the schema on
/// first launch, and exposing the [Database] instance to consumers.
class LocalDatabase {
  LocalDatabase._();

  static final LocalDatabase instance = LocalDatabase._();

  Database? _database;

  /// Returns the open [Database], initialising it on first access.
  Future<Database> get database async {
    _database ??= await _init();
    return _database!;
  }

  Future<Database> _init() async {
    final dbPath = await getDatabasesPath();
    final fullPath = path_pkg.join(dbPath, 'book_bridge_cache.db');

    return openDatabase(fullPath, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE cached_listings (
        id          TEXT PRIMARY KEY,
        title       TEXT,
        author      TEXT,
        price_fcfa  INTEGER,
        condition   TEXT,
        image_url   TEXT,
        description TEXT,
        seller_id   TEXT,
        status      TEXT,
        category    TEXT,
        cached_at   INTEGER
      )
    ''');
  }
}
