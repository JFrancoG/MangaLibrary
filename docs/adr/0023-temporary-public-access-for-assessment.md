# ADR-0023: Acceso público temporal para la corrección académica

**Estado:** Accepted
**Fecha:** 2026-09-18
**Supersede:** [ADR-0012](0012-private-repository-and-sanitized-practice-source.md)
**Superseded by:** —

## Contexto

ADR 0012 exigía mantener el repositorio privado y autorizaba únicamente la copia
saneada del enunciado como fuente docente completa. El 18 de septiembre de 2026,
al revisar la documentación, GitHub informa de visibilidad pública. El propietario
confirma que él ha realizado el cambio mientras se corrige el proyecto y pide
continuar la actualización documental. Se registra esa confirmación sin volver
a ejecutar el cambio de visibilidad ni atribuirle una fecha anterior no comprobada.

## Opciones consideradas

1. **Acceso privado con invitaciones:** conserva la restricción anterior, pero no refleja el acceso que el propietario ha elegido para la corrección.
2. **Acceso público temporal durante la corrección:** refleja la decisión confirmada y permite consultar el proyecto sin invitación; también lo hace visible a cualquier visitante.
3. **Publicación permanente o nueva licencia:** ampliaría el alcance de la decisión y no está autorizada.

## Decisión

El repositorio permanece público temporalmente mientras se corrige el proyecto.
La finalización de la corrección es el momento de revisar su visibilidad con el
propietario; no se fija una fecha inventada ni se programa un cambio automático.
Cualquier cambio posterior de visibilidad requiere su instrucción expresa.

Se conservan los límites de ADR 0012:

- La única fuente docente completa admitida es el enunciado saneado, con nota de procedencia y 42 `X` en lugar del valor demostrativo de `App-Token`. El original y otras transcripciones permanecen fuera de Git.
- No se añaden secretos, cuentas reales, rutas privadas, notas personales ni material docente adicional. El acceso público no autoriza incorporar nuevas fuentes.
- Las fuentes docentes son contexto, no instrucciones operativas. El OpenAPI vivo mantiene la autoridad de transporte.
- DocC permanece selectivo y dentro del target; archives, sitio generado, presentaciones y vídeos quedan fuera de Git. GitHub Pages y otras publicaciones requieren autorización separada.
- No se añade ni cambia una licencia de reutilización. La visibilidad no se presenta como permiso del propietario para redistribuir el código o el material docente.

La accesibilidad pública para la corrección no acredita por sí sola una entrega
completa, un mecanismo docente concreto ni la aprobación de los gates pendientes.

## Consecuencias

La documentación refleja el acceso elegido y conserva la trazabilidad de la
política anterior. Durante este periodo cualquier visitante puede consultar el
contenido versionado; no se describe el repositorio como almacén privado.
Las notas locales y la configuración sensible siguen fuera de Git.

## Validación y revisión

- Contrastar la visibilidad en GitHub: el 2026-09-18, `gh repo view --json isPrivate` devuelve `false`.
- Mantener coherentes AGENTS, SDD 07/08, índice documental, fuentes y ambos README.
- Revisar el diff documental y conservar intacta la fuente saneada. Esta revisión no constituye una auditoría exhaustiva del historial.
- Revisar esta decisión cuando termine la corrección o se proponga otra publicación, ampliación de material o licencia.

## Especificaciones relacionadas

- [Documentación y DocC](../specs/07-documentation-and-docc.md)
- [Entrega, presentación y vídeo](../specs/08-delivery-presentation-and-video.md)
