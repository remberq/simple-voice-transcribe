from PIL import Image, ImageDraw

def process_icon():
    img = Image.open('Resources/AppIcon.png').convert('RGBA')
    width, height = img.size
    
    # Fill exterior with a magic color (magenta) to identify exterior pixels
    # We do four corners just in case.
    magic_color = (255, 0, 255, 255)
    ImageDraw.floodfill(img, (0, 0), magic_color, thresh=30)
    ImageDraw.floodfill(img, (width-1, 0), magic_color, thresh=30)
    ImageDraw.floodfill(img, (0, height-1), magic_color, thresh=30)
    ImageDraw.floodfill(img, (width-1, height-1), magic_color, thresh=30)
    
    pixels = img.load()
    
    # We will identify magenta pixels and the white halo.
    # Halo pixels are adjacent to magenta pixels and are bright.
    
    # First pass: collect all magenta pixels
    exterior = set()
    for y in range(height):
        for x in range(width):
            if pixels[x, y] == magic_color:
                exterior.add((x, y))
                
    # Dilate exterior to catch halo
    # Dilate by 2 pixels
    dilated = set(exterior)
    for _ in range(2):
        new_ext = set()
        for x, y in dilated:
            for dx, dy in [(0,1),(1,0),(0,-1),(-1,0),(1,1),(-1,-1),(1,-1),(-1,1)]:
                nx = x + dx
                ny = y + dy
                if 0 <= nx < width and 0 <= ny < height and (nx, ny) not in dilated:
                    new_ext.add((nx, ny))
        dilated.update(new_ext)
        
    # Second pass: compute alpha for everything in dilated set
    for y in range(height):
        for x in range(width):
            if (x, y) in exterior:
                pixels[x, y] = (0, 0, 0, 0)
            elif (x, y) in dilated:
                r, g, b, a = pixels[x, y]
                # If it's a bright pixel in the halo
                lum = 0.299 * r + 0.587 * g + 0.114 * b
                # very bright halo -> almost 0 alpha
                # dark edge -> high alpha
                if lum > 100:
                    alpha = max(0, min(255, int(255 - lum)))
                    # recover color
                    if alpha > 0:
                        af = alpha / 255.0
                        cr = max(0, min(255, int((r - 255 * (1 - af)) / af)))
                        cg = max(0, min(255, int((g - 255 * (1 - af)) / af)))
                        cb = max(0, min(255, int((b - 255 * (1 - af)) / af)))
                        pixels[x, y] = (cr, cg, cb, alpha)
                    else:
                        pixels[x, y] = (0, 0, 0, 0)

    img.save('Resources/AppIcon_transparent.png', 'PNG')

if __name__ == '__main__':
    process_icon()
