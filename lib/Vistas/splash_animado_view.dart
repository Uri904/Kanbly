import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Pantalla de inicio animada de Kanbly.
///
/// La abeja entra en vuelo desde abajo a la izquierda aleteando, se estabiliza
/// y flota mientras aparece el nombre de la app. Los colores siguen el tema
/// (claro u oscuro) de la aplicación.
class SplashAnimadoView extends StatefulWidget {
  /// Construye la pantalla a la que se navega cuando termina la animación.
  final WidgetBuilder destinoBuilder;

  /// En vista previa (desde Ajustes) se hace pop en lugar de reemplazar la ruta.
  final bool vistaPrevia;

  const SplashAnimadoView({
    super.key,
    required this.destinoBuilder,
    this.vistaPrevia = false,
  });

  static const Color fondoOscuro = Color(0xFF0F1B2A);
  static const Color fondoClaro = Color(0xFFF5F7FA);
  static const Color azulCielo = Color(0xFF52ABEB);
  static const Color verdeTurquesa = Color(0xFF63D0A1);
  static const Color esloganOscuro = Color(0xFF94A3B8);
  static const Color esloganClaro = Color(0xFF64748B);

  @override
  State<SplashAnimadoView> createState() => _SplashAnimadoViewState();
}

class _SplashAnimadoViewState extends State<SplashAnimadoView>
    with SingleTickerProviderStateMixin {
  static const Duration _duracion = Duration(milliseconds: 2400);
  static const double _duracionSeg = 2.4;

  /// Fracción de la animación en la que termina la entrada en vuelo.
  static const double _finVuelo = 0.40;

  static const String _rutaBase = 'assets/imagenes/abeja_base.png';
  static const String _rutaAlas = 'assets/imagenes/abeja_alas.png';
  static const String _rutaIcono = 'assets/imagenes/icono_app.png';

  /// Raíz de las alas dentro de la imagen cuadrada de 1024 px: (388, 372).
  static const Alignment _pivoteAlas = Alignment(-0.242, -0.273);

  late final AnimationController _controller;
  Timer? _watchdogTimer;
  bool _navegado = false;
  bool _precacheDone = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: _duracion);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navegarFinal();
      }
    });

    // Respaldo: si por cualquier motivo la animación no termina, se navega igual.
    _watchdogTimer = Timer(const Duration(seconds: 4), _navegarFinal);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precacheDone) return;
    _precacheDone = true;

    precacheImage(const AssetImage(_rutaBase), context).catchError((_) {});
    precacheImage(const AssetImage(_rutaAlas), context).catchError((_) {});

    if (MediaQuery.of(context).disableAnimations) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _navegarFinal());
    } else if (!_controller.isAnimating && !_navegado) {
      _controller.forward();
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

  /// Progreso (0 a 1) del tramo [ini, fin] de la animación, con una curva.
  double _tramo(double val, double ini, double fin,
      [Curve curva = Curves.linear]) {
    return Interval(ini, fin, curve: curva).transform(val);
  }

  /// Fase del aleteo: 5 aleteos por segundo en vuelo y 3 al quedarse flotando,
  /// sin saltos de fase en el cambio.
  double _faseAlas(double val) {
    const double frecuenciaVuelo = 5.0;
    const double frecuenciaFlote = 3.0;
    final double t = val * _duracionSeg;
    final double tCorte = _finVuelo * _duracionSeg;
    if (val <= _finVuelo) {
      return 2 * math.pi * frecuenciaVuelo * t;
    }
    return 2 *
        math.pi *
        (frecuenciaVuelo * tCorte + frecuenciaFlote * (t - tCorte));
  }

  @override
  Widget build(BuildContext context) {
    final Size pantalla = MediaQuery.of(context).size;
    final double anchoLogo = pantalla.width * 0.55;

    // Tema de la app (ya resuelve el modo "Sistema").
    final bool temaOscuro = Theme.of(context).brightness == Brightness.dark;
    final Color fondoTema = temaOscuro
        ? SplashAnimadoView.fondoOscuro
        : SplashAnimadoView.fondoClaro;
    // El fondo nativo de arranque sigue el modo del teléfono; se parte de ese
    // color y se pasa suavemente al del tema para evitar un salto brusco.
    final Color fondoArranque =
    MediaQuery.platformBrightnessOf(context) == Brightness.dark
        ? SplashAnimadoView.fondoOscuro
        : SplashAnimadoView.fondoClaro;
    final Color colorEslogan = temaOscuro
        ? SplashAnimadoView.esloganOscuro
        : SplashAnimadoView.esloganClaro;
    final double alfaResplandor = temaOscuro ? 0.15 : 0.12;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final double val = _controller.value;

        // Fondo: cambio suave del color nativo al del tema (0% - 12%).
        final double cambioFondo = _tramo(val, 0.0, 0.12, Curves.easeInOut);
        final Color fondo = (fondoArranque == fondoTema || cambioFondo >= 1.0)
            ? fondoTema
            : Color.lerp(fondoArranque, fondoTema, cambioFondo)!;

        // Barra de estado: iconos que contrasten con el fondo actual.
        final bool fondoEsOscuro =
            ThemeData.estimateBrightnessForColor(fondo) == Brightness.dark;
        final SystemUiOverlayStyle estiloBarra = SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
          fondoEsOscuro ? Brightness.light : Brightness.dark,
          statusBarBrightness:
          fondoEsOscuro ? Brightness.dark : Brightness.light,
        );

        // Fade out final (90% - 100%).
        final double opacidadGlobal =
            1.0 - _tramo(val, 0.90, 1.0, Curves.easeIn);

        // Entrada en vuelo (0% - 40%): llega desde abajo a la izquierda en curva.
        final double vuelo = _tramo(val, 0.0, _finVuelo, Curves.easeOutCubic);
        final double escalaT = _tramo(val, 0.0, _finVuelo, Curves.easeOutBack);
        final double opacidadLogo = _tramo(val, 0.0, 0.25, Curves.easeOut);
        final double escala = 0.85 + 0.15 * escalaT;
        final double entradaX = (1.0 - vuelo) * (-pantalla.width * 0.35);
        final double entradaY = (1.0 - vuelo) * (pantalla.height * 0.16) -
            math.sin(math.pi * vuelo) * (pantalla.height * 0.04);
        final double inclinacionEntrada = (1.0 - vuelo) * -0.10;

        // Flote en el lugar (40% - 100%).
        double floteY = 0.0;
        double floteRot = 0.0;
        if (val > _finVuelo) {
          final double p = (val - _finVuelo) / (1.0 - _finVuelo);
          final double onda = math.sin(p * 2 * math.pi * 2);
          floteY = onda * 4.0;
          floteRot = onda * 0.026;
        }

        // Aleteo: ángulo positivo = alas hacia arriba.
        final double amplitud =
            13.0 - 4.0 * _tramo(val, _finVuelo, _finVuelo + 0.2, Curves.easeInOut);
        final double gradosAlas = 4.0 + amplitud * math.sin(_faseAlas(val));
        final double anguloAlas = gradosAlas * math.pi / 180.0;

        // Destello que cruza la abeja una vez (45% - 75%).
        final double destello = _tramo(val, 0.45, 0.75);
        final bool hayDestello = destello > 0.0 && destello < 1.0;

        // Nombre y eslogan (55% - 85%).
        final double opacidadTexto = _tramo(val, 0.55, 0.85, Curves.easeOut);
        final double desplazamientoTexto = (1.0 - opacidadTexto) * 20.0;

        // Pulso suave del resplandor.
        final double pulso = 1.0 + 0.06 * math.sin(val * 2 * math.pi * 2);

        // Las dos capas de la abeja: alas detrás, cuerpo y tablero delante.
        final Widget abeja = SizedBox(
          width: anchoLogo,
          height: anchoLogo,
          child: Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: Transform.rotate(
                  angle: anguloAlas,
                  alignment: _pivoteAlas,
                  child: Image.asset(
                    _rutaAlas,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
                  ),
                ),
              ),
              RepaintBoundary(
                child: Image.asset(
                  _rutaBase,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (context, error, stackTrace) => Image.asset(
                    _rutaIcono,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.view_kanban,
                      size: 100,
                      color: SplashAnimadoView.azulCielo,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

        final Widget abejaConDestello = hayDestello
            ? ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (Rect bounds) {
            return LinearGradient(
              begin: const Alignment(-1.0, -0.3),
              end: const Alignment(1.0, 0.3),
              colors: const [
                Color(0x00FFFFFF),
                Color(0x00FFFFFF),
                Color(0x99FFFFFF),
                Color(0x00FFFFFF),
                Color(0x00FFFFFF),
              ],
              stops: const [0.0, 0.40, 0.50, 0.60, 1.0],
              transform: _DeslizarGradiente(-1.0 + 2.0 * destello),
            ).createShader(bounds);
          },
          child: abeja,
        )
            : abeja;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: estiloBarra,
          child: GestureDetector(
            onTap: _navegarFinal,
            behavior: HitTestBehavior.opaque,
            child: Scaffold(
              backgroundColor: fondo,
              body: Opacity(
                opacity: opacidadGlobal.clamp(0.0, 1.0),
                child: Stack(
                  children: [
                    // Resplandor radial detrás de la abeja.
                    Center(
                      child: Transform.scale(
                        scale: pulso,
                        child: Container(
                          width: anchoLogo * 1.4,
                          height: anchoLogo * 1.4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                SplashAnimadoView.azulCielo.withValues(
                                  alpha: alfaResplandor *
                                      opacidadLogo.clamp(0.0, 1.0),
                                ),
                                SplashAnimadoView.azulCielo
                                    .withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Transform.translate(
                            offset: Offset(entradaX, entradaY + floteY),
                            child: Transform.rotate(
                              angle: inclinacionEntrada + floteRot,
                              child: Transform.scale(
                                scale: escala,
                                child: Opacity(
                                  opacity: opacidadLogo.clamp(0.0, 1.0),
                                  // El PNG tiene mucho margen vacío arriba y
                                  // abajo: se recorta el espacio de layout para
                                  // que el texto quede cerca de la abeja.
                                  child: Align(
                                    alignment: const Alignment(0.0, -0.316),
                                    heightFactor: 0.5,
                                    child: abejaConDestello,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Transform.translate(
                            offset: Offset(0, desplazamientoTexto),
                            child: Opacity(
                              opacity: opacidadTexto.clamp(0.0, 1.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ShaderMask(
                                    shaderCallback: (Rect bounds) {
                                      return const LinearGradient(
                                        colors: [
                                          SplashAnimadoView.azulCielo,
                                          SplashAnimadoView.verdeTurquesa,
                                        ],
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
                                  Text(
                                    'Fluye y avanza',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                      color: colorEslogan,
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
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Desplaza horizontalmente un gradiente (porcentaje del ancho) para el destello.
class _DeslizarGradiente extends GradientTransform {
  const _DeslizarGradiente(this.porcentaje);

  final double porcentaje;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * porcentaje, 0.0, 0.0);
  }
}
