#!/usr/bin/env bash
# Headless network test: for every scenario in game/tests/scenarios, starts a host and a client
# Godot over ENet on localhost (game/tools/net_test.gd), plays the scenario as co-op and fails
# on any per-wave state hash mismatch, failed host command on the client, or timeout.
# Usage: ./tools/run_network_test.sh [scenario.json ...]   (names inside game/tests/scenarios)
# Set GODOT_BIN to use your own binary; it must match .godot-version.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$("$ROOT/tools/install_godot.sh")}"
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
trap 'rm -rf "$LOGS"' EXIT
PORT=17777
FAILED=0
for name in "${SCENARIOS[@]}"; do
	scenario="res://tests/scenarios/$name"
	PORT=$((PORT + 1))
	"$GODOT_BIN" --headless --path . --script res://tools/net_test.gd -- \
		--role=host --port="$PORT" --scenario="$scenario" >"$LOGS/host.log" 2>&1 &
	HOST_PID=$!
	set +e
	"$GODOT_BIN" --headless --path . --script res://tools/net_test.gd -- \
		--role=client --port="$PORT" --scenario="$scenario" >"$LOGS/client.log" 2>&1
	CLIENT_CODE=$?
	wait "$HOST_PID"
	HOST_CODE=$?
	set -e
	grep -h '^\[\(host\|client\) ' "$LOGS/host.log" "$LOGS/client.log" | grep -v ' skipped \| refused ' || true
	if [ "$HOST_CODE" -ne 0 ] || [ "$CLIENT_CODE" -ne 0 ]; then
		echo "FAILED $name (host exit $HOST_CODE, client exit $CLIENT_CODE)"
		grep -h 'ERROR\|desync' "$LOGS/host.log" "$LOGS/client.log" | head -n 20 || true
		FAILED=$((FAILED + 1))
	else
		echo "ok $name"
	fi
done

if [ "$FAILED" -gt 0 ]; then
	echo "$FAILED of ${#SCENARIOS[@]} network scenario(s) failed" >&2
	exit 1
fi
echo "All ${#SCENARIOS[@]} network scenarios in sync."
