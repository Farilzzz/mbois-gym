import 'package:flutter/material.dart';

/// Data model representing a captured digital signature.
class DedicatedSignatureResult {
  final List<List<Offset>> strokes;
  final List<Offset?> points;
  final DateTime timestamp;

  DedicatedSignatureResult({
    required List<List<Offset>> strokes,
    List<Offset?>? points,
    DateTime? timestamp,
  }) : strokes = List.unmodifiable(
         strokes.map((s) => List<Offset>.unmodifiable(s)),
       ),
       points = List.unmodifiable(points ?? strokesToPoints(strokes)),
       timestamp = timestamp ?? DateTime.now();

  int get totalPoints =>
      strokes.fold<int>(0, (sum, stroke) => sum + stroke.length);

  bool get isValid => totalPoints >= 8;

  /// Helper to convert segmented strokes to a flat list with null delimiters.
  static List<Offset?> strokesToPoints(List<List<Offset>> strokes) {
    final list = <Offset?>[];
    for (final stroke in strokes) {
      list.addAll(stroke);
      list.add(null);
    }
    return list;
  }

  /// Helper to reconstruct segmented strokes from a flat list with null delimiters.
  static List<List<Offset>> pointsToStrokes(List<Offset?> points) {
    final list = <List<Offset>>[];
    List<Offset> current = [];
    for (final p in points) {
      if (p == null) {
        if (current.isNotEmpty) {
          list.add(List.unmodifiable(current));
          current = [];
        }
      } else {
        current.add(p);
      }
    }
    if (current.isNotEmpty) {
      list.add(List.unmodifiable(current));
    }
    return list;
  }
}

/// Fullscreen adaptive modal dialog dedicated to capturing digital signatures.
///
/// Features:
/// - Screen isolation: protected against scroll collisions and back-gesture accidental dismissals.
/// - SafeArea and PopScope(canPop: false).
/// - Large canvas with light background (#F8F9FA) and dark ink (#1E232A).
/// - Baseline guide.
/// - Raw pointer event handling for seamless multi-stroke support without auto-clear on finger lift.
/// - Action buttons: Hapus, Batal, Simpan (with min 8 points validation).
class DedicatedSignatureDialog extends StatefulWidget {
  const DedicatedSignatureDialog({
    super.key,
    this.title = 'Tanda Tangan Digital',
    this.signerLabel,
    this.instruction = 'Silakan tanda tangan pada kotak berikut',
    this.initialStrokes,
    this.initialPoints,
    this.minPoints = 8,
    this.backgroundColor = const Color(0xFFF8F9FA),
    this.penColor = const Color(0xFF1E232A),
    this.strokeWidth = 3.0,
    this.onSaved,
  });

  final String title;
  final String? signerLabel;
  final String instruction;
  final List<List<Offset>>? initialStrokes;
  final List<Offset?>? initialPoints;
  final int minPoints;
  final Color backgroundColor;
  final Color penColor;
  final double strokeWidth;
  final ValueChanged<DedicatedSignatureResult>? onSaved;

  /// Convenience static method to show the signature dialog.
  static Future<DedicatedSignatureResult?> show(
    BuildContext context, {
    String title = 'Tanda Tangan Digital',
    String? signerLabel,
    String instruction = 'Silakan tanda tangan pada kotak berikut',
    List<List<Offset>>? initialStrokes,
    List<Offset?>? initialPoints,
    int minPoints = 8,
  }) {
    return showDialog<DedicatedSignatureResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DedicatedSignatureDialog(
        title: title,
        signerLabel: signerLabel,
        instruction: instruction,
        initialStrokes: initialStrokes,
        initialPoints: initialPoints,
        minPoints: minPoints,
      ),
    );
  }

  @override
  State<DedicatedSignatureDialog> createState() =>
      _DedicatedSignatureDialogState();
}

class _DedicatedSignatureDialogState extends State<DedicatedSignatureDialog> {
  final List<List<Offset>> _strokes = [];
  final List<Offset?> _allPoints = [];
  List<Offset>? _currentStroke;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialStrokes != null && widget.initialStrokes!.isNotEmpty) {
      for (final s in widget.initialStrokes!) {
        _strokes.add(List.of(s));
      }
      _allPoints.addAll(DedicatedSignatureResult.strokesToPoints(_strokes));
    } else if (widget.initialPoints != null &&
        widget.initialPoints!.isNotEmpty) {
      final converted = DedicatedSignatureResult.pointsToStrokes(
        widget.initialPoints!,
      );
      for (final s in converted) {
        _strokes.add(List.of(s));
      }
      _allPoints.addAll(widget.initialPoints!);
    }
  }

  int get _totalPoints =>
      _strokes.fold<int>(0, (sum, stroke) => sum + stroke.length);

  void _onPointerDown(PointerDownEvent event) {
    setState(() {
      _errorMessage = null;
      _currentStroke = [event.localPosition];
      _strokes.add(_currentStroke!);
      _allPoints.add(event.localPosition);
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    setState(() {
      if (_currentStroke == null) {
        _currentStroke = [event.localPosition];
        _strokes.add(_currentStroke!);
      } else {
        _currentStroke!.add(event.localPosition);
      }
      _allPoints.add(event.localPosition);
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    setState(() {
      _currentStroke = null;
      if (_allPoints.isNotEmpty && _allPoints.last != null) {
        _allPoints.add(null);
      }
    });
  }

  void _onPointerCancel(PointerCancelEvent event) {
    setState(() {
      _currentStroke = null;
      if (_allPoints.isNotEmpty && _allPoints.last != null) {
        _allPoints.add(null);
      }
    });
  }

  void _clearCanvas() {
    setState(() {
      _strokes.clear();
      _allPoints.clear();
      _currentStroke = null;
      _errorMessage = null;
    });
  }

  void _onCancel() {
    Navigator.of(context).pop(null);
  }

  void _onSave() {
    if (_totalPoints < widget.minPoints) {
      setState(() {
        _errorMessage =
            'Tanda tangan minimal ${widget.minPoints} titik (saat ini $_totalPoints titik)';
      });
      return;
    }

    final result = DedicatedSignatureResult(
      strokes: _strokes,
      points: _allPoints,
      timestamp: DateTime.now(),
    );

    widget.onSaved?.call(result);
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strokeCount = _strokes.length;

    return PopScope(
      canPop: false,
      child: Dialog.fullscreen(
        backgroundColor: theme.scaffoldBackgroundColor,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (widget.signerLabel != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.signerLabel!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _onCancel,
                      tooltip: 'Tutup',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Instruction text & strokes counter
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        widget.instruction,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '$strokeCount goresan',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Inline validation error message
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 16,
                          color: Colors.red.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Canvas Container
              Expanded(
                child: Container(
                  key: const Key('signature_canvas'),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: widget.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _errorMessage != null
                          ? Colors.red.shade400
                          : Colors.grey.shade400,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Listener(
                            behavior: HitTestBehavior.opaque,
                            onPointerDown: _onPointerDown,
                            onPointerMove: _onPointerMove,
                            onPointerUp: _onPointerUp,
                            onPointerCancel: _onPointerCancel,
                            child: CustomPaint(
                              painter: _DedicatedSignaturePainter(
                                strokes: _strokes,
                                penColor: widget.penColor,
                                strokeWidth: widget.strokeWidth,
                              ),
                            ),
                          ),
                        ),
                        if (_strokes.isEmpty)
                          Center(
                            child: IgnorePointer(
                              child: Text(
                                'Goreskan tanda tangan di sini',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // Action buttons bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _clearCanvas,
                      icon: const Icon(Icons.clear, size: 16),
                      label: const Text('Hapus'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _onCancel,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Batal'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _onSave,
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Simpan'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DedicatedSignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color penColor;
  final double strokeWidth;

  _DedicatedSignaturePainter({
    required this.strokes,
    required this.penColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Baseline guide
    final linePaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.35)
      ..strokeWidth = 1.0;
    final baselineY = size.height - 36;
    canvas.drawLine(
      Offset(24, baselineY),
      Offset(size.width - 24, baselineY),
      linePaint,
    );

    // Baseline marker '✕'
    final textPainter = TextPainter(
      text: TextSpan(
        text: '✕',
        style: TextStyle(
          color: Colors.grey.withValues(alpha: 0.4),
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(24, baselineY - textPainter.height));

    // User strokes
    final strokePaint = Paint()
      ..color = penColor
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = penColor
      ..style = PaintingStyle.fill;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, strokeWidth / 2, dotPaint);
      } else {
        final path = Path();
        path.moveTo(stroke[0].dx, stroke[0].dy);
        for (int i = 1; i < stroke.length; i++) {
          path.lineTo(stroke[i].dx, stroke[i].dy);
        }
        canvas.drawPath(path, strokePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DedicatedSignaturePainter oldDelegate) => true;
}

/// Adaptive widget displaying the saved signature preview, 'Terverifikasi' status,
/// timestamp, and 'Ubah Tanda Tangan' action button.
class SignaturePreviewCard extends StatelessWidget {
  const SignaturePreviewCard({
    super.key,
    this.signature,
    this.points,
    this.strokes,
    this.timestamp,
    this.signerLabel = 'Tanda Tangan',
    this.onEdit,
    this.height = 130,
    this.backgroundColor = const Color(0xFFF8F9FA),
    this.penColor = const Color(0xFF1E232A),
  });

  final DedicatedSignatureResult? signature;
  final List<Offset?>? points;
  final List<List<Offset>>? strokes;
  final DateTime? timestamp;
  final String signerLabel;
  final VoidCallback? onEdit;
  final double height;
  final Color backgroundColor;
  final Color penColor;

  List<List<Offset>> get _effectiveStrokes {
    if (signature != null && signature!.strokes.isNotEmpty) {
      return signature!.strokes;
    }
    if (strokes != null && strokes!.isNotEmpty) {
      return strokes!;
    }
    if (points != null && points!.isNotEmpty) {
      return DedicatedSignatureResult.pointsToStrokes(points!);
    }
    return const [];
  }

  DateTime? get _effectiveTimestamp => signature?.timestamp ?? timestamp;

  bool get _hasSignature =>
      _effectiveStrokes.isNotEmpty || (signature?.isValid ?? false);

  String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSig = _hasSignature;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasSig
              ? Colors.green.withValues(alpha: 0.5)
              : theme.dividerColor,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  signerLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (hasSig)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.green, width: 1),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 12, color: Colors.green),
                      SizedBox(width: 4),
                      Text(
                        'Terverifikasi',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.orange, width: 1),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit, size: 12, color: Colors.orange),
                      SizedBox(width: 4),
                      Text(
                        'Belum ditandatangani',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (hasSig && _effectiveTimestamp != null) ...[
            const SizedBox(height: 2),
            Text(
              'Waktu tanda tangan: ${_formatDate(_effectiveTimestamp!)}',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
          const SizedBox(height: 8),
          Container(
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: hasSig
                  ? CustomPaint(
                      painter: _DedicatedSignaturePainter(
                        strokes: _effectiveStrokes,
                        penColor: penColor,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Center(
                      child: Text(
                        'Belum ada tanda tangan',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ),
            ),
          ),
          if (onEdit != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit, size: 14),
                label: const Text(
                  'Ubah Tanda Tangan',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
