#!/usr/bin/env sh
# Executa a bateria de testes (tests/Testes.hs). Codigo de saida 0 = tudo OK.
cd "$(dirname "$0")"
runghc -isrc tests/Testes.hs
