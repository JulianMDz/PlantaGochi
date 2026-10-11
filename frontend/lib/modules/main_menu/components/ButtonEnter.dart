import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/flame.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';

import 'package:frontend/core/audio.dart';

class ButtonEnter extends SpriteButtonComponent {
  late TextComponent textComp;

  ButtonEnter({required void Function() onPressed})
      : super(
       size: Vector2.zero(),
       button: null, 
       buttonDown: null, 
       onPressed: onPressed);

  @override
  Future<void> onLoad() async {
    final normalImage = await Flame.images.load('Botones/Boton_General_01a.png');
    final pressedImage = await Flame.images.load('Botones/Boton_General_01b.png');

    button = Sprite(normalImage);
    buttonDown = Sprite(pressedImage);

    size = button.srcSize;
    scale = Vector2.all(0.5);

    textComp = TextComponent(
      text: 'Entrar',
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white, 
          fontSize: 18,
          fontFamily: 'Press Start 2P',
        ),
        
      ),
    )
      ..anchor = Anchor.center
      ..position = size / 2;

    add(textComp);
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    scale = Vector2.all(0.49);
  }

  @override
  void onTapUp(TapUpEvent event) {
    super.onTapUp(event);
    AudioManager.click();
    scale = Vector2.all(0.51);
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    super.onTapCancel(event);
    scale = Vector2.all(0.51);
  }
}
