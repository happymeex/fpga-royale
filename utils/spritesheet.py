import png
import sys
from pathlib import Path

if (len(sys.argv) < 4):
    print("usage: spritesheet.py <filename> <rows> <cols>")
    sys.exit(1)

path = sys.argv[1]
filename = Path(path).stem
print(filename)

reader = png.Reader(filename=path)
row, cols = int(sys.argv[2]), int(sys.argv[3])
width, height, pixel_rows, metadata = reader.asRGBA()
if width % cols != 0:
    print("width must be a multiple of cols")
    sys.exit(1)
if height % row != 0:
    print("height must be a multiple of rows")
    sys.exit(1)
frame_width, frame_height = width // cols, height // row

print("spritesheet dimensions:", width, "x", height)


def is_transparent(a_value):
    return a_value < 32


# 2D array holding (R,G,B,A) tuples, where A in {0,1} and others in [0,255]
pixels = []
pixel_rows = list(pixel_rows)
for pixel_row in pixel_rows:
    pixel_list = []
    pixel = []
    for value in pixel_row:
        pixel.append(value)
        if len(pixel) == 4:
            pixel[3] = 0 if is_transparent(pixel[3]) else 1
            pixel_list.append(tuple(pixel))
            pixel = []
    pixels.append(pixel_list)

outfile = "data/spritesheet.mem"
# write pixel values to file, frame by frame
with open(outfile, "w") as f:
    for y in range(0, height, frame_height):
        for x in range(0, width, frame_width):
            for r in range(frame_height):
                for c in range(frame_width):
                    # make each pixel value a 2-digit hex
                    pixel = [f"{val:02x}" for val in pixels[y+r][x+c]]
                    f.write(f"{''.join(pixel)}\n")

print("wrote spritesheet data to", outfile)
