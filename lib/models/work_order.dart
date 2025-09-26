// lib/models/work_order.dart

import 'package:cloud_firestore/cloud_firestore.dart'; // Necesario para Timestamp y FieldValue

// --- SparePart Class (Adaptada para Firestore) ---
class SparePart {
  // No necesita 'id' si solo vive dentro de WorkOrder y no tiene su propia colección.
  // Si en el futuro necesitaras consultarlos individualmente o referenciarlos
  // desde otro lugar, podrías añadir un 'id' único (ej. generado con uuid).
  // Por ahora, lo mantenemos simple.
  final String description;
  final int quantity;
  final double price;
  // 'workOrderId' eliminado ya que estará anidado.

  SparePart({
    required this.description,
    required this.quantity,
    required this.price,
  });

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'quantity': quantity,
      'price': price,
    };
  }

  factory SparePart.fromMap(Map<String, dynamic> map) {
    return SparePart(
      description: map['description'] ?? '',
      quantity: map['quantity'] ?? 0,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  SparePart copyWith({
    String? description,
    int? quantity,
    double? price,
  }) {
    return SparePart(
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
    );
  }
}

// --- LaborDetail Class (Adaptada para Firestore) ---
class LaborDetail {
  // Similar a SparePart, no 'id' si está anidado.
  final String description;
  final double price;
  // 'workOrderId' eliminado.

  LaborDetail({
    required this.description,
    required this.price,
  });

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'price': price,
    };
  }

  factory LaborDetail.fromMap(Map<String, dynamic> map) {
    return LaborDetail(
      description: map['description'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  LaborDetail copyWith({
    String? description,
    double? price,
  }) {
    return LaborDetail(
      description: description ?? this.description,
      price: price ?? this.price,
    );
  }
}

// --- WorkOrder Class (Adaptada para Firestore) ---
class WorkOrder {
  final String? id; // ID del documento de Firestore (String)
  final String clientName;
  final String address;
  final String phone;
  final Timestamp date; // Firestore Timestamp
  final String engineNumber;
  final String year;
  final String brand;
  final String model;
  final String plate;
  final List<SparePart> spareParts; // Lista de objetos SparePart
  final List<LaborDetail> laborDetails; // Lista de objetos LaborDetail
  final String authorizedBy;
  final String observations;
  final String userId; // ID del usuario de Firebase Auth (String)
  final String? userName;
  final Timestamp? createdAt; // Firestore Timestamp, puede ser null al crear
  final Timestamp? updatedAt; // Opcional: para registrar cuándo se actualizó

  WorkOrder({
    this.id,
    required this.clientName,
    required this.address,
    required this.phone,
    required this.date,
    required this.engineNumber,
    required this.year,
    required this.brand,
    required this.model,
    required this.plate,
    required this.spareParts,
    required this.laborDetails,
    required this.authorizedBy,
    required this.observations,
    required this.userId,
    this.userName,
    this.createdAt, // Permitir que sea null inicialmente
    this.updatedAt, // Permitir que sea null inicialmente
  });
  DateTime get dateAsDateTime => date.toDate();
  DateTime? get createdAtAsDateTime => createdAt?.toDate();
  DateTime? get updatedAtAsDateTime => updatedAt?.toDate();

  double get totalSpareParts =>
      spareParts.fold(0, (sum, part) => sum + (part.price * part.quantity));

  double get totalLabor =>
      laborDetails.fold(0, (sum, labor) => sum + labor.price);

  double get total => totalSpareParts + totalLabor;

  Map<String, dynamic> toMap() {
    return {
      // 'id' no se incluye, es el ID del documento
      'clientName': clientName,
      'address': address,
      'phone': phone,
      'date': date, // Se guarda directamente como Timestamp
      'engineNumber': engineNumber,
      'year': year,
      'brand': brand,
      'model': model,
      'plate': plate,
      'spareParts': spareParts.map((part) => part.toMap()).toList(), // Lista de Maps
      'laborDetails': laborDetails.map((labor) => labor.toMap()).toList(), // Lista de Maps
      'authorizedBy': authorizedBy,
      'observations': observations,
      //'userId': userId,
      'createdByUid': userId, // <- CAMBIA ESTA LÍNEA para usar la clave esperada por las reglas
      'userName': userName,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(), // Establece la hora del servidor si es nueva
      'updatedAt': FieldValue.serverTimestamp(), // Siempre actualiza a la hora del servidor
    };
  }

  factory WorkOrder.fromMap(Map<String, dynamic> map, String documentId) {
    final String effectiveUserId = map['createdByUid'] as String? ?? map['userId'] as String? ?? '';
    // Es buena práctica añadir un log o manejo si effectiveUserId es vacío y no debería serlo:
    if (effectiveUserId.isEmpty && (map['createdByUid'] != null || map['userId'] != null)) {
      // Esto podría indicar un problema de datos, ej. el campo existe pero es un string vacío.
      print("Advertencia: WorkOrder.fromMap - El campo UID ('createdByUid' o 'userId') está presente pero vacío en el documento $documentId.");
    } else if (effectiveUserId.isEmpty) {
      // Esto significa que ninguno de los campos UID estaba presente en el mapa.
      // Dependiendo de tu lógica, esto podría ser un error o un caso esperado (aunque raro si lo requieres).
      print("Error Crítico: WorkOrder.fromMap - Faltan 'createdByUid' y 'userId' en el documento $documentId. Se usará un string vacío.");
      // Considera si aquí deberías lanzar una excepción en lugar de usar '' si un userId es absolutamente crítico.
      // throw FormatException("Falta userId en los datos del documento $documentId");
    }
    return WorkOrder(
      id: documentId,
      clientName: map['clientName'] ?? '',
      address: map['address'] ?? '',
      phone: map['phone'] ?? '',
      date: map['date'] as Timestamp? ?? Timestamp.now(),
      engineNumber: map['engineNumber'] ?? '',
      year: map['year'] ?? '',
      brand: map['brand'] ?? '',
      model: map['model'] ?? '',
      plate: map['plate'] ?? '',
      spareParts: (map['spareParts'] as List<dynamic>?)
          ?.map((partMap) => SparePart.fromMap(partMap as Map<String, dynamic>))
          .toList() ??
          [],
      laborDetails: (map['laborDetails'] as List<dynamic>?)
          ?.map((laborMap) => LaborDetail.fromMap(laborMap as Map<String, dynamic>))
          .toList() ??
          [],
      authorizedBy: map['authorizedBy'] ?? '',
      observations: map['observations'] ?? '',
      userId: effectiveUserId, // <--- LÍNEA AÑADIDA/CORREGIDA
      userName: map['userName'] as String?,
      createdAt: map['createdAt'] as Timestamp?,
      updatedAt: map['updatedAt'] as Timestamp?,
    );
  }

  WorkOrder copyWith({
    String? id,
    String? clientName,
    String? address,
    String? phone,
    Timestamp? date,
    String? engineNumber,
    String? year,
    String? brand,
    String? model,
    String? plate,
    List<SparePart>? spareParts,
    List<LaborDetail>? laborDetails,
    String? authorizedBy,
    String? observations,
    String? userId,
    String? userName,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    bool setToNullCreatedAt = false, // Para permitir poner createdAt a null explícitamente si es necesario
    bool setToNullUpdatedAt = false,
  }) {
    return WorkOrder(
      id: id ?? this.id,
      clientName: clientName ?? this.clientName,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      date: date ?? this.date,
      engineNumber: engineNumber ?? this.engineNumber,
      year: year ?? this.year,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      plate: plate ?? this.plate,
      spareParts: spareParts ?? this.spareParts,
      laborDetails: laborDetails ?? this.laborDetails,
      authorizedBy: authorizedBy ?? this.authorizedBy,
      observations: observations ?? this.observations,
      userId: userId ?? this.userId,
      createdAt: setToNullCreatedAt ? null : (createdAt ?? this.createdAt),
      updatedAt: setToNullUpdatedAt ? null : (updatedAt ?? this.updatedAt),
    );
  }
}