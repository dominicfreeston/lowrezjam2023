COLOR0 = {r: 155, g: 188, b: 15}
COLOR1 = {r: 139, g: 172, b: 15}
COLOR2 = {r:  48, g: 198, b: 48}
COLOR3 = {r:  15, g:  56, b: 15}

FLY_RANGE_W = 96
FLY_RANGE_H = 64
CANVAS_W = 64
CANVAS_H = 64
# when position is 0, camera should be 0
# when position is 80 (96-16), camera should be 48 (64 - 16)
CAMERA_RATIO_W = (CANVAS_W - 16) / (FLY_RANGE_W - 16)

SHIP_BASE_SPEED = 1
SHIP_SPEED_X = 1.5
SHIP_SPEED_Y = 1
HELP_SPEED = 0.5

HELP1_POS = {x: -3, y: -7}
HELP2_POS = {x:  11, y: -7}

BULLET_GAP = 4
BULLET_SPEED = 2
 
BULLET_POSITIONS = [
  {x:   7, y: 14},
  {x:   8, y: 14},
  {x:   2, y: 12},
  {x:  13, y: 12},
]

HELP_BULLET_POS = [
   {x: 0, y: 7},
   {x: 7, y: 7},
]
