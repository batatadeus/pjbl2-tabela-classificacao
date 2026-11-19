# PjBL2 — Tabela de Classificação de Campeonato (Haskell)

Calcula a tabela de classificação de um campeonato de futebol a partir dos
resultados das partidas, em três camadas:

| Camada | Módulo | O que faz |
|---|---|---|
| 1 | `src/Tipos.hs` | Tipos algébricos (`Time`, `Resultado`, `Partida`, `Linha`) e consultas básicas |
| 2 | `src/Classificacao.hs` | Classificação e estatísticas **só com funções de ordem superior** (sem recursão explícita) |
| 3 | `src/Leitura.hs` | Leitura de texto com validação via `Maybe`/`Either`, relatório de erros e tabela formatada |
| — | `src/Dados.hs` | Campeonato de teste embutido como `String` (funciona no playground) |
| — | `src/Main.hs` | Demonstração das três camadas (`main` é a única função com `IO`) |

**Integrante:** Raphael de Oliveira Soares

**Ambiente utilizado:** **GHC local 9.10.3**, instalado via GHCup. O código usa
apenas o pacote `base` e compila **sem nenhum aviso com `-Wall -Werror`**.
Para conveniência, também existe uma versão de arquivo único para o
[play.haskell.org](https://play.haskell.org) em `playground/Main.hs` (ver §6).

---

## 1. Requisitos

- **GHC 9.x** (testado com 9.10.3). Nenhuma biblioteca extra: não usa Cabal nem Stack.
- Instalação recomendada: [GHCup](https://www.haskell.org/ghcup/).
  - **Windows (PowerShell):**
    ```powershell
    Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; try { & ([ScriptBlock]::Create((Invoke-WebRequest https://www.haskell.org/ghcup/sh/bootstrap-haskell.ps1 -UseBasicParsing))) -Interactive -DisableCurl } catch { Write-Error $_ }
    ```
    (ou, como foi feito aqui, baixar o `ghcup.exe` de
    `https://downloads.haskell.org/~ghcup/x86_64-mingw64-ghcup.exe` para
    `C:\ghcup\bin` e rodar `ghcup install ghc recommended --set`).
  - **Linux / macOS:**
    `curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh`
- Confira com `ghc --version`. Se o comando não for encontrado no Windows,
  adicione `C:\ghcup\bin` ao `PATH` (os scripts `.ps1` deste projeto já fazem isso).

## 2. Como executar (rápido)

Na pasta `projeto/`:

| O quê | Windows (PowerShell) | Linux / macOS |
|---|---|---|
| Compilar e rodar a demonstração | `.\executar.ps1` | `./executar.sh` |
| Rodar com dados de um arquivo | `.\executar.ps1 exemplos\com_erros.txt` | `./executar.sh exemplos/com_erros.txt` |
| Rodar os testes (87 casos) | `.\executar_testes.ps1` | `./executar_testes.sh` |
| Validar contra os requisitos | `powershell -ExecutionPolicy Bypass -File validacao\validar_requisitos.ps1` | — |

> Se o PowerShell recusar scripts, use
> `powershell -ExecutionPolicy Bypass -File .\executar.ps1`.

## 3. Comandos manuais (sem scripts)

```sh
# compilar (os .o/.hi vão para build/, o executável para build/campeonato)
mkdir build
ghc -Wall -isrc -outputdir build/obj -o build/campeonato src/Main.hs

# executar
./build/campeonato                        # dados embutidos (Dados.hs)
./build/campeonato exemplos/campeonato.txt # dados de um arquivo

# sem compilar (interpretado)
runghc -isrc src/Main.hs
runghc -isrc tests/Testes.hs

# explorar no GHCi
ghci -isrc src/Main.hs
ghci> let ps = either (const []) id (lerCampeonato dadosCampeonato)
ghci> putStr (tabelaFormatada (classificacao (ateRodada 3 ps)))
ghci> maiorGoleada ps
ghci> todosOsErros dadosComErros
ghci> :main exemplos/com_erros.txt
```

## 4. O que a demonstração imprime (`main`)

Em sequência, conforme a Seção 5 do enunciado:

1. **Camada 1** — lista de times (`times`), rodadas e `resultadoPara` aplicado ao mandante, ao visitante e a um time que não jogou.
2. **Camada 2** — tabela **final** (+ líder e qual critério desempatou cada empate em pontos).
3. **Camada 2** — tabela **após a rodada intermediária** (`ateRodada 3`): o líder muda (Coritiba → Athletico).
4. **Camada 2** — estatísticas: total e média de gols, maior goleada, aproveitamento do líder.
5. **Camada 3** — entrada com erros: `lerCampeonato` (para no 1º erro) e `todosOsErros` (relatório completo).
6. **Caso de borda** — campeonato vazio: `Right []`, tabela vazia, `maiorGoleada`/`mediaGols` = `Nothing`.

Trecho da saída:

```
  #  Time          P   J   V   E   D  GP  GC   SG      %
--------------------------------------------------------
  1  Athletico    10   5   3   1   1  11   4   +7   66.7
  2  Coritiba     10   5   3   1   1   7   4   +3   66.7
  3  Operário      7   5   2   1   2   5   5    0   46.7
  4  Paraná        7   5   1   4   0   6   4   +2   46.7
  5  Londrina      4   5   1   1   3   3   7   -4   26.7
  6  Cascavel      2   5   0   2   3   3  11   -8   13.3
Lider: Athletico
Empates em pontos e o criterio que decidiu:
  Athletico a frente de Coritiba por saldo de gols
  Operário a frente de Paraná por vitorias
```

Colunas: P = pontos, J = jogos, V/E/D = vitórias/empates/derrotas,
GP/GC = gols pró/contra, SG = saldo, % = aproveitamento.

## 5. Formato da entrada

Uma partida por linha, campos separados por `;`. Linhas em branco e linhas
que começam com `#` são ignoradas. Espaços em volta dos campos e o `\r` de
arquivos do Windows são tolerados.

```
# rodada;mandante;gols mandante;gols visitante;visitante
1;Coritiba;2;0;Cascavel
1;Paraná;0;0;Operário
```

Erros detectados (cada um indica **a linha** do texto; a repetição indica também **a rodada**):

| Construtor | Exemplo de linha que provoca |
|---|---|
| `CamposInvalidos linha qtd` | `1;Londrina;1;1` (4 campos) |
| `NumeroInvalido linha texto` | `1;Paraná;dois;0;Operário`, `2a`, número que não cabe em `Int` |
| `PlacarNegativo linha gols` | `2;Cascavel;-1;0;Londrina` |
| `MesmoTime linha time` | `2;Operário;1;1;Operário` |
| `TimeRepetidoNaRodada linha rodada time` | o mesmo time escalado duas vezes na rodada 2 |
| `TimeVazio linha` *(extra)* | `3;;1;0;Paraná` |
| `RodadaInvalida linha rodada` *(extra)* | `0;Coritiba;1;0;Paraná` |

Arquivos de exemplo: `exemplos/campeonato.txt` (válido) e `exemplos/com_erros.txt`.
Se o arquivo passado não existir ou não puder ser lido, o programa avisa e
usa o campeonato embutido; ele **nunca** termina com exceção.

## 6. Playground (play.haskell.org)

O playground aceita um único arquivo e não tem entrada pelo teclado. Por isso:

1. Abra `playground/Main.hs` (gerado a partir de `src/*.hs`, com as seções na
   mesma ordem dos módulos: Tipos → Classificacao → Leitura → Dados → Main).
2. Copie todo o conteúdo para https://play.haskell.org e clique em **Run**.

Os dados já estão no código (`dadosCampeonato = unlines [...]`), sem `getLine`.
Se alterar algo em `src/`, regenere o arquivo único com:

```powershell
powershell -ExecutionPolicy Bypass -File ferramentas\gerar_playground.ps1
```

## 7. Testes

`tests/Testes.hs` usa a função `testar` do enunciado e imprime `OK`/`FALHOU`
por caso, um resumo e retorna código de saída 1 se algo falhar. São **87 casos**:

- **Camada 1** (16): `resultadoPara` (mandante, visitante, time que não jogou, empate), `participou`, `times` sem repetição, e os requisitos mínimos do campeonato (6 times, 5 rodadas, 0 x 0, goleada ≥ 3, ninguém joga duas vezes na rodada).
- **Camada 2** (30): classificação completa conferida à mão; desempates por **saldo**, por **vitórias**, por **gols pró** e por **ordem alfabética**, cada um dizendo qual critério decidiu; `ateRodada 3` diferente da final; `maiorGoleada []` e `mediaGols []` = `Nothing`; aproveitamento de quem não jogou = 0.
- **Camada 3** (41): `lerCampeonato` válido → `Right`; **um teste por construtor de `Erro`**; `todosOsErros` com 7 linhas inválidas; CRLF, comentários, texto vazio, lixo (`";;;;;;"`, `"abc"`), estouro de `Int`, formatação da tabela e dos decimais.

## 8. Campeonato de teste (`src/Dados.hs`)

6 times, 5 rodadas, turno único (15 partidas, 3 por rodada). Casos de borda cobertos:

| Situação | Onde |
|---|---|
| Empate 0 x 0 | R1 Paraná 0 x 0 Operário |
| Vitória por 3+ gols (maior goleada) | R3 Cascavel 0 x 5 Athletico |
| Empate em pontos decidido por **saldo** | Athletico e Coritiba (10 pts, 3 V; +7 x +3) |
| Empate em pontos decidido por **vitórias** (mesmo com saldo pior) | Operário (2 V, saldo 0) à frente de Paraná (1 V, saldo +2) |
| Líder diferente na rodada 3 | Coritiba lidera após a 3ª rodada; Athletico termina em 1º |
| Time invicto / time sem vitórias | Paraná / Cascavel |

## 9. Estrutura

```
projeto/
├── src/
│   ├── Tipos.hs            Camada 1: tipos e consultas básicas
│   ├── Classificacao.hs    Camada 2: ordem superior
│   ├── Leitura.hs          Camada 3: Maybe, Either e formatação
│   ├── Dados.hs            campeonato de teste, como String
│   └── Main.hs             demonstração das três camadas
├── tests/
│   └── Testes.hs           87 testes com resultado esperado
├── docs/
│   ├── decisoes.md         decisões de modelagem + limitações conhecidas
│   └── validacao.md        resultado da validação contra o enunciado
├── playground/Main.hs      versão arquivo único (gerada) para play.haskell.org
├── exemplos/               entradas de exemplo para ler de arquivo
├── validacao/validar_requisitos.ps1   checagem automática dos requisitos
├── ferramentas/gerar_playground.ps1   gera playground/Main.hs
├── executar.ps1 / executar.sh
├── executar_testes.ps1 / executar_testes.sh
└── README.md
```

## 10. Problemas comuns

- **Acentos aparecem estranhos no terminal do Windows** (`ParanÃ¡`): o programa
  imprime em UTF-8. Rode `chcp 65001` antes, ou use o Windows Terminal. Os scripts
  `.ps1` já ajustam a codificação.
- **"Uma política de Controle de Aplicativo bloqueou este arquivo"**: o Smart App
  Control do Windows às vezes bloqueia `.exe` recém-compilados. Use `runghc`
  (`.\executar_testes.ps1` já usa; `.\executar.ps1` cai para `runghc` sozinho).
- **`ghc` não encontrado**: abra um novo terminal após instalar o GHCup ou
  adicione `C:\ghcup\bin` (Windows) / `~/.ghcup/bin` (Linux/macOS) ao `PATH`.
