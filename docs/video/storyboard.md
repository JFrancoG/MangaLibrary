# Storyboard de vídeo

**Estado:** borrador; no grabar como entrega hasta superar el Deluxe Release Gate.
**Última revisión:** 2026-08-18
**Duración objetivo:** 6–8 minutos.

## 1. Apertura — 30 s

- Presentar Manga Library y el problema que resuelve.
- Aclarar que Deluxe acumula todos los niveles anteriores.

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
- Demostrar logout sin exponer secretos y explicar que primero se cierra y verifica el `SessionFence`; solo entonces se invalidan sesión y Keychain, aunque WidgetKit o un reloj no alcanzable puedan conservar cache hasta una entrega eventual.

## 5. Deluxe — 60 s

- Cambiar el progreso en la app y explicar que el commit local completado precede a la publicación serializada, la revalidación de sesión y el reload dirigido.
- Mostrar el widget `StaticConfiguration` pequeño o mediano con la misma proyección para todas las instancias; no depender de una latencia concreta para completar la toma.
- Mostrar companion watchOS de solo lectura.
- Explicar App Group, doble lectura del fence, portadas inmutables, epoch/revisión y timeline `.never` para widget, además del contexto autocontenido reemplazable de `WCSession.updateApplicationContext(_:)` para reloj.
- Aclarar que «tiempo real» describe publicación por evento, no un SLA ni ejecución continua de la extensión.

## 6. Arquitectura y calidad — 60 s

- Enseñar brevemente el árbol feature-first, SDD y ADR.
- Mostrar evidencia final de ReleaseGate y DocC; si no existe, omitir esta toma.
- Mencionar warnings como errores, estrategia híbrida y accesibilidad verificada.

## 7. Cierre — 30 s

- Resumir Advanced, Deluxe y limitaciones multi-dispositivo.
- Indicar siguientes pasos sin prometer funcionalidad no entregada.

## Checklist previo

- [ ] Deluxe Release Gate registrado en `docs/Progress.md`.
- [ ] Datos y cuenta preparados sin secretos visibles.
- [ ] Notificaciones y material personal ocultos.
- [ ] Barra de estado, fondo, consola y audio revisados.
- [ ] La edición no hace parecer que WidgetKit garantiza una actualización instantánea.
- [ ] Afirmaciones contrastadas con la evidencia actual.
- [ ] Export final revisado de principio a fin fuera del repositorio.
