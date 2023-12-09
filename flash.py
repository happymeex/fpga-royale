#!/usr/bin/env python3
#kosinw helped with this tool for faster testing
import struct
import sys
import serial
import time

#PORT = "/dev/cu.usbserial-8874292302E81"
PORT= "/dev/cu.usbserial-8874292302111"
BAUDRATE = 115200

if __name__ == "__main__":
    if len(sys.argv) < 2:
        exit()

    input_file = sys.argv[1]
    chunks=[]
    print("asdf")
    with open(input_file,'r') as f:
        for line in f.readlines():
            print(line)
            chunks.append(bytes.fromhex("0"+line.rstrip("\n")))
    #chunks = [binary_data[i:i+4] for i in range(0, len(binary_data), 4)]

   # print(f"sending '{input_file}' to orca computer...")

    with serial.Serial(PORT, BAUDRATE) as uart:
        for i in range(len(chunks)):
            addr = struct.pack("<I", i)
            data = chunks[i].ljust(5, b"\x00")
            print(f"addr={addr[::-1].hex()},data={data.hex()}")
            message = b"".join([b"W", addr, data[::-1], b"\r\n"])
            uart.write(message)
            time.sleep(0.01)


    print("done!")