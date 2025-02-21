alphabet = ''.join(chr(i) for i in range(256)) + "абвгдеёжзийклмнопрстуфхцчшщьыъэюяАБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЬЫЪЭЮЯ"

def findChar(char):
	prefix = format(ord(char), '04X') + ":"
	with open("font.hex", 'r', encoding='utf-8') as file:
		for line in file:
			if line.startswith(prefix):
				return line[len(prefix):].strip()
	return None

def convertChar(hex_string):
    hex_string = hex_string.strip().upper()
    byte_array = bytearray(int(hex_string[i:i+2], 16) for i in range(0, len(hex_string), 2))
    return byte_array

def rasterizeChar(binary_string):
    for byte in binary_string:
        print(byte)

for char in alphabet:
	rasterizeChar(convertChar(findChar(char)))