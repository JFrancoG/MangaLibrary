# Storyboard de vídeo

**Estado:** borrador versionado; vídeo opcional, no generado ni grabado por esta unidad.
La versión de entrega debe identificar su candidata y los gates aplicables. La
excepción de Watch de SDD 06 permite mantener H02/H03/H04 documentadas como
pendientes postentrega; no aplaza H01 ni aprueba el Deluxe Release Gate completo.
**Última revisión:** 2026-09-18
**Duración objetivo:** 6–8 minutos.

## 1. Apertura — 30 s

- Presentar Manga Library y el problema que resuelve.
- Aclarar que Deluxe acumula todos los niveles anteriores: Advanced y DX1–DX5 entregadas (5/7), cortes técnicos DX6/DX7 integrados y gate completo pendiente.

## 2. Catálogo — 75 s

- Mostrar carga paginada, búsqueda y filtros.
- Alternar lista/cuadrícula sin perder consulta.
- Abrir detalle y mostrar estados de portada.

## 3. Colección local — 75 s

- Añadir tomos, marcar lectura y completar colección.
- Mostrar persistencia tras relanzar y un estado sin conexión preparado.
- No exponer datos internos o consola con payloads.

## 4. Cuenta y sincronización — 75 s

- Entrar mediante una sesión ya preparada o credenciales introducidas fuera de captura.
- Mostrar una intención local y su estado sincronizado sin enseñar tokens.
- Si se menciona R2.2, distinguir aceptación funcional multidispositivo de la respuesta exacta del primer DELETE y del GET presente `200`, todavía no caracterizadas directamente. No superponer un status inventado en la demo.
- Demostrar logout sin exponer secretos y explicar que primero se cierra y verifica el `SessionFence`; solo entonces se invalidan sesión y Keychain, aunque WidgetKit o un reloj no alcanzable puedan conservar cache hasta una entrega eventual.

## 5. Deluxe — 90 s

- Cambiar el progreso en la app y explicar que el commit local completado precede a la publicación serializada, la revalidación de sesión y el reload dirigido.
- Mostrar los widgets pequeño/grande de lecturas y el mediano de colección. Usan `StaticConfiguration`, sin configuración interactiva, red ni store SwiftData en la extensión; Watch recibe solo lecturas.
- Explicar la rotación acotada: slots de 300 segundos, actual más doce futuras y `.atEnd` con varios elementos; `.never` para cero/uno o estados sin contenido. Mencionar las prioridades independientes de lectura y alta de colección. No depender de una latencia concreta ni esperar una vuelta completa para terminar la toma.
- Mostrar el companion watchOS de solo lectura. Identificar explícitamente si la toma pertenece a Simulator; no presentarla como prueba de pairing, desconexión o background físicos.
- Explicar App Group, doble lectura del fence, recursos verificados y epoch/revisión, además del contexto autocontenido reemplazable de `WCSession.updateApplicationContext(_:)` para reloj.
- Aclarar que publicación por evento y timeline programada no equivalen a actualización instantánea ni ejecución continua. Un salto de edición del vídeo no debe fingir una garantía temporal del sistema.

## 6. Arquitectura y calidad — 60 s

- Enseñar brevemente el árbol feature-first, SDD y ADR.
- Identificar el commit de la candidata y mostrar solo evidencia que le corresponda. El último checkpoint de producto es C6/PR #125, del 2026-09-14: commit `0d14d6b`, merge `6dfc59d`, ReleaseGate 846 declaraciones / 1.274 invocaciones (13 UI), iPhone 17 Simulator / iOS 27, builds Debug/Release de cinco targets y DocC limpios. DX7/PR #91 (811 declaraciones / 1.160 invocaciones) y A03/PR #97 son cortes anteriores. Ninguno se presenta como una nueva ejecución ni como evidencia física obtenida al grabar.
- Seleccionar las correcciones que ayuden al relato: autorización y caché Watch A01/A02, aislamiento de usuario A03, recuperación del catálogo y del arranque C1/C3 o reutilización acotada de portadas C6. El [outline](../presentation/outline.md) y Progress registran las PR y pruebas; no forzar fallos live ni presentar las mediciones locales como garantías de rendimiento.
- Mencionar warnings como errores, estrategia híbrida y accesibilidad realmente verificada, con la matriz y los límites de cada entorno.

## 7. Cierre — 30 s

- Resumir Advanced, Deluxe y limitaciones multidispositivo.
- Declarar H01 limitado/no observable y no aplazado; H02/H03/H04 físicas Watch pendientes postentrega por la decisión del 2026-09-10. El gate completo permanece pendiente en #88/#77 y la excepción de Watch no aprueba los demás criterios.
- Indicar siguientes pasos sin prometer funcionalidad no entregada.

## Checklist previo

- [ ] Commit de la candidata y evidencia aplicable registrados en [Progress](../Progress.md); resultados históricos identificados por su corte.
- [ ] Criterios de entrega revisados frente a [SDD 06](../specs/06-testing-quality-and-accessibility.md#entrega-del-proyecto-con-validación-física-de-watch-diferida): H01 y los demás criterios no aplazados satisfechos para el paquete final; H02/H03/H04 pueden seguir pendientes bajo la decisión documentada, sin declarar el gate completo aprobado.
- [ ] Familias y timeline contrastadas con [ADR-0022](../adr/0022-widget-collection-projection-and-adaptive-reading.md); correcciones hasta C6 y limitaciones API coherentes con [outline](../presentation/outline.md).
- [ ] Datos y cuenta preparados sin secretos visibles.
- [ ] Notificaciones y material personal ocultos.
- [ ] Barra de estado, fondo, consola y audio revisados.
- [ ] La edición no hace parecer que WidgetKit garantiza una actualización instantánea.
- [ ] Afirmaciones contrastadas con la evidencia actual.
- [ ] Export final revisado de principio a fin fuera del repositorio.
