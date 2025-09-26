import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth; // Importación con alias para claridad
// Importa tu FirestoreService
import '../firebase_core/firestore_service.dart';
// Importa tu modelo de usuario
import '../models/user.dart' as AppUser;
import '../utils/constants.dart';
import '../widgets/custom_logo.dart';
import 'registration_screen.dart';
import 'user_home_screen.dart';
import 'admin_home_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _loadingMethod; // Para saber qué botón está cargando
  late FirestoreService _firestoreService;

  @override
  void initState() {
    super.initState();
    _firestoreService = FirestoreService();
  }

  Future<void> _loginWithEmail() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showMessage('Por favor complete todos los campos');
      return;
    }

    if (mounted) setState(() {
      _isLoading = true;
      _loadingMethod = 'email'; // Marcar que este método está cargando
    });

    try {
      final AppUser.User? user = await _firestoreService.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (user != null) {
        await _handleSuccessfulLogin(user);
      } else {
        // FirestoreService ya debería haber logueado el error si signInWithEmailAndPassword retorna null
        // pero getUserById falla.
        _showMessage('Email o contraseña incorrectos, o error de conexión.');
      }
    } on fb_auth.FirebaseAuthException catch (e) {
      print("LoginScreen (Email): FirebaseAuthException: ${e.message}");
      _showMessage('Error de inicio de sesión: ${e.message ?? "Ocurrió un problema."}');
    } catch (e) {
      print("LoginScreen (Email): Generic error: $e");
      _showMessage('Ocurrió un error inesperado durante el inicio de sesión.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingMethod = null;
        });
      }
    }
  }

  Future<void> _loginWithGoogle() async {
    if (mounted) setState(() {
      _isLoading = true;
      _loadingMethod = 'google'; // Marcar que este método está cargando
    });

    try {
      final AppUser.User? user = await _firestoreService.signInWithGoogle();

      if (user != null) {
        await _handleSuccessfulLogin(user);
      } else {
        // El usuario pudo haber cancelado el flujo o FirestoreService ya logueó un error.
        // Opcional: _showMessage('Inicio de sesión con Google cancelado o fallido.');
        print("LoginScreen: Google Sign-In returned null user (possibly cancelled).");
      }
    } on fb_auth.FirebaseAuthException catch (e) {
      print("LoginScreen (Google): FirebaseAuthException: ${e.message}");
      // Manejar casos específicos como 'account-exists-with-different-credential' si es necesario
      _showMessage('Error con Google Sign-In: ${e.message ?? "Ocurrió un problema."}');
    } catch (e) {
      print("LoginScreen (Google): Generic error: $e");
      _showMessage('Ocurrió un error inesperado con Google Sign-In.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingMethod = null;
        });
      }
    }
  }

  Future<void> _handleSuccessfulLogin(AppUser.User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', user.id!);
    await prefs.setBool('isAdmin', user.isAdmin);
    // Opcional: podrías guardar el email también
    // await prefs.setString('userEmail', user.email);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
          user.isAdmin ? AdminHomeScreen() : UserHomeScreen(),
        ),
      );
    }
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CustomLogo(size: 120),
                const SizedBox(height: 20),
                Text(
                  'Órdenes de Trabajo',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email, color: AppColors.primaryBlue),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primaryBlue, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: Icon(Icons.lock, color: AppColors.primaryBlue),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primaryBlue, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _loginWithEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: (_isLoading && _loadingMethod == 'email')
                        ? CircularProgressIndicator(color: AppColors.white)
                        : Text(
                      'Iniciar Sesión',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    icon: Image.asset('assets/images/google_logo.png', height: 24.0), // Asegúrate de tener esta imagen
                    label: Text(
                      'Iniciar Sesión con Google',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    onPressed: _isLoading ? null : _loginWithGoogle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                    ),
                    // Mostrar indicador si este método está cargando
                    // child: (_isLoading && _loadingMethod == 'google') // Esto no funciona bien con ElevatedButton.icon directamente
                    //   ? CircularProgressIndicator(color: AppColors.primaryBlue) // o un color que contraste
                    //   : null, // El label y el icon ya están definidos
                  ),
                ),
                // Para mostrar el CircularProgressIndicator dentro del botón de Google,
                // podrías tener que hacer el child del botón condicionalmente.
                // Una forma más simple es que el botón se deshabilite y el usuario vea
                // que algo está pasando por el estado general de _isLoading.
                // Si quieres un indicador DENTRO del botón de Google, es un poco más complejo:
                // child: (_isLoading && _loadingMethod == 'google')
                //     ? SizedBox(
                //         height: 24, // Ajusta al tamaño del icono
                //         width: 24,  // Ajusta al tamaño del icono
                //         child: CircularProgressIndicator(strokeWidth: 2.0, color: AppColors.primaryBlue),
                //       )
                //     : Row( // O como lo tenías con ElevatedButton.icon
                //         mainAxisSize: MainAxisSize.min,
                //         children: [
                //           Image.asset('assets/images/google_logo.png', height: 24.0),
                //           SizedBox(width: 8),
                //           Text('Iniciar Sesión con Google', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                //         ],
                //       ),

                const SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => RegistrationScreen()));
                  },
                  child: Text(
                    '¿No tienes una cuenta? Regístrate',
                    style: TextStyle(color: AppColors.primaryBlue),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}