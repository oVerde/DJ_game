extends Node

class_name DJLogger

var test_id: String = ""
var path: String = ""
var path_sensoriality: String = ""
const CSV_HEADER := "test,whereX,whereY,datetime,type,typeof,payload\n"

func _pad2(n: int) -> String:
	var s = str(n)
	return s if s.length() >= 2 else "0" + s

func start_new_session(test_number: int = 0) -> void:
	# Agora guarda em res://testes/ (pasta do projeto)
	var base_dir = "res://testes/"
	var abs_dir = ProjectSettings.globalize_path(base_dir)
	var dir = DirAccess.open(abs_dir)
	if dir == null:
		DirAccess.make_dir_recursive_absolute(abs_dir)
		dir = DirAccess.open(abs_dir)
	var max_n = 0
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.begins_with("teste") and file_name.ends_with("-sensemaking.csv"):
				var num_str = file_name.substr(5, file_name.length() - 20) # "teste"=5, "-sensemaking.csv"=15
				var n = int(num_str)
				if n > max_n:
					max_n = n
			file_name = dir.get_next()
		dir.list_dir_end()
	var next_n = max_n + 1
	if test_number > 0:
		next_n = test_number
	test_id = str(next_n)
	path = abs_dir + "/teste" + test_id + "-sensemaking.csv"
	path_sensoriality = abs_dir + "/teste" + test_id + "-sensoriality.csv"

	if not FileAccess.file_exists(path):
		var f = FileAccess.open(path, FileAccess.WRITE)
		f.store_string(CSV_HEADER)
		f.close()
	if not FileAccess.file_exists(path_sensoriality):
		var f2 = FileAccess.open(path_sensoriality, FileAccess.WRITE)
		f2.store_string(CSV_HEADER)
		f2.close()

func _iso_datetime() -> String:
	var dt = Time.get_datetime_dict_from_system()
	return str(dt.year) + "-" + _pad2(dt.month) + "-" + _pad2(dt.day) + "T" + _pad2(dt.hour) + ":" + _pad2(dt.minute) + ":" + _pad2(dt.second)

func _escape_csv_field(s: String) -> String:
	var escaped = s.replace('"', '""')
	return '"' + escaped + '"'

func log_entry(type_label: String, type_label_detail: String, payload: Variant, pos: Variant = null) -> void:
	# pos opcional: Vector2 com posição do jogador; se for null, escreve -1,-1
	var dt = _iso_datetime()
	var whereX = -1
	var whereY = -1
	if pos != null and typeof(pos) == TYPE_VECTOR2:
		whereX = int(pos.x)
		whereY = int(pos.y)

	var payload_str = JSON.stringify(payload)
	var payload_field = _escape_csv_field(payload_str)
	var line = str(test_id) + "," + str(whereX) + "," + str(whereY) + "," + dt + "," + type_label + "," + type_label_detail + "," + payload_field + "\n"

	if FileAccess.file_exists(path):
		var f = FileAccess.open(path, FileAccess.READ_WRITE)
		f.seek_end()
		f.store_string(line)
		f.close()
	else:
		var f = FileAccess.open(path, FileAccess.WRITE)
		f.store_string(CSV_HEADER)
		f.store_string(line)
		f.close()

# --- SENSORIALITY LOGGING ---
func log_sensoriality(type_label: String, type_label_detail: String, payload: Variant, pos: Variant = null) -> void:
	var dt = _iso_datetime()
	var whereX = -1
	var whereY = -1
	if pos != null and typeof(pos) == TYPE_VECTOR2:
		whereX = int(pos.x)
		whereY = int(pos.y)
	var payload_str = JSON.stringify(payload)
	var payload_field = _escape_csv_field(payload_str)
	var line = str(test_id) + "," + str(whereX) + "," + str(whereY) + "," + dt + "," + type_label + "," + type_label_detail + "," + payload_field + "\n"
	if FileAccess.file_exists(path_sensoriality):
		var f = FileAccess.open(path_sensoriality, FileAccess.READ_WRITE)
		f.seek_end()
		f.store_string(line)
		f.close()
	else:
		var f = FileAccess.open(path_sensoriality, FileAccess.WRITE)
		f.store_string(CSV_HEADER)
		f.store_string(line)
		f.close()

# Convenience wrappers
func log_event(type_label_detail: String, payload: Variant, pos: Variant = null) -> void:
	log_entry("event", type_label_detail, payload, pos)

func log_action(type_label_detail: String, payload: Variant, pos: Variant = null) -> void:
	log_entry("action", type_label_detail, payload, pos)

func log_state(type_label_detail: String, payload: Variant, pos: Variant = null) -> void:
	log_entry("state", type_label_detail, payload, pos)

# --- SENSORIALITY wrappers ---
func log_object_touched(object_id: String, is_key_item: bool, pos: Variant = null) -> void:
	# action, object_touched, object_ID, is_key_item
	log_sensoriality("action", "object_touched", {"object_ID": object_id, "is_key_item": is_key_item}, pos)

func log_location_entered(room_id: int, pos: Variant = null) -> void:
	# event, location_entered, room_ID
	log_sensoriality("event", "location_entered", {"room_ID": room_id}, pos)
