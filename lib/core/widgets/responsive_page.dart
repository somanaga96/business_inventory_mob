import 'package:flutter/material.dart';

class ResponsivePage extends StatelessWidget {
  const ResponsivePage({
    super.key,
    required this.children,
    this.horizontalPaddingFactor = .05,
    this.bottomPaddingFactor = .12,
  });

  final List<Widget> children;
  final double horizontalPaddingFactor;
  final double bottomPaddingFactor;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        size.width * horizontalPaddingFactor,
        size.height * .03,
        size.width * horizontalPaddingFactor,
        size.height * bottomPaddingFactor,
      ),
      children: children,
    );
  }
}
