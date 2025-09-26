import 'package:cloud_firestore/cloud_firestore.dart';
// Import FirebaseAuth with a prefix to avoid conflict
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:google_sign_in/google_sign_in.dart'; // <<<--- AÑADIR ESTA IMPORTACIÓN
import '../models/user.dart'; // Your custom User model
import '../models/work_order.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  // Use the prefixed import for FirebaseAuth instance
  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(); // <<<--- AÑADIR ESTA LÍNEA

  // Define the collection name as a constant
  static const String _usersCollection = 'users';
  static const String _workOrdersCollection = 'work_orders';

  // --- Autenticación ---
  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    print("FirestoreService: Attempting Email/Password Sign-In for $email"); // Log
    try {
      fb_auth.UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (userCredential.user != null) {
        print("FirestoreService: Email/Password Auth successful. UID: ${userCredential.user!.uid}"); // Log
        return getUserById(userCredential.user!.uid);
      }
      print("FirestoreService: Email/Password Auth successful but userCredential.user is null."); // Log
      return null;
    } on fb_auth.FirebaseAuthException catch (e) {
      print('FirestoreService: Email/Password FirebaseAuthException: ${e.code} - ${e.message}'); // Log detallado
      rethrow;
    } catch (e) {
      print('FirestoreService: Email/Password Generic Error: $e'); // Log genérico
      rethrow;
    }
  }

  // --- MÉTODO PARA INICIO DE SESIÓN CON GOOGLE ---
  Future<User?> signInWithGoogle() async {
    print("FirestoreService: Attempting Google Sign-In");
    GoogleSignInAccount? googleUser;
    try {
      // 1. Iniciar el flujo de Google Sign-In
      googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // El usuario canceló el flujo de inicio de sesión
        print("FirestoreService: Google Sign-In cancelled by user.");
        return null;
      }
      print("FirestoreService: Google User fetched: ${googleUser.email}");

      // 2. Obtener los detalles de autenticación de la cuenta de Google
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      print("FirestoreService: Google Auth details fetched.");

      // 3. Crear una credencial de Firebase con el token de Google
      final fb_auth.OAuthCredential credential = fb_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      print("FirestoreService: Firebase OAuthCredential created.");

      // 4. Iniciar sesión en Firebase con la credencial
      final fb_auth.UserCredential userCredential = await _auth.signInWithCredential(credential);
      final fb_auth.User? firebaseUser = userCredential.user;
      print("FirestoreService: Firebase sign-in with Google credential successful. UID: ${firebaseUser?.uid}");

      if (firebaseUser != null) {
        // 5. Verificar si el usuario ya existe en Firestore o crearlo/actualizarlo
        User? appUser = await getUserById(firebaseUser.uid);

        if (appUser == null) {
          // El usuario es nuevo o no tiene un documento en Firestore. Creamos uno.
          print("FirestoreService: User ${firebaseUser.email} is new or document not found. Creating Firestore document.");
          appUser = User(
            id: firebaseUser.uid,
            // Intenta usar displayName de Google o Firebase, sino usa parte del email.
            // Asegúrate que tu modelo AppUser.User tenga 'username'
            username: firebaseUser.displayName ?? googleUser.displayName ?? firebaseUser.email!.split('@')[0],
            email: firebaseUser.email!,
            // Decide el valor por defecto para isAdmin para nuevos usuarios de Google
            // Podrías tener una lógica para esto o un valor por defecto.
            isAdmin: false,
            createdAt: Timestamp.now(),
            // profilePictureUrl: firebaseUser.photoURL, // Opcional, si tu modelo User lo tiene
          );
          // Usamos el método createUserDocument que ya tienes para la consistencia
          await createUserDocument(appUser);
          print("FirestoreService: Firestore document created for ${appUser.email}");
        } else {
          // El usuario ya existe.
          // Opcional: Podrías querer actualizar alguna información aquí si ha cambiado en Google
          // (ej. displayName, photoURL). Por ahora, solo lo retornamos.
          print("FirestoreService: User ${appUser.email} (ID: ${appUser.id}) already exists in Firestore.");
          // Ejemplo de actualización si el nombre ha cambiado:
          // String newUsername = firebaseUser.displayName ?? googleUser.displayName ?? firebaseUser.email!.split('@')[0];
          // if (appUser.username != newUsername) {
          //   print("FirestoreService: Updating username for ${appUser.email} from ${appUser.username} to $newUsername");
          //   appUser = appUser.copyWith(username: newUsername); // Asume que tu AppUser.User tiene copyWith
          //   await updateUser(appUser);
          // }
        }
        return appUser;
      }
      print("FirestoreService: Google Sign-In successful but firebaseUser is null.");
      return null;
    } on fb_auth.FirebaseAuthException catch (e) {
      print('FirestoreService: Google Sign-In FirebaseAuthException: ${e.code} - ${e.message}');
      // Un error común aquí es 'account-exists-with-different-credential'
      // si el usuario ya se registró con email/contraseña usando el mismo email.
      // Firebase tiene mecanismos para enlazar cuentas (linkWithCredential),
      // pero eso es más avanzado y no está implementado aquí.
      if (e.code == 'account-exists-with-different-credential') {
        print('FirestoreService: This email (${googleUser?.email}) is already associated with another sign-in method.');
        // Podrías querer notificar al usuario de esto de alguna manera.
      }
      rethrow;
    } catch (e, s) { // Añadir stack trace para más detalles en errores genéricos
      print('FirestoreService: Google Sign-In Generic Error: $e');
      print('FirestoreService: Stack trace: $s');
      rethrow;
    }
  }

  Future<User?> createUserWithEmailAndPassword(
      String email, String password, String username, bool isAdmin) async {
    print("FirestoreService: Attempting to create user $username with email $email"); // Log
    try {
      fb_auth.UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (userCredential.user != null) {
        print("FirestoreService: Firebase Auth user created. UID: ${userCredential.user!.uid}"); // Log
        User newUser = User(
          id: userCredential.user!.uid,
          username: username,
          email: email,
          isAdmin: isAdmin,
          createdAt: Timestamp.now(),
        );
        // Usamos el método createUserDocument para la consistencia
        await createUserDocument(newUser);
        print("FirestoreService: Firestore document created for ${newUser.email}"); // Log
        return newUser;
      }
      print("FirestoreService: Firebase Auth user creation successful but userCredential.user is null."); // Log
      return null;
    } on fb_auth.FirebaseAuthException catch (e) {
      print('FirestoreService: Create User FirebaseAuthException: ${e.code} - ${e.message}'); // Log detallado
      rethrow;
    } catch (e) {
      print('FirestoreService: Create User Generic Error: $e'); // Log genérico
      rethrow;
    }
  }

  Future<void> signOut() async {
    // También hacer sign out de Google si el usuario inició sesión con Google
    // para que la próxima vez le pida seleccionar cuenta de nuevo.
    await _googleSignIn.signOut();
    print("FirestoreService: Signed out from Google."); // Log
    await _auth.signOut();
    print("FirestoreService: Signed out from Firebase Auth."); // Log
  }

  Stream<User?> get authStateChanges =>
      _auth.authStateChanges().asyncMap((fb_auth.User? firebaseUser) {
        if (firebaseUser == null) {
          print("FirestoreService: authStateChanges - User is null (logged out)."); // Log
          return null;
        }
        print("FirestoreService: authStateChanges - User is not null (UID: ${firebaseUser.uid}). Fetching user details."); // Log
        return getUserById(firebaseUser.uid);
      });

  String? getCurrentUserId() {
    final userId = _auth.currentUser?.uid;
    print("FirestoreService: Current User ID: $userId"); // Log
    return userId;
  }

  // --- Métodos para Usuarios (Firestore) ---
  Future<void> createUserDocument(User user) async {
    if (user.id == null || user.id!.isEmpty) {
      print("FirestoreService Error: User ID is null or empty. Cannot create document without ID.");
      return;
    }
    print("FirestoreService: Creating/Updating user document for ID: ${user.id} with data: ${user.toMap()}"); // Log
    try {
      await _db.collection(_usersCollection).doc(user.id).set(user.toMap());
      print("FirestoreService: User document successfully set for ID: ${user.id}"); // Log
    } catch (e) {
      print("FirestoreService: Error setting user document for ID ${user.id}: $e"); // Log
      rethrow;
    }
  }

  Future<User?> getUserById(String userId) async {
    print("FirestoreService: Attempting to get user by ID: $userId"); // Log
    if (userId.isEmpty) {
      print("FirestoreService Error: getUserById called with empty userId.");
      return null;
    }
    try {
      final doc = await _db.collection(_usersCollection).doc(userId).get();
      if (doc.exists && doc.data() != null) {
        print("FirestoreService: User document found for $userId. Data: ${doc.data()}"); // Log
        return User.fromMap(doc.data()! as Map<String, dynamic>, doc.id);
      } else {
        print("FirestoreService: No user document found in Firestore for $userId"); // Log
        return null;
      }
    } catch (e) {
      print("FirestoreService: Error fetching user by ID $userId: $e"); // Log
      return null;
    }
  }

  Future<List<User>> getAllUsers() async {
    print("FirestoreService: Attempting to get all users."); // Log
    try {
      final snapshot = await _db.collection(_usersCollection).orderBy('username').get();
      final users = snapshot.docs
          .where((doc) => doc.data() != null)
          .map((doc) => User.fromMap(doc.data()! as Map<String, dynamic>, doc.id))
          .toList();
      print("FirestoreService: Fetched ${users.length} users."); // Log
      return users;
    } catch (e) {
      print("FirestoreService: Error fetching all users: $e"); // Log
      return [];
    }
  }

  Future<void> updateUser(User user) async {
    if (user.id == null || user.id!.isEmpty) {
      print("FirestoreService Error: User ID is null or empty. Cannot update document without ID.");
      return;
    }
    print("FirestoreService: Updating user document for ID: ${user.id} with data: ${user.toMap()}"); // Log
    try {
      await _db.collection(_usersCollection).doc(user.id).update(user.toMap());
      print("FirestoreService: User document successfully updated for ID: ${user.id}"); // Log
    } catch (e) {
      print("FirestoreService: Error updating user document for ID ${user.id}: $e"); // Log
      rethrow;
    }
  }

  Future<void> deleteUser(String userId) async {
    print("FirestoreService: Attempting to delete user data for ID: $userId"); // Log
    try {
      await _db.collection(_usersCollection).doc(userId).delete();
      print("FirestoreService: User document deleted from Firestore for ID: $userId"); // Log

      fb_auth.User? currentAuthUser = _auth.currentUser;
      if (currentAuthUser != null && currentAuthUser.uid == userId) {
        print("FirestoreService: Attempting to delete user from Firebase Auth: $userId"); // Log
        try {
          await currentAuthUser.delete();
          print("FirestoreService: User deleted from Firebase Auth."); // Log
        } on fb_auth.FirebaseAuthException catch (e) {
          print("FirestoreService: Error deleting user from Firebase Auth (re-authentication might be required): ${e.message}"); // Log
        }
      } else if (currentAuthUser == null) {
        print("FirestoreService: Cannot delete from Auth: No user is currently signed in."); // Log
      } else {
        print("FirestoreService: Cannot delete from Auth: The user to delete ($userId) is not the currently signed-in user (${currentAuthUser.uid}). This operation usually requires admin privileges."); // Log
      }
    } catch (e) {
      print("FirestoreService: Error deleting user data for ID $userId: $e"); // Log
      rethrow;
    }
  }

  // --- Métodos para Órdenes de Trabajo (Firestore) ---
  // (He añadido algunos logs básicos aquí también, puedes expandirlos si es necesario)

  Future<String> createWorkOrder(WorkOrder order) async {
    print("FirestoreService: Creating work order for client: ${order.clientName}"); // Log
    final Map<String, dynamic> orderData = order.toMap();
    if (orderData['createdAt'] == null) {
      orderData['createdAt'] = FieldValue.serverTimestamp();
    }
    orderData['updatedAt'] = FieldValue.serverTimestamp(); // Siempre actualizar esto

    try {
      final docRef = await _db.collection(_workOrdersCollection).add(orderData);
      print("FirestoreService: Work order created with ID: ${docRef.id}"); // Log
      return docRef.id;
    } catch (e) {
      print("FirestoreService: Error creating work order: $e"); // Log
      rethrow;
    }
  }

  Future<void> updateWorkOrder(WorkOrder order) async {
    if (order.id == null || order.id!.isEmpty) {
      print("FirestoreService Error: WorkOrder ID is null or empty. Cannot update document without ID.");
      return;
    }
    print("FirestoreService: Updating work order with ID: ${order.id}"); // Log
    final Map<String, dynamic> orderData = order.toMap();
    orderData['updatedAt'] = FieldValue.serverTimestamp();

    try {
      await _db.collection(_workOrdersCollection).doc(order.id).update(orderData);
      print("FirestoreService: Work order updated successfully for ID: ${order.id}"); // Log
    } catch (e) {
      print("FirestoreService: Error updating work order ID ${order.id}: $e"); // Log
      rethrow;
    }
  }

  Future<void> deleteWorkOrder(String workOrderId) async {
    if (workOrderId.isEmpty) {
      print("FirestoreService Error: WorkOrder ID is empty. Cannot delete.");
      return;
    }
    print("FirestoreService: Deleting work order with ID: $workOrderId"); // Log
    try {
      await _db.collection(_workOrdersCollection).doc(workOrderId).delete();
      print("FirestoreService: Work order deleted successfully for ID: $workOrderId"); // Log
    } catch (e) {
      print("FirestoreService: Error deleting work order ID $workOrderId: $e"); // Log
      rethrow;
    }
  }

  Future<WorkOrder?> getWorkOrderById(String orderId) async {
    if (orderId.isEmpty) {
      print("FirestoreService Error: WorkOrder ID is empty. Cannot fetch.");
      return null;
    }
    print("FirestoreService: Fetching work order by ID: $orderId"); // Log
    try {
      DocumentSnapshot doc = await _db.collection(_workOrdersCollection).doc(orderId).get();
      if (doc.exists && doc.data() != null) {
        print("FirestoreService: Work order found for ID: $orderId"); // Log
        return WorkOrder.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      } else {
        print("FirestoreService: No work order found for ID: $orderId"); // Log
        return null;
      }
    } catch (e) {
      print("FirestoreService: Error fetching work order by ID $orderId: $e"); // Log
      return null;
    }
  }

  Future<List<WorkOrder>> getWorkOrders({String? userId}) async {
    // --- DEBUG PRINTS ---
    print("*****************************************************");
    print("FirestoreService.getWorkOrders(): Iniciando...");
    print("FirestoreService: userId recibido como parámetro = $userId");
    // --- FIN DEBUG PRINTS ---

    try {
      // CONFIRMA EL NOMBRE DE LA COLECCIÓN AQUÍ - DEBE SER 'work_orders' si tus reglas usan eso
      Query query = _db.collection('work_orders').orderBy('createdAt', descending: true);
      print("FirestoreService: Nombre de colección usado para la consulta: 'work_orders'"); // DEBUG

      if (userId != null && userId.isNotEmpty) {
        print("FirestoreService: Aplicando filtro: .where('createdByUid', isEqualTo: '$userId')"); // DEBUG
        query = query.where('createdByUid', isEqualTo: userId);
      } else {
        print("FirestoreService: No se aplica filtro por UID (userId es null o vacío - modo admin o error)."); // DEBUG
      }

      final QuerySnapshot snapshot = await query.get();
      print("FirestoreService: Query ejecutada. Documentos obtenidos: ${snapshot.docs.length}"); // DEBUG

      if (snapshot.docs.isEmpty && userId != null) {
        print("FirestoreService: ALERTA - No se encontraron documentos para el usuario '$userId' con el filtro actual, aunque el usuario tiene un UID.");
      }

      List<WorkOrder> orders = snapshot.docs.map((doc) {
        // print("FirestoreService: Mapeando documento ${doc.id} con datos: ${doc.data()}"); // DEBUG (Puede ser muy verboso)
        return WorkOrder.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();

      print("FirestoreService.getWorkOrders(): Finalizado. Órdenes parseadas: ${orders.length}");
      print("*****************************************************");
      return orders;

    } catch (e, stackTrace) { // Captura también el stackTrace
      print("Error catastrófico en FirestoreService.getWorkOrders: $e"); // DEBUG
      print("Stack trace: $stackTrace"); // DEBUG
      print("*****************************************************");
      throw Exception('Error al obtener las órdenes de trabajo: ${e.toString()}');
    }
  }

  Stream<List<WorkOrder>> getWorkOrdersStream({String? userId}) {
    print("FirestoreService: Initializing work orders stream. UserID filter: $userId"); // Log
    Query query = _db.collection(_workOrdersCollection).orderBy('createdAt', descending: true);

    if (userId != null && userId.isNotEmpty) {
      query = query.where('createdByUid', isEqualTo: userId);
    }

    return query.snapshots().map((snapshot) {
      print("FirestoreService: Work orders stream received ${snapshot.docs.length} documents."); // Log
      return snapshot.docs
          .where((doc) => doc.data() != null)
          .map((doc) {
        return WorkOrder.fromMap(doc.data()! as Map<String, dynamic>, doc.id);
      })
          .toList();
    }).handleError((error) {
      print('FirestoreService: Error in work orders stream: $error'); // Log
      return <WorkOrder>[];
    });
  }
}