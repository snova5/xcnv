# xcnv / xconvert

A tiny command-line media converter — a friendly wrapper around **ffmpeg** and
**ImageMagick** that turns one file into another with a single command.

```
xcnv input.ext [-c WxH] output.ext
```

It does what ffmpeg does, but with a short, memorable syntax:

```bash
xcnv photo.png photo.jpg                  # png  -> jpg  (same resolution)
xcnv photo.png -c 255x255 photo.ico       # png 1920x1080 -> ico 255x255
xcnv clip.mp4 clip.webm                   # mp4  -> webm
xcnv song.mp3 song.ogg                    # mp3  -> ogg
xcnv anim.gif -c 480x480 anim.mp4         # gif  -> mp4
xcnv video.mp4 -c 640x360 frame.png       # video -> still image
```

With no `-c`, the original resolution is kept: a 1920x1080 PNG becomes a
1920x1080 JPG.

## Install

### Linux
```bash
git clone <this-repo> xcnv
cd xcnv
install -Dm755 xcnv ~/.local/bin/xcnv
ln -sf ~/.local/bin/xcnv ~/.local/bin/xconvert   # optional short alias
```
Make sure `~/.local/bin` is in your `PATH`.

Requirements: `ffmpeg` and ImageMagick (`magick`, i.e. ImageMagick 7).

```bash
# Fedora
sudo dnf install ffmpeg ImageMagick
# Debian / Ubuntu
sudo apt install ffmpeg imagemagick
# Arch
sudo pacman -S ffmpeg imagemagick
```

### Windows
Requirements: `ffmpeg` and ImageMagick in `PATH`
(`winget install Gyan.FFmpeg` and `winget install ImageMagick.ImageMagick`).

Then copy `xcnv.ps1` + `xcnv.bat` somewhere in `PATH` and call:
```powershell
xcnv.bat photo.png -c 255x255 photo.ico
```
`xcnv.bat` uses PowerShell 7 (`pwsh`) if present, otherwise Windows
PowerShell, otherwise Git Bash. You can also run `xcnv.ps1` directly:
```powershell
.\xcnv.ps1 photo.png -c 255x255 photo.ico
```

## Usage

```
xcnv <input> [-c WxH] <output>

  -c W x H      resize to WxH pixels (e.g. -c 255x255)
                without -c, the original resolution is kept
  -q, --quiet   no status messages, only errors
  -h, --help    show this help
  -V, --version show version
```

`xconvert` is an alias for `xcnv`.

## Supported formats

| Kind  | Common extensions |
|-------|-------------------|
| Image | png, jpg, jpeg, webp, bmp, tiff, ico, gif, heic, heif, avif, svg, tga, ppm/pgm/pbm, eps |
| Video | mp4, mkv, webm, avi, mov, wmv, flv, m4v, mpg/mpeg, ts, 3gp, ogv |
| Audio | mp3, m4a, aac, wav, flac, ogg, opus, wma, ac3, aiff |

Anything ffmpeg supports generally works too — the lists above are just the
picked defaults.

## Notes

- **ICO**: `xcnv logo.png -c 255x255 logo.ico` writes an ICO with exactly that
  size. Without `-c` it defaults to 256x256.
- **GIF out**: a palette is generated first, so the result looks good.
- **Video codecs**: the tool detects which encoders your ffmpeg actually has
  (libx264 / libopenh264, libvpx-vp9, aac, opus…) and picks the best available
  one, so it also works with minimal ffmpeg builds.
- **Same-extension input/output**: allowed; the file is re-encoded.

## License

MIT
