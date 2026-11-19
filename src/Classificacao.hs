-- =============================================================================
-- CAMADA 2: Classificacao com Funcoes de Ordem Superior
-- =============================================================================
-- Calcula a tabela de classificacao e estatisticas do campeonato.
-- Regra desta camada: NENHUMA recursao explicita. Tudo e feito com map,
-- filter, dobras (foldl), composicao (.) e sortBy/sortOn com comparing,
-- Down e (<>) -- Ordering e um Monoid.
--
-- Criterios de classificacao (Brasileirao, sem confronto direto):
--   1. mais pontos
--   2. mais vitorias
--   3. maior saldo de gols
--   4. mais gols pro
--   5. ordem alfabetica do nome (desempate final deterministico)
module Classificacao
  ( pontos
  , acumular
  , linhaDoTime
  , pontosLinha
  , saldo
  , aproveitamento
  , criterios
  , criterioClassificacao
  , criterioDecisivo
  , desempates
  , classificacao
  , ateRodada
  , diferencaGols
  , totalGols
  , maiorGoleada
  , mediaGols
  , lider
  , rodadas
  ) where

import Data.List (find, nub, sort, sortBy, sortOn)
import Data.Maybe (fromMaybe, listToMaybe)
import Data.Ord (Down (..), comparing)

import Tipos

-- | Pontos conquistados por resultado: 3 / 1 / 0.
pontos :: Resultado -> Int
pontos Vitoria = 3
pontos Empate  = 1
pontos Derrota = 0

-- | Acrescenta UMA partida a linha de um time. E o passo da dobra.
--   Se o time nao jogou a partida, a linha volta intacta (maybe).
acumular :: Linha -> Partida -> Linha
acumular l p = maybe l somar (golsPara (time l) p)
  where
    somar (pro, contra) = l
      { jogos      = jogos l + 1
      , vitorias   = vitorias l + fromEnum (pro > contra)
      , empates    = empates l + fromEnum (pro == contra)
      , derrotas   = derrotas l + fromEnum (pro < contra)
      , golsPro    = golsPro l + pro
      , golsContra = golsContra l + contra
      }

-- | Linha da tabela de um time, acumulada com foldl sobre as partidas das
--   quais ele participou. foldl porque o acumulador (Linha) e o argumento
--   da ESQUERDA de `acumular`, e as partidas sao somadas da primeira para a
--   ultima, como numa tabela real. (ver docs/decisoes.md: foldl x foldl')
linhaDoTime :: [Partida] -> Time -> Linha
linhaDoTime ps t = foldl acumular (linhaVazia t) (filter (participou t) ps)

-- | Pontos ganhos por uma linha da tabela (reaproveita `pontos`, assim a
--   regra 3/1/0 fica definida num unico lugar).
pontosLinha :: Linha -> Int
pontosLinha l = pontos Vitoria * vitorias l
              + pontos Empate  * empates l
              + pontos Derrota * derrotas l

-- | Saldo de gols: gols pro menos gols contra.
saldo :: Linha -> Int
saldo l = golsPro l - golsContra l

-- | Percentual (0 a 100) dos pontos disputados que o time conquistou.
--   0 se o time nao jogou (evita divisao por zero). fromIntegral faz a
--   ponte Int -> Double; nao ha div truncando o resultado.
aproveitamento :: Linha -> Double
aproveitamento l
  | jogos l == 0 = 0
  | otherwise    = 100 * fromIntegral (pontosLinha l)
                       / fromIntegral (3 * jogos l)

-- | Criterios de classificacao, em ordem de prioridade, com um nome para
--   que a demonstracao possa dizer QUAL criterio decidiu um empate.
--   Down inverte a ordem (maior primeiro); o nome fica em ordem crescente.
criterios :: [(String, Linha -> Linha -> Ordering)]
criterios =
  [ ("pontos",           comparing (Down . pontosLinha))
  , ("vitorias",         comparing (Down . vitorias))
  , ("saldo de gols",    comparing (Down . saldo))
  , ("gols pro",         comparing (Down . golsPro))
  , ("ordem alfabetica", comparing time)
  ]

-- | Comparacao por VARIOS criterios numa unica funcao. Funcoes que devolvem
--   Ordering formam um Monoid: (f <> g) x y so consulta g quando f x y == EQ.
--   E a mesma sequencia da lista `criterios` (ha um teste garantindo isso).
criterioClassificacao :: Linha -> Linha -> Ordering
criterioClassificacao =
     comparing (Down . pontosLinha)
  <> comparing (Down . vitorias)
  <> comparing (Down . saldo)
  <> comparing (Down . golsPro)
  <> comparing time

-- | Nome do primeiro criterio que diferencia duas linhas; Nothing se forem
--   identicas em todos os criterios.
criterioDecisivo :: Linha -> Linha -> Maybe String
criterioDecisivo a b = fst <$> find (\(_, cmp) -> cmp a b /= EQ) criterios

-- | Para cada par de times VIZINHOS na tabela com o mesmo numero de pontos,
--   informa qual criterio de desempate colocou um a frente do outro.
desempates :: [Linha] -> [(Time, Time, String)]
desempates ls =
  map explicar (filter mesmosPontos (zip ls (drop 1 ls)))
  where
    mesmosPontos (a, b) = pontosLinha a == pontosLinha b
    explicar (a, b)     = (time a, time b, fromMaybe "nenhum" (criterioDecisivo a b))

-- | Tabela completa, ja ordenada. Composicao: times -> linhas -> ordena.
classificacao :: [Partida] -> [Linha]
classificacao ps = (sortBy criterioClassificacao . map (linhaDoTime ps) . times) ps

-- | Somente as partidas ate a rodada informada (inclusive).
ateRodada :: Int -> [Partida] -> [Partida]
ateRodada n = filter ((<= n) . rodada)

-- | Diferenca absoluta de gols de uma partida.
diferencaGols :: Partida -> Int
diferencaGols p = abs (golsMandante p - golsVisitante p)

-- | Total de gols de uma partida.
totalGols :: Partida -> Int
totalGols p = golsMandante p + golsVisitante p

-- | Partida com a maior diferenca de gols; Nothing para lista vazia.
--   sortOn e estavel: em caso de empate fica a primeira da lista.
--   listToMaybe substitui o `head` (parcial) por uma versao total.
maiorGoleada :: [Partida] -> Maybe Partida
maiorGoleada = listToMaybe . sortOn (Down . diferencaGols)

-- | Media de gols por partida; Nothing para lista vazia.
mediaGols :: [Partida] -> Maybe Double
mediaGols [] = Nothing
mediaGols ps = Just (fromIntegral (sum (map totalGols ps))
                     / fromIntegral (length ps))

-- | Primeiro colocado; Nothing se nao houver partidas.
lider :: [Partida] -> Maybe Linha
lider = listToMaybe . classificacao

-- | Rodadas presentes no campeonato, em ordem crescente e sem repeticao.
rodadas :: [Partida] -> [Int]
rodadas = sort . nub . map rodada
