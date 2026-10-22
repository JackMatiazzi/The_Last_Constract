#!/usr/bin/env bash
# testes de ponta a ponta: um contrato solo e uma partida em grupo com dois processos na rede local.
# O Godot pode sair com 0 mesmo com erro de script, entao o log tambem decide
set -u

GODOT="${GODOT:-godot}"
PROJECT="$(cd "$(dirname "$0")/../.." && pwd)"
LOGS="${LOGS:-${TMPDIR:-/tmp}/the-last-contract-e2e}"
mkdir -p "$LOGS"

play() {
	"$GODOT" --headless --path "$PROJECT" "res://tests/e2e/$1" -- "${@:2}"
}

play solo_e2e.tscn > "$LOGS/solo.log" 2>&1
solo=$?

play coop_e2e.tscn --role=host --host --adventurer=0 --autostart=2 --name=Host > "$LOGS/host.log" 2>&1 &
host_pid=$!
# o cliente so entra depois que o host abriu a porta; maquina de CI fria demora a carregar o jogo
for _ in $(seq 120); do
	grep -q "E2E host escutando" "$LOGS/host.log" 2>/dev/null && break
	kill -0 "$host_pid" 2>/dev/null || break
	sleep 0.5
done
play coop_e2e.tscn --role=client --join=127.0.0.1 --adventurer=2 --name=Cliente > "$LOGS/client.log" 2>&1
client=$?
wait "$host_pid"
host=$?

failed=0
for name in solo host client; do
	code_var="$name"
	log="$LOGS/$name.log"
	grep -E "E2E" "$log"
	if [ "${!code_var}" -ne 0 ] || grep -q "SCRIPT ERROR" "$log" || ! grep -q "E2E OK" "$log"; then
		echo "== $name falhou (codigo ${!code_var}); erros do log:"
		grep -E "SCRIPT ERROR|ERROR:|E2E FALHOU" "$log" | head -20
		failed=1
	fi
done
exit "$failed"
