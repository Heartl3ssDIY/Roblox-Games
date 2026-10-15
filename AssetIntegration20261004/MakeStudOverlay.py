from pathlib import Path
from PIL import Image, ImageDraw
root = Path(__file__).resolve().parent
(root/'Upload').mkdir(exist_ok=True)
image = Image.new('RGBA', (256,256))
d = ImageDraw.Draw(image)
d.rounded_rectangle((54,59,202,207), radius=10, fill=(20,29,45,48))
d.rounded_rectangle((54,47,202,193), radius=10, fill=(255,255,255,21))
d.line([(64,49),(192,49),(200,57),(200,183)], fill=(255,255,255,104), width=5)
d.line([(57,63),(57,182),(66,191),(191,191)], fill=(20,29,45,90), width=5)
image.resize((128,128), Image.Resampling.LANCZOS).save(root/'Upload'/'RetroStudOverlay.png')
