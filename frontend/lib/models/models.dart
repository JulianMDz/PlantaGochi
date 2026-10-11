// Modelo legado del usuario creado en el login (SharedPreferences `user_<id>`).
// El estado del juego vive en el `.tree` ([TreeData]); este modelo solo
// aporta id y nombre cuando todavía no existe un `.tree`.

enum PlantType { hidro, solar, xerofito, montana, templado, pasto }
enum PlantStage { seed, bush, tree, ent }

class UserResources {
  int sunAmount;
  int waterAmount;
  int fertilizerAmount;
  int compostAmount;

  UserResources({
    this.sunAmount = 0,
    this.waterAmount = 0,
    this.fertilizerAmount = 0,
    this.compostAmount = 0,
  });

  factory UserResources.fromJson(Map<String, dynamic> json) => UserResources(
        sunAmount: json['sun_amount'] ?? 0,
        waterAmount: json['water_amount'] ?? 0,
        fertilizerAmount: json['fertilizer_amount'] ?? 0,
        compostAmount: json['compost_amount'] ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'sun_amount': sunAmount,
        'water_amount': waterAmount,
        'fertilizer_amount': fertilizerAmount,
        'compost_amount': compostAmount,
      };
}

class SourcesNextState {
  double sun;
  double water;
  double fertilizer;

  SourcesNextState({required this.sun, required this.water, required this.fertilizer});

  factory SourcesNextState.fromJson(Map<String, dynamic> json) => SourcesNextState(
        sun: (json['sun'] ?? 0).toDouble(),
        water: (json['water'] ?? 0).toDouble(),
        fertilizer: (json['fertilizer'] ?? 0).toDouble(),
      );

  Map<String, dynamic> toJson() => {'sun': sun, 'water': water, 'fertilizer': fertilizer};
}

class PlantState {
  String plantId;
  String plantName;
  PlantType plantType;
  PlantStage stage;
  double health;
  double sun;
  double water;
  double fertilizer;
  bool isDead;
  DateTime lastInteraction;
  SourcesNextState sourcesNextState;

  PlantState({
    required this.plantId,
    required this.plantName,
    required this.plantType,
    this.stage = PlantStage.seed,
    this.health = 100,
    this.sun = 0,
    this.water = 0,
    this.fertilizer = 0,
    this.isDead = false,
    required this.lastInteraction,
    required this.sourcesNextState,
  });

  bool get isEnt => stage == PlantStage.ent;

  factory PlantState.fromJson(Map<String, dynamic> json) => PlantState(
        plantId: json['plant_id'],
        plantName: json['plant_name'],
        plantType: PlantType.values.firstWhere((e) => e.name == json['plant_type']),
        stage: PlantStage.values.firstWhere((e) => e.name == json['stage']),
        health: (json['health'] ?? 100).toDouble(),
        sun: (json['sun'] ?? 0).toDouble(),
        water: (json['water'] ?? 0).toDouble(),
        fertilizer: (json['fertilizer'] ?? 0).toDouble(),
        isDead: json['is_dead'] ?? false,
        lastInteraction: _parseDateTime(json['last_interaction']),
        sourcesNextState: SourcesNextState.fromJson(json['sources_next_state']),
      );

  /// Parseo defensivo de fechas: evita crash si [value] viene nulo o
  /// corrupto (ej. dato malformado escrito por Unity u otro sistema).
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now().toUtc();
    try {
      return DateTime.parse(value as String);
    } catch (_) {
      return DateTime.now().toUtc();
    }
  }

  Map<String, dynamic> toJson() => {
        'plant_id': plantId,
        'plant_name': plantName,
        'plant_type': plantType.name,
        'stage': stage.name,
        'health': health,
        'sun': sun,
        'water': water,
        'fertilizer': fertilizer,
        'is_dead': isDead,
        'last_interaction': lastInteraction.toIso8601String(),
        'sources_next_state': sourcesNextState.toJson(),
      };
}

class UserModel {
  String userId;
  String username;
  List<String> unlockedPlants;
  List<PlantState> plants;
  UserResources resources;

  UserModel({
    required this.userId,
    required this.username,
    required this.unlockedPlants,
    required this.plants,
    required this.resources,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        userId: json['user_id'],
        username: json['username'],
        unlockedPlants: List<String>.from(json['unlocked_plants'] ?? []),
        plants: (json['plants'] as List? ?? []).map((p) => PlantState.fromJson(p)).toList(),
        resources: UserResources.fromJson(json['resources'] ?? {}),
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'username': username,
        'unlocked_plants': unlockedPlants,
        'plants': plants.map((p) => p.toJson()).toList(),
        'resources': resources.toJson(),
      };
}
