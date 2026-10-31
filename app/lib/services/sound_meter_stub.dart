/// Non-web fallback: counts everything as sound until native metering lands.
class SoundMeter {
  Future<bool> start() async => true;

  double get level => 1.0;

  void stop() {}
}
