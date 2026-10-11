import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/modules/plant_game/mini_games/water/components/panel_water.dart';
import 'package:frontend/modules/plant_game/mini_games/water/components/text_water.dart';
import 'package:frontend/modules/plant_game/mini_games/water/components/water.dart';
import 'package:frontend/modules/plant_game/mini_games/water/water_logic.dart';
import 'package:frontend/modules/plant_game/plant_controller.dart';
import 'package:frontend/core/audio.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WaterOverlay — Flame overlay del minijuego del Agua
//
// Patrón unificado con SunOverlay:
//   1. Recibe [BuildContext] por constructor para acceder a PlantController.
//   2. Al terminar, llama controller.addWater() → TreeStorageService.saveTreeLocally()
//      (Regla de Oro: auto-sync inmediato del archivo .tree).
// ─────────────────────────────────────────────────────────────────────────────
class WaterOverlay extends FlameGame {
  final BuildContext context;

  late ButtonResourceWater buttonWater;
  late TextWater textComponents;

  final WaterLogic logic = WaterLogic();

  bool _gameEndHandled = false;

  WaterOverlay({required this.context});

  // ── Ciclo de vida ──────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    textComponents = TextWater();
    buttonWater = ButtonResourceWater(onPressed: _onWaterTapped);

    add(panelWater());
    add(buttonWater);
    add(textComponents);

    logic.start();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    buttonWater
      ..position = size / 2
      ..anchor = Anchor.center;
    textComponents
      ..position = size / 2
      ..anchor = Anchor.center;
  }

  // ── Input ──────────────────────────────────────────────────────────────────

  void _onWaterTapped() {
    AudioManager.regar(); 
    logic.onTap();
    textComponents.updateClicks(logic.clickCount);
  }

  // ── Game loop ──────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);
    logic.update(dt);
    textComponents.updateTime(logic.timeLeft);

    if (logic.shouldEndGame && !_gameEndHandled) {
      logic.markRewardProcessed();
      _gameEndHandled = true;
      _endMinigame();
    }
  }

  // ── Recompensa y cierre ────────────────────────────────────────────────────

  Future<void> _endMinigame() async {
    buttonWater.state = 2;
    final reward = logic.waterReward;

    try {
      final controller = Provider.of<PlantController>(context, listen: false);
      controller.addWater(reward);
      controller.markPlayed(Minigame.water);
      await controller.saveTree();
    } catch (e) {
      debugPrint('[WaterOverlay] Error al guardar: $e');
    }

    _showAlert(reward);
  }

  void _showAlert(int reward) {
    add(
      WaterAlertComponent(
        size: size,
        onClose: _closeOverlay,
        waterAmount: reward,
      ),
    );
  }

  void _closeOverlay() => removeFromParent();
}

// ─────────────────────────────────────────────────────────────────────────────
// WaterAlertComponent — Pantalla de resultado final.
// Muestra overlay unificado. Tap en cualquier parte cierra.
// ─────────────────────────────────────────────────────────────────────────────
class WaterAlertComponent extends PositionComponent with TapCallbacks {
  final VoidCallback onClose;
  final int waterAmount;
  bool _closed = false;

  WaterAlertComponent({
    required Vector2 size,
    required this.onClose,
    required this.waterAmount,
  }) : super(size: size);

  @override
  Future<void> onLoad() async {
    // Fondo semitransparente
    add(
      RectangleComponent(
        size: size,
        paint: Paint()..color = const Color(0xCC000000),
      ),
    );

    // Texto principal de resultado
    add(
      TextComponent(
        text: '💧 Agua obtenida\n+$waterAmount Gota${waterAmount != 1 ? 's' : ''}',
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Color(0xFF66CCFF),
            fontSize: 26,
            fontWeight: FontWeight.bold,
            fontFamily: 'Press Start 2P',
            shadows: [Shadow(blurRadius: 8, color: Colors.black)],
          ),
        ),
        anchor: Anchor.center,
        position: size / 2 - Vector2(0, 20),
      ),
    );

    // Instrucción de cierre
    add(
      TextComponent(
        text: 'Toca para continuar',
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Color(0xAAFFFFFF),
            fontSize: 14,
            fontFamily: 'Press Start 2P',
          ),
        ),
        anchor: Anchor.center,
        position: size / 2 + Vector2(0, 30),
      ),
    );
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (_closed) return;
    _closed = true;
    onClose();
    removeFromParent();
  }
}