import 'package:flutter/material.dart';

class AppMessageDialog extends StatelessWidget {
  const AppMessageDialog({
    super.key,
    required this.title,
    required this.message,
    required this.actionLabel,
    this.cancelLabel,
  });

  final String title;
  final String message;
  final String actionLabel;
  final String? cancelLabel;

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFFD9553E);
    const muted = Color(0xFF71777D);
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF292D32),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(color: muted, fontSize: 15, height: 2.5),
              ),
              const SizedBox(height: 20),
              Row(
                spacing: 12,
                children: [
                  if (cancelLabel case final label?)
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          foregroundColor: muted,
                          side: const BorderSide(color: Color(0xFFECEDEF)),
                        ),
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(label),
                      ),
                    ),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        backgroundColor: brand,
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: brand),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(actionLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
