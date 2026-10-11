import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../models/plant_catalog.dart';
import '../../models/tree_models.dart';
import '../../services/local_storage_service.dart';
import '../../services/shared_tree_storage_service.dart';
import '../../services/tree_storage_service.dart';

/// Recursos que el jugador puede aplicar a la planta activa.
enum PlantResource { sol, agua, fertilizante }

/// Resultado de intentar aplicar un recurso a la planta activa.
enum SpendResult { applied, noStock, plantFull }

/// Minijuegos con cooldown persistente en SharedPreferences.
enum Minigame {
  sun(Duration(minutes: 10), 'cooldown_sun'),
  water(Duration(minutes: 10), 'cooldown_water'),
  compost(Duration(minutes: 3), 'cooldown_compost');

  const Minigame(this.cooldown, this.prefsKey);
  final Duration cooldown;
  final String prefsKey;
}

/// Controlador de estado global del juego.
///
/// [TreeData] (.tree v2) es la única fuente de verdad.
///
/// Dominio de escritura (Regla de Oro):
///   🟢 Flutter escribe: recursos, plantas[].estado.fase, recursos_aplicados.
///   🔴 Unity escribe: nivel, xp, salud, hp_actual, semillas.
///   PlantController NUNCA modifica campos 🔴.
class PlantController extends ChangeNotifier {
  final LocalStorageService _authStorage = LocalStorageService();
  final TreeStorageService _treeStorage = TreeStorageService();
  final SharedTreeStorageService _sharedStorage = SharedTreeStorageService();
  static const _uuid = Uuid();

  // ── Requisitos de evolución por tipo y fase ────────────────────────────────
  // Alcanzar estos valores evoluciona la planta; también son la capacidad
  // máxima de la fase (no se puede aplicar más).
  static const Map<String, Map<String, Map<String, int>>> _evolutionRequirements = {
    'solar': {
      'semilla': {'sol': 6, 'agua': 2},
      'arbusto': {'sol': 8, 'agua': 4},
      'planta': {'sol': 10, 'agua': 6},
    },
    'xerofito': {
      'semilla': {'sol': 4, 'agua': 2},
      'arbusto': {'sol': 6, 'agua': 4},
      'planta': {'sol': 8, 'agua': 6},
    },
    'templado': {
      'semilla': {'sol': 4, 'agua': 4},
      'arbusto': {'sol': 6, 'agua': 6},
      'planta': {'sol': 8, 'agua': 8},
    },
    'montana': {
      'semilla': {'sol': 2, 'agua': 4},
      'arbusto': {'sol': 4, 'agua': 6},
      'planta': {'sol': 6, 'agua': 8},
    },
    'hidro': {
      'semilla': {'sol': 2, 'agua': 6},
      'arbusto': {'sol': 4, 'agua': 8},
      'planta': {'sol': 6, 'agua': 10},
    },
    'pasto': {
      'semilla': {'sol': 3, 'agua': 3},
      'arbusto': {'sol': 5, 'agua': 5},
      'planta': {'sol': 7, 'agua': 7},
    },
  };

  /// Fertilizante requerido por fase (igual para todos los tipos).
  static const Map<String, int> _fertilizerRequirements = {
    'semilla': 4,
    'arbusto': 6,
    'planta': 8,
  };

  /// Recursos con los que arranca una planta nueva o recién evolucionada.
  static const int _minSol = 1;
  static const int _minAgua = 1;

  /// Cada 10 minutos sin interacción la planta activa pierde 1 de sol y agua.
  static const int _decayIntervalMin = 10;

  // ── Estado ────────────────────────────────────────────────────────────────

  TreeData? _currentTree;
  int _activePlantIndex = 0;
  bool _showEvolutionAnimation = false;
  final Map<Minigame, DateTime> _lastPlayed = {};

  Future<void>? _saving;
  bool _pendingSave = false;

  /// Minutos acumulados por el botón de debug (varios taps suman tiempo).
  int _debugMinutes = 0;
  bool _isDebugAdvancing = false;

  // ── Getters públicos ──────────────────────────────────────────────────────

  /// Árbol de datos completo (.tree v2). Null antes de [loadCurrentTree].
  TreeData? get currentTree => _currentTree;

  /// Inventario del jugador.
  TreeRecursos get recursos => _currentTree?.recursos ?? TreeRecursos();

  /// Todas las plantas del jugador (incluidas las muertas).
  List<TreePlanta> get plants => _currentTree?.plantas ?? [];

  List<TreePlanta> get _alivePlants =>
      plants.where((p) => p.desbloqueada && p.estado.fase != 'muerto').toList();

  /// Planta seleccionada, o null si no hay ninguna viva.
  TreePlanta? get activePlant {
    final alive = _alivePlants;
    if (alive.isEmpty) return null;
    if (_activePlantIndex < 0 || _activePlantIndex >= alive.length) {
      _activePlantIndex = 0;
    }
    return alive[_activePlantIndex];
  }

  /// Recursos aplicados a la planta activa.
  TreeRecursosAplicados get activePlantResources =>
      activePlant?.recursosAplicados ?? TreeRecursosAplicados();

  /// True si hay una animación de evolución pendiente de mostrar.
  bool get showEvolutionAnimation => _showEvolutionAnimation;

  /// Limpia el flag de evolución tras consumirlo en la UI.
  void clearAnimationFlags() => _showEvolutionAnimation = false;

  /// Tipo de planta (`solar`, `hidro`, …) según su id.
  String getPlantType(String plantId) => PlantCatalog.typeOf(plantId);

  // ── Carga de sesión ───────────────────────────────────────────────────────

  /// Carga el .tree guardado; si no existe, lo crea a partir de la sesión
  /// iniciada en el login.
  Future<void> loadCurrentTree() async {
    try {
      _currentTree = await _treeStorage.loadTree();

      if (_currentTree == null) {
        final userId = await _authStorage.getCurrentSession();
        if (userId == null) return;
        final user = await _authStorage.getUser(userId);
        if (user == null) return;
        _currentTree = TreeData(
          version: 2,
          usuario: TreeUsuario(id: user.userId, nombre: user.username),
          recursos: TreeRecursos(),
          plantas: [],
        );
      }

      _ensureDefaultPlant();
      await applyPassiveDecay();
      await saveTree();
      await _loadCooldowns();
      notifyListeners();
    } catch (e) {
      debugPrint('[PlantController] Error al cargar datos: $e');
    }
  }

  /// Si no queda ninguna planta viva, añade un Pasto en semilla con los
  /// recursos mínimos para sobrevivir.
  void _ensureDefaultPlant() {
    if (_currentTree == null || _alivePlants.isNotEmpty) return;

    final instanceId = _uuid.v4();
    _currentTree!.plantas.add(TreePlanta(
      id: 'pasto',
      instanceId: instanceId,
      subid: 'pasto',
      desbloqueada: true,
      estado: TreeEstado(fase: 'semilla'),
      recursosAplicados:
          TreeRecursosAplicados(sol: _minSol, agua: _minAgua, fertilizante: 0),
    ));
    _activePlantIndex = 0;
    _authStorage.savePlantLastInteraction(instanceId, DateTime.now().toUtc());
    debugPrint('[PlantController] 🌱 Nueva planta pasto creada');
  }

  // ── Decay pasivo ──────────────────────────────────────────────────────────

  /// Descuenta 1 de sol y agua de la planta activa por cada 10 min
  /// transcurridos desde su última interacción. Si alguno llega a 0 la planta
  /// muere. Las plantas ENT y las no activas no decaen; la composta tampoco.
  ///
  /// [fakeNow] permite simular el paso del tiempo (botón de debug).
  Future<void> applyPassiveDecay({DateTime? fakeNow}) async {
    final plant = activePlant;
    if (plant == null || plant.estado.fase == 'ent') return;

    final now = fakeNow ?? DateTime.now().toUtc();
    final last = await _authStorage.getPlantLastInteraction(plant.instanceId);
    final intervals = now.difference(last).inMinutes ~/ _decayIntervalMin;
    if (intervals < 1) return;

    final res = plant.recursosAplicados;
    res.agua = (res.agua - intervals).clamp(0, 9999);
    res.sol = (res.sol - intervals).clamp(0, 9999);
    debugPrint('[Decay] ${plant.id}: -$intervals → sol=${res.sol}, agua=${res.agua}');

    if (res.agua <= 0 || res.sol <= 0) {
      plant.estado.fase = 'muerto';
      debugPrint('[PlantController] 🚨 Planta ${plant.id} muerta por decay.');
      _ensureDefaultPlant();
    }

    await _authStorage.savePlantLastInteraction(plant.instanceId, now);
    await saveTree();
    notifyListeners();
  }

  // ── Inventario ────────────────────────────────────────────────────────────

  void addSun(int amount) {
    if (amount <= 0 || _currentTree == null) return;
    _currentTree!.recursos.sol.cantidad += amount;
    notifyListeners();
  }

  void addWater(int amount) {
    if (amount <= 0 || _currentTree == null) return;
    _currentTree!.recursos.agua.cantidad += amount;
    notifyListeners();
  }

  /// Suma composta; cada 4 se convierten automáticamente en 1 fertilizante.
  void addCompost(int amount) {
    if (amount <= 0 || _currentTree == null) return;
    final r = _currentTree!.recursos;
    r.composta.cantidad += amount;
    r.fertilizante.cantidad += r.composta.cantidad ~/ 4;
    r.composta.cantidad %= 4;
    notifyListeners();
  }

  /// Unidades disponibles en el inventario.
  int stockOf(PlantResource r) {
    switch (r) {
      case PlantResource.sol:
        return recursos.sol.cantidad;
      case PlantResource.agua:
        return recursos.agua.cantidad;
      case PlantResource.fertilizante:
        return recursos.fertilizante.cantidad;
    }
  }

  // ── Aplicar recursos a la planta activa ───────────────────────────────────

  /// Pasa 1 unidad de [resource] del inventario a la planta activa y
  /// comprueba si evoluciona. El estado se actualiza y notifica de forma
  /// síncrona (la animación puede lanzarse ya); el guardado va después.
  SpendResult spend(PlantResource resource) {
    final plant = activePlant;
    if (_currentTree == null || plant == null || stockOf(resource) < 1) {
      return SpendResult.noStock;
    }

    final applied = plant.recursosAplicados;
    final capacity = _phaseCapacity(plant);
    if (capacity != null && _applied(applied, resource) >= capacity[resource.name]!) {
      return SpendResult.plantFull;
    }

    final inv = _currentTree!.recursos;
    switch (resource) {
      case PlantResource.sol:
        inv.sol.cantidad--;
        applied.sol++;
      case PlantResource.agua:
        inv.agua.cantidad--;
        applied.agua++;
      case PlantResource.fertilizante:
        inv.fertilizante.cantidad--;
        applied.fertilizante++;
    }

    _checkEvolution(plant);
    notifyListeners();

    _authStorage.savePlantLastInteraction(plant.instanceId, DateTime.now().toUtc());
    saveTree();
    return SpendResult.applied;
  }

  static int _applied(TreeRecursosAplicados a, PlantResource r) {
    switch (r) {
      case PlantResource.sol:
        return a.sol;
      case PlantResource.agua:
        return a.agua;
      case PlantResource.fertilizante:
        return a.fertilizante;
    }
  }

  /// Máximo de sol/agua/fertilizante que admite la planta en su fase actual
  /// (igual al requisito de evolución). ENT usa los valores de 'planta'.
  /// Null si la planta está muerta.
  Map<String, int>? _phaseCapacity(TreePlanta plant) {
    final fase = plant.estado.fase == 'ent' ? 'planta' : plant.estado.fase;
    final reqs = _evolutionRequirements[PlantCatalog.typeOf(plant.id)]?[fase];
    if (reqs == null) return null;
    return {
      'sol': reqs['sol']!,
      'agua': reqs['agua']!,
      'fertilizante': _fertilizerRequirements[fase]!,
    };
  }

  /// Capacidad de la fase actual de la planta activa (para las barras).
  Map<String, int>? getCurrentPhaseRequirements() {
    final plant = activePlant;
    return plant == null ? null : _phaseCapacity(plant);
  }

  /// Hace activa a [plant] (debe estar viva). Una planta ENT se rellena al
  /// máximo porque ya no evoluciona ni decae.
  void selectPlant(TreePlanta plant) {
    final index = _alivePlants.indexOf(plant);
    if (index < 0) return;
    _activePlantIndex = index;

    if (plant.estado.fase == 'ent') {
      final cap = _phaseCapacity(plant)!;
      plant.recursosAplicados
        ..sol = cap['sol']!
        ..agua = cap['agua']!
        ..fertilizante = cap['fertilizante']!;
    }
    notifyListeners();
  }

  // ── Evolución ─────────────────────────────────────────────────────────────

  /// Si la planta alcanzó los requisitos de su fase, pasa a la siguiente y
  /// sus recursos vuelven al mínimo.
  void _checkEvolution(TreePlanta plant) {
    final faseIndex = kPhases.indexOf(plant.estado.fase);
    if (faseIndex < 0 || faseIndex >= kPhases.length - 1) return; // muerto o ent

    final cap = _phaseCapacity(plant);
    final a = plant.recursosAplicados;
    if (cap == null ||
        a.sol < cap['sol']! ||
        a.agua < cap['agua']! ||
        a.fertilizante < cap['fertilizante']!) {
      return;
    }

    plant.estado.fase = kPhases[faseIndex + 1];
    a
      ..sol = _minSol
      ..agua = _minAgua
      ..fertilizante = 0;
    _showEvolutionAnimation = true;
    debugPrint('[PlantController] 🌱 ${plant.id} evolucionó a ${plant.estado.fase}');
  }

  // ── Persistencia ──────────────────────────────────────────────────────────

  /// Guarda el .tree en SharedPreferences y lo exporta a la carpeta
  /// compartida con Unity.
  ///
  /// Los guardados nunca se solapan: si llega una petición mientras otro está
  /// en curso, se repite al terminar para que el último estado quede escrito.
  Future<void> saveTree() {
    if (_currentTree == null) return Future.value();
    if (_saving != null) {
      _pendingSave = true;
      return _saving!;
    }
    return _saving = _saveLoop().whenComplete(() => _saving = null);
  }

  Future<void> _saveLoop() async {
    do {
      _pendingSave = false;
      try {
        await _treeStorage.saveTreeLocally(flutterData: _currentTree!);
        await _sharedStorage.exportTree(_currentTree!, silent: true);
      } catch (e) {
        debugPrint('[PlantController] ❌ Error guardando el .tree: $e');
      }
    } while (_pendingSave);
  }

  // ── Sincronización con Unity ──────────────────────────────────────────────

  /// Importa el .tree escrito por Unity y aplica solo sus campos 🔴,
  /// conservando la planta activa si sigue existiendo.
  Future<bool> importFromSharedStorage() async {
    try {
      await _sharedStorage.createBackup('pre_unity_import');

      final unityData = await _sharedStorage.importTree();
      if (unityData == null) {
        debugPrint('[PlantController] ℹ️ No hay archivo .tree para importar.');
        return false;
      }

      final previousActiveId = activePlant?.instanceId;

      await _treeStorage.applyUnitySync(unityData);
      _currentTree = await _treeStorage.loadTree();
      if (_currentTree != null) {
        final alive = _alivePlants;
        final idx = alive.indexWhere((p) => p.instanceId == previousActiveId);
        _activePlantIndex = idx < 0 ? 0 : idx;
        await applyPassiveDecay();
      }

      notifyListeners();
      debugPrint('[PlantController] ✅ Import desde Unity aplicado.');
      return true;
    } catch (e) {
      debugPrint('[PlantController] ❌ Error importando desde Unity: $e');
      return false;
    }
  }

  /// Abre Ajustes para conceder acceso a Documents. True si ya tenía permiso.
  Future<bool> requestStoragePermission() => _sharedStorage.requestPermissions();

  /// Comprueba el acceso a Documents sin mostrar diálogos.
  Future<bool> checkStoragePermission() => _sharedStorage.checkPermissions();

  /// Exporta explícitamente. Solo llamar si [checkStoragePermission] es true.
  Future<String> exportToSharedStorage() async {
    if (_currentTree == null) return 'Sin datos para exportar.';
    final file = await _sharedStorage.exportTree(_currentTree!, silent: false);
    return file?.path ?? 'Permisos no concedidos.';
  }

  /// Info de la carpeta compartida para la UI de diagnóstico.
  Future<SharedFolderInfo> getSharedFolderInfo() => _sharedStorage.getFolderInfo();

  // ── Cooldowns de minijuegos ───────────────────────────────────────────────

  Future<void> _loadCooldowns() async {
    final prefs = await SharedPreferences.getInstance();
    for (final game in Minigame.values) {
      final value = DateTime.tryParse(prefs.getString(game.prefsKey) ?? '');
      if (value != null) _lastPlayed[game] = value;
    }
  }

  Future<void> _saveCooldowns() async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in _lastPlayed.entries) {
      await prefs.setString(entry.key.prefsKey, entry.value.toIso8601String());
    }
  }

  /// Tiempo que falta para poder volver a jugar, o null si está disponible.
  Duration? remainingCooldown(Minigame game) {
    final last = _lastPlayed[game];
    if (last == null) return null;
    final remaining = game.cooldown - DateTime.now().difference(last);
    return remaining.isNegative ? null : remaining;
  }

  bool canPlay(Minigame game) => remainingCooldown(game) == null;

  /// Registra que el jugador terminó [game] e inicia su cooldown.
  void markPlayed(Minigame game) {
    _lastPlayed[game] = DateTime.now();
    _saveCooldowns();
    notifyListeners();
  }

  /// Formatea un cooldown como "9:32" (o "Listo" si es null).
  String formatRemainingCooldown(Duration? duration) {
    if (duration == null) return 'Listo';
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '${duration.inMinutes}:$seconds';
  }

  // ── Debug ─────────────────────────────────────────────────────────────────

  /// Simula que pasaron [minutes] minutos: adelanta los cooldowns y aplica
  /// el decay correspondiente. Solo lo usa el botón "T" en modo debug.
  Future<void> debugAdvanceTime(int minutes) async {
    if (_isDebugAdvancing) return;
    _isDebugAdvancing = true;
    try {
      _debugMinutes += minutes;
      _lastPlayed.updateAll((_, t) => t.subtract(Duration(minutes: minutes)));
      await _saveCooldowns();
      await applyPassiveDecay(
        fakeNow: DateTime.now().toUtc().add(Duration(minutes: _debugMinutes)),
      );
    } finally {
      _isDebugAdvancing = false;
    }
  }
}
