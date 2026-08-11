import 'package:flutter/material.dart';

/// Common scaffold for Studio tools: a titled screen with a blocking progress
/// overlay shown while an FFmpeg operation runs.
class ToolScaffold extends StatelessWidget {
  const ToolScaffold({
    super.key,
    required this.title,
    required this.busy,
    required this.child,
    this.busyLabel = 'Processing…',
    this.actions,
  });

  final String title;
  final bool busy;
  final Widget child;
  final String busyLabel;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: Stack(
        children: [
          AbsorbPointer(
            absorbing: busy,
            child: SafeArea(child: child),
          ),
          if (busy)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        busyLabel,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
