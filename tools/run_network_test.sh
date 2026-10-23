#!/usr/bin/env bash
# Headless network test: for every scenario in game/tests/scenarios, starts a host and a client
# Godot over ENet on localhost (game/tools/net_test.gd), plays the scenario as co-op and fails
# on any per-wave state hash mismatch, failed host command on the client, or timeout. Then plays
# one co-op scenario over WebRTC through a local lobby (lobby/, needs bun; skipped without bun
# except in CI).
# Usage: ./tools/run_network_test.sh [scenario.json ...]   (names inside game/tests/scenarios)
# Set GODOT_BIN to use your own binary; it must match .godot-version.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$("$ROOT/tools/install_godot.sh")}"
WEBRTC_SCENARIO="coop_two_wizards_pass_cards.json"
LOBBY_PORT=18900
cd "$ROOT/game"
# Import once so class_name scripts and resources are registered.
"$GODOT_BIN" --headless --import >/dev/null 2>&1

if [ "$#" -gt 0 ]; then
	SCENARIOS=("$@")
else
	SCENARIOS=()
	for file in tests/scenarios/*.json; do SCENARIOS+=("$(basename "$file")"); done
fi

LOGS="$(mktemp -d)"
LOBBY_PID=""
trap '[ -n "$LOBBY_PID" ] && kill "$LOBBY_PID" 2>/dev/null; rm -rf "$LOGS"' EXIT
PORT=17777
RUNS=0
FAILED=0

net_test() {
	"$GODOT_BIN" --headless --path . --script res://tools/net_test.gd -- "$@"
}

# Prints the outcome of one host + client pair: report <label> <host exit> <client exit>
report() {
	RUNS=$((RUNS + 1))
	grep -h '^\[\(host\|client\) ' "$LOGS/host.log" "$LOGS/client.log" | grep -v ' skipped \| refused ' || true
	if [ "$2" -ne 0 ] || [ "$3" -ne 0 ]; then
		echo "FAILED $1 (host exit $2, client exit $3)"
		grep -h 'ERROR\|desync' "$LOGS/host.log" "$LOGS/client.log" | head -n 20 || true
		FAILED=$((FAILED + 1))
	else
		echo "ok $1"
	fi
}

for name in "${SCENARIOS[@]}"; do
	scenario="res://tests/scenarios/$name"
	PORT=$((PORT + 1))
	net_test --role=host --port="$PORT" --scenario="$scenario" >"$LOGS/host.log" 2>&1 &
	HOST_PID=$!
	set +e
	net_test --role=client --port="$PORT" --scenario="$scenario" >"$LOGS/client.log" 2>&1
	CLIENT_CODE=$?
	wait "$HOST_PID"
	HOST_CODE=$?
	set -e
	report "$name" "$HOST_CODE" "$CLIENT_CODE"
done

if ! command -v bun >/dev/null; then
	if [ -n "${CI:-}" ]; then
		echo "bun is required for the WebRTC network test" >&2
		exit 1
	fi
	echo "skipped WebRTC: install bun (https://bun.sh) to run it"
else
	PORT="$LOBBY_PORT" bun "$ROOT/lobby/src/server.ts" >"$LOGS/lobby.log" 2>&1 &
	LOBBY_PID=$!
	LOBBY="ws://127.0.0.1:$LOBBY_PORT/ws"
	scenario="res://tests/scenarios/$WEBRTC_SCENARIO"
	for _ in $(seq 50); do
		curl -fs "http://127.0.0.1:$LOBBY_PORT/healthz" >/dev/null && break
		sleep 0.2
	done
	net_test --role=host --lobby="$LOBBY" --scenario="$scenario" >"$LOGS/host.log" 2>&1 &
	HOST_PID=$!
	CODE=""
	for _ in $(seq 100); do
		CODE="$(grep -o 'room [A-Z]\{4\}' "$LOGS/host.log" | head -n 1 | cut -c6- || true)"
		[ -n "$CODE" ] && break
		sleep 0.2
	done
	set +e
	net_test --role=client --lobby="$LOBBY" --code="$CODE" --scenario="$scenario" \
		>"$LOGS/client.log" 2>&1
	CLIENT_CODE=$?
	wait "$HOST_PID"
	HOST_CODE=$?
	set -e
	report "$WEBRTC_SCENARIO (WebRTC)" "$HOST_CODE" "$CLIENT_CODE"
fi

if [ "$FAILED" -gt 0 ]; then
	echo "$FAILED of $RUNS network run(s) failed" >&2
	exit 1
fi
echo "All $RUNS network runs in sync."
