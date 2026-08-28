# Manga Library — sistema cromático Library Red

- **Aplicación:** Manga Library
- **Plataforma objetivo:** iOS 27
- **Versión:** 1.0.0
- **Fecha:** 25 de agosto de 2026
- **Estado:** contrato aprobado y materializado en Asset Catalog
- **Implementación:** 28 de agosto de 2026
- **Autoridad exacta:** [`library-color-tokens.json`](library-color-tokens.json)

## Resultado

Library Red conserva la identidad visual del icono versionado de Manga Library: negro tinta, papel marfil y rojo coral. La paleta se expresa mediante nombres semánticos y cuatro apariencias nativas:

1. Light estándar.
2. Dark estándar.
3. Increased Contrast Light.
4. Increased Contrast Dark.

El término «pantone» se usó como nombre de trabajo durante la exploración privada. Técnicamente, este contrato es un **sistema cromático digital semántico**; no asigna tintas físicas ni códigos licenciados del Pantone Matching System.

La referencia visual durable es el icono versionado en `MangaLibrary/Resources/MangaLibrary.icon`. Los ensayos genéricos y la referencia HTML permanecen fuera de Git; este contrato no depende de ellos y todos los valores y ratios se recalculan desde el JSON canónico. El trabajo se originó como una exploración coordinada con ScienceLibrary, pero Manga Library no impone ni presume sincronización entre repositorios.

## Alcance normativo correcto

- Los pares Light y Dark se han contrastado con los umbrales numéricos de [WCAG 2.2](https://www.w3.org/TR/WCAG22/) nivel AA. Para software nativo, [WCAG2ICT](https://www.w3.org/TR/wcag2ict-22/) orienta de forma informativa sobre los criterios A y AA; no es un estándar ni establece requisitos propios.
- Increased Contrast usa como objetivo interno `7:1` para todo texto, tomando el umbral de [WCAG 2.2 SC 1.4.6](https://www.w3.org/TR/WCAG22/#contrast-enhanced).
- WCAG no define un nivel AAA independiente para contraste no textual. En Increased Contrast se adopta un objetivo interno reforzado de `4.5:1`, por encima del umbral `3:1` de [SC 1.4.11](https://www.w3.org/TR/WCAG22/#non-text-contrast), adoptado aquí como referencia para software nativo mediante la guía informativa WCAG2ICT.
- Una paleta no puede certificar la conformidad AA o AAA de una app completa. Solo puede demostrar que sus pares de color autorizados satisfacen los umbrales indicados; tampoco demuestra conformidad con WCAG2ICT ni soporte de la etiqueta Sufficient Contrast de App Store.
- WCAG2ICT vigente cubre A y AA, no AAA, y no define conformidad propia. Por eso el término preciso es **«objetivo AAA para contraste textual en Increased Contrast»**, no «app WCAG AAA».
- [WCAG2Mobile 2.2](https://www.w3.org/TR/wcag2mobile-22/) continúa como Group Draft Note informativa y trabajo en curso; no define conformidad para apps y, por ahora, solo orienta A y AA, no AAA.

### Umbrales de esta especificación

| Uso | Light / Dark | Increased Contrast | Política de Library Red |
|---|---:|---:|---|
| Todo texto funcional | `≥ 4.5:1` | `≥ 7:1` | No se rebaja el umbral por tamaño o peso. |
| Iconos esenciales, foco y límites necesarios | `≥ 3:1` | `≥ 4.5:1` | `4.5:1` en Increased Contrast es una exigencia interna, no AAA normativo. |
| Separadores decorativos | No aplicable | No aplicable | Nunca pueden ser la única señal de un límite, estado o relación. |
| Texto que forma parte del logotipo o nombre de marca | Exento | Exento | Excepción limitada al logotipo exacto; no cubre iconos funcionales, texto corriente ni controles interactivos. |

WCAG permite `3:1` para texto grande en AA y `4.5:1` en AAA, pero esta paleta trata **todo el texto como texto normal**. Así no se depende de una interpretación ambigua entre puntos CSS, puntos iOS, tamaño y peso.

WCAG exime formalmente el contenido de componentes inactivos. Library Red adopta voluntariamente el umbral textual también para `TextDisabled`; es una política de producto más exigente, no un requisito normativo adicional.

## Método de construcción y validación

1. Se partió de los tres ejes del icono: papel cálido `h≈65`, coral/rojo `h≈22–32` y tinta casi negra.
2. Las escalas se diseñaron en OKLCH para controlar de forma predecible claridad, cromaticidad y matiz.
3. Cada color se restringió al gamut sRGB. Ningún token funcional necesita clipping ni gamut mapping.
4. El valor OKLCH se convirtió a sRGB opaco y se cuantizó a 8 bits.
5. El contraste se calculó sobre el **HEX sRGB final**, usando la luminancia relativa de WCAG y el umbral de linealización `0.04045`.
6. Se validaron los productos cartesianos de todos los foregrounds y fondos autorizados, no una selección de ejemplos.

> La `L` de OKLCH no es la luminancia relativa de WCAG. OKLCH ayuda a diseñar una escala coherente, pero no demuestra contraste por sí solo.

[`library-color-tokens.json`](library-color-tokens.json) es la autoridad exacta de roles, modos, umbrales, parejas, OKLCH y HEX sRGB. Este Markdown define su significado, política de uso y límites. Una discrepancia entre ambos bloquea la implementación; ni el código ni los assets pueden sustituir silenciosamente el contrato. Los color sets materializados coinciden con el JSON y mantienen los OKLCH como información de diseño para futuras revisiones.

## Inventario semántico materializado en Asset Catalog

Los nombres de asset son deliberadamente semánticos. Que dos roles compartan el mismo valor en v1 no los convierte en el mismo contrato.

| Asset | Color fuente | Uso permitido |
|---|---|---|
| `Canvas` | `canvas` | Fondo raíz opaco. |
| `BackgroundElevated` | `backgroundElevated` | Hojas, popovers o fondos elevados opacos. |
| `Surface` | `surface` | Tarjetas y agrupaciones no interactivas. |
| `SurfaceStrong` | `surfaceStrong` | Agrupación de mayor jerarquía. |
| `SeparatorDecorative` | `separatorDecorative` | División puramente decorativa. |
| `ControlBorder` | `controlBorder` | Límite necesario de controles, campos, selección o gráficos. |
| `TextPrimary` | `textPrimary` | Títulos y contenido principal. |
| `TextSecondary` | `textSecondary` | Metadatos y contenido secundario. |
| `TextTertiary` | `textTertiary` | Contenido de menor jerarquía, todavía funcional. |
| `TextDisabled` | `textDisabled` | Texto de controles inactivos; no aplicar opacidad adicional. |
| `BrandPrimary` | `brandPrimary` | Fondo de acción primaria o selección. |
| `BrandPrimaryInk` | `brandPrimary` | Marca, enlace, icono o texto sobre fondos neutros autorizados. |
| `OnBrandPrimary` | `onBrandPrimary` | Contenido sobre `BrandPrimary`. |
| `BrandContainer` | `brandContainer` | Contenedor tonal, nunca único límite esencial. |
| `OnBrandContainer` | `onBrandContainer` | Contenido sobre `BrandContainer`. |
| `Link` | `brandPrimary` | Enlaces con subrayado, icono o affordance adicional. |
| `FocusRing` | `brandPrimary` | Indicador de foco; debe conservar grosor y área perceptibles. |
| `SuccessFill` / `SuccessInk` | `success` | Fondo e ink de éxito. |
| `OnSuccess` | `onSuccess` | Contenido sobre `SuccessFill`. |
| `WarningFill` / `WarningInk` | `warning` | Fondo e ink de aviso. |
| `OnWarning` | `onWarning` | Contenido sobre `WarningFill`. |
| `DangerFill` / `DangerInk` | `danger` | Fondo e ink de error o acción destructiva. |
| `OnDanger` | `onDanger` | Contenido sobre `DangerFill`. |
| `InformationFill` / `InformationInk` | `information` | Fondo e ink informativos. |
| `OnInformation` | `onInformation` | Contenido sobre `InformationFill`. |

## Valores fuente

Todos los colores siguientes son opacos y están dentro de sRGB.

### Light

| Token fuente | OKLCH | sRGB HEX |
|---|---:|---:|
| `canvas` | `oklch(0.985 0.004 65)` | `#FCFAF7` |
| `backgroundElevated` | `oklch(0.997 0.001 65)` | `#FFFEFD` |
| `surface` | `oklch(0.960 0.005 65)` | `#F4F1EE` |
| `surfaceStrong` | `oklch(0.925 0.006 65)` | `#E9E5E2` |
| `separatorDecorative` | `oklch(0.850 0.006 65)` | `#D1CDCA` |
| `controlBorder` | `oklch(0.590 0.010 65)` | `#827C77` |
| `textPrimary` | `oklch(0.180 0.008 65)` | `#14110E` |
| `textSecondary` | `oklch(0.420 0.012 65)` | `#524C46` |
| `textTertiary` | `oklch(0.490 0.012 65)` | `#655F59` |
| `textDisabled` | `oklch(0.490 0.012 65)` | `#655F59` |
| `brandPrimary` | `oklch(0.500 0.180 28)` | `#B3241F` |
| `onBrandPrimary` | `oklch(0.990 0.002 65)` | `#FDFBFA` |
| `brandContainer` | `oklch(0.940 0.025 28)` | `#FCE5E2` |
| `onBrandContainer` | `oklch(0.410 0.145 28)` | `#881B17` |
| `success` | `oklch(0.490 0.115 150)` | `#23723B` |
| `onSuccess` | `oklch(0.990 0.002 65)` | `#FDFBFA` |
| `warning` | `oklch(0.490 0.095 75)` | `#7F5714` |
| `onWarning` | `oklch(0.990 0.002 65)` | `#FDFBFA` |
| `danger` | `oklch(0.490 0.180 22)` | `#B01C2E` |
| `onDanger` | `oklch(0.990 0.002 65)` | `#FDFBFA` |
| `information` | `oklch(0.490 0.115 245)` | `#13659D` |
| `onInformation` | `oklch(0.990 0.002 65)` | `#FDFBFA` |

### Dark

| Token fuente | OKLCH | sRGB HEX |
|---|---:|---:|
| `canvas` | `oklch(0.135 0.008 65)` | `#0A0805` |
| `backgroundElevated` | `oklch(0.175 0.010 65)` | `#14100C` |
| `surface` | `oklch(0.200 0.012 65)` | `#1A1510` |
| `surfaceStrong` | `oklch(0.245 0.013 65)` | `#251F1A` |
| `separatorDecorative` | `oklch(0.300 0.012 65)` | `#322D28` |
| `controlBorder` | `oklch(0.600 0.010 65)` | `#857F7A` |
| `textPrimary` | `oklch(0.970 0.004 65)` | `#F7F5F2` |
| `textSecondary` | `oklch(0.720 0.008 65)` | `#A8A49F` |
| `textTertiary` | `oklch(0.650 0.008 65)` | `#938E8A` |
| `textDisabled` | `oklch(0.650 0.008 65)` | `#938E8A` |
| `brandPrimary` | `oklch(0.740 0.155 32)` | `#FD826A` |
| `onBrandPrimary` | `oklch(0.130 0.008 65)` | `#090705` |
| `brandContainer` | `oklch(0.270 0.060 28)` | `#3F1915` |
| `onBrandContainer` | `oklch(0.830 0.080 32)` | `#F7B5A7` |
| `success` | `oklch(0.780 0.130 150)` | `#76CF8A` |
| `onSuccess` | `oklch(0.130 0.008 65)` | `#090705` |
| `warning` | `oklch(0.820 0.115 80)` | `#EBBC69` |
| `onWarning` | `oklch(0.130 0.008 65)` | `#090705` |
| `danger` | `oklch(0.740 0.150 22)` | `#FB817F` |
| `onDanger` | `oklch(0.130 0.008 65)` | `#090705` |
| `information` | `oklch(0.780 0.115 245)` | `#75BFFC` |
| `onInformation` | `oklch(0.130 0.008 65)` | `#090705` |

### Increased Contrast Light

| Token fuente | OKLCH | sRGB HEX |
|---|---:|---:|
| `canvas` | `oklch(1.000 0.000 65)` | `#FFFFFF` |
| `backgroundElevated` | `oklch(1.000 0.000 65)` | `#FFFFFF` |
| `surface` | `oklch(0.955 0.000 65)` | `#F0F0F0` |
| `surfaceStrong` | `oklch(0.910 0.000 65)` | `#E1E1E1` |
| `separatorDecorative` | `oklch(0.680 0.000 65)` | `#989898` |
| `controlBorder` | `oklch(0.000 0.000 65)` | `#000000` |
| `textPrimary` | `oklch(0.000 0.000 65)` | `#000000` |
| `textSecondary` | `oklch(0.220 0.000 65)` | `#1B1B1B` |
| `textTertiary` | `oklch(0.340 0.000 65)` | `#383838` |
| `textDisabled` | `oklch(0.340 0.000 65)` | `#383838` |
| `brandPrimary` | `oklch(0.400 0.145 28)` | `#851713` |
| `onBrandPrimary` | `oklch(1.000 0.000 65)` | `#FFFFFF` |
| `brandContainer` | `oklch(0.940 0.025 28)` | `#FCE5E2` |
| `onBrandContainer` | `oklch(0.360 0.125 28)` | `#711612` |
| `success` | `oklch(0.390 0.090 150)` | `#18522A` |
| `onSuccess` | `oklch(1.000 0.000 65)` | `#FFFFFF` |
| `warning` | `oklch(0.390 0.080 75)` | `#5E3E04` |
| `onWarning` | `oklch(1.000 0.000 65)` | `#FFFFFF` |
| `danger` | `oklch(0.390 0.140 22)` | `#7F1520` |
| `onDanger` | `oklch(1.000 0.000 65)` | `#FFFFFF` |
| `information` | `oklch(0.390 0.090 245)` | `#0D4972` |
| `onInformation` | `oklch(1.000 0.000 65)` | `#FFFFFF` |

### Increased Contrast Dark

| Token fuente | OKLCH | sRGB HEX |
|---|---:|---:|
| `canvas` | `oklch(0.000 0.000 65)` | `#000000` |
| `backgroundElevated` | `oklch(0.000 0.000 65)` | `#000000` |
| `surface` | `oklch(0.180 0.000 65)` | `#121212` |
| `surfaceStrong` | `oklch(0.240 0.000 65)` | `#1F1F1F` |
| `separatorDecorative` | `oklch(0.520 0.000 65)` | `#696969` |
| `controlBorder` | `oklch(1.000 0.000 65)` | `#FFFFFF` |
| `textPrimary` | `oklch(1.000 0.000 65)` | `#FFFFFF` |
| `textSecondary` | `oklch(0.860 0.000 65)` | `#D1D1D1` |
| `textTertiary` | `oklch(0.750 0.000 65)` | `#AEAEAE` |
| `textDisabled` | `oklch(0.750 0.000 65)` | `#AEAEAE` |
| `brandPrimary` | `oklch(0.800 0.110 32)` | `#FCA391` |
| `onBrandPrimary` | `oklch(0.000 0.000 65)` | `#000000` |
| `brandContainer` | `oklch(0.220 0.050 28)` | `#2E100D` |
| `onBrandContainer` | `oklch(0.870 0.050 32)` | `#F3C9C0` |
| `success` | `oklch(0.820 0.105 150)` | `#92D8A0` |
| `onSuccess` | `oklch(0.000 0.000 65)` | `#000000` |
| `warning` | `oklch(0.850 0.090 80)` | `#EDC889` |
| `onWarning` | `oklch(0.000 0.000 65)` | `#000000` |
| `danger` | `oklch(0.800 0.110 22)` | `#FDA19E` |
| `onDanger` | `oklch(0.000 0.000 65)` | `#000000` |
| `information` | `oklch(0.820 0.090 245)` | `#92CBFB` |
| `onInformation` | `oklch(0.000 0.000 65)` | `#000000` |

## Contrato de parejas autorizadas

La validación exhaustiva expande estas reglas en `56` parejas semánticas por apariencia, `224` en total.

### Texto sobre fondos neutros

Los siguientes foregrounds están autorizados sobre `Canvas`, `BackgroundElevated`, `Surface` y `SurfaceStrong`:

- `TextPrimary`
- `TextSecondary`
- `TextTertiary`
- `TextDisabled`
- `BrandPrimaryInk`
- `Link`
- `SuccessInk`
- `WarningInk`
- `DangerInk`
- `InformationInk`

### Parejas explícitas de contenido sobre fill

| Foreground | Background |
|---|---|
| `OnBrandPrimary` | `BrandPrimary` |
| `OnBrandContainer` | `BrandContainer` |
| `OnSuccess` | `SuccessFill` |
| `OnWarning` | `WarningFill` |
| `OnDanger` | `DangerFill` |
| `OnInformation` | `InformationFill` |

### Límites e indicadores

`ControlBorder` y `FocusRing` están autorizados sobre los cuatro fondos neutros y sobre `BrandContainer`. `SeparatorDecorative` queda expresamente fuera de esta regla.

No están validados directamente contra `BrandPrimary`: si el indicador de foco toca ese fill, desplazarlo hasta un fondo neutro auditado o definir y validar un tratamiento separado de doble halo. La validez del par depende de los colores realmente adyacentes.

### Resumen del peor caso validado

Los ratios se obtienen de los HEX sRGB finales sin redondear el resultado antes de compararlo con el umbral.

| Apariencia | Peor pareja textual | Ratio | Objetivo | Peor pareja no textual | Ratio | Objetivo |
|---|---|---:|---:|---|---:|---:|
| Light | `SuccessInk / SurfaceStrong` | `4.735:1` | `4.5:1` | `ControlBorder / SurfaceStrong` | `3.289:1` | `3:1` |
| Dark | `TextTertiary / SurfaceStrong` | `5.022:1` | `4.5:1` | `ControlBorder / BrandContainer` | `3.904:1` | `3:1` |
| Increased Contrast Light | `SuccessInk / SurfaceStrong` | `7.046:1` | `7:1` | `FocusRing / SurfaceStrong` | `7.542:1` | `4.5:1` interno |
| Increased Contrast Dark | `TextTertiary / SurfaceStrong` | `7.429:1` | `7:1` | `FocusRing / SurfaceStrong` | `8.467:1` | `4.5:1` interno |

Los umbrales son límites estrictos: `4.499:1` no sería `4.5:1`. El auditor utiliza el valor completo y solo redondea para mostrarlo.

## Reglas que no deben romperse

1. **No usar alpha para “suavizar” texto sin volver a validar.** Los ratios tabulados solo son válidos para estos tokens opacos con `alpha = 1`. Cualquier alpha distinto exige calcular y auditar el color compuesto sobre cada fondo real. Esto incluye `TextDisabled`.
2. **No colocar estos pares sobre imágenes, degradados, materiales, blur o translucencia sin una nueva auditoría del píxel compuesto.** El contraste de un color aislado no permite validar Liquid Glass.
3. **`SeparatorDecorative` no delimita controles.** Si una frontera es necesaria para reconocer un campo, botón, selección, foco, eje o serie, usar `ControlBorder` o `FocusRing`.
4. **`BrandContainer` y las superficies neutras no son una señal suficiente de estado.** Añadir borde, icono, texto, forma o posición. Sus parejas con `ControlBorder` y `FocusRing` sí están auditadas.
5. **La adyacencia importa.** `FocusRing` sobre un fondo neutro no demuestra el mismo anillo sobre `BrandPrimary`; cada colocación real debe pertenecer a la matriz o auditarse aparte.
6. **No depender del color.** Éxito, aviso, error, información, validación, selección y gráficos requieren una segunda señal conforme a [SC 1.4.1](https://www.w3.org/TR/WCAG22/#use-of-color).
7. **No intercambiar `Fill`, `Ink` y `On`.** Un color que funciona como fondo no se presume válido como contenido ni viceversa; solo se permiten las parejas documentadas.
8. **No usar rojo de marca como única indicación de peligro.** `Danger` tiene un matiz propio y siempre se acompaña de símbolo y texto.

## Biblioteca, estados y visualizaciones

Manga Library puede mostrar progreso de lectura, colecciones, estados editoriales, descargas, favoritos o estadísticas. Para que la información siga siendo interpretable sin color:

- Cada serie combina color con nombre visible y, cuando sea posible, símbolo, patrón de trazo o forma de marcador.
- Las leyendas repiten el mismo símbolo o patrón de la serie, no solo una muestra cromática.
- Los hitos de progreso y los valores destacados tienen etiqueta o anotación accesible.
- Los ejes y límites necesarios usan `ControlBorder`; las rejillas prescindibles pueden usar `SeparatorDecorative`.
- Leído, pendiente, favorito, descargado, error y advertencia usan `Label` con SF Symbol y texto. El icono no sustituye el texto accesible.
- En `accessibilityDifferentiateWithoutColor`, pueden reforzarse patrones o símbolos, pero la versión base ya debe funcionar sin color.
- Las portadas no deben cargar con el significado exclusivo de un estado. Cualquier insignia superpuesta necesita fondo opaco o composición auditada, texto accesible y una segunda señal que no dependa del color.

## Implementación nativa en iOS 27

### Asset Catalog

La paleta se materializa mediante un `.colorset` universal por cada uno de los 29 nombres semánticos. Cada entrada usa espacio `sRGB`, componentes del HEX final y `alpha = 1.0`.

| Apariencia de esta especificación | Traits del color set |
|---|---|
| Light estándar | Entrada `Any Appearance`, que actúa como Light en el contexto soportado y como fallback. |
| Dark estándar | `luminosity = dark`. |
| Increased Contrast Light | `contrast = high`. |
| Increased Contrast Dark | `luminosity = dark` + `contrast = high`. |

La elección Light/Dark e Increased Contrast es ortogonal. No existe una única tercera paleta «High Contrast».

Xcode 27 genera `ColorResource` y extensiones de `SwiftUI.Color`, que la app usa directamente sin wrapper manual. La generación se limita al framework SwiftUI mediante `ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOL_FRAMEWORKS = SwiftUI`: el rol normativo `Link` coincide con `UIColor.link`, por lo que generar también extensiones UIKit produciría un conflicto de símbolos. La limitación no renombra assets ni desactiva los recursos tipados.

Manga Library no usa un color set `AccentColor`. Las configuraciones Debug y Release del target declaran `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = BrandPrimary`, evitando que `actool` busque el placeholder retirado. `MainShellView` establece además el tint global de SwiftUI con `.tint(Color(.brandPrimary))`, de modo que `BrandPrimary` es el único origen de la identidad cromática y conserva sus cuatro variantes.

Asset Catalog empaqueta las variantes y UIKit/SwiftUI seleccionan en runtime la combinación correspondiente a los traits. Esa selección no calcula ni garantiza contraste. `@Environment(\.colorSchemeContrast)` solo debe utilizarse si la estructura necesita un refuerzo adicional; no para anular la preferencia del usuario.

En iOS 27, un estilo nativo puede añadir materiales o tratamientos propios para enabled, pressed, focused y disabled. Hay que auditar cada estado renderizado; `TextDisabled` solo conserva su ratio cuando se controla realmente el color final, y no impide que un estilo atenúe el control completo.

### Estados de interacción

- Priorizar `Button`, `Toggle`, `Picker`, `TextField` y estilos nativos para conservar estados y accesibilidad de plataforma.
- Si se crea un estado pressed personalizado, recalcular el par final; no aplicar una opacidad arbitraria sobre `BrandPrimary`.
- Para disabled, mantener el texto legible con `TextDisabled` cuando el estilo lo permita, desactivar realmente el control y explicar la causa cuando no sea evidente. WCAG exime el componente inactivo, pero la política de producto busca conservar legibilidad; verificar cualquier atenuación aplicada por el estilo nativo.
- El foco visible usa `FocusRing` y una geometría perceptible; el color no compensa un anillo demasiado fino o recortado.
- Como referencia interna derivada de WCAG web, [SC 2.4.13 Focus Appearance](https://www.w3.org/TR/WCAG22/#focus-appearance) exige además un área equivalente a un perímetro de 2 CSS px y un cambio `≥ 3:1` entre los mismos píxeles en los estados focused y unfocused. La matriz de esta paleta solo demuestra contraste adyacente de color; no demuestra por sí sola ese cambio, el área ni el grosor, y WCAG2ICT y WCAG2Mobile no orientan sobre AAA.
- Los enlaces usan `Link` más subrayado, icono, convención textual o contexto inequívoco.

### Transparencia y materiales

Los tokens de esta especificación son opacos. Si la interfaz incorpora materiales o Liquid Glass:

1. Componer el foreground sobre todos los fondos reales posibles.
2. Auditar los píxeles resultantes, incluidos estados scroll y contenido cambiante.
3. Proporcionar un fallback opaco cuando Reduce Transparency esté activo.
4. Volver a validar con Dark Mode e Increased Contrast combinados.

No puede reutilizarse el ratio de un token opaco para afirmar que una composición translúcida cumple.

### sRGB y Display P3

Los tokens funcionales se entregan en sRGB para maximizar reproducibilidad. Display P3 puede reservarse para ilustración o arte no crítico. Si se añade una variante P3 funcional, debe tener fallback sRGB y una auditoría independiente; el clipping no conserva necesariamente contraste ni diferenciación.

## Contrato de validación

Swift Testing automatiza:

1. Inventario exacto de assets semánticos.
2. Resolución no nula bajo cuatro `UITraitCollection`: Light, Dark, Light + High Contrast y Dark + High Contrast.
3. Espacio sRGB y `alpha = 1` para todos los tokens funcionales.
4. Coincidencia de componentes con `library-color-tokens.json`.
5. Expansión de las `56` parejas por apariencia y comparación sin redondeo previo.
6. Umbral `4.5` para todo texto estándar, `7.0` para todo texto Increased Contrast, `3.0` para UI estándar y `4.5` como política UI Increased Contrast.
7. Ausencia de `AccentColor` tanto en el inventario fuente como en el bundle compilado.

El gate de implementación verifica por separado y registra en
[`Progress.md`](../Progress.md):

- `BrandPrimary` como color global de Debug y Release, el argumento efectivo de
  `actool` y el `tint` directo de `MainShellView`;
- ausencia de colores RGB/HEX de marca hardcodeados en producción fuera del
  catálogo.

Una prueba de assets no demuestra el contraste real de composiciones con opacidad, imágenes o materiales; esas rutas requieren pruebas específicas.

## Validación manual antes de cerrar la UI

- Light y Dark por separado.
- Increase Contrast combinado con Light y Dark.
- Reduce Transparency combinado con las cuatro apariencias.
- Bold Text combinado con Light, Dark e Increased Contrast.
- Escenario conjunto exigente: activar simultáneamente Bold Text + Increase Contrast + Reduce Transparency y evaluar la experiencia completa tanto en Light como en Dark.
- Differentiate Without Color y escala de grises.
- Todas las variantes de Dynamic Type, incluida la familia Accessibility.
- VoiceOver: etiquetas, orden, valor y estado; el color nunca se anuncia como único significado.
- Switch Control, acceso por teclado y foco visible cuando sean aplicables.
- Controles con el tamaño predeterminado recomendado de `44 × 44 pt` en iOS y iPadOS y nunca por debajo del mínimo Apple de `28 × 28 pt`, con separación suficiente; no confundir tamaño táctil con contraste.
- Accessibility Inspector como ayuda, sin sustituir la fórmula W3C ni la revisión humana.
- Dispositivo físico además de Simulator para brillo, legibilidad, OLED y materiales.
- Cada gráfica o estadística de lectura con leyenda, símbolos/patrones y alternativa accesible.

## Autoridad y evolución

- Este Markdown es la especificación humana del sistema cromático de Manga Library.
- [`library-color-tokens.json`](library-color-tokens.json) es la autoridad exacta y auditable de versión, valores, roles, modos, umbrales y parejas.
- Los dos archivos forman una sola revisión: cualquier cambio de versión, HEX, OKLCH, rol, umbral o pareja autorizada debe actualizar ambos y repetir la validación completa.
- Los color sets versionados son una implementación del JSON, no una fuente alternativa. Cualquier cambio futuro debe conservar la unidad RED/GREEN y repetir la evidencia de las cuatro apariencias.
- La procedencia coordinada con ScienceLibrary no crea una invariante entre repositorios. Cualquier cambio allí requiere alcance, revisión y entrega propios.

## Referencias oficiales

Consultadas el 25 de agosto de 2026:

- [W3C — WCAG 2.2](https://www.w3.org/TR/WCAG22/)
- [W3C — SC 1.4.1 Use of Color](https://www.w3.org/TR/WCAG22/#use-of-color)
- [W3C — SC 1.4.3 Contrast (Minimum)](https://www.w3.org/TR/WCAG22/#contrast-minimum)
- [W3C — SC 1.4.6 Contrast (Enhanced)](https://www.w3.org/TR/WCAG22/#contrast-enhanced)
- [W3C — SC 1.4.11 Non-text Contrast](https://www.w3.org/TR/WCAG22/#non-text-contrast)
- [W3C — SC 2.4.13 Focus Appearance](https://www.w3.org/TR/WCAG22/#focus-appearance)
- [W3C — WCAG2ICT Group Note](https://www.w3.org/TR/wcag2ict-22/)
- [W3C — WCAG2Mobile 2.2 Group Draft Note](https://www.w3.org/TR/wcag2mobile-22/)
- [W3C — CSS Color Module Level 4](https://www.w3.org/TR/css-color-4/)
- [Apple HIG — Color](https://developer.apple.com/design/human-interface-guidelines/color)
- [Apple HIG — Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [Apple HIG — Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode)
- [Apple — Sufficient Contrast evaluation criteria](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/sufficient-contrast-evaluation-criteria)
- [Apple — Specifying your app's color scheme](https://developer.apple.com/documentation/xcode/specifying-your-apps-color-scheme)
- [Apple — Testing system accessibility features in your app](https://developer.apple.com/documentation/accessibility/testing-system-accessibility-features-in-your-app)
- [SwiftUI — `ColorSchemeContrast`](https://developer.apple.com/documentation/swiftui/colorschemecontrast)
- [SwiftUI — `accessibilityDifferentiateWithoutColor`](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilitydifferentiatewithoutcolor)
- [SwiftUI — `accessibilityReduceTransparency`](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducetransparency)

APCA no participa en el resultado de aprobado/suspenso: no ofrece una equivalencia normativa AA/AAA para WCAG 2.2.
