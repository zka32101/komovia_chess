import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/deployment_manager.dart';
import '../utils/beta_testing_manager.dart';
import '../utils/launch_checklist.dart';
import '../utils/cicd_pipeline.dart';

/// Deployment manager provider
final deploymentManagerProvider = Provider((ref) => DeploymentManager());

/// Beta testing manager provider
final betaTestingManagerProvider = Provider((ref) => BetaTestingManager());

/// Launch checklist provider
final launchChecklistProvider = Provider((ref) => LaunchChecklist());

/// CI/CD pipeline provider
final cicdPipelineProvider = Provider((ref) => CICDPipeline());

/// Current deployment config provider
final currentDeploymentConfigProvider = Provider((ref) {
  final manager = ref.watch(deploymentManagerProvider);
  return manager.getConfig();
});

/// All deployments provider
final allDeploymentsProvider = Provider((ref) {
  final manager = ref.watch(deploymentManagerProvider);
  return manager.getAllDeployments();
});

/// Latest deployment provider
final latestDeploymentProvider = Provider((ref) {
  final manager = ref.watch(deploymentManagerProvider);
  return manager.getLatestDeployment();
});

/// Successful deployments provider
final successfulDeploymentsProvider = Provider((ref) {
  final manager = ref.watch(deploymentManagerProvider);
  return manager.getSuccessfulDeployments();
});

/// Active beta testers provider
final activeBetaTestersProvider = Provider((ref) {
  final manager = ref.watch(betaTestingManagerProvider);
  return manager.getActiveTesters();
});

/// All beta testers provider
final allBetaTestersProvider = Provider((ref) {
  final manager = ref.watch(betaTestingManagerProvider);
  return manager.getAllTesters();
});

/// Beta testing sessions provider
final betaSessionsProvider = Provider((ref) {
  final manager = ref.watch(betaTestingManagerProvider);
  return manager.getAllSessions();
});

/// Current launch phase provider
final currentLaunchPhaseProvider = Provider((ref) {
  final checklist = ref.watch(launchChecklistProvider);
  return checklist.getCurrentPhase();
});

/// Launch completion percentage provider
final launchCompletionProvider = Provider((ref) {
  final checklist = ref.watch(launchChecklistProvider);
  return checklist.getOverallCompletion();
});

/// Current phase items provider
final currentPhaseItemsProvider = Provider((ref) {
  final checklist = ref.watch(launchChecklistProvider);
  return checklist.getCurrentPhaseItems();
});

/// Ready for next phase provider
final readyForNextPhaseProvider = Provider((ref) {
  final checklist = ref.watch(launchChecklistProvider);
  return checklist.isReadyForNextPhase();
});

/// All pipeline runs provider
final allPipelineRunsProvider = Provider((ref) {
  final pipeline = ref.watch(cicdPipelineProvider);
  return pipeline.getAllRuns();
});

/// Latest pipeline run provider
final latestPipelineRunProvider = Provider((ref) {
  final pipeline = ref.watch(cicdPipelineProvider);
  return pipeline.getLatestRun();
});

/// Pipeline passed runs provider
final pipelinePassedRunsProvider = Provider((ref) {
  final pipeline = ref.watch(cicdPipelineProvider);
  return pipeline.getPassedRuns();
});

/// Deployment execution notifier
class DeploymentNotifier extends StateNotifier<bool> {
  DeploymentNotifier() : super(false);
  final _manager = DeploymentManager();

  Future<void> deploy({
    required DeploymentEnvironment environment,
    required String version,
    required int buildNumber,
    String? commitHash,
  }) async {
    state = true;
    try {
      await _manager.startDeployment(
        environment: environment,
        version: version,
        buildNumber: buildNumber,
        commitHash: commitHash,
      );
    } finally {
      state = false;
    }
  }
}

/// Deployment execution provider
final deploymentExecutionProvider =
    StateNotifierProvider<DeploymentNotifier, bool>(
        (ref) => DeploymentNotifier());

/// Beta session notifier
class BetaSessionNotifier extends StateNotifier<int> {
  BetaSessionNotifier() : super(0);
  final _manager = BetaTestingManager();

  void startSession(String version) {
    _manager.startBetaSession(version);
    state = _manager.getAllSessions().length;
  }

  void endSession(String sessionId) {
    _manager.endBetaSession(sessionId);
  }
}

/// Beta session provider
final betaSessionNotifierProvider =
    StateNotifierProvider<BetaSessionNotifier, int>(
        (ref) => BetaSessionNotifier());

/// Launch phase advancement notifier
class LaunchPhaseNotifier extends StateNotifier<LaunchPhase> {
  LaunchPhaseNotifier() : super(LaunchPhase.preAlpha);
  final _checklist = LaunchChecklist();

  bool advancePhase() {
    if (_checklist.advanceToNextPhase()) {
      state = _checklist.getCurrentPhase();
      return true;
    }
    return false;
  }

  void setPhase(LaunchPhase phase) {
    _checklist.setCurrentPhase(phase);
    state = phase;
  }
}

/// Launch phase provider
final launchPhaseNotifierProvider =
    StateNotifierProvider<LaunchPhaseNotifier, LaunchPhase>(
        (ref) => LaunchPhaseNotifier());

/// Pipeline execution notifier
class PipelineNotifier extends StateNotifier<bool> {
  PipelineNotifier() : super(false);
  final _pipeline = CICDPipeline();

  Future<void> executePipeline(String commitHash, String branch) async {
    state = true;
    try {
      final run = _pipeline.startRun(commitHash, branch);
      await _pipeline.executePipelineRun(run.id);
    } finally {
      state = false;
    }
  }
}

/// Pipeline execution provider
final pipelineExecutionProvider =
    StateNotifierProvider<PipelineNotifier, bool>((ref) => PipelineNotifier());
