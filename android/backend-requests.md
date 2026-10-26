# Cambios sugeridos al servidor (para las animaciones de batalla)

La app de Android **ya funciona con el servidor actual**. Estos cambios hacen que las animaciones
sean exactas. Todos son **campos nuevos opcionales**: si el servidor no los manda, la app usa su
propio cálculo, así que no rompen nada (ni a iOS).

## 1. `turnNumber` y no borrar el último turno al cambiar de combate (el más importante)

Hoy, 2 segundos después del KO, `startNextBattle` reemplaza `room.battle` y `lastTurn` vuelve a `null`.
Si la app hace polling justo en ese momento, **nunca ve el turno del KO** y no puede animarlo
(la app lo deduce del marcador, pero se pierde qué movimiento y cuánto daño hizo).

Propuesta en `lastTurn`:

```json
"lastTurn": {
  "turnNumber": 7,        // contador global del match, solo sube
  "battleNumber": 2,      // combate al que pertenece este turno
  ...
}
```

Y en `startNextBattle`, **conservar** el `lastTurn` anterior en vez de ponerlo en `null`
(como trae `battleNumber`, la app sabe que es del combate anterior).

## 2. Quién ataca primero: `firstAttacker`

```json
"lastTurn": { "firstAttacker": "player1", ... }
```

Calculado por `speed` (empate: al azar o player1). Idealmente, si el primero deja KO al segundo,
el segundo **no ataca** (como en los juegos) y su daño es 0.
Sin este campo la app ordena por velocidad solo de forma visual.

## 3. Fallos y efectividad

```json
"lastTurn": {
  "player1Missed": false,
  "player2Missed": true,
  "player1Effectiveness": 2,     // multiplicador del ataque de player1 contra player2
  "player2Effectiveness": 0.5
}
```

Bug relacionado en `calculateDamage`: cuando el ataque falla, `damage = 0` pero luego
`return Math.max(1, damage)` lo convierte en 1. **Un fallo debería hacer 0 de daño.**

Si se agrega `player1Effectiveness`/`player2Effectiveness`, se puede ampliar la tabla de tipos
(y usar ambos tipos del defensor) sin que la app muestre mensajes incorrectos.

## 4. Bug: empate cuando ambos quedan en 0 HP

En `resolveTurn`: `const winnerIndex = p1.hp > 0 ? 0 : 1;`
Si **los dos** quedan en 0, siempre gana player2. Opciones:
- Con `firstAttacker` (punto 2) no pasa, porque el segundo no ataca si ya cayó.
- O decidir por velocidad / repetir el combate.

## Resumen de campos nuevos (todos opcionales)

| Campo (en `lastTurn`) | Tipo | Ejemplo |
|---|---|---|
| `turnNumber` | int | `7` |
| `battleNumber` | int | `2` |
| `firstAttacker` | `"player1"` \| `"player2"` | `"player1"` |
| `player1Missed`, `player2Missed` | bool | `false` |
| `player1Effectiveness`, `player2Effectiveness` | number | `2`, `0.5`, `1` |
