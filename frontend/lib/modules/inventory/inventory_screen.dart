import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/audio.dart';
import 'package:frontend/modules/inventory/components/button_close.dart';
import 'package:frontend/modules/inventory/components/filter_panel.dart';
import 'package:frontend/modules/inventory/components/image_button.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:frontend/models/plant_catalog.dart';
import 'package:frontend/models/tree_models.dart';
import 'package:frontend/modules/plant_game/plant_controller.dart';

class InventoryScreen extends FlameGame with DragCallbacks {
  final BuildContext context;

  InventoryScreen(this.context);

  PlantController? _controller;
  TreePlanta? _selectedPlant;
  List<PositionComponent> _plantSlots = [];

  String? _filterCategory;
  String? _filterStage;
  String? _filterUrgency;

  // Scroll vertical
  double _scrollOffsetY = 0;
  double _maxScrollY = 0;
  bool _isDragging = false;

  // Constantes de layout compartidas
  static const double _collapsedH = 56.0;
  static const double _marginTop = 42.0;
  static const int _columns = 3;

  /// Sprite-sheet resuelto (y ya en caché) de cada planta, por instanceId.
  final Map<String, String> _spritePaths = {};

  /// Primer frame del sprite-sheet de la planta (precargado en [onLoad]).
  Sprite _plantSprite(TreePlanta plant) {
    final img = images.fromCache(
        _spritePaths[plant.instanceId] ?? 'Planta/Pasto/fase2_ss.png');
    return Sprite(img, srcSize: Vector2.all(500));
  }

  @override
  Future<void> onLoad() async {
    final ctx = context;
    _controller = Provider.of<PlantController>(ctx, listen: false);
    _selectedPlant = _controller?.activePlant;

    await images.loadAll([
      'Paneles/Fondo_Inv_01.png',
      'Paneles/Panel_DescripciónPlanta_05.png',
      'Inventario/Panel_InvEspacio_01.png',
      'Inventario/Panel_InvEspacio_02.png',
      'Planta/Pasto/fase1_ss.png',
      'Planta/Pasto/fase2_ss.png',
      'Planta/Pasto/fase3_ss.png',
      'Planta/Pasto/fase4_ss.png',
      'Botones/Boton_Cerrar_01.png',
      'Botones/Boton_Categoría_01.png',
      'Botones/Boton_Categoría_02.png',
      'Botones/Boton_Categoría_03.png',
      'Botones/Boton_Categoría_04.png',
      'Botones/Boton_Categoría_05.png',
      'Botones/Boton_Estado_01.png',
      'Botones/Boton_Estado_02.png',
      'Botones/Boton_Estado_03.png',
      'Botones/Boton_Estado_04.png',
      'Botones/Boton_Urgencia_01.png',
      'Botones/Boton_Urgencia_02.png',
      'Botones/Boton_Urgencia_03.png',
      'Botones/Boton_Filtro.png',
      'Botones/Boton_General_01a.png',
      'Iconos/Icono_Semaforo_01.png',
      'Iconos/Icono_Semaforo_02.png',
      'Iconos/Icono_Semaforo_03.png',
      'Iconos/Icono_Semaforo_04.png',
    ]);

    await AudioManager.musicaInventario();

    for (final plant in _controller?.plants ?? <TreePlanta>[]) {
      final path = await PlantCatalog.spritePath(
          plant.id, phaseNumber(plant.estado.fase));
      await images.load(path);
      _spritePaths[plant.instanceId] = path;
    }

    add(SpriteComponent()
      ..sprite = Sprite(images.fromCache('Paneles/Fondo_Inv_01.png'))
      ..size = size);

    add(FilterPanelComponent(gameRef: this));

    final closeBtn = CloseButtonComponent(ctx);
    closeBtn.position = Vector2(size.x - 82, 10);
    closeBtn.size = Vector2(40, 40);
    closeBtn.priority = 20;
    add(closeBtn);

    _loadPlantSlots();
  }

  String _getCategoryIconPath(String plantId) {
    switch (PlantCatalog.typeOf(plantId)) {
      case 'solar': return 'Botones/Boton_Categoría_01.png';
      case 'xerofito': return 'Botones/Boton_Categoría_02.png';
      case 'templado': return 'Botones/Boton_Categoría_03.png';
      case 'montana': return 'Botones/Boton_Categoría_04.png';
      case 'hidro': return 'Botones/Boton_Categoría_05.png';
      default: return 'Botones/Boton_Categoría_01.png';
    }
  }

  String _getStageIconPath(String fase) {
    switch (fase) {
      case 'semilla': return 'Botones/Boton_Estado_01.png';
      case 'arbusto': return 'Botones/Boton_Estado_02.png';
      case 'planta': return 'Botones/Boton_Estado_03.png';
      case 'ent': return 'Botones/Boton_Estado_04.png';
      default: return 'Botones/Boton_Estado_01.png';
    }
  }

 String _getTrafficLightIconPath(int sol, int agua) {
  final bool solBajo = sol < 2;
  final bool aguaBaja = agua < 2;

  // Ambos bien
  if (!solBajo && !aguaBaja) {
    return 'Iconos/Icono_Semaforo_01.png';
  }

  // Solo agua baja
  if (aguaBaja && !solBajo) {
    return 'Iconos/Icono_Semaforo_02.png';
  }

  // Solo sol bajo
  if (solBajo && !aguaBaja) {
    return 'Iconos/Icono_Semaforo_03.png';
  }

  // Ambos bajos
  return 'Iconos/Icono_Semaforo_04.png';
}

  // ── Cálculo de layout compartido ─────────────────────
  double _getSlotSize() {
    final double availableH = size.y - _collapsedH - _marginTop;
    return availableH * 0.40;
  }

  double _getGap() {
    final double slotSize = _getSlotSize();
    final double totalSlotsW = slotSize * _columns;
    final double totalGap = size.x - totalSlotsW;
    return totalGap / (_columns + 1);
  }

  // Posición X base de una columna
  double _colToX(int col) {
    final double slotSize = _getSlotSize();
    final double gap = _getGap();
    return gap * (col + 1) + slotSize * col;
  }

  // Posición Y base de una fila (sin scroll)
  double _rowToBaseY(int row) {
    final double slotSize = _getSlotSize();
    final double gap = _getGap();
    return _marginTop + gap * (row + 1) + slotSize * row;
  }

  void _loadPlantSlots() {
    for (final slot in _plantSlots) {
      slot.removeFromParent();
    }
    _plantSlots.clear();

    _controller = Provider.of<PlantController>(context, listen: false);
  
    final plants = _getFilteredPlants();
    if (plants.isEmpty) {
      return;
    }

    final int displayCount = plants.length;
    final int rows = (displayCount / _columns).ceil();
    final double slotSize = _getSlotSize();
    final double gap = _getGap();

    // Alto total del contenido — para calcular scroll máximo
    final double totalContentH = _marginTop + rows * slotSize + (rows + 1) * gap;
    // Área visible disponible para los slots (sin drawer ni margen)
    final double visibleH = size.y - _collapsedH;
    _maxScrollY = (totalContentH - visibleH).clamp(0, double.infinity);
    _scrollOffsetY = 0;

    for (int i = 0; i < displayCount; i++) {
      final int col = i % _columns;
      final int row = i ~/ _columns;
      final double x = _colToX(col);
      final double y = _rowToBaseY(row);
      _addPlantSlot(Vector2(x, y), slotSize, slotSize, plants[i]);
    }
  }

  List<TreePlanta> _getFilteredPlants() {
    final plants = _controller?.plants ?? [];

    return plants.where((plant) {

      // -------------------------
      // CATEGORY
      // -------------------------
      if (_filterCategory != null) {
        final category = PlantCatalog.typeOf(plant.id);

        if (category != _filterCategory) {
          return false;
        }
      }

      // -------------------------
      // STAGE
      // -------------------------
      if (_filterStage != null) {
        final fase = plant.estado.fase;

        if (fase != _filterStage) {
          return false;
        }
      }

      // -------------------------
      // URGENCY
      // -------------------------
      if (_filterUrgency != null) {

        final sol = plant.recursosAplicados.sol;
        final agua = plant.recursosAplicados.agua;

        final bool solBajo = sol <= 4;
        final bool aguaBaja = agua <= 4;

        String urgency;

        // TODO BIEN
        if (!solBajo && !aguaBaja) {
          urgency = 'normal';
        }

        // ALGUNO BAJO
        else if (solBajo != aguaBaja) {
          urgency = 'warning';
        }

        // AMBOS BAJOS
        else {
          urgency = 'critical';
        }

        if (urgency != _filterUrgency) {
          return false;
        }
      }

      return true;

    }).toList();
  }

  void _addPlantSlot(
      Vector2 pos, double slotW, double slotH, TreePlanta plant) {
    final slot = PositionComponent()
      ..position = pos
      ..size = Vector2(slotW, slotH);

    final isSelected = identical(plant, _selectedPlant);
    final isAlive = plant.estado.fase != 'muerto' && plant.desbloqueada;

    slot.add(SpriteComponent()
      ..sprite = Sprite(images.fromCache(
        isSelected
            ? 'Inventario/Panel_InvEspacio_01.png'
            : 'Inventario/Panel_InvEspacio_02.png',
      ))
      ..size = Vector2(slotW, slotH));

    if (isAlive) {
      final plantId = plant.id;
      final plantPhase = plant.estado.fase;
      final displayName = PlantCatalog.displayName(plantId);

      slot.add(TextComponent(
        text: displayName,
        anchor: Anchor.topCenter,
        position: Vector2(slotW / 2, slotH * 0.16),
        textRenderer: TextPaint(
          style: const TextStyle(
            fontSize: 10,
            fontFamily: 'Press Start 2P',
            color: Color(0xFF3E2A1F),
            fontWeight: FontWeight.bold,
          ),
        ),
      ));

      slot.add(SpriteComponent()
        ..sprite = _plantSprite(plant)
        ..size = Vector2.all(slotW * 0.4)
        ..anchor = Anchor.center
        ..position = Vector2(slotW / 2, slotH / 2));

      final double iconH = slotH * 0.16;
      final double iconY = slotH - iconH - slotH * 0.13;
      const double iconGap = 6.0;

      final recursos = plant.recursosAplicados;
      final sol = recursos.sol;
      final agua = recursos.agua;
      final categoryIcon = _getCategoryIconPath(plantId);
      final stageIcon = _getStageIconPath(plantPhase);
      final trafficLightIcon = _getTrafficLightIconPath(sol, agua);

      final iconPaths = [
        categoryIcon,
        stageIcon,
        trafficLightIcon,
      ];

      final List<double> iconWidths = iconPaths.map((path) {
        final iconImg = images.fromCache(path);
        final double ratio = iconImg.width / iconImg.height;
        return iconH * ratio;
      }).toList();

      final double totalIconW = iconWidths.fold(0.0, (sum, w) => sum + w) +
          iconGap * (iconPaths.length - 1);
      double ix = (slotW - totalIconW) / 2;

      for (int i = 0; i < iconPaths.length; i++) {
        final iconImg = images.fromCache(iconPaths[i]);
        final double ratio = iconImg.width / iconImg.height;
        final double iconW = iconH * ratio;
        slot.add(SpriteComponent()
          ..sprite = Sprite(images.fromCache(iconPaths[i]))
          ..size = Vector2(iconW, iconH)
          ..position = Vector2(ix, iconY));
        ix += iconW + iconGap;
      }

      slot.add(_TappableSlot(
        slotSize: Vector2(slotW, slotH),
        gameRef: this,
        plant: plant,
        onTap: (TreePlanta p) {
          // Solo seleccionar si no se estaba arrastrando
          if (_isDragging) return;
          _onPlantSelected(p);
        },
      )..size = Vector2(slotW, slotH));
    } else {
      slot.add(TextComponent(
        text: 'MUERTA',
        anchor: Anchor.center,
        position: Vector2(slotW / 2, slotH / 2),
        textRenderer: TextPaint(
          style: const TextStyle(
            fontSize: 10,
            fontFamily: 'Press Start 2P',
            color: Color(0xFF666666),
            fontWeight: FontWeight.bold,
          ),
        ),
      ));
    }

    add(slot);
    _plantSlots.add(slot);
  }

  void _onPlantSelected(TreePlanta plant) {
    _selectedPlant = plant;
    _controller?.selectPlant(plant);
    _loadPlantSlots();
  }

  void applyCategoryFilter(String? cat) {

    if (_filterCategory == cat) {
      _filterCategory = null;
    } else {
      _filterCategory = cat;
    }
    _loadPlantSlots();
  }

  void applyStageFilter(String? stage) {

    if (_filterStage == stage) {
      _filterStage = null;
    } else {
      _filterStage = stage;
    }
    _loadPlantSlots();
  }

  void applyUrgencyFilter(String? urgency) {

    if (_filterUrgency == urgency) {
      _filterUrgency = null;
    } else {
      _filterUrgency = urgency;
    }
    _loadPlantSlots();
  }


  // ── Scroll vertical ───────────────────────────────────
  @override
  void onDragUpdate(DragUpdateEvent event) {
    final dy = event.localDelta.y;

    // Marcar como dragging si el movimiento es suficiente
    if (dy.abs() > 12) {
      _isDragging = true;
    }

    // Scroll: arrastrar hacia arriba = ver más plantas abajo
    _scrollOffsetY -= dy;
    _scrollOffsetY = _scrollOffsetY.clamp(0.0, _maxScrollY);

    // Mover cada slot según el scroll
    for (int i = 0; i < _plantSlots.length; i++) {
      final int row = i ~/ _columns;
      final int col = i % _columns;
      _plantSlots[i].position.x = _colToX(col);
      _plantSlots[i].position.y = _rowToBaseY(row) - _scrollOffsetY;
    }
  }

@override
void onDragEnd(DragEndEvent event) {
  super.onDragEnd(event);
  Future.delayed(const Duration(milliseconds: 150), () {
    _isDragging = false;
  });
}
}

// -------------------------------------------------------
// Slot tappable
// -------------------------------------------------------
class _TappableSlot extends PositionComponent with TapCallbacks {
  final Vector2 slotSize;
  final FlameGame gameRef;
  final TreePlanta plant;
  final void Function(TreePlanta) onTap;
  bool _expanded = false;

  _TappableSlot({required this.slotSize, required this.gameRef, required this.plant, required this.onTap});

  @override
  void onTapDown(TapDownEvent event) {
    if (_expanded) return;

    AudioManager.click();
    onTap(plant);
    _expanded = true;
    gameRef.add(_ExpandedOverlay(
      gameRef: gameRef,
      plant: plant,
      onClose: () => _expanded = false,
    )..size = gameRef.size);
    event.continuePropagation = false;
  }
}

// -------------------------------------------------------
// Overlay expandido
// -------------------------------------------------------
class _ExpandedOverlay extends PositionComponent with TapCallbacks {
  final FlameGame gameRef;
  final VoidCallback onClose;
  final TreePlanta plant;

  _ExpandedOverlay({required this.gameRef, required this.onClose, required this.plant});

  @override
  Future<void> onLoad() async {
    priority = 10;
    size = gameRef.size;

    add(RectangleComponent(
      size: gameRef.size,
      paint: Paint()..color = const Color(0x33000000),
    ));

    const double collapsedH = 52.0;
    const double marginTop = 40.0;//15
    const double marginSide = 30.0;
    const double btnH = 44.0;
    const double btnGap = 10.0;

    final double availH =
        gameRef.size.y - collapsedH - marginTop - btnH - btnGap - 8.0;
    final double availW = gameRef.size.x - marginSide * 2;
    final double panelSize = availH < availW ? availH : availW;

    final double panelX = (gameRef.size.x - panelSize) / 2;
    final double panelY = marginTop;

    add(SpriteComponent()
      ..sprite = Sprite(gameRef.images.fromCache('Inventario/Panel_InvEspacio_01.png'))
      ..size = Vector2(panelSize, panelSize)
      ..position = Vector2(panelX, panelY));

    final lowerId = plant.id;
    final displayName = PlantCatalog.displayName(lowerId);

    add(TextComponent(
      text: displayName,
      anchor: Anchor.topCenter,
      position: Vector2(gameRef.size.x / 2, panelY + panelSize * 0.16),
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 18,
          fontFamily: 'Press Start 2P',
          color: Color(0xFF3E2A1F),
          fontWeight: FontWeight.bold,
        ),
      ),
    ));

    final double plantSize = panelSize * 0.32;
    add(SpriteComponent()
      ..sprite = (gameRef as InventoryScreen)._plantSprite(plant)
      ..size = Vector2(plantSize, plantSize)
      ..anchor = Anchor.center
      ..position = Vector2(gameRef.size.x / 2, panelY + panelSize * 0.50));

    final double iconH = panelSize * 0.15;
    final double iconY = panelY + panelSize - iconH - panelSize * 0.13;
    const double gap = 8.0;

    final fase = plant.estado.fase;
    final recursos = plant.recursosAplicados;
    final sol = recursos.sol;
    final agua = recursos.agua;
    final categoryIcon = (gameRef as InventoryScreen)._getCategoryIconPath(lowerId);
    final stageIcon = (gameRef as InventoryScreen)._getStageIconPath(fase);
    final trafficLightIcon = (gameRef as InventoryScreen)._getTrafficLightIconPath(sol, agua);

    final iconPaths = [
      categoryIcon,
      stageIcon,
      trafficLightIcon,
    ];

    final List<double> iconWidths = iconPaths.map((path) {
      final iconImg = gameRef.images.fromCache(path);
      final double ratio = iconImg.width / iconImg.height;
      return iconH * ratio;
    }).toList();

    final double totalIconW =
        iconWidths.fold(0.0, (sum, w) => sum + w) + gap * (iconPaths.length - 1);
    double ix = (gameRef.size.x - totalIconW) / 2;

    for (int i = 0; i < iconPaths.length; i++) {
      final iconImg = gameRef.images.fromCache(iconPaths[i]);
      final double ratio = iconImg.width / iconImg.height;
      final double iconW = iconH * ratio;
      add(SpriteComponent()
        ..sprite = Sprite(gameRef.images.fromCache(iconPaths[i]))
        ..size = Vector2(iconW, iconH)
        ..position = Vector2(ix, iconY));
      ix += iconW + gap;
    }

    final double btnY = panelY + panelSize + btnGap;
    final double btnW = panelSize * 0.42;

    // Botón Volver — click y cierra overlay
    add(ImageButton(
      label: 'Volver',
      position: Vector2(panelX, btnY),
      btnSize: Vector2(btnW, btnH),
      gameRef: gameRef,
      onTap: () {
        AudioManager.click();
        gameRef.remove(this);
        onClose();
      },
    ));

    // Botón Seleccionar — click, detiene música y navega
    add(ImageButton(
      label: 'Seleccionar',
      position: Vector2(panelX + panelSize - btnW, btnY),
      btnSize: Vector2(btnW, btnH),
      gameRef: gameRef,
      onTap: () {
        AudioManager.click();
        AudioManager.stopMusica();
        gameRef.remove(this);
        onClose();
        if (gameRef is InventoryScreen) {
          GoRouter.of((gameRef as InventoryScreen).context).go('/plant_game');
        }
      },
    ));
  }

  @override
  void onTapDown(TapDownEvent event) {
    event.continuePropagation = true;
  }
}



