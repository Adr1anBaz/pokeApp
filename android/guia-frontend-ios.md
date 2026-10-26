# Guía de Front-end para iOS — Pokémon Battle PvP

Todo lo visual y de experiencia que se hizo en la app de Android, con los **valores exactos**
(colores, URLs, tiempos, posiciones, textos) para replicarlo en iOS y que ambas apps se vean igual.

Código de referencia (Kotlin/Compose) en `android/app/src/main/java/com/ibero/pokeapp/`.
Los nombres de archivo se mencionan en cada sección.

---

## 0. Reglas generales

- **Nada de assets en el repo.** Sprites, artwork, íconos de tipo, gritos, nombres de movimientos
  y fuentes se cargan desde URLs en tiempo de ejecución. Fondos, plataformas, Poké Balls, barras
  de PS y efectos de ataque se **dibujan con código**. Los efectos de sonido se **sintetizan**.
- Estética: **escena de batalla estilo Pokémon DS** + **movimientos como cartas estilo Card-Jitsu**
  (Club Penguin).
- Todo el texto de la UI está en **español**.
- La lógica de red es la del contrato (`contratoApp.md`): polling de sala cada **2 s**, polling de
  batalla cada **1 s** (1 s para no perder el turno del KO; ver sección 7).

---

## 1. Fuentes (pixel)

Se descargan una vez y se guardan en el dispositivo (Android: `ui/theme/Theme.kt`).

| Uso | Fuente | URL |
|---|---|---|
| Títulos, botones, números grandes | Press Start 2P | `https://raw.githubusercontent.com/google/fonts/main/ofl/pressstart2p/PressStart2P-Regular.ttf` |
| Texto normal, diálogos | Pixelify Sans | `https://raw.githubusercontent.com/google/fonts/main/ofl/pixelifysans/PixelifySans%5Bwght%5D.ttf` |

Mientras no carguen, usar monospace.
**iOS:** descargar el `.ttf`, guardarlo en `Application Support` y registrarlo con
`CTFontManagerRegisterGraphicsFont` (con `CGDataProvider` + `CGFont`); luego `Font.custom(nombre, size:)`.

Tamaños usados (sp ≈ pt):

| Estilo | Fuente | Tamaño |
|---|---|---|
| displayLarge (logo, VS) | Press Start 2P | 30 (logo 40/34, VS 64) |
| headlineMedium | Press Start 2P | 18 |
| headlineSmall (botones, títulos de panel) | Press Start 2P | 14 |
| titleLarge (diálogo de batalla) | Pixelify Sans | 24 |
| titleMedium | Pixelify Sans | 20 |
| titleSmall | Pixelify Sans | 17 |
| bodyMedium | Pixelify Sans | 17 |
| bodySmall | Pixelify Sans | 14 |
| labelMedium | Pixelify Sans | 15 |
| labelSmall | Pixelify Sans | 12 |

---

## 2. Paleta

### Colores base ("Ds")

| Nombre | Hex | Uso |
|---|---|---|
| Ink | `#283038` | texto, bordes oscuros, fondo de batalla |
| InkSoft | `#5A6470` | texto secundario |
| Paper | `#F8F8F8` | fondo de paneles |
| Frame | `#4A5560` | marco exterior de paneles |
| Red / RedDark | `#E3350D` / `#9E2A0C` | botón principal |
| Blue / BlueDark | `#3B6FD8` / `#22408A` | botón secundario, contorno del logo |
| Yellow / YellowDark | `#FFCB05` / `#C79A00` | logo, selección, acentos |
| Green / GreenDark | `#3FA34D` / `#256B30` | "listo", efectivo |
| HpGreen / HpYellow / HpRed | `#38D058` / `#F8C800` / `#F03030` | barra de PS |
| SkyTop / SkyBottom | `#7FD8F0` / `#D8F8E0` | cielo de la batalla |
| Grass / GrassDark | `#78C850` / `#4E9A32` | plataformas |

### Colores por tipo (`ui/theme/Types.kt`)

| tipo (API) | Nombre ES | color | oscuro |
|---|---|---|---|
| normal | Normal | `#A8A878` | `#6D6D4E` |
| fire | Fuego | `#F08030` | `#9C531F` |
| water | Agua | `#6890F0` | `#445E9C` |
| electric | Eléctrico | `#F8D030` | `#A1871F` |
| grass | Planta | `#78C850` | `#4E8234` |
| ice | Hielo | `#98D8D8` | `#638D8D` |
| fighting | Lucha | `#C03028` | `#7D1F1A` |
| poison | Veneno | `#A040A0` | `#682A68` |
| ground | Tierra | `#E0C068` | `#927D44` |
| flying | Volador | `#A890F0` | `#6D5E9C` |
| psychic | Psíquico | `#F85888` | `#A13959` |
| bug | Bicho | `#A8B820` | `#6D7815` |
| rock | Roca | `#B8A038` | `#786824` |
| ghost | Fantasma | `#705898` | `#493963` |
| dragon | Dragón | `#7038F8` | `#4924A1` |
| dark | Siniestro | `#705848` | `#49392F` |
| steel | Acero | `#B8B8D0` | `#787887` |
| fairy | Hada | `#EE99AC` | `#9B6470` |

---

## 3. URLs de assets (PokeAPI)

Base sprites: `https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon`

| Qué | URL | Notas |
|---|---|---|
| Sprite animado frente (rival) | `{base}/other/showdown/{id}.gif` | GIF animado |
| Sprite animado espalda (tuyo) | `{base}/other/showdown/back/{id}.gif` | GIF animado |
| Fallback frente | `{base}/{id}.png` | si el GIF da 404 (p. ej. #1010) |
| Fallback espalda | `{base}/back/{id}.png` | |
| Artwork oficial | `{base}/other/official-artwork/{id}.png` | cartas de selección, VS, resultado |
| Símbolo de tipo (sin texto) | `https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/types/generation-ix/scarlet-violet/small/{typeId}.png` | 60×60 |
| Grito | `https://raw.githubusercontent.com/PokeAPI/cries/main/cries/pokemon/latest/{id}.ogg` | **OGG — ver nota iOS** |
| Nombre de movimiento | `https://pokeapi.co/api/v2/move/{moveId}` → `names[]` | usar `es-419`, si no `es`, si no el nombre en inglés formateado |

`typeId`: normal 1, fighting 2, flying 3, poison 4, ground 5, rock 6, bug 7, ghost 8, steel 9,
fire 10, water 11, grass 12, electric 13, psychic 14, ice 15, dragon 16, dark 17, fairy 18.

**Notas iOS:**
- `AsyncImage` de SwiftUI **no anima GIFs**. Usar una librería (p. ej. SDWebImageSwiftUI `AnimatedImage`
  o Kingfisher `KFAnimatedImage`).
- Los sprites son pixel art: dibujar con **interpolación nearest** (`.interpolation(.none)`).
- **iOS no reproduce OGG de forma nativa.** Alternativa en MP3 (probada que responde):
  `https://play.pokemonshowdown.com/audio/cries/{nombre}.mp3` — nombre en minúsculas sin guiones ni
  símbolos (`pikachu`, `charizard`, `mrmime`). Para formas del API como `deoxys-normal`, usar la
  especie base (`deoxys`). Si falla, simplemente no sonar.
- Nombres de movimientos: cachear (memoria + `UserDefaults`) para pedir cada uno una sola vez.

**Tamaño real de los sprites:** los GIFs tienen tamaños distintos por Pokémon. **No** escalarlos a un
cuadro fijo (Pikachu quedaría igual de grande que Wailord). Se dibujan a su tamaño original × un factor:
- rival (frente): `factor = anchoEscena / 215`
- tuyo (espalda): `factor = anchoEscena / 270` (los sprites de espalda de Showdown son más grandes)

(en píxeles; en iOS: `anchoEscenaEnPuntos * escalaPantalla / 215`, o equivalente en puntos).

---

## 4. Componentes reutilizables (`ui/components/Components.kt`)

- **Fondo con rayas:** gradiente vertical + líneas diagonales blancas al 10% de opacidad, separación
  48 pt, grosor 45% de la separación, se desplazan en bucle (6 s). **Recortar al contenedor**
  (que no se metan en la barra de estado). Colores por pantalla:
  lobby/onboarding `#E85040→#F8A040`, unirse `BlueDark→Blue`, sala de espera `#3050B0→#58A8E8`,
  selección `#305878→#58A0C8`, victoria `#F8B820→#F87830`, derrota `#384058→#586078`.
- **Panel DS:** borde 3 pt `Frame` (radio 12) → 3 pt de espacio → borde 3 pt de acento (radio 9) →
  fondo `Paper`, padding 14.
- **Botón pixel:** cara de color con gradiente leve, "canto" inferior oscuro de 5 pt que baja a 1 pt
  al presionar, borde blanco 35%, radio 12, texto blanco Press Start 2P 14. Suena `Select` (o `Confirm`).
  Deshabilitado: `#B8B8B8` / `#888888`.
- **Texto con contorno (logo):** dibujar el texto con trazo grueso (10–14 px) en un color y encima el
  relleno. Logo: "POKé" / "BATTLE" amarillo con contorno `BlueDark`, chip "PvP".
- **Poké Ball dibujada:** círculo blanco, mitad superior roja (gris si "debilitado"), contorno Ink
  16% del radio, línea central, botón central (Ink 36% del radio + blanco 22%). Puede girar.
- **Barra de PS:** alto 12, fondo Ink, interior `#506058`, relleno con color según %:
  `> 50%` verde, `> 20%` amarillo, si no rojo. El valor es **float** para animarlo.
- **Badge de tipo:** fondo color del tipo, borde oscuro del tipo, símbolo de tipo 14 pt + nombre en
  español en mayúsculas.

---

## 5. Pantallas

### 5.1 Onboarding
Logo (Poké Ball 64 pt que flota ±6 pt y rota, ciclo 1.1 s), panel "¡Bienvenido, Entrenador!",
campo IP (muestra debajo `▶ http://{ip}:3000`), campo nombre (máx 12), botón **CONTINUAR**
(hace `GET /` para probar). Si falla: mensaje de error + botón **GUARDAR IGUAL**.

### 5.2 Lobby
Logo, panel "ENTRENADOR" con el nombre editable, botones **CREAR SALA** (rojo), **UNIRSE A SALA**
(azul), **VOLVER A SALA {código}** (verde, si hay sala guardada). Abajo: servidor actual,
chip **CAMBIAR IP**, chip 🔊/🔇 (silenciar, se guarda).

### 5.3 Unirse
Título "UNIRSE", 4 casillas de letra (ver 5.4), campo de código (solo letras, mayúsculas, máx 4),
**¡ENTRAR!** (activo con 4 letras), **CANCELAR**.

### 5.4 Sala de espera
- "CÓDIGO DE SALA" + **4 casillas** 58×70 pt, fondo Ink, borde amarillo 3 pt, letra amarilla
  grande. Aparecen una por una (150 ms de diferencia) con escala 0→1 tipo resorte con rebote.
- Panel "ENTRENADORES n/2" con filas que entran deslizándose desde la derecha: Poké Ball, nombre
  (+ "(tú)"), "Anfitrión"/"Retador", chip de estado: **¡LISTO!** verde / **EQUIPO OK** azul /
  **ELIGIENDO** gris.
- Con 1 jugador: Poké Ball girando + "Esperando rival…".
- Cuando entra el rival: sonido `Join`, texto verde "¡Rival encontrado! Preparando equipos…" y
  **esperar 1.8 s** antes de pasar a selección (para que se vea el momento).

### 5.5 Selección de equipo (draft de cartas)
- Header oscuro: "ELIGE TU EQUIPO", "Sala {código} · Toca 3 cartas en orden de batalla", chip con el
  estado del rival.
- Cargando: Poké Ball girando 64 pt + "Abriendo sobres…" + "(puede tardar unos segundos)".
- **Grid de 2 columnas de cartas** (estilo carta coleccionable):
  - marco del color oscuro del tipo (amarillo si está elegida, más grueso), radio 14/11
  - fondo gradiente: color del tipo → 70% → blanco
  - fila: nombre + "PS {hp}" en rojo oscuro
  - ventana con el **artwork oficial** (fondo radial blanco → color del tipo 35%)
  - **número de orden (1/2/3) en un círculo rojo con borde blanco en la esquina superior izquierda
    de la ventana del artwork** (no encima del nombre)
  - badges de tipo
  - barras ATQ (rojo), DEF (azul), VEL (verde), escala sobre 160
- **Animación de reparto:** cada carta entra con 70 ms de retraso × índice: escala 0.6→1,
  sube 120 px, rotación ±8°→0, resorte con rebote. Elegida: sube 14 px y escala +4%.
- Al elegir una carta: suena su **grito**.
- **Bandeja inferior** (panel con acento rojo): 3 casillas con el sprite animado pequeño de cada
  elegido (o una Poké Ball gris si está vacía); tocar una casilla la quita.
  Botón: **CONFIRMAR EQUIPO (n/3)** → luego **¡LISTO PARA PELEAR!** (verde) → luego Poké Ball girando
  + "Esperando a {rival}…" / "¡Que empiece la batalla!".
  Cambiar la selección después de confirmar obliga a confirmar otra vez. Tras "listo" se bloquea.

### 5.6 Resultado
- Victoria: fondo dorado, **confeti** (60 rectángulos de colores cayendo y girando), 🏆, "¡VICTORIA!"
  amarillo con contorno rojo oscuro, sonido `Victory`.
- Derrota: fondo gris azulado, 💫, "DERROTA" blanco con contorno Ink, sonido `Defeat`.
- El ícono y el título entran con escala tipo resorte.
- Panel: "Ganador: {nombre}", "{tú} X - Y {rival}", "Tu equipo" con los 3 artworks.
- Botón **VOLVER AL INICIO** (borra la sala guardada).

---

## 6. Pantalla de batalla (`ui/battle/`)

Layout vertical, fondo Ink:

1. **Barra superior:** 3 Poké Balls tuyas (grises = las que ya perdiste) + tu nombre ·
   "COMBATE n/3" amarillo · nombre del rival + sus 3 Poké Balls · 🔊.
2. **Escena** (ancho completo, proporción **1.15 : 1**, recortada).
3. **Caja de diálogo** (panel DS, acento rojo, alto 92 pt, texto 24).
4. **Mano de cartas** (ocupa el resto).

### 6.1 Escena (posiciones en fracción de ancho/alto)

- Cielo: gradiente `SkyTop→SkyBottom` hasta el 56% del alto. 5 nubes/líneas blancas (45%) en
  y = 0.08, 0.17, 0.27, 0.36, 0.45 con largo 0.5, 0.3, 0.6, 0.25, 0.45 del ancho, alto 2.2%,
  desplazándose en bucle (5 s).
- Campo: gradiente `#A8E080→#70B850` del 56% al 100%, con 6 franjas blancas al 6%.
- **Plataforma rival:** óvalo centro (0.70, 0.51), tamaño 0.48 × 0.11.
  **Plataforma tuya:** centro (0.27, 0.97), tamaño 0.64 × 0.14.
  Cada una: óvalo `GrassDark` desplazado 12% abajo, óvalo `Grass`, óvalo interior `#A0E070`
  (76%×60%), y 9 "matas" triangulares `GrassDark` en el borde superior.
- **Sprites:** el punto **inferior-central** del sprite se coloca en: rival (0.70, 0.52),
  tuyo (0.27, 0.99). Vaivén idle de 3 pt (0.9 s tuyo / 1.1 s rival).
- **Caja PS rival:** arriba-izquierda, 56% del ancho: nombre, puntos de color de sus tipos,
  "PS" + barra, y sus Poké Balls.
- **Caja PS tuya:** a la derecha, top = 60% del alto, 54% del ancho: nombre, tipos, barra y
  **"{ps} / {máx}"** (el número baja junto con la barra).
  Las cajas entran deslizándose cuando su Pokémon aparece.

### 6.2 Mensajes del diálogo

Texto que se escribe **letra por letra (22 ms por letra)**; cuando termina y hay más animaciones,
una flecha ▼ roja parpadea abajo a la derecha. Textos (en orden de aparición):

| Momento | Texto |
|---|---|
| Inicio | `¡{rival} te desafía!` |
| Rival saca | `¡{rival} envió a {Pokémon}!` |
| Tú sacas | `¡Adelante, {Pokémon}!` |
| Tu turno | `¿Qué hará {Pokémon}?` |
| Esperando | `Esperando a {rival}…` |
| Ataque tuyo | `¡{Pokémon} usó {Movimiento}!` |
| Ataque rival | `¡{Pokémon} rival usó {Movimiento}!` |
| Fallo | `¡Pero falló!` |
| Efectividad | `¡Es súper eficaz!` / `No es muy eficaz…` |
| Debilitado | `¡{Pokémon} se debilitó!` / `¡{Pokémon} rival se debilitó!` |
| Retirar | `¡{Pokémon}, vuelve!` / `¡{rival} retiró a {Pokémon}!` |
| Nuevo combate | `¡Combate {n}!` |
| Entre combates | `Preparando el siguiente combate…` |
| Fin | `¡Derrotaste a {rival}!` / `¡{rival} te ha derrotado!` |

Nombres de Pokémon: `prettyName` = separar por `-` y capitalizar cada palabra.

### 6.3 Animaciones (tiempos exactos)

- **Intro VS:** pantalla dividida en diagonal (arriba azul `Blue→BlueDark`, abajo `RedDark→Red`,
  línea blanca de 8 pt de (0, 58%) a (100%, 42%)). Rival + su artwork entran desde la derecha
  (arriba), tú desde la izquierda (abajo), "VS" gigante escala 0→1.1 y rota −40°→0.
  700 ms entrando, 1300 ms quieto, luego **flash blanco** (opacidad 1→0 en 450 ms). Sonido `Join`.
- **Sacar Pokémon:** Poké Ball en arco (parábola, altura 30% de la escena, girando 720°) desde fuera
  de pantalla — tuyo desde (−0.05, 0.90), rival desde (1.05, 0.05) — hasta la plataforma, 520 ms,
  sonido `Throw`. Al llegar: sonido `BallOpen`, flash blanco 35%, el sprite aparece **teñido de
  blanco** con escala 0→1 (320 ms, origen abajo-centro), se quita el tinte, suena su **grito**,
  pausa 650 ms.
- **Ataque:** embestida del atacante 6% del ancho y 4% del alto hacia el rival (110 ms) y regreso
  (220 ms); sonido `Card`; **efecto del tipo** (700 ms físico, 950 ms especial; los especiales
  lanzan primero un proyectil en arco del color del tipo).
- **Golpe:** sonido `Hit` / `SuperHit` / `WeakHit` según efectividad, **vibración** (fuerte si es
  súper eficaz), parpadeo del defensor (3 veces: 70 ms invisible / 70 ms visible), sacudida
  horizontal ±1.5% (4 × 50 ms). Súper eficaz: además sacude toda la escena ±10 pt.
- **Barra de PS:** baja linealmente hasta el valor **exacto del servidor**,
  duración = `daño × 22 ms` (mínimo 250, máximo 1300).
- **Debilitado:** grito con **pitch 0.75**, 300 ms, sonido `Faint`, el sprite baja 25% del alto y
  se desvanece (450 ms), se marca su Poké Ball como gris, mensaje.
- **Retirar (entre combates):** tinte rojo `#FF5050` y escala →0 (300 ms), sonido `BallOpen`.
- **Fin:** pausa 300 ms, sonido Victory/Defeat, mensaje 1.6 s, y **solo entonces** ir a la
  pantalla de resultado.

### 6.4 Efectos por tipo (`ui/battle/Effects.kt`)

Dibujados con canvas sobre el centro del defensor; `u = anchoEscena / 10`; 18 partículas con
parámetros aleatorios fijos (semilla por ataque, para que no "tiemblen" entre frames).

| Tipos | Patrón |
|---|---|
| fire, dragon | **Llamas:** círculos que suben y se encogen, núcleo amarillo `#FFE070` |
| water, poison | **Burbujas:** círculos que se alejan en todas direcciones con borde blanco |
| electric | **Rayos:** 3 zigzags (6 segmentos) desde arriba, parpadeando, trazo blanco + color |
| grass | **Hojas:** óvalos girando en espiral hacia afuera |
| ice | **Cristales:** rombos blancos con borde del color, explotando hacia afuera |
| psychic | **Anillos:** 4 círculos concéntricos que se expanden escalonados |
| ghost, dark | **Sombra:** círculo oscuro `#201030` + partículas que convergen |
| rock, ground | **Rocas:** 9 cuadrados que caen desde arriba girando |
| flying | **Viento:** 5 arcos blancos barriendo de izquierda a derecha |
| bug | **Enjambre:** puntos orbitando |
| fairy | **Destellos:** estrellitas de cruz que titilan |
| normal, fighting, steel, otros | **Impacto:** 10 líneas radiales blancas + destello central |

### 6.5 Cartas de movimiento (`ui/battle/MoveCards.kt`)

- **Grid 2×2** (no slider: con 4 opciones es mejor verlas todas). Separación 10 pt; alto de carta =
  `min((altoDisponible − 26 − 20) / 2, 165)`. Arriba: "▼ Elige un ataque ▼" en amarillo
  (o "Esperando la jugada del rival…").
- Fondo de la zona: gradiente `#3A4450 → Ink`.
- **Carta** (mismo estilo que las cartas de Pokémon): radio 14, fondo gradiente color del tipo →
  oscuro del tipo, borde blanco 35%, padding 5.
  - **Pestaña izquierda tipo Card-Jitsu** (58 pt de ancho, sobre el marco): símbolo de tipo 38 pt
    (radio 10, borde blanco 2), **potencia grande** (Press Start 2P, 23 pt; 18 si ≥ 100) blanca con
    sombra Ink desplazada 5 px hacia abajo, y "POTENCIA" (9 pt).
  - **Ventana derecha** (radio 10, gradiente blanco → `#F4F0E4` → color del tipo 25%):
    nombre del movimiento en español (20, negrita, máx 2 líneas) · badge de tipo ·
    fila con chip de clase **FÍSICO** `#C05030` / **ESPECIAL** `#5060C0` / **ESTADO** InkSoft
    + chip de efectividad · barra "PREC." con `{precisión}%`.
  - **Chip de efectividad** contra el Pokémon rival actual: `¡EFICAZ!` (verde) si ×2,
    `POCO EFICAZ` (gris) si ×0.5, nada si ×1. Se calcula con **la misma tabla que el servidor**
    (ver 7.4) para que coincida con el daño real.
- **Animaciones de la mano:**
  - Repartir: al poder elegir, las cartas suben a su lugar con 60 ms × índice de retraso (280 ms).
  - Bajadas (mientras se anima el turno): bajan 18 pt, escala 0.96, opacidad 55%, no se pueden tocar.
  - **Jugar una carta:** sonido `Card`, la carta vuela 240 pt hacia arriba, escala +12%, rota 8° y se
    desvanece (380 ms); luego se envía el movimiento.
  - Esperando al rival: 4 **cartas boca abajo** (gradiente rojo, borde amarillo, Poké Ball 46 pt
    al centro) que se mecen (±1.5°, ±3 pt, 700 ms, desfasadas 120 ms).
- Solo se puede jugar si: no hay animaciones pendientes, `status == "waiting_moves"`, no hay
  ganador, no estás esperando al rival y el combate mostrado es el actual.

---

## 7. Lógica del "director" de batalla (`ui/battle/BattleDirector.kt`) — importante

El polling trae estados nuevos cada segundo, pero las animaciones tardan varios segundos. Por eso
**no se dibuja directo el estado del servidor**: se compara cada respuesta con la anterior, se
generan **eventos** y se reproducen **en cola, uno por uno**.

### 7.1 Eventos
`Intro`, `Turn(turno, hp1Final, hp2Final)`, `Faint(lado)`, `NextBattle(estado)`, `End(ganaste)`.

### 7.2 Al recibir un estado
Se mantiene un "modelo" de cómo quedará la pantalla cuando termine la cola
(`combate`, `hp1`, `hp2`, `marcador`, `últimoTurnoVisto`).

1. Primer estado → `Intro`. Guardar el turno actual como "visto" (no repetir un turno viejo al
   reanudar). Si ya hay ganador → `End`.
2. **Turno nuevo:** clave = `turnNumber` si el servidor lo manda; si no,
   `combate|movP1|movP2|dañoP1|dañoP2|hpP1|hpP2`. Si la clave cambió y el turno es del combate que
   se muestra → `Turn` con los PS finales del servidor.
3. **Cambió `battleNumber`:** si ninguno de los dos quedó en 0 (nos perdimos el turno del KO
   porque el servidor cambia de combate 2 s después) → `Faint` del perdedor, **deducido por
   quién subió en el marcador**. Luego `NextBattle`.
4. **Hay `winner`:** igual, si nadie quedó en 0 → `Faint` del perdedor; luego `End`. Dejar de
   hacer polling.

### 7.3 Reproducir un turno
- Lado: el anfitrión es `player1`, el invitado `player2`.
- Orden: `firstAttacker` si existe; si no, **el de mayor velocidad** (`stats.speed`; empate → player1).
- **Ajuste visual:** el servidor actual aplica los dos ataques a la vez, así que el más lento ataca
  aunque el rápido lo haya dejado en 0. Si no viene `firstAttacker` y el segundo atacante termina en
  0 PS y aun así hizo daño, **se invierte el orden** (para no mostrar un Pokémon atacando con 0 PS).
- Para cada ataque: mensaje → embestida + efecto → si `missed` "¡Pero falló!", si no golpe + barra
  hasta el PS final del servidor + mensaje de efectividad.
- Al final se fijan los PS exactos del servidor y se reproducen los desmayos.
- Entre combates el servidor cambia **a los dos** Pokémon: el que sigue vivo se **retira**
  y luego se lanzan los dos nuevos (primero el rival).

### 7.4 Efectividad (igual que `calculateDamage` del servidor)
Solo con el **primer tipo del defensor**:

| Ataque | ×2 contra | ×0.5 contra |
|---|---|---|
| fire | grass | water, fire |
| water | fire | grass, water |
| grass | water | fire, grass |
| electric | water | grass, electric |

Todo lo demás ×1. Si el servidor manda `player1Effectiveness` / `player2Effectiveness`, usar eso.

### 7.5 Campos opcionales del servidor
La app ya lee estos campos de `lastTurn` si existen (ver `android/backend-requests.md`):
`turnNumber`, `battleNumber`, `firstAttacker`, `player1Missed`, `player2Missed`,
`player1Effectiveness`, `player2Effectiveness`. Además usa `stats` y `types` de
`currentPokemon.player1/player2` (el servidor ya los manda aunque no estén en el contrato).

---

## 8. Sonido (`audio/Sound.kt`)

- Botón 🔊/🔇 global; se guarda la preferencia.
- **Gritos:** al elegir carta, al salir a batalla, y al debilitarse (pitch 0.75), volumen 0.6.
- **Efectos sintetizados** (22050 Hz, mono, PCM 16 bit). "tono" = onda cuadrada con barrido de
  frecuencia y envolvente decreciente; "ruido" = ruido blanco (muestreado cada 3 muestras) con caída
  exponencial; "seno" = barrido senoidal.

| Sonido | Receta |
|---|---|
| Select | tono 1320 Hz, 45 ms, vol 0.25 |
| Confirm | tono 880 Hz 60 ms + tono 1320 Hz 90 ms (vol 0.25) |
| Card | ruido 60 ms (0.25) + tono 660→990 Hz 70 ms (0.2) |
| Hit | ruido 140 ms (0.6) + tono 180→90 Hz 60 ms (0.3) |
| SuperHit | ruido 90 ms (0.7), silencio 20 ms, ruido 180 ms (0.8), tono 220→70 Hz 90 ms |
| WeakHit | ruido 90 ms (0.3, caída rápida) |
| Miss | seno 900→300 Hz 220 ms |
| Faint | tono 700→110 Hz 650 ms (ciclo 25%) |
| Throw | seno 300→1200 Hz 260 ms |
| BallOpen | ruido 50 ms + tono 523→1568 Hz 160 ms (ciclo 25%) |
| Join | 784, 988 Hz (80 ms c/u) + 1175 Hz 160 ms |
| Victory | 523, 659, 784, 1047 Hz (110 ms c/u), pausa 40 ms, 784 (110), 1047 (380) — ciclo 25% |
| Defeat | 659, 587, 523, 392 Hz (200 ms c/u, vol 0.3, ciclo 25%) |

**iOS:** generar los buffers con `AVAudioPCMBuffer` y reproducir con `AVAudioEngine` +
`AVAudioPlayerNode` (o crear un WAV en memoria y usar `AVAudioPlayer`). Vibración:
`UIImpactFeedbackGenerator(style: .heavy)` en súper eficaz, `.light` en golpe normal.

---

## 9. Otros detalles de experiencia

- Transición entre pantallas: fundido (fade).
- Guardar localmente: `serverUrl`, `playerName`, `playerId`, `roomCode` y `role`. Si hay sala
  guardada, el Lobby muestra **VOLVER A SALA** y al entrar la app va directo a la pantalla correcta
  según el estado (`battle`/`finished` → batalla).
- Errores de red: banner rojo oscuro con borde blanco; en polling, "Sin conexión con el servidor,
  reintentando…". Si la sala ya no existe (404) → volver al Lobby con "La sala ya no existe en el servidor".
- Al terminar la partida, la pantalla de batalla deja de hacer polling.
