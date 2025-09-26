import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Necesario para Timestamp
import '../models/work_order.dart';
import '../utils/constants.dart';
import '../widgets/custom_logo.dart'; // Si OrderHeader no es CustomLogo directamente

// Si OrderHeader es simplemente el logo, podrías usar CustomLogo directamente
// o definir OrderHeader como un widget simple aquí o en su propio archivo.
// Por ejemplo:


class OrderDetailScreen extends StatelessWidget {
  final WorkOrder order;
  final bool isAdmin;

  // El constructor no necesita cambios si WorkOrder ya está adaptado para Firebase
  const OrderDetailScreen({super.key, required this.order, required this.isAdmin});

  // Helper para formatear Timestamp a String de manera segura
  String _formatTimestamp(Timestamp? timestamp, String format) {
    if (timestamp == null) return 'N/A';
    return DateFormat(format).format(timestamp.toDate());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          // order.id ya es un String, así que la comprobación de null es suficiente
            order.id != null ? 'Detalle de Orden #${order.id}' : 'Detalle de Orden',
            style: const TextStyle(color: AppColors.white)
        ),
        backgroundColor: AppColors.primaryBlue,
        iconTheme: const IconThemeData(color: AppColors.white),
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Asumiendo que OrderHeader existe y es relevante.
            // Si order.id es null, significa que la orden podría ser nueva y aún no guardada,
            // entonces OrderHeader podría no tener sentido o necesitar un estado diferente.
            if (order.id != null)
              const OrderHeader(),
            if (order.id != null)
              const SizedBox(height: 20),

            _buildSectionCard(
              titleIcon: Icons.person_outline,
              'Datos del Cliente',
              [
                _buildInfoRow('Nombre', order.clientName),
                _buildInfoRow('Dirección', order.address),
                _buildInfoRow('Teléfono', order.phone),
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              titleIcon: Icons.directions_car_outlined,
              'Información del Vehículo',
              [
                // Formatear 'order.date' (Timestamp) a String
                _buildInfoRow('Fecha Servicio', _formatTimestamp(order.date, 'dd/MM/yyyy')),
                _buildInfoRow('Número de Motor', order.engineNumber),
                _buildInfoRow('Año', order.year),
                _buildInfoRow('Marca', order.brand),
                _buildInfoRow('Modelo', order.model),
                _buildInfoRow('Placa', order.plate),
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              titleIcon: Icons.build_outlined,
              'Repuestos (${order.spareParts.length})',
              order.spareParts.isEmpty
                  ? [_buildEmptyState('No hay repuestos en esta orden.')]
                  : order.spareParts.map((part) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${part.description} (x${part.quantity})',
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // La lógica de mostrar precios basada en isAdmin no cambia
                    if (part.price > 0)
                      Text(
                        isAdmin
                            ? '\$${(part.price * part.quantity).toStringAsFixed(2)}'
                            : '',
                        style: TextStyle(
                          fontWeight: isAdmin ? FontWeight.bold : FontWeight.normal,
                          color: isAdmin ? AppColors.primaryBlue : Colors.grey[800],
                          fontSize: 15,
                        ),
                      ),
                  ],
                ),
              )).toList(),
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              titleIcon: Icons.construction_outlined,
              'Mano de Obra (${order.laborDetails.length})',
              order.laborDetails.isEmpty
                  ? [_buildEmptyState('No hay detalles de mano de obra.')]
                  : order.laborDetails.map((labor) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        labor.description,
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // La lógica de mostrar precios basada en isAdmin no cambia
                    if (labor.price > 0)
                      Text(
                        isAdmin
                            ? '\$${labor.price.toStringAsFixed(2)}'
                            : '',
                        style: TextStyle(
                          fontWeight: isAdmin ? FontWeight.bold : FontWeight.normal,
                          color: isAdmin ? AppColors.primaryBlue : Colors.grey[800],
                          fontSize: 15,
                        ),
                      ),
                  ],
                ),
              )).toList(),
            ),

            if (isAdmin) ...[
              const SizedBox(height: 16),
              // _buildTotalCard usa los datos de `order` directamente, no necesita cambios
              _buildTotalCard(),
            ],
            const SizedBox(height: 16),
            _buildSectionCard(
              titleIcon: Icons.info_outline,
              'Información Adicional',
              [
                _buildInfoRow('Autorizado por', order.authorizedBy),
                if (order.observations.isNotEmpty)
                  _buildInfoRow('Observaciones', order.observations),
                // Formatear 'order.createdAt' (Timestamp) a String
                _buildInfoRow(
                  'Fecha de Creación',
                  _formatTimestamp(order.createdAt, 'dd/MM/yyyy HH:mm'),
                ),
                // order.id ya es String o null
                if(order.id != null)
                  _buildInfoRow('ID Orden', '#${order.id!}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Center(
        child: Text(
          message,
          style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
        ),
      ),
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children, {IconData? titleIcon}) {
    return Card(
      elevation: 2.5,
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (titleIcon != null)
                  Icon(titleIcon, color: AppColors.primaryBlue, size: 22),
                if (titleIcon != null)
                  const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
            Divider(height: 20, thickness: 0.8, color: Colors.grey[300]),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) { // value puede ser null ahora
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              // Manejar el caso de que value sea null o vacío
              (value == null || value.isEmpty) ? '-' : value,
              style: const TextStyle(fontSize: 15, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard() {
    double totalSpareParts = order.spareParts.fold(0.0, (sum, part) => sum + (part.price * part.quantity));
    double totalLabor = order.laborDetails.fold(0.0, (sum, labor) => sum + labor.price);
    double grandTotal = totalSpareParts + totalLabor;

    return Card(
      elevation: 3,
      color: AppColors.lightBlue.withOpacity(0.15),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.primaryBlue.withOpacity(0.4), width: 1)
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTotalRow('Subtotal Repuestos:', totalSpareParts),
            const SizedBox(height: 8),
            _buildTotalRow('Subtotal Mano de Obra:', totalLabor),
            Divider(thickness: 1, color: AppColors.primaryBlue.withOpacity(0.5), height: 24),
            _buildTotalRow('TOTAL GENERAL:', grandTotal, isGrandTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool isGrandTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isGrandTotal ? 18 : 16,
              fontWeight: isGrandTotal ? FontWeight.bold : FontWeight.w600,
              color: isGrandTotal ? AppColors.primaryBlue : Colors.black.withOpacity(0.8),
            ),
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isGrandTotal ? 18 : 16,
              fontWeight: FontWeight.bold,
              color: isGrandTotal ? AppColors.primaryBlue : Colors.black.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }
}