import 'package:flutter_test/flutter_test.dart';
import 'package:kanbly/modelo/tablero.dart';
import 'package:kanbly/modelo/resumen_tableros.dart';
import 'package:kanbly/servicios/cache_adjuntos_service.dart';

void main() {
  group('Pruebas de Permisos y Tableros Individuales vs Equipo', () {
    test('Tableros individuales no deben contener roles de equipo en resumen o miembros', () {
      final tableroIndividual = Tablero(
        id: 'ind_1',
        nombre: 'Mi Tablero Personal',
        esGrupal: false,
        creadorId: 'user_me',
        fechaCreacion: DateTime.now(),
      );

      final resumen = ResumenTableros.desde([tableroIndividual], 'user_me');

      expect(tableroIndividual.esGrupal, isFalse);
      expect(resumen.tableros.first.esGrupal, isFalse);
      // El rol Kanban de un tablero individual debe ser cadena vacía
      expect(resumen.tableros.first.rolKanban, isEmpty);
    });

    test('Permisos por defecto en miembros regulares de tableros grupales', () {
      final tableroGrupal = Tablero(
        id: 'g_1',
        nombre: 'Proyecto de Equipo',
        esGrupal: true,
        creadorId: 'owner_1',
        miembrosIds: ['owner_1', 'member_1'],
        miembrosInfo: {
          'member_1': const MiembroTableroInfo(
            usuarioId: 'member_1',
            rolKanban: 'Programador / Desarrollador',
            esAdmin: false,
            permisos: PermisosMiembro(
              crearTareas: false,
              editarTareas: true,
              eliminarTareas: false,
            ),
          ),
        },
        fechaCreacion: DateTime.now(),
      );

      final permisosOwner = tableroGrupal.obtenerPermisosDeUsuario('owner_1');
      final permisosMember = tableroGrupal.obtenerPermisosDeUsuario('member_1');

      // El Creador siempre tiene permisos inmutables totales
      expect(permisosOwner.crearTareas, isTrue);
      expect(permisosOwner.eliminarTareas, isTrue);

      // El miembro sin permiso de crear/eliminar debe reflejar sus valores
      expect(permisosMember.crearTareas, isFalse);
      expect(permisosMember.editarTareas, isTrue);
      expect(permisosMember.eliminarTareas, isFalse);
    });

    test('Lógica de servicio de caché local para consumo offline de adjuntos', () async {
      // Probar que la verificación de URL vacía o no HTTP retorna null de forma segura
      final resVacio = await CacheAdjuntosService.obtenerArchivoLocalSiExiste('', 'prueba.pdf');
      expect(resVacio, isNull);

      final resDownloadInvalid = await CacheAdjuntosService.descargarYGuardarEnCache('', 'prueba.pdf');
      expect(resDownloadInvalid, isNull);
    });
  });
}
