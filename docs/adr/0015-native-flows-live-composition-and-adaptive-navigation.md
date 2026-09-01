# ADR-0015: Flujos nativos, composición live y navegación adaptable

**Estado:** Superseded
**Fecha:** 2026-08-28
**Supersede:** [ADR-0014](0014-native-flows-live-composition-and-direct-doubles.md)
**Superseded by:** [ADR-0017](0017-validated-http-status-response-boundary.md)

## Contexto

ADR 0014 separó correctamente composición live, dobles directos y flujos según
su fuente de verdad. También conservó para Catálogo un `NavigationSplitView` en
todas las presentaciones. C4 necesita una navegación compacta apilada y una
portada de detalle grande con énfasis visual al abrir, sin animar el detalle
completo ni perder la relación simultánea lista-detalle de iPad.

Se evaluaron primero `navigationTransition(.zoom)` y después una superposición
que interpolaba la portada entre las geometrías del origen y el destino. La
primera anima todo el destino; la segunda añade medición global, estado efímero,
una copia visual y coordinación con el push, y no produjo un resultado runtime
convincente. El propietario eligió una animación local, corta y explícita sobre
la portada del destino.

La toolbar también necesita tres acciones visibles. Un menú de desbordamiento
para Filtros no se justifica con un único elemento y un `Picker` segmentado
dentro de la toolbar produce un control anidado. En iOS 27,
`ToolbarSpacer(.fixed)` es la API que declara el corte visual entre secciones.

## Drivers

- Animar exclusivamente la portada grande al abrir el detalle compacto.
- Mantener una única selección de Catálogo y la misma identidad `Manga.ID`.
- Conservar navegación, pop y gestos nativos sin geometría o overlays propios.
- Conservar una presentación regular estable sin fingir un push.
- Restablecer el contexto de lectura al cambiar de manga en el detalle regular.
- Respetar Reduce Motion mediante una alternativa del sistema.
- Mantener Filtros separado y Lista/Cuadrícula juntos como botones nativos.
- No introducir router global, dependencia externa ni rutas entre tabs.
- Conservar todas las fronteras live, de preview y de testing de ADR 0014.

## Opciones consideradas

1. **Escala local de la portada del destino:** `scaleEffect` recorre tres
   valores explícitos (`0,1 → 1,25 → 1`) durante `0,38 s`; no necesita conocer el
   origen ni alterar la navegación.
2. **Superposición entre geometrías reales:** enlaza visualmente origen y
   destino, pero requiere medición global, copia visual y coordinación efímera;
   la implementación evaluada no dio un resultado runtime convincente.
3. **`navigationTransition(.zoom)`:** es nativa y simétrica, pero anima el
   destino entero, no solo la portada solicitada.
4. **`matchedGeometryEffect` entre árboles de navegación:** no proporciona un
   ciclo de vida soportado cuando la fuente deja de estar en el árbol presentado
   y obligaría a coordinar manualmente push y pop.
5. **Stack en todas las presentaciones:** simplifica el árbol, pero elimina la
   relación lista-detalle simultánea de la presentación regular.

## Decisión

Se conservan las decisiones de ADR 0014 sobre arquitectura feature-first,
composition root exclusivamente live, transporte HTTP, cliente tipado, dobles
directos, previews deterministas y smoke UI mínimo.

El shell mantiene tabs estables y no queda envuelto en una pila global. Cada
feature posee su navegación. Catálogo usa:

- `NavigationStack` con path homogéneo `[Manga.ID]` en presentación compacta;
- `NavigationSplitView` con selección y detalle estables en presentación
  regular;
- `selectedMangaID: Manga.ID?` como única fuente semántica para derivar el path
  compacto y alimentar el detalle regular;
- `NavigationLink(value:)` en lista y cuadrícula compactas, sin callbacks de
  apertura ni medición de portadas;
- estado local de presentación en `MangaDetailView`: la portada parte de escala
  `0,1`, anima hasta `1,25` con `easeIn` durante `0,3 s` y vuelve a `1` con
  `easeOut` durante `0,08 s`;
- ausencia de escala personalizada en presentación regular o con Reduce Motion;
  en este último caso se conserva `crossFade` para el destino compacto;
- posición de scroll local que vuelve inmediatamente al borde superior cuando
  cambia `Manga.ID` en presentación regular, sin recrear todo el detalle, animar
  el desplazamiento ni forzar el foco;
- pop nativo sin interceptar el gesto de regreso.

En compacto, la toolbar declara tres botones con placement `.primaryAction`:
Filtros en su propio `ToolbarItem`, un `ToolbarSpacer(.fixed)` y un
`ToolbarItemGroup` para Lista y Cuadrícula. En regular, Filtros
permanece en la toolbar y la pareja de layout pasa a una franja superior propia
para que el título de la columna no se trunque. Los dos modos conservan
indicación visual y trait accesible de selección. El spacer permanece como
hermano del grupo y el agrupamiento compacto expresa la pareja sin cambiar su
presentación observable. El título conserva modo `.large` en compacto y usa
`.inline` en regular para no apilar la reserva expandida del título grande entre
la toolbar, la búsqueda y la franja de layout.

Colección conserva selección y navegación independientes; su contenedor se
concreta al implementar esa feature sin copiar el path de Catálogo. Cuenta
mantiene su ruta lineal en `NavigationStack`. Los destinos reciben identidades,
no DTO, modelos SwiftData vivos ni clientes. No se introduce un router global.

## Consecuencias

### Positivas

- Solo la portada recibe la animación personalizada de apertura.
- Se retiran geometría global, overlay, copia visual y coordinación manual.
- iPad conserva su detalle simultáneo y estable.
- Un manga nuevo no hereda la posición de lectura del seleccionado previamente.
- Push, pop y selección actualizan la misma fuente de verdad.
- Reduce Motion recibe una alternativa explícita.
- Filtros queda visualmente separado de dos botones de layout nativos y el
  título regular conserva su anchura.
- Las fronteras live y los dobles directos no cambian.

### Negativas

- La escala enfatiza la portada del destino, pero no dibuja continuidad espacial
  desde la portada seleccionada.
- Si la imagen remota no está lista durante los `0,38 s`, se anima su contenedor o
  placeholder y no el bitmap que llegue después.
- El pico `1,25` requiere inspección visual en anchura compacta y Dynamic Type de
  accesibilidad para descartar recortes indeseados.
- Catálogo compone dos contenedores nativos según la presentación.
- `MangaDetailView` posee una posición de scroll local adicional.
- Build, tests y snapshots no demuestran por sí solos el timing frame a frame.

## Validación

- Verificar que push y pop compactos escriben únicamente `selectedMangaID` y
  abren el mismo `Manga.ID` desde lista y cuadrícula.
- Verificar que el split regular sigue actualizando su detalle sin push.
- Desplazar el detalle regular, seleccionar otro `Manga.ID` y verificar que
  portada y título vuelven al borde superior sin scroll animado ni cambio de
  foco impuesto por la app.
- Inspeccionar que Filtros forma una sección propia y Lista/Cuadrícula una pareja
  de botones, sin menú de un elemento ni `Picker` segmentado, y que el título
  regular no se trunca.
- Inspeccionar en runtime la secuencia de escala de la portada, que el resto del
  detalle no recibe la animación y que el regreso conserva el pop nativo.
- Inspeccionar `crossFade` y ausencia de escala con Reduce Motion activado.
- Ejecutar previews compactas y regulares, el smoke UI, `ReleaseGate`, build y
  diagnósticos con warnings como errores.
- Confirmar que el diff no añade router, dependencia, configuración, endpoint,
  medición geométrica ni segunda fuente de navegación.

## Condiciones de revisión

- Deep links, restauración o navegación transversal requieren coordinación
  programática compartida.
- Colección demuestra una necesidad de ruta distinta a su selección local.
- SwiftUI ofrece una transición pública limitada a una subvista que satisfaga
  mejor la intención visual sin estado o geometría auxiliar.
- La identidad remota deja de poder representarse inequívocamente con
  `Manga.ID`.

## Especificaciones relacionadas

- [Arquitectura y composición](../specs/01-architecture-and-composition.md)
- [API, catálogo, búsqueda e imágenes](../specs/02-api-catalog-search-and-images.md)
- [Colección local e invariantes](../specs/03-local-collection-and-invariants.md)
- [Alcance de producto y niveles](../specs/00-product-scope-and-levels.md)
- [Testing, calidad y accesibilidad](../specs/06-testing-quality-and-accessibility.md)
