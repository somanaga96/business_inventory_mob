import 'package:flutter/material.dart';

class ResponsivePage extends StatelessWidget {
  const ResponsivePage({
    super.key,
    required this.children,
    this.horizontalPaddingFactor = .05,
  });

  final List<Widget> children;
  final double horizontalPaddingFactor;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        size.width * horizontalPaddingFactor,
        size.height * .03,
        size.width * horizontalPaddingFactor,
        size.height * .12,
      ),
      children: children,
    );
  }
}
