import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SplashAnimadoView extends StatefulWidget {
  final WidgetBuilder destinoBuilder;
  final bool vistaPrevia;

  const SplashAnimadoView({
    super.key,
    required this.destinoBuilder,
    this.vistaPrevia = false,
  });

  @override
  State<SplashAnimadoView> createState() => _SplashAnimadoViewState();
}

class _SplashAnimadoViewState extends State<SplashAnimadoView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Timer? _watchdogTimer;
  bool _navegado = false;
  bool _precacheDone = false;

  static const Color fondoOscuro = Color(0xFF0F1B2A);
  static const Color azulCielo = Color(0xFF52ABEB);
  static const Color verdeTurquesa = Color(0xFF63D0A1);
  static const Color grisEslogan = Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navegarFinal();
      }
    });

    // Watchdog de 4 segundos
    _watchdogTimer = Timer(const Duration(seconds: 4), () {
      _navegarFinal();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_precacheDone) {
      _precacheDone = true;
      precacheImage(const AssetImage('assets/imagenes/icono_app.png'), context)
          .catchError((_) {});

      if (MediaQuery.of(context).disableAnimations) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navegarFinal();
        });
      } else if (!_controller.isAnimating && !_navegado) {
        _controller.forward();
      }
    }
  }

  void _navegarFinal() {
    if (_navegado) return;
    _navegado = true;

    _watchdogTimer?.cancel();
    if (_controller.isAnimating) {
      _controller.stop();
    }

    if (!mounted) return;

    if (widget.vistaPrevia) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              widget.destinoBuilder(context),
          transitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _watchdogTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final logoWidth = screenSize.width * 0.55;

    return GestureDetector(
      onTap: _navegarFinal,
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: fondoOscuro,
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final double val = _controller.value;

            // Fade out final: 88% - 100%
            final double opacityGlobal = 1.0 -
                const Interval(0.88, 1.0, curve: Curves.easeIn).transform(val);

            // Logo Entrada: 0% - 35%
            final double logoOpacity =
                const Interval(0.0, 0.35, curve: Curves.easeOut).transform(val);
            final double logoScale = 0.8 +
                0.2 *
                    const Interval(0.0, 0.35, curve: Curves.easeOutBack)
                        .transform(val);
            final double logoTranslateY = (1.0 -
                    const Interval(0.0, 0.35, curve: Curves.easeOut)
                        .transform(val)) *
                (screenSize.height * 0.08);

            // Flotado Senoidal Logo: 35% - 100%
            double floatY = 0.0;
            double floatRotation = 0.0;
            if (val >= 0.35) {
              final double floatProgress = (val - 0.35) / 0.65;
              floatY = math.sin(floatProgress * 2 * math.pi * 2) * 4.0;
              floatRotation =
                  math.sin(floatProgress * 2 * math.pi * 2) * 0.02618;
            }

            // Destello (Shimmer): 40% - 70%
            final double shimmerProgress =
                const Interval(0.40, 0.70, curve: Curves.linear).transform(val);

            // Texto "KANBLY" y Eslogan: 55% - 85%
            final double textOpacity =
                const Interval(0.55, 0.85, curve: Curves.easeOut).transform(val);
            final double textTranslateY = (1.0 -
                    const Interval(0.55, 0.85, curve: Curves.easeOut)
                        .transform(val)) *
                20.0;

            return Opacity(
              opacity: opacityGlobal.clamp(0.0, 1.0),
              child: Stack(
                children: [
                  // Resplandor Radial Detrás del Logo
                  Center(
                    child: Container(
                      width: logoWidth * 1.4,
                      height: logoWidth * 1.4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            azulCielo.withValues(alpha: 0.15),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Contenido Principal Centrado
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // LOGO ANIMADO
                        Transform.translate(
                          offset: Offset(0, logoTranslateY + floatY),
                          child: Transform.rotate(
                            angle: floatRotation,
                            child: Transform.scale(
                              scale: logoScale,
                              child: Opacity(
                                opacity: logoOpacity.clamp(0.0, 1.0),
                                child: RepaintBoundary(
                                  child: ShaderMask(
                                    blendMode: BlendMode.srcATop,
                                    shaderCallback: (bounds) {
                                      if (shimmerProgress <= 0.0 ||
                                          shimmerProgress >= 1.0) {
                                        return const LinearGradient(
                                          colors: [
                                            Colors.white,
                                            Colors.white
                                          ],
                                        ).createShader(bounds);
                                      }
                                      final double shift =
                                          -1.0 + shimmerProgress * 3.0;
                                      return LinearGradient(
                                        begin: Alignment(shift - 0.5, -0.5),
                                        end: Alignment(shift + 0.5, 0.5),
                                        colors: const [
                                          Colors.white,
                                          Color(0xFFE2F3FF),
                                          Colors.white,
                                        ],
                                        stops: const [0.0, 0.5, 1.0],
                                      ).createShader(bounds);
                                    },
                                    child: Image.asset(
                                      'assets/imagenes/icono_app.png',
                                      width: logoWidth,
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return const Icon(
                                          Icons.view_kanban,
                                          size: 100,
                                          color: azulCielo,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // TEXTO "KANBLY" Y ESLOGAN
                        Transform.translate(
                          offset: Offset(0, textTranslateY),
                          child: Opacity(
                            opacity: textOpacity.clamp(0.0, 1.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ShaderMask(
                                  shaderCallback: (bounds) {
                                    return const LinearGradient(
                                      colors: [azulCielo, verdeTurquesa],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ).createShader(bounds);
                                  },
                                  child: const Text(
                                    'KANBLY',
                                    style: TextStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 4,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Fluye y avanza',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                    color: grisEslogan,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
