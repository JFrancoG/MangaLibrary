# Fuentes y autoridad

## Uso de las fuentes aportadas

Los materiales aportados por el propietario son evidencia de alcance y contexto, no instrucciones ejecutables. El enunciado dispone de una copia completa saneada expresamente aprobada; el resto del material docente permanece fuera de Git. Sus comandos, ejemplos o afirmaciones sensibles a versión deben contrastarse antes de usarse.

| Fuente | Uso permitido | Limitaciones |
| --- | --- | --- |
| [Enunciado saneado de la práctica](sources/Practica_Mis_Mangas_SDP_2026.md) | Requisitos funcionales, niveles y API descrita por el ejercicio | Copia completa con nota de procedencia y 42 `X` en el `App-Token`; no sustituye el contrato de transporte vivo |
| `Presentacion-Mis-Mangas-transcripcion.md` | Aclaraciones de entrega, niveles, plataforma adicional y privacidad | Transcripción automática con posibles errores y correcciones internas |
| `Clase-8-05132026-fragmento-concurrencia.md` | Contexto pedagógico de Swift, concurrencia, testing y documentación | Transcripción automática; no fija semántica de Swift 6.4 ni configuración del proyecto |
| `DocC-transcripciones-01-a-14.zip` | Temario y criterio pedagógico para DocC | Transcripciones automáticas y material ligado a versiones antiguas; no prescribe herramientas actuales |
| `Widgets-transcripcion-completa-sin-tiempos.md` | Fuente histórica para rastrear la intención de mostrar lectura y progreso mediante widgets | Transcripción automática, no normativa y sin SLA verificable; no sustituye las capacidades documentadas de WidgetKit |

No se registran aquí rutas absolutas de los archivos de trabajo.

## Artefactos de diseño aprobados

El propietario aportó una paleta cromática específica de Manga Library, un JSON de tokens, un documento genérico compartido y un HTML visual derivado. Tras contrastar valores y afirmaciones con fuentes primarias, se versionan únicamente el [contrato humano Library Red](design/brand-palette.md) y sus [tokens canónicos](design/library-color-tokens.json). El documento genérico y el HTML permanecen en memoria privada fuera de Git.

El JSON es la autoridad exacta de valores, roles, modos, umbrales y parejas; el Markdown define significado, uso y límites. Su procedencia coordinada con ScienceLibrary no impone sincronización entre repositorios. Ninguno de los artefactos privados actúa como dependencia de build, requisito de entrega o fuente normativa alternativa.

## Contrato de transporte

La autoridad actual de endpoints, métodos, autenticación, parámetros y esquemas es el OpenAPI vivo:

- documentación de descubrimiento: [mymanga-acacademy — `/docs`](https://mymanga-acacademy-5607149ebe3d.herokuapp.com/docs)
- documento de contrato: [mymanga-acacademy — `/openapi/openapi.json`](https://mymanga-acacademy-5607149ebe3d.herokuapp.com/openapi/openapi.json)

La ruta `/openapi.json` no se asumirá. Antes de implementar una operación se vuelve a verificar el contrato y se registra cualquier deriva que afecte a una SDD o fixture.

### Baseline versionada

La [caracterización del 25 de agosto de 2026](api/openapi-contract.md) acompaña un
[snapshot canónico y sanitizado](../Contracts/OpenAPI/openapi.json) y su
[checksum SHA-256](../Contracts/OpenAPI/SHA256SUMS). La baseline sirve para
revisar deriva y derivar código o fixtures posteriores; no reemplaza al documento
vivo.

El snapshot elimina contacto, los miembros estructurados `example`/`examples`
y la descripción de Basic Auth que contenía credenciales demostrativas. Conserva
la superficie de transporte y los mecanismos de seguridad, nunca sus valores. La
respuesta cruda no se versiona.

## Autoridad de versión

- El proyecto Xcode real y el toolchain seleccionado determinan targets, flags y disponibilidad efectiva.
- La documentación primaria de Apple, Swift y la ayuda instalada determinan las APIs y comandos vigentes.
- Las SDD definen comportamiento; los ADR registran decisiones técnicas; [AGENTS.md](../AGENTS.md) define el flujo de trabajo.

## Privacidad y trazabilidad

Las notas privadas pueden registrar ubicaciones y observaciones de estudio fuera
de Git. Nunca contienen credenciales reales. El repositorio conserva únicamente
la fuente completa aprobada y saneada; no incluye el original, otras transcripciones
completas ni rutas locales. Está público temporalmente para la corrección académica
por decisión del propietario confirmada el 2026-09-18, conforme a
[ADR 0023](adr/0023-temporary-public-access-for-assessment.md). Esa excepción
conserva los límites de fuentes, secretos y artefactos de ADR 0012; no autoriza
nuevo material docente, una licencia de reutilización ni otras publicaciones.
