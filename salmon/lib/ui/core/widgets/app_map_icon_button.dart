import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

const appMapGlassOutline = BorderSide(color: Color(0x4054697E));

final appMapGlassSettings = LiquidGlassSettings.ios27Light.copyWith(
  glassColor: const Color(0xBFFFFFFF),
  lightIntensity: 0.65,
  rimShade: 1.7,
  rimShadeEnds: 0.45,
);

class AppMapIconButton extends StatelessWidget {
  const AppMapIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size = 48,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final double size;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: const ShapeDecoration(
            shape: CircleBorder(side: appMapGlassOutline),
          ),
          child: GlassIconButton(
            icon: Icon(icon, color: iconColor),
            quality: GlassQuality.minimal,
            size: size,
            semanticLabel: label,
            onPressed: onPressed,
            surfaceStyle: GlassSurfaceStyle.glass,
            style: GlassButtonStyle.filled,
            settings: appMapGlassSettings,
          ),
        ),
      ),
    );
  }
}
