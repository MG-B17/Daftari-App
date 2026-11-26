import 'package:flutter/material.dart';

import 'daftari_loading.dart';

class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({super.key, this.color, this.semanticsLabel});

  final Color? color;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) =>
      DaftariLoading.inline(color: color, semanticsLabel: semanticsLabel);
}
