import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

const _glassOutline = BorderSide(color: Color(0x4054697E));

class ChipButton extends StatelessWidget {
  const ChipButton({
    super.key,
    required this.settings,
    required this.label,
    required this.onTap,
    this.selected=false,
    this.icon,
  });

  final LiquidGlassSettings settings;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: const ShapeDecoration(
        shape: StadiumBorder(side: _glassOutline),
      ),

      child: GlassChip(
        label: icon == null ? label : '',
        semanticLabel: label,
        icon: icon == null ? null : Icon(icon),
        spacing: icon == null ? 6 : 0,
        selected: selected,
        selectedColor: Colors.transparent,
        surfaceStyle: GlassSurfaceStyle.glass,
        quality: GlassQuality.minimal,
        settings: selected
            ? settings.copyWith(glassColor: const Color(0xC6D9553E))
            : settings,
        onTap: onTap,
      ),
    );
  }
}