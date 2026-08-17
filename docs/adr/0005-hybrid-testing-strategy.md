# ADR-0005: Estrategia híbrida de pruebas

**Estado:** Accepted
**Fecha:** 2026-08-17
**Supersede:** —
**Superseded by:** —

## Contexto

El proyecto necesita feedback rápido sobre reglas y persistencia, y evidencia de
los recorridos críticos en una aplicación real. Swift Testing cubre bien unidad e
integración, mientras que la automatización de interfaz continúa apoyándose en
XCUITest.

## Drivers

- Usar la API moderna para tests deterministas y expresivos.
- Validar integraciones reales sin convertir toda la suite en UI lenta.
- Hacer explícito qué conjunto bloquea cada etapa de desarrollo y entrega.

## Opciones consideradas

1. **Swift Testing para unidad/integración y XCUITest para UI:** usa cada
   herramienta en su fortaleza, a cambio de convivir con dos APIs.
2. **Todo con XCTest:** unifica la API, pero renuncia a capacidades modernas de
   Swift Testing sin beneficio para los tests no UI.
3. **Solo unidad e integración:** es más rápido, pero deja sin evidencia los
   recorridos, accesibilidad y wiring de la app.

## Decisión

Las pruebas unitarias y de integración nuevas usarán Swift Testing. Los recorridos
de interfaz usarán XCUITest. Se mantendrán cuatro planes de prueba con propósito
explícito:

- `Fast`: unidad determinista para el ciclo habitual.
- `Integration`: persistencia, API y límites entre componentes controlados.
- `UI`: recorridos críticos mediante XCUITest.
- `ReleaseGate`: conjunto completo exigido para una entrega.

No se añadirán librerías de testing externas. Los tests no dependerán de orden,
red pública, credenciales reales ni esperas temporales arbitrarias.

## Consecuencias

### Positivas

- El ciclo local puede ser rápido sin reducir el gate de entrega.
- Reglas, persistencia y wiring de interfaz reciben cobertura proporcionada.

### Negativas

- El equipo mantiene convenciones de Swift Testing y XCUITest.
- Cuatro planes pueden divergir si no se revisan al añadir o mover suites.

## Validación

- Ejecutar cada plan por separado y confirmar que selecciona solo las suites
  previstas.
- Ejecutar `ReleaseGate` en un destino limpio antes de considerar una entrega.
- Repetir tests sensibles para detectar dependencia de orden o tiempo.

## Condiciones de revisión

- Swift Testing incorpora soporte UI suficiente para sustituir XCUITest.
- El tiempo o la inestabilidad de `ReleaseGate` impiden usarlo como gate y existe
  evidencia para redistribuir suites.

## Especificaciones relacionadas

- [Alcance y niveles del producto](../specs/00-product-scope-and-levels.md)
- [Arquitectura y composición](../specs/01-architecture-and-composition.md)
- [Testing, calidad y accesibilidad](../specs/06-testing-quality-and-accessibility.md)
