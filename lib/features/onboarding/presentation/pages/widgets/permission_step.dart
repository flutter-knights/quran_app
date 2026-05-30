import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/typography_styles.dart';

/// Steps 4 & 5 — a permission rationale: icon, title, and a "why" paragraph
/// shown before the OS prompt. Purely presentational; the Enable / Not-now
/// actions live in the wizard's shared bottom chrome.
class PermissionStep extends StatelessWidget {
  const PermissionStep({
    super.key,
    required this.icon,
    required this.title,
    required this.why,
  });

  final List<List<dynamic>> icon;
  final String title;
  final String why;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: HugeIcon(icon: icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TS.bold20.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            why,
            textAlign: TextAlign.center,
            style: TS.regular14.copyWith(
              color: Colors.white.withValues(alpha: 0.75),
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}
