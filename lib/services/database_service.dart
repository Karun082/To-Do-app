import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  DatabaseService._();

  static Database? _db;

  static Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'dailychip_todo.db');

    return openDatabase(
      path,
      version: 2,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE users (
            id TEXT PRIMARY KEY,
            email TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            password TEXT NOT NULL,
            salt TEXT NOT NULL,
            avatar_url TEXT,
            created_at TEXT NOT NULL,
            theme_pref TEXT DEFAULT 'system'
          )
        ''');

        await database.execute('''
          CREATE TABLE tasks (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            title TEXT NOT NULL,
            notes TEXT DEFAULT '',
            due_date TEXT,
            due_time TEXT,
            status TEXT DEFAULT 'pending',
            priority INTEGER DEFAULT 1,
            tag TEXT,
            reminder_offset INTEGER DEFAULT 10,
            notification_id INTEGER,
            subtasks_json TEXT DEFAULT '[]',
            order_index INTEGER DEFAULT 0,
            recurrence_type TEXT DEFAULT 'none',
            recurrence_interval INTEGER DEFAULT 1,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            FOREIGN KEY(user_id) REFERENCES users(id)
          )
        ''');
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await database.execute("ALTER TABLE tasks ADD COLUMN subtasks_json TEXT DEFAULT '[]'");
          await database.execute('ALTER TABLE tasks ADD COLUMN order_index INTEGER DEFAULT 0');
        }
      },
    );
  }
}
