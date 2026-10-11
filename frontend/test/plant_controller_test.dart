import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/models.dart';
import 'package:frontend/modules/plant_game/plant_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory docs;
  final sessions = <PlantController>[];

  setUp(() {
    // El export a la carpeta compartida escribe en Documents: redirigirlo a
    // un directorio temporal.
    docs = Directory.systemTemp.createTempSync('imaginatio_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => docs.path,
    );

    final user = UserModel(
      userId: 'ana',
      username: 'Ana',
      unlockedPlants: [],
      plants: [],
      resources: UserResources(),
    );
    SharedPreferences.setMockInitialValues({
      'current_session_id': 'ana',
      'user_ana': jsonEncode(user.toJson()),
    });
  });

  tearDown(() async {
    // Esperar los guardados en segundo plano antes de limpiar.
    await Future.wait(sessions.map((c) => c.saveTree()));
    sessions.clear();
    docs.deleteSync(recursive: true);
  });

  Future<PlantController> newSession() async {
    final c = PlantController();
    sessions.add(c);
    await c.loadCurrentTree();
    return c;
  }

  test('una sesión nueva arranca con un Pasto en semilla (sol 1, agua 1)', () async {
    final c = await newSession();

    expect(c.currentTree!.usuario.nombre, 'Ana');
    expect(c.activePlant!.id, 'pasto');
    expect(c.activePlant!.estado.fase, 'semilla');
    expect(c.activePlantResources.sol, 1);
    expect(c.activePlantResources.agua, 1);
  });

  test('spend pasa 1 unidad del inventario a la planta', () async {
    final c = await newSession();
    c.addSun(2);

    expect(c.spend(PlantResource.sol), SpendResult.applied);
    expect(c.stockOf(PlantResource.sol), 1);
    expect(c.activePlantResources.sol, 2);
  });

  test('spend sin stock no modifica nada', () async {
    final c = await newSession();

    expect(c.spend(PlantResource.agua), SpendResult.noStock);
    expect(c.activePlantResources.agua, 1);
  });

  test('spend se bloquea al llegar a la capacidad de la fase', () async {
    final c = await newSession();
    c.addSun(10);

    // Pasto en semilla admite 3 de sol.
    expect(c.spend(PlantResource.sol), SpendResult.applied); // 2
    expect(c.spend(PlantResource.sol), SpendResult.applied); // 3
    expect(c.spend(PlantResource.sol), SpendResult.plantFull);
    expect(c.stockOf(PlantResource.sol), 8);
  });

  test('al cumplir los requisitos evoluciona y vuelve a los mínimos', () async {
    final c = await newSession();
    c
      ..addSun(2)
      ..addWater(2)
      ..addCompost(16); // = 4 fertilizantes

    for (var i = 0; i < 2; i++) {
      c.spend(PlantResource.sol);
      c.spend(PlantResource.agua);
    }
    for (var i = 0; i < 3; i++) {
      c.spend(PlantResource.fertilizante);
    }
    expect(c.activePlant!.estado.fase, 'semilla');

    c.spend(PlantResource.fertilizante); // 4/4 → evoluciona
    expect(c.activePlant!.estado.fase, 'arbusto');
    expect(c.showEvolutionAnimation, isTrue);
    expect(c.activePlantResources.sol, 1);
    expect(c.activePlantResources.agua, 1);
    expect(c.activePlantResources.fertilizante, 0);
  });

  test('cada 4 de composta se convierten en 1 fertilizante', () async {
    final c = await newSession();

    c.addCompost(6);
    expect(c.recursos.fertilizante.cantidad, 1);
    expect(c.recursos.composta.cantidad, 2);

    c.addCompost(3);
    expect(c.recursos.fertilizante.cantidad, 2);
    expect(c.recursos.composta.cantidad, 1);
  });

  test('el decay mata la planta y aparece un Pasto nuevo', () async {
    final c = await newSession();
    final original = c.activePlant!;

    await c.debugAdvanceTime(10); // -1 sol, -1 agua → 0

    expect(original.estado.fase, 'muerto');
    expect(c.plants, hasLength(2));
    expect(c.activePlant, isNot(same(original)));
    expect(c.activePlant!.estado.fase, 'semilla');
  });

  test('los cooldowns se activan al jugar', () async {
    final c = await newSession();
    expect(c.canPlay(Minigame.sun), isTrue);

    c.markPlayed(Minigame.sun);

    expect(c.canPlay(Minigame.sun), isFalse);
    expect(c.canPlay(Minigame.water), isTrue);
    final left = c.remainingCooldown(Minigame.sun)!;
    expect(left, greaterThan(const Duration(minutes: 9)));
    expect(left, lessThanOrEqualTo(Minigame.sun.cooldown));
  });

  test('el progreso se guarda y se recupera en la siguiente sesión', () async {
    final c = await newSession();
    c.addSun(5);
    c.spend(PlantResource.sol);
    await c.saveTree();

    final again = await newSession();
    expect(again.stockOf(PlantResource.sol), 4);
    expect(again.activePlantResources.sol, 2);
  });
}
