# Ejemplos de contrato Deluxe

Estos JSON son ejemplos sintéticos del [contrato aprobado DX1 / SDD 09](../../docs/specs/09-deluxe-reading-contract.md).
No contienen datos reales ni constituyen por sí solos evidencia ejecutable.
Los tests DX2 de codec/publicación leen estos archivos desde el checkout; no se
incluyen en el bundle de producto ni acreditan un transporte WatchConnectivity.

Los resultados esperados de esta tabla y de `projection-scenarios.json` son el
oráculo independiente para Swift Testing; no se calculan desde
una implementación de Deluxe. La verificación DX1 comprueba que los ejemplos se
pueden leer y que los defectos intencionados y conteos concuerdan con la tabla.

| Archivo | Resultado esperado |
| --- | --- |
| `content.json` | Contenido A con IDs `[20, 10, 30]`; último tomo todavía en lectura, propiedad independiente y título/total ausentes. |
| `empty.json` | Vacío verdadero de A, 0 elegibles. |
| `redacted.json` | Redacción dirigida a A, sin payload de lectura; no retira B. |
| `unavailable.json` | No disponible, sin sesión ni payload; no es vacío. |
| `uint64-max.json` | Decodifica revisión `18446744073709551615` exacta; la siguiente reserva exige rotar epoch, no sumar con wrap. |
| `future-format.json` | Versión 2 rechazada completa, no disponible. |
| `future-state.json` | Estado desconocido rechazado, no disponible. |
| `invalid-reading.json` | Lectura 301 rechazada; nunca saturar a 300. |
| `invalid-total.json` | Total 0 rechazado; no reinterpretar como `null`. |
| `invalid-duplicate-id.json` | IDs repetidos rechazados; no deduplicar silenciosamente el envelope. |
| `invalid-revision-overflow.json` | Revisión fuera de UInt64 rechazada sin pérdida por Double. |
| `cover-fallback.json` | La referencia de portada con ruta se ignora; permanecen título/progreso con placeholder. No se accede fuera de `covers/`. |
| `fence-open-a.json` | Dos lecturas idénticas permiten `content.json`; el envelope solo no basta. |
| `fence-closed.json` | Niega el contenido anterior de A aun con bytes legibles. |
| `fence-open-b.json` | Niega el envelope de A y protege B de redacción A tardía. |
| `projection-scenarios.json` | Datos fuente sintéticos, elegibilidad y presentación esperada. El lote válido excluye el caso histórico incompatible. |

Los fences distintos al principio/final deben rechazar la lectura. Los archivos
son fixtures independientes, no una secuencia real con callbacks, Keychain o
reloj. No hay portada binaria: las referencias nulas prueban ausencia; los tests
de recursos válidos, digest, tamaño, staging y cuota pertenecen a DX3.

DX2 añade pruebas de límite exacto 32.768/32.769 bytes del diccionario
`readingSnapshot: Data` serializado con Foundation. La abreviación de títulos
Unicode pertenece a DX3; las medidas Python sobre estos ejemplos no certifican la
serialización del SDK ni la aceptación por WatchConnectivity. El reloj recibe
`Data` de estos envelopes, nunca `projection-scenarios.json` ni el README.
