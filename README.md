# xcnv / xconvert

Wrapper rapid pentru `ffmpeg` și `ImageMagick 7+` pentru a converti imagini, videouri, audio direct din terminal.

## Comenzi rapide
- `xcnv` sau `xconvert`

## Utilizare
```bash
xcnv intrare.ext [-c W x H] iesire.ext
```

## Exemple

### Imagini
```bash
xcnv poza.png poza.jpg
xcnv poza.png -c 255x255 icon.ico
xcnv screenshot.png screenshot.webp
```

### Video / Audio
```bash
xcnv clip.mp4 clip.webm
xcnv clip.mp4 -c 640x360 clip_sm.mp4
xcnv song.mp3 song.ogg
```

## Cum funcționează
- Imagini: folosește `magick` (ImageMagick 7)
- Video/Audio: folosește `ffmpeg`
- `-c WxH` forțează resize la dimensiunea exactă (pentru ico/gif sau downscale/upscale rapid)

## Cerințe
- Linux: `imagemagick`, `ffmpeg`
- Windows (WSL/MSYS2/Cygwin/Git Bash): `magick` + `ffmpeg` în PATH
