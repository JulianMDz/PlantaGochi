import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/modules/plant_game/plant_controller.dart';

/// Cuenta atrás ("9:32") sobre el botón de un minijuego en cooldown.
/// Vacío cuando el minijuego está disponible.
class CooldownIndicator extends PositionComponent {
  final BuildContext context;
  final Minigame game;

  late final PlantController _controller;
  late final TextComponent _text;
  int _lastSecond = -1;

  CooldownIndicator({
    required this.context,
    required this.game,
    required Vector2 position,
  }) : super(position: position);

  @override
  Future<void> onLoad() async {
    _controller = Provider.of<PlantController>(context, listen: false);
    _text = TextComponent(
      text: '',
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontFamily: 'Press Start 2P',
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(color: Colors.black, blurRadius: 4, offset: Offset(2, 2)),
          ],
        ),
      ),
    );
    add(_text);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Actualizar el texto una vez por segundo, no en cada frame.
    final second = DateTime.now().second;
    if (second == _lastSecond) return;
    _lastSecond = second;

    final remaining = _controller.remainingCooldown(game);
    _text.text =
        remaining == null ? '' : _controller.formatRemainingCooldown(remaining);
  }
}
