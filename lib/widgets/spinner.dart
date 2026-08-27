import 'package:flutter/cupertino.dart';

class Spinner extends StatelessWidget {
  const Spinner({super.key, this.radius = 14.0});
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CupertinoActivityIndicator(
        radius: radius,
      ),
    );
  }
}
