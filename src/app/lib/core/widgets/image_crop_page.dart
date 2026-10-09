import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Recadrage d'une photo dans un cadre au format donné (carte étudiante :
/// 1,586). On déplace et on zoome la photo sous le cadre ; la zone visible
/// dans le cadre est enregistrée en PNG.
class ImageCropPage extends StatefulWidget {
  const ImageCropPage({
    required this.bytes,
    this.aspectRatio = 1.586,
    this.title = 'Recadrer',
    super.key,
  });

  final Uint8List bytes;
  final double aspectRatio;
  final String title;

  /// Renvoie l'image recadrée (PNG), ou `null` si l'élève annule.
  static Future<Uint8List?> open(
    BuildContext context, {
    required Uint8List bytes,
    double aspectRatio = 1.586,
    String title = 'Recadrer',
  }) {
    return Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) =>
            ImageCropPage(bytes: bytes, aspectRatio: aspectRatio, title: title),
      ),
    );
  }

  @override
  State<ImageCropPage> createState() => _ImageCropPageState();
}

class _ImageCropPageState extends State<ImageCropPage> {
  /// Largeur maximale de l'image enregistrée : nette, sans fichier énorme.
  static const _maxOutputWidth = 1600.0;

  final _transform = TransformationController();
  ui.Image? _image;
  Object? _error;
  bool _saving = false;

  // Géométrie du dernier affichage, pour convertir le cadre en pixels.
  Rect _frame = Rect.zero;
  double _baseScale = 1;
  Size? _laidOutFor;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void dispose() {
    _transform.dispose();
    _image?.dispose();
    super.dispose();
  }

  Future<void> _decode() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() => _image = frame.image);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  /// Photo prise de travers : on la tourne d'un quart de tour.
  Future<void> _rotate() async {
    final image = _image;
    if (image == null) return;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..translate(image.height.toDouble(), 0)
      ..rotate(math.pi / 2);
    canvas.drawImage(image, Offset.zero, Paint());
    final rotated = await recorder.endRecording().toImage(
      image.height,
      image.width,
    );
    if (!mounted) return;
    setState(() {
      _image = rotated;
      _laidOutFor = null;
    });
    image.dispose();
  }

  Future<void> _save() async {
    final image = _image;
    if (image == null || _frame.isEmpty) return;
    setState(() => _saving = true);

    // Le cadre, ramené dans le repère de la photo affichée puis en pixels.
    final inverse = Matrix4.inverted(_transform.value);
    final inChild = MatrixUtils.transformRect(inverse, _frame);
    final source =
        Rect.fromLTRB(
          inChild.left / _baseScale,
          inChild.top / _baseScale,
          inChild.right / _baseScale,
          inChild.bottom / _baseScale,
        ).intersect(
          Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
        );

    final width = math.min(_maxOutputWidth, source.width).roundToDouble();
    final height = (width / widget.aspectRatio).roundToDouble();
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(
      image,
      source,
      Rect.fromLTWH(0, 0, width, height),
      Paint()..filterQuality = FilterQuality.high,
    );
    final cropped = await recorder.endRecording().toImage(
      width.toInt(),
      height.toInt(),
    );
    final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
    cropped.dispose();
    if (!mounted) return;
    Navigator.pop(context, data?.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title),
        titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        actions: [
          IconButton(
            tooltip: 'Pivoter',
            onPressed: image == null || _saving ? null : _rotate,
            icon: const Icon(Icons.rotate_90_degrees_cw_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: image == null
                  ? Center(
                      child: _error == null
                          ? const CircularProgressIndicator()
                          : const Text(
                              'Impossible de lire cette photo.',
                              style: TextStyle(color: Colors.white),
                            ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) =>
                          _buildEditor(image, constraints.biggest),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                children: [
                  const Text(
                    'Déplace et zoome la photo pour cadrer la carte.',
                    style: TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const ValueKey('crop-save-button'),
                      onPressed: image == null || _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.crop),
                      label: const Text('Valider le cadrage'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor(ui.Image image, Size area) {
    const margin = 20.0;
    var frameWidth = area.width - margin * 2;
    var frameHeight = frameWidth / widget.aspectRatio;
    if (frameHeight > area.height - margin * 2) {
      frameHeight = area.height - margin * 2;
      frameWidth = frameHeight * widget.aspectRatio;
    }
    final frame = Rect.fromCenter(
      center: area.center(Offset.zero),
      width: frameWidth,
      height: frameHeight,
    );

    // À l'échelle 1, la photo couvre exactement le cadre (comme « cover »).
    final baseScale = math.max(
      frameWidth / image.width,
      frameHeight / image.height,
    );
    final childSize = Size(image.width * baseScale, image.height * baseScale);

    _frame = frame;
    _baseScale = baseScale;
    if (_laidOutFor != area) {
      _laidOutFor = area;
      _transform.value = Matrix4.identity()
        ..translateByDouble(
          frame.center.dx - childSize.width / 2,
          frame.center.dy - childSize.height / 2,
          0,
          1,
        );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: InteractiveViewer(
            transformationController: _transform,
            constrained: false,
            minScale: 1,
            maxScale: 6,
            // Le cadre ne peut jamais sortir de la photo.
            boundaryMargin: EdgeInsets.fromLTRB(
              frame.left,
              frame.top,
              area.width - frame.right,
              area.height - frame.bottom,
            ),
            child: SizedBox.fromSize(
              size: childSize,
              child: RawImage(image: image, fit: BoxFit.fill),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _FramePainter(frame)),
          ),
        ),
      ],
    );
  }
}

/// Assombrit tout sauf le cadre, et dessine son contour.
class _FramePainter extends CustomPainter {
  const _FramePainter(this.frame);

  final Rect frame;

  @override
  void paint(Canvas canvas, Size size) {
    final rounded = RRect.fromRectAndRadius(frame, const Radius.circular(14));
    canvas
      ..drawPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect(Offset.zero & size),
          Path()..addRRect(rounded),
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.6),
      )
      ..drawRRect(
        rounded,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
  }

  @override
  bool shouldRepaint(_FramePainter oldDelegate) => oldDelegate.frame != frame;
}
