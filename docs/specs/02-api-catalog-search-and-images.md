# API, catálogo, búsqueda e imágenes

- Estado: aprobado
- Versión: 1.1
- Última revisión: 2026-08-17

## Propósito y alcance

Definir el comportamiento observable del catálogo remoto, su paginación, búsqueda, filtros y portadas. No fija nombres de endpoints, campos ni payloads que no hayan sido verificados contra el contrato vivo.

## Autoridad del contrato

La autoridad de transporte es `/openapi/openapi.json`, accesible a través de la documentación en `/docs`. La ruta `/openapi.json` no debe asumirse.

Antes de implementar o modificar una llamada:

1. se verifica en el OpenAPI vivo el endpoint, método, autenticación, parámetros, límites y esquema;
2. la implementación modela solo los campos que necesita y que el contrato confirma;
3. los fixtures positivos de transporte deben corresponder a respuestas válidas del contrato verificado; los negativos se identifican como mutaciones deliberadamente inválidas para probar error o deriva;
4. una discrepancia entre material formativo y OpenAPI se resuelve a favor del OpenAPI para transporte, y se registra si cambia comportamiento de producto.

## Flujo técnico del catálogo

La API remota es la única fuente de producto del catálogo. La implementación live usa una `URLSession` configurada en composición, un cliente HTTP concreto y un cliente tipado de catálogo. El modelo observable de catálogo posee consulta, páginas acumuladas, carga, vacío, error, cancelación y protección frente a respuestas tardías. No persiste el catálogo remoto en SwiftData ni introduce un Repository genérico sin una segunda fuente real.

Una preview estática puede partir de un estado ya preparado. Una preview interactiva de carga, error, reintento o paginación debe servir fixtures JSON mediante un `URLProtocol` registrado solo en su sesión efímera. Así conserva el mismo request, validación HTTP, decoder, DTO, traducción y modelo de feature que producción sin acceder a red real ni mantener una implementación paralela del catálogo.

JSON positivo es un fixture validado contra el OpenAPI, no una fuente de producto; un fixture negativo queda marcado como inválido de forma deliberada. SwiftData contiene la colección y se consulta en paralelo cuando la UI necesita relacionarla con resultados remotos mediante `Manga.ID`; no implementa un catálogo local intercambiable. Métodos como cargar, buscar o pedir la siguiente página pertenecen al modelo de catálogo mientras un UseCase separado solo reenviaría una llamada.

## Requisitos de catálogo y paginación

| ID | Requisito |
| --- | --- |
| CAT-001 | El catálogo debe escalar a más de 64.000 referencias sin descarga ni materialización total. |
| CAT-002 | La primera petición de una consulta usa `per = 20`. |
| CAT-003 | Ninguna petición generada por la app usa un `per` superior a 100. |
| CAT-004 | La identidad de una consulta incluye orden, búsqueda y filtros; la siguiente página debe conservar exactamente esa identidad salvo el avance de página. |
| CAT-005 | Un cambio en búsqueda, filtros u orden reinicia la paginación a su página inicial y descarta resultados pertenecientes a la consulta anterior. |
| CAT-006 | Los filtros activos se combinan con semántica AND según el contrato vivo. La app no debe simular OR ni ampliar resultados localmente. |
| CAT-007 | La ausencia de más páginas debe detener nuevas peticiones para esa consulta. |
| CAT-008 | Respuestas tardías de una consulta sustituida no deben contaminar la consulta vigente. |
| CAT-009 | Lista y cuadrícula deben representar el mismo conjunto, búsqueda, filtros y progreso de paginación. |
| CAT-010 | El detalle debe abrir la misma identidad de manga seleccionada en lista o cuadrícula. |
| CAT-011 | Advanced debe permitir explorar o filtrar por destacados/mejores, autoría, demografía, género y tema cuando cada operación y valor hayan sido verificados en el contrato vivo. |

El tamaño `20` es la política inicial de la app, no una afirmación sobre el valor predeterminado del servidor. Cualquier optimización posterior debe mantener el máximo `100` y justificarse con evidencia.

## Búsqueda y filtros

- La aplicación ofrece los filtros que el contrato vivo exponga para alcanzar el alcance acumulado de Advanced.
- La interfaz cubre explícitamente destacados/mejores, autoría, demografía, género y tema; si el OpenAPI modifica o retira una de esas capacidades, la deriva bloquea la aceptación hasta decidir cómo reconciliar el alcance.
- Un valor de filtro se serializa con la forma y codificación que declare el OpenAPI; no se infieren nombres ni formatos a partir de ejemplos antiguos.
- La combinación visual de filtros debe coincidir con la combinación enviada.
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
- Un error de decodificación identifica deriva de contrato y debe quedar observable en diagnóstico sin exponer datos sensibles.
- Los contratos públicos o internamente relevantes de carga deben documentar efectos, cancelación y errores con DocC selectivo.

## Criterios de aceptación

| Caso | Evidencia esperada |
| --- | --- |
| Primera consulta | La petición verificada contiene `per = 20`. |
| Límite | Ningún camino permite emitir `per > 100`. |
| Página siguiente | Mantiene búsqueda, orden y filtros de la consulta inicial. |
| Cambio de filtro | Reinicia la página y una respuesta anterior tardía se ignora. |
| Varios filtros | El request construido conserva la semántica AND del contrato. |
| Cambio lista/cuadrícula | Mantiene resultados, consulta y selección. |
| Detalle | La identidad corresponde al elemento seleccionado y solo muestra datos disponibles. |
| Portada válida | Lista, cuadrícula y detalle muestran la portada. |
| Portada fallida | Los tres contextos mantienen placeholder o ausencia explícita sin saltos de identidad. |
| Fin de páginas | El desplazamiento posterior no genera más requests. |
| Preview interactiva | Usa una sesión local determinista y recorre el mismo pipeline tipado que live sin emitir tráfico real. |
| Fuente de producto | No existe un catálogo SwiftData o JSON que sustituya silenciosamente la autoridad remota. |

Las pruebas de construcción de request y decodificación usan el contrato verificado; las pruebas de interfaz validan los estados visuales sin depender de la red real.

## Fuera de alcance y riesgos

- No se implementa búsqueda de texto completa local sobre las más de 64.000 referencias.
- No se descargan por anticipado todas las portadas.
- No se fijan en esta SDD endpoints ni estructuras que todavía no se hayan confirmado en OpenAPI.
- El orden estable entre páginas depende del contrato remoto; si el servidor no lo garantiza, la limitación debe hacerse visible y decidirse antes de compensarla en cliente.
- URLs externas de imágenes pueden caducar o fallar independientemente de la respuesta de catálogo.

## Especificaciones relacionadas

- [Alcance de producto](00-product-scope-and-levels.md)
- [Arquitectura y composición](01-architecture-and-composition.md)
- [Colección local e invariantes](03-local-collection-and-invariants.md)
- [ADR-0009: flujos nativos por fuente y navegación local](../adr/0009-native-source-owned-features-and-local-navigation.md)
