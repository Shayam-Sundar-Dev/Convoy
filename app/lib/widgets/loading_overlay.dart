import 'package:flutter/material.dart';

/// Wraps [child] in a [Stack] and, when [isLoading] is true, overlays a
/// semi-transparent [ModalBarrier] + centred [CircularProgressIndicator] that
/// absorbs all pointer events so the user cannot interact with anything
/// underneath until the operation completes.
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading) ...[
          // Absorbs all taps so nothing underneath can be interacted with.
          const ModalBarrier(dismissible: false, color: Colors.transparent),
          const Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xCC0E1115),
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

