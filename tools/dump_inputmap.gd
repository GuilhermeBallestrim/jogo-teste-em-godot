extends SceneTree
## Diagnostico: imprime como o Godot interpretou cada acao do Input Map.
##   godot --headless --path . --script res://tools/dump_inputmap.gd

func _process(_delta: float) -> bool:
	print("=== INPUT MAP ===")
	for action in InputMap.get_actions():
		if not InputMap.has_action(action):
			continue
		print("acao: %s" % action)
		for event in InputMap.action_get_events(action):
			print("    -> %s" % [event])
			if event is InputEventKey:
				print("       keycode=%s physical_keycode=%s label=%s device=%s" % [
					event.keycode, event.physical_keycode, event.key_label, event.device,
				])
				print("       -> de volta: %s" % OS.get_keycode_string(event.physical_keycode))
			elif event is InputEventJoypadMotion:
				print("       axis=%s value=%s" % [event.axis, event.axis_value])
			elif event is InputEventMouseButton:
				print("       button_index=%s" % event.button_index)
	print("=== FIM ===")
	return true