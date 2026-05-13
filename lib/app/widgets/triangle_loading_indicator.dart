import 'dart:math' as math;
import 'package:flutter/material.dart';

class TriangleLoadingIndicator extends StatefulWidget {
  const TriangleLoadingIndicator({
    super.key,
    this.size = 48,
    this.targetDeg = 60,
    this.trianglesPerCycle = 6,
    this.buildDuration = const Duration(milliseconds: 1300),
    this.zoomDuration = const Duration(milliseconds: 800),
    this.keepHistoryCycles = 2,
    this.strokeWidth = 2.2,
    this.strokeColor = const Color(0xFF111111),
    this.showFill = true,
    this.baseColor,
    this.baseHue = 26,
    this.saturation = 0.73,
    this.lightness = 0.52,
    this.hueStep = 7,
    this.maxDepth = 1500,
  });

  final double size;
  final double targetDeg;
  final int trianglesPerCycle;
  final Duration buildDuration;
  final Duration zoomDuration;
  final int keepHistoryCycles;
  final double strokeWidth;
  final Color strokeColor;
  final bool showFill;
  final Color? baseColor;
  final double baseHue;
  final double saturation;
  final double lightness;
  final double hueStep;
  final int maxDepth;

  @override
  State<TriangleLoadingIndicator> createState() =>
      _TriangleLoadingIndicatorState();
}

class _TriangleLoadingIndicatorState extends State<TriangleLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Stopwatch _clock;

  @override
  void initState() {
    super.initState();
    _clock = Stopwatch()..start();
    _controller = AnimationController.unbounded(vsync: this)
      ..repeat(min: 0, max: 1, period: const Duration(seconds: 1));
  }

  @override
  void dispose() {
    _clock.stop();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final tSec =
                _clock.elapsedMicroseconds / Duration.microsecondsPerSecond;
            return CustomPaint(
              painter: _TriangleLoadingPainter(
                tSec: tSec,
                targetDeg: widget.targetDeg,
                trianglesPerCycle: widget.trianglesPerCycle,
                buildSeconds:
                    widget.buildDuration.inMicroseconds /
                    Duration.microsecondsPerSecond,
                zoomSeconds:
                    widget.zoomDuration.inMicroseconds /
                    Duration.microsecondsPerSecond,
                keepHistoryCycles: widget.keepHistoryCycles,
                strokeWidth: widget.strokeWidth,
                strokeColor: widget.strokeColor,
                showFill: widget.showFill,
                baseColor:
                    widget.baseColor ?? Theme.of(context).colorScheme.primary,
                baseHue: widget.baseHue,
                saturation: widget.saturation,
                lightness: widget.lightness,
                hueStep: widget.hueStep,
                maxDepth: widget.maxDepth,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TriangleLoadingPainter extends CustomPainter {
  _TriangleLoadingPainter({
    required this.tSec,
    required this.targetDeg,
    required this.trianglesPerCycle,
    required this.buildSeconds,
    required this.zoomSeconds,
    required this.keepHistoryCycles,
    required this.strokeWidth,
    required this.strokeColor,
    required this.showFill,
    required this.baseColor,
    required this.baseHue,
    required this.saturation,
    required this.lightness,
    required this.hueStep,
    required this.maxDepth,
  });

  final double tSec;
  final double targetDeg;
  final int trianglesPerCycle;
  final double buildSeconds;
  final double zoomSeconds;
  final int keepHistoryCycles;
  final double strokeWidth;
  final Color strokeColor;
  final bool showFill;
  final Color? baseColor;
  final double baseHue;
  final double saturation;
  final double lightness;
  final double hueStep;
  final int maxDepth;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = side * 0.46;
    final stepDeg = targetDeg / trianglesPerCycle;

    final triangles = <List<Offset>>[
      _equilateral(center: center, radius: outerRadius),
    ];

    void ensureTriangles(int minCount) {
      while (triangles.length < minCount && triangles.length < maxDepth) {
        final solved = _solveInnerTriangle(triangles.last, stepDeg);
        if (solved == null || solved.scale >= 0.999999) break;
        triangles.add(solved.vertices);
      }
    }

    final nPerCycle = trianglesPerCycle;
    ensureTriangles(nPerCycle + 3);

    final cycleLen = buildSeconds + zoomSeconds;
    final cycleIndex = (tSec / cycleLen).floor();
    final local = tSec % cycleLen;
    final inBuild = local < buildSeconds;
    final p = inBuild
        ? (local / buildSeconds)
        : ((local - buildSeconds) / zoomSeconds);

    final neededDepth = (cycleIndex + 1) * nPerCycle + 3;
    ensureTriangles(neededDepth);
    final maxDepthIdx = triangles.length - 1;
    final baseDepth = math.min(cycleIndex * nPerCycle, maxDepthIdx);

    final startIdx = math.min(baseDepth, maxDepthIdx);
    final endIdx = math.min(baseDepth + nPerCycle, maxDepthIdx);
    final cameraStart = _affineFromTriangles(triangles[startIdx], triangles[0]);
    final cameraEnd = _affineFromTriangles(triangles[endIdx], triangles[0]);
    final camera = inBuild
        ? cameraStart
        : _mixAffine(cameraStart, cameraEnd, _easeInOut(p));

    final clipPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: outerRadius));
    canvas.save();
    canvas.clipPath(clipPath);

    final currentTopDepth = inBuild
        ? (baseDepth + p * nPerCycle)
        : (baseDepth + nPerCycle.toDouble());
    final fullTopDepth = math.min(maxDepthIdx, currentTopDepth.floor());
    final partialAlpha = currentTopDepth - currentTopDepth.floor();
    final historyStart = math.max(0, baseDepth - keepHistoryCycles * nPerCycle);

    for (var triIdx = historyStart; triIdx <= fullTopDepth; triIdx++) {
      _drawTriangle(
        canvas,
        triangles[triIdx]
            .map((pt) => _applyAffine(camera, pt))
            .toList(growable: false),
        _triColor(triIdx),
        1,
      );
    }

    final partialIdx = fullTopDepth + 1;
    if (partialIdx <= maxDepthIdx && partialAlpha > 1e-6) {
      _drawTriangle(
        canvas,
        triangles[partialIdx]
            .map((pt) => _applyAffine(camera, pt))
            .toList(growable: false),
        _triColor(partialIdx),
        partialAlpha,
      );
    }

    canvas.restore();

    final boundary = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = strokeColor;
    canvas.drawCircle(center, outerRadius, boundary);
  }

  List<Offset> _equilateral({
    required Offset center,
    required double radius,
    double rotationDeg = 0,
  }) {
    final points = <Offset>[];
    final rot = rotationDeg * math.pi / 180;
    for (var k = 0; k < 3; k++) {
      final a = rot + (-math.pi / 2) + (k * 2 * math.pi / 3);
      points.add(
        Offset(
          center.dx + radius * math.cos(a),
          center.dy + radius * math.sin(a),
        ),
      );
    }
    return points;
  }

  _SolveResult? _solveInnerTriangle(
    List<Offset> outerVertices,
    double thetaDeg,
  ) {
    final th = thetaDeg * math.pi / 180;
    final r00 = math.cos(th);
    final r01 = -math.sin(th);
    final r10 = math.sin(th);
    final r11 = math.cos(th);

    final a = List.generate(6, (_) => List<double>.filled(6, 0));
    final b = List<double>.filled(6, 0);

    for (var i = 0; i < 3; i++) {
      final vi = outerVertices[i];
      final vj = outerVertices[(i + 1) % 3];
      final edgeX = vj.dx - vi.dx;
      final edgeY = vj.dy - vi.dy;
      final rviX = r00 * vi.dx + r01 * vi.dy;
      final rviY = r10 * vi.dx + r11 * vi.dy;

      final rowX = 2 * i;
      final rowY = rowX + 1;

      a[rowX][0] = rviX;
      a[rowX][1] = 1;
      a[rowX][3 + i] = -edgeX;
      b[rowX] = vi.dx;

      a[rowY][0] = rviY;
      a[rowY][2] = 1;
      a[rowY][3 + i] = -edgeY;
      b[rowY] = vi.dy;
    }

    final x = _solveLinear6(a, b);
    if (x == null) return null;

    final scale = x[0];
    final tx = x[1];
    final ty = x[2];

    final w = outerVertices
        .map((p) {
          final rx = r00 * p.dx + r01 * p.dy;
          final ry = r10 * p.dx + r11 * p.dy;
          return Offset(scale * rx + tx, scale * ry + ty);
        })
        .toList(growable: false);

    return _SolveResult(vertices: w, scale: scale);
  }

  List<double>? _solveLinear6(List<List<double>> a, List<double> b) {
    const n = 6;
    final m = List.generate(n, (i) => [...a[i], b[i]]);

    for (var col = 0; col < n; col++) {
      var piv = col;
      for (var r = col + 1; r < n; r++) {
        if (m[r][col].abs() > m[piv][col].abs()) piv = r;
      }
      if (m[piv][col].abs() < 1e-12) return null;
      if (piv != col) {
        final tmp = m[col];
        m[col] = m[piv];
        m[piv] = tmp;
      }

      final pv = m[col][col];
      for (var j = col; j <= n; j++) {
        m[col][j] /= pv;
      }

      for (var r = 0; r < n; r++) {
        if (r == col) continue;
        final f = m[r][col];
        if (f == 0) continue;
        for (var j = col; j <= n; j++) {
          m[r][j] -= f * m[col][j];
        }
      }
    }

    return List.generate(n, (i) => m[i][n]);
  }

  _Affine _affineFromTriangles(List<Offset> src, List<Offset> dst) {
    final s0 = src[0], s1 = src[1], s2 = src[2];
    final d0 = dst[0], d1 = dst[1], d2 = dst[2];

    final a = <List<double>>[
      [s0.dx, s0.dy, 1.0, 0.0, 0.0, 0.0],
      [0.0, 0.0, 0.0, s0.dx, s0.dy, 1.0],
      [s1.dx, s1.dy, 1.0, 0.0, 0.0, 0.0],
      [0.0, 0.0, 0.0, s1.dx, s1.dy, 1.0],
      [s2.dx, s2.dy, 1.0, 0.0, 0.0, 0.0],
      [0.0, 0.0, 0.0, s2.dx, s2.dy, 1.0],
    ];
    final b = [d0.dx, d0.dy, d1.dx, d1.dy, d2.dx, d2.dy];

    final x = _solveLinear6(a, b);
    if (x == null) return const _Affine(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0);

    return _Affine(a: x[0], b: x[1], tx: x[2], c: x[3], d: x[4], ty: x[5]);
  }

  _Affine _mixAffine(_Affine a, _Affine b, double t) {
    return _Affine(
      a: a.a + (b.a - a.a) * t,
      b: a.b + (b.b - a.b) * t,
      c: a.c + (b.c - a.c) * t,
      d: a.d + (b.d - a.d) * t,
      tx: a.tx + (b.tx - a.tx) * t,
      ty: a.ty + (b.ty - a.ty) * t,
    );
  }

  Offset _applyAffine(_Affine t, Offset p) {
    return Offset(
      t.a * p.dx + t.b * p.dy + t.tx,
      t.c * p.dx + t.d * p.dy + t.ty,
    );
  }

  double _easeInOut(double t) {
    if (t < 0.5) return 4 * t * t * t;
    return 1 - math.pow(-2 * t + 2, 3) / 2;
  }

  Color _triColor(int index) {
    final seedHsl = baseColor != null ? HSLColor.fromColor(baseColor!) : null;
    final hue = ((seedHsl?.hue ?? baseHue) + index * hueStep) % 360;
    final hsl = HSLColor.fromAHSL(1, hue, saturation, lightness);
    return hsl.toColor();
  }

  void _drawTriangle(
    Canvas canvas,
    List<Offset> points,
    Color fill,
    double alpha,
  ) {
    final path = Path()
      ..moveTo(points[0].dx, points[0].dy)
      ..lineTo(points[1].dx, points[1].dy)
      ..lineTo(points[2].dx, points[2].dy)
      ..close();

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = fill.withValues(alpha: alpha);

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = strokeColor.withValues(alpha: alpha);

    if (showFill) {
      canvas.drawPath(path, fillPaint);
    }
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _TriangleLoadingPainter oldDelegate) => true;
}

class _SolveResult {
  const _SolveResult({required this.vertices, required this.scale});

  final List<Offset> vertices;
  final double scale;
}

class _Affine {
  const _Affine({
    required this.a,
    required this.b,
    required this.c,
    required this.d,
    required this.tx,
    required this.ty,
  });

  final double a;
  final double b;
  final double c;
  final double d;
  final double tx;
  final double ty;
}
