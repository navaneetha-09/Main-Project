/// Model representing subsea ocean environmental conditions & grid emissions telemetry.
class OceanCondition {
  final String podId;
  final DateTime timestamp;
  final double waterTemperatureC;
  final double currentSpeedMps;
  final double currentDirectionDeg;
  final double salinityPsu;
  final double depthM;
  final String ecologicalZone; // "LOW_IMPACT", "MODERATE", "SENSITIVE_BENTHIC", "PROTECTED_CORAL_REEF"
  final double gridCarbonIntensityKgPerKwh;
  final double ambientTurbidityNtu;

  const OceanCondition({
    required this.podId,
    required this.timestamp,
    required this.waterTemperatureC,
    required this.currentSpeedMps,
    required this.currentDirectionDeg,
    required this.salinityPsu,
    required this.depthM,
    required this.ecologicalZone,
    required this.gridCarbonIntensityKgPerKwh,
    required this.ambientTurbidityNtu,
  });

  bool get isProtectedSanctuary =>
      ecologicalZone.toUpperCase() == "PROTECTED_CORAL_REEF" ||
      ecologicalZone.toUpperCase() == "SANCTUARY" ||
      ecologicalZone.toUpperCase() == "MARINE_PROTECTED_AREA";
}
