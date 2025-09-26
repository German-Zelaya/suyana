// En screens/registration_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth; // Para FirebaseAuthException
import '../firebase_core/firestore_service.dart'; // Ajusta la ruta a tu FirestoreService
import '../models/user.dart' as AppUser; // Ajusta la ruta a tu modelo User
import '../utils/constants.dart'; // Para AppColors, si los usas aquí
// Opcional: para la navegación de vuelta o a la pantalla de inicio
// import 'user_home_screen.dart';
// import 'admin_home_screen.dart';


class RegistrationScreen extends StatefulWidget {
  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  late FirestoreService _firestoreService;

  @override
  void initState() {
    super.initState();
    _firestoreService = FirestoreService();
  }

  Future<void> _tryRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _formKey.currentState!.save(); // Guarda los valores de los campos

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // Usamos el método de FirestoreService para crear el usuario
      final AppUser.User? newUser =
      await _firestoreService.createUserWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _usernameController.text.trim(),
        false, // isAdmin siempre false al registrar
      );

      if (newUser != null && mounted) {
        // Registro y creación de documento en Firestore exitosos
        _showMessage('¡Registro exitoso! Ahora puedes iniciar sesión.', isError: false);
        // Opcional: Navegar directamente a la pantalla de inicio
        // final prefs = await SharedPreferences.getInstance();
        // await prefs.setString('userId', newUser.id!);
        // await prefs.setBool('isAdmin', newUser.isAdmin);
        // Navigator.pushReplacement(
        //   context,
        //   MaterialPageRoute(
        //     builder: (context) => UserHomeScreen(), // O AdminHomeScreen si isAdmin fuera true
        //   ),
        // );

        // Por ahora, solo volvemos a la pantalla de login para que inicie sesión
        Navigator.of(context).pop();

      } else if (mounted) {
        // Esto es poco probable si createUserWithEmailAndPassword maneja bien sus excepciones
        _showMessage('Ocurrió un error inesperado durante el registro.');
      }
    } on fb_auth.FirebaseAuthException catch (e) {
      String message = 'Ocurrió un error durante el registro.';
      if (e.code == 'weak-password') {
        message = 'La contraseña proporcionada es demasiado débil.';
      } else if (e.code == 'email-already-in-use') {
        message = 'La cuenta ya existe para ese correo electrónico.';
      } else if (e.code == 'invalid-email') {
        message = 'El correo electrónico no es válido.';
      }
      if (mounted) _showMessage(message);
      print('RegistrationScreen: FirebaseAuthException: ${e.message}');
    } catch (e) {
      if (mounted) _showMessage('Ocurrió un error inesperado: ${e.toString()}');
      print('RegistrationScreen: Generic error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showMessage(String message, {bool isError = true}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.redAccent : Colors.green,
        ),
      );
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text('Crear Cuenta'),
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    'Regístrate',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 30),
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Nombre de Usuario',
                      prefixIcon: Icon(Icons.person, color: AppColors.primaryBlue),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.primaryBlue, width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Por favor ingresa tu nombre de usuario.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
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
                    validator: (value) {
                      if (value == null || value.trim().isEmpty || !value.contains('@')) {
                        return 'Por favor ingresa un email válido.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
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
                    validator: (value) {
                      if (value == null || value.isEmpty || value.length < 6) {
                        return 'La contraseña debe tener al menos 6 caracteres.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _tryRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? CircularProgressIndicator(color: AppColors.white)
                          : Text(
                        'Registrar Cuenta',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: _isLoading ? null : () {
                      Navigator.of(context).pop(); // Volver a la pantalla de login
                    },
                    child: Text(
                      '¿Ya tienes una cuenta? Inicia Sesión',
                      style: TextStyle(color: AppColors.primaryBlue),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}