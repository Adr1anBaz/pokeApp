import argparse
import json
import os
import time

import requests


BASE = os.getenv("BASE_URL", "http://172.22.41.221:3000")


def pp(title, data):
    print(f"\n=== {title} ===")
    print(json.dumps(data, indent=2, ensure_ascii=False))


def test_history():
    """Comprueba los endpoints de historial global y por sala."""
    response = requests.get(f"{BASE}/history")
    response.raise_for_status()
    history = response.json()
    pp("Historial global", history)

    assert isinstance(history.get("total"), int), "history.total debe ser un entero"
    assert isinstance(history.get("matches"), list), "history.matches debe ser una lista"

    # Crear una sala para probar el endpoint filtrado con un código válido.
    response = requests.post(f"{BASE}/room", json={"playerName": "History test"})
    response.raise_for_status()
    room_code = response.json()["roomCode"]

    response = requests.get(f"{BASE}/room/{room_code}/history")
    response.raise_for_status()
    room_history = response.json()
    pp(f"Historial de la sala {room_code}", room_history)

    assert room_history["roomCode"] == room_code
    assert isinstance(room_history["total"], int)
    assert isinstance(room_history["matches"], list)

    for match in history["matches"]:
        for field in ("id", "roomCode", "date", "players", "score", "winner", "battlesPlayed"):
            assert field in match, f"Falta el campo {field} en el historial"

    print("\n✅ Prueba de historial terminada")


def test_full():
    # 1. Crear sala
    response = requests.post(f"{BASE}/room", json={"playerName": "Adrian"})
    response.raise_for_status()
    room = response.json()
    pp("Crear sala", room)
    code = room["roomCode"]
    p1 = room["playerId"]

    # 2. Unirse
    response = requests.post(f"{BASE}/room/join", json={"roomCode": code, "playerName": "Haili"})
    response.raise_for_status()
    guest = response.json()
    pp("Unirse", guest)
    p2 = guest["playerId"]

    # 3. Estado sala
    response = requests.get(f"{BASE}/room/{code}")
    response.raise_for_status()
    pp("Estado sala", response.json())

    # 4. Pokémon jugador 1
    response = requests.get(f"{BASE}/room/{code}/pokemon", headers={"playerid": p1})
    response.raise_for_status()
    pokes1 = response.json()["pokemon"]
    pp("Pokémon P1 (primeros 3)", pokes1[:3])

    # 5. Pokémon jugador 2
    response = requests.get(f"{BASE}/room/{code}/pokemon", headers={"playerid": p2})
    response.raise_for_status()
    pokes2 = response.json()["pokemon"]
    pp("Pokémon P2 (primeros 3)", pokes2[:3])

    # 6. Equipos (toma los primeros 3 de cada uno)
    team1 = [{"pokemonId": p["id"], "order": i + 1} for i, p in enumerate(pokes1[:3])]
    team2 = [{"pokemonId": p["id"], "order": i + 1} for i, p in enumerate(pokes2[:3])]

    response = requests.post(f"{BASE}/room/{code}/team", json={"playerId": p1, "team": team1})
    response.raise_for_status()
    pp("Equipo P1", response.json())

    response = requests.post(f"{BASE}/room/{code}/team", json={"playerId": p2, "team": team2})
    response.raise_for_status()
    pp("Equipo P2", response.json())

    # 7. Ready
    response = requests.post(f"{BASE}/room/{code}/ready", json={"playerId": p1})
    response.raise_for_status()
    pp("Ready P1", response.json())

    response = requests.post(f"{BASE}/room/{code}/ready", json={"playerId": p2})
    response.raise_for_status()
    pp("Ready P2", response.json())

    time.sleep(1)

    # 8. Estado batalla
    response = requests.get(f"{BASE}/room/{code}/battle")
    response.raise_for_status()
    battle = response.json()
    pp("Estado batalla", battle)

    # 9. Movimientos (toma el primer move de cada uno)
    move1 = battle["currentPokemon"]["player1"]["moves"][0]["id"]
    move2 = battle["currentPokemon"]["player2"]["moves"][0]["id"]

    response = requests.post(
        f"{BASE}/room/{code}/battle/move", json={"playerId": p1, "moveId": move1}
    )
    response.raise_for_status()
    pp("Move P1", response.json())

    response = requests.post(
        f"{BASE}/room/{code}/battle/move", json={"playerId": p2, "moveId": move2}
    )
    response.raise_for_status()
    pp("Move P2", response.json())

    time.sleep(1)

    # 10. Resultado del turno
    response = requests.get(f"{BASE}/room/{code}/battle")
    response.raise_for_status()
    pp("Después del turno", response.json())

    # 11. Los endpoints de historial también deben responder para esta sala.
    response = requests.get(f"{BASE}/room/{code}/history")
    response.raise_for_status()
    pp(f"Historial de {code}", response.json())

    print("\n✅ Prueba completa terminada")


def main():
    parser = argparse.ArgumentParser(
        description="Pruebas del servidor Pokémon Battle",
        epilog="Ejemplos: python test_server.py --test history | python test_server.py --test all",
    )
    parser.add_argument(
        "--test",
        choices=("all", "history"),
        default="all",
        help="Prueba a ejecutar (por defecto: all)",
    )
    args = parser.parse_args()

    if args.test == "history":
        test_history()
    else:
        test_full()


if __name__ == "__main__":
    main()
