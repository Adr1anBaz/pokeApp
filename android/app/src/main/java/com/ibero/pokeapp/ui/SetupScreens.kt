package com.ibero.pokeapp.ui

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInHorizontally
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.ibero.pokeapp.GameViewModel
import com.ibero.pokeapp.audio.Sfx
import com.ibero.pokeapp.audio.Sound
import com.ibero.pokeapp.data.PlayerInfo
import com.ibero.pokeapp.ui.components.DsPanel
import com.ibero.pokeapp.ui.components.ErrorBanner
import com.ibero.pokeapp.ui.components.OutlinedText
import com.ibero.pokeapp.ui.components.PixelButton
import com.ibero.pokeapp.ui.components.Pokeball
import com.ibero.pokeapp.ui.components.SpinningPokeball
import com.ibero.pokeapp.ui.components.StripedBackground
import com.ibero.pokeapp.ui.theme.Ds

/** Scrollable column on the striped backdrop, shared by the menu screens. */
@Composable
fun MenuScreen(
    modifier: Modifier = Modifier,
    top: Color = Color(0xFFE85040),
    bottom: Color = Color(0xFFF8A040),
    content: @Composable ColumnScope.() -> Unit,
) {
    StripedBackground(modifier, top, bottom) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .imePadding()
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            content = content,
        )
    }
}

@Composable
fun GameLogo(modifier: Modifier = Modifier) {
    val bob by rememberInfiniteTransition(label = "logo").animateFloat(
        -6f, 6f, infiniteRepeatable(tween(1100), RepeatMode.Reverse), label = "bob",
    )
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        Pokeball(Modifier.graphicsLayer { translationY = bob * density; rotationZ = bob * 2 }, size = 64.dp)
        Spacer(Modifier.height(10.dp))
        OutlinedText("POKé", MaterialTheme.typography.displayLarge.copy(fontSize = 40.sp, lineHeight = 46.sp), outlineWidth = 14f)
        OutlinedText("BATTLE", MaterialTheme.typography.displayLarge.copy(fontSize = 34.sp, lineHeight = 42.sp), outlineWidth = 14f)
        Text(
            "PvP",
            style = MaterialTheme.typography.headlineSmall,
            color = Color.White,
            modifier = Modifier
                .padding(top = 6.dp)
                .clip(RoundedCornerShape(6.dp))
                .background(Ds.BlueDark)
                .padding(horizontal = 10.dp, vertical = 4.dp),
        )
    }
}

@Composable
private fun DsTextField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    placeholder: String = "",
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(label) },
        placeholder = { Text(placeholder) },
        singleLine = true,
        textStyle = MaterialTheme.typography.titleMedium,
        keyboardOptions = keyboardOptions,
        colors = OutlinedTextFieldDefaults.colors(
            focusedBorderColor = Ds.Blue,
            unfocusedBorderColor = Ds.Frame,
            focusedLabelColor = Ds.Blue,
            cursorColor = Ds.Blue,
        ),
        modifier = Modifier.fillMaxWidth(),
    )
}

@Composable
fun OnboardingScreen(vm: GameViewModel, modifier: Modifier = Modifier) {
    var ip by rememberSaveable {
        mutableStateOf(vm.serverUrl?.removePrefix("http://")?.removeSuffix(":3000") ?: "")
    }
    var name by rememberSaveable { mutableStateOf(vm.playerName) }
    if (vm.serverUrl != null) BackHandler { vm.backToLobby() }

    MenuScreen(modifier) {
        Spacer(Modifier.height(12.dp))
        GameLogo()
        DsPanel(Modifier.fillMaxWidth()) {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("¡Bienvenido, Entrenador!", style = MaterialTheme.typography.titleLarge, color = Ds.Ink)
                Text(
                    "Escribe la IP de la computadora con el servidor. Ambos deben estar en la misma red WiFi.",
                    style = MaterialTheme.typography.bodyMedium, color = Ds.InkSoft,
                )
                DsTextField(ip, { ip = it }, "IP del servidor", "172.22.41.221", KeyboardOptions(keyboardType = KeyboardType.Uri))
                GameViewModel.normalizeServerUrl(ip)?.let {
                    Text("▶ $it", style = MaterialTheme.typography.bodySmall, color = Ds.InkSoft)
                }
                DsTextField(name, { name = it.take(12) }, "Tu nombre", "Ash", KeyboardOptions(capitalization = KeyboardCapitalization.Words))
            }
        }
        ErrorBanner(vm.error)
        PixelButton(
            if (vm.loading) "CONECTANDO…" else "CONTINUAR",
            onClick = { vm.saveServer(ip, name) },
            enabled = !vm.loading,
            sfx = Sfx.Confirm,
            modifier = Modifier.fillMaxWidth(),
        )
        if (vm.connectionFailed) {
            PixelButton(
                "GUARDAR IGUAL",
                onClick = { vm.saveServer(ip, name, skipCheck = true) },
                enabled = !vm.loading,
                color = Ds.Frame, dark = Ds.Ink,
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}

@Composable
fun LobbyScreen(vm: GameViewModel, modifier: Modifier = Modifier) {
    MenuScreen(modifier) {
        Spacer(Modifier.height(12.dp))
        GameLogo()
        DsPanel(Modifier.fillMaxWidth(), accent = Ds.Red) {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text("ENTRENADOR", style = MaterialTheme.typography.headlineSmall, color = Ds.Red)
                DsTextField(vm.playerName, { vm.updateName(it.take(12)) }, "Tu nombre", keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words))
            }
        }
        ErrorBanner(vm.error)
        PixelButton(
            "CREAR SALA", onClick = vm::createRoom, enabled = !vm.loading, sfx = Sfx.Confirm,
            modifier = Modifier.fillMaxWidth(),
        )
        PixelButton(
            "UNIRSE A SALA", onClick = vm::openJoin, enabled = !vm.loading,
            color = Ds.Blue, dark = Ds.BlueDark, modifier = Modifier.fillMaxWidth(),
        )
        vm.roomCode?.let { code ->
            PixelButton(
                "VOLVER A SALA $code", onClick = vm::resumeRoom,
                color = Ds.Green, dark = Ds.GreenDark, modifier = Modifier.fillMaxWidth(),
            )
        }
        Spacer(Modifier.height(4.dp))
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(
                "Servidor: ${vm.serverUrl}",
                style = MaterialTheme.typography.bodySmall,
                color = Color.White,
                modifier = Modifier.weight(1f),
            )
            SmallChip("CAMBIAR IP", vm::changeServer)
            SmallChip(if (Sound.muted) "🔇" else "🔊", Sound::toggleMute)
        }
    }
}

@Composable
fun SmallChip(text: String, onClick: () -> Unit) {
    PixelButton(
        text, onClick = onClick, color = Ds.Ink.copy(alpha = 0.75f), dark = Ds.Ink,
        textStyle = MaterialTheme.typography.labelMedium,
    )
}

@Composable
fun JoinScreen(vm: GameViewModel, modifier: Modifier = Modifier) {
    var code by rememberSaveable { mutableStateOf("") }
    BackHandler { vm.backToLobby() }

    MenuScreen(modifier, top = Ds.BlueDark, bottom = Ds.Blue) {
        Spacer(Modifier.height(24.dp))
        OutlinedText("UNIRSE", MaterialTheme.typography.displayLarge, outlineWidth = 12f)
        DsPanel(Modifier.fillMaxWidth()) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                Text("Escribe el código de 4 letras", style = MaterialTheme.typography.titleMedium, color = Ds.Ink)
                CodeTiles(code.padEnd(4, ' '), animate = false)
                DsTextField(
                    code, { code = it.uppercase().filter(Char::isLetter).take(4) }, "Código", "ABCD",
                    KeyboardOptions(capitalization = KeyboardCapitalization.Characters),
                )
                Text("Jugando como: ${vm.playerName}", style = MaterialTheme.typography.bodyMedium, color = Ds.InkSoft)
            }
        }
        ErrorBanner(vm.error)
        PixelButton(
            if (vm.loading) "UNIÉNDOSE…" else "¡ENTRAR!",
            onClick = { vm.joinRoom(code) },
            enabled = !vm.loading && code.length == 4,
            sfx = Sfx.Confirm,
            modifier = Modifier.fillMaxWidth(),
        )
        PixelButton("CANCELAR", onClick = vm::backToLobby, color = Ds.Frame, dark = Ds.Ink, modifier = Modifier.fillMaxWidth())
    }
}

/** Room code shown as 4 letter tiles that pop in one by one. */
@Composable
fun CodeTiles(code: String, animate: Boolean = true) {
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        code.forEachIndexed { i, c ->
            val scale = remember { Animatable(if (animate) 0f else 1f) }
            LaunchedEffect(animate) {
                if (animate) {
                    kotlinx.coroutines.delay(150L * i)
                    scale.animateTo(1f, spring(dampingRatio = Spring.DampingRatioMediumBouncy, stiffness = Spring.StiffnessLow))
                }
            }
            Box(
                Modifier
                    .size(58.dp, 70.dp)
                    .graphicsLayer { scaleX = scale.value; scaleY = scale.value }
                    .clip(RoundedCornerShape(10.dp))
                    .background(Ds.Ink)
                    .border(3.dp, Ds.Yellow, RoundedCornerShape(10.dp)),
                contentAlignment = Alignment.Center,
            ) {
                Text(c.toString(), style = MaterialTheme.typography.displayLarge, color = Ds.Yellow)
            }
        }
    }
}

@Composable
fun WaitingRoomScreen(vm: GameViewModel, modifier: Modifier = Modifier) {
    val players = vm.room?.players.orEmpty()
    var lastCount by remember { mutableStateOf(0) }
    LaunchedEffect(players.size) {
        if (players.size > lastCount && lastCount > 0) Sound.play(Sfx.Join)
        lastCount = players.size
    }

    MenuScreen(modifier, top = Color(0xFF3050B0), bottom = Color(0xFF58A8E8)) {
        Spacer(Modifier.height(16.dp))
        Text("CÓDIGO DE SALA", style = MaterialTheme.typography.headlineSmall, color = Color.White)
        CodeTiles(vm.roomCode ?: "????")
        Text(
            "¡Compártelo con tu rival!",
            style = MaterialTheme.typography.titleMedium, color = Color.White, textAlign = TextAlign.Center,
        )
        DsPanel(Modifier.fillMaxWidth(), accent = Ds.Yellow) {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("ENTRENADORES ${players.size}/2", style = MaterialTheme.typography.headlineSmall, color = Ds.Ink)
                players.forEachIndexed { i, p -> TrainerRow(p, isYou = p.playerId == vm.playerId, isHost = i == 0) }
                if (players.size < 2) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        SpinningPokeball(28.dp)
                        Text("Esperando rival…", style = MaterialTheme.typography.titleMedium, color = Ds.InkSoft)
                    }
                } else {
                    Text("¡Rival encontrado! Preparando equipos…", style = MaterialTheme.typography.titleMedium, color = Ds.Green)
                }
            }
        }
        ErrorBanner(vm.error)
        PixelButton("SALIR DE LA SALA", onClick = vm::leaveRoom, color = Ds.Frame, dark = Ds.Ink, modifier = Modifier.fillMaxWidth())
    }
}

@Composable
fun TrainerRow(p: PlayerInfo, isYou: Boolean, isHost: Boolean) {
    var shown by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { shown = true }
    AnimatedVisibility(shown, enter = slideInHorizontally { it } + fadeIn()) {
        Row(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(10.dp))
                .background(if (isHost) Ds.Red.copy(alpha = 0.12f) else Ds.Blue.copy(alpha = 0.12f))
                .padding(10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Pokeball(size = 26.dp)
            Column(Modifier.weight(1f)) {
                Text(p.name + if (isYou) " (tú)" else "", style = MaterialTheme.typography.titleMedium, color = Ds.Ink)
                Text(if (isHost) "Anfitrión" else "Retador", style = MaterialTheme.typography.bodySmall, color = Ds.InkSoft)
            }
            val (label, color) = when {
                p.ready -> "¡LISTO!" to Ds.Green
                p.hasTeam -> "EQUIPO OK" to Ds.Blue
                else -> "ELIGIENDO" to Ds.InkSoft
            }
            Text(
                label, style = MaterialTheme.typography.labelMedium, color = Color.White,
                modifier = Modifier
                    .clip(RoundedCornerShape(6.dp))
                    .background(color)
                    .padding(horizontal = 8.dp, vertical = 2.dp),
            )
        }
    }
}
