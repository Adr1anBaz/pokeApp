package com.ibero.pokeapp.ui.theme

import android.content.Context
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.io.File
import java.net.URL

/** DS-era palette. */
object Ds {
    val Ink = Color(0xFF283038)
    val InkSoft = Color(0xFF5A6470)
    val Paper = Color(0xFFF8F8F8)
    val Frame = Color(0xFF4A5560)
    val Red = Color(0xFFE3350D)
    val RedDark = Color(0xFF9E2A0C)
    val Blue = Color(0xFF3B6FD8)
    val BlueDark = Color(0xFF22408A)
    val Yellow = Color(0xFFFFCB05)
    val YellowDark = Color(0xFFC79A00)
    val Green = Color(0xFF3FA34D)
    val GreenDark = Color(0xFF256B30)
    val HpGreen = Color(0xFF38D058)
    val HpYellow = Color(0xFFF8C800)
    val HpRed = Color(0xFFF03030)
    val SkyTop = Color(0xFF7FD8F0)
    val SkyBottom = Color(0xFFD8F8E0)
    val Grass = Color(0xFF78C850)
    val GrassDark = Color(0xFF4E9A32)
}

/**
 * Pixel fonts are fetched once from Google Fonts' GitHub repo into the app's files dir,
 * so nothing is bundled in the repo. Until they arrive the UI uses monospace.
 */
object PixelFonts {
    private const val BASE = "https://raw.githubusercontent.com/google/fonts/main/ofl"
    var title by mutableStateOf<FontFamily>(FontFamily.Monospace)
        private set
    var body by mutableStateOf<FontFamily>(FontFamily.Monospace)
        private set

    fun load(context: Context) {
        CoroutineScope(SupervisorJob() + Dispatchers.IO).launch {
            fetch(context, "PressStart2P.ttf", "$BASE/pressstart2p/PressStart2P-Regular.ttf")?.let {
                title = FontFamily(Font(it))
            }
            fetch(context, "PixelifySans.ttf", "$BASE/pixelifysans/PixelifySans%5Bwght%5D.ttf")?.let {
                body = FontFamily(Font(it))
            }
        }
    }

    private fun fetch(context: Context, name: String, url: String): File? {
        val file = File(context.filesDir, "fonts/$name")
        if (file.exists() && file.length() > 0) return file
        return runCatching {
            file.parentFile?.mkdirs()
            val tmp = File(file.path + ".part")
            URL(url).openStream().use { input -> tmp.outputStream().use { input.copyTo(it) } }
            tmp.renameTo(file)
            file
        }.getOrNull()
    }
}

@Composable
fun PokeTheme(content: @Composable () -> Unit) {
    val body = PixelFonts.body
    val title = PixelFonts.title
    val typography = Typography(
        displayLarge = TextStyle(fontFamily = title, fontSize = 30.sp, lineHeight = 38.sp),
        headlineLarge = TextStyle(fontFamily = title, fontSize = 22.sp, lineHeight = 30.sp),
        headlineMedium = TextStyle(fontFamily = title, fontSize = 18.sp, lineHeight = 26.sp),
        headlineSmall = TextStyle(fontFamily = title, fontSize = 14.sp, lineHeight = 20.sp),
        titleLarge = TextStyle(fontFamily = body, fontSize = 24.sp, lineHeight = 28.sp),
        titleMedium = TextStyle(fontFamily = body, fontSize = 20.sp, lineHeight = 24.sp),
        titleSmall = TextStyle(fontFamily = body, fontSize = 17.sp, lineHeight = 20.sp),
        bodyLarge = TextStyle(fontFamily = body, fontSize = 20.sp, lineHeight = 26.sp),
        bodyMedium = TextStyle(fontFamily = body, fontSize = 17.sp, lineHeight = 22.sp),
        bodySmall = TextStyle(fontFamily = body, fontSize = 14.sp, lineHeight = 18.sp),
        labelLarge = TextStyle(fontFamily = body, fontSize = 18.sp, lineHeight = 22.sp),
        labelMedium = TextStyle(fontFamily = body, fontSize = 15.sp, lineHeight = 18.sp),
        labelSmall = TextStyle(fontFamily = body, fontSize = 12.sp, lineHeight = 14.sp),
    )
    MaterialTheme(
        colorScheme = lightColorScheme(
            primary = Ds.Red,
            onPrimary = Color.White,
            secondary = Ds.Blue,
            background = Ds.Paper,
            surface = Ds.Paper,
            onSurface = Ds.Ink,
            onBackground = Ds.Ink,
            error = Ds.Red,
        ),
        typography = typography,
        content = content,
    )
}
