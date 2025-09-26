import 'package:cloud_firestore/cloud_firestore.dart'; // Necesario para Timestamp
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// import 'package:shared_preferences/shared_preferences.dart'; // _checkIfAdmin aún lo usa
import '../models/work_order.dart';
// Asegúrate de que tus modelos SparePart y LaborDetail estén preparados para Firestore
// (ej. constructores fromMap y toMap que manejen IDs opcionales y Timestamps)
import '../firebase_core/firestore_service.dart'; // ASUME QUE ESTE ES TU SERVICIO DE FIRESTORE
import '../models/user.dart' as AppUser; // Si necesitas datos del usuario actual
import '../utils/constants.dart';
import '../widgets/custom_logo.dart'; // Asumo que este widget existe // Y que OrderHeader está definido o es este

class CreateOrderScreen extends StatefulWidget {
  final WorkOrder? orderToEdit; // orderToEdit ahora debería tener un ID de Firestore si es una edición

  const CreateOrderScreen({super.key, this.orderToEdit});

  @override
  _CreateOrderScreenState createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  late FirestoreService _firestoreService; // Instancia del servicio

  // Controllers
  final _clientNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _engineNumberController = TextEditingController();
  final _yearController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _plateController = TextEditingController();
  final _authorizedByController = TextEditingController();
  final _observationsController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  List<SparePart> _spareParts = [];
  List<LaborDetail> _laborDetails = [];

  Map<int, TextEditingController> _sparePartPriceControllers = {};
  Map<int, TextEditingController> _laborDetailPriceControllers = {};
  Map<int, TextEditingController> _sparePartQuantityControllers = {};

  bool _isLoading = false;
  bool _isAdmin = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _firestoreService = FirestoreService();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _fetchCurrentUserAndAdminStatus();
    if (widget.orderToEdit != null) {
      _loadOrderData();
    }
    _initializeQuantityControllers(); // Asegúrate de que los controllers de cantidad se inicialicen
    if (_isAdmin) {
      _initializePriceControllers(); // Y los de precio si es admin
    }
    if (mounted) setState(() {});
  }

  Future<void> _fetchCurrentUserAndAdminStatus() async {
    _currentUserId = _firestoreService.getCurrentUserId();
    if (_currentUserId != null) {
      AppUser.User? currentUser = await _firestoreService.getUserById(_currentUserId!);
      if (currentUser != null && mounted) {
        setState(() {
          _isAdmin = currentUser.isAdmin;
        });
      }
    }
  }

  void _initializeQuantityControllers() {
    // Limpia los controllers existentes para evitar memory leaks si se llama múltiples veces
    _sparePartQuantityControllers.forEach((_, controller) => controller.dispose());
    _sparePartQuantityControllers.clear();
    for (int i = 0; i < _spareParts.length; i++) {
      _sparePartQuantityControllers[i] =
          TextEditingController(text: _spareParts[i].quantity.toString());
    }
  }

  void _initializePriceControllers() {
    // Limpia los controllers existentes
    _sparePartPriceControllers.forEach((_, controller) => controller.dispose());
    _sparePartPriceControllers.clear();
    for (int i = 0; i < _spareParts.length; i++) {
      _sparePartPriceControllers[i] =
          TextEditingController(text: _spareParts[i].price.toStringAsFixed(2));
    }

    _laborDetailPriceControllers.forEach((_, controller) => controller.dispose());
    _laborDetailPriceControllers.clear();
    for (int i = 0; i < _laborDetails.length; i++) {
      _laborDetailPriceControllers[i] =
          TextEditingController(text: _laborDetails[i].price.toStringAsFixed(2));
    }
  }


  @override
  void dispose() {
    _clientNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _engineNumberController.dispose();
    _yearController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _plateController.dispose();
    _authorizedByController.dispose();
    _observationsController.dispose();
    _sparePartPriceControllers.forEach((_, controller) => controller.dispose());
    _laborDetailPriceControllers.forEach((_, controller) => controller.dispose());
    _sparePartQuantityControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  void _loadOrderData() {
    final order = widget.orderToEdit!;
    _clientNameController.text = order.clientName;
    _addressController.text = order.address;
    _phoneController.text = order.phone;
    _selectedDate = (order.date as Timestamp).toDate();
    _engineNumberController.text = order.engineNumber;
    _yearController.text = order.year;
    _brandController.text = order.brand;
    _modelController.text = order.model;
    _plateController.text = order.plate;
    _authorizedByController.text = order.authorizedBy;
    _observationsController.text = order.observations;

    _spareParts = List.from(order.spareParts);
    _laborDetails = List.from(order.laborDetails);

    // No es necesario llamar a _initializeQuantityControllers y _initializePriceControllers aquí
    // si _initializeScreen ya lo hace después de _loadOrderData.
    // Solo asegúrate de que el setState en _initializeScreen refresque la UI.
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _addSparePart() {
    showDialog(
      context: context,
      builder: (context) {
        final descController = TextEditingController();
        final quantityController = TextEditingController(text: '1');
        // El priceController se crea solo si es admin
        TextEditingController? priceController = _isAdmin ? TextEditingController(text: '0.00') : null;

        return AlertDialog(
          title: const Text('Agregar Repuesto'),
          content: SingleChildScrollView(
            child: Form( // <- Es buena práctica tener un Form aquí también para validación local del diálogo
              // key: _dialogFormKey, // Si necesitas una validación más compleja
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: descController,
                    decoration: const InputDecoration(labelText: 'Descripción'),
                    validator: (value) => (value == null || value.isEmpty) ? 'Requerido' : null,
                  ),
                  TextFormField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Cantidad'),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Requerido';
                      if (int.tryParse(value) == null || int.parse(value) <= 0) return 'Cantidad inválida';
                      return null;
                    },
                  ),
                  if (_isAdmin && priceController != null) // Verifica que priceController no sea null
                    TextFormField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Precio Unitario'),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Requerido';
                        if (double.tryParse(value) == null || double.parse(value) < 0) return 'Precio inválido';
                        return null;
                      },
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
              onPressed: () {
                // Validar el formulario del diálogo si tienes una _dialogFormKey
                // if (!_dialogFormKey.currentState!.validate()) return;

                final String description = descController.text;
                final int? quantity = int.tryParse(quantityController.text);
                final double? priceFromDialog = _isAdmin && priceController != null
                    ? double.tryParse(priceController.text)
                    : 0.0; // Precio por defecto si no es admin o no se ingresa

                if (description.isNotEmpty && quantity != null && quantity > 0 && (_isAdmin ? priceFromDialog != null : true)) {
                  final newPart = SparePart(
                    description: description,
                    quantity: quantity,
                    price: _isAdmin ? (priceFromDialog ?? 0.0) : 0.0,
                  );
                  setState(() {
                    _spareParts.add(newPart);
                    int newIndex = _spareParts.length - 1;
                    _sparePartQuantityControllers[newIndex] =
                        TextEditingController(text: newPart.quantity.toString());
                    if (_isAdmin) {
                      _sparePartPriceControllers[newIndex] =
                          TextEditingController(text: newPart.price.toStringAsFixed(2));
                    }
                  });
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Por favor, ingrese datos válidos.'))
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );
  }

  void _addLaborDetail() {
    showDialog(
      context: context,
      builder: (context) {
        final descController = TextEditingController();
        TextEditingController? priceController = _isAdmin ? TextEditingController(text: '0.00') : null;

        return AlertDialog(
          title: const Text('Agregar Mano de Obra'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                  validator: (value) => (value == null || value.isEmpty) ? 'Requerido' : null,
                ),
                if (_isAdmin && priceController != null)
                  TextFormField(
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Precio'),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Requerido';
                      if (double.tryParse(value) == null || double.parse(value) < 0) return 'Precio inválido';
                      return null;
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final String description = descController.text;
                final double? priceFromDialog = _isAdmin && priceController != null
                    ? double.tryParse(priceController.text)
                    : 0.0;

                if (description.isNotEmpty && (_isAdmin ? priceFromDialog != null : true)) {
                  final newLabor = LaborDetail(
                    description: description,
                    price: _isAdmin ? (priceFromDialog ?? 0.0) : 0.0,
                  );
                  setState(() {
                    _laborDetails.add(newLabor);
                    if (_isAdmin) {
                      _laborDetailPriceControllers[_laborDetails.length - 1] =
                          TextEditingController(text: newLabor.price.toStringAsFixed(2));
                    }
                  });
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Por favor, ingrese datos válidos.'))
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSparePartsList() {
    if (_spareParts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Center(
          child: Text(
            'No hay repuestos agregados.',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ),
      );
    }
    return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _spareParts.length,
        itemBuilder: (context, index) {
          final part = _spareParts[index];
          // Asegúrate que el controller exista antes de usarlo
          if (!_sparePartQuantityControllers.containsKey(index)) {
            _sparePartQuantityControllers[index] = TextEditingController(text: part.quantity.toString());
          }
          if (_isAdmin && !_sparePartPriceControllers.containsKey(index)) {
            _sparePartPriceControllers[index] = TextEditingController(text: part.price.toStringAsFixed(2));
          }

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6.0),
            elevation: 2.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    initialValue: part.description,
                    decoration: InputDecoration(
                      labelText: 'Descripción Repuesto',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    onChanged: (value) {
                      // Actualiza el objeto en la lista directamente
                      _spareParts[index] = part.copyWith(description: value);
                    },
                    validator: (value) => (value == null || value.isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _sparePartQuantityControllers[index],
                          decoration: InputDecoration(
                            labelText: 'Cantidad',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 15),
                          onChanged: (value) {
                            final newQuantity = int.tryParse(value);
                            if (newQuantity != null) {
                              _spareParts[index] = part.copyWith(quantity: newQuantity);
                              if (_isAdmin && mounted) setState(() {}); // Para actualizar totales si es admin
                            }
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Requerido';
                            final val = int.tryParse(value);
                            if (val == null || val <= 0) return 'Inválido';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: _isAdmin
                            ? TextFormField(
                          controller: _sparePartPriceControllers[index],
                          decoration: InputDecoration(
                            labelText: 'Precio U. (\$)',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(fontSize: 15),
                          onChanged: (value) {
                            // El precio se tomará del controller en _saveOrder
                            // pero actualizamos el estado para recalcular totales en la UI
                            if (mounted) setState(() {});
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Requerido';
                            final val = double.tryParse(value);
                            if (val == null || val < 0) return 'Inválido';
                            return null;
                          },
                        )
                            : (part.price > 0 // Muestra el precio si no es admin y el precio es mayor a 0
                            ? InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Precio U. (\$)',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                          ),
                          child: Text(
                            '\$${part.price.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 15, color: Colors.black87),
                          ),
                        )
                            : const SizedBox.shrink() // No muestra nada si el precio es 0 y no es admin
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0, top: 4.0),
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 26),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Eliminar repuesto',
                          onPressed: () {
                            setState(() {
                              _spareParts.removeAt(index);
                              // Ya no es necesario llamar a _reindexControllersAfterDelete
                              // si _initializeQuantityControllers y _initializePriceControllers
                              // se llaman correctamente y limpian los controllers antiguos.
                              _initializeQuantityControllers();
                              if (_isAdmin) {
                                _initializePriceControllers();
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
  }

  Widget _buildLaborDetailsList() {
    if (_laborDetails.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Center(
          child: Text(
            'No hay mano de obra agregada.',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ),
      );
    }
    return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _laborDetails.length,
        itemBuilder: (context, index) {
          final labor = _laborDetails[index];
          // Asegúrate que el controller exista antes de usarlo
          if (_isAdmin && !_laborDetailPriceControllers.containsKey(index)) {
            _laborDetailPriceControllers[index] = TextEditingController(text: labor.price.toStringAsFixed(2));
          }

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6.0),
            elevation: 2.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: labor.description,
                          decoration: InputDecoration(
                            labelText: 'Descripción Mano de Obra',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                          maxLines: null,
                          textInputAction: TextInputAction.next,
                          onChanged: (value) {
                            _laborDetails[index] = labor.copyWith(description: value);
                          },
                          validator: (value) => (value == null || value.isEmpty) ? 'Requerido' : null,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 26),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Eliminar mano de obra',
                          onPressed: () {
                            setState(() {
                              _laborDetails.removeAt(index);
                              if (_isAdmin) {
                                _initializePriceControllers(); // Re-inicializa solo los de precio
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _isAdmin
                      ? TextFormField(
                    controller: _laborDetailPriceControllers[index],
                    decoration: InputDecoration(
                      labelText: 'Costo (\$)',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 15),
                    onChanged: (value) {
                      if (mounted) setState(() {}); // Para actualizar totales
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Requerido';
                      final val = double.tryParse(value);
                      if (val == null || val < 0) return 'Inválido';
                      return null;
                    },
                  )
                      : (labor.price > 0
                      ? InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Costo (\$)',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                    ),
                    child: Text(
                      '\$${labor.price.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 15, color: Colors.black87),
                    ),
                  )
                      : const SizedBox.shrink()),
                ],
              ),
            ),
          );
        });
  }

  // ELIMINADO: void _reindexControllersAfterDelete() porque la reinicialización completa es más simple.

  Future<void> _saveOrder() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, corrija los errores en el formulario.')),
      );
      return;
    }
    if (_spareParts.isEmpty && _laborDetails.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debe agregar al menos un repuesto o mano de obra.')),
      );
      return;
    }

    if (_currentUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Usuario no autenticado.')),
        );
      }
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    List<SparePart> finalSpareParts = [];
    for (int i = 0; i < _spareParts.length; i++) {
      final currentPart = _spareParts[i];
      double price = currentPart.price; // Precio por defecto
      int quantity = currentPart.quantity; // Cantidad por defecto

      // Obtener cantidad del controller (ya debería estar actualizada en el objeto currentPart por su onChanged)
      // quantity = int.tryParse(_sparePartQuantityControllers[i]?.text ?? currentPart.quantity.toString()) ?? currentPart.quantity;


      if (_isAdmin && _sparePartPriceControllers.containsKey(i)) {
        price = double.tryParse(_sparePartPriceControllers[i]!.text) ?? currentPart.price;
      }
      finalSpareParts.add(SparePart(
        description: currentPart.description,
        quantity: quantity, // Usar la cantidad del objeto que ya fue actualizada
        price: price,
      ));
    }

    List<LaborDetail> finalLaborDetails = [];
    for (int i = 0; i < _laborDetails.length; i++) {
      final currentLabor = _laborDetails[i];
      double price = currentLabor.price;
      if (_isAdmin && _laborDetailPriceControllers.containsKey(i)) {
        price = double.tryParse(_laborDetailPriceControllers[i]!.text) ?? currentLabor.price;
      }
      finalLaborDetails.add(LaborDetail(
        description: currentLabor.description,
        price: price,
      ));
    }

    final order = WorkOrder(
      id: widget.orderToEdit?.id,
      clientName: _clientNameController.text,
      address: _addressController.text,
      phone: _phoneController.text,
      date: Timestamp.fromDate(_selectedDate),
      engineNumber: _engineNumberController.text,
      year: _yearController.text,
      brand: _brandController.text,
      model: _modelController.text,
      plate: _plateController.text,
      spareParts: finalSpareParts,
      laborDetails: finalLaborDetails,
      authorizedBy: _authorizedByController.text,
      observations: _observationsController.text,
      userId: widget.orderToEdit?.userId ?? _currentUserId!,
      userName: widget.orderToEdit?.userName,
      createdAt: widget.orderToEdit?.createdAt, // FirestoreService debe manejar la primera creación
      // updatedAt: FieldValue.serverTimestamp(), // Si quieres actualizar este campo siempre
    );

    try {
      if (widget.orderToEdit == null) {
        await _firestoreService.createWorkOrder(order);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Orden creada exitosamente')));
      } else {
        await _firestoreService.updateWorkOrder(order);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Orden actualizada exitosamente')));
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar la orden: ${e.toString()}')),
        );
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    double currentTotalSpareParts = 0;
    double currentTotalLabor = 0;

    if (_isAdmin) {
      for (int i = 0; i < _spareParts.length; i++) {
        double price = 0.0;
        int quantity = 0;

        // Tomar cantidad del objeto _spareParts (que es actualizado por el controller de cantidad)
        quantity = _spareParts[i].quantity;

        // Tomar precio del controller de precio si existe y es admin
        if (_sparePartPriceControllers.containsKey(i) && _sparePartPriceControllers[i] != null) {
          price = double.tryParse(_sparePartPriceControllers[i]!.text) ?? _spareParts[i].price;
        } else {
          price = _spareParts[i].price; // Fallback al precio del objeto si no hay controller (no debería pasar si es admin)
        }
        currentTotalSpareParts += price * quantity;
      }

      for (int i = 0; i < _laborDetails.length; i++) {
        double price = 0.0;
        // Tomar precio del controller de precio si existe y es admin
        if (_laborDetailPriceControllers.containsKey(i) && _laborDetailPriceControllers[i] != null) {
          price = double.tryParse(_laborDetailPriceControllers[i]!.text) ?? _laborDetails[i].price;
        } else {
          price = _laborDetails[i].price; // Fallback al precio del objeto
        }
        currentTotalLabor += price;
      }
    }
    // Si no es admin, los totales deben ser 0 o basarse en los precios ya guardados (si los muestras)
    // Para este caso, los totales solo se muestran para admin, así que esto está bien.

    final currentGrandTotal = currentTotalSpareParts + currentTotalLabor;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.orderToEdit == null ? 'Nueva Orden de Trabajo' : 'Editar Orden de Trabajo',
          style: TextStyle(color: AppColors.white),
        ),
        backgroundColor: AppColors.primaryBlue,
        iconTheme: IconThemeData(color: AppColors.white),
      ),
      body: _currentUserId == null && widget.orderToEdit == null
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Aquí asegúrate que OrderHeader esté definido. Podría ser tu CustomLogo.
            // Si CustomLogo es solo un logo, quizás quieras un widget específico OrderHeader.
            if (CustomLogo != null) const OrderHeader(), // o const OrderHeader(),
            const SizedBox(height: 20),
            _buildSectionTitle('Datos del Cliente'),
            _buildTextField(_clientNameController, 'Nombre del Cliente', Icons.person),
            _buildTextField(_addressController, 'Dirección', Icons.location_on),
            _buildTextField(_phoneController, 'Celular/Teléfono', Icons.phone, keyboardType: TextInputType.phone),

            const SizedBox(height: 20),
            _buildSectionTitle('Información del Vehículo'),
            _buildDateField(),
            _buildTextField(_engineNumberController, 'Número de Motor', Icons.settings),
            _buildTextField(_yearController, 'Año del Vehículo', Icons.calendar_today, keyboardType: TextInputType.number),
            _buildTextField(_brandController, 'Marca', Icons.directions_car),
            _buildTextField(_modelController, 'Modelo', Icons.drive_eta),
            _buildTextField(_plateController, 'Placa (Patente)', Icons.confirmation_number),

            const SizedBox(height: 20),
            _buildSectionTitle('Repuestos'),
            _buildSparePartsList(),
            ElevatedButton.icon(
              onPressed: _addSparePart,
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Agregar Repuesto'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondaryBlue,
                foregroundColor: AppColors.white,
              ),
            ),

            const SizedBox(height: 20),
            _buildSectionTitle('Mano de Obra'),
            _buildLaborDetailsList(),
            ElevatedButton.icon(
              onPressed: _addLaborDetail,
              icon: const Icon(Icons.build_circle),
              label: const Text('Agregar Mano de Obra'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondaryBlue,
                foregroundColor: AppColors.white,
              ),
            ),

            if (_isAdmin) ...[
              const SizedBox(height: 20),
              _buildSectionTitle('Totales'),
              _buildTotalSection(currentTotalSpareParts, currentTotalLabor, currentGrandTotal),
            ],

            const SizedBox(height: 20),
            _buildTextField(_authorizedByController, 'Trabajo Autorizado por', Icons.person_pin_circle),
            _buildTextField(
              _observationsController,
              'Observaciones Adicionales',
              Icons.notes,
              maxLines: 3,
              isOptional: true,
            ),

            const SizedBox(height: 30),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                icon: Icon(
                  _isLoading
                      ? Icons.hourglass_empty // Usar un icono diferente para loading si quieres
                      : (widget.orderToEdit == null ? Icons.save : Icons.update),
                  color: AppColors.white,
                ),
                onPressed: _isLoading ? null : _saveOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: AppColors.white,
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                label: _isLoading
                    ? SizedBox( // Para centrar el CircularProgressIndicator
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: AppColors.white,
                    strokeWidth: 3,
                  ),
                )
                    : Text(
                  widget.orderToEdit == null ? 'Crear Orden' : 'Actualizar Orden',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  // ... (resto del código de _CreateOrderScreenState, incluyendo el método build) ...

  // --- MÉTODOS AUXILIARES PARA EL BUILD METHOD ---
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold, // Añadido
          color: AppColors.primaryBlue, // Añadido (asegúrate que AppColors.primaryBlue esté definido)
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller,
      String label,
      IconData icon, {
        int maxLines = 1,
        TextInputType? keyboardType,
        bool isOptional = false,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.primaryBlue),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
          filled: true,
          fillColor: AppColors.white.withOpacity(0.8), // O un color de fondo sutil
        ),
        validator: (value) {
          if (!isOptional && (value == null || value.isEmpty)) {
            return 'Este campo es requerido.';
          }
          if (label == 'Año del Vehículo' && value != null && value.isNotEmpty) {
            final year = int.tryParse(value);
            if (year == null || year < 1900 || year > DateTime.now().year + 1) {
              return 'Año inválido.';
            }
          }
          if (keyboardType == TextInputType.phone && value != null && value.isNotEmpty && !RegExp(r'^[0-9\s\-\+\(\)]+$').hasMatch(value)) {
            return 'Teléfono inválido.';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDateField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: _selectDate,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Fecha de la Orden',
            prefixIcon: Icon(Icons.date_range, color: AppColors.primaryBlue),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
            filled: true,
            fillColor: AppColors.white.withOpacity(0.8),
          ),
          child: Text(
            DateFormat('dd/MM/yyyy').format(_selectedDate), // Asegúrate de tener 'intl' importado
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildTotalSection(double totalSpareParts, double totalLabor, double total) {
    // Este método ya lo tenías bien definido en el código que me pasaste antes.
    // Solo lo incluyo por completitud.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
          color: AppColors.lightBlue.withOpacity(0.15), // Asegúrate que AppColors.lightBlue esté definido
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3))
      ),
      child: Column(
        children: [
          _buildTotalRow('Total Repuestos:', totalSpareParts),
          const SizedBox(height: 8),
          _buildTotalRow('Total Mano de Obra:', totalLabor),
          Divider(thickness: 1, height: 24, color: AppColors.primaryBlue.withOpacity(0.5)),
          _buildTotalRow('TOTAL GENERAL:', total, isGrandTotal: true),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool isGrandTotal = false}) {
    // Este método también ya lo tenías bien.
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isGrandTotal ? 17 : 15,
            fontWeight: isGrandTotal ? FontWeight.bold : FontWeight.normal,
            color: isGrandTotal ? AppColors.primaryBlue : Colors.black87,
          ),
        ),
        Text(
          '\$${amount.toStringAsFixed(2)}', // Formato de moneda
          style: TextStyle(
            fontSize: isGrandTotal ? 17 : 15,
            fontWeight: FontWeight.bold,
            color: isGrandTotal ? AppColors.primaryBlue : Colors.black87,
          ),
        ),
      ],
    );
  }

} // Esta es la llave de cierre de la clase _CreateOrderScreenState