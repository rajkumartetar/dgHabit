import 'package:flutter/material.dart';

class SheetHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onClose;
  final List<Widget>? actions;
  const SheetHeader({super.key, required this.title, this.onClose, this.actions});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (actions != null) ...actions!,
          if (onClose != null)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Close',
              onPressed: onClose,
            ),
        ],
      ),
    );
  }
}
