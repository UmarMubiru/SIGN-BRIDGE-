import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// Responsive, shared visual layout for authentication screens.
///
/// Keeps form widgets supplied by login/register screens intact while giving
/// both screens one consistent SignBridge brand treatment.
class AuthPageLayout extends StatelessWidget {
  final String title;
  final String highlight;
  final String subtitle;
  final Widget form;

  const AuthPageLayout({
    super.key,
    required this.title,
    required this.highlight,
    required this.subtitle,
    required this.form,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: _AuthBackdropPainter()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 980;
                if (isWide) {
                  return Row(
                    children: [
                      Expanded(
                        flex: 11,
                        child: Center(child: _BrandPanel(isWide: true)),
                      ),
                      Expanded(
                        flex: 9,
                        child: Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 24,
                            ),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 640),
                              child: _FormPanel(
                                title: title,
                                highlight: highlight,
                                subtitle: subtitle,
                                form: form,
                                isWide: true,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 30),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        children: [
                          const _BrandPanel(isWide: false),
                          const SizedBox(height: 22),
                          _FormPanel(
                            title: title,
                            highlight: highlight,
                            subtitle: subtitle,
                            form: form,
                            isWide: false,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  final bool isWide;

  const _BrandPanel({required this.isWide});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isWide ? 36 : 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/signbridge_logo.png',
              width: isWide ? 600 : 260,
              height: isWide ? 350 : 152,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                width: isWide ? 240 : 104,
                height: isWide ? 240 : 104,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.gold, AppTheme.supportingCyan],
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(
                  Icons.sign_language_rounded,
                  size: 92,
                  color: AppTheme.primaryBackground,
                ),
              ),
            ),
            Text(
              'Different Hands  •  Same Voice',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.ivory,
                fontSize: isWide ? 25 : 16,
                letterSpacing: isWide ? 1.2 : 0.4,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isWide) ...[
              const SizedBox(height: 42),
              const Row(
                children: [
                  Expanded(
                    child: _BrandFeature(
                      icon: Icons.back_hand_outlined,
                      label: 'Learn\nSign Language',
                    ),
                  ),
                  _FeatureDivider(),
                  Expanded(
                    child: _BrandFeature(
                      icon: Icons.groups_outlined,
                      label: 'Build a More\nInclusive Community',
                      accent: AppTheme.gold,
                    ),
                  ),
                  _FeatureDivider(),
                  Expanded(
                    child: _BrandFeature(
                      icon: Icons.graphic_eq_rounded,
                      label: 'Communication\nWithout Barriers',
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BrandFeature extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;

  const _BrandFeature({
    required this.icon,
    required this.label,
    this.accent = AppTheme.supportingCyan,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Icon(icon, color: accent, size: 36),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.ivory,
              height: 1.3,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureDivider extends StatelessWidget {
  const _FeatureDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 86,
      color: AppTheme.outline.withValues(alpha: 0.65),
    );
  }
}

class _FormPanel extends StatelessWidget {
  final String title;
  final String highlight;
  final String subtitle;
  final Widget form;
  final bool isWide;

  const _FormPanel({
    required this.title,
    required this.highlight,
    required this.subtitle,
    required this.form,
    required this.isWide,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isWide ? 52 : 24),
      decoration: BoxDecoration(
        color: AppTheme.secondarySurface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(isWide ? 30 : 24),
        border: Border.all(color: AppTheme.outline, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.supportingCyan.withValues(alpha: 0.08),
            blurRadius: 36,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '$title '),
                TextSpan(
                  text: highlight,
                  style: const TextStyle(color: AppTheme.supportingCyan),
                ),
              ],
            ),
            style: TextStyle(
              color: AppTheme.ivory,
              fontSize: isWide ? 38 : 30,
              height: 1.15,
              letterSpacing: -0.8,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: TextStyle(
              color: AppTheme.ivory.withValues(alpha: 0.9),
              fontSize: isWide ? 17 : 15,
              height: 1.45,
            ),
          ),
          SizedBox(height: isWide ? 34 : 26),
          form,
        ],
      ),
    );
  }
}

class _AuthBackdropPainter extends CustomPainter {
  const _AuthBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF003F9B),
          Color(0xFF00184D),
          AppTheme.primaryBackground,
        ],
        stops: [0, 0.24, 0.68],
      ).createShader(bounds);
    canvas.drawRect(bounds, background);

    final dots = Paint()
      ..color = AppTheme.supportingCyan.withValues(alpha: 0.72);
    for (var row = 0; row < 5; row++) {
      for (var column = 0; column < 6; column++) {
        canvas.drawCircle(Offset(26 + column * 19, 28 + row * 19), 2.3, dots);
      }
    }

    final topWave = Path()
      ..moveTo(0, size.height * 0.28)
      ..cubicTo(
        size.width * 0.12,
        size.height * 0.1,
        size.width * 0.24,
        size.height * 0.07,
        size.width * 0.38,
        0,
      )
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(
      topWave,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF007BFF), Color(0xFF00347F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds),
    );

    final lowerBlueWave = Path()
      ..moveTo(0, size.height * 0.78)
      ..cubicTo(
        size.width * 0.18,
        size.height * 0.92,
        size.width * 0.3,
        size.height * 0.76,
        size.width * 0.48,
        size.height * 0.87,
      )
      ..cubicTo(
        size.width * 0.68,
        size.height * 0.98,
        size.width * 0.78,
        size.height * 0.81,
        size.width,
        size.height * 0.96,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      lowerBlueWave,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF0047B5), Color(0xFF007CF5), Color(0xFF003980)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds),
    );

    final cyanRibbon = Path()
      ..moveTo(0, size.height * 0.83)
      ..cubicTo(
        size.width * 0.22,
        size.height * 0.99,
        size.width * 0.36,
        size.height * 0.82,
        size.width * 0.53,
        size.height * 0.94,
      )
      ..cubicTo(
        size.width * 0.69,
        size.height * 1.04,
        size.width * 0.84,
        size.height * 0.86,
        size.width,
        size.height * 0.99,
      )
      ..lineTo(size.width, size.height * 0.975)
      ..cubicTo(
        size.width * 0.83,
        size.height * 0.84,
        size.width * 0.7,
        size.height * 1.02,
        size.width * 0.52,
        size.height * 0.92,
      )
      ..cubicTo(
        size.width * 0.35,
        size.height * 0.8,
        size.width * 0.2,
        size.height * 0.97,
        0,
        size.height * 0.81,
      )
      ..close();
    canvas.drawPath(
      cyanRibbon,
      Paint()
        ..shader = const LinearGradient(
          colors: [AppTheme.gold, AppTheme.supportingCyan],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(bounds),
    );

    final goldCorner = Path()
      ..moveTo(size.width * 0.92, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.12)
      ..quadraticBezierTo(
        size.width * 0.96,
        size.height * 0.07,
        size.width * 0.92,
        0,
      )
      ..close();
    canvas.drawPath(
      goldCorner,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFD000), AppTheme.gold],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
