package com.ibero.pokeapp

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import com.ibero.pokeapp.ui.BattleScreen
import com.ibero.pokeapp.ui.JoinScreen
import com.ibero.pokeapp.ui.LobbyScreen
import com.ibero.pokeapp.ui.OnboardingScreen
import com.ibero.pokeapp.ui.ResultScreen
import com.ibero.pokeapp.ui.TeamSelectScreen
import com.ibero.pokeapp.ui.WaitingRoomScreen

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            MaterialTheme {
                PokeApp()
            }
        }
    }
}

@Composable
fun PokeApp(vm: GameViewModel = viewModel()) {
    Scaffold(modifier = Modifier.fillMaxSize()) { padding ->
        val modifier = Modifier.padding(padding)
        when (vm.screen) {
            Screen.Onboarding -> OnboardingScreen(vm, modifier)
            Screen.Lobby -> LobbyScreen(vm, modifier)
            Screen.Join -> JoinScreen(vm, modifier)
            Screen.WaitingRoom -> WaitingRoomScreen(vm, modifier)
            Screen.TeamSelect -> TeamSelectScreen(vm, modifier)
            Screen.Battle -> BattleScreen(vm, modifier)
            Screen.Result -> ResultScreen(vm, modifier)
        }
    }
}
