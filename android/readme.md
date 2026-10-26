# App Android - Pokémon Battle PvP (MVP)

App en Kotlin + Jetpack Compose que se conecta al servidor de `pokemon-server` siguiendo `contratoApp.md`.

## Abrir y correr

1. En Android Studio: **File → Open** y elegir esta carpeta `android/`.
2. Esperar el Gradle sync y darle **Run** (emulador o celular).

Desde terminal (con el JDK de Android Studio):

```bash
./gradlew assembleDebug
```

El APK queda en `app/build/outputs/apk/debug/app-debug.apk`.

## Conectar al servidor

- En la primera pantalla escribe la **IP** de la compu donde corre el servidor (ej. `172.22.41.221`); la app usa `http://{ip}:3000`.
- El celular y la compu deben estar en la **misma red WiFi**.
- En el **emulador**, la compu es `10.0.2.2`.
- La IP se puede cambiar después desde el Lobby ("Cambiar IP del servidor").

## Flujo

Onboarding (IP + nombre) → Lobby → Crear sala / Unirse con código → Sala de espera (polling cada 2 s) →
Elegir 3 Pokémon en orden → Confirmar equipo → Listo → Batalla (polling cada 1.5 s, elegir movimiento) → Resultado.

Se guardan en `SharedPreferences`: `serverUrl`, `playerName`, `playerId`, `roomCode` y `role`.
Si cierras la app a mitad de partida, en el Lobby aparece "Volver a la sala".

## Visuales y sonido (sin archivos en el repo)

Todo se carga en tiempo real desde URLs:

- **Sprites animados** (frente y espalda) de Showdown vía PokeAPI; si no existen, sprite estático.
- **Artwork oficial** en las cartas de selección y en la pantalla de resultado.
- **Gritos de los Pokémon** desde `PokeAPI/cries`.
- **Nombres de movimientos en español** desde `pokeapi.co/api/v2/move/{id}` (se guardan en caché).
- **Fuentes pixel** (Press Start 2P y Pixelify Sans) desde el repo de Google Fonts, guardadas en el dispositivo.
- Efectos de sonido (golpes, desmayo, Poké Ball, victoria) **sintetizados en código**.
- Fondos, plataformas, Poké Balls, barras de PS y efectos de ataque **dibujados en código**.

La batalla usa un "director" (`ui/battle/BattleDirector.kt`) que convierte cada respuesta del
servidor en una cola de animaciones (intro VS, lanzar Poké Ball, ataque, daño, desmayo, cambio de
combate, final) y las reproduce en orden.

Cambios sugeridos al servidor para que las animaciones sean exactas: ver `backend-requests.md`.

## Estructura

- `data/PokeApi.kt` — endpoints con Retrofit + manejo de errores de red.
- `data/Models.kt` — JSON del contrato (+ campos opcionales propuestos).
- `data/Prefs.kt` — datos guardados localmente.
- `data/MoveNames.kt` — nombres de movimientos en español.
- `GameViewModel.kt` — estado, navegación y polling.
- `audio/Sound.kt` — efectos sintetizados y gritos.
- `ui/theme/` — paleta DS, fuentes, colores por tipo, URLs de sprites.
- `ui/components/` — paneles, botones, Poké Ball, barra de PS, sprites pixel.
- `ui/battle/` — escena, director de animaciones, efectos por tipo y cartas.
- `ui/` — resto de pantallas (Compose).
