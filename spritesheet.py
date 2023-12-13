import sys
from PIL import Image

palette_outpath = "data/palette.mem"
spritesheet_outpath = "data/spritesheet.mem"
palette_size = 7  # includes a transparent color
green = '32a852'
blue = '19729e'
grey = '656565'

def color_to_hex(color):
    '''
    Convert a RGB color tuple to hex string (without leading '0x')
    '''
    hex_string = '{:02x}{:02x}{:02x}'.format(*color)
    return hex_string


if len(sys.argv) < 5:
    print(f"usage: {sys.argv[0]} <filename> <rows> <columns> <palette size>")
    exit(1)

im = Image.open(sys.argv[1])
width, height = im.size
rows, cols = int(sys.argv[2]), int(sys.argv[3])
palette_size = int(sys.argv[4])
if width % cols != 0:
    print(f"width ({width}) must be a multiple of columns ({cols})")
    exit(1)
if height % rows != 0:
    print(f"height ({height}) must be a multiple of rows ({rows})")
    exit(1)
frame_width, frame_height = width // cols, height // rows

discretized_im = im.convert(mode='P', palette=1, colors=palette_size)
palette = discretized_im.getpalette()
palette = [tuple(palette[i:i+3]) for i in range(0, len(palette), 3)]

# write final palette to file
with open(palette_outpath, 'w') as f:
    f.write('\n'.join([color_to_hex(color)
            for color in palette[:palette_size]]))
    f.write('\n' + grey) # grey for UI banner appeneded as third-to-last color
    f.write('\n' + blue) # water blue appended as penultimate color
    f.write('\n' + green) # background green appended as final color
    print(f"palette written to {palette_outpath}")


# write image to file
with open(spritesheet_outpath, 'w') as f:
    lines = []
    for y in range(0, height, frame_height):
        for x in range(0, width, frame_width):
            for y_offset in range(frame_height):
                for x_offset in range(frame_width):
                    index = discretized_im.getpixel((x+x_offset, y+y_offset))
                    lines.append(f"{index:01x}")
    f.write('\n'.join(lines))
    print(f"image written to {spritesheet_outpath}")
