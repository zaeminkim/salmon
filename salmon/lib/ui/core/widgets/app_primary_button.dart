import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

const _brand = Color(0xFFD9553E);

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GlassButton.custom(
      label: label,
      height: 52,
      surfaceStyle: GlassSurfaceStyle.solid,
      enabled: enabled,
      color: enabled ? _brand : _brand.withAlpha(225),
      shape: const LiquidRoundedRectangle(borderRadius: 24),
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
