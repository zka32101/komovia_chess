import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/version.dart';

/// Version Management Service
class VersionManagementService {
  factory VersionManagementService({FirebaseFirestore? firestore}) {
    if (firestore != null) {
      _instance._firestore = firestore;
    }
    return _instance;
  }

  VersionManagementService._internal()
      : _firestore = FirebaseFirestore.instance;
  static final VersionManagementService _instance =
      VersionManagementService._internal();

  FirebaseFirestore _firestore;
  String? _currentVersion = '1.0.0';
  int? _currentBuildNumber = 1;

  /// Get current version
  String getCurrentVersion() => _currentVersion ?? '1.0.0';

  /// Get current build number
  int getCurrentBuildNumber() => _currentBuildNumber ?? 1;

  /// Check for updates
  Future<AppVersion?> checkForUpdates() async {
    try {
      final querySnapshot = await _firestore
          .collection('app_versions')
          .orderBy('releaseDate', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) return null;

      final latestVersion =
          AppVersion.fromJson(querySnapshot.docs.first.data());

      // Compare versions
      if (_isNewerVersion(
          latestVersion.versionNumber, _currentVersion ?? '1.0.0')) {
        return latestVersion;
      }

      return null;
    } catch (e) {
      print('Error checking for updates: $e');
      return null;
    }
  }

  /// Get update details
  Future<AppVersion?> fetchUpdateDetails(String versionNumber) async {
    try {
      final querySnapshot = await _firestore
          .collection('app_versions')
          .where('versionNumber', isEqualTo: versionNumber)
          .get();

      if (querySnapshot.docs.isEmpty) return null;

      return AppVersion.fromJson(querySnapshot.docs.first.data());
    } catch (e) {
      print('Error fetching update details: $e');
      return null;
    }
  }

  /// Get release notes
  Future<String> getVersionReleaseNotes(String version) async {
    try {
      final versionDoc = await fetchUpdateDetails(version);
      if (versionDoc == null) return '';

      final notes = StringBuffer();
      notes.writeln('### Version $version');
      notes.writeln('Released: ${versionDoc.releaseDate}');
      notes.writeln();

      for (final entry in versionDoc.changelog) {
        notes.writeln('**${entry.type.name.toUpperCase()}**: ${entry.title}');
        notes.writeln(entry.description);
        notes.writeln();
      }

      if (versionDoc.knownIssues.isNotEmpty) {
        notes.writeln('### Known Issues');
        for (final issue in versionDoc.knownIssues) {
          notes.writeln('- $issue');
        }
      }

      return notes.toString();
    } catch (e) {
      print('Error getting release notes: $e');
      return '';
    }
  }

  /// Track update statistics
  Future<void> trackUpdateStats(String version, {int? activeUsers}) async {
    try {
      final stat = VersionStat(
        version: version,
        activeUsers: activeUsers ?? 0,
        adoptionRate: 0,
        updatePercentage: 0,
        crashRate: 0,
        timestamp: DateTime.now(),
      );

      await _firestore
          .collection('version_stats')
          .doc(version)
          .set(stat.toJson());
    } catch (e) {
      print('Error tracking update stats: $e');
    }
  }

  /// Update app version
  Future<void> updateAppVersion(String version, int buildNumber) async {
    _currentVersion = version;
    _currentBuildNumber = buildNumber;

    try {
      await _firestore.collection('settings').doc('current_version').set({
        'version': version,
        'buildNumber': buildNumber,
        'lastUpdated': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error updating app version: $e');
    }
  }

  /// Helper: Compare versions
  bool _isNewerVersion(String newVersion, String currentVersion) {
    final newParts =
        newVersion.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final currentParts =
        currentVersion.split('.').map((p) => int.tryParse(p) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      final newPart = i < newParts.length ? newParts[i] : 0;
      final currentPart = i < currentParts.length ? currentParts[i] : 0;

      if (newPart > currentPart) return true;
      if (newPart < currentPart) return false;
    }

    return false;
  }
}
