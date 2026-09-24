import 'dart:math' as math;
import 'package:flutter/material.dart';

class BatteryRingWidget extends StatefulWidget {
  final int percentage;
  final bool isCharging;

  const BatteryRingWidget({
    super.key,
    required this.percentage,
    required this.isCharging,
  });

  @override
  State<BatteryRingWidget> createState() => _BatteryRingWidgetState();
}

class _BatteryRingWidgetState extends State<BatteryRingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chargeFraction = (widget.percentage.clamp(0, 100)) / 100.0;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulseScale = widget.isCharging
            ? 1.0 + (_pulseController.value * 0.03)
            : 1.0;

        return Transform.scale(
          scale: pulseScale,
          child: SizedBox(
            width: 260,
            height: 260,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Glowing outer blurred ring if charging
                if (widget.isCharging)
                  Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00E676)
                              .withOpacity(0.25 + (_pulseController.value * 0.2)),
                          blurRadius: 36,
                          spreadRadius: 6,
                        ),
                      ],
                    ),
                  ),

                // Ring Canvas
                CustomPaint(
                  size: const Size(260, 260),
                  painter: _BatteryPainter(
                    fraction: chargeFraction,
                    isCharging: widget.isCharging,
                    pulse: _pulseController.value,
                  ),
                ),

                // Center Info
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.isCharging)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bolt_rounded,
                            color: const Color(0xFF00E676),
                            size: 26,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'CHARGING',
                            style: TextStyle(
                              color: const Color(0xFF00E676),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        'DISCHARGING',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      '${widget.percentage}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 58,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.5,
                        fontFeatures: [],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.percentage >= 80 && widget.isCharging
                          ? '🎯 80% TARGET REACHED'
                          : 'Target: 80% Protection',
                      style: TextStyle(
                        color: widget.percentage >= 80 && widget.isCharging
                            ? const Color(0xFFFF5252)
                            : const Color(0xFF00E5FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BatteryPainter extends CustomPainter {
  final double fraction;
  final bool isCharging;
  final double pulse;

  _BatteryPainter({
    required this.fraction,
    required this.isCharging,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 28) / 2;
    const strokeWidth = 14.0;

    // Track Paint (background track)
    final trackPaint = Paint()
      ..color = const Color(0xFF1E2638)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Active progress arc
    final sweepAngle = 2 * math.pi * fraction;
    final startAngle = -math.pi / 2;

    final gradientColors = isCharging
        ? [
            const Color(0xFF00B0FF),
            const Color(0xFF00E676),
            const Color(0xFF69F0AE),
          ]
        : [
            const Color(0xFF3D5AFE),
            const Color(0xFF00E5FF),
          ];

    final progressPaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0.0,
        endAngle: 2 * math.pi,
        colors: gradientColors,
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );

    // 80% Marker notch
    const targetFraction = 0.80;
    final markerAngle = startAngle + (2 * math.pi * targetFraction);
    final markerX1 = center.dx + (radius - 12) * math.cos(markerAngle);
    final markerY1 = center.dy + (radius - 12) * math.sin(markerAngle);
    final markerX2 = center.dx + (radius + 12) * math.cos(markerAngle);
    final markerY2 = center.dy + (radius + 12) * math.sin(markerAngle);

    final markerPaint = Paint()
      ..color = const Color(0xFFFF5252)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    canvas.drawLine(Offset(markerX1, markerY1), Offset(markerX2, markerY2), markerPaint);
  }

  @override
  bool shouldRepaint(covariant _BatteryPainter oldDelegate) {
    return oldDelegate.fraction != fraction ||
        oldDelegate.isCharging != isCharging ||
        oldDelegate.pulse != pulse;
  }
}
