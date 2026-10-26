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

## Estructura

- `data/PokeApi.kt` — endpoints con Retrofit + manejo de errores de red.
- `data/Models.kt` — JSON del contrato.
- `data/Prefs.kt` — datos guardados localmente.
- `GameViewModel.kt` — estado, navegación y polling.
- `ui/` — pantallas (Compose). Sprites con Coil.
