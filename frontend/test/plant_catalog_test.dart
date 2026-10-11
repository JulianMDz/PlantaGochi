import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/plant_catalog.dart';

void main() {
  group('PlantCatalog.typeOf', () {
    test('clasifica ids de Unity con variantes, espacios y tildes', () {
      expect(PlantCatalog.typeOf('Drago5'), 'solar');
      expect(PlantCatalog.typeOf('Pino romerón2'), 'montana');
      expect(PlantCatalog.typeOf('PinoRomeron'), 'montana');
      expect(PlantCatalog.typeOf('AlcaparroEnano'), 'xerofito');
      expect(PlantCatalog.typeOf('Alcaparro enano3'), 'xerofito');
      expect(PlantCatalog.typeOf('Cedrillo2'), 'hidro');
      expect(PlantCatalog.typeOf('Cedro'), 'templado');
      expect(PlantCatalog.typeOf('Espino'), 'solar');
      expect(PlantCatalog.typeOf('Sietecueros13'), 'templado');
    });

    test('ids desconocidos son pasto', () {
      expect(PlantCatalog.typeOf('pasto'), 'pasto');
      expect(PlantCatalog.typeOf('Helecho'), 'pasto');
    });
  });

  test('displayName', () {
    expect(PlantCatalog.displayName('Pino romerón1'), 'PINO ROMERÓN');
    expect(PlantCatalog.displayName('Helecho'), 'HELECHO');
  });

  test('phaseNumber', () {
    expect(phaseNumber('semilla'), 1);
    expect(phaseNumber('ent'), 4);
    expect(phaseNumber('muerto'), 0);
  });

  group('PlantCatalog.spritePath', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('usa la carpeta exacta de la variante', () async {
      expect(await PlantCatalog.spritePath('Drago5', 1),
          'Planta/Drago5/fase1_ss.png');
    });

    test('encuentra sheets ENT con nombre de autor', () async {
      expect(await PlantCatalog.spritePath('Sietecueros', 4),
          'Planta/Sietecueros/Sietecueros_Danna_Lucia_Plazas_Lara_fase4_ss.png');
    });

    test('variante sin carpeta propia → carpeta base de la especie', () async {
      expect(await PlantCatalog.spritePath('Nogal9', 2),
          'Planta/Nogal/fase2_ss.png');
    });

    test('sin sheet (planta muerta o especie sin arte) → Pasto', () async {
      expect(await PlantCatalog.spritePath('Drago', 0),
          'Planta/Pasto/fase2_ss.png');
      expect(await PlantCatalog.spritePath('Dividivi', 3),
          'Planta/Pasto/fase3_ss.png');
    });

    test('todas las carpetas de plantas tienen las 4 fases resolubles', () async {
      for (final id in ['Pasto', 'Aliso', 'Cajeto', 'Cedro', 'Roble1']) {
        for (var phase = 1; phase <= 4; phase++) {
          expect(await PlantCatalog.spritePath(id, phase),
              startsWith('Planta/$id/'),
              reason: '$id fase $phase');
        }
      }
    });
  });
}
