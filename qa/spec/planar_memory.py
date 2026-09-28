"""VGA read latches and planar writes, independent of the driver's renderer."""
from unicorn import UC_HOOK_INSN, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE, UC_MEM_WRITE
from unicorn import x86_const as reg


class PlanarMemory:
    def __init__(self, machine, planes):
        self.planes = [bytearray(plane) for plane in planes]
        self.bank = 0
        self.mask = 15
        self.index = 0
        self.gc = [0] * 9
        self.gc[8] = 255
        self.latches = [0] * 4
        self.reads = []
        machine.uc.hook_add(UC_HOOK_INSN, self.out, None, 1, 0, reg.UC_X86_INS_OUT)
        machine.uc.hook_add(UC_HOOK_INSN, self.input, None, 1, 0, reg.UC_X86_INS_IN)
        machine.uc.hook_add(UC_HOOK_MEM_READ | UC_HOOK_MEM_WRITE, self.memory,
                            begin=0xa0000, end=0xaffff)

    def out(self, uc, port, size, value, user):
        if port == 0x3c4:
            assert size == 2 and value & 255 == 2
            self.mask = value >> 8
            return
        assert port == 0x3ce and size in (1, 2)
        self.index = value & 255
        assert self.index in (0, 1, 4, 5, 8)
        if size == 2:
            self.gc[self.index] = value >> 8

    def input(self, uc, port, size, user):
        assert port == 0x3cf and size == 1
        return self.gc[self.index]

    def memory(self, uc, access, address, size, value, user):
        assert address + size <= 0xb0000
        offset = self.bank * 65536 + address - 0xa0000
        if access != UC_MEM_WRITE:
            self.reads.append((address, size))
            self.latches = [plane[offset + size - 1] for plane in self.planes]
            uc.mem_write(address, bytes(self.planes[self.gc[4]][offset:offset + size]))
            return
        mode = self.gc[5] & 3
        assert mode in (0, 3)
        if mode == 3 or self.gc[8] != 255:
            assert size == 1, 'Masked VGA writes require a fresh latch for each byte'
        for column, data in enumerate(value.to_bytes(size, 'little')):
            mask = self.gc[8] & (data if mode == 3 else 255)
            for plane in range(4):
                if self.mask & (1 << plane):
                    color = data
                    if mode == 3 or self.gc[1] & (1 << plane):
                        color = 255 if self.gc[0] & (1 << plane) else 0
                    self.planes[plane][offset + column] = (
                        (color & mask) | (self.latches[plane] & (255 ^ mask)))
