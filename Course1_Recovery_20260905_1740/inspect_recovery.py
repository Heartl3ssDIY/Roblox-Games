import pathlib, struct, re

path = pathlib.Path(__file__).with_name('128350578096458_AutoRecovery_0.rbxl')
data = path.read_bytes()
print('HEADER', repr(data[:32]))

def decompress_lz4(src):
    out = bytearray()
    i = 0
    while i < len(src):
        token = src[i]; i += 1
        length = token >> 4
        if length == 15:
            while True:
                v = src[i]; i += 1; length += v
                if v != 255: break
        out.extend(src[i:i+length]); i += length
        if i == len(src): break
        offset = int.from_bytes(src[i:i+2], 'little'); i += 2
        length = (token & 15) + 4
        if token & 15 == 15:
            while True:
                v = src[i]; i += 1; length += v
                if v != 255: break
        if offset == 0 or offset > len(out): raise ValueError('Invalid LZ4 offset')
        for _ in range(length): out.append(out[-offset])
    return bytes(out)

pos = 32
names = []
while pos + 16 <= len(data):
    kind, compressed, raw, reserved = struct.unpack_from('<4sIII', data, pos)
    pos += 16
    payload = data[pos:pos+(compressed or raw)]
    pos += compressed or raw
    if compressed: payload = decompress_lz4(payload)
    if len(payload) != raw: raise ValueError('Unexpected decoded size')
    if kind == b'PROP':
        length = struct.unpack_from('<I', payload, 4)[0]
        prop = payload[8:8+length]
        if prop == b'Name':
            cursor = 9 + length
            while cursor + 4 <= len(payload):
                n = struct.unpack_from('<I', payload, cursor)[0]; cursor += 4
                name = payload[cursor:cursor+n].decode('utf-8', errors='replace'); cursor += n
                names.append(name)
    if kind == b'END\x00': break
print('INSTANCE NAMES:',len(names))
print('ZONE NAMES:')
for name in sorted(set(names)):
    if re.search(r'zone|course', name, re.I): print(name)
