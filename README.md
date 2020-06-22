# Digital Piano VHDL MIDI Player 

This is my final university project that I had developed while I was coursing my last year in Computer Engineering (*Universidad Complutense de Madrid, Facultad de Informática*) . It consist in a MIDI file hardware interpreter. In order to play MIDI files, this system implements a piano keyboard with 88 keys that can generate the sound of each note as well. The generated sound is mono with a quality of 48,8Khz and 16 bit per sample, and the sonority corresponds to a piano. This system is also able to apply a reverb effect on the sound generated by Itself. The design allows the configuration of both, a maximum number of compatible MIDI tracks and the polyphony degree (maximum number of notes that can be played at the same time). This system has been developed using the Digilent Nexys 4 DDr's FPGA board, the Pmod BT2 and the Pmod I2S2.

Besides, using an android app as an external interface, allow the user to play notes and chords generated by the MIDI interpreter. This external interface can also upload MIDI files to the system to play them at the same time you play notes or chords. This app includes two buttons to play/stop the MIDI file interpretation and to start/stop the reverb effect. 

Due to the before-mentioned features, we can refer to this project as a hardware design of a basic digital piano.

The android app is named as MySoc, and is located in the GitHub repository that follows: https://github.com/fernandoka/MySoc-Android-app


## Purpose

The purpose of this project is the creation of a base open-design to develop a polyphonic digital keyboard that can play a MIDI files. 

This project aims to be a solid base for future improvements in MIDI file compatibility. At the same time, this project intends to be the first approach to wavetable sound synthesis which is commonly used in current digital pianos. 

The hardware design is developed to be implemented in an FPGA platform, allowing the component reconfiguration of the system. This design follows a modular philosophy and could be configured to adjust the polyphony degree and the maximum number of MIDI tracks that the system can play.

## Requirements

* Digilent boards, **Nexys 4 DDR** or **Nexys A7**: [Nexys 4 DDR reference manual](https://reference.digilentinc.com/reference/programmable-logic/nexys-4-ddr/start) and [Nexys A7 reference manual](https://reference.digilentinc.com/reference/programmable-logic/nexys-a7/start)
* **Vivado 2018.2 Installation** : [Xilinx Vivado downloads](https://www.xilinx.com/support/download/index.html/content/xilinx/en/downloadNav/vivado-design-tools/archive.html)
* **MicroUSB Cable**
* **Pmod BT2** : [Digilent Pmod BT2 reference manual](https://reference.digilentinc.com/reference/pmod/pmodbt2/reference-manual?redirect=1)
* **Pmod I2S2** : [Digilent Pmod I2S2 reference manual](https://reference.digilentinc.com/reference/pmod/pmodi2s2/reference-manual)
* **Android Phone** : To use the external interface

## Setup
1. Download and extract the first release 7z files from this repository's [Releases Page](https://github.com/fernandoka/Digital-Piano-VHDL-MIDI-Player/releases).
2. Open the project in Vivado 2018.2 by double clicking on the included XPR file found at "\<archive extracted location\>/MIDI_Soc/MIDI_Soc.xpr".
3. In the Flow Navigator panel on the left side of the Vivado window, click **Open Hardware Manager**.
4. Plug the Nexys 4 DDR or Nexys A7 into the computer using a MicroUSB cable.
6. In the green bar at the top of the Vivado window, click **Open target**. Select **Auto connect** from the drop down menu.
7. Select the entry **s25fl128sxx...x0-spi-x1_x2_x4** in the Hardware Window, and click the right button of the mouse.
8. Click the entry **Program Configuration Memory Device...** and select in the corresponding fields of the new window, the .mcs and .prm files included in **MIDI_Soc-FlashConfig.7z**.
7. Click the buttons **Apply** and after **OK**. The write process of the flash memory will start, just wait.
8. Disconenct the board from the PC and configure the JP1 to **QSPI**.
9. Connenct the board to the PC and wait until the FPGA is configured with the .bit file which is included in the .mcs file.
10. Now Nexys 4 DDR or Nexys A7 is programmed with this project. The first thing to do is press the BTNC button in order to store in ram memory all the data that is needed to play a MIDI file.

| Button | Function                                                          |
| ------ | ----------------------------------------------------------------- |
| BTNU   | Start/Stop playing MIDI file                                      |
| BTNC   | Start ram memory inicialization                                   |                                    
| BTNL   | Start/Stop reverb effect		                             |
| BTND   | Turn On/Off the bluethooth connection with the external interface |

12. To upload MIDI files to the board, you should try to use the [app MySoc](https://github.com/fernandoka/MySoc-Android-app). If not you can also use your PC to establish a serial port connection via bluehtooth (using a terminal emulator software, [Tera Term](https://osdn.net/projects/ttssh2/releases/) is what I usually use) and then send the corresponding codes. The next list shows the differents code pattern to interact with the board: 

| Function | Hexadecimal Codes                              |
| -------- | -----------------------------------------------|
| Start/Stop playing MIDI file    | 7E			    |
| Start/Stop reverb effect        | 5F		            |
| Note On                         | 02 nn 0v                |                     
| Note Off                        | 01 nn 0v                |                    
| Upload MIDI file to the system  | 67 *"MIDI file raw data"* |

- *nn* corresponds with the note code. Possible values are defined by the interval (hex numbers) [15, 6C]
- *v* corresponds with the note intensity (volume). Possible values are (hex numbers):
    - *0* : Normal
    - *1* : Very soft
    - *2* : soft
    - *4* : Hight
    - *8* : Very hight

## Additional Notes
The sound samples that this project use, are originally .wav files from the [FreePats project](http://freepats.zenvoid.org/Piano/acoustic-grand-piano.html) and the orignal author of these audio recording files, is Alexander Holm.

Downloaded from the "Salamander Grand Piano" section

File entry in the site -> "1.18GiB Best quality. 48kHz 24bit samples"
