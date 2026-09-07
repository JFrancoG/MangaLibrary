# DX4 — validación de los widgets de lectura y colección

**Última actualización:** 2026-09-07
**Estado:** implementación en la rama de #84, con aceptación del propietario de todos los ajustes visuales y de UI. Instalación de desarrollo y App Group efectivos acreditados en iPhone 11. Pruebas guiadas de VoiceOver por comenzar; matriz física DX4.5 y recorrido sintético instrumentado de colección pendientes. Sin entrega DX4 ni Deluxe Release Gate.
**Tracker:** [issue #84](https://github.com/JFrancoG/MangaLibrary/issues/84),
rama `codex/84-dx4-reading-widget`.

La autoridad de comportamiento permanece en [SDD 05](specs/05-deluxe-watch-and-widget.md),
[SDD 09 v1.12](specs/09-deluxe-reading-contract.md) y ADR 0007/0022. Este documento
registra cómo comprobar ese contrato y distingue cada entorno. La
[evidencia técnica de Progress](Progress.md#rotación-y-tamaño-grande--7-de-septiembre)
conserva los bundles y conteos canónicos.

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
2. La app crea Colección en memoria y registra, mediante el escritor real, ocho
   lecturas sintéticas. Catálogo, cuenta y autorización permanecen aislados de red
   y Keychain. Las portadas usan placeholder.
3. Añadir el widget de Manga Library en la superficie del dispositivo de pruebas
   y registrar la primera observación de contenido. Que la app solicite reload no
   demuestra que la extensión haya leído o que el sistema haya renderizado.
4. Cambiar o vaciar un tomo desde Colección y observar una nueva oportunidad del
   widget. Registrar el cambio efectivo, sin convertir un plazo en un SLA.
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

La siembra secuencial propone 9008 como foco inicial, seguido circularmente por
9001, 9002 y los siguientes. El pequeño muestra una lectura y siete más; el
mediano admite hasta tres y el grande hasta seis, reducidos según espacio. El
contador siempre resta las filas visibles del total de ocho, independientemente
de las portadas disponibles. Editar Bosque de 2 a 3 debe iniciar otra secuencia
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
El issue #84 sigue abierto con las filas no marcadas pendientes; la implementación y
su validación automatizada/Simulator no constituyen la entrega de DX4.

- [x] Instalación de desarrollo firmada, extensión y App Group efectivos en
  iPhone 11/iOS 27, Debug: RunProject final del 7 de septiembre a las 19:03:32,
  build sin warnings; inspección previa del grupo y snapshot autorizado, más
  confirmación funcional del propietario tras corregir el archivado.
  Esta evidencia no acredita provisioning de distribución ni primer desbloqueo.
- [ ] Protección antes del primer desbloqueo tras reiniciar: la lectura inaccesible
  se trata como no disponible y no inicializa otro epoch. Registrar lo realmente
  observable; no inferir el estado de disco solo por una timeline cacheada.
- [ ] Bloqueo/desbloqueo: no confundir bloqueo de pantalla con invalidación de sesión;
  verificar el marcado sensible sin prometer desaparición inmediata del cache.
- [ ] Logout/retirada con el widget instalado y sin debugger: el fence cerrado niega
  lecturas futuras; registrar por separado cuándo cambia la presentación.
- [ ] VoiceOver real en las tres familias, EN/ES: orden, título, progreso, contador y
  fecha completos; portadas decorativas excluidas y estados comprensibles.
- [ ] Rotación con varias lecturas, app en segundo plano y sin debugger: registrar
  el cambio efectivo, la prioridad tras editar un tomo y tras añadir a colección.
  Los 300 segundos de la
  timeline son una programación, no un plazo garantizado por WidgetKit.

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
| VO-01 | Pequeño con lectura: encabezado, título completo y progreso hablado completo; restantes y actualización si existen. Portada sin foco propio. | Pendiente |
| VO-02 | Grande con varias lecturas: orden de cada título/progreso, sin pérdidas ni duplicados; restantes y fecha. | Pendiente |
| VO-03 | Mi colección: título, total completo, manga, tomos en propiedad y completitud, fecha; portada decorativa. | Pendiente |
| VO-04 | Sin lecturas, colección vacía, sesión cerrada y datos no disponibles: mensaje y acción comprensibles, ilustración decorativa. Separar estados naturales de fixtures. | Pendiente |
| VO-05 | Repetir los casos anteriores en inglés y comprobar títulos largos; documentar cualquier estado no ejercitado. | Pendiente |

El orden exacto y el agrupamiento se contrastan con el árbol real de WidgetKit;
la presencia de etiquetas SwiftUI no demuestra cómo las anuncia VoiceOver.
