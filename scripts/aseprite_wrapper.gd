extends Node

var process_node : ProcessNode;
var script_path := Util.user_folder.replace("AsepriteAudioExtension", "Aseprite").path_join("scripts/aseprite-audio-extension.lua");
var path := "";
var sprite_path := "";
var is_finished := true;
var previously_opened := false;

var stop_timer := 0.0;
var is_paused := true;
var raw_position := 0.0;

func _ready() -> void:
	process_node = ProcessNode.new();
	process_node.finished.connect(set_finished);
	process_node.stdout.connect(handle_stdout);
	add_child(process_node);



func _process(delta: float) -> void:
	is_paused = stop_timer <= 0.0;
	if(!is_paused):
		stop_timer -= delta;



func activate() -> void:
	if(!guarantee_aseprite_path()): return;
	if(!guarantee_script_file()): return;
	
	var args := PackedStringArray([
		"-verbose",
		"-script",
		script_path
	]);
	
	process_node.cmd = path;
	process_node.args = args;
	
	await get_tree().create_timer(0.1).timeout;
	
	previously_opened = true;
	is_finished = false;
	process_node.start();



func guarantee_aseprite_path() -> bool:
	if(!FileAccess.file_exists(path)):
		Util.show_error_window("Couldn't find Aseprite.", "Couldn't find Aseprite. Please double-check the path.");
	
	return FileAccess.file_exists(path);



func guarantee_script_file() -> bool:
	var script := FileAccess.open(script_path, FileAccess.WRITE);
	if(script != null):
		script.store_string(FileAccess.get_file_as_string("res://lua_script.txt"));
		script.close();
		
	var error := FileAccess.get_open_error();
	if(error != OK):
		print("FAILED TO WRITE THE FILE. HOWEVER!!! THE PATH IS: ", script_path);
		show_err(error);
		return FileAccess.file_exists(script_path);
	
	return FileAccess.file_exists(script_path);



func show_err(error : Error) -> void:
	var err_string := "";
	match(error):
		ERR_FILE_NOT_FOUND:
			err_string = "Not found.";
		ERR_FILE_BAD_DRIVE:
			err_string = "Bad drive.";
		ERR_FILE_BAD_PATH:
			err_string = "Bad path.";
		ERR_FILE_NO_PERMISSION:
			err_string = "No permission.";
		ERR_FILE_ALREADY_IN_USE:
			err_string = "Already in use.";
		ERR_FILE_CANT_OPEN:
			err_string = "Can't open.";
		ERR_FILE_CANT_WRITE:
			err_string = "Can't write.";
		ERR_FILE_CANT_READ:
			err_string = "Can't read.";
		ERR_FILE_UNRECOGNIZED:
			err_string = "Unrecognized.";
		ERR_FILE_CORRUPT:
			err_string = "Corrupt.";
		ERR_FILE_MISSING_DEPENDENCIES:
			err_string = "Missing dependencies.";
		ERR_FILE_EOF:
			err_string = "End of file (EOF).";
	
	Util.show_error_window("Error", "An error has occurred while trying to write the lua script. Below is the error message:\n\n" + err_string);



var previous_command := "";
func handle_stdout(string_raw : PackedByteArray) -> void:
	var string := string_raw.get_string_from_utf8();
	previous_command += string;
	print(previous_command);
	
	var process_strings := previous_command.trim_prefix("&").split("&");
	var left_over := process_strings[process_strings.size() - 1];
	process_strings.remove_at(process_strings.size() - 1);
	previous_command = left_over;
	
	for command : String in process_strings:
		process_command(command);


func process_command(raw_command : String) -> void:
	var command : String = raw_command.get_slice(":", 0);
	var value : String = raw_command.trim_prefix(command + ":");
	match(command):
		"p":
			raw_position = float(value) / 1000.0;
		
		"n":
			stop_timer = float(value) / 1000.0 + 0.05;
		
		"s":
			sprite_path = str(value);
		
		"x":
			frame_max = int(value);
			print(frame_max);


func is_sprite_unsaved() -> bool:
	return (!Aseprite.sprite_path.contains("/") && !Aseprite.sprite_path.contains("\\"));


func is_sprite_valid() -> bool:
	return Aseprite.sprite_path != "";


func run_export_command() -> void:
	var arguments := PackedStringArray([
		"-b",
		sprite_path
	]);
	
	if(true):
		arguments.append_array([
			"--scale", "2"
		]);
	
	arguments.append_array([
		"--filename-format",
		"{path}/{frame}--{duration}.{extension}",
		"--save-as",
		Util.temp_folder.path_join("file.png")
	]);
	
	var process_node := ProcessNode.new();
	
	add_child(process_node);
	
	process_node.cmd = path;
	process_node.args = arguments;
	
	finished_export = false;
	process_node.finished.connect(finish_export.bind(process_node));
	process_node.start();
	
	while(update_status()): # """"Threaded"""" while loop.
		await RenderingServer.frame_post_draw;
	
	var files := Array(DirAccess.get_files_at(Util.temp_folder)).filter(func (x): return x.contains("--"));
	files.sort_custom(func (a, b):
		return int(a.get_slice("--", 0)) < int(b.get_slice("--", 0));
	);
	
	var ffmpeg_file := "ffconcat version 1.0"
	for file : String in files:
		var duration := file.get_slice("--", 1).get_slice(".", 0);
		ffmpeg_file += "\nfile '{0}'\nduration {1}".format([
			file, str(float(duration) / 1000.0)
		]);
	
	ffmpeg_file += "\nfile '{0}'".format([files[-1]]);
	
	var file := FileAccess.open(Util.temp_folder.path_join("concat.txt"), FileAccess.WRITE);
	file.store_string(ffmpeg_file);
	file.flush();



func is_open() -> bool:
	return !is_finished;


func set_finished(status: int) -> void:
	is_finished = true;


var frame_max := 0;
var finished_export := false;
func update_status() -> bool:
	var progress := DirAccess.get_files_at(Util.temp_folder).size();
	get_tree().current_scene.update_export_progress(float(progress) / float(frame_max));
	return progress < frame_max || finished_export;


func finish_export(out: int, process_node : Node) -> void:
	finished_export = true;
	process_node.queue_free();
