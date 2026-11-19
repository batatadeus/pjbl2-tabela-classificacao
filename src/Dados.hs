-- =============================================================================
-- DADOS: campeonato de teste (como String, para funcionar tambem no
-- playground, que nao tem entrada pelo teclado)
-- =============================================================================
-- Campeonato Paranaense ficticio: 6 times, 5 rodadas, turno unico (todos
-- contra todos, 3 jogos por rodada, ninguem joga duas vezes na mesma rodada).
--
-- Casos de borda cobertos de proposito:
--   * empate em 0 x 0 ............ R1 Parana 0 x 0 Operario
--   * vitoria por 3+ gols ......... R3 Cascavel 0 x 5 Athletico (maior goleada)
--   * empate em PONTOS decidido por SALDO:
--       Athletico e Coritiba, 10 pts e 3 vitorias cada; saldo +7 x +3
--   * empate em PONTOS decidido por VITORIAS (mesmo com saldo pior):
--       Operario e Parana, 7 pts; Operario 2V (saldo 0) x Parana 1V (saldo +2)
--   * empate em PONTOS e VITORIAS decidido por SALDO na rodada 3:
--       Londrina e Cascavel, 0 pts; saldo -5 x -8
--   * lider muda: Coritiba lidera apos a 3a rodada, Athletico termina em 1o
--   * time invicto (Parana) e time sem vitorias (Cascavel)
--   * comentarios, linha em branco e espacos extras (ignorados pela leitura)
module Dados
  ( dadosCampeonato
  , dadosComErros
  , dadosVazio
  ) where

-- | Campeonato valido usado na demonstracao e nos testes.
dadosCampeonato :: String
dadosCampeonato = unlines
  [ "# rodada;mandante;gols mandante;gols visitante;visitante"
  , "# ---------------- Rodada 1 ----------------"
  , "1;Coritiba;2;0;Cascavel"
  , "1;Athletico;3;1;Londrina"
  , "1;Paraná;0;0;Operário"
  , ""
  , "# ---------------- Rodada 2 ----------------"
  , "2;Coritiba;1;0;Londrina"
  , "2;Cascavel;1;2;Operário"
  , "2;Athletico;1;1;Paraná"
  , ""
  , "# ---------------- Rodada 3 ----------------"
  , "3;Coritiba;2;1;Operário"
  , "3;Londrina;0;2;Paraná"
  , "3;Cascavel;0;5;Athletico"
  , ""
  , "# ---------------- Rodada 4 ----------------"
  , "4;Coritiba;2;2;Paraná"
  , "4;Operário;2;1;Athletico"
  , "4; Londrina ; 1 ; 1 ; Cascavel "
  , ""
  , "# ---------------- Rodada 5 ----------------"
  , "5;Coritiba;0;1;Athletico"
  , "5;Paraná;1;1;Cascavel"
  , "5;Operário;0;1;Londrina"
  ]

-- | Texto com erros de digitacao: pelo menos um de cada construtor de Erro.
--   As linhas 2 e 7 sao validas e servem de referencia para a repeticao.
dadosComErros :: String
dadosComErros = unlines
  [ "# entrada com erros de digitacao"                 -- linha 1
  , "1;Coritiba;2;1;Athletico"                         -- linha 2  (ok)
  , "1;Paraná;dois;0;Operário"                         -- linha 3  NumeroInvalido
  , "1;Londrina;1;1"                                   -- linha 4  CamposInvalidos
  , "2;Cascavel;-1;0;Londrina"                         -- linha 5  PlacarNegativo
  , "2;Operário;1;1;Operário"                          -- linha 6  MesmoTime
  , "2;Athletico;0;0;Paraná"                           -- linha 7  (ok)
  , "2;Coritiba;3;0;Athletico"                         -- linha 8  TimeRepetidoNaRodada
  , "0;Coritiba;1;0;Paraná"                            -- linha 9  RodadaInvalida
  , "3;;1;0;Paraná"                                    -- linha 10 TimeVazio
  ]

-- | Campeonato sem nenhuma partida (so comentarios e linhas em branco).
dadosVazio :: String
dadosVazio = unlines
  [ "# campeonato ainda nao comecou"
  , ""
  ]
