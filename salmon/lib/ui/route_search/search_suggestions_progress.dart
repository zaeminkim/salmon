import 'package:flutter/widgets.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

class SearchSuggestionsProgress extends StatelessWidget {
  const SearchSuggestionsProgress({super.key, required this.semanticLabel});

  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    const trackHeight = 6.0;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(trackHeight / 2),
        child: GlassProgressIndicator.linear(
          height: trackHeight,
          color: const Color(0xFFD9553E),
          backgroundColor: const Color(0x3371777D),
          semanticLabel: semanticLabel,
        ),
      ),
    );
  }
}
