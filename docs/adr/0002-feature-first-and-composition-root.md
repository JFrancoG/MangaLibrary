# ADR-0002: Arquitectura feature-first y composition root

**Estado:** Accepted
**Fecha:** 2026-08-17
**Supersede:** —
**Superseded by:** —

## Contexto

El producto crecerá por niveles y añadirá búsqueda, colección, autenticación,
sincronización y superficies complementarias. La estructura debe hacer visible
cada capacidad sin introducir capas o abstracciones que dupliquen los frameworks
de Apple.

## Drivers

- Mantener juntos UI, estado, modelos y efectos propios de una funcionalidad.
- Hacer explícita la composición y dirección de dependencias.
- Minimizar complejidad operativa y riesgo de mantenimiento externo.

## Opciones consideradas

1. **Feature-first con composition root:** favorece cohesión y crecimiento
   incremental, pero exige vigilar duplicación y dependencias cruzadas.
2. **Carpetas por capa técnica:** resultan familiares, aunque dispersan cada flujo
   entre directorios y facilitan dependencias globales.
3. **Framework arquitectónico externo:** aporta convenciones, pero añade una API,
   ciclo de versiones y coste de aprendizaje que el alcance no necesita.

## Decisión

La aplicación se organizará por funcionalidades. Un composition root en el target
de la app construirá servicios y dependencias compartidas y los inyectará en las
features. El código común solo pasará a un núcleo compartido cuando tenga un
contrato estable y más de un consumidor real. No se incorporarán dependencias
externas; cualquier excepción futura requerirá un ADR que compare costes.

## Consecuencias

### Positivas

- Cada flujo puede entenderse, probarse y evolucionar con un alcance localizado.
- La creación de dependencias queda auditable en un punto explícito.
- El proyecto conserva una superficie tecnológica pequeña y nativa.

### Negativas

- Puede existir duplicación temporal antes de descubrir una abstracción estable.
- La composición manual y los límites entre features requieren disciplina de
  revisión.

## Validación

- Revisar que una feature no construya dependencias de infraestructura por su
  cuenta ni importe otra feature para reutilizar detalles internos.
- Confirmar que el proyecto no contiene paquetes o binarios de terceros.

## Condiciones de revisión

- Aparecen ciclos entre features que no pueden eliminarse con contratos pequeños.
- Una dependencia externa resuelve una necesidad demostrada cuyo coste de
  construir y mantener internamente es mayor.

## Especificaciones relacionadas

- [Arquitectura y composición](../specs/01-architecture-and-composition.md)
