import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/modules/plant_game/plant_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PanelLayout — panel lateral izquierdo con 3 filas:
//   [icono_sol]     [====barra====]
//   [icono_agua]    [====barra====]
//   [icono_abono]   [====barra====]
//
// Refleja los recursos_aplicados de la planta activa.
// Usa posicionamiento manual (sin RowComponent/ColumnComponent anidados)
// para evitar problemas de solapamiento con el sistema de layout de Flame.
// ─────────────────────────────────────────────────────────────────────────────
class PanelLayout extends PositionComponent {
  final BuildContext context;

  // ── Constantes de layout ───────────────────────────────────────────────────
  static const double _iconSize    = 26.0;
  static const double _barW        = 60.0;
  static const double _barH        = 9.0;
  static const double _gap         = 8.0;   // espacio entre icono y barra
  static const double _rowSpacing  = 38.0;  // separación vertical entre filas

  // ── Componentes de barra ───────────────────────────────────────────────────
  late BarraCarga _barraSol;
  late BarraCarga _barraAgua;
  late BarraCarga _barraComposta;

  late final PlantController _controller;

  PanelLayout({required this.context});

  @override
  Future<void> onLoad() async {
    _controller = Provider.of<PlantController>(context, listen: false);
    final double barX = _iconSize + _gap;
    final double barCenterY = (_iconSize - _barH) / 2; // centrar barra en fila

    // ── Fila Sol (y = 0) ─────────────────────────────────────────────────────
    _barraSol = BarraCarga(fillColor: const Color.fromARGB(255, 228, 110, 0))
      ..size     = Vector2(_barW, _barH)
      ..position = Vector2(barX, barCenterY);

    final solSprite = SpriteComponent(
      sprite:   await Sprite.load('Iconos/Icono_Sol_01.png'),
      size:     Vector2.all(_iconSize),
      position: Vector2(0, 0),
    );

    // ── Fila Agua (y = rowSpacing) ────────────────────────────────────────────
    _barraAgua = BarraCarga(fillColor: const Color.fromARGB(255, 28, 87, 120))
      ..size     = Vector2(_barW, _barH)
      ..position = Vector2(barX, _rowSpacing + barCenterY);

    final aguaSprite = SpriteComponent(
      sprite:   await Sprite.load('Iconos/Icono_Agua_01.png'),
      size:     Vector2.all(_iconSize),
      position: Vector2(0, _rowSpacing),
    );

    // ── Fila Fertilizante (y = rowSpacing*2) ─────────────────────────────────
    _barraComposta = BarraCarga(fillColor: const Color.fromARGB(255, 97, 47, 14))
      ..size     = Vector2(_barW, _barH)
      ..position = Vector2(barX, _rowSpacing * 2 + barCenterY);

    final abonoSprite = SpriteComponent(
      sprite:   await Sprite.load('Iconos/Icono_Abono_01.png'),
      size:     Vector2.all(_iconSize),
      position: Vector2(0, _rowSpacing * 2),
    );

    await addAll([
      solSprite, _barraSol,
      aguaSprite, _barraAgua,
      abonoSprite, _barraComposta,
    ]);

    // Tamaño total del panel
    size = Vector2(barX + _barW, _rowSpacing * 2 + _iconSize);

    // Carga inicial y suscripción
    _syncFromController();
    _controller.addListener(_syncFromController);
  }

  @override
  void onRemove() {
    _controller.removeListener(_syncFromController);
    super.onRemove();
  }

  /// Barras = recursos aplicados / capacidad de la fase actual.
  void _syncFromController() {
    final applied = _controller.activePlantResources;
    final max = _controller.getCurrentPhaseRequirements();

    double ratio(int value, String key) =>
        (value / (max?[key] ?? 10)).clamp(0.0, 1.0);

    _barraSol.progress = ratio(applied.sol, 'sol');
    _barraAgua.progress = ratio(applied.agua, 'agua');
    _barraComposta.progress = ratio(applied.fertilizante, 'fertilizante');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BarraCarga — barra de progreso horizontal dibujada con Canvas.
// ─────────────────────────────────────────────────────────────────────────────
class BarraCarga extends PositionComponent {
  double progress = 0.0;
  Color fillColor;

  BarraCarga({this.fillColor = Colors.green});

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Fondo
    canvas.drawRRect(
      RRect.fromRectAndRadius(size.toRect(), const Radius.circular(3)),
      Paint()..color = const Color(0x99000000),
    );
    // Relleno
    if (progress > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.x * progress, size.y),
          const Radius.circular(3),
        ),
        Paint()..color = fillColor,
      );
    }
    // Borde
    canvas.drawRRect(
      RRect.fromRectAndRadius(size.toRect(), const Radius.circular(3)),
      Paint()
        ..color = Colors.white.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }
}