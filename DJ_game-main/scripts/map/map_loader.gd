extends Node
class_name MapLoader

## Gerenciador de carregamento de mapas
## Carrega dados dos mapas e gerencia transições

static func load_all_maps() -> Array:
	var maps := []
	
	# Carregar todos os mapas em ordem
	maps.append(MapData01.get_data())
	maps.append(MapData02.get_data())
	maps.append(MapData03.get_data())
	
	# Adicionar max_hp aos inimigos que não têm e realizar verificações de debug
	for map in maps:
		for enemy in map["enemies"]:
			if not enemy.has("max_hp"):
				enemy["max_hp"] = enemy["hp"]
			# Verificar campos obrigatórios
			if not enemy.has("pos") or not enemy.has("hp"):
				print("Warning: enemy missing required fields in map '", map["name"], "': ", enemy)
			else:
				# Verificar se posição está dentro dos limites do mapa
				if not IsometricUtils.is_position_valid(enemy["pos"], map["size"]):
					print("Warning: enemy position out of bounds in map '", map["name"], "': pos=", enemy["pos"], " map_size=", map["size"])
	
	# Resumo de carregamento
	for i in range(maps.size()):
		var m = maps[i]
		print("Loaded map ", i, ": ", m["name"], " enemies=", m["enemies"].size())
	
	return maps

static func get_map_count() -> int:
	return 3  # Atualizar quando adicionar mais mapas

static func is_valid_map_index(index: int) -> int:
	return index >= 0 and index < get_map_count()
