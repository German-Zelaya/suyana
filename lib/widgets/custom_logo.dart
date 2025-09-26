// lib/widgets/custom_logo.dart

import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../utils/constants.dart';

class CustomLogo extends StatelessWidget {
  final double size;
  const CustomLogo({super.key, this.size = 100});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/t2.png',
      width: size,
      height: size * 1.2,
      fit: BoxFit.contain,
    );
  }
}

// Clase para el logo animado en el splash screen
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
            'assets/images/t2.png',
            width: size,
            height: size * 1.2,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }
}

// Painter para los engranajes animados de fondo
class AnimatedGearsPainter extends CustomPainter {
  final double rotationAngle;

  AnimatedGearsPainter(this.rotationAngle);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Engranaje superior derecho
    canvas.save();
    canvas.translate(size.width * 0.75, size.height * 0.25);
    canvas.rotate(rotationAngle);
    _drawGear(canvas, 0, 0, size.width * 0.15, paint, strokePaint);
    canvas.restore();

    // Engranaje inferior izquierdo
    canvas.save();
    canvas.translate(size.width * 0.25, size.height * 0.75);
    canvas.rotate(-rotationAngle * 1.5);
    _drawGear(canvas, 0, 0, size.width * 0.15, paint, strokePaint);
    canvas.restore();

    // Engranaje pequeño superior izquierdo
    canvas.save();
    canvas.translate(size.width * 0.2, size.height * 0.2);
    canvas.rotate(rotationAngle * 2);
    _drawGear(canvas, 0, 0, size.width * 0.08, paint, strokePaint);
    canvas.restore();

    // Engranaje pequeño inferior derecho
    canvas.save();
    canvas.translate(size.width * 0.8, size.height * 0.8);
    canvas.rotate(-rotationAngle * 0.8);
    _drawGear(canvas, 0, 0, size.width * 0.1, paint, strokePaint);
    canvas.restore();
  }

  void _drawGear(Canvas canvas, double x, double y, double radius, Paint fillPaint, Paint strokePaint) {
    final teeth = 8;
    final innerRadius = radius * 0.6;
    final toothHeight = radius * 0.25;

    final path = Path();

    for (int i = 0; i < teeth * 2; i++) {
      final angle = (i * 2 * math.pi) / (teeth * 2);
      final r = i % 2 == 0 ? radius : radius - toothHeight;
      final gearX = x + r * math.cos(angle);
      final gearY = y + r * math.sin(angle);

      if (i == 0) {
        path.moveTo(gearX, gearY);
      } else {
        path.lineTo(gearX, gearY);
      }
    }
    path.close();

    // Dibujar engranaje relleno
    canvas.drawPath(path, fillPaint);

    // Dibujar borde del engranaje
    canvas.drawPath(path, strokePaint);

    // Centro del engranaje
    canvas.drawCircle(Offset(x, y), innerRadius * 0.4, fillPaint);
    canvas.drawCircle(Offset(x, y), innerRadius * 0.4, strokePaint);

    // Agujero central
    final holePaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(x, y), innerRadius * 0.2, holePaint);
  }

  @override
  bool shouldRepaint(AnimatedGearsPainter oldDelegate) =>
      oldDelegate.rotationAngle != rotationAngle;
}

class OrderHeader extends StatelessWidget {
  const OrderHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: AppColors.secondaryBlue, // Asegúrate de que AppColors esté definido
            width: 2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const CustomLogo(size: 60),
          const SizedBox(width: 16),
          Expanded(
            child: Column( // Esta es la Column principal para organizar verticalmente la imagen y el texto
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [ // La lista de widgets hijos para esta Column
                // Reemplaza el Widget Text con el Widget Image
                Image.asset(
                  'assets/images/su.png', // Cambia esto a la ruta de tu imagen
                  height: 40, // Ajusta la altura según necesites
                  // Opcional: puedes ajustar el ancho también
                  // width: 200,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 4),
                Text(
                  'Servicio de Ambulancia',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}