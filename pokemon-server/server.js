const express = require('express');
const cors = require('cors');
const axios = require('axios');
const { v4: uuidv4 } = require('uuid');

const app = express();
const PORT = 3000;

app.use(cors());
app.use(express.json());

// Almacenamiento en memoria
const rooms = {};

// Generar código de sala de 4 letras
function generateRoomCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  let code = '';
  for (let i = 0; i < 4; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}

// Obtener Pokémon aleatorio de PokeAPI
async function getRandomPokemon() {
  const id = Math.floor(Math.random() * 1010) + 1; // 1-1010
  try {
    const res = await axios.get(`https://pokeapi.co/api/v2/pokemon/${id}`);
    const data = res.data;
    
    const stats = {};
    data.stats.forEach(s => {
      stats[s.stat.name] = s.base_stat;
    });

    // Obtener hasta 4 moves con poder
    const moves = [];
    const moveUrls = data.moves.slice(0, 15); // revisar más para encontrar con power
    
    for (const m of moveUrls) {
      if (moves.length >= 4) break;
      try {
        const moveRes = await axios.get(m.move.url);
        const move = moveRes.data;
        if (move.power && move.power > 0) {
          moves.push({
            id: move.id,
            name: move.name,
            power: move.power,
            accuracy: move.accuracy || 100,
            type: move.type.name,
            damageClass: move.damage_class.name
          });
        }
      } catch (e) {}
    }

    // Si no hay moves con power, poner uno básico
    if (moves.length === 0) {
      moves.push({
        id: 33,
        name: "tackle",
        power: 40,
        accuracy: 100,
        type: "normal",
        damageClass: "physical"
      });
    }

    return {
      id: data.id,
      name: data.name,
      sprite: data.sprites.front_default,
      types: data.types.map(t => t.type.name),
      stats,
      moves
    };
  } catch (err) {
    // Fallback
    return {
      id: 25,
      name: "pikachu",
      sprite: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/25.png",
      types: ["electric"],
      stats: { hp: 35, attack: 55, defense: 40, "special-attack": 50, "special-defense": 50, speed: 90 },
      moves: [{ id: 85, name: "thunderbolt", power: 90, accuracy: 100, type: "electric", damageClass: "special" }]
    };
  }
}

// ========== ENDPOINTS ==========

// 1. Crear sala
app.post('/room', (req, res) => {
  const { playerName } = req.body;
  const roomCode = generateRoomCode();
  const playerId = uuidv4();

  rooms[roomCode] = {
    roomCode,
    status: 'waiting',
    players: [{
      playerId,
      name: playerName || 'Jugador 1',
      ready: false,
      hasTeam: false,
      team: [],
      availablePokemon: []
    }],
    battle: null,
    score: { player1: 0, player2: 0 },
    currentBattle: 1
  };

  res.json({
    roomCode,
    playerId,
    role: 'host'
  });
});

// 2. Unirse a sala
app.post('/room/join', (req, res) => {
  const { roomCode, playerName } = req.body;
  const room = rooms[roomCode?.toUpperCase()];

  if (!room) return res.status(404).json({ error: 'Sala no encontrada' });
  if (room.players.length >= 2) return res.status(400).json({ error: 'Sala llena' });

  const playerId = uuidv4();
  room.players.push({
    playerId,
    name: playerName || 'Jugador 2',
    ready: false,
    hasTeam: false,
    team: [],
    availablePokemon: []
  });

  room.status = 'selecting';

  res.json({
    roomCode: room.roomCode,
    playerId,
    role: 'guest',
    hostName: room.players[0].name
  });
});

// 3. Estado de la sala
app.get('/room/:roomCode', (req, res) => {
  const room = rooms[req.params.roomCode.toUpperCase()];
  if (!room) return res.status(404).json({ error: 'Sala no encontrada' });

  res.json({
    roomCode: room.roomCode,
    status: room.status,
    players: room.players.map(p => ({
      playerId: p.playerId,
      name: p.name,
      ready: p.ready,
      hasTeam: p.hasTeam
    }))
  });
});

// 4. Obtener 10 Pokémon aleatorios
app.get('/room/:roomCode/pokemon', async (req, res) => {
  const room = rooms[req.params.roomCode.toUpperCase()];
  if (!room) return res.status(404).json({ error: 'Sala no encontrada' });

  const playerId = req.headers.playerid;
  const player = room.players.find(p => p.playerId === playerId);
  if (!player) return res.status(400).json({ error: 'Jugador no encontrado' });

  if (player.availablePokemon.length === 0) {
    const promises = Array(10).fill().map(() => getRandomPokemon());
    player.availablePokemon = await Promise.all(promises);
  }

  res.json({ pokemon: player.availablePokemon });
});

// 5. Enviar equipo
app.post('/room/:roomCode/team', (req, res) => {
  const room = rooms[req.params.roomCode.toUpperCase()];
  if (!room) return res.status(404).json({ error: 'Sala no encontrada' });

  const { playerId, team } = req.body;
  const player = room.players.find(p => p.playerId === playerId);
  if (!player) return res.status(400).json({ error: 'Jugador no encontrado' });

  // Validar que los Pokémon estén en los disponibles
  const validTeam = team.map(t => {
    const poke = player.availablePokemon.find(p => p.id === t.pokemonId);
    return poke ? { ...poke, order: t.order } : null;
  }).filter(Boolean);

  if (validTeam.length !== 3) {
    return res.status(400).json({ error: 'Debes elegir 3 Pokémon válidos' });
  }

  validTeam.sort((a, b) => a.order - b.order);
  player.team = validTeam;
  player.hasTeam = true;

  res.json({ success: true });
});

// 6. Marcar listo
app.post('/room/:roomCode/ready', (req, res) => {
  const room = rooms[req.params.roomCode.toUpperCase()];
  if (!room) return res.status(404).json({ error: 'Sala no encontrada' });

  const { playerId } = req.body;
  const player = room.players.find(p => p.playerId === playerId);
  if (!player) return res.status(400).json({ error: 'Jugador no encontrado' });
  if (!player.hasTeam) return res.status(400).json({ error: 'Primero debes elegir equipo' });

  player.ready = true;

  // Si ambos listos, iniciar batalla
  if (room.players.length === 2 && room.players.every(p => p.ready)) {
    room.status = 'battle';
    startBattle(room);
  } else {
    room.status = 'ready';
  }

  res.json({ success: true });
});

function startBattle(room) {
  const p1 = room.players[0];
  const p2 = room.players[1];
  const poke1 = p1.team[0];
  const poke2 = p2.team[0];

  room.battle = {
    battleNumber: room.currentBattle,
    status: 'waiting_moves',
    currentPokemon: {
      player1: {
        pokemonId: poke1.id,
        name: poke1.name,
        hp: poke1.stats.hp,
        maxHp: poke1.stats.hp,
        moves: poke1.moves,
        stats: poke1.stats,
        types: poke1.types
      },
      player2: {
        pokemonId: poke2.id,
        name: poke2.name,
        hp: poke2.stats.hp,
        maxHp: poke2.stats.hp,
        moves: poke2.moves,
        stats: poke2.stats,
        types: poke2.types
      }
    },
    pendingMoves: {},
    lastTurn: null
  };
}

// 7. Estado de batalla
app.get('/room/:roomCode/battle', (req, res) => {
  const room = rooms[req.params.roomCode.toUpperCase()];
  if (!room || !room.battle) return res.status(404).json({ error: 'No hay batalla activa' });

  const b = room.battle;
  res.json({
    battleNumber: b.battleNumber,
    status: b.status,
    currentPokemon: {
      player1: b.currentPokemon.player1,
      player2: b.currentPokemon.player2
    },
    score: room.score,
    winner: room.winner || null,
    lastTurn: b.lastTurn
  });
});

// 8. Elegir movimiento
app.post('/room/:roomCode/battle/move', (req, res) => {
  const room = rooms[req.params.roomCode.toUpperCase()];
  if (!room || !room.battle) return res.status(400).json({ error: 'No hay batalla' });

  const { playerId, moveId } = req.body;
  const playerIndex = room.players.findIndex(p => p.playerId === playerId);
  if (playerIndex === -1) return res.status(400).json({ error: 'Jugador no encontrado' });

  const key = playerIndex === 0 ? 'player1' : 'player2';
  room.battle.pendingMoves[key] = moveId;

  // Si ambos eligieron, resolver turno
  if (room.battle.pendingMoves.player1 && room.battle.pendingMoves.player2) {
    resolveTurn(room);
  }

  res.json({
    accepted: true,
    waitingForOpponent: !room.battle.pendingMoves.player1 || !room.battle.pendingMoves.player2
  });
});

function resolveTurn(room) {
  const b = room.battle;
  const p1 = b.currentPokemon.player1;
  const p2 = b.currentPokemon.player2;

  const move1 = p1.moves.find(m => m.id === b.pendingMoves.player1) || p1.moves[0];
  const move2 = p2.moves.find(m => m.id === b.pendingMoves.player2) || p2.moves[0];

  // Cálculo simple de daño
  const dmg1to2 = calculateDamage(move1, p1, p2);
  const dmg2to1 = calculateDamage(move2, p2, p1);

  p2.hp = Math.max(0, p2.hp - dmg1to2);
  p1.hp = Math.max(0, p1.hp - dmg2to1);

  b.lastTurn = {
    player1Move: move1.name,
    player2Move: move2.name,
    damageToPlayer1: dmg2to1,
    damageToPlayer2: dmg1to2,
    logs: [
      `${p1.name} usó ${move1.name}`,
      `${p2.name} usó ${move2.name}`,
      `${p2.name} recibió ${dmg1to2} de daño`,
      `${p1.name} recibió ${dmg2to1} de daño`
    ]
  };

  b.pendingMoves = {};
  b.status = 'resolving';

  // Verificar si terminó el combate
  if (p1.hp <= 0 || p2.hp <= 0) {
    const winnerIndex = p1.hp > 0 ? 0 : 1;
    room.score[winnerIndex === 0 ? 'player1' : 'player2']++;
    b.status = 'finished';

    // Verificar si alguien ganó el match (2 de 3)
    if (room.score.player1 >= 2 || room.score.player2 >= 2) {
      room.status = 'finished';
      room.winner = room.score.player1 >= 2 ? room.players[0].name : room.players[1].name;
    } else {
      // Preparar siguiente combate
      room.currentBattle++;
      setTimeout(() => startNextBattle(room), 2000);
    }
  } else {
    b.status = 'waiting_moves';
  }
}

function startNextBattle(room) {
  const p1 = room.players[0];
  const p2 = room.players[1];
  const idx = room.currentBattle - 1;

  if (idx >= 3) return;

  const poke1 = p1.team[idx];
  const poke2 = p2.team[idx];

  room.battle = {
    battleNumber: room.currentBattle,
    status: 'waiting_moves',
    currentPokemon: {
      player1: {
        pokemonId: poke1.id,
        name: poke1.name,
        hp: poke1.stats.hp,
        maxHp: poke1.stats.hp,
        moves: poke1.moves,
        stats: poke1.stats,
        types: poke1.types
      },
      player2: {
        pokemonId: poke2.id,
        name: poke2.name,
        hp: poke2.stats.hp,
        maxHp: poke2.stats.hp,
        moves: poke2.moves,
        stats: poke2.stats,
        types: poke2.types
      }
    },
    pendingMoves: {},
    lastTurn: null
  };
}

function calculateDamage(move, attacker, defender) {
  if (!move.power) return 0;

  const attackStat = move.damageClass === 'special' 
    ? attacker.stats['special-attack'] 
    : attacker.stats.attack;
  
  const defenseStat = move.damageClass === 'special'
    ? defender.stats['special-defense']
    : defender.stats.defense;

  // Fórmula simplificada
  let damage = Math.floor((move.power * attackStat / defenseStat) * 0.4) + 5;

  // Tipo efectividad básica (puedes expandirla)
  const typeChart = {
    fire: { grass: 2, water: 0.5, fire: 0.5 },
    water: { fire: 2, grass: 0.5, water: 0.5 },
    grass: { water: 2, fire: 0.5, grass: 0.5 },
    electric: { water: 2, grass: 0.5, electric: 0.5 },
    // ... puedes agregar más
  };

  const multiplier = typeChart[move.type]?.[defender.types[0]] || 1;
  damage = Math.floor(damage * multiplier);

  // Accuracy
  if (Math.random() * 100 > move.accuracy) damage = 0;

  return Math.max(1, damage);
}

// Health check
app.get('/', (req, res) => {
  res.json({ status: 'ok', message: 'Pokémon Battle Server running' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Servidor corriendo en http://0.0.0.0:${PORT}`);
  console.log('Listo para conexiones en la red local');
});
