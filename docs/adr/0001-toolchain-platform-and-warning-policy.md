# ADR-0001: Plataforma, toolchain y warnings como errores

**Estado:** Accepted
**Fecha:** 2026-08-17
**Supersede:** —
**Superseded by:** —

## Contexto

Manga Library parte como proyecto nuevo y puede adoptar una base moderna sin
compatibilidad heredada. La configuración debe ser inequívoca para que el código,
las pruebas y la documentación fallen ante diagnósticos que de otro modo se
acumularían como deuda.

## Drivers

- Usar las capacidades de lenguaje, concurrencia y plataforma definidas para el
  nivel avanzado del proyecto.
- Obtener resultados reproducibles entre desarrollo y automatización.
- Evitar que warnings conocidos lleguen a la rama principal o a la entrega.

## Opciones consideradas

1. **Xcode 27, Swift 6.4 e iOS 27 con todos los warnings como errores:** máxima
   coherencia y exigencia, a cambio de depender del toolchain acordado.
2. **Soportar versiones anteriores:** amplía compatibilidad, pero introduce
   bifurcaciones y limita APIs sin una necesidad de producto actual.
3. **Tratar warnings como errores solo en CI:** reduce fricción local, pero retrasa
   el feedback y permite configuraciones divergentes.

## Decisión

El proyecto usará Xcode 27, Swift 6.4 y un deployment target de iOS 27. Los
warnings de Swift, Clang y DocC se tratarán como errores tanto localmente como en
los gates de entrega. Una supresión solo será admisible en el límite mínimo
afectado, con justificación verificable y revisión explícita.

## Consecuencias

### Positivas

- Los diagnósticos bloquean cerca de su origen y no se normalizan como ruido.
- La base puede usar APIs y reglas de Swift 6.4 sin capas de compatibilidad.

### Negativas

- Una actualización del SDK puede detener temporalmente builds o DocC hasta
  resolver nuevos diagnósticos.
- Colaborar exige disponer exactamente del toolchain acordado.

## Validación

- Registrar las versiones efectivas de Xcode y Swift al validar una entrega.
- Ejecutar build, suites y construcción DocC con sus warnings configurados como
  errores, sin supresiones globales.

## Condiciones de revisión

- Una restricción real de distribución exige soportar una versión anterior de iOS.
- Un defecto confirmado del toolchain impide avanzar y no tiene mitigación
  acotada.

## Especificaciones relacionadas

- [Alcance y niveles del producto](../specs/00-product-scope-and-levels.md)
- [Arquitectura y composición](../specs/01-architecture-and-composition.md)
- [Testing, calidad y accesibilidad](../specs/06-testing-quality-and-accessibility.md)
