"""Drive DOSBox's actual keyboard through an isolated X display.

The guest asks for each key over COM1 only when its observation is ready.
This exercises IRQ1 even when an application owns its keyboard interrupt.
"""
import ctypes
import ctypes.util
import json
import os
import select
import shutil
import socket
import struct
import subprocess
import time


class PhysicalKeyboard:
    def __init__(self, directory):
        self.directory = directory
        self.server = socket.socket()
        self.server.bind(('127.0.0.1', 0))
        self.server.listen(1)
        self.port = self.server.getsockname()[1]
        self.client = None
        self.pending = b''
        self.display = None
        self.xvfb = None
        self.log = None
        self.requests = []

    def __enter__(self):
        try:
            assert shutil.which('Xvfb'), 'Physical keyboard tests require Xvfb'
            x11 = ctypes.util.find_library('X11')
            xtst = ctypes.util.find_library('Xtst')
            assert x11 and xtst, 'Physical keyboard tests require libX11 and libXtst'
            self.x = ctypes.CDLL(x11)
            self.t = ctypes.CDLL(xtst)
            self.x.XOpenDisplay.argtypes = [ctypes.c_char_p]
            self.x.XOpenDisplay.restype = ctypes.c_void_p
            self.x.XCloseDisplay.argtypes = [ctypes.c_void_p]
            self.x.XStringToKeysym.argtypes = [ctypes.c_char_p]
            self.x.XStringToKeysym.restype = ctypes.c_ulong
            self.x.XKeysymToKeycode.argtypes = [ctypes.c_void_p, ctypes.c_ulong]
            self.x.XKeysymToKeycode.restype = ctypes.c_uint
            self.x.XSync.argtypes = [ctypes.c_void_p, ctypes.c_int]
            self.t.XTestFakeKeyEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]
            r, w = os.pipe()
            self.log = (self.directory / 'xvfb.log').open('wb')
            try:
                self.xvfb = subprocess.Popen(['Xvfb', '-displayfd', str(w), '-screen', '0',
                                              '800x600x24', '-nolisten', 'tcp'],
                                             pass_fds=(w,), stdout=self.log, stderr=self.log)
                os.close(w)
                w = None
                assert select.select([r], [], [], 5)[0], 'Xvfb did not start'
                self.name = ':' + os.read(r, 32).decode().strip()
            finally:
                os.close(r)
                if w is not None:
                    os.close(w)
            self.display = self.x.XOpenDisplay(self.name.encode())
            assert self.display, f'Cannot open private X display {self.name}'
            (self.directory / 'IRQ.KEY').touch()
            return self
        except BaseException:
            self.__exit__(None, None, None)
            raise

    @property
    def config(self):
        return f'\n[serial]\nserial1=nullmodem server:127.0.0.1 port:{self.port} transparent:1\n'

    def event(self, name, pressed):
        code = self.x.XKeysymToKeycode(self.display, self.x.XStringToKeysym(name.encode()))
        assert code, f'Unknown physical key {name}'
        assert self.t.XTestFakeKeyEvent(self.display, code, pressed, 0)
        self.x.XSync(self.display, 0)

    def poll(self):
        peer = self.client or self.server
        if not select.select([peer], [], [], .05)[0]:
            return
        if self.client is None:
            self.client, _ = self.server.accept()
            return
        data = self.client.recv(128)
        if not data:
            return
        self.pending += data
        while len(self.pending) >= 2:
            key, = struct.unpack('<H', self.pending[:2])
            self.requests.append(key)
            self.pending = self.pending[2:]
            names = {0x50: 'Down', 0x48: 'Up', 0x47: 'Home', 0x4f: 'End',
                     0x4b: 'Left', 0x4d: 'Right', 0x53: 'Delete', 0x0e: 'BackSpace',
                     0x3c: 'F2', 0x3d: 'F3', 0x1c: 'Return', 0x01: 'Escape',
                     0x21: 'f', 0x2d: 'x', 0x22: 'g', 0x12: 'e'}
            name = names[key >> 8]
            alt = key in (0x2100, 0x2d00)
            if alt:
                self.event('Alt_L', True)
            self.event(name, True)
            time.sleep(.06)  # Make and break must remain distinct guest events.
            self.event(name, False)
            if alt:
                self.event('Alt_L', False)
            self.client.sendall(b'\xa5')

    def __exit__(self, *_):
        (self.directory / 'physical-keys.json').write_text(json.dumps(self.requests)+'\n')
        if self.display:
            self.x.XCloseDisplay(self.display)
        if self.xvfb:
            self.xvfb.terminate()
            try:
                self.xvfb.wait(timeout=3)
            except subprocess.TimeoutExpired:
                self.xvfb.kill()
                self.xvfb.wait()
        if self.client:
            self.client.close()
        self.server.close()
        if self.log:
            self.log.close()
