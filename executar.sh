#!/usr/bin/env sh
# Compila (com -Wall) e executa a demonstracao das tres camadas.
# Uso:  ./executar.sh                         (dados embutidos em src/Dados.hs)
#       ./executar.sh exemplos/com_erros.txt  (le as partidas de um arquivo)
set -e
cd "$(dirname "$0")"
mkdir -p build
ghc -Wall -isrc -outputdir build/obj -o build/campeonato src/Main.hs
echo
./build/campeonato "$@"
