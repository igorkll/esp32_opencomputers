// ---------------------------------------------- render settings

#define RENDER_RESOLUTION_X 80
#define RENDER_RESOLUTION_Y 25
#define RENDER_PIXEL_PERFECT false

// ---------------------------------------------- sound settings

#define SOUND_DAC //it says that we are going to use DAC for audio output. please comment if you don't need audio output
#define SOUND_MASTER_VOLUME 16 //0-255
#define SOUND_FREQ 40000 //how often will the hardware timer responsible for sound generation work
#define SOUND_OUTPUT 0 //DAC CHANNEL

// ---------------------------------------------- hardware settings (all parameters are optional, remove the define that you don't need)

#define HARDWARE_LED_POWER_PIN 18
#define HARDWARE_LED_POWER_INVERT false

#define HARDWARE_LED_ERROR_PIN 18
#define HARDWARE_LED_ERROR_INVERT false

#define HARDWARE_LED_HDD_PIN 19
#define HARDWARE_LED_HDD_INVERT false

// ---------------------------------------------- hardware display settings

#define DISPLAY_FREQ 80000000
#define DISPLAY_HOST SPI2_HOST
#define DISPLAY_MISO 12
#define DISPLAY_MOSI 13
#define DISPLAY_CLK  14
#define DISPLAY_DC   21
#define DISPLAY_CS   22
#define DISPLAY_RST  33 //comment if you connected this pin to the microcontroller RST
#define DISPLAY_BL   4

#define DISPLAY_WIDTH  480
#define DISPLAY_HEIGHT 320

#define DISPLAY_SWAP_ENDIAN true
#define DISPLAY_SWAP_RGB    true
#define DISPLAY_INVERT      true
#define DISPLAY_FLIP_X      true
#define DISPLAY_FLIP_Y      false
#define DISPLAY_FLIP_XY     false
#define DISPLAY_ROTATION    1
#define DISPLAY_OFFSET_X    0
#define DISPLAY_OFFSET_Y    0
#define DISPLAY_INVERT_BL   false

// ---------------------------------------------- hardware touchscreen settings

#define TOUCHSCREEN_FT6336U
#define TOUCHSCREEN_SDA   5
#define TOUCHSCREEN_SCL   27
#define TOUCHSCREEN_HOST  I2C_NUM_0
#define TOUCHSCREEN_ADDR  0x38
#define TOUCHSCREEN_RST   23

#define TOUCHSCREEN_FLIP_XY false //swaps X and Y
#define TOUCHSCREEN_MUL_X 0 // if 0, it is counted as 1
#define TOUCHSCREEN_MUL_Y 0
#define TOUCHSCREEN_OFFSET_X 0
#define TOUCHSCREEN_OFFSET_Y 0
#define TOUCHSCREEN_WIDTH 320 //required parameters. the width and height of the touchscreen in pixels
#define TOUCHSCREEN_HEIGHT 480
#define TOUCHSCREEN_FLIP_X false
#define TOUCHSCREEN_FLIP_Y false
#define TOUCHSCREEN_ROTATION 1