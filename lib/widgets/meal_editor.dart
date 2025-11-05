import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class MealEditor extends StatefulWidget {
  final String? existingUrl;
  final Uint8List? initialBytes;
  final ValueChanged<Uint8List?> onBytesChanged;
  final ValueChanged<bool> onRemoveChanged;
  final TextEditingController caloriesCtrl;
  final TextEditingController healthCtrl;

  const MealEditor({
    super.key,
    this.existingUrl,
    this.initialBytes,
    required this.onBytesChanged,
    required this.onRemoveChanged,
    required this.caloriesCtrl,
    required this.healthCtrl,
  });

  @override
  State<MealEditor> createState() => _MealEditorState();
}

class _MealEditorState extends State<MealEditor> {
  Uint8List? _bytes;
  bool _removeExisting = false;
  final _cropController = CropController();

  @override
  void initState() {
    super.initState();
    _bytes = widget.initialBytes;
  }

  Future<void> _pick(ImageSource source) async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: source, maxWidth: 2048, maxHeight: 2048);
    if (x == null) return;
    final data = await x.readAsBytes();
    setState(() {
      _bytes = data;
      _removeExisting = false;
    });
    widget.onRemoveChanged(false);
    widget.onBytesChanged(data);
  }

  Future<void> _crop() async {
    if (_bytes == null) return;
    await showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    const Text('Crop photo', style: TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.check),
                      onPressed: () => _cropController.crop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Crop(
                  controller: _cropController,
                  image: _bytes!,
                  onCropped: (result) {
                    Uint8List? cropped;
                    try {
                      // crop_your_image v2.x returns CropResult with a .bytes getter
                      cropped = (result as dynamic).bytes as Uint8List?;
                    } catch (_) {
                      // Older versions return Uint8List directly
                      try { cropped = result as Uint8List; } catch (_) {}
                    }
                    if (cropped == null) { Navigator.of(ctx).pop(); return; }
                    setState(() { _bytes = cropped; });
                    widget.onBytesChanged(cropped);
                    Navigator.of(ctx).pop();
                  },
                  withCircleUi: false,
                  baseColor: Theme.of(context).colorScheme.surface,
                  maskColor: Colors.black.withOpacity(0.5),
                  cornerDotBuilder: (size, edgeAlignment) => Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _remove() {
    setState(() {
      _bytes = null;
      _removeExisting = true;
    });
    widget.onBytesChanged(null);
    widget.onRemoveChanged(true);
  }

  @override
  Widget build(BuildContext context) {
    final imageWidget = _bytes != null
        ? Image.memory(_bytes!, fit: BoxFit.cover)
        : (widget.existingUrl != null && !_removeExisting)
            ? Image.network(widget.existingUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox())
            : const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Meal details', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 16 / 9,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageWidget is! SizedBox) imageWidget,
                  if (imageWidget is SizedBox)
                    Center(
                      child: Text('No photo', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Gallery'),
              onPressed: () => _pick(ImageSource.gallery),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Camera'),
              onPressed: () => _pick(ImageSource.camera),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.crop),
              label: const Text('Crop'),
              onPressed: _bytes == null ? null : _crop,
            ),
            TextButton.icon(
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove'),
              onPressed: (widget.existingUrl != null || _bytes != null) ? _remove : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: widget.caloriesCtrl,
          decoration: const InputDecoration(labelText: 'Calories (kcal, optional)'),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: widget.healthCtrl,
          decoration: const InputDecoration(labelText: 'Health score 0-100 (optional)'),
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }
}
