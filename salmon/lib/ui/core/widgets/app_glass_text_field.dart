import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

class AppGlassTextField extends StatelessWidget {
  const AppGlassTextField({
    super.key,
    required this.focusNode,
    required this.placeholder,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autocorrect = true,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
  });

  final FocusNode focusNode;
  final String placeholder;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool autocorrect;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(fontFamily: 'Noto Sans KR');
    return TextFieldTapRegion(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: () {
          final editable = focusNode.context
              ?.findAncestorStateOfType<EditableTextState>();
          if (editable != null) {
            editable.requestKeyboard();
          } else {
            focusNode.requestFocus();
          }
        },
        child: GlassTextField(
          controller: controller,
          focusNode: focusNode,
          placeholder: placeholder,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          autocorrect: autocorrect,
          obscureText: obscureText,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          height: 52,
          textStyle: textStyle,
          placeholderStyle: textStyle,
          surfaceStyle: GlassSurfaceStyle.glass,
          useOwnLayer: true,
          settings: const LiquidGlassSettings(
            bodyMode: GlassBodyMode.clear,
            glassColor: Color(0xB3E1E7EF),
          ),
          shape: const LiquidRoundedRectangle(
            borderRadius: 12,
            side: BorderSide(color: Color(0xFFA9ABB0)),
          ),
        ),
      ),
    );
  }
}
