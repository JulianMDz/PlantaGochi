import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class Panel_resource_info extends SpriteComponent {
  late TextComponent textComp;

  String info;

  Panel_resource_info(this.info);

  @override
  Future<void> onLoad() async {
    sprite = await Sprite.load('Paneles/Panel_AvisoPlanta_01.png');

    size = sprite!.srcSize / 3.5;

    textComp = TextComponent(
      text: info,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontFamily: 'Press Start 2P',
        ),
      ),
    )
      ..anchor = Anchor.center
      ..position = size / 2;

    add(textComp);
  }

  void setMessage(String msg) {
    if (isLoaded) {
      textComp.text = msg;
    }
  }
}
