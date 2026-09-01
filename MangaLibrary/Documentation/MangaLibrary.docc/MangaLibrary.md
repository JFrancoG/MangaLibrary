# ``MangaLibrary``

Explora un catálogo de manga y gestiona una colección personal con una experiencia local-first.

## Overview

Manga Library reúne el catálogo, la colección y la cuenta en una aplicación para iPhone y iPad. Catálogo carga operaciones públicas tipadas, mantiene estados de presentación y navega por identidades estables con una composición adaptativa.

La sesión dual usa el email y la contraseña Basic solo durante el envío, intercambia refresh por access y resuelve la identidad remota antes de activar una generación local. `SessionPersistenceActor` serializa un único registro Keychain V2 que reúne autoridad y ambos JWT, condiciona refresh y borrado a la generación vigente y nunca permite que un efecto tardío sustituya otra sesión. Logout solo publica el cierre después del borrado; `authenticationRequired` conserva el UUID en memoria, pero no es un estado durable. La Cuenta proyecta únicamente identidad segura.

El alta de Cuenta mantiene su `App-Token` fuera del grafo compartido y confirma `POST /users` únicamente mediante `200` con el entero opaco publicado o el `201 Created` observado en runtime. Una confirmación enlaza una sola vez con el login de sesión existente. Si el request pudo salir sin respuesta concluyente, el workflow conserva la incertidumbre y evita cualquier reintento automático; si el alta se confirmó pero el login no terminó, conserva el hecho «cuenta creada» sin volver a registrar.

El transporte compartido valida cada respuesta HTTP antes de entregar bytes. Los clientes tipados construyen y decodifican fuera del actor principal; los modelos observables poseen las transiciones de presentación, reconcilian cancelación con su fuente de verdad y protegen frente a respuestas tardías. Las Views permanecen declarativas.

La documentación de símbolos y los artículos se incorporan solo junto a contratos reales que necesiten explicar invariantes, efectos, errores, aislamiento o cancelación; no se añaden por cuota.
