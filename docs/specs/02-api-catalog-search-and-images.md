# API, catálogo, búsqueda e imágenes

- Estado: aprobado
- Versión: 1.4
- Última revisión: 2026-08-27

## Propósito y alcance

Definir el comportamiento observable del catálogo remoto, su paginación, búsqueda, filtros y portadas. No fija nombres de endpoints, campos ni payloads que no hayan sido verificados contra el contrato vivo.

## Autoridad del contrato

La autoridad de transporte es `/openapi/openapi.json`, accesible a través de la documentación en `/docs`. La ruta `/openapi.json` no debe asumirse.

Antes de implementar o modificar una llamada:

1. se verifica en el OpenAPI vivo el endpoint, método, autenticación, parámetros, límites y esquema;
2. la implementación modela solo los campos que necesita y que el contrato confirma;
3. los fixtures positivos de transporte deben corresponder a respuestas válidas del contrato verificado; los negativos se identifican como mutaciones deliberadamente inválidas para probar error o deriva;
4. una discrepancia entre material formativo y OpenAPI se resuelve a favor del OpenAPI para transporte, y se registra si cambia comportamiento de producto.

### Baseline caracterizada

La [caracterización del 25 de agosto de 2026](../api/openapi-contract.md) y su
[snapshot sanitizado](../../Contracts/OpenAPI/openapi.json) registran una
baseline histórica: OpenAPI 3.0.1, 28 paths, 30 operaciones, 19 schemas y 3
mecanismos de seguridad. El documento vivo conserva precedencia y debe
consultarse de nuevo antes de implementar.

La revalidación del 27 de agosto de 2026 no detectó deriva: el documento vivo
canonizado coincide byte a byte con el snapshot saneado y conserva SHA-256
`9fbfc6dd7fbb3d439088860e902ce3e3d62c119b8dec64bfe65369be58842c7b`.
No se realizaron llamadas funcionales al servicio.

La baseline no declara `servers`, ordenación configurable, responses distintos
de `200`, errores tipados, idempotency key, revocación, rate limits, ETag ni
versión de recurso. Los schemas de `page` y `per` tampoco codifican
`default`, `minimum` o `maximum`, aunque sus descripciones indiquen valores
operativos. La clave de sinopsis es literalmente `sypnosis`. Los paths de
colección con `{id}` describen un manga ID, pero lo modelan como `string`
mientras los mangas usan `int64` y la entrada posee además un UUID; esa
identidad debe resolverse antes de implementar esas llamadas.

## Flujo técnico del catálogo

La API remota es la única fuente de producto del catálogo. La implementación live usa una `URLSession` configurada en composición, un cliente HTTP concreto y un cliente tipado de catálogo. `HTTPClient` valida transporte, respuesta HTTP y status antes de devolver bytes no opcionales; `CatalogAPIClient` construye el request, decodifica únicamente los campos consumidos, valida metadata e identidades y traduce el resultado a valores de producto. El modelo observable de catálogo posee consulta, páginas acumuladas, carga, vacío, error, cancelación y protección frente a respuestas tardías. No persiste el catálogo remoto en SwiftData ni introduce un Repository genérico sin una segunda fuente real.

Una preview parte de un estado preparado o de un `CatalogModel.PageLoader` determinista que devuelve valores de dominio. No construye `URLSession`, `HTTPClient`, DTO, `URLProtocol` o JSON. El bootstrap de UI tests usa la misma capacidad directa en un único modo Debug fail-closed y nunca puede caer a red live.

Los JSON mock pertenecen exclusivamente a tests del cliente tipado: un fixture positivo conserva los campos consumidos y puede incluir ampliaciones remotas desconocidas; uno negativo omite o corrompe deliberadamente un requisito para probar deriva. SwiftData contiene la colección y se consulta en paralelo cuando la UI necesita relacionarla con resultados remotos mediante `Manga.ID`; no implementa un catálogo local intercambiable. Métodos como cargar, buscar o pedir la siguiente página pertenecen al modelo de catálogo mientras un UseCase separado solo reenviaría una llamada.

## Requisitos de catálogo y paginación

| ID | Requisito |
| --- | --- |
| CAT-001 | El catálogo debe escalar a más de 64.000 referencias sin descarga ni materialización total. |
| CAT-002 | La primera petición de una consulta usa `per = 20`. |
| CAT-003 | Ninguna petición generada por la app usa un `per` superior a 100. |
| CAT-004 | La identidad de una consulta incluye el conjunto de resultados, el modo de coincidencia, el texto, la autoría y las selecciones de demografía, género y tema. La siguiente página debe conservar exactamente esa identidad salvo el avance de página. El contrato actual no ofrece ordenación configurable. |
| CAT-005 | Un cambio en cualquier componente de la identidad reinicia la paginación a su página inicial, limpia la selección anterior y descarta resultados pertenecientes a la consulta sustituida. Una ordenación futura se incorporará solo después de verificarla. |
| CAT-006 | Los filtros activos se combinan con semántica AND según el contrato vivo. La app no debe simular OR ni ampliar resultados localmente. |
| CAT-007 | La ausencia de más páginas debe detener nuevas peticiones para esa consulta. |
| CAT-008 | Respuestas tardías de una consulta sustituida no deben contaminar la consulta vigente. |
| CAT-009 | Lista y cuadrícula deben representar el mismo conjunto, búsqueda, filtros y progreso de paginación. |
| CAT-010 | El detalle debe abrir la misma identidad de manga seleccionada en lista o cuadrícula. |
| CAT-011 | Advanced debe permitir buscar por autoría, demografía, género y tema mediante la operación avanzada paginada y explorar «Mejores» mediante su conjunto paginado exclusivo. El contrato actual no expone «Destacados». |

El tamaño `20` es la política inicial de la app, no una afirmación sobre el valor predeterminado del servidor. Cualquier optimización posterior debe mantener el máximo `100` y justificarse con evidencia.

Las descripciones del contrato anuncian página inicial/default `1` y `per`
default `10`/máximo `100`, pero sus schemas no expresan esos límites mediante
keywords OpenAPI. La app valida su propia política y no depende de que el servidor
rechace valores fuera de rango.

## Búsqueda y filtros

- La búsqueda principal usa `POST /search/manga` con `page` y `per`. Su body
  `CustomSearch` conserva `searchContains` y solo incluye, cuando proceda,
  `searchTitle`, `searchAuthorFirstName`, `searchAuthorLastName`,
  `searchDemographics`, `searchGenres` y `searchThemes`.
- El modo «Contiene» serializa `searchContains = true`; «Empieza por»,
  `false`. El endpoint dedicado a BEGINS WITH devuelve un array sin parámetros
  de página y no sustituye la operación avanzada para un catálogo de más de
  64.000 referencias.
- Los valores disponibles se obtienen de las operaciones públicas
  `GET /list/demographics`, `GET /list/genres` y `GET /list/themes`. Su carga
  perezosa posee estados independientes de carga, vacío, error recuperable y
  contenido; tests y previews usan un loader de dominio directo.
- «Mejores» corresponde a `GET /list/bestMangas` con `page` y `per`. Es un
  conjunto paginado ordenado por puntuación por el servidor, no una ordenación
  configurable de la búsqueda, y no puede combinarse con texto u otros filtros
  porque el contrato no declara una operación que admita esa combinación.
- No existe una operación de «Destacados» en el contrato verificado. La app no
  inventa ese conjunto ni lo sustituye por «Mejores» sin hacerlo explícito.
- La combinación visual conserva las dimensiones enviadas. El servidor aplica
  AND entre las dimensiones presentes; la app no atribuye una semántica no
  declarada a varios valores dentro de una misma lista.
- Quitar todos los filtros produce una consulta nueva sin filtros y reinicia la página.
- Los estados vacío, cargando, error recuperable y resultados deben distinguirse.
- Reintentar conserva la identidad de la consulta fallida; modificar la consulta cancela lógicamente ese reintento.

## Lista, cuadrícula y detalle

Lista y cuadrícula son dos presentaciones de un único estado de consulta. Cambiar entre ellas no debe:

- borrar filtros o texto de búsqueda;
- volver a la primera página sin una causa explícita;
- duplicar elementos ya integrados;
- cambiar el manga seleccionado.

Lista, cuadrícula y filtros son estado de la feature, no rutas distintas. La selección pertenece a la raíz de Catálogo y pasa el mismo `Manga.ID` al detalle. El detalle puede solicitar información adicional solo si el contrato ofrece una operación verificada. No debe rellenar propiedades ausentes con datos inventados.

Las previews representativas incluyen carga inicial, vacío, contenido, error inicial recuperable, fallo de página adicional conservando resultados, portada ausente o fallida y contenido largo. Su composición y aislamiento se rigen por [Testing, calidad y accesibilidad](06-testing-quality-and-accessibility.md).

## Portadas

Toda representación principal de un manga en lista, cuadrícula y detalle reserva un espacio visible para la portada.

| Estado | Comportamiento requerido |
| --- | --- |
| URL válida y carga correcta | Mostrar la imagen respetando proporción y accesibilidad. |
| Carga en curso | Mantener el espacio con un placeholder estable. |
| URL ausente o no válida | Mostrar una representación explícita de portada no disponible. |
| Error de red o decodificación | Mantener la representación de ausencia y permitir recuperación cuando proceda. |
| Reutilización o cambio de identidad | No mostrar transitoriamente la portada de otro manga. |

La carga usa APIs de Apple y no introduce una dependencia externa. La caché HTTP del sistema puede aprovecharse sin convertirse en una fuente de verdad del catálogo.

## Errores y cancelación

- Cancelar o sustituir una consulta no se presenta como error al usuario.
- Un fallo de una página adicional conserva los resultados ya visibles y ofrece reintento de esa página.
- Un fallo de la página inicial muestra un estado recuperable sin fabricar resultados.
- `NetworkError` conserva una categoría segura y una descripción localizable; nunca retiene body, URL, credenciales o error subyacente.
- Un error de decodificación de un campo consumido identifica deriva de contrato y debe quedar observable en diagnóstico sin exponer datos sensibles. Un campo remoto desconocido que la app no consume no es por sí solo deriva.
- Los contratos públicos o internamente relevantes de carga deben documentar efectos, cancelación y errores con DocC selectivo.

## Criterios de aceptación

| Caso | Evidencia esperada |
| --- | --- |
| Primera consulta | La petición verificada contiene `per = 20`. |
| Límite | Ningún camino permite emitir `per > 100`. |
| Página siguiente | Mantiene búsqueda y filtros de la consulta inicial; no inventa una ordenación ausente. |
| Cambio de consulta | Reinicia la página, limpia la selección anterior y una respuesta tardía de la consulta sustituida se ignora. |
| Búsqueda avanzada | Construye el `POST` paginado exacto y omite del body las dimensiones sin valor. |
| Varios filtros | El request construido conserva todas las dimensiones que el servidor combina con semántica AND. |
| Mejores | Usa su `GET` paginado exclusivo y no presenta texto, filtros u ordenación configurable como combinables. |
| Vocabularios | Demografía, género y tema cargan de sus operaciones verificadas con estados de carga, vacío, error recuperable y contenido. |
| Cambio lista/cuadrícula | Mantiene resultados, consulta y selección. |
| Detalle | La identidad corresponde al elemento seleccionado y solo muestra datos disponibles. |
| Portada válida | Lista, cuadrícula y detalle muestran la portada. |
| Portada fallida | Los tres contextos mantienen placeholder o ausencia explícita sin saltos de identidad. |
| Fin de páginas | El desplazamiento posterior no genera más requests. |
| Preview interactiva | Usa estado o un loader de dominio determinista sin transporte, credenciales ni almacenamiento live. |
| Fuente de producto | No existe un catálogo SwiftData o JSON que sustituya silenciosamente la autoridad remota. |

Las pruebas de construcción de request y decodificación inyectan bytes y registran el `URLRequest` real. Las pruebas de `HTTPClient` usan un `URLProtocol` limitado a su sesión; las pruebas de interfaz validan el smoke crítico con un loader de dominio y sin red real.

## Fuera de alcance y riesgos

- No se implementa búsqueda de texto completa local sobre las más de 64.000 referencias.
- No se descargan por anticipado todas las portadas.
- No se fijan en esta SDD endpoints ni estructuras que todavía no se hayan confirmado en OpenAPI. Las operaciones de C3 documentadas arriba deben revalidarse antes de una modificación posterior.
- El orden estable entre páginas depende del contrato remoto; si el servidor no lo garantiza, la limitación debe hacerse visible y decidirse antes de compensarla en cliente.
- URLs externas de imágenes pueden caducar o fallar independientemente de la respuesta de catálogo.

## Especificaciones relacionadas

- [Alcance de producto](00-product-scope-and-levels.md)
- [Arquitectura y composición](01-architecture-and-composition.md)
- [Colección local e invariantes](03-local-collection-and-invariants.md)
- [Caracterización del contrato OpenAPI](../api/openapi-contract.md)
- [ADR-0014: flujos nativos, composición live y dobles directos](../adr/0014-native-flows-live-composition-and-direct-doubles.md)
