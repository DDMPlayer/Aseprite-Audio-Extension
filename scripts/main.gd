extends Node

@onready var audio_player : AudioStreamPlayer = $Audio;
@onready var waveform : TextureRect = $MainMenu/WaveformRect/WaveformParent/Waveform;
@onready var info : Label = $MainMenu/Control/InfoText;
@onready var status : Label = $MainMenu/Control/StatusText;

var extension_path := "";
var aseprite_path := "" : set = set_aseprite_path;
var audio_path := "" : set = set_audio_path;

var route_to_credits := false : set = set_route_to_credits;
var settings := {
	"aseprite_path": "",
	"is_first_time": true,
};


func _ready() -> void:
	extension_path = OS.get_executable_path().get_base_dir() + "/";
	
	var cmd_aseprite_path = [];
	OS.execute("where", ["Aseprite"], cmd_aseprite_path);
	aseprite_path = cmd_aseprite_path[0].replace("\n","").replace("\r","");
	
	load_settings();
	
	if(aseprite_path):
		_on_activate_pressed.call_deferred();
	
	var is_first_time : bool = settings["is_first_time"];
	settings["is_first_time"] = false;
	
	if(is_first_time):
		_on_setup_pressed.call_deferred();
		set.call_deferred("route_to_credits", true);



func _process(delta: float) -> void:
	var scaler := 999999999999999999;
	RenderingServer.canvas_item_set_custom_rect($MainMenu/WaveformRect/WaveformParent/Waveform.get_canvas_item(), true, Rect2(
		-Vector2.ONE * scaler,
		Vector2(2.0, 2.0) * scaler
	));
	$MainMenu/Control/Export.disabled = (audio_path == "" || aseprite_path == "");
	
	var surpassed_audio_length := (audio_player.stream && Aseprite.raw_position > audio_player.stream.get_length());
	audio_player.stream_paused = Aseprite.is_paused || surpassed_audio_length;
	
	if(!Aseprite.is_paused && !audio_player.playing && !surpassed_audio_length):
		audio_player.play(Aseprite.raw_position - AudioServer.get_output_latency());
	
	if(
		abs(audio_player.get_playback_position() - Aseprite.raw_position) > Aseprite.stop_timer + AudioServer.get_output_latency() + delta ||
		Aseprite.is_paused
	):
		audio_player.seek(Aseprite.raw_position - AudioServer.get_output_latency());
	
	$MainMenu/WaveformRect/WaveformParent/Waveform.position.x = -Aseprite.raw_position * 32.0 + 16.0;
	
	var sprite_text := "Sprite: " + Aseprite.sprite_path.get_file().get_basename();
	if(Aseprite.is_sprite_unsaved()): sprite_text += " (unsaved)";
	if(Aseprite.sprite_path == ""): sprite_text = "No sprite selected.";
	info.text = "\n".join([
		str(int(Aseprite.raw_position / 60)) + ":" + str(int(Aseprite.raw_position) % 60).pad_zeros(2) + "." + str(int(Aseprite.raw_position * 1000) % 1000).pad_zeros(3),
		("PAUSED" if Aseprite.is_paused else "")
	]);
	
	if(audio_path == ""): sprite_text = "No audio selected.";
	if(!Aseprite.is_open()):
		sprite_text = "Connection lost! Please {0} Aseprite.".format(["reactivate" if Aseprite.previously_opened else "activate"])
		status.add_theme_color_override("font_color", Color.RED);
	else:
		status.remove_theme_color_override("font_color");
	status.text = sprite_text;



func set_aseprite_path(new_path : String) -> void:
	if(!FileAccess.file_exists(new_path)):
		audio_path = "";
		Aseprite.path = "";
		return;
	
	aseprite_path = new_path;
	settings["aseprite_path"] = aseprite_path;
	$PathMenu/PathText.text = aseprite_path;
	Aseprite.path = aseprite_path;
	
	if(!DirAccess.dir_exists_absolute(Aseprite.script_path.get_base_dir()) && DirAccess.dir_exists_absolute(aseprite_path.get_base_dir().path_join("scripts"))):
		Aseprite.script_path = aseprite_path.get_base_dir().path_join("scripts/aseprite-audio-extension.lua");


func set_audio_path(new_path : String) -> void:
	var stream := AudioLoader.load_path(new_path);
	var file_display : Label = $MainMenu/Control/LoadAudio/Path;
	audio_player.stream = stream;
	waveform.texture = null;
	
	if(stream == null):
		file_display.text = "No file selected.";
		audio_path = "";
		return;
	
	file_display.text = new_path.get_file();
	audio_path = new_path;
	
	waveform.texture = (await FFmpeg.generate_waveform(stream, audio_path));


func open_menu(control_name : String) -> void:
	for child : Node in get_children():
		if(child.name.contains("Menu")):
			child.visible = (child.name == control_name);


func _on_setup_pressed() -> void:
	open_menu("PathMenu");

func _on_credits_pressed() -> void:
	open_menu("HelpMenu");

func _on_export_pressed() -> void:
	if(audio_path == ""):
		Util.show_error_window("No audio selected.", "No audio file has been picked. Please pick an audio file before proceeding.");
		return;
		
	if(!Aseprite.is_sprite_valid()):
		Util.show_error_window("No sprite selected.", "No sprite is active in Aseprite. Navigate to a sprite before proceeding.");
		return;
		
	if(Aseprite.is_sprite_unsaved()):
		Util.show_error_window("Unsaved sprite.", "The active sprite is not saved to disk. Please save your sprite before proceeding.");
		return;
		
	var export_path = (await Util.show_file_select(FileDialog.FileMode.FILE_MODE_SAVE_FILE, ["*.mp4"], Aseprite.sprite_path.get_basename() + ".mp4"));
		
	open_menu("ExportMenu");
	update_export_progress(0.0);
	
	await RenderingServer.frame_post_draw;
	
	if(!Aseprite.guarantee_aseprite_path()): return;
	if(!FFmpeg.verify_ffmpeg()): return;
	
	if(!DirAccess.dir_exists_absolute(Util.temp_folder)):
		DirAccess.make_dir_recursive_absolute(Util.temp_folder);
	
	var dir_access := DirAccess.open(Util.temp_folder);
	for file : String in DirAccess.get_files_at(Util.temp_folder):
		dir_access.remove(file);
	
	await Aseprite.run_export_command();
	await FFmpeg.run_export_command(audio_path, export_path);
	
	open_menu("MainMenu");
	

func _on_back_pressed() -> void:
	if(route_to_credits):
		if($HelpMenu.visible):
			route_to_credits = false;
		
		else:
			open_menu("HelpMenu");
			return;
	
	open_menu("MainMenu");

func _on_load_audio_pressed() -> void:
	audio_path = (await Util.show_file_select(FileDialog.FileMode.FILE_MODE_OPEN_FILE, ["*.mp3", "*.ogg", "*.wav"]));

func _on_select_file_pressed() -> void:
	aseprite_path = (await Util.show_file_select(FileDialog.FileMode.FILE_MODE_OPEN_FILE, ["Aseprite.exe"]));

func _on_activate_pressed() -> void:
	Aseprite.activate();
	_on_back_pressed();


func _on_help_clicked(meta: Variant) -> void:
	OS.shell_open(meta);


var previous_state := DisplayServer.WINDOW_MODE_WINDOWED;
func _on_display_toggled(toggled_on: bool) -> void:
	$MainMenu/Support.visible = !toggled_on;
	$Dragger.visible = toggled_on;
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, toggled_on);
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, toggled_on);
	
	if(toggled_on):
		previous_state = DisplayServer.window_get_mode();
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);
		DisplayServer.window_set_min_size(Vector2i.ONE);
		DisplayServer.window_set_size(Vector2i(DisplayServer.window_get_size().x,  28 * 2));
	
	else:
		DisplayServer.window_set_mode(previous_state);
		DisplayServer.window_set_min_size(Vector2i(64, 64));
		DisplayServer.window_set_size(Vector2i(DisplayServer.window_get_size().x, 144 * 2));


var base_dragging_position := Vector2i.ZERO;
var last_press_timer := 0.0;
func _on_control_gui_input(event: InputEvent) -> void:
	if(event is InputEventMouseButton):
		if(event.pressed):
			if(Time.get_ticks_msec() - last_press_timer < 500):
				$MainMenu/WaveformRect/AlwaysOnTop2.button_pressed = !$MainMenu/WaveformRect/AlwaysOnTop2.button_pressed;
			
			last_press_timer = Time.get_ticks_msec();
		
		base_dragging_position = DisplayServer.mouse_get_position() - DisplayServer.window_get_position();
	
	if(event is InputEventMouseMotion):
		if(Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
			DisplayServer.window_set_position(DisplayServer.mouse_get_position() - base_dragging_position);
			
		
func load_settings() -> void:
	var file := FileAccess.open("user://settings.json", FileAccess.READ);
	if(file == null):
		open_menu("HelpMenu");
		return;
	
	var saved_settings = JSON.parse_string(file.get_as_text(true));
	for setting in saved_settings:
		settings[setting] = saved_settings[setting];
	
	aseprite_path = settings["aseprite_path"];


func _notification(what: int) -> void:
	if(what == NOTIFICATION_CRASH || what == NOTIFICATION_WM_CLOSE_REQUEST):
		save_settings();


func save_settings() -> void:
	var file := FileAccess.open("user://settings.json", FileAccess.WRITE);
	file.store_string(JSON.stringify(settings));


func _on_path_text_text_changed(new_text: String) -> void:
	aseprite_path = $PathMenu/PathText.text;


func set_route_to_credits(value: bool) -> void:
	route_to_credits = value;
	
	var text := "Continue" if route_to_credits else "Back";
	$HelpMenu/Back.text = text;
	$PathMenu/Back.text = text;



func update_export_progress(progress: float) -> void:
	%ExportProgress.size.x = lerp(0.0, %ExportProgress.get_parent().size.x, progress);
