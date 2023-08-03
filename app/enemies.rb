# Moves are sequences of simple steps
# - Shoot moves don't consume a tick
module Moves
  def self.repeat_shoot gun, times, gap
    (0..times).map do |i|
      r = gun.map { |g| {shoot: g} }
      r << {ticks: gap} if i < times
      r
    end.flatten!
  end
  
  def self.slide_wait_drop (dir, slide)
    [
      {dx: dir, ticks: slide},
      {ticks: 120},
      {dy: -0.5, ticks: 10},
      {dy: -1, ticks: 10},
      {dy: -1.5, ticks: 10},
      {dy: -2, ticks: 30},
    ]
  end

  def self.slide_shoot_leave (dir, slide, gun)
    [
      {dx: dir, ticks: slide},
      {ticks: 30},
      *gun.map { |g| {shoot: g} },
      {ticks: 60},
      {dy: 1, ticks: 30},
    ]
  end

  def self.dive
    [
      {dx: -0.25, dy: -0.75, ticks: 16},
      {dx:  0.25, dy: -0.75, ticks: 32},
      {dx: -0.25, dy: -0.75, ticks: 32},
      {dx:  0.25, dy: -0.75, ticks: 32},
    ]
  end

  def self.diagonal flip
    [
      {dx: 0.2 * flip, dy: -0.15, ticks: 600},
    ]
  end

  def self.fighter_loop flip
    [
      {dx: 0.3 * flip, dy: -0.4, ticks: 32},
      {dx: 0.4 * flip, dy: -0.15, ticks: 32},
      *Guns.fighter_gun.map { |g| {shoot: g} },
      {dx: 0.4 * flip, dy: 0.15, ticks: 32},
      {dx: 0.3 * flip, dy: 0.4, ticks: 32},      
    ]
  end

  def self.copter_move_1
    [
      {dy: -0.4, ticks: 50},
      {ticks: 45},
      *repeat_shoot(Guns.copter_gun, 10, 30),
      {ticks: 120},
      {dy: 0.4, ticks: 60},
    ]
  end
  
end

# Guns are one-shot bullet patterns
module Guns  
  def self.bomber_gun
    [
      {
        x: 2, y: 0, w: 2, h: 1,
        vy: -0.5,
        spr: SPRITES.bullet_enemy_large,
      }
    ]
  end

  def self.fighter_gun
    [
      {x: 5, y: 0, w: 1, h: 1,
       vx: -0.4, vy: -0.4,
       flip_horizontally: true,
       spr: SPRITES.bullet_enemy_angle
      },
      {x: 2, y: 0, w: 1, h: 1,
       vx: 0.4, vy: -0.4,
       spr: SPRITES.bullet_enemy_angle
      },
    ]
  end

  def self.copter_gun
    [
      {
        x: 6, y: 1, w: 1, h: 1,
        vx: -0.1, vy: -0.5,
        spr: SPRITES.bullet_enemy_small,
      },
      {
        x: 6, y: 1, w: 1, h: 1,
        vx: 0.1, vy: -0.5,
        spr: SPRITES.bullet_enemy_small,
      },
      {
        x: 11, y: 2, w: 1, h: 1,
        vx: 0.25, vy: -0.25,
        spr: SPRITES.bullet_enemy_angle,
      },
      {
        x: 0, y: 2, w: 1, h: 1,
        vx: -0.25, vy: -0.25,
        flip_horizontally: true,
        spr: SPRITES.bullet_enemy_angle,
      },
    ]
  end
end

# Grunts follow simple rules
# - One set of Moves then disappear
# - One looping animation (or none)
# - Activate when in range (active_offset t to tweak)
# - Bullets disappear on death
module Grunts  
  def self.bomber_left loc, slide
    {
      x: -6, y: loc * SHIP_BASE_SPEED,
      w: 6, h: 6,
      health: 6,
      moves: Moves.slide_shoot_leave(1, slide, Guns.bomber_gun),
      spr: SPRITES.enemy_bomber_01,
      bullets: [],
      active_offset: -8,
    }
  end

  def self.bomber_right loc, slide
    {
      x: FLY_RANGE_W, y: loc * SHIP_BASE_SPEED,
      w: 6, h: 6,
      health: 6,
      moves: Moves.slide_shoot_leave(-1, slide, Guns.bomber_gun),
      spr: SPRITES.enemy_bomber_01,
      bullets: [],
      active_offset: -8,
    }
  end

  def self.diver x, y
    {
      x: x, y: y * SHIP_BASE_SPEED,
      w: 3, h: 5,
      health: 1,
      moves: Moves.dive,
      spr: SPRITES.enemy_diver_01,
    }
  end

  def self.fighter x, y, flip = nil
    flip = flip.nil? ? x > FLY_RANGE_W / 2 : flip
    {
      x: x, y: y * SHIP_BASE_SPEED,
      w: 8, h: 8,
      health: 12,
      moves: Moves.fighter_loop(flip ? -1 : 1),
      spr: SPRITES.enemy_fighter_01,
      bullets: [],
    }
  end

  def self.flyer x, y, offset = 0
    flip = x > FLY_RANGE_W / 2
    {
      x: x, y: y * SHIP_BASE_SPEED,
      w: 8, h: 8,
      flip_horizontally: flip,
      health: 40,
      moves: Moves.diagonal(flip ? -1 : 1),
      spr: SPRITES.enemy_flying_01,
      spr_flash: SPRITES.enemy_flying_01_flash,
      exp: SPRITES.explosion_02,
      active_offset: offset,
    }
  end

  def self.copter x, y
    {
      x: x, y: y * SHIP_BASE_SPEED,
      w: 12, h: 12,
      health: 60,
      moves: Moves.copter_move_1,
      spr: SPRITES.enemy_copter_01,
      bullets: [],
      exp: SPRITES.explosion_02,
    }
  end
  
end

module Formations

  def self.bomber_drop loc
    loc = loc * 16
    [
      Grunts.bomber_left(loc, 16),
      Grunts.bomber_left(loc, 26),
      Grunts.bomber_left(loc, 36),
      Grunts.bomber_left(loc, 46),
      
      Grunts.bomber_right(loc, 16),
      Grunts.bomber_right(loc, 26),
      Grunts.bomber_right(loc, 36),
      Grunts.bomber_right(loc, 46),
    ]
  end

  def self.fighter_dance loc
    loc = loc * 16
    [
      Grunts.fighter(-2, loc + 16),
      Grunts.fighter(10, loc),
      Grunts.fighter(10, loc + 64),
      Grunts.fighter(78, loc + 32),
      Grunts.fighter(78, loc + 96),
      Grunts.fighter(90, loc + 48),
    ]
  end

  def self.fighter_duet x, loc
    loc = loc * 16
    [
      Grunts.fighter(x - 8, loc),
      Grunts.fighter(x + 8, loc),
    ]
  end

  def self.diver_rush loc
    loc = loc * 16
    [
      Grunts.diver(13, loc),
      Grunts.diver(29, loc),
      Grunts.diver(45, loc),
      Grunts.diver(61, loc),
      Grunts.diver(77, loc),
    ]
  end

  def self.flyer_trio_left loc
    loc = loc * 16
    [
      Grunts.flyer(-16, loc, 16),
      Grunts.flyer(-16, loc, 32),
      Grunts.flyer(-32, loc, 16),
    ]
  end

  def self.flyer_trio_right loc
    loc = loc * 16
    [
      Grunts.flyer(FLY_RANGE_W + 16, loc, 16),
      Grunts.flyer(FLY_RANGE_W + 16, loc, 32),
      Grunts.flyer(FLY_RANGE_W + 32, loc, 16),
    ]
  end

  def self.copter_two_shot loc
    loc = loc * 16
    
    [
      Grunts.copter(20, loc),
      Grunts.copter(62, loc + 128),
    ]
  end
  
end

$gtk.reset
