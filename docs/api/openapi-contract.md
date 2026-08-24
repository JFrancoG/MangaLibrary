# Contrato OpenAPI

## Propósito y autoridad

Este documento caracteriza la superficie de transporte observada el 25 de agosto
de 2026. El [OpenAPI vivo][live-contract], descubierto desde la
[documentación de la API][live-docs], sigue siendo la autoridad actual antes de
implementar o modificar una operación.

El [snapshot versionado][snapshot] es una baseline histórica, canónica y
sanitizada para revisar deriva y construir fixtures futuros. No fija la URL base,
no sustituye una consulta posterior al contrato vivo y no demuestra el
comportamiento del backend.

## Identidad de la baseline

| Propiedad | Valor |
| --- | --- |
| Fecha de observación | 2026-08-25 |
| OpenAPI | 3.0.1 |
| API | Saotome Manga API 1.0.0 |
| Paths | 28 |
| Operaciones | 30 |
| Schemas | 19 |
| Security schemes | 3 |
| Referencias internas | 39 |
| SHA-256 del snapshot sanitizado | `9fbfc6dd7fbb3d439088860e902ce3e3d62c119b8dec64bfe65369be58842c7b` |

El documento vivo no declara `servers`. La procedencia conocida permite
descubrir el contrato, pero la URL de transporte deberá entrar por configuración
y no se incorpora como una verdad inventada dentro del snapshot.

## Transformación y privacidad

La respuesta cambia el orden de sus miembros entre descargas. Para obtener una
representación estable se ordenan recursivamente las claves con `jq --sort-keys`
y se termina el archivo con una nueva línea.

Antes de versionar se retiran:

- `info.contact`;
- `components.examples`;
- cualquier miembro `example` o `examples`;
- la descripción de `http_basic`, porque incluía credenciales demostrativas.

La transformación conserva paths, métodos, parámetros, request bodies,
responses, schemas, `required`, `nullable`, enums y los tres
`securitySchemes`. Los nombres de los mecanismos y cabeceras son contrato; sus
valores no se versionan.

El snapshot se puede regenerar sin almacenar la respuesta cruda:

```sh
curl --fail --silent --show-error --location \
  https://mymanga-acacademy-5607149ebe3d.herokuapp.com/openapi/openapi.json \
| jq --sort-keys \
  'walk(if type == "object" then del(.example, .examples) else . end)
   | del(.info.contact,
         .components.examples,
         .components.securitySchemes.http_basic.description)' \
> Contracts/OpenAPI/openapi.json

(cd Contracts/OpenAPI && shasum -a 256 -c SHA256SUMS)
```

Una regeneración no se acepta de forma automática por coincidir en recuentos:
primero se revisa la deriva semántica y su impacto en las SDD, DTOs y fixtures.

## Autenticación

| Protección | Operaciones | Uso declarado |
| --- | ---: | --- |
| Pública | 17 | Catálogo, búsqueda, autores y vocabularios |
| `http_basic` | 3 | Login legacy, JWT y sesión dual |
| `bearerAuth` | 9 | Sesión, identidad y colección |
| `appTokenAuth` | 1 | Alta de usuario mediante cabecera `App-Token` |

La sesión dual que adopta el producto está compuesta por:

1. `POST /users/session/login`, con Basic Auth, devuelve un refresh JWT de
   treinta días;
2. `GET /users/session/access`, con el refresh JWT como Bearer, devuelve un
   access JWT de una hora;
3. `GET /users/session/me` y las operaciones protegidas consumen el access JWT.

`DualSessionTokenResponse` diferencia `tokenUse` y entrega `token`,
`tokenType` y `expiresIn`. El contrato no declara revocación remota. Tampoco
declara OAuth, scopes ni una garantía de que un refresh token sea rechazado por
todos los recursos mediante una restricción machine-readable; esa separación
aparece en las descripciones y debe respetarse en el cliente.

Los flujos legacy y JWT de un solo token siguen presentes, pero no sustituyen la
decisión de sesión dual de la [SDD 04][sdd-04].

## Catálogo, búsqueda y paginación

Las diecisiete operaciones públicas se agrupan en:

- doce operaciones `/list` para mangas paginados, mejores mangas, autores,
  demografías, géneros y temas;
- cinco operaciones `/search` para detalle por ID, autor, prefijo, contenido y
  búsqueda avanzada.

`POST /search/manga` recibe `CustomSearch`. Sus filtros son opcionales y se
combinan con semántica AND. `searchContains` es el único miembro requerido y
selecciona entre CONTAINS y BEGINS WITH. Autor, demografía, género, tema y título
se transportan con las claves wire declaradas; la app no traduce ni inventa
valores del backend.

`GET /search/mangasBeginsWith/{search}` devuelve un array y no acepta
paginación. No será la ruta principal para una búsqueda escalable mientras
`POST /search/manga` ofrece el mismo modo de prefijo dentro de una respuesta
`MangaPageDTO`.

`page` y `per` son query parameters enteros, opcionales y nullable. Sus
descripciones anuncian página inicial/default 1 y `per` default 10/máximo 100,
pero sus schemas no contienen `default`, `minimum` ni `maximum`. La política
de la app de empezar con `per = 20` y no superar 100 permanece explícita y
testeable, sin atribuir esos keywords ausentes al schema.

No existe parámetro de ordenación ni garantía machine-readable de orden estable
entre páginas. Una página siguiente debe conservar la búsqueda y los filtros; el
cliente no ofrece ordenación configurable mientras el contrato no la declare.

## Colección

Las cuatro operaciones protegidas son:

| Método y path | Contrato observado |
| --- | --- |
| `GET /collection/manga` | Devuelve las entradas de la persona autenticada |
| `POST /collection/manga` | Añade o actualiza mediante `UserMangaCollectionRequest` |
| `GET /collection/manga/{id}` | Devuelve una entrada descrita como seleccionada por manga |
| `DELETE /collection/manga/{id}` | Elimina una entrada descrita como seleccionada por manga |

La petición de escritura requiere `manga` como `int64`,
`completeCollection` y `volumesOwned`; `readingVolume` es nullable. La
respuesta de lectura incluye un `id` UUID propio de la entrada y un
`MangaDTO` completo.

Existe una inconsistencia que debe resolverse antes de implementar los dos paths
con `{id}`: sus descripciones dicen “manga ID”, el parámetro solo se llama
`id` y su schema es `string`, mientras `MangaDTO.id` y el campo
`UserMangaCollectionRequest.manga` son `int64`; además, la entrada expone otro
`id` con formato UUID. No se elegirá silenciosamente entre identidad de manga e
identidad de entrada.

`POST` y `DELETE` responden con un entero sin semántica adicional tipada. El
OpenAPI tampoco ofrece idempotency key. Estas ausencias sostienen la política de
outbox y resultado ambiguo de la [SDD 04][sdd-04]; el UUID local de una operación
no se enviará como garantía remota inventada.

## Wire keys y modelos

`MangaDTO` requiere `id`, `title`, `score`, `status`, `authors`,
`demographics`, `genres` y `themes`. El resto de sus datos, incluidas fechas,
volúmenes, capítulos, portada y títulos alternativos, puede ser nullable.

La sinopsis usa literalmente la clave wire `sypnosis`. Un DTO Swift podrá
ofrecer un nombre interno correcto mediante `CodingKeys`, pero el decoder debe
consumir la grafía contractual mientras el servidor no la cambie.

`MangaStatus` y `AuthorRole` son enums cerrados en esta baseline. Una opción
desconocida futura es deriva de contrato y no debe convertirse silenciosamente
en otro caso existente. `mainPicture` y `url` son strings nullable, no schemas
`uri`; el cliente validará su conversión a `URL`.

## Vacíos contractuales

- Las treinta operaciones solo modelan respuesta `200`. Algunas descripciones
  mencionan `404`, pero no existe response ni payload de error tipado.
- No hay `servers`, ordenación configurable, idempotency key, endpoint de
  revocación, rate limits, ETag ni versión de recurso.
- Los schemas de paginación omiten límites y defaults machine-readable.
- No se declara una política de compatibilidad ni versionado de la API.
- No se garantiza orden estable entre páginas.
- La identidad de `/collection/manga/{id}` es contradictoria entre descripción
  y tipos.
- La búsqueda dedicada por prefijo no es paginada y no satisface por sí sola el
  requisito de catálogo escalable.

El cliente deberá validar el status HTTP antes de decodificar, mapear los
no-`2xx` sin asumir un payload inexistente y conservar diagnóstico de deriva
sin registrar bodies, tokens o datos personales.

## Política de deriva

Antes de implementar o cambiar una operación:

1. recuperar el OpenAPI vivo desde la ruta documentada;
2. compararlo canónicamente con esta baseline;
3. revisar paths, autenticación, parámetros, required/nullable, enums y
   responses, no solo los recuentos;
4. actualizar la SDD o ADR correspondiente cuando cambie una verdad de producto;
5. regenerar snapshot y checksum solo dentro de una unidad revisable;
6. derivar después DTOs y fixtures mínimos para la operación implementada.

No se realizan peticiones funcionales, login, altas ni escrituras para validar
esta baseline. Build, tests de Xcode y TDD no aplican a este cambio documental;
sí aplican validación JSON/OpenAPI, referencias, checksum, privacidad, enlaces y
revisión iOS/API.

[live-docs]: https://mymanga-acacademy-5607149ebe3d.herokuapp.com/docs
[live-contract]: https://mymanga-acacademy-5607149ebe3d.herokuapp.com/openapi/openapi.json
[snapshot]: ../../Contracts/OpenAPI/openapi.json
[sdd-04]: ../specs/04-authentication-and-sync.md
