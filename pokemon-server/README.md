# Servidor Pokémon Battle PvP

## Requisitos
- Node.js 18 o superior

## Instalación

```bash
cd pokemon-server
npm install
```

## Ejecutar

```bash
npm start
```

El servidor queda escuchando en el puerto **3000** en todas las interfaces (`0.0.0.0`).

## Cómo usar desde las apps

1. Averigua la IP local de la computadora donde corre el servidor (ej. `192.168.1.10`).
2. En las apps usa como base URL: `http://192.168.1.10:3000`
3. Ambos dispositivos deben estar en la **misma red WiFi**.

## Endpoints implementados

- `POST /room` — Crear sala
- `POST /room/join` — Unirse
- `GET /room/:code` — Estado
- `GET /room/:code/pokemon` — 10 Pokémon (header `playerid`)
- `POST /room/:code/team` — Enviar equipo
- `POST /room/:code/ready` — Listo
- `GET /room/:code/battle` — Estado de batalla
- `POST /room/:code/battle/move` — Elegir movimiento

## Notas

- Almacenamiento en memoria (se pierde al reiniciar).
- Daño calculado de forma simplificada con tipos básicos.
- Puedes expandir la tabla de tipos en `calculateDamage`.
