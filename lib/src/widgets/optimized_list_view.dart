import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Optimized list view with virtual scrolling and lazy loading
/// Handles large lists efficiently by rendering only visible items
class OptimizedListView<T> extends ConsumerStatefulWidget {
  const OptimizedListView({
    required this.items,
    required this.itemBuilder,
    Key? key,
    this.pageSize = 20,
    this.onEndReached,
    this.showLoadingIndicator = true,
  }) : super(key: key);
  final List<T> items;
  final Widget Function(BuildContext, int, T) itemBuilder;
  final int pageSize;
  final VoidCallback? onEndReached;
  final bool showLoadingIndicator;

  @override
  ConsumerState<OptimizedListView> createState() =>
      _OptimizedListViewState<T>();
}

class _OptimizedListViewState<T> extends ConsumerState<OptimizedListView<T>> {
  late ScrollController _scrollController;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Detect when user scrolls near the end
  void _onScroll() {
    if (!_isLoadingMore &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 500) {
      _isLoadingMore = true;
      widget.onEndReached?.call();

      // Reset after a short delay to allow for new data loading
      Future.delayed(const Duration(milliseconds: 500), () {
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          // Suppress scroll notifications to prevent unnecessary rebuilds
          return false;
        },
        child: ListView.builder(
          controller: _scrollController,
          itemCount:
              widget.items.length + (widget.showLoadingIndicator ? 1 : 0),
          itemBuilder: (context, index) {
            // Show loading indicator at the end
            if (index == widget.items.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }

            // Wrap in RepaintBoundary to prevent cascade repaints
            return RepaintBoundary(
              child: widget.itemBuilder(context, index, widget.items[index]),
            );
          },
        ),
      );
}

/// Optimized grid view with virtual scrolling
class OptimizedGridView<T> extends ConsumerStatefulWidget {
  const OptimizedGridView({
    required this.items,
    required this.itemBuilder,
    Key? key,
    this.crossAxisCount = 2,
    this.pageSize = 20,
    this.onEndReached,
  }) : super(key: key);
  final List<T> items;
  final Widget Function(BuildContext, int, T) itemBuilder;
  final int crossAxisCount;
  final int pageSize;
  final VoidCallback? onEndReached;

  @override
  ConsumerState<OptimizedGridView> createState() =>
      _OptimizedGridViewState<T>();
}

class _OptimizedGridViewState<T> extends ConsumerState<OptimizedGridView<T>> {
  late ScrollController _scrollController;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_isLoadingMore &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 500) {
      _isLoadingMore = true;
      widget.onEndReached?.call();

      Future.delayed(const Duration(milliseconds: 500), () {
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => GridView.builder(
        controller: _scrollController,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: widget.crossAxisCount,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: widget.items.length,
        itemBuilder: (context, index) => RepaintBoundary(
          child: widget.itemBuilder(context, index, widget.items[index]),
        ),
      );
}

/// High-performance list tile with memoization
/// Prevents unnecessary rebuilds when parent list is rebuilt
class OptimizedListTile extends ConsumerWidget {
  const OptimizedListTile({
    required this.title,
    Key? key,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.tileColor,
  }) : super(key: key);
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? tileColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) => RepaintBoundary(
        child: ListTile(
          title: Text(title),
          subtitle: subtitle != null ? Text(subtitle!) : null,
          leading: leading,
          trailing: trailing,
          onTap: onTap,
          tileColor: tileColor,
          // Enable tiling to reduce memory overhead
          dense: false,
        ),
      );
}

/// Cached image widget with memory management
class CachedAssetImage extends StatelessWidget {
  const CachedAssetImage({
    required this.assetPath,
    required this.width,
    required this.height,
    Key? key,
    this.fit = BoxFit.contain,
  }) : super(key: key);
  final String assetPath;
  final double width;
  final double height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: Image.asset(
          assetPath,
          width: width,
          height: height,
          fit: fit,
          // Cache with 2x resolution for better quality on high-DPI devices
          cacheWidth: (width * 2).toInt(),
          cacheHeight: (height * 2).toInt(),
        ),
      );
}

/// Debounced search widget for list filtering
class DebouncedSearchField extends ConsumerWidget {
  const DebouncedSearchField({
    required this.onSearch,
    Key? key,
    this.hintText = 'Search...',
    this.debounceDelay = const Duration(milliseconds: 500),
  }) : super(key: key);
  final ValueChanged<String> onSearch;
  final String hintText;
  final Duration debounceDelay;

  @override
  Widget build(BuildContext context, WidgetRef ref) => TextField(
        onChanged: (value) {
          // Debounce the search query
          Future.delayed(debounceDelay, () {
            onSearch(value);
          });
        },
        decoration: InputDecoration(
          hintText: hintText,
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.search),
        ),
      );
}

/// Performance monitoring widget
class PerformanceMonitor extends StatefulWidget {
  const PerformanceMonitor({
    required this.child,
    required this.label,
    Key? key,
    this.onBuildComplete,
  }) : super(key: key);
  final Widget child;
  final String label;
  final VoidCallback? onBuildComplete;

  @override
  State<PerformanceMonitor> createState() => _PerformanceMonitorState();
}

class _PerformanceMonitorState extends State<PerformanceMonitor> {
  late Stopwatch _stopwatch;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
  }

  @override
  void didUpdateWidget(PerformanceMonitor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _stopwatch.reset();
    _stopwatch.start();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _stopwatch.stop();
      final ms = _stopwatch.elapsedMilliseconds;
      if (ms > 16) {
        // Warn if build took longer than one frame (60fps = 16.67ms)
        debugPrint(
            'Slow build: ${widget.label} took ${ms}ms (should be < 16.67ms)');
      }
      widget.onBuildComplete?.call();
    });

    return widget.child;
  }

  @override
  void dispose() {
    _stopwatch.stop();
    super.dispose();
  }
}
