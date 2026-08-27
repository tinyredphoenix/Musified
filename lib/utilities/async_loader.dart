import 'package:flutter/cupertino.dart';
import 'package:musified/extensions/l10n.dart';
import 'package:musified/main.dart';
import 'package:musified/widgets/spinner.dart';

Widget _defaultAsyncLoaderErrorBuilder(
  BuildContext context,
  Object? error,
  StackTrace? stack,
) {
  return Center(child: Text('${context.l10n.error}!'));
}

class AsyncLoader<T> extends StatelessWidget {
  const AsyncLoader({
    super.key,
    required this.future,
    required this.builder,
    this.emptyWidget = const SizedBox.shrink(),
    this.loadingWidget = const Center(child: Spinner()),
    this.errorBuilder = _defaultAsyncLoaderErrorBuilder,
  });

  final Future<T> future;
  final Widget Function(BuildContext, T) builder;
  final Widget emptyWidget;
  final Widget loadingWidget;
  final Widget Function(BuildContext, Object?, StackTrace?)? errorBuilder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return loadingWidget;
        }

        if (snapshot.hasError) {
          logger.log(
            'AsyncLoader error',
            error: snapshot.error,
            stackTrace: snapshot.stackTrace,
          );
          return errorBuilder!(context, snapshot.error, snapshot.stackTrace);
        }

        final data = snapshot.data;
        if (data == null) return emptyWidget;

        if (data is Iterable && data.isEmpty) {
          return emptyWidget;
        }

        return builder(context, data);
      },
    );
  }
}
