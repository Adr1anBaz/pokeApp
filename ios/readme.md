
# App iOS

El proyecto Xcode está en `ios/PokeApp.xcodeproj`. Los archivos SwiftUI están en `ios/PokeApp/`:

- `PokeApp.swift`: punto de entrada y navegación inicial.
- `AppConfig.swift`: guarda la URL del servidor en `UserDefaults`.
- `OnboardingView.swift`: solicita la IP la primera vez.
- `LobbyView.swift`: permite crear o unirse a una sala.
- `WaitingRoomView.swift`: consulta el estado de la sala cada 2 segundos.
- `TeamSelectionView.swift`: muestra imágenes, tipos y estadísticas para elegir 3 Pokémon.
- `BattleView.swift`: muestra HP, movimientos, turnos y ganador.
- `ResultView.swift`: muestra el resultado y el historial reciente.
- `RoomActions.swift`: permite salir de una sala sin borrar la sesión del otro jugador.

Para ejecutarlo:

1. Abre `ios/PokeApp.xcodeproj` en Xcode.
2. En **Signing & Capabilities**, selecciona tu Apple ID/team y cambia el Bundle Identifier si es necesario.
3. Selecciona tu iPhone como destino y pulsa **Run**.
4. En el onboarding escribe la IP local del Mac que ejecuta el servidor, por ejemplo `172.22.41.221`.

La URL, el nombre, el `playerId` y el código de sala se guardan en `UserDefaults`.
