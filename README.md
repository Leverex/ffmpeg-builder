# FFmpeg builder
This build script will create a static [FFmpeg](https://ffmpeg.org) 
build using [Docker](https://www.docker.com) and can easily be 
integrated with Gitlab CI.

## Requirements
- Docker: https://docs.docker.com/install/

## How to use
Rename or copy the `.env.example` file to `.env` and adjust it according 
your needs.

Then run the following command to start building FFmpeg.

```
docker run --rm -it \
  --name ffmpeg-builder \
  --hostname ffmpeg-builder \
  --volume $(pwd):/data \
  alpine:3.12 /data/build.sh
```

Find the static binaries inside the `dist` directory.

## What is included?
- libass
- libfontconfig
- libfreetype
- libfribidi
- libx264
- libx265
- libfdk-aac
- libmp3lame
- libogg
- libvorbis
- libvpx

## License
This code is released under GPLv2. Please checkout the source code to 
examine license headers. 
