class_name Layers
extends RefCounted
## Bits das camadas de fisica 2D.
## Espelham os nomes em [layer_names] do project.godot -- se mudar la,
## mude aqui tambem.
##
## Uso:
##     collision_layer = Layers.ENEMY
##     collision_mask = Layers.WORLD | Layers.PLAYER

const WORLD := 1 << 0
const PLAYER := 1 << 1
const ENEMY := 1 << 2
const INTERACTABLE := 1 << 3
const HITBOX := 1 << 4
const HURTBOX := 1 << 5