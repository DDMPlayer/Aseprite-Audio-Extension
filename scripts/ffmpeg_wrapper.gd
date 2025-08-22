extends Node

var ffmpeg_path := OS.get_executable_path().get_base_dir().path_join("ffmpeg.exe");

func _ready() -> void:
	if(OS.is_debug_build()):
		ffmpeg_path = Util.user_folder.path_join("ffmpeg.exe");
	
	verify_ffmpeg();



func generate_waveform(stream : AudioStream, path : String) -> ImageTexture:
	if(!verify_ffmpeg()): return;
	
	var waveform_path := Util.user_folder.path_join("waveform.png");
	var out := [];
	var error_code = OS.execute(ffmpeg_path, [
		"-i", path,
		"-filter_complex", "compand=gain=10,showwavespic=s=" + str(int(stream.get_length() * 32)) + "x32",
		waveform_path, "-y"
	], out);
	
	if(error_code == 0):
		return ImageTexture.create_from_image(Image.load_from_file(waveform_path));
	
	return null;



func verify_ffmpeg() -> bool:
	if(!FileAccess.file_exists(ffmpeg_path)):
		Util.show_error_window("Couldn't find FFmpeg.", "Couldn't find ffmpeg.exe under Aseprite Audio Extension's download location. Double-check your installation and try again.");
	
	return FileAccess.file_exists(ffmpeg_path);


func run_export_command(audio_path : String, export_path : String) -> void:
	var duration := 0.0;
	
	var file := FileAccess.get_file_as_string(Util.temp_folder.path_join("concat.txt")).replace("\r","").split("\nduration ");
	for duration_entry : String in file:
		var current_duration : float = float(duration_entry.split("\n")[0]);
		duration += current_duration;
	
	var concat := Util.temp_folder.path_join("concat.txt");
	var output := export_path; #Util.temp_folder.path_join("output.mp4");
	
	var args_ffmpeg := PackedStringArray([
		"-y",
		"-loglevel", "debug",
		"-f", "concat", "-safe", "0",
		"-i", concat,										# Image
		"-i", audio_path,						# Audio
		#"-vf", "\"scale=2:2:flags=neighbor\"",
		"-fps_mode", "vfr",
		"-c:v", "libx264", "-pix_fmt", "yuv420p",
		"-t", str(duration),
		output,												# Output
	]);
	
	#var process_node := ProcessNode.new();
	#
	#add_child(process_node);
	#
	#process_node.stdout.connect(update_export_progress);
	#process_node.stderr.connect(update_export_progress);
	#
	#process_node.cmd = ffmpeg_path;
	#process_node.args = args_ffmpeg;
	#
	#process_node.start();
	#
	#var out = (await process_node.finished);
	#process_node.queue_free();
	#return out;
	
	print("\"" + ffmpeg_path + "\"", " ", " ".join(args_ffmpeg));
	OS.execute(ffmpeg_path, args_ffmpeg);
	

var last_frame := 0;
func update_export_progress(byte_array : PackedByteArray) -> void:
	var string := byte_array.get_string_from_utf8();
	if(string.contains("frame=")):
		var frame : int = int(string.split("frame=")[1].split(" QP")[0]);
		get_tree().current_scene.update_export_progress(float(frame + 1) / float(Aseprite.frame_max));
