# FFmetric

[FFmetric](https://github.com/HadiAmirpour/FFmetric?utm_source=chatgpt.com) is an open-source perceptual video quality prediction framework integrated directly into FFmpeg/libx264. The primary objective of FFmetric is to provide lightweight and decoding-free perceptual quality estimation using encoder-side compression statistics in order to enable real-time quality monitoring, adaptive encoding, bitrate ladder generation, and large-scale transcoding applications without requiring decoded frames or reference videos.


    
## Build 

If you don't have the FFmpeg source code already then first you need to obtain the latest revision of the FFmpeg source code from its Git repository:

```ssh
git clone https://git.ffmpeg.org/ffmpeg.git ffmpeg
```


Afterward, or if you already have an FFmpeg source tree, clone this repository.

```ssh
git clone https://github.com/HadiAmirpour/FFmetric
```

The plugin includes `install_vca.sh` shell script to copy vca source files and apply changes to the build files of ffmpeg:

```ssh
./FFmetric/install_vca.sh path/to/ffmpeg
```

Note that neither `install_vca.sh` nor vca source files should be moved to another folder for `install_vca.sh` to work.

Provided all copies and changes were succesful now you can (re)configure and (re)compile FFmpeg according to your operating system and requirements, there is no known conflicts and no special provisions for compilation must be made:

```
cd ffmpeg

./configure

make -j8
```



## Usage 


Example usage:

Use all defaults and output to vca.csv
```ssh
./ffmpeg -i input.mp4 -c:v libx264 -ffmetric output.mp4
```
