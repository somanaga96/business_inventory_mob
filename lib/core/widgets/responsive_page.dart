import 'package:flutter/material.dart';

class ResponsivePage extends StatelessWidget {
  const ResponsivePage({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        size.width * .05,
        size.height * .03,
        size.width * .05,
        size.height * .12,
      ),
      children: children,
    );
  }
}
