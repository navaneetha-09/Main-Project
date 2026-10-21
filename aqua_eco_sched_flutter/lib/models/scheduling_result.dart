/// Models representing scheduling evaluations, metrics, and decisions.
library;

class PodScoreRecord {
  final String podId;
  final String podName;
  final String location;
  int rank;
  final double compositeScore;

  // Raw metrics
  final double energyKwh;
  final double carbonKgCo2e;
  final double thermalFootprint;
  final double environmentalRisk;
  final double performancePenalty;

  // Hydrodynamic metrics
  final double deltaTempC;
  final double localWaterTempC;
  final double internalPodTempC;
  final double convectiveHWm2k;

  // Normalized metrics
  final double normEnergy;
  final double normCarbon;
  final double normThermal;
  final double normRisk;
  final double normPerf;

  // Weighted contributions
  final double energyContrib;
  final double carbonContrib;
  final double thermalContrib;
  final double riskContrib;
  final double perfContrib;

  final String decisionNotes;

  PodScoreRecord({
    required this.podId,
    required this.podName,
    required this.location,
    required this.rank,
    required this.compositeScore,
    required this.energyKwh,
    required this.carbonKgCo2e,
    required this.thermalFootprint,
    required this.environmentalRisk,
    required this.performancePenalty,
    required this.deltaTempC,
    required this.localWaterTempC,
    required this.internalPodTempC,
    required this.convectiveHWm2k,
    required this.normEnergy,
    required this.normCarbon,
    required this.normThermal,
    required this.normRisk,
    required this.normPerf,
    required this.energyContrib,
    required this.carbonContrib,
    required this.thermalContrib,
    required this.riskContrib,
    required this.perfContrib,
    required this.decisionNotes,
  });
}

class SchedulingDecisionResult {
  final PodScoreRecord? selectedPod;
  final List<PodScoreRecord> rankedPods;
  final Map<String, List<String>> ineligiblePods;
  final Map<String, double> weightsApplied;
  final String explanationSummary;
  final String status; // "SUCCESS" or "INFEASIBLE_NO_PODS"

  const SchedulingDecisionResult({
    required this.selectedPod,
    required this.rankedPods,
    required this.ineligiblePods,
    required this.weightsApplied,
    required this.explanationSummary,
    required this.status,
  });

  bool get isSuccess => status == "SUCCESS" && selectedPod != null;
}

class BaselinePolicyMetric {
  final String policyName;
  final String? selectedPodId;
  final String selectedPodName;
  final bool scheduledSuccessfully;
  final double energyKwh;
  final double carbonKgCo2e;
  final double waterTempDeltaC;
  final double environmentalRiskScore;
  final int constraintViolations;
  final List<String> violationDetails;

  const BaselinePolicyMetric({
    required this.policyName,
    required this.selectedPodId,
    required this.selectedPodName,
    required this.scheduledSuccessfully,
    required this.energyKwh,
    required this.carbonKgCo2e,
    required this.waterTempDeltaC,
    required this.environmentalRiskScore,
    required this.constraintViolations,
    required this.violationDetails,
  });
}
