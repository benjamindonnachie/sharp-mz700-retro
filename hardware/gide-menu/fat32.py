"""Deterministic FAT32 image builder and independent readback inspector."""
import math
import struct

START = 0x9000
SECTORS = 131072  # 64 MiB; enough clusters to be FAT32 with 512-byte clusters.


def short_name(name):
    parts = name.upper().split('.')
    if len(parts) > 2 or not 1 <= len(parts[0]) <= 8 or (len(parts) == 2 and len(parts[1]) > 3):
        raise ValueError('Use an 8.3 filename: '+name)
    if any(c not in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_$~!#%&-{}()@\'`' for part in parts for c in part):
        raise ValueError('Unsupported short filename: '+name)
    return (parts[0].ljust(8)+(parts[1] if len(parts) == 2 else '').ljust(3)).encode('ascii')


class Volume:
    def __init__(self, sectors=SECTORS, start=START):
        self.sectors, self.start, self.spc = sectors, start, 1
        self.reserved, self.fat_sectors = 32, 1
        while True:
            clusters = (sectors-self.reserved-2*self.fat_sectors)//self.spc
            needed = math.ceil((clusters+2)*4/512)
            if needed <= self.fat_sectors: break
            self.fat_sectors = needed
        self.clusters = (sectors-self.reserved-2*self.fat_sectors)//self.spc
        assert 65525 <= self.clusters < 0x0ffffff5
        self.data_start = self.reserved+2*self.fat_sectors
        self.data = bytearray(sectors*512)
        self.fat = [0]*(self.fat_sectors*128)
        self.fat[:2] = [0x0ffffff8, 0xffffffff]
        self.used = set()
        root = self.allocate(1)[0]
        assert root == 2
        self.directories = {'': [root]}
        self.positions = {'': 1}
        b = self.data
        b[:11] = b'\xeb\x58\x90MZ7GIDE '
        struct.pack_into('<HBHBHHBHHHII', b, 11, 512, self.spc, self.reserved, 2, 0,
                         0, 0xf8, 0, 63, 16, start, sectors)
        struct.pack_into('<IHHIHH', b, 36, self.fat_sectors, 0, 0, root, 1, 6)
        b[64:67] = b'\x80\x00\x29'
        struct.pack_into('<I', b, 67, 0x4d5a3730)
        b[71:82] = b'MZ700 FILES'
        b[82:90] = b'FAT32   '
        b[510:512] = b'\x55\xaa'
        b[6*512:7*512] = b[:512]
        entry = bytearray(32); entry[:11] = b'MZ700 FILES'; entry[11] = 8
        self._entry('', 0, entry)

    def cluster_offset(self, cluster):
        return (self.data_start+(cluster-2)*self.spc)*512

    def allocate(self, count, fragmented=False):
        free = [n for n in range(2, self.clusters+2) if n not in self.used]
        if fragmented: free = free[::2]+free[1::2]
        chain = free[:count]
        if len(chain) != count: raise ValueError('FAT volume full')
        self.used.update(chain)
        for i, n in enumerate(chain): self.fat[n] = chain[i+1] if i+1 < count else 0x0fffffff
        return chain

    def _entry(self, directory, index, entry):
        entry = bytearray(entry)
        if not entry[11] & 8:
            for at in (16, 18, 24): struct.pack_into('<H', entry, at, ((2026-1980) << 9) | (11 << 5) | 15)
        chain = self.directories[directory]
        ci, within = divmod(index, self.spc*512//32)
        while ci >= len(chain):
            nxt = self.allocate(1)[0]; self.fat[chain[-1]] = nxt; chain.append(nxt)
        offset = self.cluster_offset(chain[ci])+within*32
        self.data[offset:offset+32] = entry

    def mkdir(self, path):
        path = path.strip('/').upper()
        if path in self.directories: return
        parent, _, name = path.rpartition('/'); self.mkdir(parent)
        cluster = self.allocate(1)[0]
        entry = bytearray(32); entry[:11] = short_name(name); entry[11] = 0x10
        struct.pack_into('<H', entry, 20, cluster >> 16); struct.pack_into('<H', entry, 26, cluster & 65535)
        index = self.positions[parent]; self._entry(parent, index, entry); self.positions[parent] += 1
        self.directories[path], self.positions[path] = [cluster], 2
        for index, target in enumerate((cluster, self.directories[parent][0] if parent else 0)):
            entry = bytearray(32); entry[:11] = (b'.' if index == 0 else b'..').ljust(11, b' ')
            entry[11] = 0x10
            struct.pack_into('<H', entry, 20, target >> 16); struct.pack_into('<H', entry, 26, target & 65535)
            self._entry(path, index, entry)

    def add(self, path, payload, fragmented=False):
        path = path.strip('/').upper(); parent, _, name = path.rpartition('/')
        self.mkdir(parent)
        chain = self.allocate(math.ceil(len(payload)/(self.spc*512)), fragmented)
        for index, cluster in enumerate(chain):
            part = payload[index*self.spc*512:(index+1)*self.spc*512]
            offset = self.cluster_offset(cluster); self.data[offset:offset+len(part)] = part
        entry = bytearray(32); entry[:11] = short_name(name); entry[11] = 0x20
        first = chain[0] if chain else 0
        struct.pack_into('<H', entry, 20, first >> 16); struct.pack_into('<H', entry, 26, first & 65535)
        struct.pack_into('<I', entry, 28, len(payload))
        self._entry(parent, self.positions[parent], entry); self.positions[parent] += 1
        return chain

    def image(self):
        raw = struct.pack('<'+'I'*len(self.fat), *self.fat)
        for copy in range(2):
            at = (self.reserved+copy*self.fat_sectors)*512; self.data[at:at+len(raw)] = raw
        info = bytearray(512)
        struct.pack_into('<I', info, 0, 0x41615252)
        struct.pack_into('<III', info, 484, 0x61417272, self.clusters-len(self.used), next(n for n in range(2, self.clusters+2) if n not in self.used))
        struct.pack_into('<I', info, 508, 0xaa550000)
        self.data[512:1024] = info; self.data[7*512:8*512] = info
        return bytes(self.data)


def inspect(volume):
    """Parse image bytes independently of the builder's allocation state."""
    bps, spc, reserved, fats, roots = struct.unpack_from('<HBHBH', volume, 11)
    assert bps == 512 and not roots and volume[510:512] == b'\x55\xaa'
    fat_sectors, = struct.unpack_from('<I', volume, 36)
    root, = struct.unpack_from('<I', volume, 44)
    data_start = reserved+fats*fat_sectors
    fat = volume[reserved*512:(reserved+fat_sectors)*512]

    def chain(first):
        seen = set()
        while first < 0x0ffffff8:
            if first < 2 or first in seen: raise ValueError('Invalid or cyclic FAT chain')
            seen.add(first)
            at = (data_start+(first-2)*spc)*512
            yield volume[at:at+spc*512]
            first = struct.unpack_from('<I', fat, first*4)[0] & 0x0fffffff

    output, visited = {}, set()
    def directory(prefix, first):
        if first in visited: raise ValueError('Cyclic directory graph')
        visited.add(first)
        for block in chain(first):
            for at in range(0, len(block), 32):
                entry = block[at:at+32]
                if not entry[0]: return
                if entry[0] == 0xe5 or entry[11] & 0x0e or entry[0] == ord('.'): continue
                name = entry[:8].decode().rstrip()+(('.'+entry[8:11].decode().rstrip()) if entry[8:11].strip() else '')
                cluster = (struct.unpack_from('<H', entry, 20)[0] << 16) | struct.unpack_from('<H', entry, 26)[0]
                if entry[11] & 0x10: directory(prefix+name+'/', cluster)
                else:
                    size = struct.unpack_from('<I', entry, 28)[0]
                    output[prefix+name] = (b''.join(chain(cluster)) if cluster else b'')[:size]
    directory('', root)
    return output
