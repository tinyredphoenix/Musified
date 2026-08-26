import 'package:flutter/cupertino.dart';
import 'package:material_ui/material_ui.dart';

class Spinner extends StatelessWidget {
  const Spinner({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CupertinoActivityIndicator(
        color: Theme.of(context).colorScheme.primary,
        radius: 14,
      ),
    );
  }
}
