# ADR-0009: Flujos nativos por fuente y navegación local

**Estado:** Accepted
**Fecha:** 2026-08-17
**Supersede:** —
**Superseded by:** —

## Contexto

Feature-first define dónde vive el código, pero no determina quién posee cada
estado ni obliga a que catálogo remoto, colección persistida y sesión recorran el
mismo pipeline. El producto necesita además una navegación pequeña y adaptable a
iPhone e iPad sin introducir coordinación global antes de tener deep links o
restauración compleja.

## Drivers

- Respetar los mecanismos de observación, persistencia y aislamiento nativos.
- Sustituir red y almacenamiento en previews/tests sin fingir que son la misma
  fuente de datos.
- Mantener navegación tipada y proporcional a tres destinos principales.
- Evitar Repository, UseCase, ViewModel o Router creados solo por convención.

## Opciones consideradas

1. **Flujos nativos según la fuente:** cada estado conserva un propietario y una
   ruta coherentes con su autoridad; reduce capas, pero la arquitectura es
   deliberadamente asimétrica.
2. **Pipeline uniforme Repository → UseCase → ViewModel → View:** ofrece una forma
   repetible, pero duplicaría `@Query`, escondería `ModelContext` y modelaría API,
   SwiftData y fixtures como sustitutos que no comparten semántica.
3. **Router y contenedor globales:** centralizan navegación y dependencias, aunque
   añaden estado compartido y acoplamiento que el alcance actual no necesita.

## Decisión

La aplicación mantiene feature-first y adopta flujos distintos según la fuente
de verdad:

- Catálogo: cliente tipado → modelo de consulta `@Observable @MainActor` → View.
- Colección: `@Query` → View para lectura; intención → comando por valor →
  capacidad `@ModelActor` → SwiftData para mutación.
- Cuenta y sincronización: actores propietarios de sesión, Keychain, refresh y
  outbox; la UI recibe únicamente estados seguros.

No se crea un Repository, UseCase, mapper, protocolo o Store salvo que separe una
variación real, una política reutilizada, un efecto o un límite de aislamiento.
En particular, API, colección local y JSON de preview no implementan un
`MangaRepository` común.

El composition root crea capacidades concretas y las distribuye mediante
inicializadores, factories o valores tipados de Environment. Environment no
contiene rutas, selección, modelos vivos ni un contenedor monolítico usado como
service locator. En previews interactivas, una sesión efímera con `URLProtocol`
local alimenta el mismo pipeline HTTP y DTO que live; SwiftData usa un
`ModelContainer` en memoria con el mismo esquema.

`MainShellView` posee `selectedTab: AppTab` y contiene un `TabView` estable con
Catálogo, Colección y Cuenta, sin una pila que envuelva todo el shell. Catálogo y
Colección poseen selecciones independientes y usan `NavigationSplitView`; Cuenta
posee `[AccountRoute]` dentro de su `NavigationStack`. Lista y cuadrícula abren el
mismo detalle compartido mediante `Manga.ID`, un valor `Hashable` y `Sendable`
independiente de `PersistentIdentifier`. No se pasan DTO ni modelos SwiftData
vivos en rutas. Filtros, modo de representación y estados de carga no son
destinos de navegación.

Al completar logout o un cambio de identidad, Colección invalida la selección y
rutas de la sesión anterior. Un logout cancelado durante su gate conserva esa
navegación. La política para crear y migrar una colección anónima queda fuera de
esta decisión.

No se introduce un router global mientras deep links, restauración o navegación
transversal programática no lo justifiquen.

## Consecuencias

### Positivas

- SwiftUI observa cada fuente mediante su mecanismo natural y sin copias
  paralelas.
- La colección conserva aislamiento contextual y una sola ruta de escritura.
- Live y preview pueden recorrer el mismo pipeline de red sin acceso real.
- iPhone e iPad comparten identidades y destinos con adaptación nativa.
- Se reduce el número de tipos y wiring necesarios para Advanced.

### Negativas

- No existe un pipeline único que memorizar para todas las features.
- El uso directo de SwiftData exige integración con contenedores reales en
  memoria.
- Environment necesita claves pequeñas y revisión para no ocultar dependencias.
- Cada tab mantiene su ruta; coordinación transversal futura requerirá otra
  decisión.
- Resolver detalle por ID obliga a representar ausencia, carga y posible dato
  desactualizado.

## Validación

- Revisar que no exista una copia observable de la colección leída con `@Query`.
- Revisar que cada protocolo o UseCase tenga más de una implementación real, una
  política reutilizada o una frontera explícita documentada.
- Probar catálogo live e interactivo con el mismo request, decoder y cliente,
  cambiando únicamente la sesión configurada.
- Probar colección con `ModelContainer` aislado y mutación `@ModelActor`.
- Verificar que Catálogo y Colección abren el mismo detalle por `Manga.ID` y que
  cada feature mantiene una única fuente de navegación.
- Verificar adaptación de `NavigationSplitView` en iPhone e iPad mediante Xcode.

## Condiciones de revisión

- Aparece una segunda fuente real para catálogo o persistencia.
- Deep links, restauración o navegación entre tabs necesitan coordinación
  programática compartida.
- La identidad remota no puede representarse inequívocamente con `Manga.ID`.
- El detalle debe compartirse fuera de SwiftUI o entre procesos.

## Especificaciones relacionadas

- [Arquitectura y composición](../specs/01-architecture-and-composition.md)
- [API, catálogo, búsqueda e imágenes](../specs/02-api-catalog-search-and-images.md)
- [Colección local e invariantes](../specs/03-local-collection-and-invariants.md)
- [Alcance de producto y niveles](../specs/00-product-scope-and-levels.md)
- [Autenticación y sincronización](../specs/04-authentication-and-sync.md)
- [Testing, calidad y accesibilidad](../specs/06-testing-quality-and-accessibility.md)
