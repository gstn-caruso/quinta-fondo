# Quinta Fondo

Juego de carreras 3D hecho en Godot, con conducción arcade, carreras urbanas y
persecuciones como dirección de diseño. El repositorio empieza con una escena
base; la conducción y el mundo abierto todavía están pendientes.

- Usar Godot 4.7.2 estándar y GDScript. Mantener la versión sincronizada con
  `release-config.json` y la documentación.
- Mantener identificadores técnicos en inglés y documentación en español.
- Usar traducciones nativas CSV y `tr()`. Detectar español o inglés desde el
  sistema operativo, con español como fallback. No añadir un selector de idioma
  ni guardar una preferencia de idioma sin que se solicite.
- Trabajar en ramas `feature/<nombre>` y abrir PRs hacia `main` con títulos
  Conventional Commits. Integrar mediante squash.
- Ejecutar los controles relevantes: `python3 -m unittest discover -s tools
  -p 'test_*.py'` y `GODOT=godot python3 tools/check.py`.
- Cada integración en `main` publica una versión SemVer, empezando por 0.1.0,
  con paquetes Linux amd64 y Windows x86_64 una vez verificados.
- Conservar archivos `.uid`, `.import` y `.translation` de origen. Excluir
  `.godot/`, compilaciones, credenciales y partidas guardadas de Git.
- Conservar licencias de terceros en `licenses/` y actualizar
  `THIRD_PARTY_NOTICES.md` al incorporar dependencias o recursos.
