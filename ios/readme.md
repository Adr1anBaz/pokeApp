# App iOS - Pokémon Battle PvP

Versión SwiftUI que replica **exactamente** la app de Android (`android/`): misma estética DS +
cartas Card-Jitsu, mismos textos, colores, tiempos de animación y lógica de batalla.
Guía de diseño con todos los valores: `android/guia-frontend-ios.md`.

## Ejecutar

1. Abre `ios/PokeApp.xcodeproj` en Xcode.
2. En **Signing & Capabilities**, selecciona tu Apple ID/team y cambia el Bundle Identifier si es necesario.
3. Selecciona tu iPhone (o un simulador) y pulsa **Run**.
4. En la primera pantalla escribe la IP del servidor, por ejemplo `172.22.41.221`
   (la app usa `http://{ip}:3000`). El iPhone y el servidor deben estar en la misma red WiFi.

No usa librerías externas: todo es SwiftUI + frameworks de Apple.

## Archivos (`ios/PokeApp/`)

| Archivo | Qué hace | Equivalente Android |
|---|---|---|
| `PokeApp.swift` | Entrada, pantalla actual con fundido, carga de fuentes | `MainActivity.kt` |
| `GameViewModel.swift` | Estado, navegación, polling, equipo, movimientos, rendirse | `GameViewModel.kt` |
| `API.swift` | Modelos del contrato y llamadas al servidor | `data/PokeApi.kt`, `data/Models.kt` |
| `AppConfig.swift` | Datos guardados (`serverURL`, `playerName`, `playerId`, `roomCode`, `role`) | `data/Prefs.kt` |
| `MoveNames.swift` | Nombres de movimientos en español (PokeAPI, en caché) | `data/MoveNames.kt` |
| `Sound.swift` | Efectos sintetizados + gritos | `audio/Sound.kt` |
| `RemoteFontLoader.swift` | Descarga y registra Press Start 2P y Pixelify Sans | `ui/theme/Theme.kt` |
| `DesignSystem.swift` | Paleta, tipos, URLs, paneles, botones, Poké Ball, barra de PS | `ui/theme/*`, `ui/components/*` |
| `PixelSprite.swift` | Decodifica y anima los GIF de Showdown (ImageIO), pixel nítido | `PixelSprite` en `Components.kt` |
| `OnboardingView.swift`, `LobbyView.swift`, `WaitingRoomView.swift` | Menús, unirse, sala de espera | `ui/SetupScreens.kt` |
| `TeamSelectionView.swift` | Draft de cartas coleccionables + bandeja | `ui/TeamSelectScreen.kt` |
| `BattleDirector.swift` | Convierte el polling en una cola de animaciones | `ui/battle/BattleDirector.kt` |
| `BattleView.swift` | Escena DS, cajas de PS, diálogo, VS, rendirse | `ui/battle/BattleScreen.kt` |
| `Effects.swift` | Efectos de ataque por tipo | `ui/battle/Effects.kt` |
| `MoveCards.swift` | Mano 2×2 de cartas de movimiento | `ui/battle/MoveCards.kt` |
| `ResultView.swift` | Victoria / derrota con confeti | `ui/ResultScreen.kt` |

## Diferencias con Android (por limitaciones de iOS)

- **Gritos:** iOS no reproduce los `.ogg` de PokeAPI; se usan los `.mp3` de Pokémon Showdown
  (`play.pokemonshowdown.com/audio/cries/{nombre}.mp3`). Si un grito no existe, simplemente no suena.
- **GIFs animados:** SwiftUI no los anima, por eso `PixelSprite.swift` decodifica los cuadros con ImageIO.
- "Salir de la sala" además avisa al servidor con `POST /room/{code}/leave`.
- iOS no tiene botón "atrás": para rendirse se usa el botón **RENDIRSE** de la batalla.
