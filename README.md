# Quinta Fondo

**Quinta Fondo es un juego de carreras 3D hecho en Godot.**

El proyecto apunta a conducción arcade, carreras urbanas y persecuciones en un
mundo abierto, con identidad y contenido originales.

Código abierto bajo licencia MIT.

## Estado

Base inicial del proyecto: escena de presentación 3D, traducciones español/inglés
y compilaciones automáticas. La conducción, las carreras, el tráfico y las
persecuciones están pendientes de implementación.

## Abrir y ejecutar

Requiere **Godot 4.7.2 estándar**, con GDScript. Se utiliza el renderizador
Compatibility y Jolt Physics.

1. Clonar el repositorio:

   ```sh
   git clone https://github.com/gstn-caruso/quinta-fondo.git
   cd quinta-fondo
   ```

2. Importar `project.godot` desde Godot o ejecutar:

   ```sh
   godot --editor --path .
   ```

3. Presionar **F6** para ejecutar la escena abierta o **F5** para ejecutar el
   proyecto.

El idioma se toma del sistema operativo: español e inglés, con español como
alternativa para otros idiomas. Los textos se mantienen en
`assets/i18n/messages.csv`; se versionan también los catálogos `.translation`.

## Estructura

- `scenes/`: escenas del juego.
- `scripts/`: lógica en GDScript y servicio de idioma.
- `assets/`: icono, traducciones y futuros recursos del juego.
- `tests/`: prueba de arranque de la escena y las traducciones.
- `tools/`: verificación, exportación, empaquetado y publicación.
- `licenses/`: avisos del motor y sus dependencias.

## Desarrollo y verificación

Usar ramas `feature/<nombre>` y PRs hacia `main`. Los títulos de PR siguen
Conventional Commits y se integran mediante squash.

Con Godot disponible como `godot`:

```sh
python3 -m unittest discover -s tools -p 'test_*.py'
GODOT=godot python3 tools/check.py
```

También se puede usar `python3 tools/install_godot.py` para descargar el editor
y las plantillas oficiales fijadas en `release-config.json`. El instalador
verifica los SHA-512 y muestra las rutas de los ejecutables y plantillas.

## Compilaciones y versiones

GitHub Actions verifica cada PR, genera los paquetes e inicia el ejecutable de
Windows en un runner Windows. Cada integración en `main` publica una versión
SemVer después de completar esas verificaciones:

- Primera versión: `0.1.0`.
- Cambios incompatibles (`!` o `BREAKING CHANGE:`): incrementan major.
- `feat`: incrementa minor.
- Otros cambios: incrementan patch.

Las [publicaciones](https://github.com/gstn-caruso/quinta-fondo/releases)
incluyen un instalador Linux amd64 `.deb`, ZIPs portables para Linux y Windows,
un ejecutable Windows x86_64 `.exe` y `SHA256SUMS.txt`. Los ejecutables exportados
no requieren instalar Godot.

La versión del motor, los nombres de las exportaciones y las pruebas están en
`release-config.json`. Los resultados se generan en `build/`, excluido de Git.

## Licencia

El código y los recursos originales del proyecto se distribuyen bajo
[licencia MIT](LICENSE). Los avisos de Godot y de sus dependencias se conservan
en [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) y `licenses/`.
