# SDD 08: Entrega, presentación y vídeo

**Estado:** Aprobada
**Versión:** 1.3
**Fecha:** 2026-08-18
**Fecha objetivo de entrega:** 2026-09-15

## Propósito

Definir una entrega auditable que demuestre el producto, sus decisiones y su validación sin publicar material privado ni convertir el vídeo en un requisito que las fuentes no establecen.

## Entregables

### Obligatorios del proyecto

- proyecto Xcode reproducible con los niveles acumulados hasta Deluxe;
- catálogo, detalle, colección local, autenticación y sincronización Advanced;
- widget `StaticConfiguration` —no interactivo ni configurable— con publicación dirigida por eventos y companion watchOS de solo lectura;
- README, SDD, ADR, progreso y evidencia de gates;
- documento o presentación que explique qué se hizo, cómo se hizo y por qué.

### Complementario

El vídeo es una evidencia adicional y una ayuda para la demostración. No se tratará como obligación académica mientras no exista una instrucción externa posterior que lo confirme.

### Pendiente externo

El mecanismo de entrega final —por ejemplo, plataforma docente o carpeta compartida— no estaba fijado en las fuentes. Se registrará en `docs/Progress.md` cuando el profesor lo confirme; no se inventará.

## Plan de gates

| Hito | Fecha objetivo |
| --- | --- |
| Gobierno, SDD, ADR y caracterización de contrato | 18 de agosto |
| Catálogo, SwiftData local, filtros, autenticación y sync | 2 de septiembre |
| Advanced Release Gate | 3 de septiembre |
| Snapshot y widget | 8 de septiembre |
| Companion watchOS | 11 de septiembre |
| Deluxe Release Gate | 13 de septiembre |
| Presentación, vídeo opcional y paquete final | 14 de septiembre |
| Margen de entrega | 15 de septiembre |

Una desviación actualizará progreso, riesgo y siguiente decisión; no rebajará silenciosamente un criterio de aceptación. Advanced se valida antes de empezar Deluxe.

## Presentación pública

`docs/presentation/outline.md` mantendrá el relato versionable:

1. problema y alcance acumulativo;
2. decisiones de arquitectura, persistencia y concurrencia;
3. catálogo, colección y experiencia adaptativa;
4. autenticación, seguridad y sincronización;
5. widget y watchOS;
6. estrategia de testing, accesibilidad y DocC;
7. demo, limitaciones conocidas y siguientes pasos.

La presentación final podrá generarse con una herramienta externa, pero el outline y las afirmaciones verificables permanecerán en Git.

## Vídeo público

`docs/video/storyboard.md` describirá una grabación corta y repetible. El vídeo:

- mostrará solo flujos y datos preparados para demostración;
- no revelará credenciales, tokens, correos reales, llavero, rutas locales, notificaciones personales ni configuración privada;
- no afirmará que un gate pasó sin evidencia registrada;
- distinguirá datos locales, servidor, widget y reloj;
- mostrará que el snapshot se escribe tras un commit local completado y que después se solicita la recarga dirigida, sin presentar esa solicitud como una garantía temporal de WidgetKit;
- distinguirá el cierre y verificación fail-closed del `SessionFence` —previos a invalidar sesión o limpiar Keychain— de la redacción visual eventual en caches de WidgetKit o watchOS;
- explicará que watchOS recibe un contexto autocontenido reemplazable mediante `WCSession.updateApplicationContext(_:)`, no una entrega garantizada ni un stream en tiempo real;
- evitará depender de red en vivo cuando un fallo externo pueda inutilizar la demostración.

Los binarios de vídeo, proyectos de edición y capturas sin revisar no se versionarán.

## Obsidian público y privado

- La raíz Git será el vault público; `/.obsidian/` permanecerá ignorado.
- Specs, ADR, progreso, outline, storyboard y evidencia publicable vivirán en el repositorio.
- Notas de orador, ensayos, logs de grabación, inventario de assets, rutas de fuentes y checklist personal vivirán fuera del repositorio en el espacio privado de Obsidian.
- No se guardarán secretos reales ni siquiera en el vault privado.

El espacio privado ayuda a trabajar, pero GitHub Issues y los documentos versionados son la fuente operativa y normativa.

## Flujo de entrega

- Un GitHub Issue representa cada unidad coherente de trabajo.
- Cada cambio usa una rama `codex/<issue>-<slug>` y una PR vinculada cuando el worktree permita aislarlo con seguridad.
- Specs, ADR y progreso cambian en la misma PR que altera su verdad.
- Commit, push, PR, merge, cierre de issue y publicación son autorizaciones separadas.
- La rama principal no contendrá artefactos generados de DocC, vídeo o presentación.

## Criterios de aceptación

- El Deluxe Release Gate está registrado con evidencia reproducible antes del paquete final.
- La presentación explica alcance, arquitectura, datos, decisiones, calidad y limitaciones sin depender de conocimiento oral.
- La demo recorre los niveles Básico, Medio, Avanzado y Deluxe de forma coherente.
- La demo explica «tiempo real» como publicación por evento sin prometer una latencia máxima ni ocultar que WidgetKit decide la presentación efectiva.
- La presentación explica configuración estática, epoch/revisión, doble lectura del `SessionFence`, portadas inmutables y recuperación de logout sin fingir una redacción visual instantánea.
- Todo material público ha pasado una revisión de secretos, privacidad y afirmaciones.
- El mecanismo de entrega y los enlaces finales quedan registrados una vez confirmados externamente.
- El repositorio no contiene notas privadas, fuentes docentes completas ni binarios pesados no aprobados.
- La entrega se prepara el 14 de septiembre y conserva el 15 como margen, salvo cambio explícito documentado.

## Decisiones relacionadas

- [Alcance y niveles](00-product-scope-and-levels.md)
- [Deluxe, watchOS y widget](05-deluxe-watch-and-widget.md)
- [Testing, calidad y accesibilidad](06-testing-quality-and-accessibility.md)
- [Documentación y DocC](07-documentation-and-docc.md)
- [ADR 0008](../adr/0008-selective-docc-and-publishing-boundaries.md)
- [ADR 0010](../adr/0010-widgetkit-event-driven-freshness.md)
