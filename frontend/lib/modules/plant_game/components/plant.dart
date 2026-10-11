import 'package:flame/components.dart';
import 'package:flame/flame.dart';

import 'package:frontend/models/plant_catalog.dart';

enum PlantStage { dead, seed, bush, tree, ent }

/// Planta animada del escenario principal. El sheet se resuelve con
/// [PlantCatalog.spritePath] y se carga bajo demanda al cambiar de planta/fase.
class PlantComponent extends SpriteAnimationGroupComponent<PlantStage> {
  final String plantType;
  final int initialStage;

  PlantComponent(this.plantType, this.initialStage, Vector2 position)
      : super(position: position, size: Vector2(250, 250));

  @override
  Future<void> onLoad() async {
    scale = stageScale;
    await updatePlant(plantType, initialStage);
  }

  /// Muestra [newPlantType] en la fase [newStage] (0 = muerta … 4 = ent).
  Future<void> updatePlant(String newPlantType, int newStage) async {
    final stage = PlantStage.values[newStage];
    animations = {stage: await _loadAnimation(newPlantType, newStage)};
    current = stage;
  }

  PlantStage get _activeStage => current ?? PlantStage.values[initialStage];

  Vector2 get stageOffset {
    switch (_activeStage) {
      case PlantStage.seed:
        return Vector2(size.x / 2, size.y / 2 + 120);
      case PlantStage.dead:
        return Vector2(size.x / 2, size.y / 2 + 80);
      case PlantStage.bush:
      case PlantStage.tree:
      case PlantStage.ent:
        return Vector2(size.x / 2, size.y / 2 + 60);
    }
  }

  Vector2 get stageScale {
    switch (_activeStage) {
      case PlantStage.dead:
        return Vector2.all(0.25);
      case PlantStage.seed:
        return Vector2.all(0.4);
      case PlantStage.bush:
        return Vector2.all(0.5);
      case PlantStage.tree:
        return Vector2.all(0.6);
      case PlantStage.ent:
        return Vector2.all(0.7);
    }
  }

  // Sheets de 18 frames de 500 px en cuadrícula 6×3 (3000×1500): en una sola
  // fila medían 9000 px y no se dibujaban en GPUs con límite de 8192.
  // spritePath solo devuelve rutas presentes en el AssetManifest.
  static Future<SpriteAnimation> _loadAnimation(String plantId, int phase) async {
    final image = await Flame.images.load(
      await PlantCatalog.spritePath(plantId, phase),
    );
    return SpriteAnimation.fromFrameData(
      image,
      SpriteAnimationData.sequenced(
        amount: 18,
        amountPerRow: 6,
        stepTime: 0.1,
        textureSize: Vector2(500, 500),
      ),
    );
  }
}
