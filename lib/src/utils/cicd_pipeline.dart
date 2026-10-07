import 'package:flutter/foundation.dart';

/// CI/CD pipeline stage
enum PipelineStage {
  checkout,
  analysis,
  testing,
  build,
  upload,
  deploy,
  verify,
}

/// Pipeline job status
enum JobStatus {
  queued,
  running,
  success,
  failure,
  skipped,
  cancelled,
}

/// CI/CD job
class PipelineJob {
  PipelineJob({
    required this.stage,
    String? id,
    DateTime? createdAt,
  })  : id = id ?? 'JOB_${DateTime.now().millisecondsSinceEpoch}',
        status = JobStatus.queued,
        createdAt = createdAt ?? DateTime.now();
  final String id;
  final PipelineStage stage;
  JobStatus status;
  final DateTime createdAt;
  DateTime? startedAt;
  DateTime? completedAt;
  String? errorMessage;
  List<String> logs = [];

  Duration? get duration {
    if (startedAt == null || completedAt == null) return null;
    return completedAt!.difference(startedAt!);
  }

  void start() {
    status = JobStatus.running;
    startedAt = DateTime.now();
  }

  void complete({bool success = true, String? error}) {
    status = success ? JobStatus.success : JobStatus.failure;
    completedAt = DateTime.now();
    errorMessage = error;
  }

  void addLog(String message) {
    logs.add('[${DateTime.now()}] $message');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'stage': stage.toString().split('.').last,
        'status': status.toString().split('.').last,
        'createdAt': createdAt.toIso8601String(),
        'startedAt': startedAt?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'durationMs': duration?.inMilliseconds,
        'errorMessage': errorMessage,
        'logCount': logs.length,
      };

  @override
  String toString() => 'PipelineJob($stage - $status)';
}

/// CI/CD pipeline run
class PipelineRun {
  PipelineRun({
    required this.commitHash,
    required this.branch,
    String? id,
    DateTime? createdAt,
  })  : id = id ?? 'RUN_${DateTime.now().millisecondsSinceEpoch}',
        createdAt = createdAt ?? DateTime.now();
  final String id;
  final String commitHash;
  final String branch;
  final List<PipelineJob> jobs = [];
  DateTime createdAt;
  DateTime? completedAt;

  void addJob(PipelineJob job) {
    jobs.add(job);
  }

  bool get isPassed => jobs.every(
      (j) => j.status == JobStatus.success || j.status == JobStatus.skipped);
  bool get isRunning => jobs.any((j) => j.status == JobStatus.running);
  bool get isComplete => !isRunning;

  Duration? get totalDuration {
    if (jobs.isEmpty) return null;
    final firstStart = jobs
        .where((j) => j.startedAt != null)
        .map((j) => j.startedAt!)
        .fold<DateTime?>(null,
            (prev, curr) => prev == null || curr.isBefore(prev) ? curr : prev);
    final lastEnd = jobs
        .where((j) => j.completedAt != null)
        .map((j) => j.completedAt!)
        .fold<DateTime?>(null,
            (prev, curr) => prev == null || curr.isAfter(prev) ? curr : prev);

    if (firstStart == null || lastEnd == null) return null;
    return lastEnd.difference(firstStart);
  }

  void complete() {
    completedAt = DateTime.now();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'commitHash': commitHash,
        'branch': branch,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'isPassed': isPassed,
        'totalDurationMs': totalDuration?.inMilliseconds,
        'jobs': jobs.map((j) => j.toJson()).toList(),
      };

  @override
  String toString() =>
      'PipelineRun($branch - ${isPassed ? "PASSED" : "FAILED"})';
}

/// CI/CD Pipeline manager
class CICDPipeline {
  factory CICDPipeline() => _instance;

  CICDPipeline._internal();
  static final CICDPipeline _instance = CICDPipeline._internal();

  final _runs = <PipelineRun>[];

  /// Start new pipeline run
  PipelineRun startRun(String commitHash, String branch) {
    final run = PipelineRun(
      commitHash: commitHash,
      branch: branch,
    );

    // Add standard jobs
    run.addJob(PipelineJob(stage: PipelineStage.checkout));
    run.addJob(PipelineJob(stage: PipelineStage.analysis));
    run.addJob(PipelineJob(stage: PipelineStage.testing));
    run.addJob(PipelineJob(stage: PipelineStage.build));
    run.addJob(PipelineJob(stage: PipelineStage.upload));
    run.addJob(PipelineJob(stage: PipelineStage.deploy));
    run.addJob(PipelineJob(stage: PipelineStage.verify));

    _runs.add(run);
    debugPrint('[CICDPipeline] Pipeline started for $branch');
    return run;
  }

  /// Execute pipeline run
  Future<void> executePipelineRun(String runId) async {
    try {
      final run = _runs.firstWhere(
        (r) => r.id == runId,
        orElse: () => null as dynamic,
      );

      for (final job in run.jobs) {
        job.start();
        job.addLog('${job.stage.toString().split('.').last} stage started');

        // Simulate job execution
        await Future.delayed(const Duration(milliseconds: 100));

        job.complete(success: true);
        job.addLog(
            '${job.stage.toString().split('.').last} stage completed successfully');
      }

      run.complete();
      debugPrint(
          '[CICDPipeline] Pipeline run completed: ${run.isPassed ? "PASSED" : "FAILED"}');
    } catch (e) {
      debugPrint('[CICDPipeline] Pipeline execution error: $e');
    }
  }

  /// Get all runs
  List<PipelineRun> getAllRuns() => List.unmodifiable(_runs);

  /// Get latest run
  PipelineRun? getLatestRun() => _runs.isNotEmpty ? _runs.last : null;

  /// Get runs by branch
  List<PipelineRun> getRunsByBranch(String branch) =>
      _runs.where((r) => r.branch == branch).toList();

  /// Get passed runs
  List<PipelineRun> getPassedRuns() => _runs.where((r) => r.isPassed).toList();

  /// Generate pipeline report
  String generateReport() {
    final buffer = StringBuffer();
    final passed = getPassedRuns().length;
    final failed = _runs.where((r) => !r.isPassed).length;

    buffer.writeln('''
╔══════════════════════════════════════════════════════════════════╗
║                  CI/CD PIPELINE REPORT                          ║
╠══════════════════════════════════════════════════════════════════╣
║ Total Runs: ${_runs.length.toString().padRight(50)}║
║ Passed: ${passed.toString().padRight(54)}║
║ Failed: ${failed.toString().padRight(54)}║
║ Success Rate: ${(_runs.isEmpty ? 0.0 : (passed / _runs.length) * 100).toStringAsFixed(1)}%${' '.padRight(43)}║
╠══════════════════════════════════════════════════════════════════╣
║ RECENT RUNS:
    ''');

    for (final run in _runs.reversed.take(10)) {
      final status = run.isPassed ? '✓ PASSED' : '✗ FAILED';
      buffer.writeln(
          '║ [$status] ${run.branch.padRight(30)}: ${run.commitHash.substring(0, 7)}');
      for (final job in run.jobs) {
        final jobStatus = job.status.toString().split('.').last;
        buffer.writeln(
            '║   ${job.stage.toString().split('.').last.padRight(15)}: $jobStatus');
      }
    }

    buffer.writeln(
        '╚══════════════════════════════════════════════════════════════════╝');
    return buffer.toString();
  }

  /// Clear all data
  void clear() {
    _runs.clear();
  }
}
