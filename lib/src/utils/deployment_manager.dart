import 'package:flutter/foundation.dart';

/// Deployment environment
enum DeploymentEnvironment {
  development,
  staging,
  production,
}

/// Deployment configuration
class DeploymentConfig {
  DeploymentConfig({
    required this.environment,
    required this.apiEndpoint,
    required this.firebaseProject,
    required this.analyticsEnabled,
    required this.crashReportingEnabled,
    required this.appVersion,
    required this.buildNumber,
  });
  final DeploymentEnvironment environment;
  final String apiEndpoint;
  final String firebaseProject;
  final bool analyticsEnabled;
  final bool crashReportingEnabled;
  final String appVersion;
  final int buildNumber;

  Map<String, dynamic> toJson() => {
        'environment': environment.toString().split('.').last,
        'apiEndpoint': apiEndpoint,
        'firebaseProject': firebaseProject,
        'analyticsEnabled': analyticsEnabled,
        'crashReportingEnabled': crashReportingEnabled,
        'appVersion': appVersion,
        'buildNumber': buildNumber,
      };

  @override
  String toString() =>
      'DeploymentConfig($environment: v$appVersion build $buildNumber)';
}

/// Deployment status
enum DeploymentStatus {
  pending,
  inProgress,
  successful,
  failed,
  rolled_back,
}

/// Deployment record
class DeploymentRecord {
  DeploymentRecord({
    required this.environment,
    required this.version,
    required this.buildNumber,
    String? commitHash,
    DateTime? deployedAt,
    Map<String, dynamic>? metadata,
  })  : id = 'DEP_${DateTime.now().millisecondsSinceEpoch}',
        status = DeploymentStatus.pending,
        deployedAt = deployedAt ?? DateTime.now(),
        commitHash = commitHash,
        metadata = metadata ?? {};
  final String id;
  final DeploymentEnvironment environment;
  final String version;
  final int buildNumber;
  DeploymentStatus status;
  final DateTime deployedAt;
  DateTime? completedAt;
  String? errorMessage;
  String? commitHash;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() => {
        'id': id,
        'environment': environment.toString().split('.').last,
        'version': version,
        'buildNumber': buildNumber,
        'status': status.toString().split('.').last,
        'deployedAt': deployedAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'errorMessage': errorMessage,
        'commitHash': commitHash,
        'metadata': metadata,
      };

  @override
  String toString() => 'DeploymentRecord($version - $status)';
}

/// Deployment manager
class DeploymentManager {
  factory DeploymentManager() => _instance;

  DeploymentManager._internal();
  static final DeploymentManager _instance = DeploymentManager._internal();

  final _deployments = <DeploymentRecord>[];
  DeploymentConfig? _currentConfig;

  /// Set deployment configuration
  void setConfig(DeploymentConfig config) {
    _currentConfig = config;
    debugPrint(
        '[DeploymentManager] Configuration set for ${config.environment}');
  }

  /// Get current configuration
  DeploymentConfig? getConfig() => _currentConfig;

  /// Start deployment
  Future<DeploymentRecord> startDeployment({
    required DeploymentEnvironment environment,
    required String version,
    required int buildNumber,
    String? commitHash,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      debugPrint('[DeploymentManager] Starting deployment to $environment...');

      final record = DeploymentRecord(
        environment: environment,
        version: version,
        buildNumber: buildNumber,
        commitHash: commitHash,
        metadata: metadata,
      );

      record.status = DeploymentStatus.inProgress;
      _deployments.add(record);

      // Simulate deployment process
      await Future.delayed(const Duration(milliseconds: 500));

      record.status = DeploymentStatus.successful;
      record.completedAt = DateTime.now();

      debugPrint('[DeploymentManager] Deployment successful: $version');
      return record;
    } catch (e) {
      debugPrint('[DeploymentManager] Deployment error: $e');
      rethrow;
    }
  }

  /// Mark deployment as failed
  void markDeploymentFailed(String deploymentId, String errorMessage) {
    final deployment = _deployments.firstWhere(
      (d) => d.id == deploymentId,
      orElse: () => null as dynamic,
    );

    deployment.status = DeploymentStatus.failed;
    deployment.errorMessage = errorMessage;
    deployment.completedAt = DateTime.now();
    debugPrint('[DeploymentManager] Deployment marked failed: $errorMessage');
  }

  /// Rollback deployment
  Future<void> rollbackDeployment(String deploymentId) async {
    try {
      final deployment = _deployments.firstWhere(
        (d) => d.id == deploymentId,
        orElse: () => null as dynamic,
      );

      deployment.status = DeploymentStatus.rolled_back;
      deployment.completedAt = DateTime.now();
      debugPrint('[DeploymentManager] Deployment rolled back');
    } catch (e) {
      debugPrint('[DeploymentManager] Rollback error: $e');
    }
  }

  /// Get all deployments
  List<DeploymentRecord> getAllDeployments() => List.unmodifiable(_deployments);

  /// Get deployments by environment
  List<DeploymentRecord> getDeploymentsByEnvironment(
          DeploymentEnvironment env) =>
      _deployments.where((d) => d.environment == env).toList();

  /// Get latest deployment
  DeploymentRecord? getLatestDeployment() =>
      _deployments.isNotEmpty ? _deployments.last : null;

  /// Get successful deployments
  List<DeploymentRecord> getSuccessfulDeployments() => _deployments
      .where((d) => d.status == DeploymentStatus.successful)
      .toList();

  /// Generate deployment report
  String generateReport() {
    final buffer = StringBuffer();
    final successful = getSuccessfulDeployments().length;
    final failed =
        _deployments.where((d) => d.status == DeploymentStatus.failed).length;

    buffer.writeln('''
╔══════════════════════════════════════════════════════════════════╗
║                 DEPLOYMENT REPORT                               ║
╠══════════════════════════════════════════════════════════════════╣
║ Total Deployments: ${_deployments.length.toString().padRight(46)}║
║ Successful: ${successful.toString().padRight(53)}║
║ Failed: ${failed.toString().padRight(55)}║
║ Success Rate: ${(_deployments.isEmpty ? 0.0 : (successful / _deployments.length) * 100).toStringAsFixed(1)}%${' '.padRight(43)}║
╠══════════════════════════════════════════════════════════════════╣
║ DEPLOYMENT HISTORY:
    ''');

    for (final deployment in _deployments.reversed.take(10)) {
      final status = deployment.status.toString().split('.').last;
      buffer.writeln(
          '║ [${deployment.environment.toString().split('.').last.toUpperCase()}] v${deployment.version}');
      buffer.writeln('║   Status: $status | Build: ${deployment.buildNumber}');
      if (deployment.errorMessage != null) {
        buffer.writeln('║   Error: ${deployment.errorMessage}');
      }
    }

    buffer.writeln(
        '╚══════════════════════════════════════════════════════════════════╝');
    return buffer.toString();
  }

  /// Clear all records
  void clear() {
    _deployments.clear();
  }
}
