extends LevelBase
## Fase 1 -- corredores baixos e largos, com vãos de 160 a 200 px.
##
## Tudo que não é dado da fase (reset, pausa, vitória, derrota) vem do
## [LevelBase]. Os valores (`coins_to_win`, `camera_limits`) são adjustados
## no Inspector, não aqui: redeclarar um `@export` do pai é erro de parse.

## Moedas para vencer. A fase tem 12 no total.
const LEVEL_ID := &"level_01"