# Arquitectura y composición

- Estado: aprobado
- Versión: 1.9
- Última revisión: 2026-09-04

## Propósito y alcance

Definir la organización arquitectónica de Manga Library, sus límites de aislamiento y el punto donde se componen las dependencias. Esta especificación cubre la app y sus extensiones; no prescribe una capa por cada operación ni una jerarquía ceremonial.

## Decisiones aprobadas

- Arquitectura **feature-first**.
- Cada flujo sigue a su **fuente de verdad**; no se impone un pipeline uniforme de Repository, UseCase, ViewModel y View.
- Todo estado mutable, recurso y tarea tiene propietario, ciclo de vida y aislamiento identificables.
- Un único **composition root** crea las dependencias compartidas y configura sus implementaciones concretas.
- SwiftData se usa directamente mediante `@Model`, `@Query` y aislamiento contextual.
- Las lecturas de interfaz usan el contexto apropiado; las mutaciones persistentes recorren una única ruta, aislada mediante `@ModelActor` por defecto.
- El aislamiento predeterminado del módulo es `nonisolated`; `@MainActor` se declara de forma explícita donde corresponda a estado y efectos de interfaz.
- Swift 6.4 con comprobación estricta de concurrencia.
- Sin dependencias externas.
- Swift Testing es la base de la estrategia híbrida; XCTest se reserva para capacidades que lo requieran.
- La navegación principal usa componentes SwiftUI nativos, rutas tipadas y estado propiedad de la feature que presenta el destino.

Estas decisiones se desarrollan en [ADR-0002](../adr/0002-feature-first-and-composition-root.md), [ADR-0003](../adr/0003-concurrency-and-default-isolation.md), [ADR-0004](../adr/0004-swiftdata-local-first-and-model-actors.md) y [ADR-0017](../adr/0017-validated-http-status-response-boundary.md).

## Organización lógica

Cada feature agrupa su interfaz, estado de presentación estrictamente necesario y efectos propios. Un tipo separado existe por una responsabilidad real, no para completar una plantilla arquitectónica. Los componentes compartidos aparecen solo cuando más de una feature necesita el mismo contrato técnico o destino de producto.

Los límites previstos son:

- **App/composición**: crea el contenedor SwiftData, `URLSession` configurada, cliente HTTP y factories; distribuye capacidades pequeñas y crea propietarios de sesión o feature con su ciclo de vida correcto.
- **Catálogo**: listado, cuadrícula, búsqueda, filtros, paginación y carga de portadas.
- **Colección**: consultas locales, comandos de mutación e invariantes.
- **Detalle de manga**: destino compartido por catálogo y colección, resuelto siempre a partir de una identidad estable.
- **Cuenta**: creación de cuenta, login, estado de sesión y logout.
- **Capacidades internas**: transporte, sesión, Keychain, outbox, envío, reintentos y reconciliación; no se convierten en features de UI por tener una carpeta o actor propio.
- **Puentes Deluxe**: proyecciones de solo los datos necesarios para watchOS y WidgetKit.

Esta lista define responsabilidades, no obliga a crear una carpeta, protocolo o tipo por cada viñeta.

## Propiedad, ciclo de vida e inyección

| Ámbito | Propietario típico | Responsabilidad y finalización |
| --- | --- | --- |
| App | composition root | recursos únicos de proceso, `ModelContainer`, configuración HTTP y factories |
| Sesión | actor de sesión y coordinador asociado | Keychain, refresh y sync de una identidad; invalida tareas al completar logout o cambio de usuario |
| Feature | raíz de Catálogo, Colección o Cuenta | modelo observable, selección y navegación propias; cancela o invalida trabajo al terminar el flujo |
| Presencia de View | SwiftUI mediante `@State` y `.task` | estado visual efímero o modelo observable creado por la propia View, y tareas que solo tienen sentido mientras está presente |
| Operación | tarea estructurada o actor receptor | request, comando o lote acotado; propaga cancelación y devuelve valores por frontera |

Una View puede mantener estado local de presentación pequeño y propio de su
identidad, incluidos adaptadores del framework como `@FocusState`. Un modelo
`@Observable @MainActor` aparece cuando la pantalla posee consulta remota,
transiciones, cancelación, coordinación o navegación no trivial; no es
obligatorio para reflejar una lectura `@Query`. Un actor o contexto posee
invariantes y recursos mutables persistentes.

Cuando una pantalla crea un modelo `@Observable` de su propio ciclo de vida, lo
conserva mediante `@State` para estabilizar su identidad. Un modelo compartido
que llega por inicializador se mantiene como referencia ordinaria: Observation
registra sus lecturas sin necesidad de convertirlo en `@State`, y `@Bindable` se
usa solo cuando la View necesita proyectar bindings sobre ese objeto. La
obligación concreta de extraer la presentación no trivial de credenciales queda
acotada por ARCH-021 y AUTH-013.

Las dependencias locales obligatorias se pasan por inicializador o factory. Environment se reserva a capacidades compartidas deliberadamente por un subárbol. Ningún scope puede conservar tareas o estado de otro usuario después de finalizar.

## Requisitos arquitectónicos

| ID | Requisito |
| --- | --- |
| ARCH-001 | El código específico de una feature debe permanecer dentro de esa feature hasta que exista reutilización real. |
| ARCH-002 | El composition root debe seleccionar exclusivamente implementaciones live y factories; no interpreta argumentos de proceso ni elige fixtures. Cada recurso se crea en ámbito app, sesión, feature u operación según su propietario real. |
| ARCH-003 | Ninguna View debe crear clientes HTTP, almacenes de tokens, contenedores SwiftData ni coordinadores de sincronización. |
| ARCH-004 | Las Views pueden leer modelos mediante `@Query`, pero no deben modificar directamente estado persistente sujeto a invariantes. |
| ARCH-005 | Toda mutación de colección y outbox debe atravesar el mismo límite `@ModelActor` o una especialización explícitamente justificada. |
| ARCH-006 | Los modelos `@Model` no deben cruzar libremente contextos de SwiftData; los límites concurrentes intercambian identificadores o valores copiables. |
| ARCH-007 | `@MainActor` debe limitarse a estado o efectos que requieren el actor principal, no usarse como anotación general para silenciar diagnósticos. |
| ARCH-008 | El transporte y el procesamiento fuera de interfaz deben exponer valores seguros para cruzar aislamientos, sin añadir conformidades `Sendable` redundantes o inseguras. |
| ARCH-009 | Cada estado mutable, recurso y tarea debe tener propietario, ciclo de vida, aislamiento y condición de cancelación o invalidación identificables. |
| ARCH-010 | La implementación no debe introducir capas de repository, interactor, mapper o protocol por convención si no separan una variación, efecto o frontera comprobable. |
| ARCH-011 | Una extensión Deluxe no debe abrir directamente el almacén privado de ejecución de otro proceso; recibe una proyección mediante el puente aprobado. |
| ARCH-012 | Todo target debe tratar warnings como errores y no depender de paquetes externos. |
| ARCH-013 | Cada flujo debe conservar una sola fuente por responsabilidad y declarar su propietario. Una View puede poseer estado local de presentación; un modelo de pantalla puede poseer presentación o workflow no trivial cuando el flujo lo defina; SwiftData posee estado persistido y los actores de sesión/sync sus recursos aislados. El mismo estado no se duplica entre esos límites. |
| ARCH-014 | Un modelo observable no debe duplicar una colección que la View ya obtiene con `@Query`. |
| ARCH-015 | Environment distribuye capacidades tipadas de ámbito apropiado; no contiene selección de navegación, modelos vivos ni un contenedor consultable como service locator. |
| ARCH-016 | La navegación pasa `Manga.ID`, un valor estable `Hashable` y `Sendable`; no pasa `PersistentIdentifier`, DTO, tokens, `@Model` vivos ni clientes de infraestructura. |
| ARCH-017 | El shell principal debe ofrecer Catálogo, Colección y Cuenta con `TabView`; el cambio lista/cuadrícula, los filtros y los estados de carga no son rutas. |
| ARCH-018 | Catálogo y Colección poseen localmente su selección. Catálogo usa un `NavigationStack` tipado en compacto y un `NavigationSplitView` en regular; Colección adopta su contenedor nativo al implementarse sin compartir rutas con Catálogo. Cuenta posee un `NavigationStack` lineal para autenticación. |
| ARCH-019 | No se crea un router global mientras no exista una necesidad aprobada de deep links, restauración o navegación transversal programática. |
| ARCH-020 | Un cambio de identidad completado invalida la selección y rutas de Colección de la sesión anterior; un intento de logout cancelado no las borra. |
| ARCH-021 | Cada presencia en pantalla de un formulario de credenciales crea un modelo `@Observable @MainActor` y su View lo retiene con `@State`; `AccountRoute` continúa siendo solo un valor de navegación. Ese modelo conserva borradores, validación presentada, visibilidad de contraseña, intención de foco, tarea y limpieza; `AccountModel` sigue siendo la única autoridad compartida de sesión y workflow remoto, y la View se limita a renderizar, enlazar y adaptar `@FocusState`. |

## Propiedad del estado y flujo por feature

| Flujo | Fuente de verdad | Propietario observable o aislado | Camino hacia SwiftUI |
| --- | --- | --- | --- |
| Catálogo | API remota verificada | Modelo de consulta `@Observable @MainActor` | cliente tipado → modelo de feature → View |
| Colección | SwiftData local | `@Query` para lectura y capacidad `@ModelActor` para mutación | `@Query` → View; intención → comando por valor → actor → SwiftData |
| Cuenta | Sesión segura y borradores efímeros de cada formulario | actor de sesión y `AccountModel` para sesión/workflow remoto; modelo de formulario por presencia en pantalla para presentación de credenciales | actor ↔ `AccountModel` ↔ modelo de formulario → View; intención de View → modelo de formulario → `AccountModel` |
| Sincronización | outbox SwiftData y confirmación remota | coordinador actor | outbox → red → reconciliación → SwiftData → `@Query` |

La API, SwiftData y los datos de preview no son implementaciones equivalentes de un `MangaRepository`: representan autoridades y grados de completitud diferentes. Una preview construye directamente el estado o la capacidad mínima que necesita; no convierte una colección local parcial ni un fixture en la fuente del catálogo remoto paginado.

Un UseCase separado solo se justifica cuando expresa una política u operación semántica compuesta y reutilizable. Cargar una página delegando inmediatamente en un único cliente, o envolver una mutación ya expresada por una capacidad semántica, no basta para crear otro tipo.

## Composición e inyección

El composition root selecciona únicamente las implementaciones live y construye cada una con el ámbito correcto. Como mínimo conoce el `ModelContainer`, la `URLSession` configurada, el cliente HTTP y las factories de sesión, persistencia y sincronización. Previews, Swift Testing y el bootstrap Debug de UI tests componen sus dobles fuera de `AppComposition`.

- Las capacidades compartidas llegan mediante valores tipados de Environment.
- El modelo observable de una feature recibe por inicializador o factory solo las capacidades que necesita.
- Una View no construye red, persistencia, Keychain ni actores de negocio.
- Una dependencia de preview o test nunca usa configuración live por defecto.
- Navigation y selección permanecen como estado local de presentación; no se inyectan como servicios.

La composición live puede cambiar la configuración concreta sin cambiar las funciones públicas de la feature, pero nunca selecciona datos mock. Catálogo recibe un loader de página directo en previews y UI tests; sus pruebas de cliente inyectan bytes en la frontera tipada y las del transporte reservan `URLProtocol` para `HTTPClient`. Para SwiftData, el reemplazo continúa siendo un `ModelContainer` en memoria con el mismo esquema.

## Navegación

`MainShellView` es la raíz estable del producto. Posee `selectedTab: AppTab` y el
aviso efímero y opcional de R1 ligado a la identidad autenticada. Ese aviso no
replica la sesión ni la colección: se limpia al cambiar la identidad o completar
una sincronización y solo adapta a presentación el error tipado de autorización.
Para R2, la raíz observa la outbox mediante `@Query` y deriva exclusivamente de
un `blockedOutcome` persistido el aviso de escritura no confirmada de la identidad
activa; no copia ese estado a `@State`, sobrevive a fallos anteriores de R1 y
desaparece al resolver la operación durable. El aviso efímero de R1 y este aviso
durable se presentan por separado para que un fallo de lectura nunca oculte el
único acceso a la resolución. Cuenta añade una ruta tipada que muestra mediante
`@Query` las operaciones bloqueadas de la identidad activa; cada destino de
detalle recibe una identidad de operación por valor y crea un modelo de workflow
que comprueba la versión remota antes de habilitar una decisión. La capacidad de
resolución llega desde composición y ninguna View muta SwiftData o construye red.
La raíz contiene tres destinos
estables con el estilo predeterminado de `TabView`:

1. **Catálogo**: usa `magnifyingglass` para expresar descubrimiento y búsqueda, con `NavigationStack` tipado por `Manga.ID` en presentación compacta y `NavigationSplitView` con lista o cuadrícula y detalle en regular.
2. **Colección**: usa `books.vertical.fill` para expresar la biblioteca personal, con navegación local e independiente y el mismo detalle compartido; su contenedor adaptable se concreta al implementar la feature.
3. **Cuenta**: `NavigationStack` para estado de cuenta, login y registro.

No se envuelve todo el `TabView` en un `NavigationStack`. Catálogo posee `selectedCatalogMangaID: Manga.ID?`; esa selección deriva el path homogéneo `[Manga.ID]` de su stack compacto y alimenta el detalle del split regular, sin una segunda fuente de navegación. Colección posee `selectedCollectionMangaID: Manga.ID?`; Cuenta posee una ruta tipada `[AccountRoute]`.

`Manga.ID` es la identidad de producto compartida entre catálogo, colección y detalle: un valor estable `Hashable` y `Sendable`, independiente de `PersistentIdentifier`. Solo necesitará `Codable` si una decisión posterior aprueba restauración o deep links. Una selección inexistente, todavía no cargada o desactualizada se representa como estado explícito, no como objeto retenido en la ruta.

Las hojas que editan un elemento usan identidad estable y presentación item-driven. Filtros, cambio lista/cuadrícula, loading, vacío y error pertenecen al estado de la pantalla. No compiten con la ruta de detalle.

La autenticación no se modela como router global. Catálogo permanece disponible sin una sesión de usuario; Cuenta representa estado autenticado o no autenticado dentro del shell. Colección conserva las reglas de aislamiento por identidad de SDD 03 y 04. Permitir una colección anónima nueva y migrarla después a una cuenta requeriría una política de producto y sincronización separada; esta arquitectura no la presupone.

Después de completar el gate de logout o un cambio de usuario, Colección limpia o revalida selección y rutas antes de mostrar el nuevo scope. Si logout se cancela durante su gate, conserva el estado de navegación vigente.

## Flujo de datos

### Lectura

1. Catálogo consume el estado de consulta que publica su modelo observable después de validar, decodificar y mapear la respuesta remota.
2. Colección ejecuta una consulta contextual con `@Query`; SwiftData notifica los cambios confirmados en el contexto observado.
3. Cuenta consume un estado seguro que no expone tokens.
4. La View deriva su representación sin conservar una copia paralela innecesaria de ninguna fuente.

### Mutación local y sincronización

1. La intención de usuario se convierte en un comando de la feature.
2. El actor de mutación valida y normaliza las invariantes.
3. En una misma operación lógica, actualiza la colección local y registra o coalesce la operación de outbox.
4. La UI cambia al observar SwiftData.
5. La composición conserva por valor la autoridad y las entradas del snapshot que
   R1 ya importó; R2 reautoriza esa autoridad antes de reutilizarlo y evita una
   segunda lectura al reconciliar trabajo `sending` recuperado.
6. El coordinador de outbox procesa valores estables y reconcilia el resultado
   mediante la misma ruta de mutación.

La red nunca escribe directamente en estado de View. El detalle operativo está en [Autenticación y sincronización](04-authentication-and-sync.md).

## Concurrencia y aislamiento

- `nonisolated` es el punto de partida, no una renuncia al aislamiento.
- Views y estado observable ligado a renderizado o navegación declaran `@MainActor` cuando el compilador o el contrato lo requieren.
- Los servicios con estado mutable compartido se protegen con actor.
- Las tareas pertenecen al mismo ámbito que su propietario y se cancelan o invalidan al finalizar ese ámbito.
- Las operaciones SwiftData respetan el `ModelContext` del actor o entorno que las ejecuta.
- El trabajo costoso solo se desplaza fuera del actor actual mediante una frontera deliberada y datos aptos para cruzarla.
- La cancelación y los errores forman parte de los contratos asíncronos relevantes y se documentan de forma selectiva con DocC.

## Criterios de aceptación

- Una inspección del árbol permite asignar cada archivo de producto a una feature o a una dependencia verdaderamente compartida.
- Las pruebas pueden inyectar capacidades controladas sin alterar singletons globales ni la composición live.
- No existe creación de infraestructura dentro de una View.
- La evidencia combinada cubre transporte HTTP, request, decoding, mapping, modelo, preview y smoke UI sin exigir que una preview atraviese el pipeline live.
- Una búsqueda estática y la revisión de código no encuentran escrituras directas a propiedades de colección desde Views.
- Una búsqueda estática no encuentra una copia observable de la colección completa ni un Repository/UseCase de una sola implementación sin frontera demostrada.
- Las mutaciones concurrentes de una misma entrada se serializan en el actor de modelo y dejan colección y outbox en un estado válido.
- Ningún `@Model` se pasa como dato de trabajo a un actor con otro contexto.
- Catálogo y Colección abren el mismo detalle mediante `Manga.ID` y conservan rutas locales independientes al cambiar de tab.
- Catálogo y Colección se distinguen en el shell mediante sus símbolos semánticos `magnifyingglass` y `books.vertical.fill`.
- Un `blockedOutcome` activo conserva siempre un acceso visible desde Cuenta,
  aunque exista simultáneamente un aviso efímero de R1; su lista se deriva de
  SwiftData y una decisión atraviesa la capacidad aislada de Colección.
- Completar logout o cambiar de usuario no permite que la selección anterior resuelva un detalle privado; cancelar logout no destruye prematuramente la navegación.
- iPhone e iPad presentan el flujo list-detail sin dos fuentes de navegación competidoras.
- El build con comprobación estricta de concurrencia y warnings-as-errors termina limpio.
- Toda excepción a estos requisitos está decidida en un ADR y enlazada desde la especificación afectada.

## Fuera de alcance y riesgos

- No se impone Clean Architecture, MVVM global ni una capa de dominio duplicada sobre SwiftData.
- La arquitectura es asimétrica de forma intencional; aprender un flujo distinto por fuente evita fingir sustituciones que no existen.
- Feature-first no autoriza ciclos entre features; una necesidad compartida debe reducirse a un contrato pequeño o resolverse desde composición.
- El uso directo de SwiftData aumenta el valor de pruebas de integración con contenedor real en memoria.
- Environment puede ocultar dependencias si se usa como bolsa global; cada clave debe tener un ámbito y consumidor claros.
- La navegación local simplifica el alcance actual, pero deep links o restauración compleja exigirían una decisión posterior.
- Un `@MainActor` demasiado amplio ocultaría decisiones de concurrencia y puede bloquear la interfaz; debe revisarse como riesgo arquitectónico.

## Especificaciones y decisiones relacionadas

- [Alcance de producto](00-product-scope-and-levels.md)
- [Colección local e invariantes](03-local-collection-and-invariants.md)
- [Autenticación y sincronización](04-authentication-and-sync.md)
- [ADR-0002: feature-first y composition root](../adr/0002-feature-first-and-composition-root.md)
- [ADR-0003: concurrencia y aislamiento predeterminado](../adr/0003-concurrency-and-default-isolation.md)
- [ADR-0004: SwiftData local-first y model actors](../adr/0004-swiftdata-local-first-and-model-actors.md)
- [ADR-0017: flujos nativos y respuesta HTTP con status validado](../adr/0017-validated-http-status-response-boundary.md)
