# Decisões de modelagem e limitações conhecidas

Este documento explica **por que** o código foi escrito como está, camada por
camada, e lista com honestidade o que o sistema **não** faz.

---

## Camada 1 — Tipos e dados

### D1. `Partida` e `Linha` como *records*, não tuplas
Uma tupla `(Int, String, Int, Int, String)` permitiria trocar os gols do
mandante pelos do visitante sem nenhum aviso do compilador. Com campos
nomeados (`golsMandante`, `golsVisitante`) cada acesso diz o que está sendo lido,
e a atualização em `acumular` usa a sintaxe de record (`l { jogos = jogos l + 1 }`).

### D2. `Resultado` como tipo soma
`data Resultado = Vitoria | Empate | Derrota` fecha o conjunto de valores: um
`"v"` minúsculo não compila. `pontos` faz *pattern matching* nos três casos e,
com `-Wall`, o compilador avisaria se algum faltasse. Derivamos também `Ord`,
`Enum` e `Bounded` (útil para enumerar resultados em testes).

### D3. `Linha` guarda só contagens primitivas
`Linha` tem `time, jogos, vitorias, empates, derrotas, golsPro, golsContra`.
**Pontos e saldo não são campos**: são funções (`pontosLinha`, `saldo`) da
Camada 2. Assim é impossível construir uma linha com "10 pontos" e 0 vitórias —
o estado inconsistente simplesmente não é representável. A regra 3/1/0 fica em
um único lugar (`pontos`), e `pontosLinha` reaproveita essa função.

### D4. `resultadoPara` é derivado de `golsPara`
`golsPara :: Time -> Partida -> Maybe (Int, Int)` devolve `(pró, contra)` do
ponto de vista do time. `resultadoPara` é só `uncurry classificar <$> golsPara t p`
(Maybe como **functor**). Assim a "inversão" do placar para o visitante está
escrita uma única vez e é usada tanto por `resultadoPara` quanto pela dobra da
Camada 2.

### D5. `times = sort . nub . concatMap ...`
Composição de três funções da biblioteca: junta mandantes e visitantes, remove
repetições e ordena. Não usamos `map head . group . sort` porque `head` é
parcial (mesmo sendo seguro nesse uso, preferimos não ter nenhuma função
parcial no código).

### D6. Campeonato de teste desenhado à mão
Seis times, cinco rodadas, turno único gerado pelo **método do círculo**
(cada time joga exatamente uma vez por rodada). Os placares foram escolhidos
para cobrir os casos de borda da tabela de armadilhas:
- 0 x 0 (Paraná x Operário) e goleada de 5 gols (Cascavel 0 x 5 Athletico);
- dois empates em pontos na tabela final, decididos por **critérios diferentes**
  (saldo e vitórias) — e no segundo o time com **saldo pior** fica à frente,
  o que prova que o critério de vitórias vem antes do saldo;
- empate em pontos e vitórias na rodada 3 (Londrina x Cascavel), decidido por saldo;
- o líder muda entre a rodada 3 e o fim; há um invicto e um time sem vitórias;
- o texto tem comentários, linhas em branco e espaços extras.
A tabela final foi **calculada à mão** antes de escrever o teste
`classificacao completa (conferida a mao)`.

---

## Camada 2 — Ordem superior

### D7. Nenhuma recursão explícita
Toda a camada usa `map`, `filter`, `foldl`, `zip`, `find`, `sortBy`, `sortOn`
e composição. O script `validacao/validar_requisitos.ps1` verifica
automaticamente que nenhuma função de topo de `Classificacao.hs` chama a si mesma.

### D8. `foldl` (e não `foldr` nem `foldl'`) em `linhaDoTime`
- O passo `acumular :: Linha -> Partida -> Linha` tem o acumulador à
  **esquerda**, exatamente o formato `b -> a -> b` que `foldl` espera; e as
  partidas são somadas da primeira para a última, como numa tabela real.
- `foldr` também daria o mesmo resultado (somas são comutativas), mas exigiria
  `flip acumular` sem nenhum ganho: não há lista infinita nem preguiça a explorar.
- `foldl'` (estrita) **não** traria vantagem aqui: ela só força a `Linha` até a
  forma normal fraca (o construtor), e os campos continuariam preguiçosos. Além
  disso, no GHC 9.10 `foldl'` passou a ser exportada pelo `Prelude`; importá-la
  de `Data.List` gera aviso de import redundante com `-Wall` no 9.10, e não
  importá-la quebra em GHCs anteriores (por exemplo, o do playground).
  `foldl` funciona sem aviso em todas as versões.
- Para os tamanhos de campeonato realistas (até 380 jogos) o acúmulo de *thunks*
  é irrelevante. Ver limitação L7.

### D9. `filter` antes da dobra
`linhaDoTime ps t = foldl acumular (linhaVazia t) (filter (participou t) ps)`.
O `filter` deixa explícito que só entram as partidas do time; mesmo assim,
`acumular` é **total**: se receber uma partida de que o time não participou,
devolve a linha intacta (`maybe l somar (golsPara ...)`), o que é testado.

### D10. V/E/D com `fromEnum` de `Bool`
`vitorias = vitorias l + fromEnum (pro > contra)` soma 1 ou 0 sem `if` nem `case`.
É conciso e cada comparação ocupa uma linha; as três condições são mutuamente
exclusivas e cobrem todos os casos.

### D11. Critérios de classificação (Brasileirão, sem confronto direto)
1. pontos ↓  2. vitórias ↓  3. saldo de gols ↓  4. gols pró ↓  5. nome ↑

A ordenação é **uma única função** de comparação:
```haskell
criterioClassificacao =
     comparing (Down . pontosLinha)
  <> comparing (Down . vitorias)
  <> comparing (Down . saldo)
  <> comparing (Down . golsPro)
  <> comparing time
```
`Ordering` é um `Monoid` (e funções que devolvem um `Monoid` também são):
`(f <> g) a b` só consulta `g` quando `f a b == EQ`. Isso evita a armadilha de
encadear vários `sortBy` esperando que o último preserve a ordem dos anteriores.
`Down` inverte a ordem para "maior primeiro". O nome em ordem alfabética entra
no fim para que a ordenação seja **total e determinística** (não depende da
ordem das linhas de entrada — há teste para isso).

### D12. Saber *qual* critério desempatou
A lista `criterios :: [(String, Linha -> Linha -> Ordering)]` dá nome a cada
critério. `criterioDecisivo` usa `find` para achar o primeiro que diferencia
duas linhas, e `desempates` aplica isso aos pares **vizinhos** da tabela com os
mesmos pontos (`zip ls (drop 1 ls)` + `filter` + `map`). Mantivemos
`criterioClassificacao` escrita por extenso com `<>` (mais fácil de ler e de
explicar); um teste garante que ela ordena exatamente como a lista `criterios`.

### D13. `aproveitamento` em `Double`, de 0 a 100
`100 * fromIntegral pontos / fromIntegral (3 * jogos)`. `fromIntegral` faz a
ponte `Int → Double` (usar `div` truncaria; usar `/` em `Int` não compila).
Se `jogos == 0`, devolve `0` em vez de dividir por zero (`NaN`).

### D14. Estatísticas totais (sem `head`, `maximum`, `foldr1`)
- `maiorGoleada = listToMaybe . sortOn (Down . diferencaGols)`: `listToMaybe`
  é a versão total de `head`; `sortOn` é estável, então em caso de empate na
  diferença vence a **primeira** partida da lista (testado). Custa O(n log n)
  em vez de O(n), troca aceitável pela clareza.
- `mediaGols [] = Nothing`; caso contrário, `Just (total / quantidade)`.
- `lider = listToMaybe . classificacao`.

### D15. `ateRodada` inclusiva
`ateRodada n = filter ((<= n) . rodada)` — "até a rodada 3" inclui a 3.
`ateRodada 0` devolve `[]` e um `n` além da última rodada devolve tudo (testados).
No `main`, a rodada intermediária é `(últimaRodada + 1) div 2` (3, num campeonato de 5).

---

## Camada 3 — Leitura, validação e saída

### D16. Todo `Erro` carrega o número da linha
O número é o da linha **no texto original**, contando comentários e linhas em
branco — o mesmo que o usuário vê no editor. `TimeRepetidoNaRodada` carrega
linha, **rodada** e time. Além dos cinco construtores exigidos, há `TimeVazio`
(`3;;1;0;Paraná`) e `RodadaInvalida` (rodada < 1), dois erros reais que, sem
eles, passariam como dados válidos. `descreverErro` gera a mensagem legível e
`linhaDoErro` permite ordenar o relatório.

### D17. `lerPartida` em `do` na mônada `Either`
Ordem das verificações: 5 campos → rodada numérica → rodada ≥ 1 → mandante não
vazio → placares numéricos e não negativos → visitante não vazio → times
diferentes. O primeiro `Left` interrompe o resto, sem "escadinha" de `case`.
Pequenos auxiliares (`cincoCampos`, `lerNumero`, `lerPlacar`, `lerTime`,
`exigir`) mantêm cada passo em uma linha.

### D18. `lerNumero`: `readMaybe` + `Integer` + `maybe`
`readMaybe s >>= caberEmInt` lê como `Integer` (Maybe como **mônada**) e só
aceita se couber em `Int`: `read`/`readMaybe` direto para `Int` daria a volta
silenciosamente em `"99999999999999999999"`. `maybe (Left ...) Right` converte
o `Maybe` em `Either`. Rejeita `"dois"`, `"2a"`, `"2.0"`, `"+2"` e `""`.

### D19. `separar` com `foldr`
Cada caractere ou abre um novo campo (separador) ou entra no campo atual.
`separar ';' "a;;b" == ["a","","b"]` e `separar ';' "" == [""]`: campos vazios são
preservados, o que permite detectar `TimeVazio` e contar campos corretamente.
Os campos passam por `aparar` (remove espaços e o `\r` de arquivos do Windows).

### D20. `lerCampeonato` × `todosOsErros`
- `lerCampeonato` usa `traverse` (para no **primeiro** erro de linha) e, se todas
  as linhas forem válidas, procura times repetidos na mesma rodada; devolve o
  primeiro com `listToMaybe` + `maybe`.
- `todosOsErros` lê **todas** as linhas, separa erros e partidas válidas com
  `partitionEithers`, procura repetições entre as válidas e ordena tudo por linha.
- A repetição é sempre acusada na **segunda** ocorrência (`inits` dá, para cada
  partida, as anteriores), apontando a linha que de fato está errada.

### D21. Campeonato vazio é válido
Um texto só com comentários/brancos devolve `Right []`. A tabela formatada
mostra "(tabela vazia...)" e as estatísticas devolvem `Nothing`. Consideramos
que "campeonato que ainda não começou" é um estado legítimo, não um erro.

### D22. `tabelaFormatada` sem `printf`
`Text.Printf` não está entre os módulos listados no enunciado. O alinhamento
usa `replicate` e o decimal é formatado por `mostrarDecimal` (arredonda com
`round` em `Integer`; `mostrarDecimal 1 (200/3) == "66.7"`). A largura da coluna
"Time" é calculada com `foldr (max . length . time)`, não com `maximum`.

### D23. `main` é a única função com `IO`
Todo o relatório é montado por `demonstracao :: String -> String -> String`
(pura). `main` só: (1) ajusta a codificação para UTF-8; (2) usa os dados de
`Dados.hs` ou, se receber um argumento, lê o arquivo; (3) imprime. Falha de
leitura do arquivo é capturada com `try` e vira um aviso — o programa segue com
os dados embutidos. Os módulos extras usados **só no `Main`** (`System.IO`,
`System.Environment`, `Control.Exception`, `GHC.IO.Encoding`) são todos do
pacote `base`; o núcleo (Camadas 1–3) usa apenas `Data.List`, `Data.Char`,
`Data.Maybe`, `Data.Either`, `Data.Ord` e `Text.Read`.

---

## Limitações conhecidas

- **L1. Nomes de times são comparados literalmente.** `Paraná`, `Parana` e
  `paraná` são três times diferentes; não há normalização de maiúsculas ou acentos.
- **L2. Sem confronto direto, cartões ou sorteio.** O Brasileirão usa ainda
  confronto direto, menos cartões e sorteio. O confronto direto exigiria olhar
  as partidas entre os times empatados; não foi implementado. O desempate final
  por nome é uma convenção nossa para tornar a ordem determinística.
- **L3. Coerência do calendário não é verificada.** Só checamos que ninguém joga
  duas vezes na mesma rodada. Não verificamos se o mesmo confronto se repete,
  se todos jogam todas as rodadas, nem se há "buracos" (rodada 1 e 3 sem a 2).
- **L4. `lerCampeonato` e `todosOsErros` podem discordar sobre o "primeiro" erro.**
  `lerCampeonato` só procura repetições quando todas as linhas são válidas;
  se a linha 3 repetir um time e a linha 10 tiver um placar inválido,
  `lerCampeonato` acusa a linha 10 e `todosOsErros` lista a 3 primeiro.
- **L5. Formato rígido.** Separador fixo `;` (um nome de time não pode conter
  `;`); `02` é aceito como 2; não há limite superior "realista" para o placar.
- **L6. Complexidade quadrática em dois pontos.** `nub` (em `times`) e a busca de
  repetições (`errosDeRodada`, que compara cada partida com as anteriores) são
  O(n²). Para 380 jogos isso é desprezível; para milhões de linhas, seria
  preciso `Data.Map`/`Data.Set` (pacote `containers`, fora do permitido).
- **L7. Campos de `Linha` são preguiçosos.** A dobra cria *thunks* que só são
  avaliados na impressão. Irrelevante para campeonatos reais; com entradas
  enormes, campos estritos (`!Int`) + `foldl'` seriam a correção.
- **L8. Playground não testado por nós.** Validamos no GHC local 9.10.3. A versão
  `playground/Main.hs` compila sem avisos localmente e produz saída idêntica à
  modular, e usa apenas recursos do `base` presentes há muitas versões, mas não
  foi executada no play.haskell.org.
- **L9. Terminal do Windows.** A saída é UTF-8; em consoles com outra página de
  código os acentos aparecem trocados (use `chcp 65001`). Os executáveis
  recém-compilados podem ser bloqueados pelo Smart App Control (use `runghc`).
- **L10. Arquivo lido inteiro na memória** (`readFile`) — adequado ao problema.
