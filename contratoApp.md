# Contrato API - Práctica Integradora 2
**Pokémon Battle PvP**

Base URL: `http://<IP-local>:3000` (misma red)

---

## 1. Crear sala
**POST** `/room`

**Request:**
```json
{
  "playerName": "Adrian"
}
```

**Response:**
```json
{
  "roomCode": "ABCD",
  "playerId": "p1-uuid",
  "role": "host"
}
```

---

## 2. Unirse a sala
**POST** `/room/join`

**Request:**
```json
{
  "roomCode": "ABCD",
  "playerName": "Amiga"
}
```

**Response:**
```json
{
  "roomCode": "ABCD",
  "playerId": "p2-uuid",
  "role": "guest",
  "hostName": "Adrian"
}
```

---

## 3. Estado de la sala
**GET** `/room/{roomCode}`

**Response:**
```json
{
  "roomCode": "ABCD",
  "status": "waiting | selecting | ready | battle | finished",
  "players": [
    {
      "playerId": "p1-uuid",
      "name": "Adrian",
      "ready": false,
      "hasTeam": false
    },
    {
      "playerId": "p2-uuid",
      "name": "Amiga",
      "ready": false,
      "hasTeam": false
    }
  ]
}
```

---

## 4. Obtener 10 Pokémon aleatorios
**GET** `/room/{roomCode}/pokemon`

**Headers:**
```
playerId: p1-uuid
```

**Response:**
```json
{
  "pokemon": [
    {
      "id": 25,
      "name": "pikachu",
      "sprite": "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/25.png",
      "types": ["electric"],
      "stats": {
        "hp": 35,
        "attack": 55,
        "defense": 40,
        "special-attack": 50,
        "special-defense": 50,
        "speed": 90
      }
    }
  ]
}
```

---

## 5. Enviar equipo (3 Pokémon + orden)
**POST** `/room/{roomCode}/team`

**Request:**
```json
{
  "playerId": "p1-uuid",
  "team": [
    { "pokemonId": 25, "order": 1 },
    { "pokemonId": 6, "order": 2 },
    { "pokemonId": 1, "order": 3 }
  ]
}
```

**Response:**
```json
{
  "success": true
}
```

---

## 6. Marcar listo
**POST** `/room/{roomCode}/ready`

**Request:**
```json
{
  "playerId": "p1-uuid"
}
```

---

## 7. Estado de batalla
**GET** `/room/{roomCode}/battle`

**Response:**
```json
{
  "battleNumber": 1,
  "status": "waiting_moves | resolving | finished",
  "currentPokemon": {
    "player1": {
      "pokemonId": 25,
      "name": "pikachu",
      "hp": 35,
      "maxHp": 35,
      "moves": [
        {
          "id": 85,
          "name": "thunderbolt",
          "power": 90,
          "accuracy": 100,
          "type": "electric",
          "damageClass": "special"
        }
      ]
    },
    "player2": {
      "pokemonId": 6,
      "name": "charizard",
      "hp": 78,
      "maxHp": 78,
      "moves": []
    }
  },
  "score": {
    "player1": 0,
    "player2": 0
  },
  "winner": null
}
```

---

## 8. Elegir movimiento (turno)
**POST** `/room/{roomCode}/battle/move`

**Request:**
```json
{
  "playerId": "p1-uuid",
  "moveId": 85
}
```

**Response:**
```json
{
  "accepted": true,
  "waitingForOpponent": true
}
```

---

## 9. Resultado del turno
**GET** `/room/{roomCode}/battle` (mismo endpoint)

Cuando ambos jugadores hayan elegido movimiento:

```json
{
  "lastTurn": {
    "player1Move": "thunderbolt",
    "player2Move": "tackle",
    "damageToPlayer1": 12,
    "damageToPlayer2": 28,
    "logs": [
      "Pikachu used Thunderbolt",
      "It was super effective!",
      "Charmander took 28 damage"
    ]
  },
  "currentPokemon": {
    "player1": { "hp": 23 },
    "player2": { "hp": 50 }
  },
  "battleFinished": false,
  "matchFinished": false
}
```

---

## 10. Rendirse (abandonar la batalla)
**POST** `/room/{roomCode}/battle/forfeit`

**Request:**
```json
{
  "playerId": "p1-uuid"
}
```

**Response:**
```json
{
  "success": true,
  "winner": "Amiga"
}
```

El jugador que se rinde pierde la partida completa. La sala pasa a `status: "finished"` y
`GET /room/{roomCode}/battle` devuelve el ganador y quién se rindió:

```json
{
  "status": "finished",
  "winner": "Amiga",
  "forfeitedBy": "player1"
}
```

`forfeitedBy` es `null` si la partida terminó normalmente. Después de rendirse ya no se aceptan
movimientos (`400 "La partida ya terminó"`).

---

## Notas importantes

- Guardar `playerId` y `roomCode` localmente en cada app.
- Hacer **polling** a `/room/{code}` y `/room/{code}/battle` cada 1–2 segundos.
- Cuando `status === "battle"` y ambos estén listos, mostrar las cartas de moves.
- El **servidor** calcula daño, tipos, accuracy y HP.
- Las apps solo muestran la información y envían las acciones.
- Flujo: Crear/Unirse → Recibir 10 Pokémon → Elegir 3 + orden → Listo → Batalla (3 combates, gana el que gane 2).

---

**Versión:** 1.0  
**Fecha:** 2026-10-26
