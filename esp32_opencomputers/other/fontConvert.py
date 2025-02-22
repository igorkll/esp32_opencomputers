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

def rasterizeChar(binchar):
	charlen = len(binchar)
	if charlen >= 32:
		for i in range(0, charlen, 2):
			print(format(binchar[i], '08b').replace('1', '#').replace('0', ' ') + format(binchar[i+1], '08b').replace('1', '#').replace('0', ' '))
	else:
		for byte in binchar:
			print(format(byte, '08b').replace('1', '#').replace('0', ' '))

with open("../filesystem/font.bin", 'wb') as file:
	for char in alphabet:
		char_code = bytearray(char.encode('utf-8'))
		binchar = convertChar(findChar(char))
		charlen = len(binchar)

		print(f"---- {char} / {list(char_code)}")
		rasterizeChar(binchar)

		metadata = 0
		if charlen >= 32:
			metadata += 1

		file.write(bytearray(metadata))
		file.write(bytearray(len(char_code)))
		file.write(char_code)
		file.write(binchar)