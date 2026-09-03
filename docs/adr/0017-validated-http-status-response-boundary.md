# ADR-0017: Flujos nativos y respuesta HTTP con status validado

**Estado:** Accepted
**Fecha:** 2026-08-31
**Última revisión:** 2026-09-03
**Supersede:** [ADR-0015](0015-native-flows-live-composition-and-adaptive-navigation.md)
**Superseded by:** —

## Contexto

ADR 0014 separó transporte y contratos de feature mediante un `HTTPClient` que
validaba un único status y devolvía solo bytes. ADR 0015 conservó esa frontera y
estableció que una operación que necesitara metadata HTTP exigiría revisar la
decisión.

El OpenAPI de `POST /users` continúa publicando únicamente `200` con un
`integer/int64`, mientras el enunciado aprobado y el backend real devuelven
`201 Created`. Registro necesita distinguir ambos status después de validarlos:
`200` conserva el requisito de decodificar el entero; `201` confirma la creación
sin depender de un body no caracterizado. Convertir `201` en error impide el
login automático y aceptar cualquier `2xx` daría por terminado un `202` que solo
representa procesamiento aceptado.

La revisión no debe obligar a Catálogo o Sesión a consumir metadata que no
necesitan ni introducir decoding, endpoints o contratos de feature en el
transporte compartido.

R2.2 activa la condición de revisión porque Colección también necesita distinguir
dos status ya validados. `GET /collection/manga/{id}` interpreta `200` como una
entrada y el `404` descrito por OpenAPI como ausencia durante la reconciliación de
un DELETE incierto. Convertir ese `404` en `NetworkError` volvería a modelar un
resultado aceptado por la operación como error e impediría confirmar la ausencia
sin repetir una escritura.

## Drivers

- Representar `201 Created` como éxito, no como un error interceptado después.
- Aceptar solo los status que cada operación haya caracterizado.
- Mantener bytes y status no opcionales después de validar una respuesta HTTP.
- Conservar decoding y política contractual dentro del cliente de feature.
- No exponer headers, URL, body o datos sensibles en errores o presentación.
- Preservar las fronteras directas de Catálogo, Sesión, previews y tests cuando
  no necesitan status.

## Opciones consideradas

1. **Respuesta mínima con bytes y status, validada por allowlist exacta:** hace
   explícita la semántica de Registro y conserva el adaptador de bytes existente.
2. **Tratar `.statusCode(201)` como éxito dentro de Registro:** reduce el diff,
   pero modela un resultado válido como error y deja implícita la política.
3. **Aceptar cualquier `2xx` y devolver bytes:** simplifica el transporte, pero
   confunde creación terminada con respuestas como `202 Accepted`.
4. **Migrar todos los clientes a una respuesta HTTP completa:** uniformiza la
   firma, pero filtra metadata innecesaria y amplía sin motivo Catálogo y Sesión.

## Decisión

Se adopta la primera opción. `HTTPClient` ofrece dos adaptadores:

- `data(for:expecting:)` acepta un único status, delega en la nueva primitiva y
  continúa devolviendo `Data` a los clientes que no necesitan metadata;
- `response(for:accepting:)` recibe un `Set<Int>` exacto y devuelve un
  `HTTPResponse` por valor con `data` y `statusCode`, únicamente después de
  comprobar que la respuesta es HTTP y que su status pertenece al conjunto.

El transporte sigue sin decodificar DTO, conocer endpoints o decidir qué status
confirma una operación. Mantiene el mapping seguro de transporte, respuesta no
HTTP, status inesperado y cancelación. `HTTPResponse` no incorpora headers, URL
ni descripción del body.

`UserRegistrationClient` y el GET individual de `CollectionAPIClient` son las
fronteras actuales que consumen la respuesta con status. Registro admite
exactamente `200` y `201`; después, el cliente de feature aplica la política de
SDD 04:

- `200` confirma solo si el body decodifica el `Int64` publicado;
- `201` confirma por el status y no interpreta su body;
- cualquier otro status conserva el resultado como no confirmado.

El GET individual de Colección admite exactamente `200` y `404`: `200` exige un
DTO válido cuyo `manga.id` coincida con el segmento solicitado, mientras `404`
ignora el body y representa ausencia únicamente para esa ruta. GET completo,
POST y DELETE continúan usando el adaptador de bytes y aceptando solo `200`.

Sus dobles directos devuelven el mismo valor mínimo para probar la política sin red.
Tests de integración aislados con `URLProtocol` atraviesan además el adaptador
real de `HTTPClient` para caracterizar `200`, `201` vacío y el rechazo de `202`
con body aparentemente válido. Tests y previews no usan producción.

Se conservan sin cambios las demás decisiones vigentes de ADR 0015: arquitectura
feature-first, composition root exclusivamente live, dobles directos,
navegación adaptable de Catálogo, ruta lineal de Cuenta, animación local de
portada, toolbar, Reduce Motion y smoke UI mínimo.

## Consecuencias

### Positivas

- El tipo transporta un status válido sin convertirlo primero en error.
- Cada feature declara una allowlist cerrada y no generaliza rangos HTTP.
- Catálogo y Sesión conservan la costura simple de bytes.
- El body `201` puede evolucionar sin crear falsa deriva contractual.
- La regresión se reproduce sin cuenta, secreto o red live.

### Negativas

- Existen dos adaptadores públicos dentro del módulo para elegir entre bytes y
  bytes con status.
- Los dobles de Registro y del GET individual conocen el valor mínimo de
  transporte necesario para probar su política.
- Una operación que necesite headers requerirá otra revisión; no se anticipa una
  respuesta HTTP genérica.

## Validación

- Demostrar en RED que `201` vacío quedaba como `.statusCode(201)` y en GREEN
  que confirma el alta.
- Probar que `200` continúa exigiendo un `Int64` válido.
- Probar que `202`, incluso con body `42`, no confirma.
- Probar que el GET individual acepta `404` sin interpretar el body, exige un ID
  coincidente en `200` y conserva cualquier otro status como fallo.
- Conservar verdes los tests de respuesta no HTTP, status inesperado,
  transporte y cancelación de `HTTPClient`.
- Ejecutar tests focales, `ReleaseGate`, build, diagnósticos y DocC sin warnings
  de Swift, Clang o DocC.
- No repetir altas, login ni escrituras live desde tests o herramientas.

## Condiciones de revisión

- Una operación necesita headers u otra metadata HTTP después de validar status.
- Una tercera feature necesita status o dos operaciones empiezan a duplicar la
  misma política de aceptación o decoding.
- El backend y OpenAPI reconcilian `POST /users` con un único contrato distinto.
- Una respuesta puede confirmar parcialmente y exige un modelo de dominio más
  rico que bytes y status.

## Especificaciones relacionadas

- [Arquitectura y composición](../specs/01-architecture-and-composition.md)
- [API, catálogo, búsqueda e imágenes](../specs/02-api-catalog-search-and-images.md)
- [Autenticación y sincronización](../specs/04-authentication-and-sync.md)
- [Testing, calidad y accesibilidad](../specs/06-testing-quality-and-accessibility.md)
