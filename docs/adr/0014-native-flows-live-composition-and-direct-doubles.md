# ADR-0014: Flujos nativos, composición live y dobles directos

**Estado:** Superseded
**Fecha:** 2026-08-27
**Supersede:** [ADR-0009](0009-native-source-owned-features-and-local-navigation.md)
**Superseded by:** [ADR-0015](0015-native-flows-live-composition-and-adaptive-navigation.md)

## Contexto

ADR 0009 estableció flujos diferentes según la fuente de verdad, navegación
local a cada feature y ausencia de capas ceremoniales. Esas decisiones siguen
siendo adecuadas.

También decidió que las previews interactivas de Catálogo recorrieran el mismo
pipeline HTTP y DTO que producción mediante una `URLSession` efímera y un
`URLProtocol` local. Después de implementar C1 y C2, esa igualdad de circuito
obliga a introducir selección de fixtures en la composición de la app, hace que
una preview preparada dependa de transporte y decoding, y lleva los tests del
cliente tipado a atravesar `URLSession` aunque su riesgo real sea construir,
decodificar y mapear una respuesta.

La composición live debe representar siempre producción. Previews, tests de
unidad y UI tests necesitan datos deterministas, pero no son fuentes de producto
ni deben convertir la composición live en un selector de escenarios.

## Drivers

- Conservar los flujos nativos y la navegación local ya aprobados.
- Hacer imposible que la composición live seleccione datos mock.
- Probar request, decoding, mapping, errores y cancelación en el propietario que
  contiene cada comportamiento.
- Mantener transporte HTTP y contrato tipado como responsabilidades distintas.
- Evitar Repository, UseCase, protocolos o builders globales sin variación real.
- Reducir tests y wiring cuyo único resultado ya está garantizado por el
  compilador.
- Mantener previews y UI tests deterministas, sin red ni credenciales live.

## Opciones consideradas

1. **Dobles directos en fronteras pequeñas:** producción conserva el circuito
   completo; previews y tests sustituyen únicamente la capacidad que necesitan.
   Divide la evidencia entre suites focalizadas.
2. **Mantener `URLProtocol` en previews y tests del cliente tipado:** conserva un
   único pipeline, pero mezcla composición live, escenarios de demostración,
   transporte y estados visuales.
3. **Decoding genérico dentro de `HTTPClient`:** centraliza `JSONDecoder`, pero
   acopla transporte a contratos de feature, dificulta una costura de bytes
   simple y puede representar estados inválidos con cuerpo o código opcionales.
4. **Repository o pipeline uniforme para todas las fuentes:** ofrece una forma
   repetible, pero vuelve a fingir que API, SwiftData y fixtures tienen la misma
   autoridad y semántica.

## Decisión

La aplicación conserva feature-first y los flujos según su fuente de verdad:

- Catálogo: cliente tipado → modelo `@Observable @MainActor` → View.
- Colección: `@Query` para lectura; intención → comando por valor → capacidad
  `@ModelActor` → SwiftData para mutación.
- Cuenta y sincronización: actores propietarios de sesión, Keychain, refresh y
  outbox; la UI recibe solo estados seguros.

No se crea Repository, UseCase, Store, mapper, router o protocolo salvo que
separe una variación real, una política reutilizada, un efecto, un aislamiento o
más de una implementación con semántica equivalente.

`AppComposition` construye exclusivamente dependencias live. No interpreta
argumentos de proceso ni selecciona fixtures o mocks. Previews y tests componen
fuera de ese root estados o capacidades directas. Un bootstrap específico de UI
tests puede reconocer un único modo determinista solo en Debug; una solicitud
no disponible falla cerrada y nunca cae a red live.

`HTTPClient` conserva una `URLSession` inyectada, ejecuta transporte, valida que
la respuesta sea HTTP y comprueba el status esperado antes de devolver bytes no
opcionales. Mapea fallos a un `NetworkError` seguro y localizable. No decodifica
DTO ni conoce contratos de feature. `CancellationError` se propaga sin
convertirse en un error visible.

`CatalogAPIClient` construye el `URLRequest`, solicita bytes, decodifica el DTO
mínimo que consume `Manga`, valida metadata e identidades y mapea errores de
contrato. Su frontera sustituible es una capacidad:

```swift
@Sendable (URLRequest) async throws -> Data
```

Producción la adapta desde `HTTPClient`. Los tests entregan JSON mock y registran
la petición real. Los campos remotos no consumidos no forman parte del DTO y una
ampliación desconocida del payload no constituye por sí sola una deriva.

La construcción de cada request permanece tipada junto a su feature y usa
`APIConfiguration`. No se crea todavía un catálogo global de endpoints ni un
builder general: se extraerá mecánica común cuando dos operaciones reales
demuestren duplicación.

`URLProtocol` queda reservado a los tests del adaptador `HTTPClient`. Los tests
del cliente de Catálogo prueban directamente construcción, decoding, mapping,
errores y cancelación con bytes controlados. Las previews de Catálogo construyen
un estado o un loader directo y no usan `URLSession`, `HTTPClient`, DTO,
`URLProtocol` o JSON.

XCUITest se limita al menor smoke determinista que demuestre wiring crítico no
cubierto por Swift Testing. No se crean pruebas cuya única posibilidad de fallo
sea una conformidad exigida por Swift, un inicializador trivial o wiring sin
ramas.

La navegación aprobada por ADR 0009 se conserva: el shell posee tabs estables;
Catálogo y Colección mantienen selecciones independientes y
`NavigationSplitView`; Cuenta usa una ruta lineal en `NavigationStack`. Los
destinos reciben `Manga.ID`, no DTO ni modelos SwiftData vivos. No se introduce
un router global. Logout completado invalida las rutas privadas de la identidad
anterior y un logout cancelado las conserva.

## Consecuencias

### Positivas

- La composición live representa siempre producción.
- Previews y UI tests dejan de depender de transporte para mostrar estados.
- Cada suite prueba el comportamiento real de su frontera con menos ceremonia.
- La evolución de campos remotos no utilizados deja de romper decoding.
- Los errores de red son seguros, tipados y localizables.
- Se conservan arquitectura nativa, navegación local y una sola fuente de verdad
  por flujo.

### Negativas

- Ninguna preview demuestra por sí sola el pipeline completo de red.
- La evidencia queda repartida entre tests de transporte, tests del cliente
  tipado, build y smoke UI.
- Los JSON mock pueden derivar del OpenAPI y requieren revalidación cuando cambie
  el contrato.
- El bootstrap Debug de UI tests constituye un camino adicional que debe
  permanecer mínimo y fail-closed.
- Si una operación futura necesita headers o metadata HTTP válidos, habrá que
  revisar la frontera de bytes.

## Validación

- Comprobar que `AppComposition` no contiene argumentos de proceso, fixtures ni
  selección Debug/live.
- Comprobar que previews no importan ni construyen `URLSession`, `HTTPClient`,
  DTO, `URLProtocol` o JSON.
- Verificar en tests de Catálogo el request exacto, decoding, mapping, metadata,
  identidades duplicadas, errores de red, deriva contractual y cancelación.
- Verificar en tests de `HTTPClient` bytes, respuesta no HTTP, status inesperado,
  transporte y cancelación mediante una sesión aislada.
- Ejecutar el smoke UI sin tráfico de producción.
- Ejecutar los planes aplicables, build, diagnósticos y DocC con cero warnings,
  sin acreditar `Fast` o `Integration` mientras persista su regresión de tags.
- Validar el String Catalog en español e inglés y probar categorías de errores,
  no literales traducidos.
- Confirmar que navegación, paginación, respuestas tardías y cancelación de C2
  no cambian.

## Condiciones de revisión

- Dos fuentes reales y semánticamente equivalentes justifican un contrato común.
- Varias features repiten mecánica de construcción de requests y un builder
  pequeño reduce duplicación demostrada.
- Una operación necesita headers o metadata HTTP después de validar su status.
- Deep links, restauración o navegación transversal justifican coordinación
  global.
- Swift Testing permite sustituir el smoke XCUITest con evidencia equivalente.

## Especificaciones relacionadas

- [Alcance y niveles del producto](../specs/00-product-scope-and-levels.md)
- [Arquitectura y composición](../specs/01-architecture-and-composition.md)
- [API, catálogo, búsqueda e imágenes](../specs/02-api-catalog-search-and-images.md)
- [Colección local e invariantes](../specs/03-local-collection-and-invariants.md)
- [Autenticación y sincronización](../specs/04-authentication-and-sync.md)
- [Testing, calidad y accesibilidad](../specs/06-testing-quality-and-accessibility.md)
