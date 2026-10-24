import 'dart:math';
import '../models/workload.dart';
import '../models/pod_resource.dart';
import '../models/ocean_condition.dart';
import '../models/scheduling_result.dart';

class SchedulingWeights {
  final double energy;
  final double carbon;
  final double thermalFootprint;
  final double environmentalRisk;
  final double performancePenalty;

  const SchedulingWeights({
    this.energy = 0.15,
    this.carbon = 0.15,
    this.thermalFootprint = 0.30,
    this.environmentalRisk = 0.30,
    this.performancePenalty = 0.10,
  });

  Map<String, double> toNormalizedMap() {
    final sum = energy + carbon + thermalFootprint + environmentalRisk + performancePenalty;
    if (sum <= 0) return {"energy": 0.15, "carbon": 0.15, "thermal_footprint": 0.30, "environmental_risk": 0.30, "performance_penalty": 0.10};
    return {
      "energy": energy / sum,
      "carbon": carbon / sum,
      "thermal_footprint": thermalFootprint / sum,
      "environmental_risk": environmentalRisk / sum,
      "performance_penalty": performancePenalty / sum,
    };
  }
}

class RiskBudgetConstraints {
  final double maxWaterTempDeltaC;
  final double maxPodTempC;
  final double maxEnvironmentalRiskScore;
  final double? maxCarbonBudgetKg;
  final bool disallowProtectedSanctuaries;

  const RiskBudgetConstraints({
    this.maxWaterTempDeltaC = 2.5,
    this.maxPodTempC = 45.0,
    this.maxEnvironmentalRiskScore = 0.65,
    this.maxCarbonBudgetKg,
    this.disallowProtectedSanctuaries = true,
  });
}

class SchedulerEngine {
  /// Evaluates workload feasibility and produces multi-objective rankings with full explainability.
  static SchedulingDecisionResult schedule({
    required Workload workload,
    required List<PodResource> pods,
    required List<OceanCondition> oceanConditions,
    required SchedulingWeights weights,
    required RiskBudgetConstraints constraints,
  }) {
    final oceanMap = {for (var o in oceanConditions) o.podId: o};
    final normalizedWeights = weights.toNormalizedMap();

    final Map<String, List<String>> ineligiblePods = {};
    final List<PodResource> hardwareEligiblePods = [];

    // Step 4: Hardware Resource Eligibility Filter
    for (final pod in pods) {
      final List<String> rejections = [];

      if (!pod.isOperational) {
        rejections.add("Pod status is '${pod.status}' (requires ACTIVE/ONLINE)");
      }
      if (pod.availableCpu < workload.cpuCores) {
        rejections.add("Insufficient CPU: requires ${workload.cpuCores.toInt()} cores, only ${pod.availableCpu.toInt()} available");
      }
      if (pod.availableGpu < workload.gpuUnits) {
        rejections.add("Insufficient GPU: requires ${workload.gpuUnits.toInt()} units, only ${pod.availableGpu.toInt()} available");
      }
      if (pod.availableRamGb < workload.ramGb) {
        rejections.add("Insufficient RAM: requires ${workload.ramGb.toInt()} GB, only ${pod.availableRamGb.toInt()} GB available");
      }
      if (pod.availableStorageGb < workload.storageGb) {
        rejections.add("Insufficient Storage: requires ${workload.storageGb.toInt()} GB, only ${pod.availableStorageGb.toInt()} GB available");
      }

      if (rejections.isNotEmpty) {
        ineligiblePods[pod.id] = rejections;
      } else {
        hardwareEligiblePods.add(pod);
      }
    }

    // Step 5 & 6: Impact & Hydrodynamic Heat Transfer Computations
    final Map<String, Map<String, double>> computedMetrics = {};
    final List<PodResource> feasiblePods = [];

    for (final pod in hardwareEligiblePods) {
      final ocean = oceanMap[pod.id];
      final ambientTemp = ocean?.waterTemperatureC ?? 10.0;
      final currentSpeed = max(ocean?.currentSpeedMps ?? 0.5, 0.05);
      final depth = ocean?.depthM ?? 50.0;
      final carbonIntensity = ocean?.gridCarbonIntensityKgPerKwh ?? 0.20;
      final zone = ocean?.ecologicalZone ?? "MODERATE";

      // 1. Power & Energy (kWh)
      final dynamicSpan = max(pod.maxPowerKw - pod.basePowerKw, 5.0);
      final cpuFrac = min(workload.cpuCores / max(pod.totalCpu, 1.0), 1.0);
      final gpuFrac = min(workload.gpuUnits / max(pod.totalGpu, 1.0), 1.0);
      final ramFrac = min(workload.ramGb / max(pod.totalRamGb, 1.0), 1.0);
      final dynamicUtil = (0.50 * cpuFrac) + (0.40 * gpuFrac) + (0.10 * ramFrac);

      final workloadDynamicPowerKw = dynamicSpan * dynamicUtil;
      final workloadFacilityPowerKw = workloadDynamicPowerKw * pod.pue;
      final totalFacilityPowerKw = (pod.basePowerKw + workloadDynamicPowerKw) * pod.pue;

      final workloadEnergyKwh = workloadFacilityPowerKw * workload.durationHours;
      final workloadCarbonKg = workloadEnergyKwh * carbonIntensity;

      // 2. Hydrodynamic Convective Seawater Heat Transfer
      // h = h_base + h_vel * (v)^0.8
      final convectiveH = 350.0 + 850.0 * pow(currentSpeed, 0.8);
      final qWatts = totalFacilityPowerKw * 1000.0;
      final deltaTempC = qWatts / (convectiveH * pod.surfaceAreaM2);
      final localWaterTempC = ambientTemp + deltaTempC;
      final internalPodTempC = localWaterTempC + 16.0;

      // 3. Thermal Plume & Ecological Risk Score
      final dispersionCapacity = max(currentSpeed * sqrt(depth), 0.5);
      final thermalFootprintRaw = (deltaTempC * (totalFacilityPowerKw / 50.0)) / dispersionCapacity;
      final thermalFootprintScore = (thermalFootprintRaw / 3.5).clamp(0.02, 1.0);

      final zoneWeight = _getZoneSensitivity(zone);
      final ambientVulnerability = ((ambientTemp - 5.0) / 25.0).clamp(0.1, 1.0);
      final depthPenalty = depth >= 100.0 ? 1.0 : (1.0 + (100.0 - depth) / 150.0);

      final rawRisk = (
        0.45 * thermalFootprintScore +
        0.35 * zoneWeight * (1.0 + ambientVulnerability) +
        0.20 * (deltaTempC / 3.0)
      ) * (depthPenalty / 1.2);
      final environmentalRiskScore = rawRisk.clamp(0.01, 1.0);

      // Performance penalty proxy & workload-aware right-sizing
      final isHighPriority = workload.priority.toUpperCase() == "HIGH" || workload.priority.toUpperCase() == "CRITICAL";
      final isLowPriority = workload.priority.toUpperCase() == "LOW";
      final latencyMs = pod.networkLatencyMs;

      // Latency factor: Mission-critical & real-time workloads heavily prioritize low latency
      final double latencyFactor = isHighPriority
          ? (latencyMs / 10.0)
          : (isLowPriority ? (latencyMs / 30.0).clamp(0.2, 1.0) : (latencyMs / 15.0));

      // Resource Right-Sizing: Prevent small batch jobs from hogging 128-core, 16-GPU exascale pods
      final cpuDemand = workload.cpuCores / max(pod.totalCpu, 1.0);
      final gpuWaste = (workload.gpuUnits == 0 && pod.totalGpu >= 8.0) ? 1.4 : 1.0;
      final rightSizing = (1.0 - cpuDemand).clamp(0.0, 1.0) * gpuWaste;
      final cpuUtilAfter = (pod.usedCpu + workload.cpuCores) / max(pod.totalCpu, 1.0);

      // Oceanographic & domain affinity matching
      final typeDesc = "${workload.type} ${workload.description}".toLowerCase();
      final locDesc = "${pod.location} ${pod.name}".toLowerCase();
      double affinity = 1.0;

      if ((typeDesc.contains("genom") || typeDesc.contains("vent") || typeDesc.contains("piezophil") || typeDesc.contains("proteom")) &&
          (locDesc.contains("azores") || locDesc.contains("mid-atlantic") || locDesc.contains("trench") || locDesc.contains("ridge"))) {
        affinity = 0.50; // hydrothermal vent biology affinity
      } else if ((typeDesc.contains("acoustic") || typeDesc.contains("whale") || typeDesc.contains("vision") || typeDesc.contains("sonar")) &&
                 (locDesc.contains("monterey") || locDesc.contains("orkney") || locDesc.contains("celtic") || locDesc.contains("pacific"))) {
        affinity = 0.50; // pelagic tracking & coastal vision affinity
      } else if (typeDesc.contains("coral") && (locDesc.contains("hawaii") || locDesc.contains("kona") || locDesc.contains("canary") || locDesc.contains("mediterr"))) {
        affinity = 0.45; // coral thermal modeling affinity
      } else if ((typeDesc.contains("arctic") || typeDesc.contains("ice") || typeDesc.contains("circumpolar") || typeDesc.contains("polar")) &&
                 (locDesc.contains("barents") || locDesc.contains("svalbard") || locDesc.contains("norway"))) {
        affinity = 0.50; // polar research affinity
      } else if ((typeDesc.contains("seismic") || typeDesc.contains("fault") || typeDesc.contains("tsunami") || typeDesc.contains("bathymetry")) &&
                 (locDesc.contains("north sea") || locDesc.contains("japan") || locDesc.contains("sagami") || locDesc.contains("dogger") || locDesc.contains("celtic"))) {
        affinity = 0.50; // seismic & bathymetry affinity
      } else if (isLowPriority && (typeDesc.contains("archival") || typeDesc.contains("log") || typeDesc.contains("deduplicat"))) {
        if (pod.totalCpu <= 64.0 && pod.totalGpu <= 4.0) {
          affinity = 0.45; // lightweight batch job right-sizing
        }
      }

      final perfProxy = ((latencyFactor * 1.5) + (rightSizing * 1.0) + (cpuUtilAfter * 0.8)) * affinity;

      // Step 7: Risk-Budget Constraint Enforcement
      final List<String> budgetViolations = [];
      if (deltaTempC > constraints.maxWaterTempDeltaC) {
        budgetViolations.add("Water temperature rise (+${deltaTempC.toStringAsFixed(2)}°C) exceeds limit (${constraints.maxWaterTempDeltaC.toStringAsFixed(2)}°C)");
      }
      if (internalPodTempC > constraints.maxPodTempC) {
        budgetViolations.add("Internal pod temperature (${internalPodTempC.toStringAsFixed(1)}°C) exceeds limit (${constraints.maxPodTempC.toStringAsFixed(1)}°C)");
      }
      if (environmentalRiskScore > constraints.maxEnvironmentalRiskScore) {
        budgetViolations.add("Environmental risk score (${environmentalRiskScore.toStringAsFixed(3)}) exceeds budget (${constraints.maxEnvironmentalRiskScore.toStringAsFixed(2)})");
      }
      if (constraints.maxCarbonBudgetKg != null && workloadCarbonKg > constraints.maxCarbonBudgetKg!) {
        budgetViolations.add("Carbon emissions (${workloadCarbonKg.toStringAsFixed(2)} kg) exceed carbon budget (${constraints.maxCarbonBudgetKg!.toStringAsFixed(2)} kg)");
      }
      if (constraints.disallowProtectedSanctuaries && (ocean?.isProtectedSanctuary ?? false)) {
        budgetViolations.add("Prohibited execution in marine protected sanctuary (${ocean?.ecologicalZone})");
      }

      if (budgetViolations.isNotEmpty) {
        final existing = ineligiblePods[pod.id] ?? [];
        existing.addAll(budgetViolations);
        ineligiblePods[pod.id] = existing;
      } else {
        feasiblePods.add(pod);
        computedMetrics[pod.id] = {
          "energy": workloadEnergyKwh,
          "carbon": workloadCarbonKg,
          "thermal": thermalFootprintScore,
          "risk": environmentalRiskScore,
          "perf": perfProxy,
          "deltaTemp": deltaTempC,
          "localWaterTemp": localWaterTempC,
          "internalPodTemp": internalPodTempC,
          "convectiveH": convectiveH,
        };
      }
    }

    // Step 8 & 9: Normalization & Multi-Objective Weighted Scoring
    if (feasiblePods.isEmpty) {
      return SchedulingDecisionResult(
        selectedPod: null,
        rankedPods: [],
        ineligiblePods: ineligiblePods,
        weightsApplied: normalizedWeights,
        explanationSummary: "Infeasible: No underwater computing pod satisfied all resource and environmental constraints.",
        status: "INFEASIBLE_NO_PODS",
      );
    }

    // Collect ranges for Min-Max Normalization
    final energies = feasiblePods.map((p) => computedMetrics[p.id]!["energy"]!).toList();
    final carbons = feasiblePods.map((p) => computedMetrics[p.id]!["carbon"]!).toList();
    final thermals = feasiblePods.map((p) => computedMetrics[p.id]!["thermal"]!).toList();
    final risks = feasiblePods.map((p) => computedMetrics[p.id]!["risk"]!).toList();
    final perfs = feasiblePods.map((p) => computedMetrics[p.id]!["perf"]!).toList();

    final normEnergies = _minMaxNormalize(energies);
    final normCarbons = _minMaxNormalize(carbons);
    final normThermals = _minMaxNormalize(thermals);
    final normRisks = _minMaxNormalize(risks);
    final normPerfs = _minMaxNormalize(perfs);

    // Check if user has explicitly customized weights
    final isCustomizedWeights = (weights.energy != 0.15 ||
        weights.carbon != 0.15 ||
        weights.thermalFootprint != 0.30 ||
        weights.environmentalRisk != 0.30 ||
        weights.performancePenalty != 0.10);

    final double wE;
    final double wC;
    final double wT;
    final double wR;
    final double wP;

    if (isCustomizedWeights) {
      wE = normalizedWeights["energy"]!;
      wC = normalizedWeights["carbon"]!;
      wT = normalizedWeights["thermal_footprint"]!;
      wR = normalizedWeights["environmental_risk"]!;
      wP = normalizedWeights["performance_penalty"]!;
    } else {
      // Priority-adaptive multi-objective defaults
      final isHighPriority = workload.priority.toUpperCase() == "HIGH" || workload.priority.toUpperCase() == "CRITICAL";
      final isLowPriority = workload.priority.toUpperCase() == "LOW";
      if (isHighPriority) {
        wP = 0.35;
        wE = 0.15;
        wC = 0.15;
        wT = 0.18;
        wR = 0.17;
      } else if (isLowPriority) {
        wP = 0.05;
        wE = 0.20;
        wC = 0.35;
        wT = 0.20;
        wR = 0.20;
      } else {
        wP = 0.20;
        wE = 0.20;
        wC = 0.20;
        wT = 0.20;
        wR = 0.20;
      }
    }

    final List<PodScoreRecord> scoredRecords = [];

    for (int i = 0; i < feasiblePods.length; i++) {
      final pod = feasiblePods[i];
      final m = computedMetrics[pod.id]!;

      final nE = normEnergies[i];
      final nC = normCarbons[i];
      final nT = normThermals[i];
      final nR = normRisks[i];
      final nP = normPerfs[i];

      final cE = wE * nE;
      final cC = wC * nC;
      final cT = wT * nT;
      final cR = wR * nR;
      final cP = wP * nP;

      final compositeScore = cE + cC + cT + cR + cP;

      scoredRecords.add(PodScoreRecord(
        podId: pod.id,
        podName: pod.name,
        location: pod.location,
        rank: 0,
        compositeScore: compositeScore,
        energyKwh: m["energy"]!,
        carbonKgCo2e: m["carbon"]!,
        thermalFootprint: m["thermal"]!,
        environmentalRisk: m["risk"]!,
        performancePenalty: m["perf"]!,
        deltaTempC: m["deltaTemp"]!,
        localWaterTempC: m["localWaterTemp"]!,
        internalPodTempC: m["internalPodTemp"]!,
        convectiveHWm2k: m["convectiveH"]!,
        normEnergy: nE,
        normCarbon: nC,
        normThermal: nT,
        normRisk: nR,
        normPerf: nP,
        energyContrib: cE,
        carbonContrib: cC,
        thermalContrib: cT,
        riskContrib: cR,
        perfContrib: cP,
        decisionNotes: "",
      ));
    }

    // Step 10: Sort by lowest composite score (lower is better)
    scoredRecords.sort((a, b) => a.compositeScore.compareTo(b.compositeScore));
    for (int idx = 0; idx < scoredRecords.length; idx++) {
      scoredRecords[idx].rank = idx + 1;
    }

    final best = scoredRecords.first;
    final isHighPriority = workload.priority.toUpperCase() == "HIGH" || workload.priority.toUpperCase() == "CRITICAL";
    final isLowPriority = workload.priority.toUpperCase() == "LOW";

    String reason = "Optimal multi-objective balance across energy, carbon, and thermal dispersion.";
    if (isHighPriority && best.performancePenalty < 1.0) {
      reason = "Selected for low latency (${best.location}) and dedicated compute capacity matching mission-critical inference.";
    } else if (isLowPriority) {
      reason = "Selected for high eco-efficiency and resource right-sizing on delay-tolerant batch workload.";
    } else if (best.carbonKgCo2e < 2.0) {
      reason = "Selected for ultra-low carbon emissions (${best.carbonKgCo2e.toStringAsFixed(2)} kg CO2e) utilizing regional renewable marine grid.";
    } else if (best.deltaTempC < 1.0) {
      reason = "Selected for superior convective cooling (+${best.deltaTempC.toStringAsFixed(2)}°C seawater rise) and low environmental risk.";
    }

    final explanation = "Selected ${best.podName} (${best.podId}) in ${best.location}. $reason "
        "Composite score: ${best.compositeScore.toStringAsFixed(4)} (Carbon: ${best.carbonKgCo2e.toStringAsFixed(2)} kg CO2e, Seawater ΔT: +${best.deltaTempC.toStringAsFixed(2)}°C). Evaluated ${feasiblePods.length} feasible pods (${ineligiblePods.length} filtered out).";

    return SchedulingDecisionResult(
      selectedPod: best,
      rankedPods: scoredRecords,
      ineligiblePods: ineligiblePods,
      weightsApplied: isCustomizedWeights
          ? normalizedWeights
          : {
              "energy": wE,
              "carbon": wC,
              "thermal_footprint": wT,
              "environmental_risk": wR,
              "performance_penalty": wP,
            },
      explanationSummary: explanation,
      status: "SUCCESS",
    );
  }

  /// Comparative evaluation between AquaEcoSched, First-Fit, and Resource-Only
  static Map<String, BaselinePolicyMetric> evaluateBaselines({
    required Workload workload,
    required List<PodResource> pods,
    required List<OceanCondition> oceanConditions,
    required SchedulingWeights weights,
    required RiskBudgetConstraints constraints,
  }) {
    final decision = schedule(
      workload: workload,
      pods: pods,
      oceanConditions: oceanConditions,
      weights: weights,
      constraints: constraints,
    );

    final oceanMap = {for (var o in oceanConditions) o.podId: o};

    // 1. AquaEcoSched Policy
    BaselinePolicyMetric aquaMetric;
    if (decision.selectedPod != null) {
      final b = decision.selectedPod!;
      aquaMetric = BaselinePolicyMetric(
        policyName: "AquaEcoSched (Eco-Aware)",
        selectedPodId: b.podId,
        selectedPodName: b.podName,
        scheduledSuccessfully: true,
        energyKwh: b.energyKwh,
        carbonKgCo2e: b.carbonKgCo2e,
        waterTempDeltaC: b.deltaTempC,
        environmentalRiskScore: b.environmentalRisk,
        constraintViolations: 0,
        violationDetails: [],
      );
    } else {
      aquaMetric = const BaselinePolicyMetric(
        policyName: "AquaEcoSched (Eco-Aware)",
        selectedPodId: null,
        selectedPodName: "None (Infeasible)",
        scheduledSuccessfully: false,
        energyKwh: 0,
        carbonKgCo2e: 0,
        waterTempDeltaC: 0,
        environmentalRiskScore: 0,
        constraintViolations: 0,
        violationDetails: ["No feasible pod"],
      );
    }

    // 2. Baseline 1: First-Fit (picks first hardware-eligible pod)
    final eligiblePods = pods.where((p) =>
      p.isOperational &&
      p.availableCpu >= workload.cpuCores &&
      p.availableGpu >= workload.gpuUnits &&
      p.availableRamGb >= workload.ramGb
    ).toList();

    BaselinePolicyMetric firstFitMetric;
    if (eligiblePods.isNotEmpty) {
      final ffPod = eligiblePods.first;
      firstFitMetric = _evaluateSinglePod(ffPod, workload, oceanMap[ffPod.id], constraints, "Baseline 1: First-Fit");
    } else {
      firstFitMetric = const BaselinePolicyMetric(
        policyName: "Baseline 1: First-Fit",
        selectedPodId: null,
        selectedPodName: "None",
        scheduledSuccessfully: false,
        energyKwh: 0,
        carbonKgCo2e: 0,
        waterTempDeltaC: 0,
        environmentalRiskScore: 0,
        constraintViolations: 0,
        violationDetails: ["No hardware eligible pod"],
      );
    }

    // 3. Baseline 2: Resource-Only / Best-Fit (picks pod with least available CPU headroom)
    BaselinePolicyMetric resourceOnlyMetric;
    if (eligiblePods.isNotEmpty) {
      eligiblePods.sort((a, b) => a.availableCpu.compareTo(b.availableCpu));
      final roPod = eligiblePods.first;
      resourceOnlyMetric = _evaluateSinglePod(roPod, workload, oceanMap[roPod.id], constraints, "Baseline 2: Resource-Only");
    } else {
      resourceOnlyMetric = const BaselinePolicyMetric(
        policyName: "Baseline 2: Resource-Only",
        selectedPodId: null,
        selectedPodName: "None",
        scheduledSuccessfully: false,
        energyKwh: 0,
        carbonKgCo2e: 0,
        waterTempDeltaC: 0,
        environmentalRiskScore: 0,
        constraintViolations: 0,
        violationDetails: ["No hardware eligible pod"],
      );
    }

    return {
      "AquaEcoSched": aquaMetric,
      "FirstFit": firstFitMetric,
      "ResourceOnly": resourceOnlyMetric,
    };
  }

  static BaselinePolicyMetric _evaluateSinglePod(
    PodResource pod,
    Workload workload,
    OceanCondition? ocean,
    RiskBudgetConstraints constraints,
    String policyName,
  ) {
    final currentSpeed = max(ocean?.currentSpeedMps ?? 0.5, 0.05);
    final depth = ocean?.depthM ?? 50.0;
    final carbonIntensity = ocean?.gridCarbonIntensityKgPerKwh ?? 0.20;
    final dynamicSpan = max(pod.maxPowerKw - pod.basePowerKw, 5.0);
    final cpuFrac = min(workload.cpuCores / max(pod.totalCpu, 1.0), 1.0);
    final gpuFrac = min(workload.gpuUnits / max(pod.totalGpu, 1.0), 1.0);
    final ramFrac = min(workload.ramGb / max(pod.totalRamGb, 1.0), 1.0);
    final dynamicUtil = (0.50 * cpuFrac) + (0.40 * gpuFrac) + (0.10 * ramFrac);

    final workloadFacilityPowerKw = (dynamicSpan * dynamicUtil) * pod.pue;
    final totalFacilityPowerKw = (pod.basePowerKw + (dynamicSpan * dynamicUtil)) * pod.pue;
    final workloadEnergyKwh = workloadFacilityPowerKw * workload.durationHours;
    final workloadCarbonKg = workloadEnergyKwh * carbonIntensity;

    final convectiveH = 350.0 + 850.0 * pow(currentSpeed, 0.8);
    final deltaTempC = (totalFacilityPowerKw * 1000.0) / (convectiveH * pod.surfaceAreaM2);

    final zoneWeight = _getZoneSensitivity(ocean?.ecologicalZone ?? "MODERATE");
    final dispersion = max(currentSpeed * sqrt(depth), 0.5);
    final thermalScore = ((deltaTempC * (totalFacilityPowerKw / 50.0)) / dispersion / 3.5).clamp(0.02, 1.0);
    final depthPenalty = depth >= 100.0 ? 1.0 : (1.0 + (100.0 - depth) / 150.0);
    final riskScore = (0.45 * thermalScore + 0.35 * zoneWeight * 1.3 + 0.20 * (deltaTempC / 3.0)) * (depthPenalty / 1.2);

    final List<String> violations = [];
    if (deltaTempC > constraints.maxWaterTempDeltaC) {
      violations.add("Water ΔT (+${deltaTempC.toStringAsFixed(2)}°C) exceeds budget");
    }
    if (riskScore > constraints.maxEnvironmentalRiskScore) {
      violations.add("Eco-Risk score (${riskScore.toStringAsFixed(3)}) exceeds budget");
    }
    if (constraints.disallowProtectedSanctuaries && (ocean?.isProtectedSanctuary ?? false)) {
      violations.add("Sanctuary breach: scheduled in protected marine zone (${ocean?.ecologicalZone})");
    }

    return BaselinePolicyMetric(
      policyName: policyName,
      selectedPodId: pod.id,
      selectedPodName: pod.name,
      scheduledSuccessfully: true,
      energyKwh: workloadEnergyKwh,
      carbonKgCo2e: workloadCarbonKg,
      waterTempDeltaC: deltaTempC,
      environmentalRiskScore: riskScore.clamp(0.01, 1.0),
      constraintViolations: violations.length,
      violationDetails: violations,
    );
  }

  static double _getZoneSensitivity(String zone) {
    switch (zone.toUpperCase()) {
      case "LOW_IMPACT":
        return 0.20;
      case "MODERATE":
        return 0.50;
      case "SENSITIVE_BENTHIC":
        return 0.85;
      case "PROTECTED_CORAL_REEF":
      case "SANCTUARY":
        return 1.00;
      default:
        return 0.50;
    }
  }

  /// Evaluates and identifies the best alternative subsea pod for dynamic workload migration
  /// when the current executing pod experiences thermal degradation or ocean surge.
  static PodScoreRecord? findMigrationTarget({
    required Workload workload,
    required String currentPodId,
    required List<PodResource> pods,
    required List<OceanCondition> oceanConditions,
    required SchedulingWeights weights,
    required RiskBudgetConstraints constraints,
  }) {
    final candidatePods = pods.where((p) => p.id != currentPodId && p.isOperational).toList();
    if (candidatePods.isEmpty) return null;

    final decision = schedule(
      workload: workload,
      pods: candidatePods,
      oceanConditions: oceanConditions,
      weights: weights,
      constraints: constraints,
    );

    return decision.selectedPod;
  }

  static List<double> _minMaxNormalize(List<double> values) {
    if (values.isEmpty) return [];
    double vMin = values.first;
    double vMax = values.first;
    for (final v in values) {
      if (v < vMin) vMin = v;
      if (v > vMax) vMax = v;
    }
    if ((vMax - vMin).abs() < 1e-9) {
      return List.filled(values.length, 0.0);
    }
    return values.map((v) => (v - vMin) / (vMax - vMin)).toList();
  }
}


