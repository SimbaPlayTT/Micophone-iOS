"""Use the pinned, unmodified receiver parser over real loopback UDP.

PortAudio is stubbed only at import; no physical sound output is claimed here.
The real receiver's _udp_loop, _claim, _on_audio and JitterBuffer are exercised.
"""
import importlib.util
import json
from pathlib import Path
import socket
import struct
import sys
import threading
import time
import types
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.modules.setdefault('sounddevice', types.ModuleType('sounddevice'))
spec = importlib.util.spec_from_file_location('pinned_receiver', ROOT / 'Upstream/receiver.py')
rx = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rx)


class ReceiverCompatibilityTests(unittest.TestCase):
    def setUp(self):
        self.f = json.loads((ROOT / 'Tests/Core/Fixtures/protocol-v2.json').read_text())
        self.engine = rx.Engine(usb_tunnel=False, log=lambda _: None)
        self.engine.udp = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.engine.udp.bind(('127.0.0.1', 0))
        self.engine.udp.settimeout(0.1)
        self.pc = self.engine.udp.getsockname()
        self.thread = threading.Thread(target=self.engine._udp_loop)
        self.thread.start()
        self.phone = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.phone.settimeout(1)

    def tearDown(self):
        self.engine.stopped.set()
        self.thread.join(2)
        self.engine.udp.close()
        self.phone.close()

    def hello(self, phone=None):
        phone = phone or self.phone
        phone.sendto(bytes.fromhex(self.f['helloHex']), self.pc)
        return phone.recv(256)

    def wait_received(self, count):
        end = time.monotonic() + 1
        while time.monotonic() < end:
            if self.engine.source and self.engine.source.received >= count:
                return
            time.sleep(0.005)
        self.fail('Receiver did not accept PCM packets')

    def test_fixture_matches_actual_receiver_and_accepts_PCM(self):
        self.assertEqual(bytes.fromhex(self.f['helloHex']), rx.msg(rx.HELLO, struct.pack('<I', 48000) + self.f['phoneName'].encode()))
        self.phone.sendto(rx.msg(rx.DISCOVER), self.pc)
        self.assertEqual(self.phone.recv(256), rx.msg(rx.ANNOUNCE, rx.PC_NAME_B))
        self.assertIsNone(self.engine.source, 'Connecting alone must not claim a microphone source')
        self.assertEqual(self.hello(), rx.msg(rx.ACK, rx.PC_NAME_B))
        self.assertEqual(self.engine.source.rate, 48000)
        self.assertEqual(self.engine.source.name, self.f['phoneName'])
        self.phone.sendto(bytes.fromhex(self.f['audioHex']), self.pc)
        self.wait_received(1)
        self.assertEqual(self.engine.source.seq, self.f['sequence'])
        self.assertEqual(self.engine.source.last_pcm, bytes.fromhex(self.f['pcmHex']))
        self.assertEqual(len(self.engine.jb.buf), 960)
        samples = struct.unpack('<480h', self.engine.source.last_pcm)
        self.assertEqual(samples[:4], (-32768, -1, 0, 32767))

    def test_sequence_wrap_loss_duplicate_and_late_packets(self):
        self.hello()
        pcm = b'\x10\x00' * 480
        for sequence in [65535, 0, 2, 2, 1]:
            self.phone.sendto(rx.msg(rx.AUDIO, struct.pack('<H', sequence) + pcm), self.pc)
        self.wait_received(3)
        time.sleep(0.03)
        self.assertEqual(self.engine.source.received, 3)
        self.assertEqual(self.engine.source.lost, 1)
        self.assertEqual(len(self.engine.jb.buf), 960 * 4, 'One missing packet must be concealed by the actual receiver')

    def test_busy_and_restart_from_new_socket(self):
        self.hello()
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as other:
            other.bind(('127.0.0.2', 0))
            other.settimeout(1)
            self.assertEqual(self.hello(other)[2], rx.BUSY)
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as restarted:
            restarted.settimeout(1)
            self.assertEqual(self.hello(restarted)[2], rx.ACK)

    def test_44100_format_and_malformed_messages(self):
        self.phone.sendto(b'XX\x04' + struct.pack('<I', 48000), self.pc)
        self.phone.sendto(rx.msg(rx.HELLO, struct.pack('<I', 0)), self.pc)
        self.phone.sendto(rx.msg(rx.HELLO, struct.pack('<I', 44100) + b'iPhone'), self.pc)
        self.assertEqual(self.phone.recv(256)[2], rx.ACK)
        pcm = bytes(882)
        self.phone.sendto(rx.msg(rx.AUDIO, struct.pack('<H', 0) + pcm), self.pc)
        self.wait_received(1)
        self.assertEqual(self.engine.source.rate, 44100)
        self.assertEqual(self.engine.source.last_pcm, pcm)
        self.phone.sendto(rx.msg(rx.AUDIO, b'\x01\x00\x00'), self.pc)
        time.sleep(0.03)
        self.assertEqual(self.engine.source.received, 1)

    def test_actual_receiver_buffer_priming_and_overrun(self):
        jb = rx.JitterBuffer(48000, 20)
        packet = b'\x01\x00' * 480
        jb.push(packet)
        self.assertEqual(jb.pull(100), bytes(100))
        jb.push(packet)
        self.assertEqual(jb.pull(100), packet[:100])
        for _ in range(20): jb.push(packet)
        self.assertLessEqual(len(jb.buf), jb.limit)
        self.assertGreater(jb.overruns, 0)


if __name__ == '__main__':
    unittest.main()
