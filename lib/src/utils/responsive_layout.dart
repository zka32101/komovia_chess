import 'package:flutter/material.dart';

/// Responsive design breakpoints for Chess Tactics Master
class ResponsiveBreakpoints {
  // Private constructor to prevent instantiation
  ResponsiveBreakpoints._();

  // Breakpoint thresholds (in logical pixels)
  static const double mobile = 0;
  static const double tablet = 600;
  static const double desktop = 1200;

  /// Check if screen size is mobile
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < tablet;

  /// Check if screen size is tablet
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= tablet && width < desktop;
  }

  /// Check if screen size is desktop
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktop;

  /// Get current screen size category
  static ScreenSize getScreenSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width < tablet) {
      return ScreenSize.mobile;
    } else if (width < desktop) {
      return ScreenSize.tablet;
    } else {
      return ScreenSize.desktop;
    }
  }

  /// Get responsive padding based on screen size
  static EdgeInsets getResponsivePadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.all(16);
    } else if (isTablet(context)) {
      return const EdgeInsets.all(24);
    } else {
      return const EdgeInsets.all(32);
    }
  }

  /// Get responsive font size
  static double getResponsiveFontSize(
    BuildContext context, {
    required double mobileSize,
    double? tabletSize,
    double? desktopSize,
  }) {
    if (isMobile(context)) {
      return mobileSize;
    } else if (isTablet(context)) {
      return tabletSize ?? mobileSize * 1.1;
    } else {
      return desktopSize ?? mobileSize * 1.2;
    }
  }

  /// Get responsive width
  static double getResponsiveWidth(
    BuildContext context, {
    required double mobileWidth,
    double? tabletWidth,
    double? desktopWidth,
  }) {
    if (isMobile(context)) {
      return mobileWidth;
    } else if (isTablet(context)) {
      return tabletWidth ?? mobileWidth * 1.2;
    } else {
      return desktopWidth ?? mobileWidth * 1.5;
    }
  }
}

/// Screen size categories
enum ScreenSize {
  mobile,
  tablet,
  desktop,
}

/// Responsive layout widget that switches layouts based on screen size
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    required this.mobileLayout,
    this.tabletLayout,
    this.desktopLayout,
    Key? key,
  }) : super(key: key);
  final Widget mobileLayout;
  final Widget? tabletLayout;
  final Widget? desktopLayout;

  @override
  Widget build(BuildContext context) {
    if (ResponsiveBreakpoints.isDesktop(context)) {
      return desktopLayout ?? tabletLayout ?? mobileLayout;
    } else if (ResponsiveBreakpoints.isTablet(context)) {
      return tabletLayout ?? mobileLayout;
    } else {
      return mobileLayout;
    }
  }
}

/// Responsive grid widget that adjusts column count based on screen size
class ResponsiveGridView extends StatelessWidget {
  const ResponsiveGridView({
    required this.children,
    this.mobileColumns = 2,
    this.tabletColumns,
    this.desktopColumns,
    this.spacing = 8.0,
    this.runSpacing = 8.0,
    Key? key,
  }) : super(key: key);
  final List<Widget> children;
  final int mobileColumns;
  final int? tabletColumns;
  final int? desktopColumns;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    int columns;

    if (ResponsiveBreakpoints.isDesktop(context)) {
      columns = desktopColumns ?? (tabletColumns ?? 4);
    } else if (ResponsiveBreakpoints.isTablet(context)) {
      columns = tabletColumns ?? 3;
    } else {
      columns = mobileColumns;
    }

    return GridView.count(
      crossAxisCount: columns,
      crossAxisSpacing: spacing,
      mainAxisSpacing: runSpacing,
      children: children,
    );
  }
}

/// Responsive container that adapts width and padding
class ResponsiveContainer extends StatelessWidget {
  const ResponsiveContainer({
    required this.child,
    this.maxWidth,
    this.padding,
    this.color,
    this.borderRadius,
    Key? key,
  }) : super(key: key);
  final Widget child;
  final double? maxWidth;
  final EdgeInsets? padding;
  final Color? color;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final responsivePadding =
        padding ?? ResponsiveBreakpoints.getResponsivePadding(context);

    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? _getMaxWidth(context),
        ),
        color: color,
        padding: responsivePadding,
        child: child,
      ),
    );
  }

  double _getMaxWidth(BuildContext context) {
    if (ResponsiveBreakpoints.isDesktop(context)) {
      return 1200;
    } else if (ResponsiveBreakpoints.isTablet(context)) {
      return 800;
    } else {
      return 600;
    }
  }
}

/// Responsive text widget with size scaling
class ResponsiveText extends StatelessWidget {
  const ResponsiveText(
    this.text, {
    this.style,
    this.mobileSize,
    this.tabletSize,
    this.desktopSize,
    this.textAlign,
    this.maxLines,
    this.overflow,
    Key? key,
  }) : super(key: key);
  final String text;
  final TextStyle? style;
  final double? mobileSize;
  final double? tabletSize;
  final double? desktopSize;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final baseSize = mobileSize ?? 14;
    final responsiveSize = ResponsiveBreakpoints.getResponsiveFontSize(
      context,
      mobileSize: baseSize,
      tabletSize: tabletSize,
      desktopSize: desktopSize,
    );

    final responsiveStyle = (style ?? const TextStyle()).copyWith(
      fontSize: responsiveSize,
    );

    return Text(
      text,
      style: responsiveStyle,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// Responsive column with adaptive spacing
class ResponsiveColumn extends StatelessWidget {
  const ResponsiveColumn({
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.max,
    Key? key,
  }) : super(key: key);
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;

  @override
  Widget build(BuildContext context) {
    final spacing = ResponsiveBreakpoints.isMobile(context) ? 8.0 : 16.0;

    return Column(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: _addSpacing(children, spacing),
    );
  }

  List<Widget> _addSpacing(List<Widget> children, double spacing) {
    if (children.isEmpty) return children;

    final result = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      result.add(children[i]);
      if (i < children.length - 1) {
        result.add(SizedBox(height: spacing));
      }
    }
    return result;
  }
}

/// Responsive row with adaptive spacing
class ResponsiveRow extends StatelessWidget {
  const ResponsiveRow({
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.max,
    Key? key,
  }) : super(key: key);
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;

  @override
  Widget build(BuildContext context) {
    final spacing = ResponsiveBreakpoints.isMobile(context) ? 8.0 : 16.0;

    return Row(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: _addSpacing(children, spacing),
    );
  }

  List<Widget> _addSpacing(List<Widget> children, double spacing) {
    if (children.isEmpty) return children;

    final result = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      result.add(children[i]);
      if (i < children.length - 1) {
        result.add(SizedBox(width: spacing));
      }
    }
    return result;
  }
}
