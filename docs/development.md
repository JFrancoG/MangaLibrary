# Desarrollo y validación

Guía operativa del proyecto. [AGENTS.md](../AGENTS.md), las SDD y los ADR vigentes
definen las reglas; [Progress](Progress.md) conserva cada ejecución con fecha,
candidata, entorno y límites.

## Preparación

1. Lee el issue activo y las SDD/ADR del alcance. Comprueba rama, estado de Git y cambios previos antes de editar.
2. Abre `MangaLibrary.xcodeproj` con Xcode 27 / Swift 6.4. El scheme principal es `MangaLibrary`; el companion tiene `MangaLibraryWatch Watch App`. Los destinos mínimos son iOS/iPadOS 27 y watchOS 27.
3. Para habilitar el registro, copia [`Local.xcconfig.example`](../Configuration/Local.xcconfig.example) a `Configuration/Local.xcconfig` y proporciona `MANGA_LIBRARY_APP_TOKEN` por el canal privado aprobado. No sobrescribas una copia existente ni imprimas su contenido en logs. [`Shared.xcconfig`](../Configuration/Shared.xcconfig) incluye ese archivo opcional; el catálogo público sigue disponible sin él.
4. Usa la firma y los entitlements aprobados para dispositivos físicos. Cambiar App Groups, capacidades o configuración de distribución necesita alcance propio.

No hay dependencias externas que instalar. Tests y previews usan composición
determinista, almacenamiento aislado y datos sintéticos; no usan red de producción
ni credenciales reales.

## Xcode MCP oficial

Descubre las herramientas y sus esquemas en la conexión actual. En la superficie
de Xcode Service, `XcodeListWorkspaces` lista proyectos abiertos; identifica
MangaLibrary por su ruta y usa su `workspaceIdentifier`. Si hace falta abrirlo,
`XcodeOpenWorkspace` recibe la ruta verificada del proyecto. La primera apertura
puede pedir autorización para el agente y la carpeta; una lista de herramientas
disponibles no demuestra que esa autorización exista.

Confirma scheme, destino, test plan, toolchain y diagnósticos antes de una
validación dependiente de Xcode. No reutilices identificadores de una conexión
anterior ni supongas que la ventana GUI y el servicio comparten selección.
Restaura cualquier selección temporal al terminar.

Builds, tests, previews y diagnósticos se operan mediante el MCP oficial. Los
scripts siguientes son los gates CLI reproducibles aprobados en
[SDD 06](specs/06-testing-quality-and-accessibility.md) y
[SDD 07](specs/07-documentation-and-docc.md); no sustituyen silenciosamente al MCP.

## Comprobaciones estáticas

Desde la raíz del repositorio:

```sh
./Scripts/validate-test-plans.sh
python3 Scripts/validate-deluxe-configuration.py
```

El primer script comprueba la clasificación exclusiva `fast`/`integration` por
suite, los filtros y targets de los cuatro planes, y `Fast` predeterminado.
El segundo contrasta los cinco targets reales, dependencias, schemes y selección
habilitada de tests. Ninguno ejecuta tests, builds, DocC ni pruebas físicas.

## Builds y DocC

Indica el Developer directory verificado durante el preflight. Sustituye la ruta
del ejemplo por esa instalación:

```sh
export MANGALIBRARY_DEVELOPER_DIR="/ruta/verificada/Xcode.app/Contents/Developer"
./Scripts/validate-advanced-build.sh --deluxe
./Scripts/validate-docc.sh
```

Los scripts comprueban Xcode 27 y Swift 6.4, aplican la selección a sus herramientas
y no modifican `xcode-select` ni recurren a otra instalación predeterminada.

El build Deluxe exige app iOS, unit tests, UI tests, widget y companion watchOS en
los grafos Debug/Release, con DerivedData temporal. Habilita testabilidad solo
para ese build local, permitiendo compilar los tests `@testable` con el resto de
ajustes Release sin cambiar la configuración distribuida. Compilar tests no
equivale a ejecutarlos. El modo sin `--deluxe` conserva el gate Advanced; no
sustituye el inventario de cinco targets de Deluxe.

El gate DocC comprueba la configuración efectiva de los cinco targets y genera
el archive de la app en `.build/docc/MangaLibrary.doccarchive`, ignorado por Git.
No acredita un archive independiente de widget o Watch. Quick Help y previews de
documentación no sustituyen ese gate.

Los gates rechazan warnings y errores, sin allowlists. Conforme a
[ADR 0020](adr/0020-skip-unused-app-intents-metadata-extraction.md), los cinco
targets omiten la extracción de metadata de App Intents mientras el producto no
declare esa capacidad. Cambiar toolchain o adoptar App Intents exige revisar
esa decisión.

## Ejecución de tests

Selecciona un plan desde **Product > Test Plan** o con las herramientas disponibles
del MCP oficial, confirmando su selección antes de ejecutar:

| Plan | Alcance |
| --- | --- |
| `Fast` | Predeterminado; suites Swift Testing con tag `fast`. |
| `Integration` | Suites con tag `integration`, para fronteras controladas como URLProtocol, SwiftData o Keychain aislado. |
| `UI` | Recorridos XCUITest con fixtures sintéticas. |
| `ReleaseGate` | Targets unitario y UI completos, sin filtros. |

Los recuentos de ejecución proceden del resultado nativo `.xcresult` cerrado.
Distingue declaraciones e invocaciones parametrizadas, fallos, omisiones y
warnings de runtime. El inventario `GetTestList` no es un oráculo de selección
para tags heredados de suite. Si el MCP agota su tiempo mientras Xcode sigue
ejecutando, espera al cierre nativo y recupera su resultado antes de repetir.

Una candidata Deluxe requiere por separado tests, build `--deluxe`, DocC y
evidencia manual aplicable. [La matriz DX6](dx6-integration-accessibility.md)
conserva H01 y los pendientes físicos Watch; una ejecución automática no los cierra.

## Cambios exclusivamente documentales

Para Markdown externo al catálogo DocC, valida fuentes, coherencia de estado,
enlaces, anchors, privacidad y `git diff --check`. No atribuyas builds, tests,
previews o archives nuevos a una revisión editorial. Los resultados históricos
mantienen fecha y alcance. Si cambia el catálogo DocC o código/configuración,
aplica además los gates afectados.
