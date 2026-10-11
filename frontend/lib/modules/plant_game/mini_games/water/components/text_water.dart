import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class TextWater extends PositionComponent with HasGameRef {
  late TextBoxComponent tiempoText;
  late TextBoxComponent tituloText;

  @override
  Future<void> onLoad() async {
    // 🔹 Texto de tiempo (arriba)
    tiempoText = TextBoxComponent(
      text: "5 SEC",
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color.fromARGB(255, 29, 137, 159),
          fontSize: 20,
          fontFamily: 'Press Start 2P',
        ),
      ),
      align: Anchor.center,
      anchor: Anchor.center,
      size: Vector2(200, 40),
      position: Vector2(0, -90), // Arriba
    );

    // 🔹 Texto grande de clicks (abajo)
    tituloText = TextBoxComponent(
      text: "0 | 50",
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 26, 
          fontFamily: 'Press Start 2P',
        ),
      ),
      align: Anchor.center,
      anchor: Anchor.center,
      size: Vector2(200, 60),
      position: Vector2(0, 90), // Abajo
    );

    add(tiempoText);
    add(tituloText);
  }

  // Métodos para actualizar la UI desde el Game Loop
  void updateTime(double timeLeft) {
    tiempoText.text = "${timeLeft.ceil()} SEC";
  }

  void updateClicks(int clicks) {
    tituloText.text = "$clicks | 50";
  }
}