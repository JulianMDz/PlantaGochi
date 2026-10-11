import 'package:flame/components.dart';

class PanelName extends SpriteComponent  {
  late TextComponent textComp;
  @override
  Future<void> onLoad() async {
    // Cargar la imagen
    sprite = await Sprite.load('Paneles/Panel_CampoTexto_01.png');

    size = sprite!.srcSize;  
  }
}