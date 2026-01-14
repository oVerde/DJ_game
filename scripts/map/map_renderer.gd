extends Node
class_name MapRenderer

## Sistema de renderização isométrica
## Responsável por desenhar tiles, entidades e efeitos visuais

# Cores dos elementos
const COLOR_FLOOR := Color(0.3, 0.3, 0.3, 1)
const COLOR_WALL := Color(0.6, 0.6, 0.6, 1)
const COLOR_PLAYER := Color(0.2, 0.6, 1.0, 1)
const COLOR_DOOR := Color(1.0, 0.8, 0.2, 1)
const COLOR_ENEMY := Color(1.0, 0.2, 0.2, 1)
const COLOR_INTERACT_HINT := Color(1, 1, 1, 0.8)

# Configurações de renderização
var canvas: CanvasItem
var camera_offset: Vector2 = Vector2.ZERO

func _init(p_canvas: CanvasItem):
	canvas = p_canvas
	# Initialize texture manager so floor textures are ready to use
	# Textures are loaded from `res://assets/floor/` via TextureManager
	TextureManager.init()

## Define o offset da câmera
func set_camera_offset(offset: Vector2):
	camera_offset = offset

## Desenha o chão do mapa (usando texturas de piso)
func draw_floor(map_size: Vector2):
	for x in range(map_size.x):
		for y in range(map_size.y):
			var grid_pos := Vector2(x, y)
			var tex := TextureManager.get_floor_texture_for_position(grid_pos)
			var iso_pos := IsometricUtils.cartesian_to_isometric(grid_pos) + camera_offset
			_draw_tile_textured(iso_pos, tex)

## Desenha as paredes do mapa (atualmente usa a mesma textura de piso)
func draw_walls(walls: Array):
	for wall in walls:
		var grid_pos: Vector2 = wall
		var tex := TextureManager.get_floor_texture_for_position(grid_pos)
		var iso_pos := IsometricUtils.cartesian_to_isometric(grid_pos) + camera_offset
		_draw_tile_textured(iso_pos, tex)

## Desenha as portas do mapa (atualmente usa a mesma textura de piso)
func draw_doors(doors: Array):
	for door in doors:
		var grid_pos: Vector2 = door["pos"]
		var tex := TextureManager.get_floor_texture_for_position(grid_pos)
		var iso_pos := IsometricUtils.cartesian_to_isometric(grid_pos) + camera_offset
		_draw_tile_textured(iso_pos, tex)


## Desenha os inimigos no mapa
func draw_enemies(enemies: Array):
	for enemy in enemies:
		if enemy["hp"] > 0:
			var iso_pos := IsometricUtils.cartesian_to_isometric(enemy["pos"]) + camera_offset
			_draw_entity(iso_pos, COLOR_ENEMY)

## Desenha o jogador
func draw_player(player_pos: Vector2):
	var iso_pos := IsometricUtils.cartesian_to_isometric(player_pos) + camera_offset
	_draw_entity(iso_pos, COLOR_PLAYER)

## Desenha dica de interação (tecla E)
func draw_interact_hint(position: Vector2, text: String = "[E] Interagir"):
	var iso_pos := IsometricUtils.cartesian_to_isometric(position) + camera_offset
	iso_pos.y -= 50  # Acima da entidade
	
	# Fundo semi-transparente
	var text_size := Vector2(120, 30)
	var bg_rect := Rect2(iso_pos - text_size / 2, text_size)
	canvas.draw_rect(bg_rect, Color(0, 0, 0, 0.7))
	
	# Texto
	canvas.draw_string(ThemeDB.fallback_font, iso_pos + Vector2(-50, 5), text, 
					   HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COLOR_INTERACT_HINT)

## Desenha um tile isométrico (losango) - (mantido para compatibilidade)
func _draw_tile(iso_pos: Vector2, color: Color):
	# Deprecated for base tile visuals; tiles now use textures.
	# This function is kept for compatibility if any external code still passes colors.
	# It will draw a textured tile instead, preserving the old outline.
	var tex := TextureManager.get_floor_texture()
	_draw_tile_textured(iso_pos, tex)

## Desenha um tile usando uma textura que cobre o tile inteiro
func _draw_tile_textured(iso_pos: Vector2, texture: Texture2D):
	# iso_pos is the center of the diamond tile; compute top-left of the tile rect
	var top_left := iso_pos - Vector2(IsometricUtils.TILE_WIDTH_HALF, IsometricUtils.TILE_HEIGHT_HALF)
	var rect := Rect2(top_left, Vector2(IsometricUtils.TILE_WIDTH, IsometricUtils.TILE_HEIGHT))
	# Draw texture filling the tile rect
	canvas.draw_texture_rect(texture, rect, false)



## Desenha uma entidade (jogador ou inimigo)
func _draw_entity(iso_pos: Vector2, color: Color):
	# Corpo (círculo)
	canvas.draw_circle(iso_pos, 12, color)
	canvas.draw_arc(iso_pos, 12, 0, TAU, 32, Color.BLACK, 2.0)
	
	# Sombra no chão
	var shadow_offset := Vector2(0, IsometricUtils.TILE_HEIGHT_HALF - 5)
	canvas.draw_ellipse(iso_pos + shadow_offset, Vector2(10, 5), Color(0, 0, 0, 0.3))

## Limpa o canvas (chama queue_redraw)
func clear():
	canvas.queue_redraw()

## Estrutura de dados para sorting de profundidade
class DrawableEntity:
	var position: Vector2
	var type: String  # "player", "enemy", "door"
	var data: Variant
	
	func _init(p_pos: Vector2, p_type: String, p_data: Variant = null):
		position = p_pos
		type = p_type
		data = p_data

## Desenha todos os elementos com depth sorting
func draw_scene_sorted(player_pos: Vector2, doors: Array, enemies: Array):
	var entities: Array[DrawableEntity] = []
	
	# Adicionar jogador
	entities.append(DrawableEntity.new(player_pos, "player"))
	
	# Adicionar portas
	for door in doors:
		entities.append(DrawableEntity.new(door["pos"], "door", door))
	
	# Adicionar inimigos vivos
	for enemy in enemies:
		if enemy["hp"] > 0:
			entities.append(DrawableEntity.new(enemy["pos"], "enemy", enemy))
	
	# Ordenar por profundidade
	entities.sort_custom(func(a, b): 
		return IsometricUtils.calculate_depth(a.position) < IsometricUtils.calculate_depth(b.position)
	)
	
	# Desenhar na ordem
	for entity in entities:
		match entity.type:
			"player":
				draw_player(entity.position)
			"door":
				draw_doors([entity.data])
			"enemy":
				draw_enemies([entity.data])
