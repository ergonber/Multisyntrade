/// Flags globales de la app (estado transitorio de arranque).
class GlobalFlags {
  GlobalFlags._();

  /// true cuando el arranque viene de un link de recuperación de contraseña
  /// (el splash NO debe navegar; se muestra NewPasswordScreen).
  static bool recovering = false;
}
