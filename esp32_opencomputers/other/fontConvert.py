alphabet = ''.join(chr(i) for i in range(256)) + "абвгдеёжзийклмнопрстуфхцчшщьыъэюяАБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЬЫЪЭЮЯ" + "█"

"""
alphabet = ""
with open("font.hex", 'r', encoding='utf-8') as file:
	for line in file:
		unicode_code, _ = line.split(":", 1)

		try:
			byte_sequence = bytes.fromhex(unicode_code)

			if len(byte_sequence) == 2:
				alphabet = alphabet + byte_sequence.decode('utf-8')
		except ValueError:
			pass
"""

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
		for i in range(16):
			print(format(binchar[i*2], '08b').replace('1', '#').replace('0', ' ') + format(binchar[(i*2)+1], '08b').replace('1', '#').replace('0', ' '))
	else:
		for byte in binchar:
			print(format(byte, '08b').replace('1', '#').replace('0', ' '))

with open("../filesystem/font.bin", 'wb') as file:
	waitList = []
	moveLimit = 256
	for char in alphabet:
		char_code = bytearray(char.encode('utf-8'))
		binchar = convertChar(findChar(char))
		charlen = len(binchar)

		if moveLimit > 0 and charlen >= 32:
			waitList.append(char)

			file.write(bytearray([2]))
			file.write(bytearray([0]))
			file.write(bytearray([0]))
			file.write(b'\0' * 16)
		else:
			print(f"---- {list(char_code)}")
			rasterizeChar(binchar)

			file.write(bytearray([0]))
			file.write(bytearray([len(char_code)]))
			file.write(char_code)
			file.write(binchar)

		moveLimit = moveLimit - 1

	for char in waitList:
		char_code = bytearray(char.encode('utf-8'))
		binchar = convertChar(findChar(char))
		charlen = len(binchar)

		print(f"---- {list(char_code)}")
		rasterizeChar(binchar)

		metadata = 0
		if charlen >= 32:
			metadata += 1

		file.write(bytearray([metadata]))
		file.write(bytearray([len(char_code)]))
		file.write(char_code)
		file.write(binchar)