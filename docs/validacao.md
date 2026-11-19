# Validação contra o enunciado (PjBL2)

Executada em 18/11/2026 com **GHC 9.10.3** (Windows 11), via
`validacao/validar_requisitos.ps1` + revisão manual.

**Resultado automático:** 81 verificações OK, 0 falhas · **testes:** 87/87 OK ·
**compilação:** `-Wall -Werror` sem nenhum aviso (`src/`, `tests/` e `playground/`).

Para reproduzir:

```powershell
powershell -ExecutionPolicy Bypass -File validacao\validar_requisitos.ps1
```

---

## Seção 3.1 — Camada 1

| Requisito | Status | Onde / evidência |
|---|---|---|
| `type Time = String` | ✅ | `src/Tipos.hs` |
| `data Resultado` = `Vitoria \| Empate \| Derrota` | ✅ | `src/Tipos.hs` |
| `data Partida` record (rodada, mandante, golsMandante, golsVisitante, visitante) | ✅ | `src/Tipos.hs` |
| `data Linha` record (time, jogos, vitórias, empates, derrotas, gols pró, gols contra) | ✅ | `src/Tipos.hs` |
| `participou :: Time -> Partida -> Bool` | ✅ | teste `participou mandante/visitante/outro` |
| `resultadoPara :: Time -> Partida -> Maybe Resultado` (Nothing se não jogou) | ✅ | 4 testes `resultadoPara ...` |
| `times :: [Partida] -> [Time]` sem repetição, alfabética | ✅ | testes `times do campeonato`, `times sem repeticao` |
| Campeonato com ≥ 6 times e ≥ 5 rodadas, ninguém joga 2x na rodada | ✅ | 6 times, 5 rodadas, 15 jogos; testes `campeonato: ...` |
| ≥ 1 empate 0 x 0 e ≥ 1 vitória por 3+ gols | ✅ | Paraná 0x0 Operário; Cascavel 0x5 Athletico |
| ≥ 2 times empatados em pontos, ordem decidida pelo desempate | ✅ | Athletico/Coritiba (saldo) e Operário/Paraná (vitórias) |

## Seção 3.2 — Camada 2

| Requisito | Status | Onde / evidência |
|---|---|---|
| `pontos :: Resultado -> Int` (3/1/0) | ✅ | teste `pontos V/E/D` |
| `linhaDoTime` acumulada com `foldl`/`foldr` | ✅ | `foldl acumular (linhaVazia t) (filter ...)` |
| `pontosLinha`, `saldo :: Linha -> Int` | ✅ | testes `pontosLinha Athletico`, `saldo Cascavel` |
| `aproveitamento :: Linha -> Double`, 0 se não jogou | ✅ | `fromIntegral`, sem `div`; 2 testes |
| `classificacao :: [Partida] -> [Linha]` ordenada | ✅ | teste `classificacao completa (conferida a mao)` |
| `ateRodada :: Int -> [Partida] -> [Partida]` | ✅ | 4 testes |
| `maiorGoleada :: [Partida] -> Maybe Partida` (Nothing p/ vazia) | ✅ | 3 testes |
| `mediaGols :: [Partida] -> Maybe Double` (Nothing p/ vazia) | ✅ | 2 testes |
| Sem recursão explícita | ✅ | detector automático (validado com função recursiva injetada) |
| Usa `map`, `filter`, dobra e composição `(.)` | ✅ | checagens automáticas |
| `sortBy`/`sortOn` com `comparing`, `Down` (sem ordenação manual) | ✅ | `sortBy criterioClassificacao`, `sortOn (Down . diferencaGols)` |
| Critérios seguem o campeonato (Brasileirão) | ✅ | pontos → vitórias → saldo → gols pró → nome (confronto direto: ver L2) |

## Seção 3.3 — Camada 3

| Requisito | Status | Onde / evidência |
|---|---|---|
| `data Erro` com `CamposInvalidos`, `NumeroInvalido`, `PlacarNegativo`, `MesmoTime`, `TimeRepetidoNaRodada`, cada um com linha/rodada | ✅ | + `TimeVazio`, `RodadaInvalida` |
| `separar :: Char -> String -> [String]` | ✅ | 4 testes (`foldr`) |
| `lerPartida :: Int -> String -> Either Erro Partida` com `do` em Either | ✅ | `src/Leitura.hs` |
| `lerCampeonato` com `traverse`/`mapM`, para no 1º erro e checa repetição na rodada | ✅ | testes `lerCampeonato ...`, `Erro TimeRepetidoNaRodada` |
| `todosOsErros :: String -> [Erro]` (todos, não só o 1º) | ✅ | teste com 7 linhas inválidas |
| `tabelaFormatada` com posição, time, pontos, jogos, V, E, D e saldo | ✅ | + GP, GC e aproveitamento; 4 testes |
| `main :: IO ()` é a única função com IO | ✅ | checagem automática de assinaturas |
| `readMaybe` (nunca `read`) | ✅ | checagem automática |
| ≥ 1 `do` em Either e ≥ 1 uso de Maybe como functor/mônada | ✅ | `<$>` em `resultadoPara`, `>>=` em `lerNumero`, `maybe` em vários |
| Dados no próprio código como String (sem `getLine`) | ✅ | `src/Dados.hs`; arquivo é opcional via argumento |

## Seção 5 — Requisitos técnicos

| Requisito | Status | Observação |
|---|---|---|
| Somente `base` | ✅ | núcleo usa só `Data.List/Char/Maybe/Either/Ord` e `Text.Read`; `Main` usa também `System.IO`, `System.Environment`, `Control.Exception`, `GHC.IO.Encoding` (todos `base`) |
| Dividido em módulos por camada | ✅ | + versão arquivo único em `playground/Main.hs` |
| Compila sem erros; sem avisos de padrões incompletos | ✅ | `-Wall -Werror`: zero avisos |
| `main` mostra, em sequência: tabela final, tabela intermediária, estatísticas, entrada com erros | ✅ | checagem automática da ordem das seções |
| Entrada inválida nunca gera exceção, sempre `Left` descritivo | ✅ | testes com lixo, CRLF, estouro, vazio; arquivo inexistente vira aviso |

## Seção 6 — Estrutura de entrega

`src/Tipos.hs`, `src/Classificacao.hs`, `src/Leitura.hs`, `src/Dados.hs`,
`src/Main.hs`, `tests/Testes.hs`, `docs/decisoes.md`, `README.md` — ✅ todos presentes.

## Seção 7 — Casos de teste obrigatórios

| Caso | Teste em `tests/Testes.hs` |
|---|---|
| `resultadoPara` mandante / visitante / não jogou | `resultadoPara mandante (vitoria)`, `... visitante (derrota)`, `... time que nao jogou` |
| `times` sem repetições | `times do campeonato (alfabetica)`, `times sem repeticao` |
| Classificação completa conferida à mão | `classificacao completa (conferida a mao)` |
| Empate em pontos + critério que decidiu | `desempate: Athletico x Coritiba decidido por SALDO`, `... Operário x Paraná ... VITORIAS`, `desempate por gols pro e por ordem alfabetica` |
| `classificacao (ateRodada 3)` diferente da final | `classificacao (ateRodada 3)`, `classificacao (ateRodada 3) /= final` |
| `maiorGoleada []`, `mediaGols []` = Nothing | `maiorGoleada [] = Nothing`, `mediaGols [] = Nothing` |
| `lerCampeonato` válido → Right | `lerCampeonato entrada valida -> Right` |
| Um teste por construtor de `Erro` | `Erro CamposInvalidos`, `Erro NumeroInvalido`, `Erro PlacarNegativo`, `Erro MesmoTime`, `Erro TimeRepetidoNaRodada`, `Erro TimeVazio`, `Erro RodadaInvalida` |
| `todosOsErros` com ≥ 3 linhas inválidas | `todosOsErros lista todos (7 erros)` |

## Rubrica (Seção 9) — autoavaliação

| Critério | Peso | Nível esperado | Justificativa |
|---|---|---|---|
| 1. Camada 1 | 15% | Excelente | `Linha` não guarda pontos/saldo (estado inválido irrepresentável); campeonato cobre todos os casos de borda |
| 2. Camada 2 | 30% | Excelente | sem recursão, `comparing`/`Down`/`<>`, todas as funções totais |
| 3. Camada 3 | 25% | Excelente | todos os erros detectados, `do` em Either, `traverse`, `todosOsErros` completo, núcleo puro × `main` |
| 4. Robustez | 10% | Excelente | nenhuma exceção; erros com linha/rodada; campeonato vazio tratado e documentado |
| 5. Qualidade | 10% | Excelente | zero avisos com `-Wall`, todas as funções de topo com assinatura |
| 6. Testes e docs | 5% | Excelente | 87 testes incluindo bordas; README com instalação, execução e problemas comuns |
| 7. Decisões | 5% | Excelente | 23 decisões justificadas + 10 limitações em `docs/decisoes.md` |

## Observações finais

- Trabalho entregue por um único integrante: Raphael de Oliveira Soares.
- Entrega: link do repositório GitHub no Canvas.
- Opcional: colar `playground/Main.hs` no play.haskell.org e confirmar a execução (não testado por nós; ver L8).
