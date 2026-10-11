import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class LocalStorageService {
  static const String _usersKeyPrefix = 'user_';
  
  Future<void> saveUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_usersKeyPrefix${user.userId}', jsonEncode(user.toJson()));
  }

  Future<UserModel?> getUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('$_usersKeyPrefix$userId');
    if (data == null) return null;
    return UserModel.fromJson(jsonDecode(data));
  }

  Future<void> saveCurrentSession(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_session_id', userId);
  }

  Future<String?> getCurrentSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('current_session_id');
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_session_id');
  }

  // ── Temporizador de Decaimiento de Plantas ────────────────────────────────
  
  /// Guarda el timestamp de la última interacción para una planta específica.
  Future<void> savePlantLastInteraction(String instanceId, DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('plant_interaction_$instanceId', time.toUtc().toIso8601String());
  }

  /// Obtiene el timestamp de la última interacción de una planta.
  /// Si no existe, asume la hora actual UTC (nueva planta).
  Future<DateTime> getPlantLastInteraction(String instanceId) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('plant_interaction_$instanceId');
    if (data == null) return DateTime.now().toUtc();
    return DateTime.parse(data);
  }
}
