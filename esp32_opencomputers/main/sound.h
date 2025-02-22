#define SOUND_CHANNEL_BEEP 0
#define SOUND_CHANNEL_TAPE 1
#define SOUND_CHANNEL_BEEPCARD 2
#define SOUND_CHANNEL_NOISECARD 2 + 8
#define SOUND_CHANNEL_SOUNDCARD 2 + 8 + 8

void sound_computer_beep(uint16_t freq, float time);
void sound_computer_beepString(char* text, size_t len);