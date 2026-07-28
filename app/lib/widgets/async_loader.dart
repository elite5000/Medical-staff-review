import 'package:flutter/material.dart';

import 'error_banner.dart';

/// Loading/error/data plumbing shared by every list and detail screen: runs [load], shows a
/// spinner while pending and an [ErrorBanner] + retry button on failure, otherwise hands the
/// resolved value to [builder] along with a `reload` callback for after mutations (create/
/// edit/delete) so the caller doesn't have to wire up its own FutureBuilder each time.
class AsyncLoader<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, VoidCallback reload)
  builder;

  const AsyncLoader({super.key, required this.load, required this.builder});

  @override
  State<AsyncLoader<T>> createState() => _AsyncLoaderState<T>();
}

class _AsyncLoaderState<T> extends State<AsyncLoader<T>> {
  late Future<T> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  void reload() {
    // A block body (not `=> setState(() => _future = widget.load())`) matters here: an
    // arrow-bodied closure's value is the assignment expression's result — the Future
    // itself — which trips Flutter's "setState callback returned a Future" assertion.
    setState(() {
      _future = widget.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ErrorBanner(message: snapshot.error.toString()),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: reload, child: const Text('Retry')),
              ],
            ),
          );
        }
        return widget.builder(context, snapshot.data as T, reload);
      },
    );
  }
}
