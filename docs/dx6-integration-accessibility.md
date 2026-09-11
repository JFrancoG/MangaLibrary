# DX6 — integración y accesibilidad de Deluxe

**Última actualización:** 2026-09-11
**Estado actual (2026-09-11):** corte técnico integrado mediante [PR #89](https://github.com/JFrancoG/MangaLibrary/pull/89), merge `681ea6d`. #88 sigue abierto y su rama se conserva por los pendientes de validación. El corte técnico DX7 también está entregado por [PR #91](https://github.com/JFrancoG/MangaLibrary/pull/91), con #90 cerrado. DX1–DX5 permanecen entregadas (5/7); el Deluxe Release Gate completo sigue pendiente. H01 conserva el resultado limitado/no observable y no está aplazado; solo H02/H03/H04 de Watch se difieren a después de entregar el proyecto.

**Checkpoint de validación previo a PR #89 (2026-09-11):** DX6 en curso, con issue y rama abiertos. Matriz visual ampliada en widgets y Watch de 40/49 mm; integración nativa de lectura, propiedad sin lectura y logout observada. Audit de dos Swift y gates Debug/Release/DocC aprobados; límites concretos y evidencia se registran abajo. La ampliación de 40 mm acredita títulos largos, seis estados ES/EN en AX5 y un recorrido con Increase Contrast/Reduce Motion activados y restaurados. El widget pequeño ES/Dark conserva texto y ayuda con ambos ajustes activados. Ajustes, sesiones y entorno Xcode restaurados, con build MCP final limpio a las 20:42. DX6.2/DX6.3 quedan cumplidas en su alcance representativo y combinado; arranque frío nativo y otras exploraciones conservan sus límites. DX1–DX5 permanecen entregadas (5/7), DX7 no está iniciada y el Deluxe Release Gate completo sigue pendiente. La entrega del proyecto se permite con H02/H03/H04 de Watch pendientes para después, anticipables con pareja compatible prestada; H01 y los demás criterios no se aplazan.
**Tracker:** [issue #88](https://github.com/JFrancoG/MangaLibrary/issues/88), subissue del [plan #77](https://github.com/JFrancoG/MangaLibrary/issues/77).
**Rama:** `codex/88-dx6-integration-accessibility`, desde `main@d2f6963dc2a506589d8b775dc7aaa9bf3589444f` limpio.

## Checkpoints de autorización y validación del corte DX6

Las decisiones siguientes conservan su alcance en el momento indicado. El
resultado Git posterior es el de la cabecera actual; no amplía la evidencia física.

El propietario autoriza abrir issue y rama e iniciar DX6. El 2026-09-10 permite
además entregar el proyecto con H02/H03/H04, validación física de Watch,
pendientes para después de la entrega, según la decisión registrada abajo.
No autoriza por esas decisiones iniciales acciones Git/GitHub de entrega, publicación en App Store o
inicio de DX7. El estado histórico de DX4/DX5 se conserva en sus checklists; sus
frases «siguiente, sin iniciar» describen el momento de aquellos cierres.

El 2026-09-11 autoriza posteriormente **commit, push y apertura de PR indicando
la limitación**. La publicación se limita a la rama DX6 y una PR hacia `main`,
con referencia a #88 sin cierre automático. H01 sigue limitado/no observable y
H02/H03/H04 físicas de Watch quedan postentrega. No se autoriza merge, cierre
de issue, borrado de rama ni inicio de DX7; tampoco cambia el criterio de H01.
El issue canónico registra el resultado verificado de estas acciones de Git.

La autoridad permanece en [SDD 05](specs/05-deluxe-watch-and-widget.md),
[SDD 06 v1.38](specs/06-testing-quality-and-accessibility.md),
[SDD 09 v1.17](specs/09-deluxe-reading-contract.md),
[ADR 0007](adr/0007-watchos-widgetkit-and-data-bridges.md) y
[ADR 0022](adr/0022-widget-collection-projection-and-adaptive-reading.md).
Esta selección operativa amplía la matriz por riesgos; no cambia el contrato
funcional ni afirma cubrir todas las combinaciones posibles. La decisión de
planificación sobre hardware se refleja en las dos SDD.

## DX6.1 — baseline y evidencia reutilizable

El preflight de apertura identifica Xcode 27 RC `27A266a`, Swift 6.4 y
`MangaLibrary` / `Fast` / iPhone 17, sin diagnósticos en el navegador. No equivale
a ejecutar nuevamente tests o builds. En la apertura quedaba por confirmar la
disponibilidad de hardware; posteriormente el propietario indica que no prevé
disponer de Apple Watch físico antes de entregar el proyecto y aprueba el
aplazamiento acotado de H02/H03/H04 registrado abajo.

| Evidencia anterior | Resultado reutilizable | Límite y condición de reutilización |
| --- | --- | --- |
| Fast, 10 de septiembre | 353 declaraciones / 539 invocaciones; repetición final 17:48:21 aprobada. | Misma lógica, planes y toolchain; no sumar la repetición ni atribuirle fecha DX6. |
| Integration, 10 de septiembre, 15:28:37 | 447 declaraciones / 610 invocaciones aprobadas. | Con Fast son **800 declaraciones / 1.149 invocaciones disjuntas**, cero fallos, skips, expected failures y runtime warnings. No prueban entrega del sistema ni hardware. |
| Builds y DocC de DX5 | Debug/Release y archive DocC limpios; build MCP posterior al Audit, 18:44:27, sin warnings ni errores. | `dx5-runtime-final-build.log`, `dx5-runtime-final-docc.log` y `BuildProject-Log-20260910-184427.txt`. El build para tests no los ejecuta; el archive no está publicado. |
| Revisión de DX5 | Audit y revisiones independientes sobre 25 Swift, incluidos los últimos tres ajustes de whitespace. | Reutilizable sobre fuentes sin cambios; revisar todo delta nuevo según su riesgo. No había checks CI ni revisiones remotas configurados en PR #87. |
| Widget, DX4 | App Group entre procesos, mutación, logout, iPad con rotación y continuidad de ventanas; renders de estados, cardinalidades y tipografía concretos. | La [checklist DX4](dx4-widget-validation.md) identifica versiones y casos; no representa todas las combinaciones ni el toolchain RC actual. |
| Widget físico, DX4 | iPhone 11/iOS 27: instalación de desarrollo, tres familias, VoiceOver ES/EN, títulos largos, estados finales, propiedad, prioridad, rotación, logout y recuperación aceptados en los casos registrados. | No reabrir toda esta matriz sin cambios relacionados. No acredita distribución, Apple Watch ni lectura protegida antes del primer desbloqueo. |
| Watch UI/cache, DX5 | Ocho escenarios en 40/46/49 mm, ES/EN, Large/XXX Large/AX5; Crown y relanzamiento de cache con PID nuevo. | [Matriz DX5](dx5-watch-validation.md#matriz-de-simulator-y-transporte). Es semántica y UI de Simulator; cache sin nuevos contextos no demuestra desconexión física. |
| WatchConnectivity nativo, DX5 | iPhone 17/iOS `24A434` y Ultra 4/watchOS `24R362`: vacío → contenido de nueva sesión → logout/redacción, con envío, callback y UI, Watch PID `71313` sin reinicio. | No acredita coalescencia nativa de pendientes, entrega tardía forzada, reconexión, suspensión, background o hardware. |

No se repiten de entrada las 800 declaraciones por abrir DX6 o ampliar esta
documentación. Se contrasta cada cambio con el baseline y se ejecutan los gates
afectados. Si aparece un defecto testeable, se aplica RED/GREEN sobre ese
comportamiento; una modificación visual reversible no exige tests que copien su
layout. Los tests de orden, corrupción, errores de disco, crash y retirada
conservan su evidencia lógica; no se reetiquetan como pruebas del sistema.
El Deluxe Release Gate exige volver a ejecutar Advanced y añadir Deluxe según
SDD 06: esta reutilización inicial no elimina esa obligación final.

## DX6.2 — matriz visual y semántica ampliada

**Bloque cumplido en el alcance representativo registrado.** Las filas conservan
sus resultados y límites concretos; no se aprueban por ello todas las
combinaciones posibles ni las tecnologías de asistencia físicas.

Cada caso seleccionado necesita entorno, idioma, tamaño de texto, estado,
captura/jerarquía y resultado. Se priorizan las combinaciones no observadas que
estresan una frontera distinta. Large, XXX Large y AX5 son muestras de Dynamic
Type; una captura con texto completo en la jerarquía no acredita su lectura
con VoiceOver. Light/Dark e Increased Contrast se comprueban en las superficies
y modos realmente disponibles; una capacidad no disponible se registra como
tal, sin convertirla en aprobada.

| ID | Entorno y caso seleccionado | Oráculo visible o semántico | Estado DX6 |
| --- | --- | --- | --- |
| W01 | Watch 40 mm, títulos largos ES/AX5; complementar EN/AX5 de DX5. | Crown permite recorrer cada título, su progreso y el pie; no hay solapamiento ni pérdida permanente de datos esenciales. | Observado en Simulator: PID `2346` acredita tres etiquetas, tercera lectura y pie; el suplemento PID `5662` cubre visualmente todas las palabras de ambos títulos largos y sus progresos mediante capturas solapadas, sin ellipsis ni superposición. No acredita VoiceOver físico. |
| W02 | Watch 40 mm, vacío, redacción y no disponible en AX5, ES/EN. | Vacío conserva ayuda y fecha sin lecturas ni contador inventado. Redacción/no disponible conservan instrucciones completas sin lecturas, fecha o contador. | Observado en Simulator: los seis cruces ES/EN en AX5 conservan título y ayuda completos mediante Crown. Vacío conserva fecha; redacción/no disponible no muestran lecturas, fecha ni contador. Los spinners iniciales se recapturan en estado estable. |
| W03 | Watch 40 mm, contenido en XXX Large y AX5, con título ausente y total desconocido; contraste con 46 mm si aparece una frontera de layout. | Fallback «Manga #ID» localizado; orden recibido, tomo y total desconocido íntegros, sin denominador/porcentaje inventado; restantes calculados con todas las filas recibidas. | Parcial: 40 mm/ES/XXX Large, tres filas observadas y pie visual pendiente por caducidad; AX5, primera/segunda filas y pie íntegros, tercera con progreso y semántica íntegros pero título parcialmente bajo navegación. Se conserva además la muestra 49 mm/ES/AX5 de `saved`. |
| W04 | Watch 40/46/49 mm: seleccionar cruces de idioma/tamaño relevantes tras W01–W03 y observar contraste aumentado donde esté disponible. | El espacio adicional no cambia selección ni significado. Texto secundario, ayuda y estados mantienen contraste en la composición real. Se registran las combinaciones exactas. | Muestras observadas: `saved` final en 49 mm/ES/AX5 conserva aviso, contenido y pie completo; 40 mm/ES/AX5 con Increase Contrast y Reduce Motion activados conserva título/progreso tras scroll. No mide tiempos de animación ni VoiceOver físico. Dark Mode de sistema no aplica a watchOS; otros cruces son exploratorios. |
| W05 | Watch, Inspector/jerarquía de contenido, total desconocido, vacío, redacción y no disponible, ES/EN. | Nombre/valor/estado completos, orden coherente, portada decorativa sin parada extra y ausencia de acciones falsas en una lista de solo lectura. | Parcial: jerarquías de contenido/títulos largos ES y seis estados ES/EN en 40 mm; contenido/aviso y pie en 49 mm, más redacción tras reactivación. Inspector no expone Increase Contrast en la superficie inicial; el ajuste nativo posterior sí permite activarlo/restaurarlo y observar contenido con PID `7376`. Foco/locución reales pendientes; no equivale a VoiceOver físico. |
| G01 | Widgets en iPhone/iPad, Light/Dark e Increased Contrast: título ausente/largo y portada ausente/corrupta en combinaciones aún no observadas. | El fallo de portada conserva lectura/título/selección y muestra placeholder. Título ausente se localiza. La corrupción de un recurso de colección no se presenta como colección vacía. | Parcial: renders con títulos ausentes/largos y placeholder en Light/Dark. La combinación de esos casos con contraste aumentado y corrupción de disco queda como ampliación exploratoria; G04 acredita otra muestra concreta de contraste nativo. |
| G02 | Widget grande en iPad y AX5, con 1–6 lecturas, títulos largos y snapshot parcial; contrastar Light/Dark según el caso aún no registrado. | Reduce de 6 a 1 elementos completos según espacio, conserva una ventana contigua sin saltos y contador/fecha accesibles. En accesibilidad oculta portadas decorativas. | Parcial: iPad Pro 13 M5, EN/AX5/Light 6 de 8, EN/AX5/Dark total desconocido y ES/AX5/Dark 6 completas; títulos largos ES/XXX Large/Light. Otros cruces/cardinalidades y runtime de esa familia instalada quedan como ampliación exploratoria. |
| G03 | Widget mediano, iPad/AX5 y contraste aumentado: ficha de colección con propiedad sin lectura, cero/total conocido/desconocido y conteo amplio. | Una ficha de **Colección**, total global accesible y propiedad/completitud persistidas; no inventa adquisición ni exige lectura activa. | Parcial: renders AX5 de 4.096 mangas, 299/300 incompleta, 300/300 completa, singular/total desconocido y contenedor estrecho. Cero poseídos y contraste aumentado no acreditados por estos renders; propiedad sin lectura conserva evidencia combinada DX4/tests, no procedencia demostrada por la fixture DTO. |
| G04 | Estados finales de las tres familias en los cruces iPad/idioma/contraste aún no registrados; rotación de dispositivo si cambia el espacio. | Ayuda localizada y estado correcto sin pérdida de datos esenciales, recorte de ilustración significativo ni superposición. Registrar foco y Reduce Motion cuando corresponda. | Parcial: mediano iPad AX5 EN/ES en los cruces registrados; pequeño/grande iPhone 18 Pro ES/AX5 vacío Light, redacción Dark y no disponible Light. Además, widget pequeño instalado en iPhone 17/ES/Dark con Increase Contrast y Reduce Motion activados conserva texto/ayuda y semántica; ajustes restaurados. Otros cruces son exploratorios; no se mide animación ni foco/VoiceOver físico en esa muestra. |

La cardinalidad actual de SDD 09/ADR 0022 es: pequeño, una lectura; mediano,
una ficha de colección; grande, hasta seis lecturas. El literal histórico
`3→2→1` de la checklist DX4 describe una UI anterior y no exige varias lecturas
en el mediano actual. La matriz pendiente se interpreta con el contrato vigente.

Las fixtures watch permiten `content`, `saved`, `longtitles`, `empty`,
`redacted`, `unavailable` y `cache`, con idioma y Dynamic Type explícitos, solo
en DEBUG/Simulator. Un caso que necesite otra frontera de fallo requiere un
seam controlado y revisado o queda sin ejecutar; no se atribuye al escenario
`unavailable` una corrupción o protección real que no haya provocado.
Las pruebas de ratios de Assets no sustituyen el contraste renderizado. Los
fallos de Preview de DX5 siguen siendo fallos de Preview; una app instalada
correcta aporta evidencia runtime distinta.

## DX6.3 — integración nativa ampliada

**Bloque cumplido con evidencia combinada DX6/DX4/DX5**, conservando las
fronteras observadas, reutilizadas y no caracterizadas de cada fila. No afirma
simultaneidad de todos los consumidores, callbacks ausentes o hardware Watch.

Usar datos sintéticos, sin cuentas, credenciales ni servicios de producción.
Separar las fixtures locales de Watch, que no instancian WC, de una pareja
nativa con el companion sin argumentos de fixture. Una llamada aceptada por
`updateApplicationContext` necesita callback y contenido aplicado para acreditar
entrega; no se usa una espera fija o un plazo de entrega como oráculo.

| ID | Caso y entorno | Resultado que debe observarse | Estado DX6 |
| --- | --- | --- | --- |
| I01 | Mismo host sintético en iPhone Simulator, Widget real y Watch enlazado: mutar lectura y después propiedad de un manga sin lectura. | Commit local y proyecciones coherentes: lectura en pequeño/grande/Watch; propiedad sin lectura en colección mediana, sin añadir una lectura al Watch. Registrar contenido de cada superficie y callback WC. | Evidencia combinada: Alba 1/3 observada en widget Home y Watch; editar propiedad de Bosque sin lectura conserva solo Alba en Watch y avanza la fecha. El mediano reutiliza la [propiedad visible DX4](dx4-widget-validation.md#propiedad-visible-confirmada-y-evidencia-de-colección-reconciliada) y los tests de publicación/rotación sin cambios. No se observó de nuevo esa ficha ni se obtuvieron logs de callback Watch en este recorrido. |
| I02 | Incorporación/retirada de colección y edición de lectura, con títulos/portadas faltantes. | La prioridad de la ficha nueva pertenece al mediano; las lecturas mantienen su contrato. Retirar no deja elementos ajenos o tombstones visibles. La falta de portada no altera la selección. | Ampliación opcional; se conserva la evidencia física DX4 de alta/baja, prioridad y propiedad junto a tests sin cambios |
| I03 | Relanzar Watch nativo con cache ya aceptada; después recibir redacción o sesión nueva. | Restauración compatible y reconciliación del contexto disponible antes de exponer cache; no aparece contenido retirado cuando el contexto del sistema ya lo invalida. Registrar PID previo/nuevo y estado recibido. | Limitado: el intento de selector nativo termina en ClockFace sin cierre accesible; activar vuelve con el mismo PID `91697` y contenido. No acredita terminación controlada ni arranque frío. |
| I04 | Pareja Simulator: último contexto pendiente, interrupción/reanudación y reactivación, si el runtime permite caracterizarlo. | El último estado deseado se conserva y se aplica al recibirlo; la falta de entrega no revierte el commit o bloquea logout. Contextos repetidos/anteriores no cambian la UI aceptada. | Parcial: redacción conservada al retornar con PID `88060`; sin nuevo callback ni contexto pendiente caracterizados. Coalescencia/reconexión nativas siguen pendientes. |
| I05 | Estado previo conservado durante indisponibilidad de actualización y recuperación dentro de la misma autorización. | La cache informa del último estado recibido sin afirmar sesión vigente, TTL o sincronización inmediata. Error de transporte y cache inválida no se confunden. | Parcial: fixture `saved` final conserva contenido, aviso y pie completo con propietarios reales, 49 mm/ES/AX5 y PID estable. No prueba indisponibilidad WC ni recuperación nativa. |
| I06 | App Group: fallo/crash/reintento en las fronteras autorizadas, manifest/portadas y cambio de sesión. | Mantener el fence y la autoridad de sesión; no abrir B antes de estar segura ni permitir escritura tardía de A. | Lógica aprobada y baseline nominal App Group de DX4 reutilizado; fallo/crash/reintento nativo con extensión activa no caracterizado. Los tests reconstruyen propietarios sobre disco temporal y fronteras inyectadas, no terminan el binario instalado. |

Los casos de orden A→B, duplicados, cache corrupta/inaccesible, saturación de
barreras y fallos de escritura ya tienen pruebas controladas. No se fuerza un
orden arbitrario del sistema ni se introduce otro transporte para convertirlos
en un recorrido nativo. La redacción es eventual al reloj; si escritura y
retirada de cache fallan simultáneamente y el contexto del sistema no está
disponible, no se acredita retirada durable entre procesos. DX6 conserva este
límite explícito de SDD 09.

## DX6.4 — hardware y tecnologías de asistencia

| ID | Capacidad pendiente y entorno necesario | Criterio y límite | Estado DX6 |
| --- | --- | --- | --- |
| H01 | iPhone físico: protección antes del primer desbloqueo tras reiniciar. | Acreditar la frontera de lectura protegida, tratamiento no disponible y ausencia de inicialización de otro epoch. La imposibilidad de abrir Hoy conserva «limitado/no observable»; no exigir cambios de PIN o controles de acceso. Recuperación posterior y un estado inyectado no la sustituyen. | Intento manual repetido el 2026-09-11: Hoy inaccesible antes del primer desbloqueo, también sin SIM; widget visible tras desbloquear y volver a bloquear. Limitado/no observable, criterio pendiente; no incluido en el aplazamiento de Watch. |
| H02 | Pareja física iPhone/Apple Watch: pairing, desconexión/reconexión, contenido, redacción y recuperación. | Registrar envío, recepción y estado aplicado sin garantía temporal. Mantener la distinción entre cache compatible offline y autorización actual del iPhone. | Pendiente después de la entrega del proyecto, no aprobado; puede adelantarse con pareja compatible prestada. |
| H03 | Pareja física: suspensión y entrega background, con apertura desde Watch sin debugger. | Observar callback y aplicación bajo el ciclo de vida real. Una ejecución con debugger, callback simulado o `.backgroundTask` compilada no acredita suspensión/entrega background. | Pendiente después de la entrega del proyecto, no aprobado; puede adelantarse con pareja compatible prestada. |
| H04 | VoiceOver watchOS real, ES/EN, contenido conocido/desconocido, títulos largos y estados sin contenido; Crown/Dynamic Type en dispositivo. | Locución completa, orden/foco, ausencia de duplicados decorativos, progreso/fecha/restantes con significado y uso físico del desplazamiento. Inspector y Simulator no la sustituyen. | Pendiente después de la entrega del proyecto, no aprobado; puede adelantarse con pareja compatible prestada. |

La evidencia física ya aceptada de widgets se reutiliza sin extenderla a otras
tecnologías de asistencia. La decisión del propietario de **2026-09-10**, recogida
en [SDD 06 v1.38](specs/06-testing-quality-and-accessibility.md#entrega-del-proyecto-con-validación-física-de-watch-diferida)
y [SDD 09 v1.17](specs/09-deluxe-reading-contract.md#pruebas-sin-apple-watch-físico),
permite entregar el proyecto con H02/H03/H04 documentadas como pendientes para
después. Si antes se dispone de una pareja compatible prestada, por ejemplo de
un amigo, o de colaboración autorizada, se podrán adelantar. No se fija fecha.

No se aprueban los criterios físicos ni se equiparan a Simulator, fixtures o
semántica inspeccionada. El gate completo continúa pendiente; esa falta de
evidencia Watch, por sí sola, ya no impide entregar el proyecto con la decisión
y el pendiente documentados. H01 del iPhone y los demás criterios no se aplazan.
La decisión tampoco equivale a publicación en App Store, autorización de
entrega Git/GitHub, cierre de DX6 o inicio de DX7.

### H01 — intento físico comunicado el 11 de septiembre

El propietario comunica una nueva comprobación manual en el iPhone del recorrido
H01. Retira la SIM y apaga/enciende el teléfono: ya no aparece la petición de PIN
de SIM, pero la pantalla bloqueada no permite desplazarse lateralmente a Hoy;
solo permite deslizar hacia arriba para desbloquear. Después de desbloquear el
iPhone y volver a bloquearlo, sí puede acceder a Hoy y ver el widget. Comunica
el mismo comportamiento con y sin SIM. No aporta una nueva identificación de
build; esta evidencia procede de su observación, no de una ejecución MCP.

El resultado previo al primer desbloqueo queda **intentado, limitado/no
observable** por la imposibilidad de acceder a la superficie en este recorrido.
La visibilidad posterior se registra por separado: no demuestra una lectura de
archivos protegidos, ejecución del provider, fallback no disponible ni estado
del epoch antes del primer desbloqueo. Tampoco demuestra un fallo de la app.
La ausencia del PIN de SIM no elimina la frontera de autenticación del iPhone.

La documentación de Apple distingue el [PIN de SIM](https://support.apple.com/es-es/118228),
que protege el uso de llamadas/datos móviles, de la [protección de archivos hasta
la primera autenticación](https://support.apple.com/guide/security/secb010e978a/web).
Esta última conserva accesibilidad después de volver a bloquear el dispositivo;
el contrato del proyecto la adopta sin equiparar bloqueo de pantalla y logout.
Eso no permite inferir que el widget visible haya vuelto a leer esos archivos.

No se solicita repetir el mismo recorrido con y sin SIM ni modificar controles
de acceso. SDD 06/09 conservan H01 pendiente; aceptar este límite como suficiente
para cerrar DX6 requeriría una decisión expresa y el ajuste normativo pertinente.
El informe actual no aprueba ese cambio ni amplía el aplazamiento de Watch.
Solo se actualizan documentación y tracker, sin código ni builds/tests nuevos.

### H01 — alcance de la simulación y preparación de entrega

En Simulator y tests se puede inyectar una lectura inaccesible para comprobar
la respuesta de nuestro código. Eso no acredita la protección real antes del
primer desbloqueo ni la disponibilidad de Hoy en el iPhone físico. La
[protección de datos de Apple](https://support.apple.com/guide/security/data-protection-overview-secf6276da8a/web)
se apoya en la jerarquía de claves y el cifrado del dispositivo; bloquear o
reiniciar Simulator no constituye por sí solo evidencia equivalente.

Ya existen pruebas controladas para partes concretas del contrato:
[ReadingSnapshotReadResultTests](../MangaLibraryTests/Deluxe/ReadingSnapshotReadResultTests.swift)
inyecta fallos en las tres lecturas de la frontera y comprueba su propagación;
[ReadingSnapshotPublisherTests](../MangaLibraryTests/Deluxe/ReadingSnapshotPublisherTests.swift)
comprueba que un estado del publicador inaccesible no cambia el fence existente.
La UI no disponible conserva sus muestras registradas. Estas evidencias no se
presentan como un nuevo recorrido conjunto inaccesible → recuperación ni como
una nueva ejecución de tests. H01 conserva el resultado físico limitado/no
observable; la recuperación tras desbloquear sigue siendo evidencia distinta.

El 2026-09-11 se revisa la preparación para commit/push/PR mediante
`finish-delivery-flow` y Audit de `swift-source-style`: dos Swift en el diff,
cero candidatos automáticos y ningún hallazgo en la pasada manual. El delta
Swift conserva el contenido validado el 10 de septiembre; se reutilizan sus
revisiones independientes, builds Debug/Release, DocC y build MCP final de las
20:42, sin repetir gates por esta actualización documental. `git diff --check`
está limpio; el remoto `main` permanece en `d2f6963` y la rama DX6 aún no está
publicada. No hay cambios de proyecto ni archivos staged.

El trabajo está preparado para commit, push y una PR con los límites explícitos,
referenciando #88 sin cierre automático. Eso no cierra DX6: H01 mantiene el
criterio pendiente de SDD 06/09 y H02/H03/H04 siguen postentrega. La petición
de aquel checkpoint solicita documentación y valoración de preparación; no ejecuta ni
autoriza por sí sola commit, push, PR, merge, cierre o borrado de rama.

## DX6.5 — revisión y preparación de DX7

- [x] Casos ejecutados registrados con herramienta, versión, dispositivo/runtime,
  configuración, acción, resultado y referencia saneada; separados de los casos
  no ejecutados y limitados/no observables.
- [x] Defecto P3 corregido y delta validado; baseline conservado y repeticiones
  sin sumar como cobertura nueva.
- [x] Revisión independiente y Audit vigente de dos Swift aprobados: pie del
  widget y fixture runtime. El entrypoint Watch vuelve a ser idéntico a HEAD
  tras retirar el selector de color. Los cambios posteriores requieren revisar
  su propio delta antes de la entrega.
- [x] Gates del delta Swift aprobados con cero warnings de Swift, Clang y DocC;
  reutilización de Fast/Integration justificada. No acredita el cierre de toda
  la matriz DX6 ni una nueva ejecución de tests.
- [x] Ajustes, instalaciones de fixture, schemes, destinos y sesiones restaurados
  tras la ampliación de 40 mm/iPhone; comprobación final de las 20:42 registrada
  abajo. La limpieza de las 19:51 conserva su alcance histórico.
- [x] Issue, matriz y Progress reconciliados con DX6.2/DX6.3 cumplidas en su
  alcance proporcional; DX6.4/DX6.5 siguen abiertas, con revisión/evidencia
  preparadas. H02/H03/H04 postentrega no se aprueban ni aplazan H01.
- [ ] Obtener la autorización de entrega correspondiente y verificar por
  separado cada acción autorizada. DX7 requiere su propio inicio aprobado.

El cierre técnico de DX6 debe identificar exactamente la matriz terminada y
sus límites; no puede presentarse como cierre de todo Deluxe. H01 mantiene su
obligación en DX6 y no se aplaza por falta de Watch. H02/H03/H04 conservan su
seguimiento después de entregar el proyecto, o antes si se dispone de pareja
prestada; no se declaran aprobadas. La entrega del proyecto puede realizarse
con ese pendiente Watch documentado por decisión expresa, manteniendo el
Deluxe Release Gate completo pendiente y los demás criterios vigentes. El plan
#77 sigue abierto; esta decisión no cierra DX6 ni inicia DX7.

### Pendientes de cierre y ampliaciones opcionales

- **H01 conserva la obligación no aplazada:** protección física anterior al
  primer desbloqueo del iPhone, hoy limitada/no observable. No se marca aprobada
  con recuperación posterior, una fixture o el aplazamiento de Watch; una
  modificación de esta obligación necesita decisión separada del propietario.
- **H02/H03/H04 conservan seguimiento después de entregar el proyecto**, con
  opción de adelantarse mediante pareja compatible prestada. No bloquean por
  sí solas esa entrega con el pendiente documentado, ni permiten declarar el
  Deluxe Release Gate completo aprobado.
- **Cierre técnico del tramo actual registrado:** muestras representativas de
  contraste/Reduce Motion, restauración de ajustes y Xcode, revisión y evidencia
  disponibles. La reconciliación del tracker conserva este alcance proporcional. El defecto P3 está corregido; los gates del delta y la
  reutilización de tests están acreditados.
  La entrega y el inicio de DX7 conservan autorizaciones separadas.

Los cruces adicionales de idioma, cardinalidad, tamaño y apariencia son una
selección exploratoria por riesgo, no la obligación de completar un producto
cartesiano. Las muestras no observadas íntegramente de W03 se conservan como
límites de esas capturas; no demuestran un defecto ni obligan a repetir una
frontera ya cubierta por otra evidencia pertinente. I02 adicional, el arranque
frío nativo de I03 y la coalescencia/reconexión Simulator de I04 amplían la
caracterización, sin invalidar la cache/relanzamiento DX5 ni las pruebas lógicas.

I01 combina el recorrido nativo DX6 con la [confirmación física de propiedad
visible DX4](dx4-widget-validation.md#propiedad-visible-confirmada-y-evidencia-de-colección-reconciliada)
y los tests de publicación/rotación sin cambios: la guía parte de un manga
incompleto sin lectura y la confirmación acredita el conteo de su ficha visible.
No se inventan cantidades, latencia, simultaneidad con el Watch o callback de
este recorrido; no hace falta repetir el guion de diez mangas. I06 conserva la
evidencia lógica de fallos y recuperación sobre disco temporal, combinada con
la integración nominal App Group. Su límite nativo permanece documentado sin
exigir un mecanismo artificial nuevo para terminar la extensión instalada.
La repetición final de Advanced y los gates conjuntos siguen perteneciendo al
Deluxe Release Gate; no se consideran ejecutados por esta reutilización.

## Registro de ejecución DX6

### Renders y corrección visual — 10 de septiembre, 19:20–19:28

Xcode MCP `RenderPreview`, Xcode 27 RC `27A266a`/Swift 6.4, produce 17 renders
válidos de la matriz inicial: nueve medianos, seis grandes y dos pequeños;
nueve Dark y ocho Light. Aunque el scheme tenía iPad A16 seleccionado, el
destino efectivo declarado es **iPad Pro 13-inch (M5), iOS 27**. La revisión
visual independiente inspecciona los 17 PNG; no se presentan como UI ejecutada
en iPad A16. Un intento con índice de timeline no soportado queda excluido.

Se observan colección de 4.096 mangas, 299/300 incompleta y 300/300 completa,
singular de propiedad, título ausente/largo, vacío y no disponible en EN,
contenedor estrecho de 220 pt, lectura con total desconocido, seis lecturas de
ocho con dos restantes y cardinalidades completas de una y seis lecturas.
Las variantes cubren ES/EN, Large, XXX Large y AX5 según cada caso; el contenedor
de 220 pt es una propuesta controlada, no otro dispositivo. Tres renders
adicionales del mediano ES/AX5 cubren vacío Light, redacción Dark y no disponible
Light: mensajes distintos e íntegros, sin cabecera, lecturas o fecha residuales.
Las portadas ausentes usan el placeholder; no se provoca corrupción de disco.

La revisión encuentra un **P3** en el pequeño ES ordinario sin restantes:
`Small · ES · Compact progress`, 19:21:52, muestra la fecha como
«Actualizado 15/1, 9:…». La etiqueta accesible conserva el dato completo, pero
la elipsis de la hora no es una forma breve diseñada. `ReadingWidgetFooterView`
añade alternativas por ancho: texto completo, fecha/hora sin prefijo y fecha
corta. Mantiene sin cambios la etiqueta accesible, selección y publicación.
La misma preview a las 19:25:37 muestra **«15/1, 9:00» completo**. La preview
local añadida contrasta el pie con y sin restantes; a las 19:27:34 conserva
«6 más en el iPhone» y fecha/hora íntegras en Dark. El grande ES/XXX Large de
las 19:27:35 conserva fecha larga y cuatro restantes. La repetición de la
preview local de las 19:28:05 declara **iPhone 18 Pro/iOS 27**, no iPhone 17.

Las capturas viven fuera de Git en `ActionArtifacts/default/RenderPreview`,
identificadas por nombre de preview y fecha/hora anteriores. Los inventarios
locales de ejecución separan matriz, estados y corrección; no se suman como
cobertura de tests. La revisión independiente confirma **24 PNG distintos**:
17 de matriz, tres estados y cuatro de corrección, sin sumar dos veces el render
que cerró el P3. El intento inválido queda excluido. Audit independiente de ese
Swift sin hallazgos; el build limpio del delta se registra abajo. La validación de VoiceOver físico del pie
de DX4 se reutiliza por permanecer idéntica su etiqueta, sin afirmar otra locución.

### Watch: redacción persistida y reactivación

`DeviceInteraction` oficial, Ultra 4 de 49 mm/watchOS 27, app instalada sin
fixture: la activación muestra «Tus mangas, aquí / Inicia sesión en Manga Library
en el iPhone.». Crown lleva a ClockFace y la reactivación conserva ese estado,
sin lecturas, fecha ni contador. Jerarquía y capturas de las 19:20:21 y 19:20:59
mantienen PID `88060`; esta secuencia acredita retorno desde segundo plano,
no una terminación controlada seguida de arranque frío. El PID histórico de
DX5 era distinto, pero no se observa aquí cuándo o por qué terminó.

La primera captura de activación fue negra transitoria; la siguiente fue estable.
El campo `applicationState` de la sesión sin workspace devuelve `NotRun`, aunque
la jerarquía identifica la app/PID; logs vacíos. Se conserva ese límite del
instrumento. Los artefactos usan el prefijo `DX6 Watch 49 Matrix` en
`ActionArtifacts/default/DeviceInteractionSynthesize`; la sesión se cierra con
`Session stopped`.

### Preview Watch y fixture runtime

`Saved readings · EN` vuelve a fallar en Preview a las 19:24:27: proceso `89238`,
Series 12 de 46 mm/watchOS `24R362`, trap durante layout en UIKitCore. No se
atribuye causa de producto ni se declara aprobado ese caso. El recorrido de la
app instalada registrado abajo aporta evidencia distinta del aviso.

La fixture DEBUG/Simulator añade `saved`: entrega contenido, drena y comunica
indisponibilidad usando el modelo/receptor reales. El recorrido posterior
observa lecturas conservadas con el aviso. El experimento
`-dx5-color-scheme light|dark` se retira posteriormente: Apple indica que watchOS
no admite Dark Mode de sistema en
[Interface fundamentals](https://developer.apple.com/documentation/technologyoverviews/interface-fundamentals).
No representa una variante nativa pendiente de lograr. `MangaLibraryWatchApp`
vuelve a ser idéntico a HEAD; el delta de fixture conserva únicamente `saved`.
El SDK expone `colorSchemeContrast` como solo lectura; no se usa un setter
privado ni un filtro de imagen. Increased Contrast nativo continúa pendiente.
En ese punto la UI de Xcode estaba bloqueada por la sesión del Mac; se solicitó
desbloqueo al propietario mientras MCP y las tareas independientes continuaban.

### Contenido guardado con aviso — Watch 49 mm, 19:31–19:33

`DeviceInteraction` oficial recorre `saved` en Ultra 4 de 49 mm/watchOS 27,
ES/AX5, PID **`91184`**. La fixture usa codec, almacenamiento y receptor reales
en `DX5Validation`, sin WatchConnectivity, red, Keychain ni datos de producto.
La secuencia contenido → drenaje → indisponibilidad conserva el snapshot y
presenta el aviso de que no se han podido actualizar las lecturas.

| Artefacto bajo el prefijo `DX6 Saved Watch Observe` | Resultado observado |
| --- | --- |
| `19_31_48_216-screenshot.png` | Aviso completo en español y primera lectura «A Quiet Library», tomo 1 de 12. |
| `19_33_18_255-screenshot.png` | Fallback «Manga #2» y «Tomo 2 · Total desconocido», sin denominador inventado. |
| `19_32_05_493-screenshot.png` | Título «The Book of Small Journeys» y «Tomo 12 de 12» visibles; no se transforma en porcentaje o estado completado. |
| `19_32_05_493-hierarchy.txt` | Pie completo: «5 más en el iPhone, Actualizado: 10 sept 2026, 2:00». La captura solo muestra parte del pie: la fecha visual completa quedó pendiente en este primer recorrido. |

Los artefactos permanecen fuera de Git en
`ActionArtifacts/default/DeviceInteractionSynthesize`. La jerarquía conserva
la semántica del pie, pero no acredita VoiceOver ni ausencia de truncado visual
en una parte que no llegó a observarse completa. Las filas presentan fondo
claro: pasar el argumento `dark` **no acredita su aplicación efectiva**.
El selector experimental se descarta y retira al contrastar que Dark Mode de
sistema no está soportado por watchOS. No demuestra un defecto cromático de
producto ni deja pendiente lograr ese modo; Increased Contrast real sí
permanece pendiente.

A las **19:33:36.606** aparece ClockFace; reactivar a las **19:33:58.728**
inicia un proceso nuevo, **`91697`**, sin argumentos de fixture, que muestra
«Tus mangas, aquí / Inicia sesión en Manga Library en el iPhone.». El proceso
anterior terminó durante el recorrido. No hubo `Stop` ni instalación del agente
principal en ese intervalo; los archivos de logs de estas capturas están vacíos.
La causa queda **no atribuida**: no se afirma crash, suspensión normal, logout
de la fixture ni recepción de una redacción nueva. La secuencia no acredita
relaunch controlado de cache ni recuperación nativa para I03/I05.

### Build del corte observado y revisión posterior

El build oficial MCP del corte observado termina con **`BUILD SUCCEEDED`**. Su log completo,
`ActionArtifacts/default/GetBuildLog/71A72779-5615-4318-9735-5E9A8583231F.txt`,
contiene **934 líneas**, incluye host, extensión Widget y companion Watch, y
no contiene diagnósticos `warning:` o `error:`. No se presenta como ejecución
de tests ni nueva validación Debug/Release/DocC completa.

La revisión independiente de aquel corte aprobó **tres Swift**:
`ReadingWidgetFooterView`, `MangaLibraryWatchApp` y `WatchReadingRuntimeFixture`.
Aquel Audit inspeccionó tres archivos con cero candidatos, pasada manual y
`diff --check` limpios. Tras retirar el selector experimental de color, el
Audit vigente aprueba **dos Swift**, pie del widget y fixture `saved`, con
cero candidatos y pasada manual limpia; el entrypoint Watch es idéntico a
HEAD. Los gates canónicos posteriores a esta retirada se registran abajo.
La composición normal permanece intacta y `saved` aplica contenido antes del
aviso solo en DEBUG/Simulator. Se reutilizan Fast/Integration y los gates anteriores en
su alcance, sin añadir tests ficticios ni sumar estas observaciones a sus
conteos. La ampliación runtime y la restauración final del entorno continúan.

### Gates canónicos posteriores al retiro del selector de color

Sobre el delta vigente de **dos Swift**, `Scripts/validate-test-plans.sh`
termina con salida 0 y verifica 28 suites Fast/39 Integration; clasificar planes
no acredita su ejecución. `Scripts/validate-advanced-build.sh`, con Xcode RC
`27A266a`/Swift 6.4 explícito, finaliza con salida 0: Debug y Release limpios,
cero warnings y errores, plan ReleaseGate y destino genérico iOS Simulator.
El log `dx6-validation-build.log` conserva el resultado; es build-for-testing,
sin ejecución de tests.

`Scripts/validate-docc.sh` también termina con salida 0, Release/destino genérico
iOS, cero warnings y errores, sin allowlists. `dx6-validation-docc.log` registra
el archive local `.build/docc/MangaLibrary.doccarchive`, sin publicación.
Tests, planes y lógica de datos/bridge/sesión no cambian frente al corte DX5:
la revisión independiente considera proporcionado reutilizar Fast 353/539 e
Integration 447/610, con sus fechas y total disjunto 800/1.149. No son tests
recién ejecutados ni una exención del gate Advanced que requiere Deluxe.

### Mutaciones del host y observación nativa de Watch — 19:39–19:47

El host sintético iPhone 17, PID `92313`, conserva la misma sesión durante el
recorrido. A las **19:39:42.778907** guarda Alba de papel (`9001`) con tomo de
lectura 1, manteniendo propiedad 1/2/3 y colección completa; WC acepta un
contexto de 501 bytes. El widget Home muestra Alba 1/3. La primera sesión Watch
facilitada devuelve `Session not found`; tras recrearla, la activación explícita
a las **19:41:41.590** muestra una única lectura «Alba de papel · Tomo 1 de 3»
y fecha visual completa «10 sept 2026, 19:39», PID **`91697`**, sin restantes.
No se capturó el estado vacío previo del Watch en este tramo.

El host modifica después solo propiedad de Bosque de tinta (`9002`), de 1/2/4
a 1/2, manteniendo lectura sin indicar y colección incompleta. Guarda a las
**19:43:13.558686** y WC acepta 501 bytes. La sesión Watch anterior vuelve a
caducar; se crea `DX6 Watch Consumer` sin instalar ni construir. A las
**19:44:15.652**, el Watch conserva PID `91697`, muestra únicamente Alba 1/3
y actualiza la fecha a **19:43**. Bosque no aparece como lectura.

Los artefactos de lectura usan `DX6 Native Watch Reading-19_41_41_590`;
propiedad usa `DX6 Watch Consumer-19_44_15_652`, con captura y jerarquía en
`ActionArtifacts/default/DeviceInteractionSynthesize`. Las sesiones sin
workspace informan `NotRun` y logs vacíos aunque la jerarquía identifica el
proceso y la UI. Se acredita el contenido aplicado observado tras los envíos;
no se acredita aquí un log de `didReceiveApplicationContext` ni una latencia.

Para I03, `b c b c` termina en ClockFace a las **19:44:45.443**, sin ofrecer un
mecanismo de cierre en la jerarquía. Activar la app a las **19:45:03.230**
conserva PID `91697`, Alba 1/3 y fecha 19:43. Es retorno al mismo proceso;
no demuestra restauración desde disco, arranque frío o suspensión física.

El host cierra sesión y confirma el descarte de cambios sintéticos pendientes.
WC acepta la redacción de 252 bytes a las **19:46:16.070952**. La captura y
jerarquía Watch **`DX6 Watch Consumer-19_47_00_906`** muestran estado redactado,
sin lecturas, fecha ni contador, con PID `91697` intacto y sin reinicio. Los logs
continúan vacíos: es observación de estado aplicado tras logout, sin registro
directo del callback. La sesión Watch se cierra con **`Session stopped`**.

### Estados finales del widget — iPhone 18 Pro, 19:47

Seis renders MCP adicionales, inventario `dx6-widget-final-states.json`,
declaran **iPhone 18 Pro/iOS 27** efectivo: pequeño y grande ES/AX5 con vacío
(Light observado), redacción Dark y no disponible Light. La revisión visual
independiente aprueba los seis: mensajes íntegros, sin datos residuales ni
recortes, e ilustración omitida en accesibilidad. El signo de apertura de
interrogación del pequeño no disponible ocupa su propia línea, patrón ya
aceptado en DX4; no falta texto.

La revisión inspecciona también el pie adicional de las **19:28:05**, que
conserva seis restantes y fecha/hora completas. El inventario final suma
**31 PNG distintos de widgets**: 20 de la matriz inicial de iPad, seis estados
de iPhone y cinco de la corrección del pie. Un intento con índice no soportado
queda excluido; las capturas Watch diagnósticas no forman parte de este conteo.
No se confunden renders con widgets instalados, pruebas de VoiceOver ni tests
ejecutados. El Audit vigente de dos Swift conserva su alcance.


### `saved` final con pie completo — Watch 49 mm, 19:48–19:49

La versión final, sin selector de color, recorre `saved` en Ultra 4/49 mm,
ES/AX5, con PID **`97703`** continuo. `DX6 Saved Final Observe-19_48_43_670`
registra el aviso íntegro y la primera lectura. El desplazamiento mediante
Digital Crown y swipe basado en la jerarquía muestra los progresos, incluido
el total desconocido y 12 de 12 (`19_49_46_136`). La captura y jerarquía
**`19_49_59_198`** presentan el pie completamente visible: «5 más en el iPhone»
y «Actualizado: 10 sept 2026, 2:00», sin recorte. Queda cubierta la fecha visual
que no se completó en el primer recorrido; no se atribuye esa limitación al
código ni se hereda su salida no explicada como fallo de esta repetición.

La evidencia sigue siendo fixture de Simulator con modelo/receptor/cache reales,
sin WC, VoiceOver físico ni desconexión real. No demuestra otros tamaños o
idiomas. El build oficial final conserva `BUILD SUCCEEDED` en
`ActionArtifacts/default/GetBuildLog/02EB4C35-DFF9-4468-B241-FD524DAA2432.txt`,
**735 líneas** y cero diagnósticos `warning:`/`error:`. Los gates canónicos y el
Audit vigente conservan su alcance sobre los dos Swift finales.

### Restauración final del entorno — 19:51

La instalación normal de Watch arranca **sin flags de fixture**, PID **`98412`**.
`DX6 Normal Watch Final-19_51_19_670` muestra únicamente «Tus mangas, aquí /
Inicia sesión en Manga Library en el iPhone.», sin aviso de fixture, lecturas,
fecha ni contador. La sesión de observación y el workspace de restauración
terminan con **`Session stopped`**; la sesión host también queda cerrada.

MCP se restaura a **`MangaLibrary` / `Fast` / iPhone 17**, con cero diagnósticos
en Issue Navigator. Ambos schemes compartidos permanecen sin diff; el principal
conserva SHA-256 `2eb06cb4b56e8ac78031322e74e497eec375e4d683c9b9fc09cef4e20adc7907`.
Watch conserva LLDB y `project.pbxproj` no tiene cambios. Los gates y la limpieza
del delta quedan cumplidos; DX6/issue #88 permanecen abiertos por la matriz
restante y los límites físicos, sin entrega de DX6 ni inicio de DX7.


### Decisión posterior sobre hardware Watch — 10 de septiembre

El propietario indica que no prevé disponer de Apple Watch físico antes de entregar
el proyecto y permite esa entrega con las pruebas físicas Watch pendientes para
después. SDD 06 v1.38 y SDD 09 v1.17 recogen el aplazamiento de H02/H03/H04,
con la oportunidad de adelantarlas si se obtiene una pareja compatible prestada,
por ejemplo de un amigo. Los criterios siguen pendientes, no aprobados; no se
fija fecha ni se sustituye hardware por Simulator.

La decisión elimina únicamente el impedimento de entrega del proyecto debido
a esa evidencia Watch pendiente. H01 del iPhone no se aplaza y los demás criterios
mantienen su obligación. El gate completo no se declara verde, ni se autoriza
por ello entrega Git/GitHub, publicación en App Store o inicio de DX7. Los
checkpoints anteriores conservan el estado y los límites que tenían entonces.

### Ampliación Watch de 40 mm e Inspector — desde las 20:07

Xcode 27 RC `27A266a`/Swift 6.4 y el scheme **local temporal**
`DX6 Watch Validation`, creado mediante Xcode UI, permiten ejecutar el target
watch sin construir/ejecutar el host. Solo el scheme temporal omite ese host;
no se cambia por ello la composición del scheme compartido. El build oficial
`GetBuildLog/DA49AD49-386A-45E5-BFF4-A352D88C3085.txt` termina con
`BUILD SUCCEEDED`, **413 líneas** y cero diagnósticos `warning:`/`error:`.

Los recorridos usan Apple Watch SE 3 de **40 mm**, UUID
`F2349454-1882-4D1F-8C48-576D4E5E973E`, watchOS 27. El inventario local
`dx6-watch40-resume.json` conserva las capturas, jerarquías y límites de la
reanudación; sus paths completos permanecen fuera de Git. Los prefijos
`DX6 Watch40 Matrix` y `DX6 Watch40 Resume` identifican **42 conjuntos de
artefactos**, diez ejecuciones/instalaciones de nueve configuraciones y 24
acciones UI completadas. Una petición UI falla por caducidad de sesión; no se
ejecutan tests. Las instalaciones reutilizan builds incrementales, no equivalen
a diez compilaciones independientes. El último log completo,
`GetBuildLog/47F84A9B-BD91-49DE-A409-3810A4070BEE.txt`, contiene 388 líneas y
cero `warning:`/`error:`; los once logs completos inspeccionados conservan ese
resultado, separado de los diagnósticos runtime indicados después.

| Caso | PID y artefactos | Evidencia y límite |
| --- | --- | --- |
| Títulos largos ES/AX5 | `2346`, `20_07_15_795` a `20_09_20_934` | Scroll y tres etiquetas agrupadas con título/progreso completos. La captura `20_08_51_226` muestra cinco restantes y fecha/hora íntegra; `20_09_20_934` muestra la tercera lectura. Las primeras muestras son parciales; el suplemento siguiente completa su inspección visual sin reetiquetar esas capturas iniciales. |
| Suplemento de títulos largos ES/AX5 | `5662`, `20_22_56_059` a `20_24_10_033` | Seis desplazamientos cortos de 87 pt, con solape de 60 pt, cubren todas las palabras: primer título en `20_22_56_059` → `20_23_08_685` → `20_23_19_615` y progreso en `20_23_33_623`; segundo en `20_23_44_258` → `20_24_00_454` y progreso en `20_24_10_033`. Sin ellipsis, superposición ni salida durante el recorrido. Pie y tercera lectura conservan la evidencia del primer caso. |
| Contenido ES/XXX Large | `3229`, `20_10_47_017`, `20_11_05_554`, `20_11_19_615` | Tres lecturas completas entre las capturas, incluido fallback y total desconocido. El siguiente desplazamiento no se ejecuta al caducar la sesión; la observación con sesión nueva muestra ClockFace (`20_13_43_384`). El pie tiene semántica completa, pero falta su inspección visual íntegra. |
| Contenido ES/AX5 | `4145`, `20_15_16_498` a `20_16_07_498` | Primera y segunda filas íntegras; pie completo en `20_15_51_850`. La tercera conserva progreso y semántica completos, pero parte de su título queda bajo la navegación en la captura. No se atribuye ese segmento no observado a truncado permanente. |
| Vacío ES/AX5 | `4435`, `20_16_39_122`, `20_16_52_648`, `20_17_13_423` | Título, ayuda de marcar el tomo en iPhone y fecha íntegros tras Crown; sin lecturas ni contador. El spinner inicial de `20_16_29_390` es transitorio y se excluye de la captura estable. |
| Vacío EN/AX5 | `4657`, `20_17_52_450`, `20_18_06_700`, `20_18_26_507` | Título y ayuda «Set your current volume in Manga Library on your iPhone.» completos entre capturas solapadas; fecha completa tras dos movimientos de Crown. Sin lecturas ni contador; spinner inicial recapturado. |
| Redacción ES/AX5 | `4935`, `20_19_02_455`, `20_19_16_325` | «Tus mangas, aquí» e instrucción íntegra de iniciar sesión en el iPhone tras un movimiento de Crown; sin lecturas, fecha ni contador. |
| Redacción EN/AX5 | `5078`, `20_19_46_264`, `20_20_13_563` | «Your manga, right here» y «Sign in to Manga Library on your iPhone.» íntegros tras un movimiento de Crown; sin lecturas, fecha ni contador. |
| No disponible ES/AX5 | `5254`, `20_20_45_157`, `20_21_00_076` | «Vamos a actualizar» e instrucción íntegra de abrir el iPhone para ver las lecturas tras un movimiento de Crown; sin lecturas, fecha ni contador. |
| No disponible EN/AX5 | `5403`, `20_21_39_186`, `20_21_54_224` | «Let's refresh» y «Open Manga Library on your iPhone to bring your readings here.» íntegros tras un movimiento de Crown; sin lecturas, fecha ni contador. |

Los seis estados se observan estables después de recapturar el spinner de
lanzamiento. Los logs conservan el baseline de API handler/`NSMapGet`; en los
lanzamientos de redacción EN y no disponible ES aparecen respectivamente dos y
ocho líneas AXUIA de serialización de hijos. Las jerarquías posteriores contienen
los textos esperados completos. Estos mensajes runtime no son warnings del
compilador ni se omiten al informar del build limpio. La jerarquía y los gestos
de Simulator no acreditan locución, foco físico o transporte WatchConnectivity.


Accessibility Inspector identifica la app del Watch 40 mm, PID `2346`. En la
superficie de ajustes inspeccionada solo se encuentra **Reduce Motion**, con
valor original `0`; no se cambia ninguna opción. No se expone un control
**Increase Contrast** en esa inspección. Es un límite de la herramienta y el
recorrido disponibles, no evidencia de que watchOS carezca de la capacidad;
la inspección posterior de Settings que se registra a continuación sí permite
activar el ajuste nativo.

La apertura de Manage Schemes vuelve a generar un scheme compartido de Widget
y guarda configuración cacheada del Watch, con argumentos antiguos y depuración.
La restauración posterior sigue pendiente en este checkpoint. No se presenta
el estado actual del IDE como limpio ni se reutiliza la limpieza de las 19:51
para acreditar esta nueva ejecución. Los seis estados y el suplemento de
títulos largos ya están registrados. Este checkpoint inicial precede a los
ajustes y la restauración Watch que se documentan a continuación; la limpieza
general de Xcode aún depende del cierre posterior del recorrido de iPhone.

### Ajustes nativos y restauración Watch de 40 mm — 20:29–20:33

El recorrido posterior usa **Settings nativo de watchOS** mediante Xcode MCP,
prefijo `DX6 Watch40 Motion`. Increase Contrast pasa de `0` en
`20_29_16_785` a `1` en `20_29_28_497`; Reduce Motion pasa de `0` en
`20_30_31_032` a `1` en `20_30_45_046`. Así se resuelve el límite inicial de
Inspector sin inferir que faltaba soporte del sistema ni introducir un setter
privado o un filtro visual en la app.

Con ambos ajustes activados, `longtitles` ES/AX5 conserva título y progreso
al desplazarse: PID `7376`, capturas `20_31_20_514` y `20_31_39_415`.
Es evidencia visual y de interacción representativa, sin medición temporal de
animaciones ni locución/foco de VoiceOver físico. Después se restauran ambos
valores originales: Reduce Motion `0` en `20_31_58_050`, con el padre «No» en
`20_32_07_300`, e Increase Contrast `0` en `20_32_37_214`.

La instalación/ejecución normal posterior usa argumentos `[]` y variables `{}`,
PID `7734`, captura `20_33_00_560`: «Vamos a actualizar», sin lecturas de fixture,
fecha ni contador. No acredita una entrega nativa WC por el hecho de arrancar
sin flags. `DX6 Watch40 Motion` se cierra con `Session stopped`; la sesión
anterior `DX6 Watch40 Resume` ya no existe. El build oficial
`GetBuildLog/DCC49ED8-7139-4A55-8964-ABF9C98BB356.txt` conserva 388 líneas y
cero diagnósticos de compilación.

El inventario ampliado `dx6-watch40-resume.json` conserva **68 conjuntos de
artefactos**: 42 de la matriz, 24 de ajustes y dos de restauración normal.
Incluye doce instalaciones/ejecuciones, sin tests nuevos. La restauración de
Settings y app Watch está acreditada. Este checkpoint precede al recorrido
de iPhone registrado a continuación; la limpieza de schemes/proyecto aún
requiere confirmación final.

### Widget instalado con contraste y movimiento reducidos — 20:34–20:38

Xcode MCP observa iPhone 17 Simulator/iOS 27 mediante la sesión
`DX6 Widget Contrast Settings`, sin construir, instalar o cambiar schemes.
El widget **pequeño, redacción ES/Dark** de Home conserva «Tus mangas, aquí»
y la ayuda de iniciar sesión, con su etiqueta combinada y sin lecturas, fecha,
progreso o contador. El baseline es `20_34_29_164`, SpringBoard PID `66102`.

Settings acredita valores originales `0` de Increase Contrast
(`20_35_25_234`) y Reduce Motion (`20_35_50_777`), activados a `1` en
`20_36_40_146` y `20_36_04_071`, respectivamente. Home con ambos activados,
`20_36_59_516`, mantiene layout y significado; la composición observada muestra
fondo más oscuro y ayuda más clara. Es una comparación visual estática, sin
cuantificar ratios, medir animaciones, acreditar VoiceOver físico o extender el
resultado a otras familias/estados o a todos los tamaños de Dynamic Type.

Increase Contrast vuelve a `0` en `20_37_23_772` y Reduce Motion a `0` en
`20_38_16_488`; Home final `20_38_34_567` conserva el mismo PID de SpringBoard,
la apariencia original y el estado sin datos residuales. La sesión termina con
`Session stopped`. El prefijo registra **18 conjuntos de artefactos**, 15 acciones
UI —13 taps y dos Home— y dos activaciones de Settings adicionales. Se conservan
separados de los 68 conjuntos Watch y de los renders de widgets. La restauración
general de Xcode quedaba en curso al terminar ese recorrido; se acredita en
el checkpoint final siguiente.

### Restauración final y cierre técnico del tramo — 20:42

Manage Schemes elimina el scheme temporal `DX6 Watch Validation`, pero el IDE
vuelve a serializar configuración cacheada. Se cierra **solo el proyecto
MangaLibrary**, se respalda esa configuración fuera de Git y se restaura el
scheme compartido Watch byte a byte desde HEAD; se retiran únicamente los dos
artefactos generados por este trabajo, el scheme compartido de Widget y el local
temporal DX6. No se modifica `project.pbxproj`.

Al reabrir, Xcode MCP muestra solo los dos schemes canónicos y
`MangaLibrary` / `Fast` / iPhone 17, sin diagnósticos en Issue Navigator. Ambos
schemes compartidos son idénticos a HEAD, verificados mediante SHA-256:

- `MangaLibrary.xcscheme`: `2eb06cb4b56e8ac78031322e74e497eec375e4d683c9b9fc09cef4e20adc7907`.
- `MangaLibraryWatch Watch App.xcscheme`: `d5ad86bbbe99b0daf005372a389283ef506766a4b05d5062aac5408a12f39421`.

`BuildProject` de las **20:42:00** aprueba en 3,592 s.
`BuildProject-Log-20260910-204200.txt` y
`GetBuildLog/BF0E18D4-75A8-4B20-8761-E5871F3FEA91.txt` contienen 439 líneas,
cero `warning:`/`error:` y cero issues estructurados. Las sesiones de dispositivo
están cerradas; los ajustes de Watch/iPhone conservan sus valores originales.
No se ejecutan tests por este build ni se alteran los planes.

DX6.2 queda cumplida como matriz visual/semántica representativa y DX6.3 mediante
evidencia nativa y reutilización explícita de evidencia física/lógica anterior.
DX6.5 dispone de revisión y registro preparados; no representa entrega.
**DX6 y el issue #88 siguen abiertos:** H01 mantiene su obligación no aplazada;
H02/H03/H04 siguen pendientes después de entregar el proyecto, anticipables con
pareja compatible prestada. No se declara verde el Deluxe Release Gate completo
ni se inicia DX7. Los límites exploratorios conservan su resultado, sin exigir
un producto cartesiano ni convertirlos en pruebas aprobadas.

El [checkpoint de issue #88](https://github.com/JFrancoG/MangaLibrary/issues/88#issuecomment-5623720754)
registra DX6.2/DX6.3 completadas con ese alcance y mantiene DX6.4/DX6.5 abiertas;
la preparación de revisión/evidencia no equivale a entregar la subfase.
