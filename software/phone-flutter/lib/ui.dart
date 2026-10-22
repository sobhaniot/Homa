import 'dart:ui';

import 'package:flutter/material.dart';

const mint = Color(0xff68ead4);

class Glass extends StatelessWidget {
  final Widget child;
  const Glass({super.key, required this.child});
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(26),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .055),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withValues(alpha: .13)),
        ),
        child: Material(type: MaterialType.transparency, child: child),
      ),
    ),
  );
}
