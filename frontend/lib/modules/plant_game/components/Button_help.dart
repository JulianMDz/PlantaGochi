import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/input.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/audio.dart';

class Button_help extends SpriteButtonComponent with HasGameRef {
  Button_help({
    required void Function() onPressed,
  }) : super(
          size: Vector2.zero(),
          button: null,
          buttonDown: null,
          onPressed: onPressed,
        );

  @override
  Future<void> onLoad() async {
    button = await Sprite.load('Botones/Boton_Ayuda_02.png');
    buttonDown = await Sprite.load('Botones/Boton_Ayuda_01.png');
    size = button.srcSize / 2.5;

    onPressed = () {
      AudioManager.click();
      gameRef.add(_HelpOverlay(gameRef: gameRef));
    };
  }
}

// -------------------------------------------------------
// Overlay de ayuda con scroll
// -------------------------------------------------------
class _HelpOverlay extends PositionComponent with TapCallbacks, DragCallbacks {
  final FlameGame gameRef;

  double _scrollOffset = 0;
  double _imageH = 0;
  double _visibleH = 0;
  double _panelX = 0;
  double _panelY = 0;
  double _panelW = 0;

  late SpriteComponent _imageComponent;

  _HelpOverlay({required this.gameRef});

  @override
  Future<void> onLoad() async {
    size = gameRef.size;
    priority = 50;

    // Fondo semitransparente
    add(RectangleComponent(
      size: gameRef.size,
      paint: Paint()..color = const Color(0x88000000),
    ));

    // Calcular dimensiones
    final imageSprite = await Sprite.load('Paneles/Panel_Ayuda.jpg');
    _panelW = gameRef.size.x * 0.5;
    final double imageRatio = imageSprite.srcSize.y / imageSprite.srcSize.x;
    _imageH = _panelW * imageRatio;

    _visibleH = gameRef.size.y * 0.90;
    _panelX = (gameRef.size.x - _panelW) / 2;
    _panelY = (gameRef.size.y - _visibleH) / 2;

    // Imagen — se mueve con el scroll
    _imageComponent = SpriteComponent()
      ..sprite = imageSprite
      ..size = Vector2(_panelW, _imageH)
      ..position = Vector2(_panelX, _panelY);

    add(_imageComponent);

    // Botón cerrar
    add(_CloseButton(
      onClose: () => removeFromParent(),
    )
      ..position = Vector2(_panelX + _panelW - 5, _panelY + 30)
      ..size = Vector2(33, 33));
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Recortar la imagen al área visible usando canvas directamente
    // Se dibuja un rectángulo opaco arriba y abajo del área visible
    // para tapar lo que se sale
    // Clip manual — tapa lo que sobresale arriba
    canvas.drawRect(
      Rect.fromLTWH(0, 0, gameRef.size.x, _panelY),
      Paint()..color = const Color(0x88000000),
    );

    // Tapa lo que sobresale abajo
    canvas.drawRect(
      Rect.fromLTWH(0, _panelY + _visibleH, gameRef.size.x,
          gameRef.size.y - (_panelY + _visibleH)),
      Paint()..color = const Color(0x88000000),
    );
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    final double maxScroll = (_imageH - _visibleH).clamp(0, double.infinity);
    _scrollOffset -= event.localDelta.y;
    _scrollOffset = _scrollOffset.clamp(0, maxScroll);
    _imageComponent.position = Vector2(_panelX, _panelY - _scrollOffset);
  }

  @override
  void onTapDown(TapDownEvent event) {
    event.continuePropagation = false;
  }
}

// -------------------------------------------------------
// Botón cerrar
// -------------------------------------------------------
class _CloseButton extends SpriteComponent with TapCallbacks {
  final VoidCallback onClose;

  _CloseButton({required this.onClose});

  @override
  Future<void> onLoad() async {
    sprite = await Sprite.load('Botones/Boton_Cerrar_01.png');
  }

  @override
  void onTapDown(TapDownEvent event) {
    AudioManager.click();
    onClose();
    event.continuePropagation = false;
  }
}