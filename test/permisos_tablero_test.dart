import 'package:flutter_test/flutter_test.dart';
import 'package:kanbly/modelo/tablero.dart';

void main() {
  group('Pruebas del Modelo Tablero y Permisos de Integrantes', () {
    test('El Dueño Principal (Creador) siempre tiene todos los permisos', () {
      final tablero = Tablero(
        id: 'board_1',
        nombre: 'Proyecto Grupal',
        esGrupal: true,
        creadorId: 'user_owner',
        miembrosIds: ['user_owner', 'user_member'],
        fechaCreacion: DateTime.now(),
      );

      final permisosOwner = tablero.obtenerPermisosDeUsuario('user_owner');

      expect(tablero.esCreador('user_owner'), isTrue);
      expect(tablero.esAdminOCreador('user_owner'), isTrue);
      expect(permisosOwner.crearTareas, isTrue);
      expect(permisosOwner.editarTareas, isTrue);
      expect(permisosOwner.eliminarTareas, isTrue);
      expect(permisosOwner.moverTareas, isTrue);
      expect(permisosOwner.gestionarModulos, isTrue);
      expect(permisosOwner.administrarMiembros, isTrue);
      expect(permisosOwner.editarTablero, isTrue);
    });

    test('Los Administradores (Co-dueños) heredan permisos totales', () {
      final tablero = Tablero(
        id: 'board_1',
        nombre: 'Proyecto Grupal',
        esGrupal: true,
        creadorId: 'user_owner',
        miembrosIds: ['user_owner', 'user_admin'],
        miembrosInfo: {
          'user_admin': const MiembroTableroInfo(
            usuarioId: 'user_admin',
            rolKanban: 'Líder de Proyecto',
            esAdmin: true,
          ),
        },
        fechaCreacion: DateTime.now(),
      );

      expect(tablero.esCreador('user_admin'), isFalse);
      expect(tablero.esAdminOCreador('user_admin'), isTrue);

      final permisosAdmin = tablero.obtenerPermisosDeUsuario('user_admin');
      expect(permisosAdmin.crearTareas, isTrue);
      expect(permisosAdmin.administrarMiembros, isTrue);
      expect(permisosAdmin.editarTablero, isTrue);
      expect(permisosAdmin.eliminarTareas, isTrue);
    });

    test('Miembros regulares respetan permisos asignados', () {
      final tablero = Tablero(
        id: 'board_1',
        nombre: 'Proyecto Grupal',
        esGrupal: true,
        creadorId: 'user_owner',
        miembrosIds: ['user_owner', 'user_dev'],
        miembrosInfo: {
          'user_dev': const MiembroTableroInfo(
            usuarioId: 'user_dev',
            rolKanban: 'Programador / Desarrollador',
            esAdmin: false,
            permisos: PermisosMiembro(
              crearTareas: true,
              editarTareas: true,
              eliminarTareas: false, // No puede eliminar
              moverTareas: true,
              gestionarModulos: false, // No puede ver modulos
              administrarMiembros: false,
              editarTablero: false,
            ),
          ),
        },
        fechaCreacion: DateTime.now(),
      );

      expect(tablero.esAdminOCreador('user_dev'), isFalse);

      final permisosDev = tablero.obtenerPermisosDeUsuario('user_dev');
      expect(permisosDev.crearTareas, isTrue);
      expect(permisosDev.eliminarTareas, isFalse);
      expect(permisosDev.gestionarModulos, isFalse);
      expect(permisosDev.administrarMiembros, isFalse);
    });

    test('Asignación y actualización de roles Kanban', () {
      const miembroInfoInitial = MiembroTableroInfo(
        usuarioId: 'user_qa',
        rolKanban: 'Tester / QA',
        esAdmin: false,
      );

      expect(miembroInfoInitial.rolKanban, equals('Tester / QA'));

      final miembroInfoUpdated = miembroInfoInitial.copyWith(
        rolKanban: 'Analista',
      );

      expect(miembroInfoUpdated.rolKanban, equals('Analista'));
      expect(miembroInfoUpdated.usuarioId, equals('user_qa'));
      expect(miembroInfoUpdated.esAdmin, isFalse);
    });

    test('Lógica de autorización para modificar Administradores', () {
      final tablero = Tablero(
        id: 'board_1',
        nombre: 'Proyecto Grupal',
        esGrupal: true,
        creadorId: 'user_creator',
        miembrosIds: ['user_creator', 'admin_1', 'admin_2'],
        miembrosInfo: {
          'admin_1': const MiembroTableroInfo(
            usuarioId: 'admin_1',
            rolKanban: 'Líder de Proyecto',
            esAdmin: true,
          ),
          'admin_2': const MiembroTableroInfo(
            usuarioId: 'admin_2',
            rolKanban: 'Scrum Master',
            esAdmin: true,
          ),
        },
        fechaCreacion: DateTime.now(),
      );

      // Función auxiliar que replica la regla del negocio:
      // Solo el creador del tablero puede modificar a un Administrador
      bool puedeModificarAdmin(String currentUserId, String targetUserId) {
        final targetIsAdmin = tablero.miembrosInfo[targetUserId]?.esAdmin ?? false;
        final targetIsCreator = tablero.esCreador(targetUserId);

        if (targetIsCreator) return false; // Inmutable
        if (targetIsAdmin) {
          return tablero.esCreador(currentUserId); // Solo el Creador puede
        }
        return tablero.esAdminOCreador(currentUserId); // Creador o Admin pueden modificar a un miembro regular
      }

      // El Creador SÍ puede editar a admin_1 y admin_2
      expect(puedeModificarAdmin('user_creator', 'admin_1'), isTrue);
      expect(puedeModificarAdmin('user_creator', 'admin_2'), isTrue);

      // admin_1 NO puede editar al Creador ni a admin_2
      expect(puedeModificarAdmin('admin_1', 'user_creator'), isFalse);
      expect(puedeModificarAdmin('admin_1', 'admin_2'), isFalse);
    });
  });
}
