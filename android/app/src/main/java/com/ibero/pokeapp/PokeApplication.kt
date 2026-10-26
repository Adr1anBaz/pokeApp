package com.ibero.pokeapp

import android.app.Application
import android.os.Build
import coil.ImageLoader
import coil.ImageLoaderFactory
import coil.decode.GifDecoder
import coil.decode.ImageDecoderDecoder
import com.ibero.pokeapp.audio.Sound
import com.ibero.pokeapp.ui.theme.PixelFonts

class PokeApplication : Application(), ImageLoaderFactory {
    override fun onCreate() {
        super.onCreate()
        PixelFonts.load(this)
        Sound.init(this)
    }

    // Battle sprites are animated GIFs (Showdown sprites from PokeAPI).
    override fun newImageLoader(): ImageLoader = ImageLoader.Builder(this)
        .components {
            if (Build.VERSION.SDK_INT >= 28) add(ImageDecoderDecoder.Factory()) else add(GifDecoder.Factory())
        }
        .crossfade(false)
        .build()
}
