local Assets=(function()
local metadata = game:GetService("HttpService"):JSONDecode([====[{"SA01":{"name":"Student 01 - Maths stack chair","meshes":{"SA01_B01_M01":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA01_B01_M02":{"rgb":[18,21,25],"name":"Soft black rubber"},"SA01_B01_M03":{"rgb":[182,155,128],"name":"Sand shell"},"SA01_B01_M04":{"rgb":[160,170,176],"name":"Brushed steel"}},"eligible":true},"SA02":{"name":"Student 02 - Science lab stool","meshes":{"SA02_B01_M01":{"rgb":[181,138,89],"name":"Natural ash"},"SA02_B01_M02":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA02_B01_M03":{"rgb":[18,21,25],"name":"Soft black rubber"},"SA02_B01_M04":{"rgb":[112,80,57],"name":"Smoked oak"},"SA02_B01_M05":{"rgb":[160,170,176],"name":"Brushed steel"}},"eligible":true},"SA03":{"name":"Student 03 - Technology swivel chair","meshes":{"SA03_B01_M01":{"rgb":[160,170,176],"name":"Brushed steel"},"SA03_B01_M02":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA03_B01_M03":{"rgb":[142,123,110],"name":"Mushroom taupe"},"SA03_B01_M04":{"rgb":[18,21,25],"name":"Soft black rubber"}},"eligible":true},"SA04":{"name":"Student 04 - Art cantilever chair","meshes":{"SA04_B01_M01":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA04_B01_M02":{"rgb":[18,21,25],"name":"Soft black rubber"},"SA04_B01_M03":{"rgb":[209,195,171],"name":"Warm ivory"},"SA04_B01_M04":{"rgb":[160,170,176],"name":"Brushed steel"}},"eligible":true},"SA05":{"name":"Student 05 - Music posture chair","meshes":{"SA05_B01_M01":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA05_B01_M02":{"rgb":[18,21,25],"name":"Soft black rubber"},"SA05_B01_M03":{"rgb":[117,99,87],"name":"Warm taupe upholstery"},"SA05_B01_M04":{"rgb":[160,170,176],"name":"Brushed steel"},"SA05_B01_M05":{"rgb":[81,72,63],"name":"Dark upholstery seam"},"SA05_B01_M06":{"rgb":[119,99,84],"name":"Saddle stitching"}},"eligible":true},"SA06":{"name":"Staff 01 - Task chair","meshes":{"SA06_B01_M01":{"rgb":[160,170,176],"name":"Brushed steel"},"SA06_B01_M02":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA06_B01_M03":{"rgb":[183,160,135],"name":"Oatmeal woven fabric"},"SA06_B01_M04":{"rgb":[117,99,87],"name":"Warm taupe upholstery"},"SA06_B01_M05":{"rgb":[142,123,110],"name":"Mushroom taupe"},"SA06_B01_M06":{"rgb":[18,21,25],"name":"Soft black rubber"},"SA06_B01_M07":{"rgb":[81,72,63],"name":"Dark upholstery seam"},"SA06_B01_M08":{"rgb":[119,99,84],"name":"Saddle stitching"}},"eligible":true},"SA07":{"name":"Staff 02 - Curved tub chair","meshes":{"SA07_B01_M01":{"rgb":[117,99,87],"name":"Warm taupe upholstery"},"SA07_B01_M02":{"rgb":[183,160,135],"name":"Oatmeal woven fabric"},"SA07_B01_M03":{"rgb":[112,80,57],"name":"Smoked oak"},"SA07_B01_M04":{"rgb":[81,72,63],"name":"Dark upholstery seam"},"SA07_B01_M05":{"rgb":[119,99,84],"name":"Saddle stitching"},"SA07_B01_M06":{"rgb":[160,170,176],"name":"Brushed steel"},"SA07_B01_M07":{"rgb":[18,21,25],"name":"Soft black rubber"}},"eligible":true},"SA08":{"name":"Staff 03 - Low lounge armchair","meshes":{"SA08_B01_M01":{"rgb":[181,138,89],"name":"Natural ash"},"SA08_B01_M02":{"rgb":[209,195,171],"name":"Warm ivory"},"SA08_B01_M03":{"rgb":[183,160,135],"name":"Oatmeal woven fabric"},"SA08_B01_M04":{"rgb":[81,72,63],"name":"Dark upholstery seam"},"SA08_B01_M05":{"rgb":[119,99,84],"name":"Saddle stitching"},"SA08_B01_M06":{"rgb":[112,80,57],"name":"Smoked oak"},"SA08_B01_M07":{"rgb":[18,21,25],"name":"Soft black rubber"}},"eligible":true},"SA09":{"name":"Black pencil - pink eraser","meshes":{"SA09_B01_M01":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA09_B01_M02":{"rgb":[181,138,89],"name":"Natural ash"},"SA09_B01_M03":{"rgb":[18,21,25],"name":"Soft black rubber"},"SA09_B01_M04":{"rgb":[160,170,176],"name":"Brushed steel"},"SA09_B01_M05":{"rgb":[204,120,140],"name":"Dusty pink eraser"},"SA09_B01_M06":{"rgb":[209,195,171],"name":"Warm ivory"}},"eligible":false},"SA10":{"name":"Black retractable pen","meshes":{"SA10_B01_M01":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA10_B01_M02":{"rgb":[160,170,176],"name":"Brushed steel"},"SA10_B01_M03":{"rgb":[18,21,25],"name":"Soft black rubber"}},"eligible":false},"SA12":{"name":"Square ivory pen pot","meshes":{"SA12_B01_M01":{"rgb":[209,195,171],"name":"Warm ivory"},"SA12_B02_M01":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA12_B02_M02":{"rgb":[160,170,176],"name":"Brushed steel"},"SA12_B02_M03":{"rgb":[18,21,25],"name":"Soft black rubber"},"SA12_B03_M01":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA12_B03_M02":{"rgb":[160,170,176],"name":"Brushed steel"},"SA12_B03_M03":{"rgb":[18,21,25],"name":"Soft black rubber"},"SA12_B04_M01":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA12_B04_M02":{"rgb":[160,170,176],"name":"Brushed steel"},"SA12_B04_M03":{"rgb":[18,21,25],"name":"Soft black rubber"},"SA12_B05_M01":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA12_B05_M02":{"rgb":[160,170,176],"name":"Brushed steel"},"SA12_B05_M03":{"rgb":[18,21,25],"name":"Soft black rubber"}},"eligible":false},"SA13":{"name":"Whiteboard marker and eraser","meshes":{"SA13_B02_M01":{"rgb":[209,195,171],"name":"Warm ivory"},"SA13_B02_M02":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA13_B03_M01":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA13_B03_M02":{"rgb":[18,21,25],"name":"Soft black rubber"}},"eligible":false},"SA14":{"name":"Simple school laptop","meshes":{"SA14_B01_M01":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA14_B01_M02":{"rgb":[18,21,25],"name":"Soft black rubber"},"SA14_B01_M03":{"rgb":[142,123,110],"name":"Mushroom taupe"},"SA14_B01_M04":{"rgb":[142,123,110],"name":"Mushroom taupe"},"SA14_B01_M05":{"rgb":[160,170,176],"name":"Brushed steel"},"SA14_B01_M06":{"rgb":[209,195,171],"name":"Warm ivory"},"SA14_B02_M01":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA14_B02_M02":{"rgb":[23,35,47],"name":"Blue black screen"},"SA14_B02_M03":{"rgb":[18,21,25],"name":"Soft black rubber"}},"eligible":false},"SA15":{"name":"Desktop monitor","meshes":{"SA15_B01_M01":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA15_B01_M02":{"rgb":[160,170,176],"name":"Brushed steel"},"SA15_B01_M03":{"rgb":[23,35,47],"name":"Blue black screen"},"SA15_B01_M04":{"rgb":[92,119,81],"name":"Sage foliage"},"SA15_B01_M05":{"rgb":[18,21,25],"name":"Soft black rubber"}},"eligible":false},"SA16":{"name":"Compact desktop keyboard and mouse","meshes":{"SA16_B02_M01":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA16_B02_M02":{"rgb":[142,123,110],"name":"Mushroom taupe"},"SA16_B02_M03":{"rgb":[142,123,110],"name":"Mushroom taupe"},"SA16_B03_M01":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA16_B03_M02":{"rgb":[18,21,25],"name":"Soft black rubber"}},"eligible":false},"SA17":{"name":"Upright piano","meshes":{"SA17_B01_M01":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA17_B01_M02":{"rgb":[112,80,57],"name":"Smoked oak"},"SA17_B01_M03":{"rgb":[18,21,25],"name":"Soft black rubber"},"SA17_B01_M04":{"rgb":[18,21,25],"name":"Soft black rubber"},"SA17_B01_M05":{"rgb":[234,232,223],"name":"Porcelain white"},"SA17_B01_M06":{"rgb":[234,232,223],"name":"Porcelain white"},"SA17_B01_M07":{"rgb":[169,138,72],"name":"Muted brass"},"SA17_B01_M08":{"rgb":[204,120,140],"name":"Dusty pink eraser"},"SA17_B01_M09":{"rgb":[160,170,176],"name":"Brushed steel"},"SA17_B01_M10":{"rgb":[181,138,89],"name":"Natural ash"}},"eligible":false},"SA18":{"name":"Piano bench","meshes":{"SA18_B01_M01":{"rgb":[117,99,87],"name":"Warm taupe upholstery"},"SA18_B01_M02":{"rgb":[112,80,57],"name":"Smoked oak"},"SA18_B01_M03":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA18_B01_M04":{"rgb":[81,72,63],"name":"Dark upholstery seam"},"SA18_B01_M05":{"rgb":[119,99,84],"name":"Saddle stitching"}},"eligible":true},"SA19":{"name":"Acoustic guitar and stand","meshes":{"SA19_B01_M01":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA19_B01_M02":{"rgb":[18,21,25],"name":"Soft black rubber"},"SA19_B02_M01":{"rgb":[169,138,72],"name":"Muted brass"},"SA19_B02_M02":{"rgb":[18,21,25],"name":"Soft black rubber"},"SA19_B02_M03":{"rgb":[112,80,57],"name":"Smoked oak"},"SA19_B02_M04":{"rgb":[209,195,171],"name":"Warm ivory"},"SA19_B02_M05":{"rgb":[160,170,176],"name":"Brushed steel"},"SA19_B02_M06":{"rgb":[181,138,89],"name":"Natural ash"},"SA19_B02_M07":{"rgb":[197,205,207],"name":"Polished keywork"}},"eligible":true},"SA20":{"name":"Clarinet and stand","meshes":{"SA20_B01_M01":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA20_B02_M01":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA20_B02_M02":{"rgb":[18,21,25],"name":"Soft black rubber"},"SA20_B02_M03":{"rgb":[197,205,207],"name":"Polished keywork"},"SA20_B02_M04":{"rgb":[169,138,72],"name":"Muted brass"},"SA20_B02_M05":{"rgb":[181,138,89],"name":"Natural ash"}},"eligible":false},"SA21":{"name":"Tall double cupboard","meshes":{"SA21_B01_M01":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA21_B01_M02":{"rgb":[181,138,89],"name":"Natural ash"},"SA21_B01_M03":{"rgb":[112,80,57],"name":"Smoked oak"},"SA21_B01_M04":{"rgb":[160,170,176],"name":"Brushed steel"},"SA21_B01_M05":{"rgb":[142,123,110],"name":"Mushroom taupe"},"SA21_B01_M06":{"rgb":[209,195,171],"name":"Warm ivory"},"SA21_B01_M07":{"rgb":[182,155,128],"name":"Sand shell"},"SA21_B02_M01":{"rgb":[142,123,110],"name":"Mushroom taupe"},"SA21_B02_M02":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA21_B03_M01":{"rgb":[142,123,110],"name":"Mushroom taupe"},"SA21_B03_M02":{"rgb":[36,41,47],"name":"Graphite powder coat"}},"eligible":false},"SA22":{"name":"Low staffroom cupboard","meshes":{"SA22_B01_M01":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA22_B01_M02":{"rgb":[181,138,89],"name":"Natural ash"},"SA22_B01_M03":{"rgb":[112,80,57],"name":"Smoked oak"},"SA22_B01_M04":{"rgb":[160,170,176],"name":"Brushed steel"},"SA22_B02_M01":{"rgb":[142,123,110],"name":"Mushroom taupe"},"SA22_B02_M02":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA22_B03_M01":{"rgb":[142,123,110],"name":"Mushroom taupe"},"SA22_B03_M02":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA22_B04_M01":{"rgb":[142,123,110],"name":"Mushroom taupe"},"SA22_B04_M02":{"rgb":[36,41,47],"name":"Graphite powder coat"}},"eligible":false},"SA23":{"name":"Classroom tray cupboard","meshes":{"SA23_B01_M01":{"rgb":[181,138,89],"name":"Natural ash"},"SA23_B01_M02":{"rgb":[112,80,57],"name":"Smoked oak"},"SA23_B02_M01":{"rgb":[209,195,171],"name":"Warm ivory"},"SA23_B02_M02":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA23_B03_M01":{"rgb":[209,195,171],"name":"Warm ivory"},"SA23_B03_M02":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA23_B04_M01":{"rgb":[209,195,171],"name":"Warm ivory"},"SA23_B04_M02":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA23_B05_M01":{"rgb":[209,195,171],"name":"Warm ivory"},"SA23_B05_M02":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA23_B06_M01":{"rgb":[142,123,110],"name":"Mushroom taupe"},"SA23_B06_M02":{"rgb":[209,195,171],"name":"Warm ivory"},"SA23_B06_M03":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA23_B07_M01":{"rgb":[142,123,110],"name":"Mushroom taupe"},"SA23_B07_M02":{"rgb":[209,195,171],"name":"Warm ivory"},"SA23_B07_M03":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA23_B08_M01":{"rgb":[142,123,110],"name":"Mushroom taupe"},"SA23_B08_M02":{"rgb":[209,195,171],"name":"Warm ivory"},"SA23_B08_M03":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA23_B09_M01":{"rgb":[142,123,110],"name":"Mushroom taupe"},"SA23_B09_M02":{"rgb":[209,195,171],"name":"Warm ivory"},"SA23_B09_M03":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA23_B10_M01":{"rgb":[172,126,108],"name":"Muted clay"},"SA23_B10_M02":{"rgb":[209,195,171],"name":"Warm ivory"},"SA23_B10_M03":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA23_B11_M01":{"rgb":[172,126,108],"name":"Muted clay"},"SA23_B11_M02":{"rgb":[209,195,171],"name":"Warm ivory"},"SA23_B11_M03":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA23_B12_M01":{"rgb":[172,126,108],"name":"Muted clay"},"SA23_B12_M02":{"rgb":[209,195,171],"name":"Warm ivory"},"SA23_B12_M03":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA23_B13_M01":{"rgb":[172,126,108],"name":"Muted clay"},"SA23_B13_M02":{"rgb":[209,195,171],"name":"Warm ivory"},"SA23_B13_M03":{"rgb":[36,41,47],"name":"Graphite powder coat"}},"eligible":false},"SA24":{"name":"Graphite electric kettle","meshes":{"SA24_B01_M01":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA24_B01_M02":{"rgb":[18,21,25],"name":"Soft black rubber"},"SA24_B01_M03":{"rgb":[160,170,176],"name":"Brushed steel"},"SA24_B02_M01":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA24_B02_M02":{"rgb":[160,170,176],"name":"Brushed steel"},"SA24_B02_M03":{"rgb":[142,123,110],"name":"Mushroom taupe"},"SA24_B02_M04":{"rgb":[23,35,47],"name":"Blue black screen"},"SA24_B02_M05":{"rgb":[209,195,171],"name":"Warm ivory"},"SA24_B02_M06":{"rgb":[92,119,81],"name":"Sage foliage"},"SA24_B02_M07":{"rgb":[18,21,25],"name":"Soft black rubber"}},"eligible":false},"SA25":{"name":"Ivory staff mug","meshes":{"SA25_B01_M01":{"rgb":[214,199,175],"name":"Glazed ivory ceramic"},"SA25_B01_M02":{"rgb":[209,195,171],"name":"Warm ivory"}},"eligible":false},"SA26":{"name":"Graphite staff mug","meshes":{"SA26_B01_M01":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA26_B01_M02":{"rgb":[209,195,171],"name":"Warm ivory"}},"eligible":false},"SA27":{"name":"Cup and saucer","meshes":{"SA27_B01_M01":{"rgb":[214,199,175],"name":"Glazed ivory ceramic"},"SA27_B02_M01":{"rgb":[214,199,175],"name":"Glazed ivory ceramic"}},"eligible":false},"SA28":{"name":"Takeaway coffee cup","meshes":{"SA28_B01_M01":{"rgb":[209,195,171],"name":"Warm ivory"},"SA28_B01_M02":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA28_B01_M03":{"rgb":[18,21,25],"name":"Soft black rubber"},"SA28_B01_M04":{"rgb":[142,123,110],"name":"Mushroom taupe"}},"eligible":false},"SA29":{"name":"mobile whiteboard","meshes":{"SA29_B01_M01":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA29_B01_M02":{"rgb":[243,240,230],"name":"Warm white enamel"},"SA29_B01_M03":{"preserve":true,"name":"Supplied white bird emblem"},"SA29_B01_M04":{"rgb":[160,170,176],"name":"Brushed steel"},"SA29_B01_M05":{"rgb":[18,21,25],"name":"Soft black rubber"},"SA29_B02_M01":{"rgb":[142,123,110],"name":"Mushroom taupe"},"SA29_B02_M02":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA29_B03_M01":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA29_B04_M01":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA29_B05_M01":{"rgb":[142,123,110],"name":"Mushroom taupe"},"SA29_B06_M01":{"rgb":[142,123,110],"name":"Mushroom taupe"},"SA29_B07_M01":{"rgb":[142,123,110],"name":"Mushroom taupe"}},"eligible":false},"SA30":{"name":"Rounded TV teaching board","meshes":{"SA30_B01_M01":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA30_B01_M02":{"rgb":[23,35,47],"name":"Blue black screen"},"SA30_B01_M03":{"preserve":true,"name":"Supplied white bird emblem"},"SA30_B01_M04":{"rgb":[18,21,25],"name":"Soft black rubber"},"SA30_B01_M05":{"rgb":[160,170,176],"name":"Brushed steel"}},"eligible":false},"SA31":{"name":"Indoor broadleaf plant","meshes":{"SA31_B01_M01":{"rgb":[209,195,171],"name":"Warm ivory"},"SA31_B01_M02":{"rgb":[51,39,30],"name":"Potting soil"},"SA31_B01_M03":{"rgb":[102,69,48],"name":"Bark"},"SA31_B01_M04":{"rgb":[37,63,42],"name":"Deep green foliage"},"SA31_B01_M05":{"rgb":[49,81,58],"name":"Forest foliage"},"SA31_B01_M06":{"rgb":[92,119,81],"name":"Sage foliage"}},"eligible":true},"SA32":{"name":"Indoor snake plant","meshes":{"SA32_B01_M01":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA32_B01_M02":{"rgb":[51,39,30],"name":"Potting soil"},"SA32_B01_M03":{"rgb":[92,119,81],"name":"Sage foliage"},"SA32_B01_M04":{"rgb":[49,81,58],"name":"Forest foliage"}},"eligible":true},"SA33":{"name":"Outdoor shrub planter","meshes":{"SA33_B01_M01":{"rgb":[142,123,110],"name":"Mushroom taupe"},"SA33_B01_M02":{"rgb":[51,39,30],"name":"Potting soil"},"SA33_B01_M03":{"rgb":[37,63,42],"name":"Deep green foliage"},"SA33_B01_M04":{"rgb":[37,63,42],"name":"Deep green foliage"},"SA33_B01_M05":{"rgb":[102,69,48],"name":"Bark"},"SA33_B01_M06":{"rgb":[49,81,58],"name":"Forest foliage"},"SA33_B01_M07":{"rgb":[49,81,58],"name":"Forest foliage"},"SA33_B01_M08":{"rgb":[92,119,81],"name":"Sage foliage"}},"eligible":false},"SA34":{"name":"Outdoor round shrub","meshes":{"SA34_B01_M01":{"rgb":[37,63,42],"name":"Deep green foliage"},"SA34_B01_M02":{"rgb":[102,69,48],"name":"Bark"},"SA34_B01_M03":{"rgb":[92,119,81],"name":"Sage foliage"},"SA34_B01_M04":{"rgb":[49,81,58],"name":"Forest foliage"}},"eligible":true},"SA35":{"name":"Broadleaf school tree","meshes":{"SA35_B01_M01":{"rgb":[102,69,48],"name":"Bark"},"SA35_B01_M02":{"rgb":[37,63,42],"name":"Deep green foliage"},"SA35_B01_M03":{"rgb":[92,119,81],"name":"Sage foliage"},"SA35_B01_M04":{"rgb":[49,81,58],"name":"Forest foliage"},"SA35_B01_M05":{"rgb":[49,81,58],"name":"Forest foliage"}},"eligible":false},"SA36":{"name":"Evergreen school tree","meshes":{"SA36_B01_M01":{"rgb":[102,69,48],"name":"Bark"},"SA36_B01_M02":{"rgb":[37,63,42],"name":"Deep green foliage"},"SA36_B01_M03":{"rgb":[49,81,58],"name":"Forest foliage"}},"eligible":false},"SA37":{"name":"Outdoor backed bench","meshes":{"SA37_B01_M01":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA37_B01_M02":{"rgb":[181,138,89],"name":"Natural ash"},"SA37_B01_M03":{"rgb":[160,170,176],"name":"Brushed steel"},"SA37_B01_M04":{"rgb":[18,21,25],"name":"Soft black rubber"},"SA37_B01_M05":{"rgb":[137,101,62],"name":"Endgrain oak"}},"eligible":false},"SA38":{"name":"Outdoor backless bench","meshes":{"SA38_B01_M01":{"rgb":[36,41,47],"name":"Graphite powder coat"},"SA38_B01_M02":{"rgb":[181,138,89],"name":"Natural ash"},"SA38_B01_M03":{"rgb":[160,170,176],"name":"Brushed steel"},"SA38_B01_M04":{"rgb":[18,21,25],"name":"Soft black rubber"},"SA38_B01_M05":{"rgb":[137,101,62],"name":"Endgrain oak"}},"eligible":false}}]====])
local Assets = {}
local version = "20261011"
local ink = Color3.fromRGB(14, 18, 25)

local function part(parent, name, size, cf, solid)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame = name, size, cf
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, solid, false, solid
	p.Transparency, p.CastShadow = 1, false
	p.Parent = parent
	return p
end

local function outline(model)
	local h = Instance.new("Highlight")
	h.Name = "CartoonOutline"
	h.Adornee, h.FillTransparency, h.OutlineTransparency = model, 1, 0
	h.OutlineColor, h.DepthMode = ink, Enum.HighlightDepthMode.Occluded
	h.Parent = model
	return h
end

local function physicalBounds(model)
	local cf, size = model:GetBoundingBox()
	return CFrame.new(cf.Position.X, cf.Position.Y - size.Y / 2, cf.Position.Z), size
end

function Assets.BuildLibrary(importParent, target)
	assert(target and not target:FindFirstChild("SchoolPropTemplates"), "SchoolPropTemplates already exists")
	assert(game.MaterialService:FindFirstChild("PlaygroundRetroStuds"), "Stud material is missing")
	local imports = {}
	for _, m in importParent:GetChildren() do
		local id = m.Name:match("^(SA%d%d)_")
		if id and m:IsA("Model") and metadata[id] then assert(not imports[id], "Duplicate " .. id) imports[id] = m end
	end
	for id in metadata do assert(imports[id], "Imported model missing: " .. id) end
	local library = Instance.new("Folder")
	library.Name = "SchoolPropTemplates"
	library:SetAttribute("SchoolAssetVersion", version)
	library.Parent = target
	local count, eligible = 0, 0
	for id, info in metadata do
		local model = imports[id]:Clone()
		model.Name = id
		model.PrimaryPart = nil
		for _, d in model:GetDescendants() do
			if d:IsA("LuaSourceContainer") or d:IsA("ProximityPrompt") or d:IsA("Highlight") or d:IsA("Seat") or d:IsA("JointInstance") or d:IsA("Constraint") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				if d.Name:find("_REF_", 1, true) then d:Destroy() else
					local style = assert(info.meshes[d.Name], "Missing material mapping: " .. d.Name)
					d.Anchored, d.CanCollide, d.CanTouch, d.CanQuery, d.Massless = true, false, false, false, true
					d.CastShadow = true
					d:SetAttribute("SchoolAssetMaterial", style.name)
					if not style.preserve then
						for _, child in d:GetChildren() do if child:IsA("SurfaceAppearance") then child:Destroy() end end
						if d:IsA("MeshPart") then d.TextureID = "" end
						d.Color = Color3.fromRGB(table.unpack(style.rgb))
						d.Material, d.MaterialVariant = Enum.Material.SmoothPlastic, "PlaygroundRetroStuds"
					else d:SetAttribute("SchoolPreserveEmblem", true) end
					d:SetAttribute("SchoolStyled", true)
				end
			end
		end
		model:PivotTo(CFrame.Angles(0, math.pi, 0))
		local bottom, size = physicalBounds(model)
		model:TranslateBy(-bottom.Position)
		model.WorldPivot = CFrame.new()
		model:SetAttribute("SchoolAssetVersion", version)
		model:SetAttribute("HSPropId", id)
		model:SetAttribute("DisplayName", info.name)
		model:SetAttribute("HSPropEligible", info.eligible)
		model:SetAttribute("HSPropSize", size)
		model:SetAttribute("HSOutlineColor", ink)
		model:SetAttribute("SchoolSourceName", imports[id].Name)
		model.Parent = library
		count += 1
		if info.eligible then eligible += 1 end
		if count % 5 == 0 then task.wait() end
	end
	library:SetAttribute("TemplateCount", count)
	library:SetAttribute("EligibleCount", eligible)
	return library, {templates = count, eligible = eligible}
end

function Assets.InstallWorld(arena, library, backup)
	assert(arena and library and backup, "Arena, library and backup required")
	assert(arena:GetAttribute("SchoolAssetsVersion") ~= version, "School assets already installed")
	local school, gameplay = arena.Geometry.PlaygroundPrimarySchool, arena.Gameplay
	assert(not school:FindFirstChild("SchoolAssetProps"), "Existing school asset props")
	local rooms = {}
	for _, item in school:GetChildren() do if item:IsA("Model") and item:GetAttribute("ClassroomNumber") then table.insert(rooms, item) end end
	table.sort(rooms, function(a, b) return a:GetAttribute("ClassroomNumber") < b:GetAttribute("ClassroomNumber") end)
	assert(#rooms == 32 or arena:GetAttribute("SchoolAssetFixture") == true, "Expand to 32 rooms first")
	local root = Instance.new("Model")
	root.Name = "SchoolAssetProps"
	root:SetAttribute("SchoolAssetVersion", version)
	root.Parent = school
	outline(root)
	local originalLockers = gameplay.LockerSpots
	local lockers
	if originalLockers:IsA("Model") then lockers = originalLockers else
		lockers = Instance.new("Model")
		lockers.Name = "LockerSpots"
		for key, value in originalLockers:GetAttributes() do lockers:SetAttribute(key, value) end
		for _, child in originalLockers:GetChildren() do child.Parent = lockers end
		originalLockers.Parent = backup
		originalLockers.Name = "OriginalEmptyLockerSpotsFolder"
		lockers.Parent = gameplay
	end
	outline(lockers)
	local replaced, placed, storageCount = 0, 0, 0
	local function preserve(old)
		old:SetAttribute("SchoolOriginalParent", old.Parent:GetFullName())
		old:SetAttribute("SchoolOriginalName", old.Name)
		replaced += 1
		old.Name = string.format("%03d_%s", replaced, old.Name)
		old.Parent = backup
	end
	local function put(id, cf, name, parent, options)
		options = options or {}
		local prop = assert(library:FindFirstChild(id), id):Clone()
		prop.Name = name or metadata[id].name
		if options.scale then prop:ScaleTo(prop:GetScale() * options.scale) end
		local size = prop:GetBoundingBox()
		local _, bounds = prop:GetBoundingBox()
		prop:PivotTo(cf)
		prop:SetAttribute("SchoolPlacedProp", true)
		if options.room then prop:SetAttribute("ClassroomNumber", options.room) end
		if options.solid then
			part(prop, "CollisionHull", Vector3.new(bounds.X * .88, bounds.Y, bounds.Z * .85), cf * CFrame.new(0, bounds.Y / 2, 0), true)
		end
		prop.Parent = parent or root
		placed += 1
		return prop, bounds
	end
	local function storage(id, cf, name, room, old)
		local model, bounds = put(id, cf, name, lockers, {solid = true, room = room})
		model:SetAttribute("HSPropEligible", false)
		model:SetAttribute("HSHidingSpot", true)
		model:SetAttribute("HSHidingSpotName", id == "SA23" and "Tray drawers" or "Cupboard")
		local door = part(model, "Door", Vector3.new(math.min(bounds.X - .2, 4.4), math.min(bounds.Y - .1, 6), .12), cf * CFrame.new(0, math.min(bounds.Y * .5, 3.8), -bounds.Z / 2 - .08), false)
		door.CanQuery = true
		local hide = part(model, "HidePoint", Vector3.new(.2,.2,.2), cf * CFrame.new(0, math.min(3, bounds.Y * .65), 0), false)
		local exit = part(model, "ExitPoint", Vector3.new(.2,.2,.2), cf * CFrame.new(0, 3, -bounds.Z / 2 - 4), false)
		if old then
			for key, value in old:GetAttributes() do if key ~= "HSPropEligible" then model:SetAttribute(key, value) end end
			hide.CFrame, exit.CFrame = old.HidePoint.CFrame, old.ExitPoint.CFrame
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name, prompt.ActionText, prompt.ObjectText = "LockerPrompt", "Hide", model:GetAttribute("HSHidingSpotName")
		prompt.HoldDuration, prompt.MaxActivationDistance, prompt.RequiresLineOfSight = .15, 6, false
		prompt.KeyboardKeyCode, prompt.GamepadKeyCode = Enum.KeyCode.E, Enum.KeyCode.ButtonY
		prompt.Parent = door
		storageCount += 1
		return model
	end
	local oldLockers = lockers:GetChildren()
	for _, old in oldLockers do
		if old:IsA("Model") and old:FindFirstChild("Door") and old:FindFirstChild("HidePoint") and old:FindFirstChild("ExitPoint") then
			local floorY = old.HidePoint.Position.Y - 3
			local centre = Vector3.new(old.HidePoint.Position.X, floorY, old.HidePoint.Position.Z)
			local look = old.ExitPoint.Position - old.HidePoint.Position
			local cf = CFrame.lookAt(centre, centre + Vector3.new(look.X, 0, look.Z))
			storage("SA21", cf, old.Name, nil, old)
			preserve(old)
		end
		if storageCount % 6 == 0 then task.wait() end
	end
	local floorPart = assert(school.Structure:FindFirstChild("GroundFloor"))
	local floorY = floorPart.Position.Y + floorPart.Size.Y / 2
	for _, room in rooms do
		local number, floor = room:GetAttribute("ClassroomNumber"), room:GetAttribute("Floor") or 1
		local furniture
		for _, item in room:GetChildren() do if item:IsA("Model") and item:FindFirstChild("Table11") then furniture = item break end end
		assert(furniture, "Classroom furniture missing: " .. room.Name)
		local desk = furniture.Table11.DeskTop
		local centre = Vector3.new(desk.Position.X + 9, floorY + (floor - 1) * 18, desk.Position.Z + 8.3)
		local cf = CFrame.new(centre)
		for _, old in furniture:GetChildren() do
			if old:IsA("Model") and (old.Name:match("^Chair%d") or old.Name == "TeacherChair") then
				local seat = assert(old:FindFirstChild("Seat"), "Chair seat missing")
				local id = old.Name == "TeacherChair" and string.format("SA%02d", 6 + (number - 1) % 3) or string.format("SA%02d", 1 + (number - 1) % 5)
				local at = seat.CFrame * CFrame.new(0, -1.9, 0)
				put(id, at, string.format("Room%02d_%s", number, old.Name), root, {solid = true, room = number})
				preserve(old)
			elseif old:IsA("Model") and old.Name == "Whiteboard" then
				local board = old.BoardFace
				local id = number % 4 == 3 and "SA30" or "SA29"
				put(id, CFrame.new(board.Position.X, centre.Y, board.Position.Z - .7), string.format("Room%02d_TeachingBoard", number), root, {solid = true, room = number, scale = .8})
				preserve(old)
			elseif old:IsA("Model") and old.Name == "ReadingCubby" then
				local id = number % 3 == 0 and "SA21" or number % 3 == 1 and "SA23" or "SA22"
				storage(id, cf * CFrame.new(-19, 0, -13.1) * CFrame.Angles(0, math.pi, 0), string.format("Room%02d_HidingStorage", number), number)
				preserve(old)
			elseif old:IsA("Model") and old.Name == "ReadingCushion" then preserve(old) end
		end
		put(number % 2 == 0 and "SA31" or "SA32", cf * CFrame.new(19, 0, 14.5), string.format("Room%02d_Plant", number), root, {solid = true, room = number})
		local tableTop = furniture.TeacherTable.DeskTop
		local tableCF = CFrame.new(tableTop.Position.X, tableTop.Position.Y + tableTop.Size.Y / 2, tableTop.Position.Z)
		local detailId = ({"SA09", "SA10", "SA12", "SA13"})[(number - 1) % 4 + 1]
		put(detailId, tableCF * CFrame.new(2.6, .015, -.1), string.format("Room%02d_DeskSupplies", number), root, {room = number})
		if number % 4 == 3 then
			put("SA15", tableCF * CFrame.new(-1.5, .015, .2), string.format("Room%02d_Monitor", number), root, {room = number})
			put("SA16", tableCF * CFrame.new(-1.5, .015, -1.0), string.format("Room%02d_Keyboard", number), root, {room = number})
		elseif number % 4 == 0 then
			put("SA14", tableCF * CFrame.new(-1.5, .015, 0), string.format("Room%02d_Laptop", number), root, {room = number})
		elseif number % 4 == 1 then
			put("SA24", tableCF * CFrame.new(-2, .015, .3), string.format("Room%02d_Kettle", number), root, {room = number})
		end
		put(string.format("SA%02d", 25 + (number - 1) % 4), tableCF * CFrame.new(.6, .015, -.5), string.format("Room%02d_Cup", number), root, {room = number})
		if number % 8 == 5 then
			put("SA17", cf * CFrame.new(-17, 0, 3.2), string.format("Room%02d_Piano", number), root, {solid = true, room = number})
			put("SA18", cf * CFrame.new(-17, 0, -.8), string.format("Room%02d_PianoBench", number), root, {solid = true, room = number})
			put("SA19", cf * CFrame.new(19, 0, 6), string.format("Room%02d_Guitar", number), root, {solid = true, room = number})
			put("SA20", cf * CFrame.new(19, 0, .5), string.format("Room%02d_Clarinet", number), root, {solid = true, room = number})
		end
		task.wait()
	end
	for _, old in arena.Grounds:GetDescendants() do
		if old:IsA("Model") and old:FindFirstChild("BenchSeat") then
			local seat = old.BenchSeat
			local at = seat.CFrame * CFrame.new(0, -2.1, 0)
			put(old.Name:find("Picnic") and "SA38" or "SA37", at, old.Name, root, {solid = true})
			preserve(old)
		end
	end
	local origin = arena:GetAttribute("SchoolOriginCFrame") or CFrame.new(floorPart.Position.X, floorY, floorPart.Position.Z - 39)
	for _, side in {-1, 1} do
		for index, z in {-185, -115, -45, 25, 95} do
			local id = index % 2 == 1 and "SA34" or "SA33"
			put(id, origin * CFrame.new(side * 76, 0, z), string.format("OutdoorPlant_%s_%02d", side == -1 and "West" or "East", index), root, {solid = true})
		end
		for index, z in {-160, 70} do
			local id = index == 1 and "SA35" or "SA36"
			put(id, origin * CFrame.new(side * 88, 0, z), string.format("SchoolTree_%s_%02d", side == -1 and "West" or "East", index), root, {solid = true})
		end
	end
	arena:SetAttribute("SchoolAssetsVersion", version)
	return {rooms = #rooms, replaced = replaced, placed = placed, hidingSpots = storageCount, outlineGroups = 2}
end

return Assets

end)()
local host = Instance.new("Folder")
host.Name = "SchoolAssetIsolatedFixture"
local arena
local checks = 0
local function check(value, message) assert(value, message) checks += 1 end
local ok, result = xpcall(function()
	local templates, libraryResult = Assets.BuildLibrary(workspace, host)
	check(libraryResult.templates == 37, "Expected 37 imported assets")
	check(libraryResult.eligible == 13, "Expected 13 fair morph forms")
	local styled, emblems = 0, 0
	for _, model in templates:GetChildren() do
		local cf, size = model:GetBoundingBox()
		check(math.abs(cf.Position.X) < .01 and math.abs(cf.Position.Z) < .01 and math.abs(cf.Position.Y - size.Y / 2) < .01, "Template pivot/ground mismatch " .. model.Name)
		check(model:GetPivot().Position.Magnitude < .001, "Template pivot not zero " .. model.Name)
		if model:GetAttribute("HSPropEligible") then
			check(size.Y >= 1.4 and math.max(size.X, size.Z) >= 1.8 and size.X * size.Y * size.Z >= 4 and math.max(size.X, size.Y, size.Z) <= 8, "Morph bounds rejected " .. model.Name)
		end
		for _, item in model:GetDescendants() do
			check(not item:IsA("LuaSourceContainer") and not item:IsA("ProximityPrompt") and not item:IsA("Highlight") and not item:IsA("Seat"), "Unsafe template child")
			if item:IsA("BasePart") then
				check(not item.Name:find("_REF_", 1, true), "Import marker survived")
				check(item.Anchored and not item.CanCollide and not item.CanTouch and not item.CanQuery, "Template physics unsafe")
				if item:GetAttribute("SchoolPreserveEmblem") then emblems += 1 else
					check(item.MaterialVariant == "PlaygroundRetroStuds", "Stud texture missing " .. item.Name)
					check(not item:FindFirstChildOfClass("SurfaceAppearance"), "PBR masks studs " .. item.Name)
					styled += 1
				end
			end
		end
	end
	for _, id in {"SA09","SA10","SA12","SA13","SA14","SA15","SA16","SA20","SA21","SA22","SA23","SA24","SA25","SA26","SA27","SA28","SA29","SA30","SA33","SA35","SA36","SA37","SA38"} do
		check(templates[id]:GetAttribute("HSPropEligible") == false, "Disallowed morph " .. id)
	end
	arena = workspace["Hide and Seek"]:Clone()
	arena:SetAttribute("SchoolAssetFixture", true)
	local backup = Instance.new("Folder") backup.Name = "OriginalProps" backup.Parent = host
	local applied = Assets.InstallWorld(arena, templates, backup)
	check(applied.rooms >= 16, "Room replacements missing")
	check(applied.outlineGroups == 2, "Outline budget excessive")
	local root = arena.Geometry.PlaygroundPrimarySchool.SchoolAssetProps
	check(root.CartoonOutline.FillTransparency == 1 and root.CartoonOutline.DepthMode == Enum.HighlightDepthMode.Occluded, "Outline hides colors or sees through walls")
	local seen, collisions = {}, 0
	for _, prop in root:GetChildren() do
		if prop:IsA("Model") then
			seen[prop:GetAttribute("HSPropId")] = true
			check(prop:GetAttribute("SchoolPlacedProp") == true, "Unmarked placed prop")
			local hull = prop:FindFirstChild("CollisionHull")
			if hull then
				check(hull.CanCollide and hull.Anchored and hull.Transparency == 1, "Bad prop collider")
				local delta = hull.Position - Vector3.new(11000, 33, 4546)
				check(math.abs(delta.X) > 13, "Prop blocks central corridor: " .. prop.Name)
				collisions += 1
			end
		end
	end
	for _, storage in arena.Gameplay.LockerSpots:GetChildren() do
		if storage:IsA("Model") then
			seen[storage:GetAttribute("HSPropId")] = true
			check(storage:GetAttribute("HSPropEligible") == false, "Storage became a morph")
			check(storage.Door:FindFirstChild("LockerPrompt") ~= nil, "Storage prompt missing")
			check((storage.HidePoint.Position-storage.Door.Position).Magnitude <= 6 and (storage.ExitPoint.Position-storage.Door.Position).Magnitude <= 8 and (storage.ExitPoint.Position-storage.HidePoint.Position).Magnitude <= 10, "Hiding contract exceeds distances: " .. storage.Name)
		end
	end
	for _, m in templates:GetChildren() do check(seen[m.Name] == true, "Asset never placed: " .. m.Name) end
	return {checks = checks, templates = libraryResult, placement = applied, studMeshes = styled, preservedEmblems = emblems, solidProps = collisions}
end, debug.traceback)
if arena then arena:Destroy() end
host:Destroy()
if not ok then error(result) end
return result
