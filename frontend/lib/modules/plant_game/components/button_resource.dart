import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/core/audio.dart';
import 'package:frontend/modules/plant_game/components/effect_animation.dart';
import 'package:frontend/modules/plant_game/plant_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ResourceButton
//
// Botón lateral que aplica 1 unidad de sol, agua o fertilizante a la planta
// activa.
//   • Muestra el stock del inventario y se actualiza con PlantController.
//   • Al pulsar: aplica el recurso → sonido + animación sobre la planta.
//   • Si no hay stock o la planta está llena, lo indica con un texto flotante.
// ─────────────────────────────────────────────────────────────────────────────
class ResourceButton extends SpriteButtonComponent with HasGameReference {
  final BuildContext context;
  final PlantResource resource;

  late final PlantController _controller;
  late final TextComponent _countText;

  /// Efecto en curso: un tap nuevo lo reinicia en vez de apilar otro encima.
  EffectAnimation? _effect;

  ResourceButton({required this.context, required this.resource})
      : super(size: Vector2.zero(), button: null, buttonDown: null);

  _ResourceStyle get _cfg => _ResourceStyle.values[resource.index];

  @override
  Future<void> onLoad() async {
    _controller = Provider.of<PlantController>(context, listen: false);
    button = await Sprite.load('Botones/${_cfg.sprite}_02.png');
    buttonDown = await Sprite.load('Botones/${_cfg.sprite}_01.png');
    size = button.srcSize / 2.3;

    _countText = TextComponent(
      text: '${_controller.stockOf(resource)}',
      textRenderer: _textPaint(Colors.white),
      position: Vector2(2, 2),
    );
    add(_countText);

    _controller.addListener(_onControllerChange);
    onPressed = _onTap;
  }

  @override
  void onRemove() {
    _controller.removeListener(_onControllerChange);
    super.onRemove();
  }

  void _onControllerChange() {
    _countText.text = '${_controller.stockOf(resource)}';
  }

  void _onTap() {
    switch (_controller.spend(resource)) {
      case SpendResult.applied:
        _cfg.sound();
        _effect?.removeFromParent();
        _effect = EffectAnimation(_cfg.effect, position: game.size / 2);
        game.add(_effect!);
      case SpendResult.noStock:
        _showHint('Sin stock');
      case SpendResult.plantFull:
        _showHint('¡Lleno!');
    }
  }

  /// Texto que sube desde el botón y desaparece.
  void _showHint(String text) {
    add(TextComponent(
      text: text,
      textRenderer: _textPaint(const Color(0xFFFFE566)),
      anchor: Anchor.bottomCenter,
      position: Vector2(size.x / 2, 0),
    )..addAll([
        MoveByEffect(Vector2(0, -16), EffectController(duration: 0.8)),
        RemoveEffect(delay: 0.8),
      ]));
  }

  static TextPaint _textPaint(Color color) => TextPaint(
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontFamily: 'Press Start 2P',
          shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
        ),
      );
}

/// Sprite, sonido y efecto de cada recurso (mismo orden que [PlantResource]).
enum _ResourceStyle {
  sol('Boton_RecursoSol', GameEffect.sun, AudioManager.sol),
  agua('Boton_RecursoAgua', GameEffect.water, AudioManager.regar),
  fertilizante('Boton_RecursoAbono', GameEffect.compost, AudioManager.abono);

  const _ResourceStyle(this.sprite, this.effect, this.sound);
  final String sprite;
  final GameEffect effect;
  final void Function() sound;
}
