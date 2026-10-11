import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class textCompost extends TextBoxComponent with HasGameRef {
  late TextBoxComponent tiempoText;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 🔹 Texto de tiempo (arriba)
    tiempoText = TextBoxComponent(
      text: "3 SEC",
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color.fromARGB(255, 152, 85, 47),
          fontSize: 20,
          fontFamily: 'Press Start 2P',
        ),
      ),
      align: Anchor.center,
      anchor: Anchor.center,
      size: Vector2(200, 40),
      position: Vector2(0, -90), // Arriba
    );
    add(tiempoText);
  }

   // Métodos para actualizar la UI desde el Game Loop
  void updateTime(double timeLeft) {
    tiempoText.text = "${timeLeft.ceil()} SEC";
  }

}