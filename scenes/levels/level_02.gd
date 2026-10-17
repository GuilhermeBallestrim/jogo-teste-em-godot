extends LevelBase
## Fase 2 -- corredores altos e verticais, o oposto da fase 1.
##
## Aqui o pulo curto e o dash são o que dá acesso: os vãos horizontais são
## largos demais para pular e as plataformas estão empilhadas. Três
## voadores patrulham no alto e dois arqueiros cobrem o chão.
##
## Nada de fluxo de jogo aqui: vem do [LevelBase]. Os valores
## (`coins_to_win`, `camera_limits`) são do Inspector.

const LEVEL_ID := &"level_02"