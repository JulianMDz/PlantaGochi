import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/modules/plant_game/mini_games/compost/components/compost.dart';
import 'package:frontend/modules/plant_game/mini_games/compost/components/panel_compost.dart';
import 'package:frontend/modules/plant_game/mini_games/compost/components/text_compost.dart';
import 'package:frontend/modules/plant_game/mini_games/compost/compost_logic.dart';
import 'package:frontend/modules/plant_game/plant_controller.dart';
import 'package:frontend/core/audio.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CompostOverlay — Flame overlay del minijuego de Composta
//
// Patrón unificado con SunOverlay y WaterOverlay:
//   1. Recibe [BuildContext] por constructor para acceder a PlantController.
//   2. Al terminar, llama controller.addCompost() → TreeStorageService.saveTreeLocally()
//      (Regla de Oro: auto-sync inmediato del archivo .tree).
// ─────────────────────────────────────────────────────────────────────────────
class CompostOverlay extends FlameGame {
  final BuildContext context;

  late CompostGrid compostGrid;
  late textCompost textComponents;

  final CompostLogic logic = CompostLogic();

  bool _gameEndHandled = false;

  CompostOverlay({required this.context});

  // ── Ciclo de vida ──────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    textComponents = textCompost();
    compostGrid = CompostGrid(onCellTap: _onCompostTapped);

    add(panelCompost());
    add(compostGrid);
    add(textComponents);

    logic.start();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    compostGrid
      ..position = size / 2
      ..anchor = Anchor.center;
    textComponents
      ..position = size / 2
      ..anchor = Anchor.center;
  }

  // ── Input ──────────────────────────────────────────────────────────────────

  void _onCompostTapped(int row, int col, bool isCorrect) {
    AudioManager.abono();
    logic.onCellTap(row, col, isCorrect);
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
    compostGrid.state = 2;
    final compostGained = logic.compostReward; // 0 a 4 unidades de composta

    try {
      final controller = Provider.of<PlantController>(context, listen: false);

      // Añadir la composta ganada al inventario
      // La conversión automática (4 compost = 1 fertilizante) se hace en addCompost()
      if (compostGained > 0) {
        controller.addCompost(compostGained);
        controller.markPlayed(Minigame.compost);
        await controller.saveTree();
      }
    } catch (e) {
      debugPrint('[CompostOverlay] Error al guardar: $e');
    }

    _showAlert(compostGained);
  }

  void _showAlert(int compostGained) {
    add(
      CompostAlertComponent(
        size: size,
        onClose: _closeOverlay,
        compostAmount: compostGained,
      ),
    );
  }

  void _closeOverlay() => removeFromParent();
}

// ─────────────────────────────────────────────────────────────────────────────
// CompostAlertComponent — Pantalla de resultado final.
// Muestra overlay unificado. Tap en cualquier parte cierra.
// ─────────────────────────────────────────────────────────────────────────────
class CompostAlertComponent extends PositionComponent with TapCallbacks {
  final VoidCallback onClose;
  final int compostAmount;
  final int fertilizerAmount;
  bool _closed = false;

  CompostAlertComponent({
    required Vector2 size,
    required this.onClose,
    required this.compostAmount,
    this.fertilizerAmount = 0,
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

    // Texto de composta ganada
    add(
      TextComponent(
        text: '🌱 +$compostAmount Composta',
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Color(0xFF66FF66),
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: 'Press Start 2P',
            shadows: [Shadow(blurRadius: 8, color: Colors.black)],
          ),
        ),
        anchor: Anchor.center,
        position: size / 2 - Vector2(0, 10),
      ),
    );

    // Texto de fertilizante convertido (si aplica)
    if (fertilizerAmount > 0) {
      add(
        TextComponent(
          text: '🧪 +$fertilizerAmount Fertilizante',
          textRenderer: TextPaint(
            style: const TextStyle(
              color: Color(0xFFFFAA00),
              fontSize: 18,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(blurRadius: 8, color: Colors.black)],
            ),
          ),
          anchor: Anchor.center,
          position: size / 2 - Vector2(0, 40),
        ),
      );
    }

    // Instrución de cierre
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
        position: size / 2 + Vector2(0, fertilizerAmount > 0 ? 50 : 30),
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
