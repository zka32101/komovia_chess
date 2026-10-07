import 'package:flutter/material.dart';

/// Principal Variation (PV) Display Widget
///
/// Shows the best line of play found during engine search.
/// Updates in real-time as the search progresses.
class PrincipalVariationDisplay extends StatelessWidget {
  const PrincipalVariationDisplay({
    required this.principalVariation,
    required this.evaluation,
    required this.depth,
    Key? key,
    this.isBestLine = true,
    this.confidence = 0.8,
  }) : super(key: key);

  /// List of moves in the principal variation
  /// Example: ['e2e4', 'c7c5', 'd2d4', 'c5d4']
  final List<String> principalVariation;

  /// Evaluation score of the line
  final int evaluation;

  /// Depth at which this variation was found
  final int depth;

  /// Whether this is the current best line
  final bool isBestLine;

  /// Confidence score (0.0-1.0)
  /// Higher = more confident in this line
  final double confidence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (principalVariation.isEmpty) {
      return Center(
        child: Text(
          'No variation yet',
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey,
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(8),
      color: isBestLine ? Colors.blue[50] : Colors.grey[100],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isBestLine ? 'Best Line' : 'Alternative',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: isBestLine ? Colors.blue : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    // Depth indicator
                    Chip(
                      label: Text('D$depth'),
                      labelStyle: const TextStyle(fontSize: 11),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 8),
                    // Evaluation
                    Chip(
                      label: Text(
                        evaluation > 0 ? '+$evaluation' : '$evaluation',
                        style: TextStyle(
                          color: evaluation > 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      labelStyle: const TextStyle(fontSize: 11),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Confidence bar
            _buildConfidenceBar(context),

            const SizedBox(height: 12),

            // Variation moves
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...principalVariation.asMap().entries.map((entry) {
                  final index = entry.key;
                  final move = entry.value;
                  final moveNumber = (index ~/ 2) + 1;
                  final isWhiteMove = index % 2 == 0;

                  return Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isWhiteMove ? Colors.blue[300]! : Colors.grey,
                      ),
                      borderRadius: BorderRadius.circular(4),
                      color: isWhiteMove ? Colors.blue[50] : Colors.grey[100],
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isWhiteMove ? '$moveNumber.' : '',
                          style: theme.textTheme.labelSmall,
                        ),
                        Text(
                          move,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),

            const SizedBox(height: 12),

            // Move descriptions
            if (principalVariation.isNotEmpty)
              Text(
                'Line continues for ${principalVariation.length} moves',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.grey,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfidenceBar(BuildContext context) {
    final displayConfidence = (confidence * 100).toInt();
    final color = confidence > 0.8
        ? Colors.green
        : confidence > 0.5
            ? Colors.orange
            : Colors.red;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Confidence',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            Text(
              '$displayConfidence%',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: confidence,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

/// Multiple Principal Variations Display
///
/// Shows top variations found during search with comparison
class PrincipalVariationsPanel extends StatefulWidget {
  const PrincipalVariationsPanel({
    required this.variations,
    Key? key,
    this.showBestOnly = false,
    this.maxVariations = 5,
  }) : super(key: key);

  /// List of principal variations
  final List<PVLine> variations;

  /// Whether to show only best line
  final bool showBestOnly;

  /// Maximum variations to display
  final int maxVariations;

  @override
  State<PrincipalVariationsPanel> createState() =>
      _PrincipalVariationsPanelState();
}

class _PrincipalVariationsPanelState extends State<PrincipalVariationsPanel> {
  late int expandedIndex;

  @override
  void initState() {
    super.initState();
    expandedIndex = 0; // Best line expanded by default
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toShow = widget.showBestOnly
        ? widget.variations.take(1).toList()
        : widget.variations.take(widget.maxVariations).toList();

    if (toShow.isEmpty) {
      return Center(
        child: Text(
          'No variations analyzed yet',
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Top Variations (${toShow.length})',
            style: theme.textTheme.titleSmall,
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: toShow.length,
          itemBuilder: (context, index) {
            final variation = toShow[index];
            final isExpanded = expandedIndex == index;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Card(
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                  ),
                  child: ExpansionTile(
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Line ${index + 1}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: index == 0 ? Colors.blue : Colors.grey,
                          ),
                        ),
                        Chip(
                          label: Text(
                            variation.evaluation > 0
                                ? '+${variation.evaluation}'
                                : '${variation.evaluation}',
                          ),
                          labelStyle: TextStyle(
                            fontSize: 11,
                            color: variation.evaluation > 0
                                ? Colors.green
                                : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    onExpansionChanged: (expanded) {
                      if (expanded) {
                        setState(() {
                          expandedIndex = index;
                        });
                      }
                    },
                    initiallyExpanded: isExpanded,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Variation details
                            Text(
                              'Evaluation: ${variation.evaluation > 0 ? '+' : ''}${variation.evaluation}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Depth: ${variation.depth}',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),

                            // Moves
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                ...variation.moves.map((move) => Chip(
                                      label: Text(
                                        move,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    )),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Statistics
                            Text(
                              'Nodes: ${_formatNumber(variation.nodesSearched)}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}

/// Principal Variation Line data structure
class PVLine {
  PVLine({
    required this.moves,
    required this.evaluation,
    required this.depth,
    this.confidence = 0.8,
    this.nodesSearched = 0,
    this.timeMs = 0,
  });
  final List<String> moves;
  final int evaluation;
  final int depth;
  final double confidence;
  final int nodesSearched;
  final int timeMs;

  /// Create copy with modified fields
  PVLine copyWith({
    List<String>? moves,
    int? evaluation,
    int? depth,
    double? confidence,
    int? nodesSearched,
    int? timeMs,
  }) =>
      PVLine(
        moves: moves ?? this.moves,
        evaluation: evaluation ?? this.evaluation,
        depth: depth ?? this.depth,
        confidence: confidence ?? this.confidence,
        nodesSearched: nodesSearched ?? this.nodesSearched,
        timeMs: timeMs ?? this.timeMs,
      );
}
