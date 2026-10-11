import 'package:flame/cache.dart';
import 'package:flame/components.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Efectos de sprite-sheet del juego (aplicar recursos, evolución, estados).
//
// Los sheets de 500 px están empaquetados en cuadrícula de 8 columnas para
// que ninguno supere 4000 px de ancho. Antes estaban en una sola fila
// (Sol.png medía 17 500 px, Evo.png 21 500 px) y superaban el tamaño máximo
// de textura de muchas GPU móviles, por lo que la animación no se dibujaba.
// ─────────────────────────────────────────────────────────────────────────────
enum GameEffect {
  sun('Animations/Sol.png', frames: 31),
  water('Animations/Water.png', frames: 15),
  compost('Animations/Abono.png', frames: 22),
  evolution('Animations/Evo.png', frames: 42),
  danger('Animations/Danger Particles.png', frames: 13, loop: true),
  critical('Animations/Critical Particles.png', frames: 13, loop: true),
  tombstone('Animations/TombStone_P.png',
      frames: 40, perRow: 40, frameSize: 32, displaySize: 150, loop: true);

  const GameEffect(
    this.file, {
    required this.frames,
    this.perRow = 8,
    this.frameSize = 500,
    this.displaySize = 300,
    this.loop = false,
  });

  final String file;
  final int frames;
  final int perRow;
  final double frameSize;
  final double displaySize;

  /// Los efectos en bucle (estados) los retira la pantalla; los de un solo
  /// ciclo se eliminan solos al terminar.
  final bool loop;

  /// Precarga todos los sheets para que el primer tap no espere la
  /// decodificación de la imagen.
  static Future<void> preloadAll(Images images) =>
      images.loadAll(values.map((e) => e.file).toList());
}

class EffectAnimation extends SpriteAnimationComponent {
  final GameEffect effect;

  EffectAnimation(this.effect, {required Vector2 position})
      : super(
          position: position,
          size: Vector2.all(effect.displaySize),
          anchor: Anchor.center,
          removeOnFinish: !effect.loop,
        );

  @override
  Future<void> onLoad() async {
    animation = await SpriteAnimation.load(
      effect.file,
      SpriteAnimationData.sequenced(
        amount: effect.frames,
        amountPerRow: effect.perRow,
        stepTime: 0.1,
        textureSize: Vector2.all(effect.frameSize),
        loop: effect.loop,
      ),
    );
  }
}
