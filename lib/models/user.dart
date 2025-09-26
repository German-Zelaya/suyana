import 'package:cloud_firestore/cloud_firestore.dart'; // Necesario para Timestamp si lo usaras

class User {
  final String? id; // UID de Firebase Auth (String) o ID del documento de Firestore.
  // Puede ser null si el objeto se crea antes de guardarlo.
  final String username; // Nombre de usuario (si lo usas además del email de autenticación)
  final String email;    // Email del usuario (generalmente el que usa para autenticarse)
  final bool isAdmin;
  final Timestamp? createdAt; // Opcional: para registrar cuándo se creó el perfil del usuario

  User({
    this.id,
    required this.username,
    required this.email,
    this.isAdmin = false,
    required this.createdAt,
  });

  // Método para convertir un objeto User a un Map para Firestore
  // Este mapa es lo que se guarda en un documento de Firestore
  Map<String, dynamic> toMap() {
    return {
      // 'id' no se incluye aquí generalmente, ya que es el ID del documento en sí.
      'username': username,
      'email': email,
      'isAdmin': isAdmin,
      'createdAt': createdAt,// Se guarda directamente como booleano
      // Si createdAt es null (al crear un nuevo usuario),
      // FirestoreService puede usar FieldValue.serverTimestamp()
    };
  }

  // Factory constructor para crear un User desde un Map (documento de Firestore)
  // 'documentId' es el ID del documento que se está leyendo de Firestore.
  factory User.fromMap(Map<String, dynamic> map, String documentId) {
    return User(
      id: documentId, // El ID del documento de Firestore se asigna al objeto
      username: map['username'] ?? '', // Proporciona un valor por defecto si puede ser nulo en DB
      email: map['email'] ?? '',       // Proporciona un valor por defecto
      isAdmin: map['isAdmin'] ?? false, // Proporciona un valor por defecto
      createdAt: map['createdAt'] ?? Timestamp.now(), // Leer como Timestamp, puede ser null
    );
  }

  // Opcional: Un método copyWith para facilitar la actualización de instancias inmutables
  User copyWith({
    String? id,
    String? username,
    String? email,
    bool? isAdmin,
    Timestamp? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      isAdmin: isAdmin ?? this.isAdmin,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get displayName { // O el nombre que prefieras, ej: displayForList
    if (username.isNotEmpty) {
      return username;
    }
    return email; // Fallback al email si no hay username
  }

  // Opcional: Para facilitar la depuración
  @override
  String toString() {
    return 'User(id: $id, username: $username, email: $email, isAdmin: $isAdmin, createdAt: $createdAt)';
  }
}