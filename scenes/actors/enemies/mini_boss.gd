extends Boss
## Mini-boss: versao menor do boss, para fases intermediarias.
##
## Reusa toda a logica do boss, so com menos vida e menos dano. Existe para
## dar um clima de "chefinho" sem exigir uma arena dedicada.

func _ready() -> void:
	super._ready()
	max_health = 8
	health = max_health
	body_color = Color(0.65, 0.3, 0.45)
	body_size = Vector2(50, 40)
	if _shape.shape is RectangleShape2D:
		(_shape.shape as RectangleShape2D).size = body_size
	slam_radius = 120.0
	slam_damage = 1
	barrage_count = 3