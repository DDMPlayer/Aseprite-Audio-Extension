# Aseprite Audio Extension

Hello, I'm DDMPlayer! Aseprite Audio Extension (AAE) is an external program that allows users to sync Aseprite's timeline with an audio file, making animation with audio significantly easier and faster to achieve. The tool also allows users to export video files of their animation. Hopefully this can be useful for anybody!


# Installation

## Requirements
- [Godot Engine 4.4](https://godotengine.org/)
- Windows*
- An [FFmpeg binary](https://ffmpeg.org/download.html) (feel free to compile or download one)

To install the project:
- clone or download and extract the source code for this repository;
- add the FFmpeg executable to the root of the project under the filename "ffmpeg.exe"; and
- add it as a project in Godot.


The final project folder should look something like this:
```
.
├── .build (optional folder, not added by default)
├── .promo (used for the source assets)
├── addons
├── fonts
├── scripts
├── textures
├─  .gitattributes
├─  .gitignore
├─  etc...
├─  ffmpeg.exe
```

\* This tool has been developed exclusively in Windows, and as such, I did not test out any other operating system. I tried to keep the code cross-platform, but it's very likely functionality may not work as expected in other operating systems.


# Building

Export an executable as you would with any Godot project, but add the FFmpeg executable under the name "ffmpeg.exe" at the export path.


# Credits

- Aseprite Audio Extension v2.2.1 by [DDMPlayer](https://bsky.app/profile/ddmplayer.bsky.social)
- Aseprite font (as a .ttf) by [haloflooder](https://www.youtube.com/user/haloflooder) (not affiliated)
- Better Processes plugin by [GreenFox](https://gitlab.com/greenfox) (not affiliated)
- AAE v2.x is powered by the [Godot 4 Engine](https://godotengine.org/) (not affiliated)
- [Aseprite](https://www.aseprite.org/) by Igara Studio (not affiliated)
- [Idea for pinning waveform](url=https://itch.io/post/10289107) by [ijsje22](https://ijsje22.itch.io/) (not affiliated)


# License

This software is licensed under the MIT License. See [the license file](LICENSE.md).

Copyright 2025 DDMPlayer

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
