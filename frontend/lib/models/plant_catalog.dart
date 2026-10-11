import 'package:flutter/services.dart';

/// Fases del `.tree` en orden de evolución.
const List<String> kPhases = ['semilla', 'arbusto', 'planta', 'ent'];

/// Número de sprite-sheet de una fase (`semilla` → 1 … `ent` → 4, `muerto` → 0).
int phaseNumber(String fase) => kPhases.indexOf(fase) + 1;

class _Species {
  final String key; // fragmento normalizado que identifica la especie
  final String type;
  final String displayName;
  final String? folder; // carpeta base en assets/images/Planta (null → Pasto)

  const _Species(this.key, this.type, this.displayName, [this.folder]);
}

/// Fuente única para clasificar una planta a partir de su id.
///
/// Los ids vienen de Unity y coinciden con el nombre de carpeta de la
/// especie, a veces con variante numérica o espacios ("Drago5",
/// "Pino romerón2", "AlcaparroEnano"). Se normalizan antes de comparar.
class PlantCatalog {
  PlantCatalog._();

  // El orden importa: los fragmentos más específicos van primero.
  static const List<_Species> _species = [
    _Species('alcaparroenano', 'xerofito', 'ALCAPARRO ENANO', 'AlcaparroEnano'),
    _Species('dividivi', 'xerofito', 'DIVIDIVI'),
    _Species('alcaparro', 'solar', 'ALCAPARRO'),
    _Species('cajeto', 'solar', 'CAJETO', 'Cajeto'),
    _Species('espino', 'solar', 'ESPINO', 'Espino'),
    _Species('drago', 'solar', 'DRAGO', 'Drago'),
    _Species('pino', 'montana', 'PINO ROMERÓN', 'PinoRomeron'),
    _Species('roble', 'montana', 'ROBLE', 'Roble'),
    _Species('nogal', 'montana', 'NOGAL', 'Nogal'),
    _Species('duraznillo', 'montana', 'DURAZNILLO', 'Duraznillo'),
    _Species('manzano', 'templado', 'MANZANO', 'Manzano'),
    _Species('mangle', 'templado', 'MANGLE', 'Mangle'),
    _Species('sietecueros', 'templado', 'SIETECUEROS', 'Sietecueros'),
    _Species('cedrillo', 'hidro', 'CEDRILLO', 'Cedrillo'),
    _Species('cedro', 'templado', 'CEDRO', 'Cedro'),
    _Species('cucharo', 'hidro', 'CUCHARO'),
    _Species('aliso', 'hidro', 'ALISO', 'Aliso'),
    _Species('pasto', 'pasto', 'PASTO', 'Pasto'),
  ];

  static String _normalize(String id) => id
      .toLowerCase()
      .replaceAll(RegExp(r'[\s_]'), '')
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');

  static _Species? _find(String id) {
    final n = _normalize(id);
    for (final s in _species) {
      if (n.contains(s.key)) return s;
    }
    return null;
  }

  /// Tipo de planta: `solar`, `xerofito`, `templado`, `montana`, `hidro` o `pasto`.
  static String typeOf(String id) => _find(id)?.type ?? 'pasto';

  /// Nombre de especie para mostrar en la UI.
  static String displayName(String id) =>
      _find(id)?.displayName ?? id.toUpperCase();

  // ── Sprites ────────────────────────────────────────────────────────────────

  static Future<List<String>>? _assets;

  /// Ruta (relativa a `assets/images/`) del sprite-sheet de [id] en la fase
  /// [phase] (1–4). Busca en la carpeta exacta del id, luego en la carpeta
  /// base de la especie y por último en Pasto.
  ///
  /// Acepta archivos con prefijo de autor (`Drago_Ana_Perez_fase4_ss.png`),
  /// que es como vienen muchos sheets de la fase ENT.
  static Future<String> spritePath(String id, int phase) async {
    final assets = await (_assets ??= _loadAssetList());
    final folders = [id, _find(id)?.folder, 'Pasto'].whereType<String>();
    final suffix = 'fase${phase}_ss.png';

    for (final folder in folders) {
      final dir = 'assets/images/Planta/$folder/';
      final inFolder = assets.where(
          (a) => a.startsWith(dir) && !a.substring(dir.length).contains('/'));
      final exact = '$dir$suffix';
      if (inFolder.contains(exact)) return exact.substring(_prefix.length);
      for (final a in inFolder) {
        if (a.endsWith('_$suffix')) return a.substring(_prefix.length);
      }
    }
    // Plantas muertas (fase 0) u otras sin sheet: arbusto de Pasto.
    return 'Planta/Pasto/fase2_ss.png';
  }

  static const _prefix = 'assets/images/';

  static Future<List<String>> _loadAssetList() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    return manifest.listAssets();
  }
}
