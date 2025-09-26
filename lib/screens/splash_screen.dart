// lib/screens/splash_screen.dart

import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../utils/constants.dart';
import '../widgets/custom_logo.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _rotationController;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Controlador para escala
    _scaleController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    // Controlador para rotación de engranajes
    _rotationController = AnimationController(
      duration: Duration(seconds: 3),
      vsync: this,
    )..repeat();

    // Controlador para fade
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    // Controlador para slide
    _slideController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );

    // Controlador para pulso
    _pulseController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );

    // Configurar animaciones
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(_rotationController);

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Iniciar animaciones en secuencia
    _startAnimations();
  }

  void _startAnimations() async {
    await Future.delayed(Duration(milliseconds: 300));
    _fadeController.forward();
    await Future.delayed(Duration(milliseconds: 200));
    _slideController.forward();
    await Future.delayed(Duration(milliseconds: 300));
    _scaleController.forward();
    await Future.delayed(Duration(milliseconds: 1000));
    _pulseController.repeat(reverse: true);

    // Navegar a login después de 4 segundos
    await Future.delayed(Duration(seconds: 2));
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: Duration(milliseconds: 800),
      ),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _rotationController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primaryBlue,
              AppColors.secondaryBlue,
            ],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _scaleAnimation,
              _fadeAnimation,
              _slideAnimation,
              _pulseAnimation,
            ]),
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ScaleTransition(
                    scale: _pulseAnimation,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Círculos de fondo animados
                          ..._buildAnimatedCircles(),
                          // Logo animado
                          AnimatedBuilder(
                            animation: _rotationAnimation,
                            builder: (context, child) {
                              return AnimatedLogo(
                                size: 200,
                                rotationAngle: _rotationAnimation.value,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAnimatedCircles() {
    return List.generate(3, (index) {
      return AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value * (1 + index * 0.2),
            child: Container(
              width: 300 + (index * 50),
              height: 300 + (index * 50),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.1 - (index * 0.03)),
                  width: 2,
                ),
              ),
            ),
          );
        },
      );
    });
  }
}

class AnimatedLogo extends StatelessWidget {
  final double size;
  final double rotationAngle;

  const AnimatedLogo({
    super.key,
    this.size = 100,
    this.rotationAngle = 0
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Engranajes animados detrás del logo
        CustomPaint(
          size: Size(size * 1.5, size * 1.8),
          painter: AnimatedGearsPainter(rotationAngle),
        ),
        // Logo principal con efectos
        Container(
          width: size,
          height: size * 1.2,
          decoration: BoxDecoration(
            // Sombra brillante alrededor del logo
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
              BoxShadow(
                color: AppColors.secondaryBlue.withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/suc.png',
            width: size,
            height: size * 1.2,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }
}