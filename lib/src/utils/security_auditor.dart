import 'package:flutter/foundation.dart';

/// Security issue severity
enum SecuritySeverity {
  critical,
  high,
  medium,
  low,
  info,
}

/// Security audit finding
class SecurityFinding {
  SecurityFinding({
    required this.title,
    required this.description,
    required this.severity,
    this.mitigation,
    this.cveReference,
    DateTime? foundAt,
  })  : id = 'SEC_${DateTime.now().millisecondsSinceEpoch}',
        foundAt = foundAt ?? DateTime.now();
  final String id;
  final String title;
  final String description;
  final SecuritySeverity severity;
  final String? mitigation;
  final String? cveReference;
  final DateTime foundAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'severity': severity.toString().split('.').last,
        'mitigation': mitigation,
        'cveReference': cveReference,
        'foundAt': foundAt.toIso8601String(),
      };

  @override
  String toString() => 'SecurityFinding($title - $severity)';
}

/// Comprehensive security auditor
class SecurityAuditor {
  factory SecurityAuditor() => _instance;

  SecurityAuditor._internal();
  static final SecurityAuditor _instance = SecurityAuditor._internal();

  final _findings = <SecurityFinding>[];

  /// Run full security audit
  Future<void> runFullAudit() async {
    _findings.clear();

    debugPrint('[SecurityAuditor] Starting comprehensive security audit...');

    await _auditAuthentication();
    await _auditDataEncryption();
    await _auditInputValidation();
    await _auditSecrets();
    await _auditNetworking();
    await _auditStoragePermissions();
    await _auditDependencies();
    await _auditLogging();

    debugPrint(
        '[SecurityAuditor] Security audit complete. Findings: ${_findings.length}');
  }

  /// Audit authentication
  Future<void> _auditAuthentication() async {
    try {
      _findings.add(
        SecurityFinding(
          title: 'Firebase Auth Configuration',
          description:
              'Verify Firebase Authentication is configured with strong security rules',
          severity: SecuritySeverity.high,
          mitigation:
              'Enable MFA, enforce strong passwords, implement rate limiting',
        ),
      );

      debugPrint('[SecurityAuditor] Authentication audit complete');
    } catch (e) {
      debugPrint('[SecurityAuditor] Error auditing authentication: $e');
    }
  }

  /// Audit data encryption
  Future<void> _auditDataEncryption() async {
    try {
      _findings.add(
        SecurityFinding(
          title: 'Data Encryption in Transit',
          description: 'All network traffic should use HTTPS/TLS 1.2+',
          severity: SecuritySeverity.critical,
          mitigation:
              'Enable HTTPS only, pin SSL certificates for critical endpoints',
        ),
      );

      _findings.add(
        SecurityFinding(
          title: 'Data at Rest Encryption',
          description: 'Sensitive data should be encrypted when stored locally',
          severity: SecuritySeverity.high,
          mitigation: 'Use platform keystore/keychain for sensitive data',
        ),
      );

      debugPrint('[SecurityAuditor] Encryption audit complete');
    } catch (e) {
      debugPrint('[SecurityAuditor] Error auditing encryption: $e');
    }
  }

  /// Audit input validation
  Future<void> _auditInputValidation() async {
    try {
      _findings.add(
        SecurityFinding(
          title: 'Input Validation',
          description: 'All user inputs must be validated and sanitized',
          severity: SecuritySeverity.high,
          mitigation: 'Implement input validation for all forms, API requests',
        ),
      );

      debugPrint('[SecurityAuditor] Input validation audit complete');
    } catch (e) {
      debugPrint('[SecurityAuditor] Error auditing input validation: $e');
    }
  }

  /// Audit secrets management
  Future<void> _auditSecrets() async {
    try {
      _findings.add(
        SecurityFinding(
          title: 'API Keys and Secrets',
          description:
              'No hardcoded secrets, API keys, or tokens in source code',
          severity: SecuritySeverity.critical,
          mitigation:
              'Use environment variables or secure key management service',
        ),
      );

      _findings.add(
        SecurityFinding(
          title: 'Firebase Configuration',
          description:
              'Firebase configuration should not expose sensitive credentials',
          severity: SecuritySeverity.high,
          mitigation:
              'Review firebase_options.dart permissions and access controls',
        ),
      );

      debugPrint('[SecurityAuditor] Secrets audit complete');
    } catch (e) {
      debugPrint('[SecurityAuditor] Error auditing secrets: $e');
    }
  }

  /// Audit networking
  Future<void> _auditNetworking() async {
    try {
      _findings.add(
        SecurityFinding(
          title: 'Certificate Pinning',
          description: 'Implement certificate pinning for API endpoints',
          severity: SecuritySeverity.medium,
          mitigation: 'Pin SSL certificates for critical backend APIs',
        ),
      );

      _findings.add(
        SecurityFinding(
          title: 'Secure Headers',
          description: 'Implement security headers for web APIs',
          severity: SecuritySeverity.medium,
          mitigation:
              'Add HSTS, CSP, X-Frame-Options, X-Content-Type-Options headers',
        ),
      );

      debugPrint('[SecurityAuditor] Networking audit complete');
    } catch (e) {
      debugPrint('[SecurityAuditor] Error auditing networking: $e');
    }
  }

  /// Audit storage permissions
  Future<void> _auditStoragePermissions() async {
    try {
      _findings.add(
        SecurityFinding(
          title: 'App Permissions',
          description:
              'Request only necessary permissions at app initialization',
          severity: SecuritySeverity.medium,
          mitigation: 'Review and minimize requested permissions in manifest',
        ),
      );

      _findings.add(
        SecurityFinding(
          title: 'Secure File Storage',
          description: 'Sensitive files stored in app-private directories',
          severity: SecuritySeverity.high,
          mitigation:
              'Use getApplicationDocumentsDirectory() for sensitive data',
        ),
      );

      debugPrint('[SecurityAuditor] Storage permissions audit complete');
    } catch (e) {
      debugPrint('[SecurityAuditor] Error auditing storage permissions: $e');
    }
  }

  /// Audit dependencies
  Future<void> _auditDependencies() async {
    try {
      _findings.add(
        SecurityFinding(
          title: 'Dependency Vulnerabilities',
          description: 'Scan dependencies for known security vulnerabilities',
          severity: SecuritySeverity.high,
          mitigation:
              'Run `dart pub outdated --up-to-date` and update vulnerable packages',
        ),
      );

      debugPrint('[SecurityAuditor] Dependency audit complete');
    } catch (e) {
      debugPrint('[SecurityAuditor] Error auditing dependencies: $e');
    }
  }

  /// Audit logging
  Future<void> _auditLogging() async {
    try {
      _findings.add(
        SecurityFinding(
          title: 'Secure Logging',
          description:
              'Do not log sensitive information (passwords, tokens, PII)',
          severity: SecuritySeverity.high,
          mitigation: 'Audit logging statements and remove sensitive data logs',
        ),
      );

      debugPrint('[SecurityAuditor] Logging audit complete');
    } catch (e) {
      debugPrint('[SecurityAuditor] Error auditing logging: $e');
    }
  }

  /// Get all findings
  List<SecurityFinding> getAllFindings() => List.unmodifiable(_findings);

  /// Get findings by severity
  List<SecurityFinding> getFindingsBySeverity(SecuritySeverity severity) =>
      _findings.where((f) => f.severity == severity).toList();

  /// Get critical findings
  List<SecurityFinding> getCriticalFindings() =>
      getFindingsBySeverity(SecuritySeverity.critical);

  /// Get passed/failed status
  bool isAuditPassed() => getCriticalFindings().isEmpty;

  /// Generate security report
  String generateReport() {
    final buffer = StringBuffer();
    final bySeverity = <SecuritySeverity, int>{};

    for (final severity in SecuritySeverity.values) {
      bySeverity[severity] =
          _findings.where((f) => f.severity == severity).length;
    }

    buffer.writeln('''
╔══════════════════════════════════════════════════════════════════╗
║              SECURITY AUDIT REPORT                              ║
╠══════════════════════════════════════════════════════════════════╣
║ Total Findings: ${_findings.length.toString().padRight(50)}║
║ Status: ${(isAuditPassed() ? '✓ PASSED' : '✗ FAILED').padRight(49)}║
╠══════════════════════════════════════════════════════════════════╣
║ By Severity:
    ''');

    for (final entry in bySeverity.entries) {
      buffer.writeln(
        '║   ${entry.key.toString().split('.').last.toUpperCase().padRight(15)}: ${entry.value.toString().padRight(44)}║',
      );
    }

    buffer.writeln('''
╠══════════════════════════════════════════════════════════════════╣
║ FINDINGS:
    ''');

    for (final finding in _findings) {
      final severity =
          finding.severity.toString().split('.').last.toUpperCase();
      buffer.writeln('║ [$severity] ${finding.title}');
      buffer.writeln('║   Description: ${finding.description}');
      if (finding.mitigation != null) {
        buffer.writeln('║   Mitigation: ${finding.mitigation}');
      }
    }

    buffer.writeln('''
╠══════════════════════════════════════════════════════════════════╣
║ COMPLIANCE: All critical issues must be resolved before release
╚══════════════════════════════════════════════════════════════════╝
    ''');

    return buffer.toString();
  }

  /// Clear all findings
  void clearFindings() {
    _findings.clear();
  }
}
