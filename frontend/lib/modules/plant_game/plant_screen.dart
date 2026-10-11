import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/experimental.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:frontend/core/audio.dart';
import 'package:frontend/models/plant_catalog.dart';
import 'package:frontend/models/tree_models.dart';
import 'package:frontend/modules/plant_game/components/Button_Inventary.dart';
import 'package:frontend/modules/plant_game/components/Button_audio.dart';
import 'package:frontend/modules/plant_game/components/Button_credit.dart';
import 'package:frontend/modules/plant_game/components/Button_game_3d.dart';
import 'package:frontend/modules/plant_game/components/Button_game_compost.dart';
import 'package:frontend/modules/plant_game/components/Button_game_sun.dart';
import 'package:frontend/modules/plant_game/components/Button_game_water.dart';
import 'package:frontend/modules/plant_game/components/Button_help.dart';
import 'package:frontend/modules/plant_game/components/Button_profile.dart';
import 'package:frontend/modules/plant_game/components/Text_name.dart';
import 'package:frontend/modules/plant_game/components/background.dart';
import 'package:frontend/modules/plant_game/components/button_resource.dart';
import 'package:frontend/modules/plant_game/components/cooldown_indicator.dart';
import 'package:frontend/modules/plant_game/components/effect_animation.dart';
import 'package:frontend/modules/plant_game/components/panel_bar.dart';
import 'package:frontend/modules/plant_game/components/panel_resource.dart';
import 'package:frontend/modules/plant_game/components/panel_title.dart';
import 'package:frontend/modules/plant_game/components/plant.dart';
import 'package:frontend/modules/plant_game/mini_games/compost/compost_overlay.dart';
import 'package:frontend/modules/plant_game/mini_games/sun/sun_overlay.dart';
import 'package:frontend/modules/plant_game/mini_games/water/water_overlay.dart';
import 'package:frontend/modules/plant_game/plant_controller.dart';

/// Pantalla principal: planta activa, recursos, minijuegos y efectos.
class PlantGameScreen extends FlameGame {
  final BuildContext context;

  late final PlantController _controller;

  late PanelLayout _panelBar;
  late RowComponent _rowTop;
  late Panel_title _panelTitle;
  late Panel_resource_info _panelInfo;
  late ColumnComponent _layoutCenter;
  late PlantComponent _plant;
  late ColumnComponent _columnRight;
  late RowComponent _rowDown;

  bool _isLayoutReady = false;
  String _lastPlantType = '';
  String _lastPlantFase = '';

  /// Efecto de estado visible (peligro, crítico o lápida). Solo se cambia
  /// cuando cambia la categoría para no reiniciarlo en cada notificación.
  GameEffect? _stateEffect;
  EffectAnimation? _stateAnim;

  /// Minijuego abierto; evita abrir dos a la vez con taps repetidos.
  Component? _openMinigame;

  PlantGameScreen(this.context);

  @override
  Color backgroundColor() => const Color.fromARGB(255, 61, 67, 17);

  @override
  Future<void> onLoad() async {
    _controller = Provider.of<PlantController>(context, listen: false);
    await _controller.loadCurrentTree();
    await GameEffect.preloadAll(images);
    _controller.addListener(_onControllerChange);

    await AudioManager.musicaPrincipal();

    add(Background());

    if (kDebugMode) {
      add(_DebugTimeButton(
        onAdvance: (minutes) => _controller.debugAdvanceTime(minutes),
      )..priority = 100);
    }

    _panelTitle = Panel_title('PASTO');
    _panelInfo = Panel_resource_info('Estado normal');

    _rowTop = RowComponent(
      children: [
        PaddingComponent(
          padding: const EdgeInsets.only(right: 10),
          child: Button_credit(onPressed: () {}),
        ),
        PaddingComponent(
          padding: const EdgeInsets.only(right: 10),
          child: _panelTitle,
        ),
        PaddingComponent(
          padding: const EdgeInsets.only(right: 30),
          child: _panelInfo,
        ),
        PaddingComponent(
          padding: const EdgeInsets.only(right: 10),
          child: Button_help(onPressed: () {}),
        ),
        PaddingComponent(
          padding: const EdgeInsets.only(right: 10),
          child: Button_inventory(
            onPressed: () {
              AudioManager.stopMusica();
              GoRouter.of(context).go('/inventory');
            },
          ),
        ),
        Button_audio(onPressed: AudioManager.toggleMute),
      ],
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
    )
      ..anchor = Anchor.topCenter
      ..position = Vector2(size.x / 2, 30);
    add(_rowTop);

    _layoutCenter = ColumnComponent(
      children: [
        Button_sun_game(
          onPressed: () => _startMinigame(
            Minigame.sun,
            AudioManager.recolectarSoles,
            () => SunOverlay(context: context),
          ),
        ),
        PaddingComponent(
          padding: const EdgeInsets.only(top: 150),
          child: RowComponent(
            children: [
              PaddingComponent(
                padding: const EdgeInsets.only(right: 200),
                child: Button_water_game(
                  onPressed: () => _startMinigame(
                    Minigame.water,
                    AudioManager.recolectarAgua,
                    () => WaterOverlay(context: context),
                  ),
                ),
              ),
              Button_compost_game(
                context: context,
                onPressed: () => _startMinigame(
                  Minigame.compost,
                  AudioManager.recolectarComposta,
                  () => CompostOverlay(context: context),
                ),
              ),
            ],
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
          ),
        ),
      ],
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
    )
      ..anchor = Anchor.center
      ..position = Vector2(size.x / 2, size.y / 2 + 10);
    add(_layoutCenter);

    // Indicadores de cooldown sobre los botones de minijuego
    addAll([
      CooldownIndicator(
        context: context,
        game: Minigame.sun,
        position: Vector2(size.x / 2, size.y / 2 - 60),
      ),
      CooldownIndicator(
        context: context,
        game: Minigame.water,
        position: Vector2(size.x / 2 - 80, size.y / 2 + 90),
      ),
      CooldownIndicator(
        context: context,
        game: Minigame.compost,
        position: Vector2(size.x / 2 + 80, size.y / 2 + 90),
      ),
    ]);

    _panelBar = PanelLayout(context: context)
      ..anchor = Anchor.centerLeft
      ..position = Vector2(80, size.y / 2);
    add(_panelBar);

    final active = _controller.activePlant;
    _plant = PlantComponent(
      active?.id ?? 'pasto',
      active == null ? 2 : _stageOf(active.estado.fase),
      Vector2(size.x, size.y),
    )..anchor = Anchor.center;
    add(_plant);

    _columnRight = ColumnComponent(
      children: [
        PaddingComponent(
          padding: const EdgeInsets.only(bottom: 12),
          child: ResourceButton(context: context, resource: PlantResource.sol),
        ),
        PaddingComponent(
          padding: const EdgeInsets.only(bottom: 12),
          child: ResourceButton(context: context, resource: PlantResource.agua),
        ),
        ResourceButton(context: context, resource: PlantResource.fertilizante),
      ],
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
    )
      ..size = Vector2(size.x * 0.8, 80)
      ..anchor = Anchor.centerRight
      ..position = Vector2(size.x, size.y / 2);
    add(_columnRight);

    _rowDown = RowComponent(
      children: [
        PaddingComponent(
          padding: const EdgeInsets.only(right: 10),
          child: Button_profile(onPressed: AudioManager.click),
        ),
        PaddingComponent(
          padding: const EdgeInsets.only(right: 400),
          child: textName(context: context),
        ),
        Button_game_3d(
          onPressed: () {
            overlays.add('sync');
            AudioManager.click();
          },
        ),
      ],
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
    )
      ..anchor = Anchor.bottomCenter
      ..position = Vector2(size.x / 2, size.y - 10);
    add(_rowDown);

    _isLayoutReady = true;
    _applyLayout(size);

    // loadCurrentTree() notificó antes de registrar el listener: sincronizar
    // ahora el estado inicial (título, partículas, lápida).
    _onControllerChange();
  }

  @override
  void onRemove() {
    _controller.removeListener(_onControllerChange);
    super.onRemove();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (_isLayoutReady) _applyLayout(size);
  }

  void _applyLayout(Vector2 size) {
    // Altura de referencia 1080 para escalar el offset de la planta.
    final double scaleFactor = size.y / 1080.0;

    _panelBar.position = Vector2(50 + size.x * 0.05, size.y / 2);
    _rowTop.position = Vector2(size.x / 2, 30);
    _layoutCenter.position = Vector2(size.x / 2, size.y / 2 + 10);
    _plant
      ..scale = _plant.stageScale
      ..position = Vector2(
        size.x / 2,
        size.y / 2 + _plant.stageOffset.y * scaleFactor,
      );
    _columnRight.position = Vector2(size.x - 70, size.y * 0.48);
    _rowDown.position = Vector2(size.x / 2, size.y - 10);
  }

  /// Fase del .tree → índice de [PlantStage] (0 = muerta … 4 = ent).
  static int _stageOf(String fase) => fase == 'muerto' ? 0 : phaseNumber(fase);

  void _startMinigame(
    Minigame game,
    void Function() collectSound,
    Component Function() buildOverlay,
  ) {
    if (_openMinigame?.isMounted ?? false) return;

    if (!_controller.canPlay(game)) {
      final left = _controller.formatRemainingCooldown(
          _controller.remainingCooldown(game));
      debugPrint('[${game.name}] En cooldown — faltan $left');
      return;
    }

    collectSound();
    AudioManager.miniGames();
    add(_openMinigame = buildOverlay());
  }

  void _onControllerChange() {
    if (!_isLayoutReady) return;

    // Sin planta viva activa se muestra la primera muerta (con su lápida).
    final TreePlanta? plant = _controller.activePlant ??
        _controller.plants.where((p) => p.estado.fase == 'muerto').firstOrNull;
    if (plant == null) return;

    final fase = plant.estado.fase;
    final sol = plant.recursosAplicados.sol;
    final agua = plant.recursosAplicados.agua;
    final fert = plant.recursosAplicados.fertilizante;

    _panelInfo.setMessage(_statusMessage(fase, sol, agua, fert));

    // Cambio de planta activa o de fase (evolución/muerte)
    if (plant.id != _lastPlantType || fase != _lastPlantFase) {
      _lastPlantType = plant.id;
      _lastPlantFase = fase;
      _panelTitle.setTitle(PlantCatalog.displayName(plant.id));
      _plant.updatePlant(plant.id, _stageOf(fase));
      _setStateEffect(null); // re-evaluar el estado de la nueva planta
    }

    if (_controller.showEvolutionAnimation) {
      _controller.clearAnimationFlags();
      add(EffectAnimation(GameEffect.evolution, position: size / 2));
    }

    if (fase == 'muerto') {
      _setStateEffect(GameEffect.tombstone);
    } else if (sol <= 2 || agua <= 2) {
      _setStateEffect(GameEffect.critical);
    } else if (sol <= 4 || agua <= 4) {
      _setStateEffect(GameEffect.danger);
    } else {
      _setStateEffect(null);
    }
  }

  static String _statusMessage(String fase, int sol, int agua, int fert) {
    if (fase == 'muerto' || sol <= 0 || agua <= 0) return 'La planta murio';
    if (sol <= 2 || agua <= 2) return 'Estado critico';
    if (sol <= 4 || agua <= 4) return 'Necesita recursos';
    if (fert <= 1) return 'Necesita composta';
    if (sol >= 8 && agua >= 8 && fert >= 5) return 'La planta esta feliz';
    return 'Estado normal';
  }

  void _setStateEffect(GameEffect? effect) {
    if (effect == _stateEffect) return;
    _stateAnim?.removeFromParent();
    _stateAnim = null;
    _stateEffect = effect;
    if (effect == null) return;

    final position = effect == GameEffect.tombstone
        ? Vector2(size.x / 2, size.y / 2 + 70)
        : Vector2(size.x / 2, size.y * 0.3);
    add(_stateAnim = EffectAnimation(effect, position: position));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Botón de debug "T": avanza 10 minutos (decay + cooldowns). Solo en debug.
// ─────────────────────────────────────────────────────────────────────────────
class _DebugTimeButton extends PositionComponent
    with TapCallbacks, HasGameReference {
  final void Function(int minutes) onAdvance;

  _DebugTimeButton({required this.onAdvance});

  static final _paint = Paint()..color = const Color(0x80FF0000);
  static final _label = TextPaint(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
  );

  @override
  Future<void> onLoad() async {
    position = Vector2(game.size.x - 50, 50);
    size = Vector2(40, 40);
  }

  @override
  void render(Canvas canvas) {
    canvas.drawCircle((size / 2).toOffset(), size.x / 2, _paint);
    _label.render(canvas, 'T', size / 2, anchor: Anchor.center);
  }

  @override
  void onTapDown(TapDownEvent event) {
    onAdvance(10);
    event.continuePropagation = false;
  }
}
