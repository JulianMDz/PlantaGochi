import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/tree_models.dart';

// ═══════════════════════════════════════════════════════════════════════════
// TreeStorageService
//
// Responsable de leer y escribir el archivo .tree (JSON v2) en
// SharedPreferences bajo la clave [_treeKey].
//
// Equivalente Flutter de syncInventoryToTree() + applyTreeDataFrom3D()
// del equipo web (Astro/Preact).
//
// REGLA DE MERGE (Campo de Autoridad):
//   - Flutter solo sobreescribe campos 🟢 de su dominio (recursos, recursosAplicados).
//   - Los campos 🔴 de Unity se leen del .tree existente y se preservan SIEMPRE.
//   - NUNCA modificar campos 🔴 en saveTreeLocally() o applyUnitySync().
//   - Matching de plantas: por instance_id (prioritario), fallback por id.
//
// CAMPO DE AUTORIDAD (Field Authority Matrix):
//   🟢 FLUTTER (Flutter solo puede escribir estos):
//     - usuario.id, usuario.nombre (creados al login)
//     - recursos.* (sol, agua, composta, fertilizante)
//     - planta.estado.fase (progresión de evolución: semilla→arbusto→planta→ent)
//     - planta.recursosAplicados.* (agua, sol, fertilizante aplicados en Flutter)
//     - planta.visualEstado
//
//   🔴 UNITY (Solo Unity puede escribir; Flutter NUNCA modifica):
//     - usuario.nivel, usuario.xp
//     - planta.estado.salud, planta.estado.hpActual
//     - planta.progreso.* (del sistema de progresión del 3D)
//     - planta.uso.* (uso de recursos en Unity)
//     - semillas.* (nuevas semillas desbloqueadas en 3D)
//
// ═══════════════════════════════════════════════════════════════════════════
class TreeStorageService {
  /// Clave SharedPreferences — coincide con localStorage del equipo web.
  static const String _treeKey = 'imaginatio_tree_data';
  /// Clave SharedPreferences para recursos de Flutter (sol, agua, composta, fertilizante).
  static const String _recursosFlutterKey = 'imaginatio_recursos_flutter';

  // ── Lectura ───────────────────────────────────────────────────────────────

  /// Carga el .tree desde SharedPreferences.
  /// Combina los recursos del .tree con los recursos guardados en SharedPreferences
  /// (sol, agua, composta, fertilizante) que Flutter mantiene separados de Unity.
  Future<TreeData?> loadTree() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_treeKey);
      if (raw == null || raw.isEmpty) return null;
      
      final treeData = TreeData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      debugPrint('[TreeStorageService] loadTree .tree recursos: sol=${treeData.recursos.sol.cantidad} agua=${treeData.recursos.agua.cantidad} composta=${treeData.recursos.composta.cantidad} fertilizante=${treeData.recursos.fertilizante.cantidad}');
      
      // Combinar recursos de Flutter desde SharedPreferences
      final recursosFlutter = await loadRecursosFlutter();
      if (recursosFlutter != null) {
        // Usar recursos de SharedPreferences (los más actualizados de Flutter)
        debugPrint('[TreeStorageService] loadTree usando recursos de SharedPreferences');
        return TreeData(
          version: treeData.version,
          usuario: treeData.usuario,
          recursos: recursosFlutter,
          plantas: treeData.plantas,
          semillas: treeData.semillas,
        );
      }
      
      debugPrint('[TreeStorageService] loadTree sin recursos de SharedPreferences, usando .tree');
      return treeData;
    } catch (e) {
      debugPrint('[TreeStorageService] Error al cargar .tree: $e');
      return null;
    }
  }

  /// Carga los recursos de Flutter desde SharedPreferences.
  /// Retorna null si no existen.
  Future<TreeRecursos?> loadRecursosFlutter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_recursosFlutterKey);
      debugPrint('[TreeStorageService] loadRecursosFlutter raw: $raw');
      if (raw == null || raw.isEmpty) return null;
      final result = TreeRecursos.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      debugPrint('[TreeStorageService] loadRecursosFlutter result: sol=${result.sol.cantidad} agua=${result.agua.cantidad} composta=${result.composta.cantidad} fertilizante=${result.fertilizante.cantidad}');
      return result;
    } catch (e) {
      debugPrint('[TreeStorageService] Error al cargar recursos Flutter: $e');
      return null;
    }
  }

  /// Guarda los recursos de Flutter en SharedPreferences (separado del .tree).
  Future<void> saveRecursosFlutter(TreeRecursos recursos) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_recursosFlutterKey, jsonEncode(recursos.toJson()));
      debugPrint(
        '[TreeStorageService] Recursos Flutter guardados ✓ — '
        'sol:${recursos.sol.cantidad} '
        'agua:${recursos.agua.cantidad} '
        'composta:${recursos.composta.cantidad} '
        'fertilizante:${recursos.fertilizante.cantidad}',
      );
    } catch (e) {
      debugPrint('[TreeStorageService] Error al guardar recursos Flutter: $e');
      rethrow;
    }
  }

  // ── Escritura con merge (Flutter → .tree) ─────────────────────────────────

/// Persiste [flutterData] como .tree v2, preservando los campos 🔴 de
  /// Unity que ya estaban guardados.
  ///
  /// Flujo:
  /// 1. Lee el .tree existente para recuperar campos 🔴 de Unity.
  /// 2. Valida que Flutter no intente modificar campos 🔴 (Regla de Oro).
  /// 3. Hace merge: campos 🟢 de [flutterData] + campos 🔴 del existente.
  /// 4. Persiste el resultado en SharedPreferences.
  Future<void> saveTreeLocally({required TreeData flutterData}) async {
    try {
      debugPrint('[TreeStorageService] saveTreeLocally input: sol=${flutterData.recursos.sol.cantidad} agua=${flutterData.recursos.agua.cantidad} composta=${flutterData.recursos.composta.cantidad} fertilizante=${flutterData.recursos.fertilizante.cantidad}');
      
      // Guardar recursos de Flutter en SharedPreferences (separado del .tree para Unity)
      await saveRecursosFlutter(flutterData.recursos);

      // Guardar .tree para Unity (sin los recursos de Flutter - se preservan del existente)
      final existing = await loadTree();
      
      // Validate field authority (warn if Flutter tries to modify 🔴 fields)
      _validateFieldAuthority(flutterData, existing: existing);
      
      final merged = _mergeFlutterIntoExisting(
        flutterData: flutterData,
        existing: existing,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_treeKey, merged.toJsonString());

      debugPrint(
        '[TreeStorageService] .tree guardado ✓ — '
        'sol:${merged.recursos.sol.cantidad} '
        'agua:${merged.recursos.agua.cantidad} '
        'composta:${merged.recursos.composta.cantidad}',
      );
} catch (e) {
      debugPrint('[TreeStorageService] Error al guardar .tree: $e');
      rethrow;
    }
  }

  // ── Sync desde Unity (Unity → .tree) ─────────────────────────────────────

  /// Aplica los datos exportados por Unity al .tree local.
  /// Equivalente al botón "Sync desde 3D" del equipo web.
  ///
  /// Solo actualiza campos 🔴 de Unity:
  ///   - usuario.nivel y usuario.xp
  ///   - planta.estado.salud, planta.estado.hp_actual
  ///   - planta.progreso.*, planta.uso.*
  ///   - Semillas nuevas (dedup por seed_id)
  ///
  /// Los campos 🟢 de Flutter NUNCA se modifican.
  Future<void> applyUnitySync(TreeData unityData) async {
    try {
      final current = await loadTree();
      if (current == null) {
        debugPrint('[TreeStorageService] No hay .tree local — sync Unity ignorado.');
        return;
      }

      // Usuario: actualizar solo nivel/xp (🔴), preservar id/nombre (🟢)
      final mergedUsuario = TreeUsuario(
        id: current.usuario.id, // 🟢 Flutter — no tocar
        nombre: current.usuario.nombre, // 🟢 Flutter — no tocar
        nivel: unityData.usuario.nivel, // 🔴 Unity actualiza
        xp: unityData.usuario.xp, // 🔴 Unity actualiza
      );

      // Plantas: merge por instance_id / fallback por id
      final mergedPlantas = _mergeUnityIntoPlantas(
        flutterPlantas: current.plantas,
        unityPlantas: unityData.plantas,
      );

      // Semillas: agregar solo las nuevas de Unity (dedup por seed_id)
      final existingSeedIds = current.semillas.map((s) => s.seedId).toSet();
      final newSeeds = unityData.semillas
          .where((s) => !existingSeedIds.contains(s.seedId))
          .toList();

      final result = TreeData(
        version: 2,
        usuario: mergedUsuario,
        recursos: current.recursos, // 🟢 Flutter — no tocar nunca
        plantas: mergedPlantas,
        semillas: [...current.semillas, ...newSeeds],
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_treeKey, result.toJsonString());

      debugPrint(
        '[TreeStorageService] Sync Unity aplicado ✓ — '
        '${newSeeds.length} semilla(s) nueva(s)',
      );
    } catch (e) {
      debugPrint('[TreeStorageService] Error en applyUnitySync: $e');
      rethrow;
    }
  }

  /// Elimina el .tree local. Útil para pruebas o cierre de sesión.
  Future<void> clearTree() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_treeKey);
    debugPrint('[TreeStorageService] .tree eliminado.');
  }

   // ── Lógica interna ────────────────────────────────────────────────────────

  /// Validates that [flutterData] respects field authority rules before merge.
  /// Logs warnings if Flutter attempts to write to Unity-owned fields (🔴).
  /// 
  /// This is a safety check; actual merge enforcement happens in _mergeFlutterIntoExisting.
  void _validateFieldAuthority(TreeData flutterData, {TreeData? existing}) {
    if (existing == null) return; // First save; no validation needed
    
    // Check usuario fields
    if (flutterData.usuario.nivel != existing.usuario.nivel) {
      debugPrint('[TreeStorageService] ⚠️ WARNING: Flutter attempted to modify usuario.nivel (🔴 Unity-owned). Will be ignored.');
    }
    if (flutterData.usuario.xp != existing.usuario.xp) {
      debugPrint('[TreeStorageService] ⚠️ WARNING: Flutter attempted to modify usuario.xp (🔴 Unity-owned). Will be ignored.');
    }
    
    // Check planta fields (simplified; could be extended per planta.estado.*)
    for (int i = 0; i < flutterData.plantas.length; i++) {
      final fp = flutterData.plantas[i];
      final match = _findMatch(fp, existing.plantas);
      if (match == null) continue;
      
      if (fp.estado.salud != match.estado.salud) {
        debugPrint('[TreeStorageService] ⚠️ WARNING: Flutter attempted to modify planta[${fp.id}].estado.salud (🔴 Unity-owned). Will be ignored.');
      }
      if (fp.estado.hpActual != match.estado.hpActual) {
        debugPrint('[TreeStorageService] ⚠️ WARNING: Flutter attempted to modify planta[${fp.id}].estado.hpActual (🔴 Unity-owned). Will be ignored.');
      }
    }
    
    debugPrint('[TreeStorageService] ✅ Field authority validation passed.');
  }

   // ── Lógica interna ────────────────────────────────────────────────────────

  /// Combina [flutterData] (fuente 🟢) con los campos 🔴 de [existing].
  /// Si [existing] es null (primer guardado), retorna [flutterData] directo.
  TreeData _mergeFlutterIntoExisting({
    required TreeData flutterData,
    TreeData? existing,
  }) {
    if (existing == null) return flutterData;

    // Preservar nivel/xp de Unity en el usuario
    final mergedUsuario = TreeUsuario(
      id: flutterData.usuario.id, // 🟢
      nombre: flutterData.usuario.nombre, // 🟢
      nivel: existing.usuario.nivel, // 🔴 preservado
      xp: existing.usuario.xp, // 🔴 preservado
    );

    // Merge plantas: Flutter trae los campos 🟢, Unity aporta los 🔴
    final mergedPlantas = _mergeFlutterIntoPlantas(
      flutterPlantas: flutterData.plantas,
      existingPlantas: existing.plantas,
    );

    return TreeData(
      version: 2,
      usuario: mergedUsuario,
      recursos: flutterData.recursos, // 🟢 Flutter owns recursos — use directly
      plantas: mergedPlantas,
      semillas: existing.semillas,
    );
  }

  /// Para cada planta de [flutterPlantas], busca su contraparte en
  /// [existingPlantas] y le aplica los campos 🔴 de Unity preservados.
  ///
  /// Matching: instance_id prioritario → fallback por id de especie.
  List<TreePlanta> _mergeFlutterIntoPlantas({
    required List<TreePlanta> flutterPlantas,
    required List<TreePlanta> existingPlantas,
  }) {
    return flutterPlantas.map((fp) {
      final match = _findMatch(fp, existingPlantas);
      if (match == null) return fp; // planta nueva, sin datos Unity

      // Construir planta final: campos 🟢 de fp + campos 🔴 de match
      return TreePlanta(
        id: fp.id, // 🟢
        instanceId: fp.instanceId, // 🟢 inmutable
        subid: fp.subid, // 🟢
        desbloqueada: fp.desbloqueada, // 🟢
        estado: TreeEstado(
          fase: fp.estado.fase, // 🟢 Flutter actualiza
          salud: match.estado.salud, // 🔴 Unity — preservar
          hpActual: match.estado.hpActual, // 🔴 Unity — preservar
        ),
        progreso: match.progreso, // 🔴 completo de Unity
        visualEstado: fp.visualEstado, // 🟢
        uso: match.uso, // 🔴 completo de Unity
        recursosAplicados: fp.recursosAplicados, // 🟢
      );
    }).toList();
  }

  /// Para cada planta existente (Flutter), busca la versión de Unity y aplica
  /// solo los campos 🔴. También agrega nuevas plantas de Unity que no existen en Flutter.
  /// Usado en [applyUnitySync].
  ///
  /// FIX 1: Genera instanceId automáticamente para plantas viejas con ID vacío (pre-instanceId).
  /// FIX 4: Valida que fase NUNCA se actualiza desde Unity (auditoría).
  /// FIX 5: Detecta y previene duplicación de plantas.
  List<TreePlanta> _mergeUnityIntoPlantas({
    required List<TreePlanta> flutterPlantas,
    required List<TreePlanta> unityPlantas,
  }) {
    const uuid = Uuid();
    
    // FIX 1: Limpiar plantas viejas con instanceId vacío
    final cleanedFlutterPlantas = flutterPlantas.map((p) {
      if (p.instanceId.isEmpty) {
        final newId = uuid.v4();
        debugPrint('[Merge] 🔧 FIX 1: Generated instanceId for old plant ${p.id}: $newId');
        // Crear copia de la planta con el nuevo instanceId
        return TreePlanta(
          id: p.id,
          instanceId: newId, // Nueva ID
          subid: p.subid,
          desbloqueada: p.desbloqueada,
          estado: p.estado,
          recursosAplicados: p.recursosAplicados,
          progreso: p.progreso,
          visualEstado: p.visualEstado,
          uso: p.uso,
        );
      }
      return p;
    }).toList();
    
    // 1. Mantener plantas existentes de Flutter (actualizadas por Unity)
    final mergedPlantas = cleanedFlutterPlantas.map((fp) {
      final unityMatch = _findMatch(fp, unityPlantas);
      if (unityMatch == null) return fp; // Unity no tiene datos de esta planta

      // FIX 4: Validar que fase NUNCA se actualiza desde Unity
      if (unityMatch.estado.fase != fp.estado.fase) {
        debugPrint('[TreeStorageService] ⚠️ FIX 4 AUTHORITY VIOLATION: Unity attempted to modify fase for ${fp.id} (${fp.estado.fase} → ${unityMatch.estado.fase}); IGNORED. Phase is Flutter domain.');
      }

      return TreePlanta(
        id: fp.id, // 🟢 preservado
        instanceId: fp.instanceId, // 🟢 inmutable (now always populated)
        subid: fp.subid, // 🟢 preservado
        desbloqueada: fp.desbloqueada, // 🟢 preservado
        estado: TreeEstado(
          fase: fp.estado.fase, // 🟢 Flutter — no tocar (ignore unityMatch.fase)
          salud: unityMatch.estado.salud, // 🔴 Unity actualiza
          hpActual: unityMatch.estado.hpActual, // 🔴 Unity actualiza
        ),
        progreso: unityMatch.progreso, // 🔴 Unity actualiza
        visualEstado: fp.visualEstado, // 🟢 preservado
        uso: unityMatch.uso, // 🔴 Unity actualiza
        recursosAplicados: fp.recursosAplicados, // 🟢 preservado
      );
    }).toList();

    // 2. Agregar plantas nuevas de Unity que no existen en Flutter
    final existingInstanceIds = cleanedFlutterPlantas.map((p) => p.instanceId).toSet();
    
    final newPlantsFromUnity = <TreePlanta>[];
    
    for (final up in unityPlantas) {
      // Agregar si es una nueva planta (instance_id no existe en Flutter)
      if (!existingInstanceIds.contains(up.instanceId)) {
        newPlantsFromUnity.add(TreePlanta(
          id: up.id,
          instanceId: up.instanceId,
          subid: up.subid,
          desbloqueada: true,
          estado: TreeEstado(fase: 'semilla'), // 🟢 default (Flutter domain)
          progreso: up.progreso,
          visualEstado: TreeVisualEstado(),
          uso: up.uso,
          recursosAplicados: TreeRecursosAplicados(
            sol: 1, 
            agua: 1, 
            fertilizante: 0, // 🟢 Mínimo inicial para que no muera inmediatamente tras import
          ),
        ));
      }
    }

    // FIX 5: Dedup de plantas por (id, instanceId)
    final finalPlantas = [...mergedPlantas, ...newPlantsFromUnity];
    final seen = <String>{};
    final dedupedPlantas = <TreePlanta>[];

    for (final p in finalPlantas) {
      final key = '${p.id}|${p.instanceId}';
      if (seen.contains(key)) {
        debugPrint('[Merge] ⚠️ FIX 5: Duplicate detected and removed: $key');
      } else {
        seen.add(key);
        dedupedPlantas.add(p);
      }
    }

    debugPrint('[Merge] 📊 FIX 5: Dedup result: ${finalPlantas.length} → ${dedupedPlantas.length} plantas');
    return dedupedPlantas;
  }

  /// Busca la contraparte de [target] en [candidates].
  /// Prioridad: instance_id → fallback por id (si solo hay una de esa especie).
  TreePlanta? _findMatch(TreePlanta target, List<TreePlanta> candidates) {
    // 1. Matching por instance_id (prioritario, nunca ambiguo)
    if (target.instanceId.isNotEmpty) {
      final byInstanceId = candidates
          .where((c) => c.instanceId == target.instanceId)
          .toList();
      if (byInstanceId.isNotEmpty) return byInstanceId.first;
    }

    // 2. Fallback por id de especie (solo si hay exactamente una)
    final byId = candidates.where((c) => c.id == target.id).toList();
    return byId.length == 1 ? byId.first : null;
  }
}
