extends Node

@onready var pn: ProcessNode = $ProcessNode;
@onready var audio: AudioStreamPlayer = $AudioStreamPlayer;
@onready var file_dialog: FileDialog = $FileDialog;
@onready var button_filepath: Label = $Button/Path;
@onready var project_info: Label = $ProjectInfo;
@onready var file_dialog_aseprite : FileDialog = $FileDialog2;

var ex_path = "";
var project_info_map = {}

var aseprite_local = "";
var full_sprite_path = "";
var full_audio_path = null;
var sprite_path = "";
var frame_index = 0;
var base_frame_index = 0;
var frame_rate = 1;
var delay_tolerance = 0.1;
var amounts_restarted = 0;
var expected_frame = 0;
var is_paused = true;

var started = false;

var script_folder_path = OS.get_environment("AppData")+"/Aseprite/scripts/";
var script_file_path = "aseprite-audio-extension.lua";

@onready var user_dir = OS.get_user_data_dir().replace("\\","/") + "/";
@onready var ffmpeg_path = user_dir + "ffmpeg.exe";

func _ready():
	file_dialog_aseprite.connect("file_selected", apply_selected_file);
	
	var array = OS.get_executable_path().replace("\\","/").split("/");
	array.remove_at(array.size()-1);
	ex_path = "/".join(array) + "/";
	print(ex_path);
	
	var aseprite_local_path = []
	OS.execute("where",["Aseprite"],aseprite_local_path);
	aseprite_local = aseprite_local_path[0].replace("\n","").replace("\r","");
	
	var proj_info_file = FileAccess.open(ex_path+"/projects.json", FileAccess.READ);
	if(proj_info_file != null):
		var json_map = JSON.parse_string(proj_info_file.get_as_text(true));
		project_info_map = json_map;
	
	var user_data = FileAccess.open(ex_path+"/aseprite-path.txt", FileAccess.READ);
	if(user_data):
		aseprite_local = user_data.get_as_text(true);
		aseprite_local_path = aseprite_local.split("\n");
		for entry in aseprite_local_path:
			if(!entry.begins_with("#")):
				aseprite_local = entry;
				print(entry);
		
		user_data.close();
	
	if(aseprite_local): $HelpMenu2/LineEdit.text = aseprite_local;

func attempt_script_write():
	var t = Time.get_ticks_msec();
	while(Time.get_ticks_msec() - t < 2000.0):
		pass;
	
	var initial_path = ex_path+"/lua_script.lua"
	var target_path = script_folder_path+script_file_path;
	
	var folder_exists = DirAccess.dir_exists_absolute(script_folder_path);
	if(!folder_exists):
		DirAccess.make_dir_recursive_absolute(script_folder_path);
	
	var error_code = DirAccess.copy_absolute(initial_path, target_path);
	if(error_code != OK && !FileAccess.file_exists(target_path)):
		show_error_window("Error initializing extension files ("+str(error_code)+")",
		"An error occurred while copying the extension's lua script.
		
		This may be a problem with application permissions and can be solved by:
		
		1. manually copying lua_script.lua to Aseprite's scripts folder
		2. running this application with administrative privileges")

func start_aae():
	if(!FileAccess.file_exists(aseprite_local) || !FileAccess.file_exists(script_folder_path+script_file_path)):
		return;
	
	var path_exec = OS.get_executable_path().replace("\\","/").split("/");
	path_exec.remove_at(path_exec.size()-1);
	path_exec = "/".join(path_exec);
	
	var dir = DirAccess.open(path_exec);
	print("AAAAAAAGH")
	print(dir.copy_absolute("./ffmpeg.exe",ffmpeg_path));
	print(ffmpeg_path)
	
	pn.cmd = aseprite_local;
	pn.args = PackedStringArray([
		"-verbose",
		"-script",
		OS.get_environment("AppData")+"/Aseprite/scripts/aseprite-audio-extension.lua"
	]);
	
	await get_tree().create_timer(0.1).timeout;
	
	pn.start();


func _on_process_node_stderr(data):
	print(data.get_string_from_ascii())


func _on_process_node_stdout(data):
	var text: String = data.get_string_from_ascii();
	var lines = text.split("\n");
	for line in lines:
		process_line(line);

func process_line(text):
	if(text.begins_with("AAE-")):
		var args: Array = text.split(":");
		match(args[0]):
			"AAE-F": # Frame index
				if(args.size() <= 2): return;
				
				print("Frame: "+args[1])
				frame_index = float(args[1]);
				frame_rate = float(args[2]);
				amounts_restarted = 0;
				
				if(is_paused || floor(frame_index) < floor(expected_frame)):
					audio.seek(frame_index*frame_rate);
					
				expected_frame = frame_index;
				is_paused = false;
				
			"AAE-S": # New sprite
				if(args.size() <= 1): return;
				args.remove_at(0);
				var path = ":".join(args);
				print("Sprite changed to "+path)
				if(path.begins_with("Sprite")):
					sprite_path = "Unsaved";
					full_sprite_path = "bad";
				else: 
					full_sprite_path = path.replace("\\","/");
					sprite_path = pretty_path(path);
					if(full_sprite_path in project_info_map):
						var audio_path = project_info_map[full_sprite_path];
						_on_file_dialog_file_selected(audio_path);
						
				
			"AAE-P": # New sprite
				if(args.size() <= 1): return;
				print("Properties received: "+args[1])


func _on_process_node_finished(out):
	print(out);

func _process(delta):
	if(!started):
		attempt_script_write.call_deferred();
		start_aae.call_deferred();
		started = true;
		return;
	
	$Button4.disabled = (full_sprite_path == "bad" || full_sprite_path == "");
	
	$TextureRect/Control/TextureRect.position.x = 16 - floor(audio.get_playback_position() * 16)
	
	aseprite_local = $HelpMenu2/LineEdit.text;
	
	if(get_window().always_on_top != $CheckButton.button_pressed):
		get_window().always_on_top = $CheckButton.button_pressed;
	
	if(audio.stream != null):
		$Title2.text = "Project information:";
		
	if(audio.stream == null):
		$Title2.text = "Please select an audio.";
		project_info.text = "";
		return;
	
	if(audio.stream.get_length() < expected_frame*frame_rate):
		audio.stream_paused = true;
		return;
	
	audio.stream_paused = is_paused;
	
	if(abs(expected_frame-frame_index) > max(0.1/frame_rate,1)):
		expected_frame = frame_index;
		is_paused = true;
		
	if(!is_paused): expected_frame += delta/frame_rate;
	if(!audio.stream_paused && !audio.playing): audio.play();
	
	var target = frame_index*frame_rate;
	
	var diff = audio.get_playback_position()-target;
	#audio.pitch_scale = lerp(audio.pitch_scale, 1.0 - diff * frame_rate * 1, delta * 5.0);
	project_info.text = sprite_path+"\n"+"{0} / {1}".format([floor(frame_index*frame_rate*100)/100,floor(audio.stream.get_length()*100)/100]);
	if(!audio.stream_paused && !is_paused):
		if(abs(diff) > max(2.5 * frame_rate, 0.1)):
			print(diff)
			audio.call_deferred("seek", target + frame_rate/5.0)


func _on_button_pressed():
	file_dialog.show();
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_ANY
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM

func _on_file_dialog_file_selected(path):
	var audio_file = AudioLoader.load_path(path);
	$TextureRect/Control/TextureRect.texture = null;
	if(audio_file):
		full_audio_path = path;
		#var image = audio_loader.generate_preview(audio_file)
		#if(image): audio_preview.set_image(image);
		var out = [];
		#"C:\Users\DDMPl\AppData\Roaming\Godot\app_userdata\Aseprite Audio Extension/ffmpeg.exe" -i "C:\Animation Audios\a merry day.mp3" -filter_complex "compand,showwavespic=s=640x120" "C:\Users\DDMPl\AppData\Roaming\Godot\app_userdata\Aseprite Audio Extension/waveform.png" -y
		var error_code = OS.execute(ffmpeg_path, ["-i", path, "-filter_complex", "compand=gain=10,showwavespic=s="+str(floor(audio_file.get_length() * 16))+"x36", user_dir+"waveform.png", "-y"], out)
		print(["-i", path, "-filter_complex", "compand=gain=10,showwavespic=s="+str(floor(audio_file.get_length() * 16))+"x36", user_dir+"waveform.png", "-y"])
		#var error_code = OS.execute(ffmpeg_path, ["--help"], out)
		print(error_code)
		print("\n".join(out))
		if(error_code == 0 || true):
			var img = Image.load_from_file(user_dir+"waveform.png")
			var img_tex = ImageTexture.create_from_image(img)
			$TextureRect/Control/TextureRect.texture = img_tex;
			$TextureRect/Control/TextureRect.size.x = floor(audio_file.get_length() * 16);
			
		button_filepath.text = pretty_path(path);
		audio.stream = audio_file;
	else:
		full_audio_path = null;
		button_filepath.text = "No audio selected.";
		audio.stream = null;
		
	project_info_map[full_sprite_path] = path;
		


func _toggle_menu():
	$HelpMenu.visible = !$HelpMenu.visible;

func pretty_path(path):
	return path.replace("\\","/").split("/").slice(-1)[0];


func _toggle_menu_2():
	$HelpMenu2.visible = !$HelpMenu2.visible;


func _on_button_2_pressed():
	start_aae();

func _notification(what):
	if(what == NOTIFICATION_WM_CLOSE_REQUEST):
		var user_data = FileAccess.open(ex_path+"/aseprite-path.txt", FileAccess.WRITE);
		if(user_data):
			user_data.store_string(aseprite_local);
			user_data.close();


func _on_button_3_pressed():
	file_dialog_aseprite.popup_centered();

func apply_selected_file(file_path):
	aseprite_local = file_path;
	$HelpMenu2/LineEdit.text = aseprite_local;

func update_projects_list():
	var proj_info_file = FileAccess.open(ex_path+"/projects.json", FileAccess.WRITE);
	proj_info_file.store_string(JSON.stringify(project_info_map))


#OS.execute("./ffmpeg/ffmpeg.exe", ["-i", audio.ogg, "-filter_complex", "compand=gain=-6,showwavespic=s=1280x240:colors=blue,drawbox=x=(iw-w)/2:y=(ih-h)/2:w=iw:h=1:replace=1:color=blue-frames:v", "1", waveform.png, "-y"], true)

func _on_button_4_pressed(): #export button
	if(full_sprite_path == "bad" || full_sprite_path == "" && full_audio_path != null):
		return;
	
	$ExportMenu.visible = true;
	
	var path = full_sprite_path.replace("\r","")
	var end_path = user_dir+"export/";
	
	if(OS.get_name() == "Windows"):
		path = path.replace("/","\\");
		end_path = end_path.replace("/","\\");
	
	if(DirAccess.dir_exists_absolute(end_path)):
		var files = Array(DirAccess.get_files_at(end_path)).map(func (x):
			var true_path = end_path + x;
			DirAccess.remove_absolute(true_path);
			await get_tree().create_timer(0.1).timeout;
		);
	
	await get_tree().create_timer(1.0).timeout;
	DirAccess.make_dir_recursive_absolute(end_path);
	
	var args = ["--batch", path, "--save-as", end_path + "frame0001.png"];
	print(OS.execute(aseprite_local, args));
	
	await get_tree().create_timer(1.0).timeout;
	#ffmpeg -i frame%d.png -i audio_path output.mp4
	
	var file_count = Array(DirAccess.get_files_at(end_path)).filter(func (x):
		return x.begins_with("frame");
	).size();
	
	# ffmpeg_path -framerate 10 -i frame%04d.png -i "C:\Animation Audios\cutecat.mp3" -vf scale=-2:720:flags=neighbor -c:v libx264 -crf 10 -c:a aac -ar 44100 C:\Users\DDMPl\AppData\Roaming\AsepriteAudioExtension\export\video2.mp4 
	
	var seconds_raw = (float(file_count) * float(frame_rate));
	var milliseconds = floor(fmod(seconds_raw*1000, 1000.0));
	var seconds = floor(fmod(seconds_raw, 60.0));
	var minutes_raw = floor(seconds_raw / 60.0);
	var minutes = floor(fmod(minutes_raw, 60.0));
	var hours = floor(minutes / 60.0);
	
	var time = str(hours).lpad(2, "0") + ":" + str(minutes).lpad(2, "0") + ":" + str(seconds).lpad(2, "0") + "." + str(milliseconds).lpad(3, "0");
	
	var args_ffmpeg = ["-framerate", str(1/frame_rate), "-i", end_path + "frame%04d.png", "-i", full_audio_path, "-vf", "scale=-2:720:flags=neighbor", "-c:v", "libx264", "-c:a", "aac", "-t", time, "-ar", "44100", end_path + "video.mp4", "-y"]
	var ffmpeg_error = OS.execute(ffmpeg_path, args_ffmpeg);
	print(ffmpeg_path + " " + " ".join(args_ffmpeg));
	print(ffmpeg_error);
	
	$ExportMenu.visible = false;
	
	$FileDialog3.show();


func _on_file_dialog_3_file_selected(path):
	if(!path.ends_with(".mp4")): path = path + ".mp4";
	DirAccess.copy_absolute(user_dir+"export/video.mp4", path);
