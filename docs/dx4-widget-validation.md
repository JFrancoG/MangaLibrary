# DX4 — validación de los widgets de lectura y colección

**Última actualización:** 2026-09-08
**Estado:** implementación en la rama de #84, UI aceptada; contenido, vacíos y sesión cerrada comprobados con VoiceOver en las tres familias ES/EN en los casos registrados. Corrección del pie confirmada, aún local. Recuperación tras reinicio confirmada; tramo anterior al primer desbloqueo limitado/no observable y trasladado a DX6 por aprobación del propietario. Colección acreditada con tests y observaciones físicas, incluido cambio de propiedad. No disponible final confirmado con ilustración y VoiceOver en las tres familias ES/EN. Versión normal reinstalada y recuperación de los tres widgets confirmada por el propietario. Validación física DX4 completada en su alcance aprobado; entrega DX4 y Deluxe Release Gate pendientes.
**Tracker:** [issue #84](https://github.com/JFrancoG/MangaLibrary/issues/84),
rama `codex/84-dx4-reading-widget`.

La autoridad de comportamiento permanece en [SDD 05](specs/05-deluxe-watch-and-widget.md),
[SDD 09 v1.14](specs/09-deluxe-reading-contract.md) y ADR 0007/0022. Este documento
registra cómo comprobar ese contrato y distingue cada entorno. La
[evidencia técnica de Progress](Progress.md#rotación-y-tamaño-grande--7-de-septiembre)
conserva los bundles y conteos canónicos.

## Gate de entrega — 8 de septiembre

Entrega completa autorizada por el propietario: commit/push, PR, revisión,
merge y cierre del issue/rama. La publicación permanece pendiente en este registro.

- Revisión independiente de datos/concurrencia/configuración y SwiftUI/accesibilidad
  cerrada sin hallazgos pendientes. Audit de los 57 Swift contra `fa60f15`, cinco
  candidatos justificados y cero infracciones; delta final del test revisado aparte.
  El cambio protegido de proyecto es intencionado: +218/0, sin deriva posterior.
- Se corrigen dos inspecciones de `generatedAt` en pruebas mediante un Decodable
  privado, conservando los diez argumentos y valores esperados. No cambia producción.
  `RunSomeTests` bajo Fast rechaza la selección por la limitación de tags del bridge;
  bajo ReleaseGate solo ejecuta dos argumentos. No se acredita con ese intento la
  matriz completa ni el Release Gate de producto.
- Se repite **Fast 327 declaraciones / 506 invocaciones**, iPhone 17 Simulator/iOS27,
  02:33:31, sin fallos, skips, expected failures ni runtime warnings. El árbol nativo
  confirma los seis y cuatro argumentos de fechas aprobados. Bundle
  `Test-MangaLibrary-2026.09.08_02-33-31-+0200.xcresult`; resumen y árbol locales
  `dx4-delivery-fast-summary.json` y `dx4-delivery-fast-tree.json`.
  El agregado MCP mezcla resultados ajenos y no es autoridad de conteo.
- Integration 436/598 y DocC se reutilizan con sus fechas del 7 de septiembre;
  fuentes de datos y documentación compilada sin cambios asociados. Total combinado
  disjunto **763 declaraciones / 1.104 invocaciones**, sin sumar las repeticiones.
- Build MCP 02:27:58 correcto, más build-for-testing limpio Debug/Release repetido
  después de la revisión del test con el script aprobado: salida0, cero warnings,
  errores o tareas de metadata de App Intents; log `dx4-delivery-reviewed-build.log`.
  Xcode27 `27A5252f`, Swift6.4, ReleaseGate, destino genérico iOS Simulator.
- Gate estático: 24 suites Fast/37 Integration, planes válidos. Catálogos/JSON,
  enlaces y diff comprobados. MangaLibrary/Fast/iPhone11 restaurado, sin argumentos
  de fixture ni sonda temporal; no se reinstala ni altera la prueba física aceptada.

Se conserva el traslado aprobado del primer desbloqueo a DX6, limitado/no
observable y pendiente para Deluxe. Los relatos anteriores mantienen sus cortes
históricos; no se presenta esta entrega como inicio de DX5 ni gate Deluxe superado.

## Ajuste de cierre aprobado — 8 de septiembre

El propietario aprueba trasladar a DX6 la comprobación física de protección
anterior al primer desbloqueo. SDD 09 v1.14, SDD 06 v1.36 y ADR 0022 conservan
el resultado **limitado/no observable** y la obligación pendiente para el Deluxe
Release Gate; no se declara superada ni se relaja la protección del bridge.
La recuperación posterior y el estado inyectado no acreditan I/O protegido.

Con los casos físicos de DX4 confirmados en el alcance de esta checklist y esa
transferencia expresa, no quedan pruebas físicas pendientes que bloqueen DX4.
La implementación y su evidencia están preparadas para la entrega autorizada;
#84 y su rama siguen abiertos, sin PR/merge/cierre ni nuevos commit/push. Deluxe
continúa en 3/7 subfases entregadas; DX5 y DX6 no se inician con este ajuste.

Revisión independiente de los tres diffs normativos sin hallazgos; versiones,
matrices y obligación pendiente coherentes. Enlaces relativos y diff comprobados.
Esta actualización es documental. Se corrige además, con autorización separada,
la errata local `limport Foundation`; `ReadingWidgetRotation.swift` vuelve a ser
idéntico al archivo de HEAD. No hay cambio de comportamiento ni nuevas suites
por esa restauración; las validaciones anteriores conservan sus fechas y alcances.
Los registros cronológicos anteriores conservan el estado de su propia ejecución;
la cabecera y las checklists actuales recogen la decisión posterior.

## No disponible confirmado y versión normal reinstalada — 8 de septiembre

El propietario confirma «Correctos los tres en español e inglés» sobre el
binario de prueba final: ilustración y locución completa del título/mensaje de
no disponible, sin anuncios decorativos, en las tres familias ES/EN del iPhone 11.
Se completa ese caso de VO-04/05; no se extrapola a otras tecnologías de asistencia,
a I/O protegido ni a primer desbloqueo.

Xcode MCP confirma MangaLibrary/Fast/iPhone 11/iOS 27. Fuente sin sonda temporal
y scheme sin argumentos de fixture. `RunProject` 02:08:08, sin debugger, instala
y abre la versión normal, PID 1462, referencia `ac603eb80`; build correcto y
`GetBuildLog` con cero warnings/errores. El propietario confirma después que los tres widgets vuelven a mostrar sus
lecturas y colección: reinstalación y recuperación visible completadas.
No hay cambios Swift nuevos, suites adicionales ni entrega. Primer desbloqueo
conserva el límite no observable y su traslado a DX6 no está aprobado.

## No disponible: texto directo e ilustración — 8 de septiembre

El propietario confirma la locución del diseño anterior en las tres familias
ES/EN y solicita el tono directo y el libro de los estados de acceso. Se registra
ese resultado como histórico; el cambio posterior exige comprobar su texto final.
SDD 09 v1.13: «¿Actualizamos?» / «Abre Manga Library y actualizamos tus mangas.»;
EN «Let's refresh» / «Open Manga Library and we'll refresh your manga.».
El título español breve está aprobado por el propietario y deja espacio al libro
incluso en el pequeño estándar. Se reutiliza la imagen acotada existente, preparada
por el provider, decorativa y omitida en tamaños de accesibilidad. No cambian
snapshots, política temporal, cuenta, publicación ni entitlements.

- Doce previews nativas iPhone 17 Pro/iOS 27: tres familias × ES/EN × estándar/AX5,
  timeline de no disponible; manifest en
  `.build/dx4-preview/2026-09-08-unavailable/`. Texto completo y libro presente en
  estándar, sin libro en AX5. En pequeño ES AX5 el signo final queda en otra línea;
  detalle cosmético, sin pérdida de mensaje. Revisión visual independiente sin
  hallazgos materiales; previews no acreditan VoiceOver físico.
- Revisión independiente de seis Swift y catálogo, Audit sin candidatos; Audit
  del diff acumulado de siete Swift limpio. No se repiten suites de datos ni DocC
  por este cambio de presentación; los gates anteriores conservan sus fechas.
- `RunProject` 02:04:10, MangaLibrary/Fast/iPhone 11/iOS 27, sin debugger,
  PID 1224 y referencia `adcecfa80`: instalado el nuevo binario de prueba;
  build correcto y `GetBuildLog` con cero warnings/errores.
- Sonda temporal solo DEBUG mediante la inyección existente de `.unavailable`,
  con host normal y sin fixture de datos. Retirada inmediatamente de fuente tras
  instalar; `MangaLibraryWidget.swift` coincide byte a byte con su versión normal
  de este ajuste, SHA-256
  `cd7f12f1f1861262587afe45d289c9aebabaae936b11dde510ba0c44660eb779`.

Pendientes confirmar la ilustración y VoiceOver del nuevo texto en las tres
familias ES/EN, y reinstalar/contrastar el binario normal. El teléfono conserva
la prueba temporal hasta esa reinstalación; restaurar la fuente no basta.
La prueba no acredita I/O protegido ni primer desbloqueo. El traslado de ese
límite a DX6 sigue sin aprobar; no hay commit/push ni entrega DX4.

## Total destacado en Mi colección — 7 de septiembre

SDD 09 v1.12: cabecera con título a la izquierda y total en pastilla adaptable
a la derecha; abajo solo fecha. Se conservan conteo y datos. Plurales 1/otros
EN/ES, número mayor semibold y etiqueta accesible completa en ambas variantes.

- 21 previews nativas: 1/24/4096 × EN/ES × Large/XXXL/AX5, dos casos oscuros de 24
  y un fixture Widget de 220 pt para forzar solo número. Manifest en
  `.build/dx4-preview/2026-09-07-collection-header/`.
- Ratio de la pareja OnBrandContainer/BrandContainer: mínimo 7,87 entre las
  cuatro variantes del Asset Catalog; pareja autorizada por Library Red.
- Build MCP 19:01:54 correcto. Revisión independiente de seis Swift y 21 renders
  sin hallazgos; Audit sin candidatos. RunProject 19:03:32 correcto en
  iPhone 11/iOS 27, PID 24475; GetBuildLog sin warnings y MangaLibrary/Fast/iPhone11
  restaurado. Script aprobado Debug/Release con salida 0 y cero warnings/errores,
  registro `dx4-collection-header-final-build.log`.

No se repiten tests de datos ni DocC. Previews no acreditan VoiceOver
interactivo. El propietario confirma posteriormente todos los ajustes visuales,
incluida la cabecera del mediano.

## Segundo aumento de cinco y seis lecturas — 7 de septiembre

SDD 09 v1.11 y ADR-0022: candidato de 56/47 pt con título/progreso mayores y menos
separación, antes del anterior de 48/44 pt. Solo afecta al grande completo de 5/6 no AX.
Quince previews EN/ES estándar, títulos largos, ES XXXL/AX5 y controles 1/4 y
parcial de 4, con manifest en `.build/dx4-preview/2026-09-07-five-six-larger/`.
Build MCP 18:36:31 correcto; revisión independiente de fuente sin hallazgos.

Revisión independiente de cinco Swift y quince renders sin hallazgos; Audit
sin candidatos. Script aprobado de build-for-testing Debug/Release con salida 0
y cero warnings/errores: `dx4-five-six-larger-build.log`. RunProject 18:39:19
correcto en iPhone 11/iOS 27, PID 24316, GetBuildLog sin warnings; configuración
MangaLibrary/Fast/iPhone11 restaurada. No se repiten tests de datos ni DocC.
El propietario confirma posteriormente que el grande se ve muy bien. La matriz
restante de DX4.5 no cambia.

## Portadas mayores y prioridad al añadir — ajuste del 7 de septiembre

El propietario confirma que la rotación natural funciona y solicita que un
nuevo manga sea la primera ficha. SDD 09 v1.10 conserva la cadencia orientativa,
prioriza altas locales/reincorporaciones y aumenta portadas del grande con
1/5/6 lecturas. [Progress](Progress.md#portadas-mayores-y-prioridad-de-nuevas-incorporaciones--7-de-septiembre)
conserva el RED/GREEN y los bundles canónicos.

| Comprobación | Evidencia y estado |
| --- | --- |
| Alta sin lectura; coalescencia; restauración/no-op; baja; nueva sesión; reincorporación; alta retirada antes de publicar | Suite final 17 invocaciones correctas, reloj y almacenamiento aislados; sin red live. |
| Compatibilidad y foco de colección | Payload previo idéntico sin preferencia; IDs ajenos rechazados; orden canónico conservado y rotación completa desde el foco. |
| Portada preferida fuera del prefijo | RED específico y GREEN: se mantienen 128 URLs adicionales y deduplicación; la portada 260 desplaza el final del prefijo. |
| Fast / Integration | 327/506 y 436/598 declaraciones/invocaciones, total 763/1.104; cero fallos, skips y runtime warnings en xcresult. |
| Previews nativas | 11 combinaciones: EN estándar 1/5/6, ES XXXL 1 largo/5/6, ES AX5 1/5/6 y parciales 1/4; iPhone17Pro/iOS27. Manifest en `.build/dx4-preview/2026-09-07-large-focus/`. No acredita VoiceOver. |
| Revisiones | iOS y SwiftUI/accesibilidad de fuente sin hallazgos; Audit de 14 Swift sin infracciones nuevas. Inspección visual independiente de los once renders cerrada sin hallazgos. |
| Build y DocC | Scripts aprobados, salida 0, Debug/Release y archive sin warnings/errores. Logs `dx4-large-focus-build.log` y `dx4-large-focus-docc.log`. |
| Instalación | RunProject 18:07:35 correcto en iPhone11/iOS27, PID 24107; GetBuildLog sin warnings. MangaLibrary/Fast/iPhone11 restaurado. |
| Confirmación física del ajuste | Pendiente: alta real del propietario y primera ficha tras actualizar; tamaños grande 1/5/6. |

No se promete un refresco inmediato ni un reloj exacto de cinco minutos.
No se cambian cuotas, protección, permisos o sincronización remota. La matriz
física de DX4.5 y la entrega continúan pendientes.

## Archivado de la ilustración — diagnóstico físico del 7 de septiembre

**Estado:** defecto reproducido en iPhone 11, corrección implementada y build
MCP completado y revisiones independientes cerradas. La confirmación visual
final en hardware ha sido aportada posteriormente por el propietario: ahora se
muestra correctamente. La ausencia del diagnóstico aislada no se usó como
GREEN visual; la confirmación no cierra el resto de DX4.5.

El propietario veía el texto y diseño anteriores de sesión cerrada, incluso
después de abrir la app, volver a iniciar sesión y recrear los widgets. La
inspección de ejecución con LLDB/Foundation comprobó App Group disponible,
fence abierto, manifest de revisión 14 con estado de lectura `empty`,
generaciones coincidentes y referencia de colección presente. El binario
embebido de la extensión contenía el literal de la vista nueva. Se registraron
estos estados sin copiar credenciales, identidades o payloads de la cuenta.

Al ejecutar el scheme de la extensión en el iPhone apareció cuatro veces el
fallo conductual de archivado:

```text
Widget archival failed due to image being too large [1] - (1024,1024), totalArea:1048576 > max[487911.600000]
```

El asset de la ilustración entregaba su imagen original de 1024 × 1024 al
archivador, aunque SwiftUI la mostrase con un `frame` menor. Las previews
anteriores acreditaron composición y legibilidad, pero no detectaron este
rechazo de archivado en el dispositivo; sus resultados históricos no lo cubren.
El error demuestra el fallo de la representación nueva, sin atribuir a una
sesión cerrada el texto antiguo que permanecía visible.

La corrección conserva el PNG original byte a byte, con SHA-256 idéntico, como
`Resources/WidgetMangaIllustration.png` fuera del imageset. El helper
`ReadingWidgetIllustration` crea con ImageIO thumbnails cacheados de hasta
128/288/512 px para pequeño/mediano/grande y la vista recibe exclusivamente ese
`CGImage` mediante `Image(decorative:scale:)`. El provider prepara la imagen antes
de entregar la entrada y la conserva en las copias de la timeline; ninguna View
lee o decodifica el recurso durante body. Se mantienen composición, exclusión
en tamaños de accesibilidad y prioridad del texto. Una carga fallida omite la
ilustración; no recupera el asset original. No cambian sesión, pipeline,
almacenamiento compartido o timelines. El máximo comunicado por el archivador
es una observación de esta ejecución, no un límite universal de Apple.

| Comprobación posterior al fix | Resultado y límite |
| --- | --- |
| Xcode MCP `BuildProject`, iPhone 11, 17:03:07 | Build completado con cero warnings. No acredita la representación del widget. |
| Xcode MCP `RunProject`, scheme de extensión, 17:03:41; PID 23694 | El proceso estaba en ejecución; la consulta posterior de consola, referencia `ac6069c80`, no encontró el fallo de archivado. Se observó una incidencia externa `XPCConnection invalidated`; no se confunde con un warning de compilación ni se omite de la evidencia. |
| Finalización de `RunProject` | La herramienta puede expirar mientras el proceso sigue ejecutándose. Se contrastan consola y observación de dispositivo; el resultado de la herramienta aislado no acredita ni descarta una representación correcta. |
| Build MCP final, 17:06:36 | Correcto; GetBuildLog sin warnings. |
| Extensión final, 17:09:54; PID 23737 | Proceso observado y consola `ac6041500` sin el fallo de archivado; una incidencia XPC externa de conexión invalidada. |
| Previews finales | Seis casos ES de vacío/redacción en pequeño, mediano y grande, iPhone17 Pro/iOS27; ilustración y textos visibles. Manifest en `.build/dx4-preview/2026-09-07-illustration-fix/`. |
| Revisión independiente | iOS y SwiftUI/accesibilidad sin hallazgos; Audit6Swift limpio. Se resuelve una observación sobre preparar la imagen fuera del render. |
| Instalación final de la app, 17:10:46 | RunProject correcto, PID23750; MangaLibrary/Fast/iPhone11 restaurado y proceso en ejecución. |
| Gates finales | Scripts aprobados de build-for-testing Debug/Release y DocC, salida0 y cero warnings/errores; sin tareas de metadata de App Intents en build. Registros `dx4-illustration-bounded-build.log` y `dx4-illustration-bounded-docc.log`; archive `.build/docc/MangaLibrary.doccarchive`. |
| Confirmación visual física | El propietario confirma en iPhone11 que ahora se muestra correctamente. La prueba no cierra la matriz completa de DX4.5. |

No se ejecutan tests de datos por este fix. Build y DocC sí se repiten con el
resultado de la tabla; las ejecuciones anteriores conservan su fecha y alcance.
Las filas físicas pendientes de DX4.5 continúan abiertas.

## Estados sin contenido — ajuste visual posterior

SDD09 v1.9; aprobación de los textos «¿Qué estás leyendo?» y «Tus mangas, aquí»
y del manga abierto del icono como ilustración decorativa. El propietario
confirma funcionamiento de la ampliación anterior sin identificar dispositivo;
se registra su aceptación sin atribuirle pruebas físicas concretas.

Build MCP y build-for-testing limpio Debug/Release completados sin warnings ni
errores; script aprobado, salida0 y registro `dx4-status-final-build.log`.
Revisión independiente de fuente/SwiftUI/accesibilidad y Audit54Swift limpios.
42 combinaciones nativas de iPhone17 Pro/iOS27, con revisión visual independiente final aprobada sin recortes ni solapamientos:

| Muestra | Alcance |
| --- | --- |
| ES / Large, XXXLarge y AX5 | Pequeño, mediano y grande; vacío, redacción y no disponible. |
| EN / AX5 | Tres familias y tres estados; mensajes completos o forma visual breve con etiqueta accesible completa. |
| ES / Dark | Tres familias con vacío y redacción; ilustración local legible sobre fondo oscuro. |

Directorio `.build/dx4-preview/2026-09-07-status/`, incluido `manifest.json`.
Hay56PNG:42iniciales,2diagnósticos y12finales de no disponible. La revisión
encuentra un nombre SF Symbol previo ausente del catálogo local de Apple y se
sustituye por `questionmark.circle`; buildMCP16:25:49 y render16:25:54 confirman
el símbolo. Las últimas12 capturas sustituyen las iniciales de ese estado;
un primer render anterior a la recompilación explícita se excluye. Las30muestras
de vacío/redacción y12finales de no disponible forman la matriz válida. La
corrección termina con otro build limpio Debug/Release, salida0, registro
`dx4-status-symbol-final-build.log`, sin warnings/errores; el Audit de los dos
Swift modificados se repite limpio.
La ilustración se copia byte a byte del icono, no cambia datos o timelines.
No se ejecutan tests nuevos ni se repite DocC por este ajuste declarativo; las
754declaraciones/1.093invocaciones y el archive limpio anteriores conservan su
alcance. No acredita VoiceOver ni hardware. Scheme Fast/iPhone17 conservado sin
argumentos de lanzamiento. DX4.5 física permanece pendiente.

## Colección mediana y lectura adaptable — ampliación posterior

Implementación y validación automatizada completas. La comprobación interactiva
de esta ampliación quedó pendiente en aquella ejecución por Mac bloqueado; no la acreditan los
recorridos anteriores. Autoridad: SDD05 v1.9, SDD06 v1.35, SDD09 v1.8 y ADR0022.
La [evidencia actual de Progress](Progress.md#colección-mediana-y-lectura-adaptable--7-de-septiembre)
registra RED, bundles, conteos y revisiones.

- Pequeño: `Tomo N/T` o `Tomo N`, etiqueta accesible completa.
- Grande: 1–4 lecturas completas aumentan portada/tipografía; 5–6 y prefijos
  parciales conservan filas compactas. Dynamic Type puede reducir filas.
- Mediano: todas las entradas activas de colección, incluso sin lectura,
  mediante fichas sucesivas con portada, propiedad, completitud y contador.
  Colección vacía es distinta de recurso ausente/corrupto y sesión redactada.
- Dos slots locales acotados, descriptor compatible, doble fence y publicación
  verificada; propiedad sin lectura actualiza. No-op conserva fase/slot y la
  reparación crea revisión. Horizonte de 13 fichas, 300 segundos entre slots,
  sin prometer puntualidad del sistema.

| Gate | Evidencia |
| --- | --- |
| RED inicial | Propiedad sin lectura no publicaba: 1 fallo esperado, bundle 14:30:51. |
| RED adicional | 754 declaraciones/1.093 invocaciones, 51 fallos; 48 de los 79 casos nuevos fallan y 31 son controles. Los tres restantes son dos no-op afectados por el stub y el oráculo de coalescencia actualizado al alcance nuevo. |
| GREEN final | Fast 325/503, bundle 15:08:22; Integration 429/590, bundle 15:04:19. Total 754/1.093, sin fallos, skips, duplicados o runtime warnings. |
| Builds y DocC | Scripts versionados aprobados, salida0, Debug/Release y archive limpios. La posterior retirada de una aserción redundante se recompila y valida en Fast; producción no cambia. |
| Revisión | iOS y SwiftUI/accesibilidad independientes, Audit 53 Swift; sin hallazgos pendientes. No equivale a VoiceOver ejecutado. |
| Planes y estado | 24 suites Fast/37 Integration; partición válida. Fast/iPhone17 restaurados; sin argumentos de lanzamiento ni diff del scheme. |

Previews nativas por Xcode MCP, iPhone17 Pro Simulator/iOS27: 29 PNG revisados,
sin recortes de progreso o pie en los archivos finales. No usan almacenamiento
live, red ni Keychain. Archivos y `manifest.json` fuera de Git en
`.build/dx4-preview/2026-09-07-collection/`.

| Muestra | Resultado visual |
| --- | --- |
| Pequeño ES estándar / EN AX5 | `Tomo 300/300` o `Tomo 300`, equivalentes EN íntegros; título largo con elipsis prevista. |
| Grande completo1–6 | Cardinalidad exacta: 1–4 filas ampliadas, 5–6 compactas; pie visible. |
| Grande parcial1/8 y4/8 | Filas compactas con7 y4 restantes; el prefijo no se interpreta como colección pequeña. |
| Grande EN AX5 | Una lectura legible o seis de ocho y dos restantes, sin portada decorativa. |
| Mediano ES estándar | 0/12 Incompleta,1 tomo en propiedad,5/12 Incompleta y12/12 Completa; singular/plural del contador correctos. |
| Mediano ES XXXL y EN/ES AX5 | Título largo, total desconocido,300/300 Completa,299/300 Incompleta y4.096 mangas; texto y pie completos. |
| Mediano EN AX5, estados | Vacío, sesión redactada e indisponibilidad tienen mensajes propios legibles. |

Una visualización inicial EN de total desconocido omitía el contador; la
repetición sin cambios muestra `1 manga`. Ambos archivos actuales tienen el
mismo SHA-256; no se atribuye la observación a un defecto de producto.

Recorrido pendiente con fixture DEBUG sin red/Keychain: diez mangas activos,
ocho lecturas. Acuarela sin empezar no se lee y posee tomos1/3/5; Alba está
completa3/3. El mediano debe mostrar el primero y después el siguiente slot;
pequeño/grande conservan las ocho lecturas. Mutación de propiedad y logout
recorren el único publicador/fence; no se sustituyen por archivos manuales.
En aquel intento, la comprobación CUA indicaba Mac bloqueado. Se conservaron
intactos los argumentos del scheme y no se lanzó este recorrido.

Los nuevos modelos/lectores comparten archivos del bridge incluidos en ambos
targets, sin cambiar pertenencia ni proyecto en esta ampliación. DX4.5 física
sigue pendiente (firma/protección/VoiceOver en iPhone). No requiere Apple Watch.

## Rotación y tamaño grande — ampliación del 7 de septiembre

**Estado de esta ampliación:** implementación, GREEN, builds limpios, DocC,
previews y recorridos iPhone/iPad Simulator completos en los casos registrados.
Pruebas físicas pendientes.

RED por Xcode MCP, `RunSomeTests`, MangaLibrary/ReleaseGate/iPhone 17 Simulator:
53 declaraciones seleccionadas, 106 invocaciones; 31 fallos conductuales esperados,
75 aprobadas, cero skips/no ejecutadas. Los 27 tests nuevos tienen 40 invocaciones:
31 fallan antes de implementar y nueve son controles; las otras 66 invocaciones
corresponden a controles existentes. Build previo sin warnings. Bundle
`Test-MangaLibrary-2026.09.07_12-14-04-+0200.xcresult`.

El selector MCP marcó todas las pruebas del plan Fast como deshabilitadas antes de
su ejecución; `RunSomeTests` se ejecutó con selección explícita sobre ReleaseGate,
cuyos tests estaban habilitados. No se ejecutaron UI tests ni el ReleaseGate
completo. Hubo un error inicial de compilación en la fixture nueva (lectura
throwing dentro de callback no throwing); se corrigió antes de registrar el RED.

La revisión independiente detectó que reactivar un tombstone mediante propiedad
o completitud podía reclamar foco sin cambiar el tomo conservado. La regresión
parametrizada falla en sus dos casos antes de corregir la comparación, bundle
`Test-MangaLibrary-2026.09.07_12-24-55-+0200.xcresult`. Ambos casos pasan en
Integration completo tras la corrección. La repetición focalizada de las 12:29
solo ejecuta el parámetro `true`; no se presenta como cobertura de ambos.

| Plan final por Xcode MCP | Declaraciones | Invocaciones | Bundle canónico |
| --- | ---: | ---: | --- |
| Fast | 298 | 440 | `Test-MangaLibrary-2026.09.07_12-52-40-+0200.xcresult` |
| Integration | 418 | 574 | `Test-MangaLibrary-2026.09.07_12-53-36-+0200.xcresult` |
| Total disjunto | **716** | **1.014** | Cero fallos, skips e identificadores repetidos o compartidos entre planes. |

La ampliación y la corrección de fechas añaden 30 declaraciones y 52 invocaciones
sobre la base 686/962. El GREEN de rotación anterior a esa corrección era 714/1.004.
Los conteos proceden de `xcresulttool get test-results summary/tests` de los
bundles emitidos por MCP: su resumen agregado incluye resultados históricos
ajenos al plan y no se toma como autoridad. El GREEN focalizado de las 12:19
ejecutó 53 declaraciones / 64 invocaciones; la evidencia completa son los dos
planes finales. Destino: iPhone 17 Simulator, iOS 27 `24A5423a`, arm64;
Xcode 27 `27A5252f`, Swift 6.4. `GetBuildLog` final devuelve cero warnings.
`Scripts/validate-test-plans.sh` valida 21 suites Fast y 36 Integration.

El primer arranque runtime sin debugger mostró un fallo de publicación cuyo
tipo no se capturó. Un retry mantuvo el aviso; dos arranques diagnósticos
posteriores no lo reprodujeron y permitieron observar las ocho lecturas. Se
retiró el breakpoint añadido y no se atribuye causalidad a esos intentos.
La investigación descubrió un defecto separado y reproducible: wire válido
terminado en `.999Z`, en 2026 y antes de 1970, podía rechazarse con `invalidDate`.
RED Fast del bundle `Test-MangaLibrary-2026.09.07_12-48-22-+0200.xcresult`:
298 declaraciones / 438 invocaciones, dos fallos y 436 controles aprobados.
La corrección normaliza milisegundos dentro del segundo, conservando UTC de 24
bytes y validación estricta. Los diez casos finales incluyen submilisegundos y
límites de segundo/año; todos pasan en el Fast canónico de la tabla. La revisión
independiente y Audit de los dos Swift afectados no encuentran hallazgos.
El comportamiento de [Foundation main](https://github.com/swiftlang/swift-foundation/blob/main/Sources/FoundationEssentials/Formatting/Date%2BISO8601FormatStyle.swift)
sirve de contexto primario para el redondeo, sin equipararlo al SDK instalado.

La revisión independiente de fuente iOS/SwiftUI/accesibilidad y Audit cubre 41
archivos Swift del alcance DX4 sin hallazgos pendientes. Los dos candidatos del
script de estilo se justifican por closures en inicializadores; la revisión
manual no encuentra nuevas infracciones. No acredita VoiceOver ejecutado.

Gates finales ejecutados con los scripts versionados aprobados:

- `Scripts/validate-advanced-build.sh`: salida 0, Debug y Release con cero warnings,
  errores y tareas de metadata de App Intents. `build-for-testing` del scheme
  MangaLibrary/ReleaseGate, destino `generic/platform=iOS Simulator` y
  DerivedData temporal aislado; no ejecuta tests. Registro final, posterior a la
  corrección de fechas, `dx4-rotation-fractional-build.log`.
- `Scripts/validate-docc.sh`: salida 0, cuatro targets, Release,
  `generic/platform=iOS`, cero warnings/errores. Archive
  `.build/docc/MangaLibrary.doccarchive` fuera de Git; registro
  `dx4-rotation-fractional-docc.log`, posterior a la corrección de fechas. No
  acredita firma o provisioning. Los registros `dx4-rotation-build.log` y
  `dx4-rotation-docc.log` conservan la primera ejecución aprobada previa al fix.

Previews nativas por Xcode MCP `RenderPreview`, iPhone 17 Pro Simulator/iOS 27;
inspección independiente de 14 PNG con 11 resultados válidos:

| Render de esta ampliación | Observación |
| --- | --- |
| Pequeño y mediano ES/Light | Regresión visual legible de la jerarquía y pie. |
| Grande ES/Light | Seis lecturas y dos restantes, con portada sintética o placeholder. |
| Grande EN/Light, preview dedicado, slots 0 y +300 | Alba…Faro pasa a Bosque…Girasol; seis filas, dos restantes y la misma fecha de publicación. Acredita representación de ambos slots, no su cadencia real. |
| Grande ES/XXX Large/Light, títulos largos | Tres filas; títulos en dos líneas y progreso íntegro. |
| Grande EN/AX5/Dark | Contenido con seis filas y dos restantes; sin portada decorativa. Total desconocido, vacío, redacción y no disponible completos en los renders válidos. |

Los archivos quedan fuera de Git, en
`.build/dx4-preview/2026-09-07-rotation/`. El primer render solicitado para la
rotación mostraba un estado no disponible y dos capturas AX5 omitían texto que
aparece completo en las repeticiones. Se conservan como observaciones no válidas;
no hubo cambios de fuente para repetir. La rotación válida usa el preview dedicado
`Large · EN · Standard`; los casos repetidos usan `unknown-repeat` y
`unavailable-repeat`. La revisión visual final no encuentra recortes o solapamientos
en la evidencia válida; no se atribuye a ella VoiceOver ni hardware.

Runtime posterior a la corrección, Xcode MCP `RunProject` sin debugger y CUA
sobre iPhone 17 Simulator/iOS 27, con ambos argumentos de la fixture:

| Acción y hora local | Observación |
| --- | --- |
| Arranque 12:54:53 | Ocho lecturas sintéticas, sin aviso de publicación ni errores de build. |
| Widget grande instalado | Seis filas, desde Historias del viento hasta El jardín de las nubes, y dos restantes. Mediano: dos filas y seis restantes. Fecha 12:55, sin recortes. |
| Home entre 12:59 y 13:00 | La primera lectura pasa de Historias a Alba sin abrir la app ni solicitar reload. Acredita una rotación natural en Simulator, sin SLA. |
| Bosque 2 → 3, guardado 13:01:22–13:01:24 | A las 13:01:53, grande empieza por Bosque 3/12, sigue hasta Gotas y muestra dos restantes; mediano muestra Bosque/Cuaderno y seis restantes. Fecha 13:01. Acredita prioridad y reinicio tras la publicación. |
| Regreso a Home de iPhone a las 13:10 | Sin abrir la app ni forzar reload, grande muestra Cuaderno…Historias, seis filas/dos restantes; mediano Cuaderno/Diario y seis restantes. Conserva fecha 13:01: rotación posterior a la edición, sin inventar otra actualización de datos. |

Las dos primeras ejecuciones diagnósticas anteriores no se usan para acreditar
cadencia sin debugger. El error del arranque inicial conserva su límite de
diagnóstico; no se observó en este recorrido final.

Runtime iPad A16/iPadOS 27, `RunProject` sin debugger a las 13:03:39, sin errores
de build. Tras cerrar la escena sintética mediante App Switcher, la galería
permite añadir la tercera familia: grande. A las 13:07, portrait muestra seis
lecturas desde Historias hasta El jardín, dos restantes y fecha 13:03. En
landscape, a las 13:08, conserva seis filas/dos restantes y todos los textos
legibles; la vuelta a portrait conserva ese resultado. La app no se relanza tras
cerrar su escena. La interacción inicial
de CUA sobre la escena lateral no era consistente; se resuelve mediante las
acciones nativas de App Switcher y no se atribuye al producto un fallo de UI.

Las capturas nativas se conservan junto a `runtime-notes.md` fuera de Git. La
primera captura portrait de iPad se tomó durante la animación de orientación y
se excluye como prueba estática; landscape y portrait-return son estables. La
última muestra portrait, a las 13:09, empieza por Alba y mantiene fecha 13:03.
La captura de iPhone a las 13:10 confirma Cuaderno y fecha 13:01. No se midió
continuamente el instante exacto de cada transición.

Restauración final verificada: `StopProject`, MangaLibrary/Fast/iPhone 17,
ambos argumentos retirados mediante Xcode UI y diff del scheme vacío.
`GetBuildLog` final: build correcto, cero warnings y sin build en curso. Audit
final del diff completo de 41 Swift, posterior al arreglo de fechas, sin hallazgos;
`git diff --check` limpio. El issue permanece abierto para DX4.5 y la entrega.

| Comprobación nueva | Criterio |
| --- | --- |
| Contrato compartido | Campo opcional compatible; preferido válido, retirado o redactado; selección bajo 32 KiB con título escapado y portada. |
| Pipeline | Edición relevante y coalescencia; guardar igual/ida-vuelta no-op; propiedad ajena no cambia foco; restauración sin publicar otra revisión. |
| Tiempo | Fronteras de 300 segundos, vuelta del ciclo, renovación de una hora sin reinicio y reloj anterior al ancla; cero/una lectura sin futuros; milisegundos canónicos y límites sin adelantar el segundo. |
| Presentación | Pequeño, mediano y grande; grupos que se solapan, títulos largos y total desconocido; vacío/redacción/error, EN/ES y AX5. |
| Recursos | Portadas solo para el horizonte y miniaturas de 160 px; falla opcional como placeholder, sin cargar toda la colección. |
| Herramientas | Xcode MCP, Fast/Integration, build limpio Debug/Release y DocC; revisión iOS/SwiftUI/Audit fuente. |
| Hardware | Cadencia real sin debugger y nueva familia grande en VoiceOver; no atribuirle los resultados de Simulator. |

## Ajuste visual — 7 de septiembre, mañana

La petición del propietario centra Reading/Leyendo y refuerza título, progreso
y portada, con pie anclado abajo y disposición horizontal o apilada según ancho.
`ReadingWidgetFooterView` conserva etiquetas completas y tipografía semántica.
La portada destacada parte de 60 puntos escalables y la compacta de 40; el título
admite dos líneas y escala mínima 0,85 solo fuera de tamaños de accesibilidad.
En accesibilidad no reduce escala, conserva una línea y oculta portadas. El
contrato de snapshot y sus eventos permanecen iguales.

| Evidencia del ajuste | Resultado y límite |
| --- | --- |
| Render mediano 10:31:28 | Dos lecturas visibles con la nueva jerarquía y pie. |
| Renders pequeño EN/AX5 10:32:18 y mediano EN/AX5 10:32:29 | Total desconocido legible; mantienen la adaptación de accesibilidad. |
| Render pequeño ES/Light 10:33:22 | Título largo en dos líneas. |
| Render mediano ES/XXX Large 10:33:25 | Título largo en dos líneas. |
| Observación y captura del propietario | Confirma funcionamiento visual. Modelo y versión de sistema no identificados; no acredita VoiceOver, provisioning o protección física. |
| Revisión final del ajuste | Revisión independiente de los 13 archivos Swift del widget y siete renders sin hallazgos; Audit Swift Source Style con cero candidatos. Catálogo de 15 claves EN/ES completo. |
| Build limpio Debug/Release del ajuste | `Scripts/validate-advanced-build.sh` aprobado, salida 0, con cero warnings, errores o tareas de metadata de App Intents; registro `dx4-widget-polish-build.log`. |
| Tests y DocC | Se reutilizan los 686/962 anteriores al tratarse de UI pura y el archive DocC anterior porque no cambia fuente DocC. No son ejecuciones nuevas. |
| Runtime iPhone 17 del ajuste: `RunProject` 10:36:48 y CUA 10:38 | Cuatro lecturas 3/2/8/1. Pequeño 1/+3 con Alba en dos líneas; mediano nuevo 2/+2 con pie horizontal. Sin recortes, solapamientos o marcas de diagnóstico. Portadas placeholder de la fixture; la portada grande de galería es sintética. |
| Runtime iPad del ajuste: `RunProject` 10:39:08 y CUA 10:43–10:44 | Portrait→landscape→portrait aprobado, sin recortes ni elementos superpuestos. Tres medianos con 1/+3, Leyendo centrado, portada placeholder grande y pie horizontal; pequeño 1/+3 con pie vertical. La portada y tipografía mayores reducen la densidad mediante la adaptación prevista; el 2/+2 de la versión anterior no se atribuye a esta UI. |
| Diagnósticos y restauración final | Ambos `RunProject` sin build errors; `GetBuildLog` devuelve cero warnings. Procesos detenidos, MangaLibrary/Fast/iPhone 17 restaurado, argumentos vacíos y diff del scheme vacío. |

Las previews pequeño Light y mediano Dark se conservan en
`.build/dx4-preview/2026-09-07-reading-polish/`, fuera de Git. No se exporta la
imagen del propietario ni se atribuye a esos renders evidencia de hardware.

El ajuste visual queda validado en los casos registrados. DX4.5 conserva las
pruebas físicas pendientes; la ampliación de combinaciones pertenece a DX6.

El segundo widget de Colección permanece como propuesta: existen datos para
títulos activos y colecciones completas, pero falta una fecha de adquisición.
Necesita una unidad y contrato propios; no está implementado ni se incorpora
como otro modo de la familia mediana de Leyendo.

## Gates y resultados de la base — 6 de septiembre y madrugada del 7

Las tablas y recorridos siguientes conservan la evidencia anterior al ajuste
visual de la mañana, con sus límites originales.

| Gate | Estado y evidencia |
| --- | --- |
| Target y pertenencia | Implementados: MangaLibraryWidgetExtension, ocho fuentes comunes y Assets, Swift 6/iOS 27, sin Configuration Intent. App y widget declaran el App Group aprobado. |
| Build MCP | Aprobado sin warnings tras corregir pertenencia e inicializador; compila y enlaza app y extensión. |
| RED conductual | 24 declaraciones / 52 invocaciones: 31 fallos y 21 controles aprobados. El fallo previo de compilación no se cuenta como RED. |
| GREEN completo | Fast 278/399 e Integration 408/563: 686 declaraciones / 962 invocaciones aprobadas, sin duplicados, fallos o skips. Las cuatro suites nuevas ejecutan 24/52. El GREEN focalizado anterior de 24/35 fue parcial. |
| Revisión iOS y tests | Wiring, lifecycle, lectores y tests revisados independientemente. Loader corregido para preparar portadas solo del prefijo máximo de tres. Revisión SwiftUI/accesibilidad de fuente final sin hallazgos; no acredita VoiceOver físico. |
| Audit Swift Source Style | Audit independiente final de los 28 archivos Swift del diff sin hallazgos, posterior al ajuste de espaciado; incluye el wiring, fixture, lifecycle, lectores y UI del widget. |
| Build limpio Debug/Release final | `Scripts/validate-advanced-build.sh` aprobado también después del ajuste final de espaciado: `build-for-testing` de ambas configuraciones, scheme MangaLibrary, plan ReleaseGate, destino `generic/platform=iOS Simulator`; salida 0, cero warnings, errores o tareas de extracción de metadata de App Intents. Xcode MCP `GetBuildLog` de las 00:13 conserva cero issues. No ejecuta tests. |
| DocC final | Aprobado mediante `Scripts/validate-docc.sh`: cuatro targets, Release, destino `generic/platform=iOS`, cero warnings y errores. Archive `.build/docc/MangaLibrary.doccarchive`, fuera de Git. |
| Configuración de test plans | `Scripts/validate-test-plans.sh` aprobado: 20 suites Fast y 35 Integration; filtros, targets, partición y plan predeterminado válidos. No es una ejecución de tests. |
| Previews y Simulator | Completados los casos concretos de la checklist: renders nativos en iPhone 17 Pro y ejecución en iPhone 17/iPad A16. iPad acredita contenido, rotación y continuidad tras cerrar una de dos ventanas. El ajuste de espaciado resuelve la densidad del mediano y recupera dos filas; las repeticiones finales iPhone/iPad y renders pasan. Las previews iPad fallidas no acreditan UI; la ampliación combinatoria pertenece a DX6. |
| App Group y WidgetKit entre procesos | Acreditado en la instalación DEBUG de iPhone Simulator: ambas familias muestran lecturas, actualizan un tomo y se redactan después de logout. El retorno a foreground no repuebla el escenario. |
| Contraste de Assets | Cálculo independiente de las cuatro variantes: mínimo 6,32:1 en las parejas comprobadas. No acredita tecnologías de asistencia ni todas las combinaciones de UI. |
| Hardware y tecnologías de asistencia | **Pendiente:** provisioning, primer desbloqueo y VoiceOver del widget en iPhone físico. |

Los tests anteriores usan iPhone 17 Simulator, iOS 27 `24A5423a`, arm64,
Xcode 27 `27A5252f` y Swift 6.4. La inspección de `.xcresult` con la herramienta
beta verifica las ejecuciones; no convierte un filtro del plan ReleaseGate en
el Deluxe Release Gate completo. No acredita interacción física ni entrega de
WatchConnectivity.

Los gates finales usan Xcode 27 `27A5252f` y Swift 6.4. Los registros locales
`dx4-advanced-build.log`, `dx4-advanced-build-final.log`,
`dx4-advanced-build-final-layout.log` y `dx4-docc.log` conservan los resultados de
los scripts aprobados; no se incorporan logs completos a Git. La generación DocC usa
`CODE_SIGNING_ALLOWED=NO` y no acredita provisioning. Ninguno de estos gates
publica la app, la documentación o la rama.

La repetición posterior al ajuste exclusivo de espaciado comprende builds, renders
y recorridos Simulator. Los conteos de Swift Testing corresponden a los bundles
Fast/Integration canónicos del 6 de septiembre; no se presentan como otra ejecución.

## Escenario sintético de App Group

Usar una instalación dedicada de pruebas. El escenario toma el bridge canónico
`group.com.plusprojects.MangaLibrary.deluxe/Reading` y el bookkeeping existente
en `Application Support/ReadingPublisher`; no utiliza un segundo ledger. No se
debe activar sobre una instalación personal con datos de producto.

1. Lanzar una compilación DEBUG con ambos argumentos:
   `-ui-testing -ui-testing-reading-widget`. Release no incluye el escenario.
2. La app crea Colección en memoria y registra, mediante el escritor real, diez
   mangas sintéticos: ocho con lectura y dos sin ella. Catálogo, cuenta y
   autorización permanecen aislados de red y Keychain. Las portadas usan placeholder.
3. Añadir el widget de Manga Library en la superficie del dispositivo de pruebas
   y registrar la primera observación de contenido. Que la app solicite reload no
   demuestra que la extensión haya leído o que el sistema haya renderizado.
4. Cambiar o vaciar un tomo desde Colección y observar una nueva oportunidad del
   widget. Para Mi colección, cambiar propiedad en una entrada sin lectura y
   contrastar su ficha. Registrar el cambio efectivo, sin convertir un plazo en un SLA.
5. Ejecutar el logout sintético y su decisión de pendientes desde Cuenta. Registrar
   la salida de sesión y una observación posterior redactada. Los tests aislados
   verifican el orden y contenido del fence; este recorrido observa la app y la
   extensión sin inspeccionar el disco. Una imagen cacheada puede seguir visible
   hasta que WidgetKit procese la actualización.

Los dos argumentos pertenecen al lanzamiento de MangaLibrary desde Xcode MCP,
no a la instalación. Tras terminarse el proceso, abrir el host desde el Dock o
el sistema puede arrancar el modo normal sin conservarlos. Para continuar la
fixture, relanzar el scheme MangaLibrary con ambos argumentos y comprobar las
ocho lecturas sintéticas antes del recorrido. No atribuir al escenario aislado
pantallas observadas después de un arranque sin esos argumentos. El aislamiento
de red y Keychain descrito arriba solo corresponde a la fixture activa.

Al terminar esta validación se retiran ambos argumentos mediante Xcode UI; el
scheme no conserva diff. Xcode MCP queda en MangaLibrary/Fast/iPhone 17 y el
proceso, detenido. El escenario se conserva en código DEBUG para repetirlo con
un lanzamiento explícito, sin habilitarse por defecto.

| Orden independiente | Lectura inicial esperada |
| --- | --- |
| 9001 — Alba de papel | Tomo 3 de 3; permanece en lectura. |
| 9002 — Bosque de tinta | Tomo 2 de 12. |
| 9003 — Cuaderno de viajes | Tomo 8, total desconocido. |
| 9004 — Diario de una biblioteca | Tomo 1 de 5. |
| 9005 — El jardín de las nubes | Tomo 5 de 9. |
| 9006 — Faro de invierno | Tomo 7 de 10. |
| 9007 — Gotas de tinta | Tomo 4 de 6. |
| 9008 — Historias del viento | Tomo 2 de 8. |

La siembra secuencial propone 9008 como foco inicial de lectura, seguido circularmente
por 9001, 9002 y los siguientes. El pequeño muestra una lectura y siete más; el
grande hasta seis, reducido según espacio. Su contador resta las filas visibles
del total de ocho, independientemente de las portadas disponibles.
El mediano actual es Mi colección: muestra una ficha y el total de diez mangas,
incluidos 9009 — Acuarela sin empezar (sin lectura, propiedad 1/3/5 de 12) y
9010 — Archivo reservado (sin lectura ni propiedad, total desconocido).
Alba de papel representa la colección completa de tres tomos.
Editar Bosque de 2 a 3 debe iniciar otra secuencia
por 9002; la siguiente frontera temporal comienza por 9003. La publicación usa el
reloj actual inyectable, sin convertir la fecha en autoridad causal o TTL.

## Observaciones visuales y de ejecución

Resultados históricos del 6 y de la madrugada del 7 de septiembre de 2026,
anteriores a la ampliación de rotación; horas locales de la sesión. Una preview
cubre representación; el widget instalado cubre ejecución entre procesos. Ninguno
de esos entornos acredita hardware o VoiceOver físico.

| Entorno y acción | Observación y límite |
| --- | --- |
| iPhone 17 / iOS 27, ES/Dark; Xcode MCP `RunProject` a las 23:14:58 con los dos argumentos DEBUG; inspección CUA DeviceHub | Cuatro lecturas sintéticas. Pequeño: Alba 3/3 y tres más. Mediano: Alba 3/3, Bosque 2/12 y dos más. Prefijo y contador correctos con dos filas visibles. |
| Misma instalación: mutar Alba de tomo 3 a 2 desde Colección | Ambas familias muestran el nuevo tomo. Acredita publicación y lectura efectiva por la extensión, sin SLA de recarga. |
| Misma instalación: logout y descartar pendientes; volver a foreground | Cuenta queda sin sesión y ambos widgets se observan redactados. Volver a foreground no repuebla el escenario. No se inspeccionan manifest/fence en disco; sus invariantes tienen evidencia aislada en tests. |
| iPad A16 / iPadOS 27, ES/Light; app y superficie de widgets en portrait/landscape | La app muestra cuatro lecturas y rota correctamente. La galería inicialmente no muestra Manga Library; aparece después de Xcode MCP `RunProject` del scheme de la extensión a las 23:27:46. Se añaden pequeño y mediano y ambos muestran contenido real. El mediano con una fila bajo ese lanzamiento no acredita aún una adaptación correcta. |
| Misma sesión iPad: abrir host desde el Dock después de lanzar la extensión | El host arranca sin argumentos y muestra el Catálogo normal. Se detiene el recorrido antes de Cuenta o mutaciones. Estas pantallas se excluyen de la evidencia sintética; Xcode MCP relanza MangaLibrary con ambos argumentos a las 23:33:13 para continuar. |
| iPad, fixture relanzada: dos ventanas visibles, cerrar una y mutar Alba de 3 a 2 desde la restante | La ventana restante continúa y los widgets muestran el cambio. Acredita el cableado entre escenas, sin demostrar que el cierre coincidiera exactamente con un commit; esa carrera permanece cubierta por los tests aislados. |
| iPad, mediano nuevo añadido sin lanzamiento de la extensión; reproducción previa a la corrección | Una sola fila y tres más pese a disponer de ancho libre. La inspección del payload sintético en App Group del Simulator confirma cuatro IDs, 9001–9004, y `totalEligibleCount = 4`; no es una lectura incompleta del origen. El defecto se resuelve con el ajuste de altura descrito en la fila siguiente. |
| iPad, 7 de septiembre, ajuste final; Xcode MCP `RunProject` a las 00:08:18 | La medición temporal encontró 307×120 puntos en mediano y 120×120 en pequeño. La candidata de dos filas rozaba el presupuesto de altura. Reducir el espaciado principal de 6 a 4 puntos recupera seis puntos: las tres instancias medianas muestran Alba 3/3, Bosque 2/12, dos más y la fecha sintética del snapshot. Se conserva `ViewThatFits` 3→2→1; no quedan GeometryReader ni sondas de diagnóstico. No se atribuye el fallo a WidgetKit; el recorrido final de la fila siguiente verifica la rotación. |
| iPad, 7 de septiembre, recorrido final CUA 00:09–00:10 sobre el lanzamiento 00:08:18 | Portrait→landscape→portrait aprobado: medianos con dos lecturas y dos más; pequeño con una y tres más. Sin recortes, solapamientos o marcas de diagnóstico. |
| iPhone 17, 7 de septiembre, `RunProject` 00:10:46 y observación CUA 00:11 | Fixture con cuatro lecturas 3/2/8/1; mediano con dos filas y dos más, pequeño con una y tres más. Fecha sin recortes y sin marcas de diagnóstico, después del ajuste final de espaciado. |
| Intentos de preview iPad | Fallan por timeout y `CHSErrorDomain 1051 timelineReloadTimeout`; no se cuentan como renders aprobados ni invalidan por sí solos el contenido observado en la instalación. |
| Renders nativos iPhone 17 Pro, ES/AX5, familia pequeña | Contenido, vacío, redacción y no disponible legibles. Las portadas decorativas se ocultan; encabezado, contador y fecha usan formas breves sin limitar el tamaño de texto. |
| Renders nativos iPhone 17 Pro, ES/Dark, pequeño y mediano | Total desconocido representado sin inventar un total. |
| Renders nativos iPhone 17 Pro, EN/AX5, total desconocido; pequeño 23:21:10 y mediano 23:21:18 | Ambos legibles con locale explícito de Environment mediante `ReadingWidgetLayoutPreview`, exclusivo de DEBUG. El locale `en` solicitado antes al MCP no se aplicaba y aquellos renders no se cuentan como evidencia EN. |
| Renders finales iPhone 17 Pro/iOS 27, 7 de septiembre; EN/AX5/Dark, total desconocido; pequeño 00:12:09 y mediano 00:12:19 | Ambos legibles tras el ajuste de espaciado, con locale explícito. |
| Renders finales iPhone 17 Pro/iOS 27, 7 de septiembre; pequeño EN/AX5/Light | Vacío 00:12:32, redacción 00:12:41 y no disponible 00:12:51 legibles. |
| Render final iPhone 17 Pro/iOS 27, 7 de septiembre, 00:13:03; mediano ES/XXX Large/Light, título largo | Una fila con elipsis intencional en el título; progreso 1/12, seis lecturas más y fecha íntegra. No se atribuye la lectura completa de la etiqueta a VoiceOver físico. |
| Render nativo de privacidad a las 23:17:30 | Redacción visual observada; no demuestra la protección de archivos o el comportamiento físico de la pantalla bloqueada. |
| Cálculo independiente de contraste de Assets, cuatro variantes | Mínimos: TextPrimary 18,06:1; TextSecondary 8,07:1; Brand 6,32:1; aviso 14,96:1. Las parejas comprobadas superan 4,5:1; el cálculo no sustituye observar todos los estados en pantalla. |

En la UI de esta evidencia base, anterior al ajuste de la mañana, el encabezado
AX5 breve «Reading»/«En lectura» conservaba el nombre completo en su etiqueta
accesible; contador y fecha también conservaban etiquetas completas. Su revisión
de fuente no acredita lectura con VoiceOver físico, que sigue pendiente.

## Checklist visual y de ejecución

- [x] Pequeño y mediano en iPhone Simulator ES/Dark: prefijo y contador restante.
- [x] App Group real en iPhone Simulator: lectura entre procesos, mutación y
  observación redactada tras logout; regreso a foreground sin repoblar el escenario.
- [x] Renders pequeños ES/AX5 de contenido, vacío, redacción y no disponible;
  total desconocido pequeño/mediano ES/Dark y EN/AX5, en el alcance de la tabla.
- [x] Contraste de las parejas de Assets comprobadas en sus cuatro variantes.
- [x] iPad A16/iPadOS 27 ES/Light: app con cuatro lecturas y widgets instalados
  muestran contenido en portrait/landscape, con el límite de lanzamiento registrado.
- [x] Corregir la densidad del mediano iPad: espaciado principal de 6→4 puntos,
  dos filas observadas con prefijo y contador correctos, sin sondas permanentes.
- [x] Repetir el recorrido iPad final y su rotación después de la corrección:
  portrait→landscape→portrait, mediano 2/+2 y pequeño 1/+3 íntegros.
- [x] Repetir iPhone después del ajuste de espaciado a cuatro puntos: mediano
  2/+2 y pequeño 1/+3 íntegros.
- [x] Repetir renders EN/AX5 de ambas familias, los estados vacío/redactado/no
  disponible pequeños EN y el título largo mediano ES tras el ajuste.
- [x] Dos ventanas iPad: cerrar una, mutar Alba 3→2 desde la restante y observar
  widgets actualizados. La coincidencia exacta con un commit no se fuerza en UI;
  los tests aislados acreditan la exclusión y el drenaje durante cancelación.

La tabla registra muestras concretas de EN/ES, Light/Dark, estados y Dynamic Type;
no acredita todas sus combinaciones. La ampliación de esa matriz, incluida la
comprobación combinatoria del prefijo 3→2→1, títulos ausentes/largos y portadas
ausentes/corruptas en los entornos aún no observados, pertenece a DX6. Esta tabla
acredita únicamente los casos registrados. Los tests del lector ya cubren los fallos de archivo,
sin convertirlos en evidencia de representación visual.

## DX4.5 — checklist física

DX4 requiere iPhone físico para las filas siguientes y **no necesita Apple Watch**.
El reloj y la evidencia física de WatchConnectivity/VoiceOver watchOS se conservan
en DX5–DX7. La falta de Watch no sustituye ni impide registrar estas pruebas iOS.
Las filas de DX4 están completas en el alcance registrado. El caso limitado del
primer desbloqueo se conserva separado en DX6 por aprobación del 8 de septiembre.
El issue #84 sigue abierto: esta evidencia no constituye la entrega de DX4.

- [x] Instalación de desarrollo firmada, extensión y App Group efectivos en
  iPhone 11/iOS 27, Debug: RunProject final del 7 de septiembre a las 19:03:32,
  build sin warnings; inspección previa del grupo y snapshot autorizado, más
  confirmación funcional del propietario tras corregir el archivado.
  Esta evidencia no acredita provisioning de distribución ni primer desbloqueo.
- [x] Recuperación visible tras reiniciar y desbloquear: el propietario llega a
  Inicio, consulta Hoy y encuentra una lectura en el pequeño. No se infiere que
  esa presentación provenga de una nueva lectura de disco.
- [x] Continuidad tras bloqueo/desbloqueo: el propietario confirma contenido
  conservado al volver a Inicio sin abrir la app y sesión activa al comprobar Cuenta.
- [x] Presentación durante bloqueo observada en el pequeño de Hoy: el propietario
  confirma acceso con el candado cerrado y una lectura visible, después de haber
  desbloqueado previamente el dispositivo. No se acredita ocultación del contenido,
  lectura de disco ni protección antes del primer desbloqueo tras reiniciar.
- [x] Logout/retirada: cierre/verificación del fence y denegación de lecturas
  posteriores cubiertos por los tests deterministas registrados; integración
  física confirmada por logout y redacción visible/accesible en los tres widgets
  sin debugger, ES/EN. No se afirma inspección física de bytes ni latencia medida.
- [x] VoiceOver físico en las tres familias, EN/ES, para contenido, vacíos y sesión
  cerrada en los casos registrados: información completa, orden y ausencia de
  anuncios decorativos/duplicados. Pequeño con restantes y grande con seis lecturas.
- [x] VoiceOver del pequeño de Hoy: el propietario confirma locución correcta
  el 8 de septiembre, en el mismo recorrido de iPhone 11/iOS 27. Esta confirmación
  no precisa idioma ni si el dispositivo permanecía bloqueado.
- [x] Título largo leído completo con VoiceOver en las tres familias ES/EN;
  pequeño con recorte visual y mediano/grande con título íntegro en pantalla.
- [x] VoiceOver físico e ilustración del texto final de no disponible, SDD 09
  v1.13: el propietario confirma las tres familias ES/EN en el binario temporal.
  No acredita la causa de indisponibilidad ni I/O protegido.
- [x] Recuperación visible del contenido tras reinstalar la versión normal:
  instalación/arranque realizados por MCP y los tres widgets confirmados por
  el propietario con sus lecturas y colección.
- [x] Actualización de tomos poseídos en Mi colección: el propietario confirma
  el conteo actualizado cuando la ficha editada está visible. Los tests cubren
  propiedad sin lectura, publicación y reload; se combinan ambas evidencias,
  sin dar por ejecutado el recorrido de Simulator que quedó incompleto.
- [x] Prioridad al añadir a colección: el propietario confirma que el mediano
  muestra primero el manga nuevo tras la actualización, durante este guiado
  preparado sin debugger. No se comunica una latencia medida.
- [x] Prioridad tras editar lectura existente: el propietario confirma que el
  manga modificado aparece primero en el pequeño y grande.
- [x] Continuación de rotación después de la edición: el propietario confirma
  que pequeño y mediano cambian tras esperar en segundo plano; comunica cinco
  minutos exactos en esta observación. Guiado preparado sin debugger.
  El intervalo observado no se convierte en garantía de entrega de WidgetKit.

## DX6 — prueba física transferida, pendiente para el gate Deluxe

- [ ] Protección antes del primer desbloqueo tras reiniciar: la lectura inaccesible
  se trata como no disponible y no inicializa otro epoch. **Limitado/no observable**
  en el recorrido del iPhone 11; antes de desbloquear no pudo acceder a Hoy.
  No acredita lectura protegida, ejecución del provider ni epoch. El propietario
  aprueba el 2026-09-08 trasladar esta comprobación desde DX4 a DX6; sigue pendiente
  para el Deluxe Release Gate, sin exigir cambios de PIN o controles de acceso.

La validación de otras tecnologías de asistencia no se deduce de VoiceOver ni de
un render. Los resultados físicos pendientes y los gates de watchOS impiden
declarar superado el Deluxe Release Gate.

## VoiceOver — registro guiado

**Inicio:** autorizado el 7 de septiembre de 2026, tras aceptar la UI y guardar
el avance. No se marca ningún caso como aprobado hasta recibir el resultado
real del dispositivo. Se usará el iPhone 11 con la versión final instalada,
primero en español. Registrar configuración de texto, idioma, estado del widget
y si la app está conectada al debugger; no guardar datos de cuenta.

| Caso | Comprobación | Resultado |
| --- | --- | --- |
| VO-01 | Pequeño con lectura: encabezado, título completo y progreso hablado completo; restantes y actualización si existen. Portada sin foco propio. | Pasa en ES/EN con restantes tras corregir el pie: encabezado, manga/progreso, restantes y actualización. Reentrada tras rotación contrastada en ES. Pequeño sin restantes y otras configuraciones no comprobados físicamente. |
| VO-02 | Grande con varias lecturas: orden de cada título/progreso, sin pérdidas ni duplicados; restantes y fecha. | Pasa en ES/EN con seis lecturas visibles: encabezado, seis títulos/progresos y actualización final. Sin restantes ni anuncios decorativos/duplicados en este recorrido. Otras distribuciones no comprobadas físicamente. |
| VO-03 | Mi colección: título, total completo, manga, tomos en propiedad y completitud, fecha; portada decorativa. | Pasa en ES/EN con contenido: encabezado, total, título, propiedad, completitud y actualización. No acredita ambas variantes de completitud ni cambios durante rotación. Colección vacía comprobada por separado en VO-04/05. |
| VO-04 | Sin lecturas, colección vacía, sesión cerrada y datos no disponibles: mensaje y acción comprensibles, ilustración decorativa. Separar estados naturales de fixtures. | Pasa en los casos registrados: sesión cerrada y vacíos naturales, más no disponible inyectado con texto final v1.13 e ilustración, en las tres familias ES/EN. |
| VO-05 | Repetir los casos anteriores en inglés y comprobar títulos largos; documentar cualquier estado no ejercitado. | Pasa en los casos registrados: contenido, vacíos, sesión cerrada, título largo y no disponible final v1.13 confirmados en las tres familias EN. Se mantienen los límites de configuraciones no ejercitadas. |

El orden exacto y el agrupamiento se contrastan con el árbol real de WidgetKit;
la presencia de etiquetas SwiftUI no demuestra cómo las anuncia VoiceOver.

### VO-01 — primer resultado físico, 7 de septiembre

El propietario prueba el pequeño en español después del commit `cebf2cf`,
con la app preparada en iPhone 11/iOS 27 y el debugger desconectado. Confirma
la secuencia: encabezado «Leyendo», título y progreso completos («tomo 9 de 72»),
y «5 más en el iPhone». El recorrido termina sin anunciar la actualización.
Esta observación acredita esos tres anuncios; no permite aprobar el caso completo.

También informa de que, si el manga rota durante la lectura de VoiceOver,
sigue anunciándose el anterior. Pendiente distinguir si la locución ya iniciada
continúa o si el árbol accesible conserva el dato anterior al salir y volver a
entrar. El propietario confirma después que la fecha sigue visible y que, desde
los restantes, el siguiente gesto a la derecha salta a un icono de la app: solo
existen esas tres paradas en el widget. Falta el contraste de salir/reentrar tras
una rotación.
El código de ese commit declara una etiqueta para la actualización mediante
`Text` con interpolación de fecha en ambas variantes del pie; su presencia en
fuente no acredita su representación ni anuncio efectivo en WidgetKit.

El fallo de recorrido queda confirmado; no se atribuye una causa interna de
WidgetKit sin evidencia. VO-02–VO-05 permanecen pendientes y #84 sigue abierto.

### VO-01 — corrección del pie accesible

`ReadingWidgetFooterView` representa el pie como un único elemento accesible,
con una etiqueta completa de restantes y actualización, o solo actualización
cuando no quedan lecturas fuera de la ventana. La fecha se formatea como texto
con el locale del entorno antes de incorporarla a la etiqueta. Un recurso nuevo
con plurales EN/ES conserva ambas informaciones; las 40 claves existentes y el
diseño permanecen intactos. El cambio afecta al pie compartido de pequeño/grande;
no modifica el mediano, los datos ni la rotación.

La etiqueta explícita sustituye el árbol de los hijos mediante
`accessibilityElement(children: .ignore)`; la solución no depende de que el texto
visual de fecha genere una parada independiente. Es una corrección candidata al
fallo observado; requiere repetir VoiceOver físico para acreditar su resultado.

Build MCP del 7 de septiembre a las 20:28:20 correcto, GetBuildLog sin warnings.
Tres previews nativas en iPhone 17 Pro/iOS 27: pequeño ES con/sin restantes y
pequeño EN AX5 con restantes. Mantienen la presentación prevista; no acreditan
el anuncio hablado. Audit de un Swift sin candidatos, catálogo validado y
`git diff --check` limpio. No se repiten tests de datos ni DocC por este cambio
exclusivo de etiqueta SwiftUI; los gates anteriores conservan su alcance.

Revisión independiente del Swift y catálogo sin hallazgos, Audit sin candidatos.
RunProject final a las 20:30:08 correcto en MangaLibrary/iPhone 11/iOS 27,
PID 25037, con `attachDebugger: false`; GetBuildLog sin warnings. La corrección
queda instalada para repetir VO-01. No se declara resuelto el fallo hasta la
confirmación del propietario; aún no se ha guardado esta corrección en un commit.

### VO-01 — confirmación del propietario tras la corrección

El propietario confirma en el mismo iPhone 11/iOS 27, en español, que el último
foco anuncia «5 más en el iPhone, Actualizado, 7 barra 9, 18:42». La actualización
ya forma parte del recorrido; el resultado previo de encabezado y título/progreso
se conserva. VO-01 pasa en esta configuración con restantes. No se extiende a
la variante sin restantes, a inglés ni al resto de familias.

Tras salir del widget y volver a entrar, VoiceOver anuncia el manga visible,
incluso cuando acaba de rotar. No se reproduce contenido antiguo al recuperar
el foco. La observación anterior corresponde a la locución durante el cambio;
no se modifica la rotación ni se atribuye una causa interna al sistema.

Siguiente caso VO-02: grande con las lecturas que estén visibles. Comprobar orden
y correspondencia de cada título/progreso, ausencia de duplicados o anuncios de
portadas, y actualización al final. Si muestra las seis lecturas de un total de
seis, no debe anunciar restantes ni «0 más». La variante sin restantes del pie
compartido tendrá así su propia comprobación física.

### VO-02 — grande con seis lecturas confirmado

El propietario confirma que en el grande todo el recorrido propuesto funciona:
encabezado, los seis mangas correctamente y, al final, la actualización
«7 barra 9, 18:42». Se registra Pasa para este caso en español, en el mismo
iPhone 11/iOS 27 con la corrección del pie instalada sin debugger. La confirmación
incluye el orden de las seis filas y la ausencia de los anuncios indebidos que
se pidieron comprobar. El pie sin restantes queda acreditado en el grande;
no se extrapola a otras distribuciones, inglés ni al pequeño sin restantes.

Siguiente caso VO-03: mediano «Mi colección», título, total de mangas, título de
la ficha, tomos en propiedad, completitud y actualización; portada decorativa.
No se cambia código ni se ejecutan nuevos builds/tests al registrar este resultado.

### VO-03 — colección mediana confirmada

El propietario confirma «Todo completo y bien en la locución» tras el recorrido
propuesto de Mi colección: encabezado y total, manga, tomos en propiedad,
completitud y actualización, sin anuncios decorativos ni duplicados. Se registra
Pasa para el contenido observado en español, en el mismo iPhone 11/iOS 27.
No se identifica qué variante de completitud estaba visible; no se dan por
probadas ambas ni las demás configuraciones.

VO-01–VO-03 tienen confirmación física en español en sus estados concretos.
Se continúa con VO-04, empezando por sesión cerrada en los tres tamaños; esta
prueba permite comprobar el mensaje de acceso sin modificar lecturas ni colección.
La aparición de una vista redactada no demuestra por sí sola el fence canónico,
y un retraso visual no basta para atribuir un fallo de autorización.
No se ejecutan nuevos builds/tests ni se cambia código por esta confirmación.

### VO-04 — sesión cerrada confirmada en las tres familias

El propietario cierra sesión mediante Cuenta, vuelve a los widgets y confirma
«Los tres correcto» al contrastar presentación y locución de «Tus mangas, aquí.
Inicia sesión en Manga Library», sin anuncios de la ilustración. Se acredita
el estado redactado visible y accesible en las tres familias, ES, en el mismo
iPhone 11/iOS 27 preparado sin debugger. No comunica una latencia medida.

Esta comprobación no inspecciona el fence canónico ni prueba acceso antes del
primer desbloqueo; no convierte la fila completa de privacidad/retirada en Pasa.
VO-04 sigue parcial: faltan lectura vacía, colección vacía y no disponible.

Para preparar los vacíos se revisa el escenario sintético existente: utiliza
Colección en memoria y no accede a Keychain/red, pero toma el bridge canónico y
el bookkeeping de la instalación. La sección Escenario sintético de App Group
exige una instalación dedicada; no se activa en el iPhone personal. Se solicita
al propietario si dispone de una cuenta de prueba vacía. No se crea ninguna
cuenta ni se modifica la colección real para esta preparación.

El propietario confirma que dispone de una cuenta vacía. VO-04 continuará mediante
login normal en esa cuenta, comprobando pequeño/grande sin lecturas y mediano sin
colección. No se solicita ni registra su identidad o credenciales; resultados aún
pendientes. No se activa el escenario sintético ni se cambia la instalación.

### VO-04 — estados vacíos confirmados con cuenta de prueba

El propietario inicia sesión normalmente con su cuenta vacía y confirma
«Todo correcto» al comprobar los tres widgets. Pequeño/grande muestran y anuncian
«¿Qué estás leyendo? Marca tu tomo actual en Manga Library»; mediano muestra y
anuncia «Sin mangas en tu colección. Añade mangas a tu colección en Manga Library».
Confirma los mensajes completos, sin datos de la cuenta anterior ni anuncios de
la ilustración en el recorrido propuesto. Evidencia en español, mismo iPhone 11/iOS 27.

La prueba usa la composición normal y no activa fixtures ni altera su colección
habitual. Se acredita el resultado visible/accesible de ese cambio de cuenta,
sin extrapolarlo a la inspección del fence o a carreras no observadas.
VO-04 conserva pendiente el estado no disponible. El siguiente bloque guiado es
VO-05 en inglés, comenzando por los vacíos de esta misma cuenta. Sin nuevos
cambios de código, builds/tests ni entrega.

### VO-05 — estados vacíos en inglés confirmados

El propietario confirma «Los 3 correctos» tras cambiar temporalmente el idioma
y contrastar presentación y locución de los vacíos EN: pequeño/grande anuncian
«What are you reading? Set your current volume in Manga Library» y mediano
«No manga in your collection. Add manga to your collection in Manga Library».
Evidencia del mismo iPhone 11/iOS 27 con la cuenta vacía y composición normal.

VO-05 queda parcial. Se continúa por sesión cerrada en inglés, manteniendo el
idioma actual. La confirmación no se extiende a contenido ni a los otros estados;
no se ejecutan nuevos builds/tests ni se cambia código por este registro.

### VO-05 — sesión cerrada en inglés confirmada

El propietario confirma «Los tres correctos» tras cerrar sesión desde Account y
contrastar los tres widgets en inglés: muestran y anuncian «Your manga, right
here. Sign in to Manga Library», sin anuncio de la ilustración. Evidencia del
mismo iPhone 11/iOS 27; no se comunica una latencia medida ni se inspecciona el
fence canónico. Vacíos y sesión cerrada tienen ya confirmación ES/EN por familia.

Se continúa con el contenido en inglés mediante login normal con la cuenta
habitual: encabezados, título/progreso, restantes y fecha en lectura; total,
título, propiedad, completitud y fecha en colección. No se cambia código ni
se ejecutan nuevos builds/tests o acciones de entrega al registrar este resultado.

### VO-05 — contenido en inglés confirmado

El propietario confirma «Todo correcto, los tres widgets» tras iniciar sesión
con su cuenta habitual manteniendo el inglés y recorrer el contenido propuesto:
pequeño con título/progreso, restantes y actualización; grande con las seis
parejas título/progreso en orden y fecha final; mediano con total, manga,
propiedad, completitud y fecha. Confirma ausencia de omisiones y repeticiones
en ese recorrido. Evidencia del mismo iPhone 11/iOS 27, sin nueva instalación.

Quedan confirmados los recorridos principales de contenido, vacíos y sesión
cerrada en las tres familias ES/EN. No se identifica un título largo ni se provoca
el estado no disponible; esos casos mantienen pendiente físico. No se afirma
que toda accesibilidad ni DX4 estén cerrados. La corrección del pie sigue local,
sin nuevos commits/push; builds y revisiones anteriores conservan su alcance.

El siguiente paso propuesto es restaurar español, desactivar VoiceOver si ya no
se usa y comprobar bloqueo/desbloqueo con sesión activa. Primero observar los
widgets sin abrir la app; después comprobar Cuenta. Esto verifica continuidad
visible de contenido/sesión, sin acreditar acceso a disco antes del primer
desbloqueo ni desaparición inmediata de timelines cacheadas.

### Bloqueo/desbloqueo — continuidad confirmada

El propietario confirma que el recorrido de bloqueo/desbloqueo no presenta
incidencias: widgets con contenido antes de abrir la app y sesión iniciada al
comprobar Cuenta después. Se acredita esa continuidad visible en el iPhone 11;
se separa de privacidad durante el bloqueo, acceso antes del primer desbloqueo
e inspección del fence. No se registra la permanencia de una timeline como
prueba de autenticación: la comprobación de Cuenta aporta el dato de sesión.

Para título largo, el propietario aporta un manga de su colección como candidato.
Su mera existencia no acredita la locución completa ni el recorte visual. Se
solicita contrastar ambos en el mediano e identificar el idioma comprobado.
No se modifica su colección ni la rotación para forzar la selección.

### Título largo — tres familias y ambos idiomas confirmados

El propietario añade un manga de título considerablemente más largo que el
candidato inicial y confirma la locución íntegra en los tres tamaños, tanto en
español como en inglés. En el pequeño se recorta visualmente; VoiceOver lo lee
completo. En el mediano ocupa dos líneas completas y se ve entero; en el grande
llega al final pero también se ve entero. Se acredita la lectura completa de ese
caso y, específicamente en pequeño, independencia frente al recorte visual.
No se infiere truncación en mediano/grande ni se modifica el diseño aprobado.

### Prioridad de nueva incorporación — confirmada

Aprovechando esa alta, se pregunta expresamente si Mi colección mostró primero
el manga nuevo cuando se actualizó. El propietario confirma «Sí, mostró primero
el nuevo». Se acredita ese resultado en el mediano de la instalación física
usada durante el guiado sin debugger; no se comunica latencia ni se promete
refresco inmediato. No acredita por sí solo la prioridad de edición de una
lectura existente ni toda la rotación posterior.

Estos registros no introducen código ni ejecuciones de build/tests; la corrección
del pie sigue local, pendiente de commit/push. Se conserva #84 abierto.

### Prioridad de edición de lectura — confirmada

El propietario modifica temporalmente el tomo de una lectura existente que no
aparecía en el pequeño y confirma «Aparece el primero en el widget pequeño y
grande». Se acredita la prioridad en ambas familias. No se infiere la continuación
de la rotación posterior a esta edición a partir de la colocación inicial.
Se indica restaurar el tomo original si solo se cambió para la prueba, y después
observar la rotación con la app en segundo plano, sin un plazo de cinco minutos.

### Reconciliación de la evidencia de retirada

La revisión independiente de SDD 06 y SDD 09 confirma que el cierre/verificación
del fence requiere evidencia proporcional, no una inspección adicional de bytes
físicos por cada logout. La garantía determinista de orden/denegación mantiene
sus tests anteriores; el propietario ya confirmó logout y redacción en los tres
widgets de la instalación física sin debugger, ES/EN. Se marca satisfecha esa
comprobación combinada, indicando ambas fuentes y sin fingir inspección de disco.
Esto no marca primer desbloqueo ni privacidad durante bloqueo como superados.
No se añade código, ejecutan nuevos builds/tests ni realiza entrega en este corte.

### Rotación posterior a la edición — confirmada

Tras el recorrido de edición/restauración y dejar la app en segundo plano, el
propietario informa que los widgets siguen mostrando los mismos mangas y,
tras esperar, cambian «a los 5 minutos exactos». Se registra la continuación de
rotación en pequeño y mediano solicitada, con ese intervalo comunicado por el
propietario; no se presenta como medición instrumentada ni como SLA del sistema.
La prueba forma parte del guiado físico preparado sin debugger.

Las prioridades de alta/edición y la continuación posterior quedan acreditadas
en sus casos. Restan protección antes del primer desbloqueo, presentación sensible
mientras permanece bloqueado, VoiceOver de no disponible y el recorrido sintético
instrumentado de colección en una instalación dedicada. Sus alcances no se deducen
de esta rotación.

La revisión independiente propone preparar el reinicio/primer desbloqueo a partir
de la ubicación de los widgets y los permisos actuales de Hoy. Se solicita esa
ubicación antes de dar el recorrido. No se cambian controles de acceso, Face ID,
código, entitlements ni App Group. Si la superficie no puede consultarse antes
de desbloquear, se registrará como no observable, no como un pase de protección.

### Hoy con el dispositivo bloqueado — contenido visible

El propietario indica inicialmente que solo tiene widgets en Inicio. Tras preparar
un pequeño en Hoy, confirma que puede acceder con el iPhone bloqueado y ver un
manga de sus lecturas, en respuesta al recorrido que exige mantener el candado
cerrado. Se registra esa presentación en iPhone 11/iOS 27, con los permisos
actuales y después de haber desbloqueado el dispositivo previamente.

El resultado no acredita redacción visual durante bloqueo ni ejecución del
provider o lectura de archivos en ese instante. Tampoco equivale a invalidar la
sesión: SDD 09 separa el bloqueo de pantalla del bloqueo de sesión y no promete
eliminar timelines cacheadas. No se modifica `privacySensitive`, la protección
de archivos ni los entitlements a partir de esta observación.

El siguiente recorrido es reiniciar y consultar la misma instancia antes de
introducir el código, solo si Hoy sigue accesible; después desbloquear y observar
de nuevo antes de abrir Manga Library. Registrar por separado inaccesibilidad de
Hoy, contenido cacheado, redacción o estado no disponible. VoiceOver de no
disponible solo se acredita si ese estado aparece y se recorre realmente.
Sin cambios de código, nuevos builds/tests ni acciones de entrega.

### Reinicio — previo al desbloqueo no observable; lectura posterior visible

El propietario reinicia el iPhone 11 y comunica que antes de introducir el PIN
de la tarjeta solo puede acceder a llamada de emergencia. Para introducirlo debe
desbloquear la pantalla; tras completar el recorrido llega a Inicio, abre Hoy y
ve uno de los mangas que está leyendo en el widget pequeño.

Se registra **no observable antes del primer desbloqueo** con la configuración
actual y recuperación visible después del desbloqueo/PIN. No se atribuye al PIN
de SIM la protección de archivos ni se deduce un fallo del widget. No se cambia
el PIN, código, Face ID ni permiso alguno para forzar el acceso previo.

La observación posterior no demuestra ejecución del provider, origen de caché o
disco, rechazo de I/O protegido ni invariancia de epoch. El estado no disponible
no se ha visto en este recorrido y conserva pendiente su prueba física con
VoiceOver. Se mantienen los tests deterministas existentes en su alcance y el
pendiente de colección sintética instrumentada en instalación dedicada.
Solo se actualizan evidencia y tracker; sin nuevos builds/tests ni entrega.

### Colección sintética — intento de interacción limitado por herramientas

Después del recorrido físico se intenta la comprobación pendiente en la instalación
dedicada de iPhone 17 Simulator/iOS 27 `24A5423a`, sin usar el iPhone 11.
Xcode MCP confirma MangaLibrary/Fast y el destino inicial iPhone 11; se selecciona
temporalmente iPhone 17. Una primera sesión de Device Interaction pierde su clave
antes de instalar. La segunda permite `DeviceInteractionInstallAndRun` con los
dos argumentos explícitos de fixture: app instalada y ejecutándose, PID 13355.
`GetBuildLog` posterior informa build correcto y cero warnings/errores.

El agente de interacción observa a las 23:36:44 la Colección de prueba con entradas
Alba/Bosque/Cuaderno/Diario/Jardín; la jerarquía incluye también Faro, parcialmente
fuera de pantalla. A las 23:37:20 observa Inicio, host en segundo
plano y pequeño con Historias del viento, tomo 2/8, siete restantes y actualización
23:36. Son observaciones de Simulator; no acreditan VoiceOver físico ni la ficha
mediana. La fuente de la fixture define diez mangas y ocho lecturas; no se afirma
que se hayan contado los diez en la interfaz durante este intento.

CUA sobre la ventana iPhone 17 permite abrir la galería de Manga Library mediante
acciones de accesibilidad. Los gestos necesarios fallan con
`windowNotFoundAtPosition`; una captura posterior por Xcode MCP vuelve a indicar
`Session not found`. No se llega a añadir el mediano, modificar propiedad ni
ejecutar logout. El recorrido instrumentado de colección permanece pendiente;
estos errores de herramientas no se registran como defectos del widget.

Los artefactos oficiales de `DeviceInteractionSynthesize`, prefijo
`DX4 Collection Verification Retry-`, conservan pares de jerarquía y captura
con sufijos `23_36_31_971`, `23_36_44_572` y `23_37_20_733` fuera de Git.
La galería queda cerrada, Inicio fuera de edición, sin widgets añadidos o
eliminados y la ventana devuelta al monitor original.

Se detiene PID 13355 mediante `StopProject`; `DeviceInteractionEndSession`
confirma que la sesión ya no existe. Destino restaurado a iPhone 11, scheme
MangaLibrary y Fast conservados, sin argumentos ni diff en el scheme. No se
reinstala ni lanza el host del iPhone físico. No se cambian fuentes Swift ni se
ejecutan suites de tests en este intento; sin commit/push ni entrega.

### VoiceOver en Hoy — confirmado, 8 de septiembre

El propietario activa VoiceOver en la página Hoy y confirma que lee correctamente
el widget pequeño colocado en el recorrido anterior. Se acredita esa locución
en la superficie Hoy del iPhone 11/iOS 27. No se comunica un cambio al estado no
disponible ni se precisa el estado de bloqueo durante esta locución; no se amplía
a ellos la evidencia. Se mantienen los pendientes y límites existentes.
Solo se actualizan documentación y tracker; sin cambios de código ni entrega.

### Alta, baja y propiedad — observación del 8 de septiembre

El propietario reconfirma que añadir un manga lo presenta en Mi colección y
que eliminar el manga visible lo retira al instante en su observación. Se
acredita esa retirada visible, sin convertirla en una latencia garantizada ni
dar por comprobado el contador al eliminar un manga que no estaba mostrado.

También informa que cambiar propiedad «no cambia el segundo widget» y aclara
después que editaba otro manga, no el visible. Esa ausencia de salto no demuestra
un fallo: ADR-0022 da prioridad a altas/reincorporaciones; una edición de propiedad
publica los nuevos datos pero no propone como foco el manga editado. El widget
representa cantidad y completitud, de modo que sustituir números poseídos sin
cambiar esos valores puede ser un no-op legítimo.

El propietario se ofrece a comprobar la ficha del mismo manga. Se guía una
variación real de cantidad en un manga incompleto y sin lectura, contrastando el
nuevo número cuando se muestre su ficha. Resultado aún pendiente; sin cambios
de código ni diagnóstico de incidencia. Revisión independiente de contrato y
ruta de publicación sin fallo concreto de fuente.

### Propiedad visible confirmada y evidencia de colección reconciliada

El propietario confirma: «si está mostrándose en ese momento sí se actualizan los
tomos en propiedad». Se acredita el conteo actualizado de la ficha visible, sin
atribuir cantidades ni latencia no comunicadas. La revisión independiente de
SDD 06/09 permite combinar los tests verdes de proyección, publicación, lector y
rotación con las observaciones físicas de contenido, alta/baja, prioridad,
rotación, logout y propiedad. `ReadingPublicationPipelineTests` cubre propiedad
sin lectura y reload; `ReadingRotationPublicationTests`, el conteo publicado y
la preferencia conservada. El guion de diez mangas en Simulator no es un gate
independiente; su intento incompleto permanece histórico, no se marca aprobado.

### VoiceOver no disponible — binario temporal instalado el 8 de septiembre

Xcode MCP confirma MangaLibrary/Fast, iPhone 17 seleccionado e iPhone 11/iOS 27
elegible. Se selecciona iPhone 11. Una sonda solo DEBUG inyecta `.unavailable`
mediante `ReadingWidgetProvider(loadEntry:)`; Release conserva el proveedor normal.
Se mantiene la misma vista accesible. La sonda no accede a archivos, publicador,
cuenta ni fence; el host conserva su composición normal, sin argumentos de fixture
ni modificación de datos para inducir el estado. Sin entitlements nuevos.

Revisión independiente SwiftUI/accesibilidad y Audit sin hallazgos; script sobre
los dos Swift del diff devuelve cero candidatos. `RunProject` 01:42:03,
`attachDebugger: false`, instala y abre en iPhone 11, PID 741 y referencia
`adcece700`; build correcto y `GetBuildLog` con cero warnings/errores.

Después de instalar se retira la sonda de fuente: `MangaLibraryWidget.swift` vuelve
byte a byte al original, SHA-256
`f5b61ae3b5e385ba76f4cd6778f8d5542445aeaafc3be123fe301f0209730213`.
El **binario del teléfono sigue siendo temporal** hasta reinstalar la versión
normal. Reinstalación y recuperación son pasos pendientes obligatorios tras VO;
retirar la fuente no los sustituye. No entregar antes de completar esa restauración.

Se comprobarán las instancias añadidas en tres familias ES/EN, no la galería que
mantiene placeholders. La prueba solo acredita locución del estado inyectado,
no I/O protegido ni primer desbloqueo. Resultado físico aún pendiente; sin nuevas
suites, commit/push ni entrega. El límite de primer desbloqueo sigue abierto;
su traslado a DX6 todavía es una propuesta, no una aprobación registrada.
