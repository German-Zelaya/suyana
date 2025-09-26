import 'package:flutter/material.dart';
// Asegúrate que tu modelo User esté actualizado para Firebase
// (con email, y el id es el UID de Firebase Auth)
import '../models/user.dart' as AppUser; // Usando un prefijo para evitar conflictos
import '../firebase_core/firestore_service.dart';
import '../utils/constants.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});
  @override
  _ManageUsersScreenState createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  List<AppUser.User> _users = [];
  bool _isLoading = true;
  late FirestoreService _firestoreService;

  @override
  void initState() {
    super.initState();
    _firestoreService = FirestoreService();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final users = await _firestoreService.getAllUsers();
      if (mounted) {
        setState(() {
          _users = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar usuarios: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _addUser() async {
    // El diálogo ahora podría devolver un mapa o un objeto específico para la creación
    final result = await showDialog<AppUser.User>( // Esperamos un objeto User con datos para crear
      context: context,
      builder: (context) => _UserDialog(firestoreService: _firestoreService), // Pasamos el servicio
    );

    if (result != null) {
      // El _UserDialog ahora debería haber manejado la creación
      // o devuelto los datos necesarios para que _firestoreService.createUserWithEmailAndPassword lo haga.
      // Si _UserDialog ya creó el usuario en Auth y Firestore:
      _showSnackbar('Usuario creado exitosamente');
      _loadUsers(); // Recargar la lista de usuarios
    }
    // El manejo de errores específico de la creación (ej. email ya existe)
    // debería hacerse dentro de _UserDialog o en el método de FirestoreService
  }

  Future<void> _editUser(AppUser.User user) async {
    final result = await showDialog<AppUser.User>( // Esperamos el usuario actualizado
      context: context,
      builder: (context) => _UserDialog(
        userToEdit: user,
        firestoreService: _firestoreService, // Pasamos el servicio
      ),
    );

    if (result != null) {
      // El _UserDialog ahora debería haber manejado la actualización
      // o devuelto el usuario actualizado para que _firestoreService.updateUser lo haga.
      _showSnackbar('Usuario actualizado');
      _loadUsers(); // Recargar la lista
    }
  }

  Future<void> _deleteUser(AppUser.User user) async {
    if (user.id == _firestoreService.getCurrentUserId()) {
      _showSnackbar('No puedes eliminar tu propia cuenta desde aquí.');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Está seguro de eliminar al usuario ${user.username} (${user.email})? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true && user.id != null) {
      if (mounted) setState(() => _isLoading = true);
      try {
        // IMPORTANTE: _firestoreService.deleteUser idealmente debería manejar
        // tanto la eliminación de Firestore como la de Firebase Auth (esta última es compleja desde el cliente).
        // Por ahora, asumimos que elimina de Firestore.
        // La eliminación de Auth para OTROS usuarios desde el cliente es un riesgo de seguridad
        // y generalmente requiere el Admin SDK en un backend.
        // Una alternativa más segura desde el cliente es "deshabilitar" la cuenta
        // (ej. añadir un campo 'isDisabled: true' en Firestore).
        await _firestoreService.deleteUser(user.id!);
        _showSnackbar('Usuario eliminado de Firestore.');
        _loadUsers();
      } catch (e) {
        if (mounted) setState(() => _isLoading = false);
        _showSnackbar('Error al eliminar usuario: ${e.toString()}');
      }
    }
  }

  void _showSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gestionar Usuarios', style: TextStyle(color: AppColors.white)),
        backgroundColor: AppColors.primaryBlue,
        iconTheme: IconThemeData(color: AppColors.white),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addUser,
        backgroundColor: AppColors.primaryBlue,
        child: Icon(Icons.add, color: AppColors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
          ? const Center(child: Text('No hay usuarios para mostrar.'))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: user.isAdmin
                    ? AppColors.primaryBlue
                    : AppColors.secondaryBlue,
                child: Icon(
                  user.isAdmin ? Icons.admin_panel_settings : Icons.person,
                  color: Colors.white,
                ),
              ),
              title: Text(
                user.username, // Mantenemos username como principal display
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.email ?? 'Email no disponible'), // Mostrar email
                  Text(
                    user.isAdmin ? 'Administrador' : 'Usuario',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _editUser(user);
                  } else if (value == 'delete') {
                    _deleteUser(user);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Editar'),
                      ],
                    ),
                  ),
                  if (user.id != _firestoreService.getCurrentUserId()) // No mostrar eliminar para el usuario actual
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Eliminar'),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _UserDialog extends StatefulWidget {
  final AppUser.User? userToEdit;
  final FirestoreService firestoreService; // Necesario para crear/actualizar

  const _UserDialog({this.userToEdit, required this.firestoreService, super.key});

  @override
  __UserDialogState createState() => __UserDialogState();
}

class __UserDialogState extends State<_UserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController(); // Nuevo campo para email
  final _passwordController = TextEditingController(); // Para nuevo usuario
  bool _isAdmin = false;
  bool _isEditMode = false;
  bool _dialogIsLoading = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.userToEdit != null;
    if (_isEditMode) {
      _usernameController.text = widget.userToEdit!.username;
      _emailController.text = widget.userToEdit!.email ?? ''; // El email es crucial
      _isAdmin = widget.userToEdit!.isAdmin;
      // La contraseña no se edita directamente aquí por simplicidad/seguridad
    }
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (mounted) setState(() => _dialogIsLoading = true);

    try {
      if (_isEditMode) {
        // Actualizar usuario existente en Firestore
        final updatedUser = AppUser.User(
            id: widget.userToEdit!.id, // ID es crucial para la actualización
            username: _usernameController.text.trim(),
            email: widget.userToEdit!.email, // El email no se edita desde aquí
            isAdmin: _isAdmin,
            createdAt: widget.userToEdit!.createdAt // Mantener el createdAt original
        );
        await widget.firestoreService.updateUser(updatedUser);
        if (mounted) Navigator.pop(context, updatedUser); // Devolver usuario actualizado
      } else {
        // Crear nuevo usuario (en Auth y Firestore)
        final newUser = await widget.firestoreService.createUserWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text, // La contraseña es necesaria para Auth
          _usernameController.text.trim(),
          _isAdmin,
        );
        if (newUser != null) {
          if (mounted) Navigator.pop(context, newUser); // Devolver el nuevo usuario creado
        } else {
          // Si newUser es null, createUserWithEmailAndPassword falló (ej. email ya existe)
          // El servicio debería haber mostrado un error o podemos hacerlo aquí
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error al crear usuario. El email podría ya estar en uso.')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _dialogIsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditMode ? 'Editar Usuario' : 'Nuevo Usuario'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView( // Para evitar overflow si hay muchos campos
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre de usuario',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Este campo es requerido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
                enabled: !_isEditMode, // El email no se puede editar una vez creado
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Este campo es requerido';
                  }
                  if (!RegExp(r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(value)) {
                    return 'Ingrese un email válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (!_isEditMode) // El campo de contraseña solo para nuevos usuarios
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (!_isEditMode && (value == null || value.isEmpty)) {
                      return 'Este campo es requerido';
                    }
                    if (!_isEditMode && value != null && value.length < 6) {
                      return 'La contraseña debe tener al menos 6 caracteres';
                    }
                    return null;
                  },
                ),
              if (!_isEditMode) const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Administrador'),
                value: _isAdmin,
                onChanged: (value) => setState(() => _isAdmin = value),
                activeColor: AppColors.primaryBlue,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _dialogIsLoading ? null : _saveUser,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: AppColors.white,
          ),
          child: _dialogIsLoading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2,))
              : Text(_isEditMode ? 'Actualizar' : 'Crear'),
        ),
      ],
    );
  }
}