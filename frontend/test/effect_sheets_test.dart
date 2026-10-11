import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/modules/plant_game/components/effect_animation.dart';

/// Comprueba que la configuración de cada [GameEffect] coincide con su
/// sprite-sheet: si `frames`/`perRow` no cuadran, Flame dibuja frames vacíos
/// (parpadeo) o corta la animación; si el sheet es demasiado ancho, la GPU
/// del móvil no lo puede cargar y el efecto no aparece.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('los sheets de plantas son cuadrículas 6×3 de 500 px', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final sheets = manifest
        .listAssets()
        .where((a) => a.startsWith('assets/images/Planta/') && a.endsWith('_ss.png'));
    expect(sheets, isNotEmpty);

    final wrong = <String>[];
    for (final path in sheets) {
      final data = await rootBundle.load(path);
      final buffer = await ui.ImmutableBuffer.fromUint8List(data.buffer.asUint8List());
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      if (descriptor.width != 3000 || descriptor.height != 1500) {
        wrong.add('$path (${descriptor.width}×${descriptor.height})');
      }
    }
    expect(wrong, isEmpty,
        reason: '18 frames de 500 px en 6 columnas × 3 filas; '
            'una sola fila (9000 px) no se dibuja en GPUs con límite 8192');
  });

  for (final effect in GameEffect.values) {
    test('${effect.name} cuadra con ${effect.file}', () async {
      final data = await rootBundle.load('assets/images/${effect.file}');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final image = (await codec.getNextFrame()).image;

      final cols = image.width ~/ effect.frameSize;
      final rows = image.height ~/ effect.frameSize;
      expect(cols, effect.perRow, reason: 'columnas del sheet');
      expect(rows, (effect.frames / effect.perRow).ceil(), reason: 'filas');
      expect(image.width, lessThanOrEqualTo(4096), reason: 'ancho máx. GPU');
      expect(image.height, lessThanOrEqualTo(4096), reason: 'alto máx. GPU');
    });
  }
}
