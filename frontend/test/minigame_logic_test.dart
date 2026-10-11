import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/modules/plant_game/mini_games/compost/compost_logic.dart';
import 'package:frontend/modules/plant_game/mini_games/sun/sun_logic.dart';
import 'package:frontend/modules/plant_game/mini_games/water/water_logic.dart';

/// Random que siempre devuelve el mismo valor.
class _FixedRandom implements Random {
  final double value;
  _FixedRandom(this.value);
  @override
  double nextDouble() => value;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}

void main() {
  group('SunLogic', () {
    test('con suerte máxima llega a Solar y termina antes de 4 clicks', () {
      final logic = SunLogic(random: _FixedRandom(0));
      for (var i = 0; i < 4 && !logic.isGameOver; i++) {
        logic.onTap();
      }
      expect(logic.currentTier, SunTier.solar);
      expect(logic.clickCount, 4);
      expect(logic.sunReward, 5);
    });

    test('sin suerte se queda en Bronce tras 4 clicks', () {
      final logic = SunLogic(random: _FixedRandom(0.99));
      for (var i = 0; i < 4; i++) {
        logic.onTap();
      }
      expect(logic.isGameOver, isTrue);
      expect(logic.sunReward, 1);
    });
  });

  group('WaterLogic', () {
    int rewardFor(int clicks) {
      final logic = WaterLogic()..start();
      for (var i = 0; i < clicks; i++) {
        logic.onTap();
      }
      logic.update(5);
      expect(logic.shouldEndGame, isTrue);
      return logic.waterReward;
    }

    test('recompensa según clicks en 5 s', () {
      expect(rewardFor(10), 0);
      expect(rewardFor(25), 2);
      expect(rewardFor(40), 4);
      expect(rewardFor(50), 6);
    });
  });

  group('CompostLogic', () {
    test('orgánicos suman, inorgánicos restan, rango 0–4', () {
      final logic = CompostLogic()..start();
      logic.onCellTap(0, 0, false); // no baja de 0
      for (var i = 0; i < 6; i++) {
        logic.onCellTap(0, i, true); // tope 4
      }
      logic.onCellTap(1, 0, false);
      expect(logic.compostReward, 3);
      expect(logic.mistakes, 2);
    });
  });
}
