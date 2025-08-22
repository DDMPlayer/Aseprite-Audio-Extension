extends Node

var user_folder := OS.get_user_data_dir() + "/";
var temp_folder := user_folder.path_join("temp");

func show_file_select(file_mode : FileDialog.FileMode, filters : PackedStringArray = [], default_path := "") -> String:
	var file_dialog := FileDialog.new();
	add_child(file_dialog);
	
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM;
	file_dialog.use_native_dialog = true;
	file_dialog.filters = filters;
	file_dialog.file_mode = file_mode;
	
	if(default_path):
		file_dialog.current_path = default_path;
	
	file_dialog.show();
	
	var data = (await file_dialog.file_selected);
	file_dialog.queue_free();
	return data;



func show_error_window(title, description):
	var window : Window = load("res://error_window.tscn").instantiate();
	window.size = window.size * 2.0;
	window.get_node("Main/Title").text = "ERROR: "+title;
	window.get_node("Main/Title2").text = description;
	call_deferred("add_child", window);
	
	window.always_on_top = true;
	window.close_requested.connect(window.queue_free);
