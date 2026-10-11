import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/modules/plant_game/plant_controller.dart';

class textName extends TextComponent with HasGameRef {
  final BuildContext context;

  textName({required this.context});

  @override
  Future<void> onLoad() async {
    text = _getUserName();

    textRenderer = TextPaint(
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontFamily: 'Press Start 2P',
        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
      ),
    );

    // Suscribirse a cambios en caso de que el árbol se cargue después
    final controller = Provider.of<PlantController>(context, listen: false);
    controller.addListener(_onControllerChange);
  }

  @override
  void onRemove() {
    try {
      Provider.of<PlantController>(context, listen: false)
          .removeListener(_onControllerChange);
    } catch (_) {}
    super.onRemove();
  }

  String _getUserName() {
    try {
      final controller = Provider.of<PlantController>(context, listen: false);
      final nombre = controller.currentTree?.usuario.nombre ?? 'Jugador';
      return "Bienvenid@, $nombre";
    } catch (_) {
      return "Bienvenid@, Jugador";
    }
  }

  void _onControllerChange() {
    text = _getUserName();
  }
}