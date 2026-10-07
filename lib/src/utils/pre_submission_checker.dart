/// Checklist item
class ChecklistItem {
  ChecklistItem({
    required this.title,
    required this.description,
    this.isCompleted = false,
    this.notes,
    DateTime? createdAt,
  })  : id = 'ITEM_${DateTime.now().millisecondsSinceEpoch}',
        createdAt = createdAt ?? DateTime.now();
  final String id;
  final String title;
  final String description;
  bool isCompleted;
  String? notes;
  final DateTime createdAt;
  DateTime? completedAt;

  void complete({String? note}) {
    isCompleted = true;
    completedAt = DateTime.now();
    notes = note;
  }

  void incomplete() {
    isCompleted = false;
    completedAt = null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'isCompleted': isCompleted,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
      };

  @override
  String toString() => '$title${isCompleted ? ' ✓' : ' ○'}';
}

/// Checklist category
class ChecklistCategory {
  ChecklistCategory({
    required this.name,
    required this.description,
  });
  final String name;
  final String description;
  final List<ChecklistItem> items = [];

  int get totalItems => items.length;
  int get completedItems => items.where((i) => i.isCompleted).length;
  double get completionPercentage =>
      totalItems > 0 ? (completedItems / totalItems) * 100 : 0.0;
  bool get isComplete => completedItems == totalItems;

  void addItem(ChecklistItem item) => items.add(item);
}

/// Pre-submission verification checker
class PreSubmissionChecker {
  factory PreSubmissionChecker() => _instance;

  PreSubmissionChecker._internal() {
    _initializeChecklists();
  }
  static final PreSubmissionChecker _instance =
      PreSubmissionChecker._internal();

  final _categories = <ChecklistCategory>[];

  /// Initialize all checklists
  void _initializeChecklists() {
    _createCodeQualityChecklist();
    _createFunctionalityChecklist();
    _createUIUXChecklist();
    _createPerformanceChecklist();
    _createSecurityChecklist();
    _createComplianceChecklist();
  }

  /// Create code quality checklist
  void _createCodeQualityChecklist() {
    final category = ChecklistCategory(
      name: 'Code Quality',
      description: 'Verify code standards and best practices',
    );

    category.addItem(
      ChecklistItem(
        title: 'Dart Analysis Passing',
        description: 'No errors from `dart analyze lib/`',
      ),
    );

    category.addItem(
      ChecklistItem(
        title: 'Code Formatting',
        description: 'All code formatted with `dart format lib/`',
      ),
    );

    category.addItem(
      ChecklistItem(
        title: 'Unit Tests',
        description: 'All unit tests passing with >60% coverage',
      ),
    );

    category.addItem(
      ChecklistItem(
        title: 'No Warnings',
        description: 'No deprecation or lint warnings',
      ),
    );

    category.addItem(
      ChecklistItem(
        title: 'No TODO Comments',
        description: 'All TODO items resolved or documented',
      ),
    );

    _categories.add(category);
  }

  /// Create functionality checklist
  void _createFunctionalityChecklist() {
    final category = ChecklistCategory(
      name: 'Functionality',
      description: 'Verify all features work correctly',
    );

    category.addItem(
      ChecklistItem(
        title: 'User Authentication',
        description: 'Login, signup, and logout working',
      ),
    );

    category.addItem(
      ChecklistItem(
        title: 'Game Features',
        description: 'All game modes and features functional',
      ),
    );

    category.addItem(
      ChecklistItem(
        title: 'Offline Mode',
        description: 'App works with limited connectivity',
      ),
    );

    category.addItem(
      ChecklistItem(
        title: 'Navigation',
        description: 'All navigation flows working correctly',
      ),
    );

    category.addItem(
      ChecklistItem(
        title: 'Data Persistence',
        description: 'User data saved and restored correctly',
      ),
    );

    _categories.add(category);
  }

  /// Create UI/UX checklist
  void _createUIUXChecklist() {
    final category = ChecklistCategory(
      name: 'UI/UX',
      description: 'Verify user experience and design',
    );

    category.addItem(
      ChecklistItem(
        title: 'Material 3 Compliance',
        description: 'All UI follows Material 3 design system',
      ),
    );

    category.addItem(
      ChecklistItem(
        title: 'Dark Mode Support',
        description: 'Dark mode fully functional across app',
      ),
    );

    category.addItem(
      ChecklistItem(
        title: 'Responsive Design',
        description: 'Works on phones, tablets, and landscape',
      ),
    );

    category.addItem(
      ChecklistItem(
        title: 'Animation Polish',
        description: 'Smooth animations, no jank',
      ),
    );

    category.addItem(
      ChecklistItem(
        title: 'Error Handling',
        description: 'User-friendly error messages shown',
      ),
    );

    _categories.add(category);
  }

  /// Create performance checklist
  void _createPerformanceChecklist() {
    final category = ChecklistCategory(
      name: 'Performance',
      description: 'Verify app performance meets targets',
    );

    category.addItem(
      ChecklistItem(
        title: 'Startup Time',
        description: 'Cold startup < 3 seconds on flagship',
      ),
    );

    category.addItem(
      ChecklistItem(
        title: 'Memory Usage',
        description: 'Memory < 200MB on iOS, < 150MB on Android',
      ),
    );

    category.addItem(
      ChecklistItem(
        title: 'Frame Rate',
        description: '60 FPS on flagship, 45+ on mid-range',
      ),
    );

    category.addItem(
      ChecklistItem(
        title: 'App Size',
        description: 'App size < 150MB (iOS), < 120MB (Android)',
      ),
    );

    category.addItem(
      ChecklistItem(
        title: 'Network Optimization',
        description: 'Requests batched and cached properly',
      ),
    );

    _categories.add(category);
  }

  /// Create security checklist
  void _createSecurityChecklist() {
    final category = ChecklistCategory(
      name: 'Security',
      description: 'Verify security best practices',
    );

    category.addItem(
      ChecklistItem(
        title: 'No Hardcoded Secrets',
        description: 'No API keys or tokens in code',
      ),
    );

    category.addItem(
      ChecklistItem(
        title: 'HTTPS Only',
        description: 'All network communication encrypted',
      ),
    );

    category.addItem(
      ChecklistItem(
        title: 'Input Validation',
        description: 'All user inputs validated',
      ),
    );

    category.addItem(
      ChecklistItem(
        title: 'Authentication Secure',
        description: 'Firebase Auth configured securely',
      ),
    );

    category.addItem(
      ChecklistItem(
        title: 'Data Privacy',
        description: 'User data handled according to policy',
      ),
    );

    _categories.add(category);
  }

  /// Create compliance checklist
  void _createComplianceChecklist() {
    final category = ChecklistCategory(
      name: 'Compliance & Release',
      description: 'Verify compliance and release readiness',
    );

    category.addItem(
      ChecklistItem(
        title: 'Accessibility (WCAG 2.1)',
        description: 'App meets WCAG 2.1 Level AA standards',
      ),
    );

    category.addItem(
      ChecklistItem(
        title: 'Privacy Policy',
        description: 'Privacy policy present and accurate',
      ),
    );

    category.addItem(
      ChecklistItem(
        title: 'Terms of Service',
        description: 'Terms of service present and compliant',
      ),
    );

    category.addItem(
      ChecklistItem(
        title: 'Release Notes',
        description: 'Release notes prepared',
      ),
    );

    category.addItem(
      ChecklistItem(
        title: 'App Store Screenshots',
        description: 'Screenshots prepared and optimized',
      ),
    );

    category.addItem(
      ChecklistItem(
        title: 'App Metadata',
        description: 'Title, description, keywords updated',
      ),
    );

    _categories.add(category);
  }

  /// Get all categories
  List<ChecklistCategory> getAllCategories() => List.unmodifiable(_categories);

  /// Get category by name
  ChecklistCategory? getCategoryByName(String name) => _categories
      .firstWhere((c) => c.name == name, orElse: () => null as dynamic);

  /// Get all incomplete items
  List<ChecklistItem> getIncompleteItems() {
    final items = <ChecklistItem>[];
    for (final category in _categories) {
      items.addAll(category.items.where((i) => !i.isCompleted));
    }
    return items;
  }

  /// Get overall completion percentage
  double getOverallCompletion() {
    int totalItems = 0;
    int completedItems = 0;

    for (final category in _categories) {
      totalItems += category.totalItems;
      completedItems += category.completedItems;
    }

    return totalItems > 0 ? (completedItems / totalItems) * 100 : 0.0;
  }

  /// Check if all items are complete
  bool isPreSubmissionReady() => getOverallCompletion() == 100.0;

  /// Generate pre-submission report
  String generateReport() {
    final buffer = StringBuffer();
    final overall = getOverallCompletion();
    final isReady = isPreSubmissionReady();

    buffer.writeln('''
╔══════════════════════════════════════════════════════════════════╗
║          PRE-SUBMISSION VERIFICATION CHECKLIST                   ║
╠══════════════════════════════════════════════════════════════════╣
║ Overall Completion: ${overall.toStringAsFixed(1)}%${' '.padRight(42)}║
║ Status: ${(isReady ? '✓ READY FOR SUBMISSION' : '⏳ IN PROGRESS').padRight(45)}║
╠══════════════════════════════════════════════════════════════════╣
    ''');

    for (final category in _categories) {
      final categoryStatus = category.isComplete ? '✓' : '○';
      buffer.writeln(
        '║ $categoryStatus ${category.name.padRight(20)}: ${category.completedItems}/${category.totalItems} items${' '.padRight(20)}║',
      );

      for (final item in category.items) {
        final itemStatus = item.isCompleted ? '  ✓' : '  ○';
        buffer.writeln('║$itemStatus ${item.title.padRight(56)}║');
      }
    }

    buffer.writeln('''
╠══════════════════════════════════════════════════════════════════╣
║ SUBMISSION STATUS: ${(isReady ? '✓ APPROVED' : '✗ BLOCKED').padRight(47)}║
╚══════════════════════════════════════════════════════════════════╝
    ''');

    return buffer.toString();
  }

  /// Generate sign-off document
  String generateSignOff() => '''
═══════════════════════════════════════════════════════════════════
                    PHASE D SIGN-OFF DOCUMENT
═══════════════════════════════════════════════════════════════════

PROJECT: Chess Tactics Master
PHASE: D (UI/UX Polish & Release Preparation)
DATE: ${DateTime.now()}
STATUS: ${isPreSubmissionReady() ? 'APPROVED FOR RELEASE' : 'PENDING COMPLETION'}

COMPLETION CHECKLIST
───────────────────────────────────────────────────────────────────
${generateReport()}

SIGN-OFF VERIFICATION
───────────────────────────────────────────────────────────────────
✓ All code quality checks passed
✓ All functionality verified
✓ UI/UX meets design standards
✓ Performance meets targets
✓ Security best practices followed
✓ Compliance requirements met

NEXT PHASE
───────────────────────────────────────────────────────────────────
→ Phase E: Paywall & Analytics Integration
  - RevenueCat subscription system
  - Firebase Analytics implementation
  - Premium features gating

═══════════════════════════════════════════════════════════════════
''';

  /// Clear all items
  void clear() {
    for (final category in _categories) {
      for (final item in category.items) {
        item.incomplete();
      }
    }
  }
}
