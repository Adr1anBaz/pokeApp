package com.ibero.pokeapp.ui

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.sp
import com.ibero.pokeapp.GameViewModel

@Composable
fun OnboardingScreen(vm: GameViewModel, modifier: Modifier = Modifier) {
    // Show the saved IP without the http:// and :3000 parts when coming back to change it.
    var ip by rememberSaveable {
        mutableStateOf(vm.serverUrl?.removePrefix("http://")?.removeSuffix(":3000") ?: "")
    }
    var name by rememberSaveable { mutableStateOf(vm.playerName) }

    if (vm.serverUrl != null) BackHandler { vm.backToLobby() }

    ScreenColumn(modifier) {
        Text("Pokémon Battle PvP", style = MaterialTheme.typography.headlineMedium)
        Text("Escribe la IP de la computadora donde corre el servidor. Ambos dispositivos deben estar en la misma red WiFi.")
        OutlinedTextField(
            value = ip,
            onValueChange = { ip = it },
            label = { Text("IP del servidor") },
            placeholder = { Text("172.22.41.221") },
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri),
            modifier = Modifier.fillMaxWidth(),
        )
        GameViewModel.normalizeServerUrl(ip)?.let {
            Text("Se usará: $it", style = MaterialTheme.typography.bodySmall)
        }
        OutlinedTextField(
            value = name,
            onValueChange = { name = it },
            label = { Text("Tu nombre") },
            singleLine = true,
            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words),
            modifier = Modifier.fillMaxWidth(),
        )
        ErrorText(vm.error)
        Button(
            onClick = { vm.saveServer(ip, name) },
            enabled = !vm.loading,
            modifier = Modifier.fillMaxWidth(),
        ) { Text(if (vm.loading) "Probando conexión…" else "Continuar") }
        if (vm.connectionFailed) {
            OutlinedButton(
                onClick = { vm.saveServer(ip, name, skipCheck = true) },
                enabled = !vm.loading,
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Guardar de todos modos") }
        }
    }
}

@Composable
fun LobbyScreen(vm: GameViewModel, modifier: Modifier = Modifier) {
    ScreenColumn(modifier) {
        Text("Lobby", style = MaterialTheme.typography.headlineMedium)
        OutlinedTextField(
            value = vm.playerName,
            onValueChange = vm::updateName,
            label = { Text("Tu nombre") },
            singleLine = true,
            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words),
            modifier = Modifier.fillMaxWidth(),
        )
        ErrorText(vm.error)
        Button(
            onClick = vm::createRoom,
            enabled = !vm.loading,
            modifier = Modifier.fillMaxWidth(),
        ) { Text("Crear Sala") }
        Button(
            onClick = vm::openJoin,
            enabled = !vm.loading,
            modifier = Modifier.fillMaxWidth(),
        ) { Text("Unirse a Sala") }
        vm.roomCode?.let { code ->
            OutlinedButton(onClick = vm::resumeRoom, modifier = Modifier.fillMaxWidth()) {
                Text("Volver a la sala $code")
            }
        }
        HorizontalDivider()
        Text("Servidor: ${vm.serverUrl}", style = MaterialTheme.typography.bodySmall)
        TextButton(onClick = vm::changeServer) { Text("Cambiar IP del servidor") }
    }
}

@Composable
fun JoinScreen(vm: GameViewModel, modifier: Modifier = Modifier) {
    var code by rememberSaveable { mutableStateOf("") }
    BackHandler { vm.backToLobby() }

    ScreenColumn(modifier) {
        Text("Unirse a Sala", style = MaterialTheme.typography.headlineMedium)
        Text("Jugando como: ${vm.playerName}")
        OutlinedTextField(
            value = code,
            onValueChange = { code = it.uppercase().filter(Char::isLetter).take(4) },
            label = { Text("Código de sala") },
            placeholder = { Text("ABCD") },
            singleLine = true,
            textStyle = MaterialTheme.typography.headlineSmall,
            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Characters),
            modifier = Modifier.fillMaxWidth(),
        )
        ErrorText(vm.error)
        Button(
            onClick = { vm.joinRoom(code) },
            enabled = !vm.loading && code.length == 4,
            modifier = Modifier.fillMaxWidth(),
        ) { Text(if (vm.loading) "Uniéndose…" else "Unirse") }
        TextButton(onClick = vm::backToLobby) { Text("Cancelar") }
    }
}

@Composable
fun WaitingRoomScreen(vm: GameViewModel, modifier: Modifier = Modifier) {
    val room = vm.room
    ScreenColumn(modifier) {
        Text("Código de sala", style = MaterialTheme.typography.titleMedium)
        Text(
            vm.roomCode ?: "",
            fontSize = 64.sp,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth(),
        )
        Text("Compártelo con el otro jugador.", textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
        HorizontalDivider()
        Text("Estado: ${statusLabel(room?.status)}")
        PlayerList(vm)
        ErrorText(vm.error)
        TextButton(onClick = vm::leaveRoom) { Text("Salir de la sala") }
    }
}

@Composable
fun PlayerList(vm: GameViewModel) {
    val players = vm.room?.players.orEmpty()
    Column {
        Text("Jugadores (${players.size}/2)", style = MaterialTheme.typography.titleMedium)
        players.forEach { p ->
            val you = if (p.playerId == vm.playerId) " (tú)" else ""
            val state = when {
                p.ready -> "listo ✅"
                p.hasTeam -> "equipo elegido"
                else -> "no listo"
            }
            Text("• ${p.name}$you — $state")
        }
    }
}
