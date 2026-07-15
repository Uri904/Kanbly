import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ==========================================
// 1. PANTALLA PRINCIPAL: TABLERO KANBAN
// ==========================================

class KanbanBoardWidget extends StatefulWidget {
  const KanbanBoardWidget({super.key});

  @override
  State<KanbanBoardWidget> createState() => _KanbanBoardWidgetState();
}

class _KanbanBoardWidgetState extends State<KanbanBoardWidget> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4F8), // Fondo Light Gray
        appBar: AppBar(
          backgroundColor: const Color(0xFF001F3F), // Deep Navy Blue
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.search_rounded,
              color: Colors.white,
              size: 24,
            ),
            onPressed: () {
              print('Search icon pressed ...');
            },
          ),
          title: Text(
            'KANBLY',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
              letterSpacing: 0.0,
            ),
          ),
          centerTitle: false,
        ),

        floatingActionButton: FloatingActionButton(
          onPressed: () {
            print('FAB pressed ...');
          },
          backgroundColor: const Color(0xFF00FFFF), // Vibrant Cyan
          elevation: 6,
          shape: const CircleBorder(),
          child: const Icon(
            Icons.add_rounded,
            color: Color(0xFF001F3F), // Navy icon para contraste
            size: 28,
          ),
        ),

        body: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- COLUMNA 1: PENDIENTE ---
              SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    ColumnHeaderWidget(
                      count: '3',
                      title: 'PENDIENTE',
                    ),
                    SizedBox(height: 16),
                    TaskCardWidget(
                      date: 'Oct 24',
                      desc: 'Finalize the patterns for the invitations.',
                      initials: 'AR',
                      labelColor: Color(0xFF00FFFF),
                      title: 'Brand Identity Revamp',
                    ),
                    SizedBox(height: 16),
                    TaskCardWidget(
                      date: 'Oct 26',
                      desc: 'Draft the user flow for the onboarding screens.',
                      initials: 'JD',
                      labelColor: Color(0xFFFF5252),
                      title: 'Mobile App Wireframes',
                    ),
                    SizedBox(height: 16),
                    TaskCardWidget(
                      date: 'Oct 28',
                      desc: 'Review the keyword density for the landing page.',
                      initials: 'MK',
                      labelColor: Color(0xFF00FFFF),
                      title: 'SEO Audit',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),

              // --- COLUMNA 2: EN PROGRESO ---
              SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    ColumnHeaderWidget(
                      count: '2',
                      title: 'EN PROGRESO',
                    ),
                    SizedBox(height: 16),
                    TaskCardWidget(
                      date: 'Oct 22',
                      desc: 'Connect the payment gateway to the checkout flow.',
                      initials: 'ST',
                      labelColor: Color(0xFF00FFFF),
                      title: 'API Integration',
                    ),
                    SizedBox(height: 16),
                    TaskCardWidget(
                      date: 'Oct 25',
                      desc: 'Create consistent components for the admin panel.',
                      initials: 'AR',
                      labelColor: Color(0xFF00FFFF),
                      title: 'Dashboard UI Kit',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),

              // --- COLUMNA 3: COMPLETADA ---
              SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    ColumnHeaderWidget(
                      count: '1',
                      title: 'COMPLETADA',
                    ),
                    SizedBox(height: 16),
                    TaskCardWidget(
                      date: 'Oct 21',
                      desc: 'Check the tone of voice for the about us page.',
                      initials: 'PL',
                      labelColor: Color(0xFFFF5252),
                      title: 'Copywriting Review',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 2. COMPONENTE: ENCABEZADO DE COLUMNA
// ==========================================

class ColumnHeaderWidget extends StatelessWidget {
  final String title;
  final String count;

  const ColumnHeaderWidget({
    super.key,
    this.title = 'PENDIENTE',
    this.count = '3',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF001F3F), // Deep Navy Blue
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Título de la columna
            Flexible(
              flex: 1,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
            ),
            // Burbuja/Badge con el contador
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF00FFFF), // Vibrant Cyan
                borderRadius: BorderRadius.circular(9999),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Text(
                count,
                style: GoogleFonts.inter(
                  color: const Color(0xFF001F3F), // Navy Blue
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3. COMPONENTE: TARJETA DE TAREA
// ==========================================

class TaskCardWidget extends StatelessWidget {
  final String date;
  final String desc;
  final String initials;
  final Color labelColor;
  final String title;

  const TaskCardWidget({
    super.key,
    this.date = 'Oct 24',
    this.desc = 'Finalize the patterns for the invitations.',
    this.initials = 'AR',
    this.labelColor = const Color(0xFF00FFFF),
    this.title = 'Brand Identity Revamp',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            color: Colors.black.withOpacity(0.08),
            offset: const Offset(0, 4),
            spreadRadius: 0,
          )
        ],
        borderRadius: BorderRadius.circular(12),
        shape: BoxShape.rectangle,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row superior: Prioridad y Menú
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 30,
                  height: 8,
                  decoration: BoxDecoration(
                    color: labelColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const Icon(
                  Icons.more_horiz_rounded,
                  color: Colors.grey,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Título y Descripción
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF001F3F), // Navy Blue
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.grey[600],
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Separador
            const Divider(
              height: 1,
              thickness: 1,
              color: Color(0xFFE0E0E0),
            ),
            const SizedBox(height: 16),

            // Row inferior: Fecha y Avatar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      color: Colors.grey[600],
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      date,
                      style: GoogleFonts.inter(
                        color: Colors.grey[600],
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Color(0xFF001F3F),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF00FFFF), // Cyan
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}