import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'auth/login_page.dart';
import 'package:google_fonts/google_fonts.dart';

class StartPage extends StatefulWidget {
  const StartPage({super.key});

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> with TickerProviderStateMixin {
  static const Color _accent = Color(0xFFEC3C24);

  late final AnimationController _meshCtrl;
  late final AnimationController _entranceCtrl;

  @override
  void initState() {
    super.initState();

   
    _meshCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
  }

  @override
  void dispose() {
    _meshCtrl.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final w = size.width;

    final logoSize = math.min(180.0, w * 0.42);
    final titleSize = math.min(52.0, w * 0.12);
    final subtitleSize = math.min(20.0, w * 0.052);

    return Scaffold(
      
backgroundColor: const Color(0xFFFFFFFF),
      body: Stack(
        children: [
        
          

          
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _meshCtrl,
              builder: (_, __) => CustomPaint(
                painter: _RotatingMeshPainter(
                  progress: _meshCtrl.value,
                  color: _accent,
                  screenSize: size,
                ),
              ),
            ),
          ),

          // ── المحتوى ──
          Center(
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: _entranceCtrl,
                curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // اللوقو الأصلي
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, -0.12),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: _entranceCtrl,
                      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
                    )),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/Logo_Spark.png',
                        fit: BoxFit.cover,
                        width: logoSize,
                        height: logoSize,
                        errorBuilder: (_, __, ___) =>
                            const SizedBox.shrink(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    'SPARK',
                     style: GoogleFonts.bebasNeue(
    fontSize: titleSize,
    color: const Color(0xFF1A1A1A),
    letterSpacing: 4.0,
    height: 1.1,
  ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'Where esports meets intelligence.',
                   textAlign: TextAlign.center,
  style: GoogleFonts.manrope(
    fontSize: subtitleSize,
    color: const Color(0xFF1A1A1A).withOpacity(0.75),
    height: 1.5,
    letterSpacing: 0.3,
    fontWeight: FontWeight.w400,
  ),
                  ),

                  const SizedBox(height: 50),

                  _SparklePillButtonWhiteStars(
  label: 'START',
  accent: Colors.white,        // لون الكتابة أبيض
  base: const Color(0xFFEC3C24),
  starsColor: const Color(0xFFEC3C24),
  width: 220,
  height: 54,
  borderRadius: 60,
  
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _RotatingMeshPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Size screenSize;

  const _RotatingMeshPainter({
    required this.progress,
    required this.color,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * math.pi * 2;
    final w = size.width;
    final h = size.height;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const lineCount = 32;       
    const crossLineCount = 18;   
    const pointsPerLine = 140;

    // ── الخطوط الأفقية الموجية ──
    for (int i = 0; i < lineCount; i++) {
      final ratio = i / (lineCount - 1);
      final phaseShift = ratio * math.pi * 2.2;
      final path = Path();

      for (int p = 0; p <= pointsPerLine; p++) {
        final xRatio = p / pointsPerLine;
        final x = -w * 0.05 + xRatio * w * 1.1;

        // موجات أعمق — ضاعفنا المعاملات
        final y1 = math.sin(xRatio * math.pi * 1.4 + t * 0.4 + phaseShift) * h * 0.20;
        final y2 = math.sin(xRatio * math.pi * 2.8 + t * 0.25 + phaseShift * 1.6) * h * 0.10;
        final y3 = math.cos(xRatio * math.pi * 0.9 + t * 0.15 + phaseShift * 0.8) * h * 0.13;
        final y4 = math.sin(xRatio * math.pi * 4.2 + t * 0.35 + phaseShift * 2.1) * h * 0.045;

        final centerPull = math.sin(ratio * math.pi) * h * 0.04;
        final baseY = h * 0.05 + ratio * h * 0.90 - centerPull;
        final y = baseY + y1 + y2 + y3 + y4;

        if (p == 0) path.moveTo(x, y); else path.lineTo(x, y);
      }

      final midFade = math.sin(ratio * math.pi);
      final alpha = (midFade * 0.55 + 0.12).clamp(0.0, 0.65);
      paint
        ..strokeWidth = 0.9
        ..color = color.withOpacity(alpha);
      canvas.drawPath(path, paint);
    }

    // ── الخطوط المتقاطعة المائلة ──
    for (int j = 0; j < crossLineCount; j++) {
      final ratio = j / (crossLineCount - 1);
      final phaseShift = ratio * math.pi * 1.7 + math.pi * 0.5;
      final path = Path();

      for (int p = 0; p <= pointsPerLine; p++) {
        final yRatio = p / pointsPerLine;
        // تمشي من أعلى لأسفل بميل
        final x = w * (ratio * 1.2 - 0.1) +
            math.sin(yRatio * math.pi * 1.8 + t * 0.3 + phaseShift) * w * 0.18 +
            math.cos(yRatio * math.pi * 3.1 + t * 0.2 + phaseShift * 1.4) * w * 0.08;
        final y = -h * 0.05 + yRatio * h * 1.1;

        if (p == 0) path.moveTo(x, y); else path.lineTo(x, y);
      }

      final alpha = (math.sin(ratio * math.pi) * 0.30 + 0.06).clamp(0.0, 0.35);
      paint
        ..strokeWidth = 0.65
        ..color = color.withOpacity(alpha);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_RotatingMeshPainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// زر START
// ─────────────────────────────────────────────────────────────────────────────

class _SparklePillButtonWhiteStars extends StatefulWidget {
  final String label;
  final Color accent;
  final Color base;
  final VoidCallback? onPressed;
  final bool loading;
  final Color starsColor;
  final double width;
  final double height;
  final double borderRadius;

  const _SparklePillButtonWhiteStars({
    required this.label,
    required this.accent,
    required this.base,
    required this.onPressed,
    required this.starsColor,
    this.loading = false,
    this.width = 176,
    this.height = 40,
    this.borderRadius = 46,
  });

  @override
  State<_SparklePillButtonWhiteStars> createState() =>
      _SparklePillButtonWhiteStarsState();
}

class _SparklePillButtonWhiteStarsState
    extends State<_SparklePillButtonWhiteStars>
    with SingleTickerProviderStateMixin {
  bool _hover = false;

  late final AnimationController _sparkCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 20),
  );

  @override
  void dispose() {
    _sparkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    final bg = _hover ? const Color(0xFFD42E1A) : widget.base; // أحمر أغمق عند الهوفر
    final fg = widget.accent;
    final borderColor =
        _hover ? const Color(0xFFE0E0E0) : Colors.transparent;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        setState(() => _hover = true);
        if (enabled) _sparkCtrl.forward(from: 0);
      },
      onExit: (_) {
        setState(() => _hover = false);
        _sparkCtrl.reverse();
      },
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(widget.borderRadius),
                border: Border.all(color: borderColor, width: 1.5),
                boxShadow: _hover
                    ? [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))]
                    : [],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  onTap: widget.onPressed,
                  child: Center(
                    child: widget.loading
                        ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
                        : Text(widget.label, style: GoogleFonts.bebasNeue(color: fg, fontSize: 22, letterSpacing: 3.0, height: 1)),
                  ),
                ),
              ),
            ),
            _SparkBurst(controller: _sparkCtrl, visible: _hover && enabled, color: widget.starsColor),
          ],
        ),
      ),
    );
  }
}

class _SparkBurst extends StatelessWidget {
  final AnimationController controller;
  final bool visible;
  final Color color;

  const _SparkBurst({required this.controller, required this.visible, required this.color});

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    final fade = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      reverseCurve: const Interval(0.0, 0.35, curve: Curves.easeIn),
    );

    Widget spark({double? left, double? right, double? top, double? bottom, required double size, required double delay, required double driftX, required double driftY, required double spinTurns, required bool softer}) {
      final pop = CurvedAnimation(parent: controller, curve: Interval(delay, math.min(1.0, delay + 0.55), curve: Curves.elasticOut));
      final move = CurvedAnimation(parent: controller, curve: Interval(delay, math.min(1.0, delay + 0.85), curve: Curves.easeOutCubic));
      return Positioned(
        left: left, right: right, top: top, bottom: bottom,
        child: FadeTransition(
          opacity: fade,
          child: AnimatedBuilder(
            animation: controller,
            builder: (_, __) => Transform.translate(
              offset: Offset(driftX * move.value, driftY * move.value),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.2, end: 1.0).animate(pop),
                child: RotationTransition(
                  turns: Tween<double>(begin: -spinTurns, end: 0.0).animate(pop),
                  child: _SparklePlus(size: size, color: color, softer: softer),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return IgnorePointer(
      child: Stack(clipBehavior: Clip.none, children: [
        spark(left: -10, top: -12, size: 14, delay: 0.00, driftX: -6, driftY: -6, spinTurns: 0.06, softer: false),
        spark(right: -10, top: -10, size: 12, delay: 0.06, driftX: 6, driftY: -5, spinTurns: 0.05, softer: false),
        spark(left: 26, top: -16, size: 10, delay: 0.10, driftX: 0, driftY: -6, spinTurns: 0.04, softer: true),
        spark(left: -12, bottom: -12, size: 12, delay: 0.14, driftX: -6, driftY: 6, spinTurns: 0.05, softer: true),
        spark(right: -12, bottom: -12, size: 14, delay: 0.18, driftX: 7, driftY: 6, spinTurns: 0.06, softer: true),
        spark(right: 34, bottom: -18, size: 10, delay: 0.22, driftX: 2, driftY: 7, spinTurns: 0.04, softer: true),
      ]),
    );
  }
}

class _SparklePlus extends StatelessWidget {
  final double size;
  final Color color;
  final bool softer;
  const _SparklePlus({required this.size, required this.color, required this.softer});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _SparklePlusPainter(color: color, softer: softer)),
      );
}

class _SparklePlusPainter extends CustomPainter {
  final Color color;
  final bool softer;
  const _SparklePlusPainter({required this.color, required this.softer});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2;
    canvas.drawCircle(c, r * 0.78,
        Paint()
          ..color = color.withOpacity(softer ? 0.45 : 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final angle = (-math.pi / 2) + (i * (math.pi / 4));
      final radius = (i % 2 == 0) ? r * 0.95 : r * 0.35;
      final p = Offset(c.dx + radius * math.cos(angle), c.dy + radius * math.sin(angle));
      if (i == 0) path.moveTo(p.dx, p.dy); else path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant _SparklePlusPainter old) =>
      old.color != color || old.softer != softer;
}
