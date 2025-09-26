import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Para Timestamp

import '../models/work_order.dart';
import '../models/user.dart'; // Asegúrate que la ruta a tu modelo User sea correcta
import '../firebase_core/firestore_service.dart';
import '../firebase_core/pdf_service.dart';
import '../utils/constants.dart';
import 'order_detail_screen.dart';
import 'create_order_screen.dart';

class ViewOrdersScreen extends StatefulWidget {
  final bool isAdmin;

  const ViewOrdersScreen({super.key, required this.isAdmin});

  @override
  _ViewOrdersScreenState createState() => _ViewOrdersScreenState();
}

class _ViewOrdersScreenState extends State<ViewOrdersScreen> {
  List<WorkOrder> _orders = [];
  bool _isLoading = true;
  String _searchQueryOrders = '';
  List<WorkOrder> _filteredOrders = [];

  final TextEditingController _searchOrdersController = TextEditingController();
  late FirestoreService _firestoreService;

  // Estados para la selección de usuario por el admin
  List<User> _allUsers = [];
  User? _selectedUserForAdmin;
  bool _isLoadingUsers = false;

  // Opción especial para "Ver Todas las Órdenes"
  final User _allOrdersUserSentinel = User(
    id: "all_orders_sentinel",
    username: "Ver Todas las Órdenes",
    email: "", // No relevante
    isAdmin: false, // No relevante
    createdAt: null, // O Timestamp.now() si tu modelo lo requiere
  );

  @override
  void initState() {
    super.initState();
    _firestoreService = FirestoreService();
    _searchOrdersController.addListener(_filterOrders);

    if (widget.isAdmin) {
      _loadUsersForAdmin();
    } else {
      _loadOrders();
    }
  }

  @override
  void dispose() {
    _searchOrdersController.dispose();
    super.dispose();
  }

  String _formatTimestamp(Timestamp? timestamp, String format) {
    if (timestamp == null) return 'N/A';
    return DateFormat(format).format(timestamp.toDate());
  }

  Future<void> _loadUsersForAdmin() async {
    if (!mounted) return;
    setState(() {
      _isLoadingUsers = true;
      _isLoading = true; // Mostrar indicador de carga general mientras se cargan usuarios
    });

    try {
      final usersFromDb = await _firestoreService.getAllUsers();
      print("Usuarios obtenidos de Firestore: ${usersFromDb.length}");
      for (var u in usersFromDb) {
        print("Usuario de DB: ID=${u.id}, Email=${u.email}");
      }

      if (!mounted) return;

      final allOrdersOption = User(
        id: "all_orders_sentinel",
        username: "Ver Todas las Órdenes",
        email: "",
        isAdmin: false,
        createdAt: Timestamp.now(), // Asegúrate que tu modelo User lo maneje
      );

      setState(() {
        _allUsers = [_allOrdersUserSentinel, ...usersFromDb];
        _isLoadingUsers = false;
        // Seleccionar "Ver Todas las Órdenes" por defecto
        _selectedUserForAdmin = _allOrdersUserSentinel;
        _loadOrders(specificUserId: _selectedUserForAdmin!.id);
      });
    } catch (e) {
      if (!mounted) return;
      print("Error al cargar usuarios: $e");
      setState(() {
        _isLoadingUsers = false;
        _isLoading = false;
      });
      print("ViewOrdersScreen: Error al cargar lista de usuarios para admin: ${e.toString()}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar lista de usuarios: ${e.toString()}')),
      );
    }
  }

  Future<void> _loadOrders({String? specificUserId}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    String? userIdForQuery;
    final prefs = await SharedPreferences.getInstance();

    if (widget.isAdmin) {
      if (_selectedUserForAdmin == null && _allUsers.isNotEmpty && !_isLoadingUsers) {
        // Si los usuarios han cargado pero no hay selección, no hacer nada
        // esto previene una carga automática si no se ha seleccionado "Todas" por defecto.
        print("ViewOrdersScreen (Admin): Esperando selección de usuario, no se cargan órdenes aún.");
        setState(() {
          _orders = [];
          _filterOrders();
          _isLoading = false;
        });
        return;
      }
      if (specificUserId == _allOrdersUserSentinel.id) {
        userIdForQuery = null;
      } else {
        userIdForQuery = specificUserId;
      }
    } else {
      userIdForQuery = prefs.getString('userId');
    }

    print("-----------------------------------------------------");
    print("ViewOrdersScreen._loadOrders(): Iniciando carga de órdenes.");
    print("ViewOrdersScreen: widget.isAdmin = ${widget.isAdmin}");
    print("ViewOrdersScreen: UID para la consulta (userIdForQuery) = $userIdForQuery");

    try {
      final ordersFromDb = await _firestoreService.getWorkOrders(userId: userIdForQuery);
      if (!mounted) return;
      setState(() {
        _orders = ordersFromDb;
        _filterOrders();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      print("ViewOrdersScreen: Error al cargar órdenes: ${e.toString()}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar órdenes: ${e.toString()}')),
      );
    }
  }

  void _filterOrders() {
    final query = _searchOrdersController.text.toLowerCase();
    if (!mounted) return;
    setState(() {
      _searchQueryOrders = query;
      if (_searchQueryOrders.isEmpty) {
        _filteredOrders = List.from(_orders);
      } else {
        _filteredOrders = _orders.where((order) {
          return order.clientName.toLowerCase().contains(_searchQueryOrders) ||
              order.plate.toLowerCase().contains(_searchQueryOrders) ||
              (order.id?.toLowerCase().contains(_searchQueryOrders) ?? false);
        }).toList();
      }
    });
  }

  Future<void> _deleteOrder(WorkOrder order) async {
    if (order.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: La orden no tiene un ID válido para eliminar.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: Text(
            '¿Está seguro de que desea eliminar permanentemente la orden de trabajo #${order.id} para ${order.clientName}? Esta acción no se puede deshacer.'),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[700])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Eliminar Definitivamente'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _firestoreService.deleteWorkOrder(order.id!);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Orden #${order.id} eliminada exitosamente.'), backgroundColor: Colors.green),
        );
        _loadOrders(specificUserId: widget.isAdmin ? _selectedUserForAdmin?.id : null);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar orden: ${e.toString()}'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _editOrder(WorkOrder order) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CreateOrderScreen(orderToEdit: order),
      ),
    );
    if (result == true && mounted) {
      _loadOrders(specificUserId: widget.isAdmin ? _selectedUserForAdmin?.id : null);
    }
  }

  Future<void> _exportToPdf(WorkOrder order) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Generando PDF para orden #${order.id}...'), duration: const Duration(seconds: 2)),
    );

    try {
      await PdfService.printOrder(order);
      if (!mounted) return;
      ScaffoldMessenger.of(context).removeCurrentSnackBar(); // Quitar el mensaje de "Generando..."
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF generado y listo para compartir/imprimir.'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).removeCurrentSnackBar(); // Quitar el mensaje de "Generando..." si hubo error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al generar PDF: ${e.toString()}'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String appBarTitle = 'Órdenes de Trabajo';
    if (widget.isAdmin && _selectedUserForAdmin != null) {
      appBarTitle = 'Órdenes de: ${_selectedUserForAdmin!.displayName}';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle, style: const TextStyle(color: AppColors.white)),
        backgroundColor: AppColors.primaryBlue,
        iconTheme: const IconThemeData(color: AppColors.white),
        elevation: 2,
      ),
      body: Column(
        children: [
          if (widget.isAdmin) _buildUserSelectorForAdmin(),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchOrdersController,
              decoration: InputDecoration(
                hintText: 'Buscar por cliente, placa o ID...',
                prefixIcon: const Icon(Icons.search, color: AppColors.primaryBlue),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
                suffixIcon: _searchQueryOrders.isNotEmpty
                    ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey[600]),
                  onPressed: () {
                    _searchOrdersController.clear();
                  },
                )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue)))
                : _buildOrdersListContent(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
                builder: (context) => CreateOrderScreen(
                  // Opcional: Pasar el createdByUid si un usuario específico está seleccionado por el admin
                  // Esto requeriría que CreateOrderScreen acepte `preSelectedUserId` o `createdByUid`
                  // y que el modelo WorkOrder tenga el campo `createdByUid`.
                  // createdByUid: (widget.isAdmin && _selectedUserForAdmin != null && _selectedUserForAdmin!.id != "all_orders_sentinel")
                  //    ? _selectedUserForAdmin!.id
                  //    : null,
                )),
          );
          if (result == true && mounted) {
            _loadOrders(specificUserId: widget.isAdmin ? _selectedUserForAdmin?.id : null);
          }
        },
        label: const Text('Nueva Orden', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add_circle_outline, color: Colors.white),
        backgroundColor: AppColors.accentColor,
        elevation: 4,
      ),
    );
  }

  Widget _buildUserSelectorForAdmin() {
    if (_isLoadingUsers) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        child: Text("Cargando usuarios...", style: TextStyle(color: Colors.grey)),
      );
    }
    if (!widget.isAdmin) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: InkWell(
        onTap: _showUserSelectionDialog,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Filtrar por Usuario',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                _selectedUserForAdmin?.displayName ?? 'Seleccionar un usuario',
                style: TextStyle(
                  color: _selectedUserForAdmin == null ? Colors.grey[600] : Colors.black,
                  fontSize: 16,
                ),
              ),
              const Icon(Icons.arrow_drop_down, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

// --- NUEVO MÉTODO PARA MOSTRAR DIÁLOGO DE SELECCIÓN DE USUARIO ---
  Future<void> _showUserSelectionDialog() async {
    print("--- Usuarios en _allUsers antes del diálogo ---");
    for (var u in _allUsers) {
      print("ID: ${u.id}, Email: ${u.email}, DisplayName: ${u.displayName}");
    }
    print("--- Fin de la lista de _allUsers ---");
    // Copia de la lista de usuarios para filtrar en el diálogo sin afectar _allUsers
    // Excluir el centinela si no quieres que sea buscable directamente, se añade como opción fija.
    final List<User> searchableUsers = List.from(_allUsers.where((u) => u.id != _allOrdersUserSentinel.id));
    List<User> filteredDialogUsers = List.from(searchableUsers);
    String dialogSearchQuery = '';

    final User? selected = await showDialog<User>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder( // Para manejar el estado del TextField y la lista filtrada dentro del diálogo
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Seleccionar Usuario'),
              contentPadding: const EdgeInsets.symmetric(vertical: 20.0),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                      child: TextField(
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Buscar usuario...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                        ),
                        onChanged: (query) {
                          dialogSearchQuery = query.toLowerCase().trim();
                          print("Query del diálogo: $dialogSearchQuery"); // LOG
                          setStateDialog(() {
                            if (dialogSearchQuery.isEmpty) {
                              filteredDialogUsers = List.from(searchableUsers);
                            } else {
                              filteredDialogUsers = searchableUsers.where((user) {
                                return user.displayName.toLowerCase().contains(dialogSearchQuery);
                              }).toList();
                            }
                            print("Usuarios filtrados en diálogo: ${filteredDialogUsers.length}"); // LOG
                          });
                        },
                      ),
                    ),
                    // Opción fija para "Ver Todas las Órdenes"
                    ListTile(
                      title: Text(_allOrdersUserSentinel.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      onTap: () {
                        Navigator.of(context).pop(_allOrdersUserSentinel);
                      },
                    ),
                    const Divider(),
                    Flexible( // Para que el ListView no desborde si hay muchos usuarios
                      child: ListView.builder(
                        shrinkWrap: true, // Importante para Column y contenido dinámico
                        itemCount: filteredDialogUsers.length,
                        itemBuilder: (context, index) {
                          final user = filteredDialogUsers[index];
                          String displayInfo = user.displayName;
                          if (user.displayName.toLowerCase() != user.email.toLowerCase()) {
                            displayInfo += " (${user.email})";
                          }
                          return ListTile(
                            title: Text(user.displayName),
                            onTap: () {
                              Navigator.of(context).pop(user); // Devuelve el usuario seleccionado
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () {
                    Navigator.of(context).pop(); // No devuelve nada (null)
                  },
                ),
              ],
            );
          },
        );
      },
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedUserForAdmin = selected;
        _searchOrdersController.clear(); // Limpiar búsqueda de órdenes
        _orders = [];
        _filteredOrders = [];
        _loadOrders(specificUserId: selected.id == _allOrdersUserSentinel.id ? null : selected.id);
      });
    }
  }
  // --- FIN DE NUEVO MÉTODO ---


  Widget _buildOrdersListContent() {
    if (widget.isAdmin && _selectedUserForAdmin == null && _allUsers.isNotEmpty && !_isLoadingUsers && !_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text(
            'Por favor, seleccione un usuario para ver sus órdenes o "Ver Todas las Órdenes".',
            style: TextStyle(fontSize: 18, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_filteredOrders.isEmpty) {
      String message;
      if (_searchQueryOrders.isNotEmpty) {
        message = 'No se encontraron órdenes para "$_searchQueryOrders".';
      } else if (widget.isAdmin && _selectedUserForAdmin != null) {
        if (_selectedUserForAdmin!.id == _allOrdersUserSentinel.id) {
          message = 'No hay órdenes de trabajo registradas en el sistema.';
        } else {
          message = 'No hay órdenes de trabajo para ${_selectedUserForAdmin!.displayName}.';
        }
      } else if (!widget.isAdmin) {
        message = 'No tienes órdenes de trabajo registradas.';
      } else {
        // Caso por defecto si es admin pero aún no se carga nada (o usuarios vacíos)
        message = 'Cargando órdenes o no hay usuarios disponibles.';
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            message,
            style: TextStyle(fontSize: 18, color: Colors.grey[700]),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadOrders(specificUserId: widget.isAdmin ? _selectedUserForAdmin?.id : null),
      color: AppColors.primaryBlue,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        itemCount: _filteredOrders.length,
        itemBuilder: (context, index) {
          final order = _filteredOrders[index];
          double currentOrderTotal = 0.0;
          if (order.spareParts.isNotEmpty) {
            currentOrderTotal += order.spareParts.fold(0.0, (sum, part) => sum + (part.price * part.quantity));
          }
          if (order.laborDetails.isNotEmpty) {
            currentOrderTotal += order.laborDetails.fold(0.0, (sum, labor) => sum + labor.price);
          }

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            elevation: 2.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              title: Text(
                order.clientName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: AppColors.primaryBlue,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  _buildInfoRow(Icons.calendar_today_outlined,
                      'Ingreso: ${_formatTimestamp(order.createdAt, 'dd/MM/yyyy')}'),
                  const SizedBox(height: 4),
                  _buildInfoRow(Icons.directions_car_outlined,
                      'Vehículo: ${order.brand} ${order.model} - ${order.plate}'),
                  if (widget.isAdmin && currentOrderTotal > 0 &&
                      (_selectedUserForAdmin != null && _selectedUserForAdmin!.id != _allOrdersUserSentinel.id)) ...[
                    // Mostrar total si es admin y hay un total.
                    // Podrías añadir lógica aquí para ocultarlo si _selectedUserForAdmin es "all_orders_sentinel"
                    // si prefieres no mostrar totales individuales en la vista "Todas".
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.lightBlue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        'Total: \$${currentOrderTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryBlue,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                  if (order.id != null) ...[
                    const SizedBox(height: 4),
                    _buildInfoRow(Icons.tag, 'ID Orden: #${order.id}'),
                  ]
                ],
              ),
              trailing: PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.grey[700]),
                onSelected: (value) {
                  switch (value) {
                    case 'view':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OrderDetailScreen(
                            order: order,
                            isAdmin: widget.isAdmin, // Pasa el estado de admin actual
                          ),
                        ),
                      );
                      break;
                    case 'edit':
                      _editOrder(order);
                      break;
                    case 'delete':
                      _deleteOrder(order);
                      break;
                    case 'export_pdf':
                      if (widget.isAdmin) { // Asegurar que solo el admin pueda exportar
                        _exportToPdf(order);
                      }
                      break;
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[

                  const PopupMenuItem<String>(
                    value: 'view',
                    child: ListTile(
                      leading: Icon(Icons.visibility_outlined, color: AppColors.primaryBlue),
                      title: Text('Ver Detalles'),
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined, color: Colors.blueAccent),
                      title: Text('Editar Orden'),
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_forever_outlined, color: Colors.redAccent),
                      title: Text('Eliminar Orden'),
                    ),
                  ),
                  // Solo mostrar Exportar a PDF si es admin
                  if (widget.isAdmin) ...[
                    const PopupMenuDivider(),
                    PopupMenuItem<String>(
                      value: 'export_pdf',
                      child: ListTile(
                        leading: Icon(Icons.picture_as_pdf_outlined, color: Colors.orange[700]),
                        title: const Text('Exportar a PDF'),
                      ),
                    ),

                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13.5, color: Colors.grey[800]),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}