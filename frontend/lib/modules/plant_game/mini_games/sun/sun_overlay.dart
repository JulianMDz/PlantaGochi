import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/modules/plant_game/mini_games/sun/components/panel_sun.dart';
import 'package:frontend/modules/plant_game/mini_games/sun/sun_logic.dart';
import 'package:frontend/modules/plant_game/plant_controller.dart';
import 'package:frontend/core/audio.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SunOverlay — Flame overlay del minijuego del Sol
//
// Recibe el [BuildContext] de Flutter por constructor (puente de estado) para:
//   1. Notificar al PlantController en memoria (Provider).
//   2. Llamar a TreeStorageService.saveTreeLocally() — Regla de Oro del .tree.
//
// Patrón de cierre: add(SunOverlay(context: context)) desde PlantGameScreen.
// ─────────────────────────────────────────────────────────────────────────────
class SunOverlay extends FlameGame with TapCallbacks {
  /// BuildContext inyectado desde PlantGameScreen. Nunca debe ser nulo.
  final BuildContext context;

  final SunLogic _logic = SunLogic();

  late PanelSun _panel;
  late _ClicksHud _clicksHud;
  late _TierHud _tierHud;

  bool _gameEndHandled = false;

  SunOverlay({required this.context});

  // ── Ciclo de vida ──────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    // Panel central — sprite del Tier actual (empieza Bronce → índice 1)
    _panel = PanelSun();
    await add(_panel);

    // HUD clicks restantes
    _clicksHud = _ClicksHud(remaining: SunLogic.maxClicks);
    await add(_clicksHud);

    // HUD nombre del Tier
    _tierHud = _TierHud(tierName: _logic.currentTier.label);
    await add(_tierHud);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _clicksHud
      ..position = Vector2(size.x / 2, 40)
      ..anchor = Anchor.topCenter;
    _tierHud
      ..position = Vector2(size.x / 2, size.y - 60)
      ..anchor = Anchor.bottomCenter;
  }

  // ── Input ──────────────────────────────────────────────────────────────────

  @override
  void onTapDown(TapDownEvent event) {
    if (_logic.isGameOver) return;

    AudioManager.sol();
    final newTier = _logic.onTap();

    // Actualizar sprite del panel al Tier resultante
    _panel.cambiarEstado(newTier.spriteIndex);

    // Actualizar HUD (métodos renombrados para no chocar con Component.update)
    _clicksHud.setRemaining(SunLogic.maxClicks - _logic.clickCount);
    _tierHud.setTierName(newTier.label);
  }

  // ── Game loop ──────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);

    if (_logic.shouldEndGame && !_gameEndHandled) {
      _logic.markRewardProcessed();
      _gameEndHandled = true;
      _endMinigame();
    }
  }

  // ── Recompensa y cierre ────────────────────────────────────────────────────

  Future<void> _endMinigame() async {
    final reward = _logic.sunReward;
    final tierName = _logic.currentTier.label;

    try {
      final controller = Provider.of<PlantController>(context, listen: false);
      // addSun actualiza memoria; saveTree() persiste en SharedPreferences
      // Y exporta al archivo físico si tiene permiso (Regla de Oro).
      controller.addSun(reward);
      controller.markPlayed(Minigame.sun);
      await controller.saveTree();
    } catch (e) {
      debugPrint('[SunOverlay] Error al guardar: $e');
    }

    _showResult(reward: reward, tierName: tierName);
  }

  void _showResult({required int reward, required String tierName}) {
    add(
      _SunResultAlert(
        reward: reward,
        tierName: tierName,
        size: size,
        onClose: _closeOverlay,
      ),
    );
  }

  void _closeOverlay() => removeFromParent();
}

// ─────────────────────────────────────────────────────────────────────────────
// _ClicksHud — HUD: clicks restantes
// Método de actualización: [setRemaining] (no "update" para evitar colisión
// con Component.update(double dt) de Flame).
// ─────────────────────────────────────────────────────────────────────────────
class _ClicksHud extends TextComponent {
  _ClicksHud({required int remaining})
      : super(
          text: '⚡ Clicks: $remaining',
          textRenderer: TextPaint(
            style: const TextStyle(
              color: Color(0xFFFFE566),
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Press Start 2P',
              shadows: [Shadow(blurRadius: 4, color: Colors.black)],
            ),
          ),
          anchor: Anchor.topCenter,
        );

  void setRemaining(int remaining) {
    text = '⚡ Clicks: $remaining';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TierHud — HUD: Tier actual
// ─────────────────────────────────────────────────────────────────────────────
class _TierHud extends TextComponent {
  _TierHud({required String tierName})
      : super(
          text: tierName,
          textRenderer: TextPaint(
            style: const TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Press Start 2P',
              shadows: [Shadow(blurRadius: 6, color: Color(0xFFFF9500))],
            ),
          ),
          anchor: Anchor.bottomCenter,
        );

  void setTierName(String tierName) {
    text = tierName;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SunResultAlert — Pantalla de resultado final.
// Un tap en cualquier lugar cierra el overlay.
// ─────────────────────────────────────────────────────────────────────────────
class _SunResultAlert extends PositionComponent with TapCallbacks {
  final int reward;
  final String tierName;
  final VoidCallback onClose;
  bool _closed = false;

  _SunResultAlert({
    required this.reward,
    required this.tierName,
    required Vector2 size,
    required this.onClose,
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
        text: '☀️ $tierName\n+$reward Sol${reward > 1 ? 'es' : ''}',
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Color(0xFFFFE566),
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
