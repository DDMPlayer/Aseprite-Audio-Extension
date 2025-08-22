extends Node

var error := "";

func load_path(path : String) -> AudioStream:
	error = "";
	
	if(!FileAccess.file_exists(path)):
		error = "File doesn't exist";
		return null;
	
	var stream : AudioStream;
	match(path.get_extension().to_lower()):
		"ogg":
			stream = AudioStreamOggVorbis.load_from_file(path);
			
		"mp3":
			stream = AudioStreamMP3.load_from_file(path);
			
		"wav":
			stream = AudioStreamWAV.load_from_file(path);
	
	return stream;
