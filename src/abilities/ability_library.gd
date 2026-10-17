class_name AbilityLibrary
extends RefCounted
## Catalogo de habilidades desbloqueaveis.

static var _abilities: Array[Ability] = []
static var _loaded := false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_abilities = [
		Ability.make(&"double_jump", "Pulo duplo", "Permite um segundo salto no ar.", 50),
		Ability.make(&"heavy_dash", "Dash carregado", "Segurar o dash o torna mais longo.", 80),
		Ability.make(&"parry_plus", "Parry melhorado", "Janela de parry 2x maior.", 60),
		Ability.make(&"glide", "Planagem", "Segurar o pulo no ar desacelera a queda.", 40),
	]


static func all_ids() -> Array[StringName]:
	_ensure_loaded()
	var out: Array[StringName] = []
	for a in _abilities:
		out.append(a.id)
	return out


static func definition(id: StringName) -> Ability:
	_ensure_loaded()
	for a in _abilities:
		if a.id == id:
			return a
	return null


static func has(id: StringName) -> bool:
	return definition(id) != null