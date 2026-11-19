-- =============================================================================
-- CAMADA 1: Tipos e Dados do Campeonato
-- =============================================================================
-- Modela o dominio com tipos algebricos (records e tipos soma) e define as
-- consultas basicas sobre uma partida. Nenhuma funcao aqui e parcial.
module Tipos
  ( Time
  , Resultado (..)
  , Partida (..)
  , Linha (..)
  , participou
  , resultadoPara
  , golsPara
  , times
  , linhaVazia
  ) where

import Data.List (nub, sort)

-- | Nome de um time (sinonimo de tipo).
type Time = String

-- | Resultado de uma partida do ponto de vista de um time.
--   Tipo soma fechado: nao existe um "v" minusculo nem um 4o valor.
data Resultado = Vitoria | Empate | Derrota
  deriving (Show, Eq, Ord, Enum, Bounded)

-- | Uma partida. Record com campos nomeados, para que os gols do mandante
--   nunca sejam confundidos com os do visitante (o que uma tupla de Ints
--   permitiria sem nenhum aviso do compilador).
data Partida = Partida
  { rodada        :: Int
  , mandante      :: Time
  , golsMandante  :: Int
  , golsVisitante :: Int
  , visitante     :: Time
  } deriving (Show, Eq)

-- | Uma linha da tabela de classificacao.
--   Guarda apenas contagens primitivas; pontos e saldo sao DERIVADOS
--   (Camada 2) para que nunca fiquem inconsistentes com V/E/D e GP/GC.
data Linha = Linha
  { time       :: Time
  , jogos      :: Int
  , vitorias   :: Int
  , empates    :: Int
  , derrotas   :: Int
  , golsPro    :: Int
  , golsContra :: Int
  } deriving (Show, Eq)

-- | Linha "zerada" de um time: elemento neutro da dobra da Camada 2.
linhaVazia :: Time -> Linha
linhaVazia t = Linha t 0 0 0 0 0 0

-- | Verdadeiro se o time jogou a partida (como mandante ou visitante).
participou :: Time -> Partida -> Bool
participou t p = t == mandante p || t == visitante p

-- | Gols (pro, contra) do ponto de vista do time; Nothing se nao jogou.
golsPara :: Time -> Partida -> Maybe (Int, Int)
golsPara t p
  | t == mandante p  = Just (golsMandante p, golsVisitante p)
  | t == visitante p = Just (golsVisitante p, golsMandante p)
  | otherwise        = Nothing

-- | Resultado do ponto de vista do time; Nothing se ele nao jogou.
--   Usa Maybe como functor: o resultado e calculado "dentro" do Just.
resultadoPara :: Time -> Partida -> Maybe Resultado
resultadoPara t p = uncurry classificar <$> golsPara t p
  where
    classificar pro contra = case compare pro contra of
      GT -> Vitoria
      EQ -> Empate
      LT -> Derrota

-- | Todos os times do campeonato, sem repeticao e em ordem alfabetica.
times :: [Partida] -> [Time]
times = sort . nub . concatMap (\p -> [mandante p, visitante p])
