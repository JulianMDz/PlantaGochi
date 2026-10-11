import 'package:flame_audio/flame_audio.dart';

/// Audio manager for the plant game.
///
/// Uses AudioPool per SFX so each sound reuses a fixed set of native
/// AudioPlayer instances instead of allocating a new one on every call.
/// Call [init] once at app startup before any sound is played.
class AudioManager {
  static bool _muted = false;
  static bool get isMuted => _muted;

  static bool _initialized = false;

  // One pool per sound effect — maxPlayers:1 prevents overlapping instances
  static AudioPool? _clickPool;
  static AudioPool? _regarPool;
  static AudioPool? _solPool;
  static AudioPool? _abonoPool;
  static AudioPool? _aguaPool;
  static AudioPool? _compostePool;
  static AudioPool? _solesPool;
  static AudioPool? _miniPool;

  // Track current BGM to avoid restarting the same track
  static String _currentBgm = '';

  static void toggleMute() {
    _muted = !_muted;
    try {
      FlameAudio.bgm.audioPlayer.setVolume(_muted ? 0 : 0.5);
    } catch (_) {}
  }

  /// Pre-load all audio assets and create player pools.
  /// Must be called once before any other method.
  static Future<void> init() async {
    if (_initialized) return;

    await FlameAudio.audioCache.loadAll([
      'abono.mp3',
      'agua_recoleccion.mp3',
      'click_general.mp3',
      'composta_recoleccion.mp3',
      'inventario.mp3',
      'principal.mp3',
      'regar.mp3',
      'sol.mp3',
      'soles_recoleccion.mp3',
      'timer_minigames.mp3',
    ]);

    _clickPool    = await FlameAudio.createPool('click_general.mp3',       maxPlayers: 1);
    _regarPool    = await FlameAudio.createPool('regar.mp3',                maxPlayers: 1);
    _solPool      = await FlameAudio.createPool('sol.mp3',                  maxPlayers: 1);
    _abonoPool    = await FlameAudio.createPool('abono.mp3',                maxPlayers: 1);
    _aguaPool     = await FlameAudio.createPool('agua_recoleccion.mp3',     maxPlayers: 1);
    _compostePool = await FlameAudio.createPool('composta_recoleccion.mp3', maxPlayers: 1);
    _solesPool    = await FlameAudio.createPool('soles_recoleccion.mp3',    maxPlayers: 1);
    _miniPool     = await FlameAudio.createPool('timer_minigames.mp3',      maxPlayers: 1);

    _initialized = true;
  }

  // Fire-and-forget pool play — swallows errors so audio never crashes the game
  static void _sfx(AudioPool? pool) {
    if (_muted || pool == null) return;
    pool.start(volume: 0.8).ignore();
  }

  // ── Effects ──────────────────────────────────────────────────────────────
  static void click()              => _sfx(_clickPool);
  static void regar()              => _sfx(_regarPool);
  static void sol()                => _sfx(_solPool);
  static void abono()              => _sfx(_abonoPool);
  static void recolectarAgua()     => _sfx(_aguaPool);
  static void recolectarComposta() => _sfx(_compostePool);
  static void recolectarSoles()    => _sfx(_solesPool);
  static void miniGames()          => _sfx(_miniPool);

  // ── BGM ──────────────────────────────────────────────────────────────────
  static Future<void> musicaPrincipal() async {
    if (_muted) return;
    if (_currentBgm == 'principal.mp3') return;
    _currentBgm = 'principal.mp3';
    await FlameAudio.bgm.play('principal.mp3', volume: 0.5);
  }

  static Future<void> musicaInventario() async {
    if (_muted) return;
    if (_currentBgm == 'inventario.mp3') return;
    _currentBgm = 'inventario.mp3';
    await FlameAudio.bgm.play('inventario.mp3', volume: 0.5);
  }

  static void stopMusica() {
    _currentBgm = '';
    FlameAudio.bgm.stop();
  }
}
