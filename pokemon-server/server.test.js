const test = require('node:test');
const assert = require('node:assert/strict');
const { calculateDamage, resolveTurn } = require('./server');

function pokemon(name, speed) {
  return {
    name,
    hp: 10,
    stats: { hp: 10, attack: 100, defense: 10, 'special-attack': 100, 'special-defense': 10, speed },
    types: ['normal'],
    moves: [{ id: 1, name: 'golpe', power: 100, accuracy: 100, type: 'normal', damageClass: 'physical' }]
  };
}

function roomWithSpeeds(player1Speed, player2Speed) {
  return {
    roomCode: 'TEST', currentBattle: 1, score: { player1: 1, player2: 1 }, status: 'battle',
    players: [{ name: 'P1' }, { name: 'P2' }],
    battle: {
      status: 'waiting_moves',
      currentPokemon: { player1: pokemon('P1mon', player1Speed), player2: pokemon('P2mon', player2Speed) },
      pendingMoves: { player1: 1, player2: 1 },
      lastTurn: null
    }
  };
}

test('un movimiento fallado causa cero daño', () => {
  const originalRandom = Math.random;
  Math.random = () => 0.99;
  try {
    assert.equal(calculateDamage({ ...pokemon('atacante', 1).moves[0], accuracy: 50 }, pokemon('atacante', 1), pokemon('defensor', 1)), 0);
  } finally {
    Math.random = originalRandom;
  }
});

test('el Pokémon más rápido ataca primero y gana si ambos caen', () => {
  const room = roomWithSpeeds(10, 100);
  resolveTurn(room);

  assert.equal(room.battle.lastTurn.logs[0], 'P2mon usó golpe');
  assert.equal(room.score.player2, 2);
  assert.equal(room.score.player1, 1);
});

test('player1 tiene prioridad cuando las velocidades empatan', () => {
  const room = roomWithSpeeds(50, 50);
  resolveTurn(room);

  assert.equal(room.battle.lastTurn.logs[0], 'P1mon usó golpe');
  assert.equal(room.score.player1, 2);
  assert.equal(room.score.player2, 1);
});
