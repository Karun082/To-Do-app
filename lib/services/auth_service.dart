import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../models/app_user.dart';
import 'database_service.dart';

class AuthService {
  AuthService();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _sessionKey = 'current_user_id';

  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final db = await DatabaseService.db;
    final existing = await db.query('users', where: 'email = ?', whereArgs: [email]);
    if (existing.isNotEmpty) {
      throw StateError('An account with this email already exists.');
    }

    final userId = const Uuid().v4();
    final salt = const Uuid().v4();
    final hash = _hash(password, salt);
    final user = AppUser(
      id: userId,
      email: email,
      name: name,
      createdAt: DateTime.now(),
    );

    await db.insert('users', {
      ...user.toMap(),
      'password': hash,
      'salt': salt,
    });
    await _storage.write(key: _sessionKey, value: userId);
    return user;
  }

  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final db = await DatabaseService.db;
    final rows = await db.query('users', where: 'email = ?', whereArgs: [email], limit: 1);
    if (rows.isEmpty) {
      throw StateError('Invalid email or password.');
    }

    final row = rows.first;
    final salt = row['salt']! as String;
    final expected = row['password']! as String;
    final actual = _hash(password, salt);
    if (actual != expected) {
      throw StateError('Invalid email or password.');
    }

    await _storage.write(key: _sessionKey, value: row['id']! as String);
    return AppUser.fromMap(row);
  }

  Future<AppUser?> restoreSession() async {
    final userId = await _storage.read(key: _sessionKey);
    if (userId == null) return null;
    final db = await DatabaseService.db;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [userId], limit: 1);
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  Future<void> logout() => _storage.delete(key: _sessionKey);

  String _hash(String password, String salt) {
    return sha256.convert(utf8.encode('$password$salt')).toString();
  }
}
