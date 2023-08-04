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

  def self.fighter_loop flip, d = 32
    gun = Guns.fighter_gun
    [
      {dx: 0.3 * flip, dy: -0.4, ticks: d},
      {dx: 0.4 * flip, dy: -0.15, ticks: d},
      *gun.map do |g|
        {shoot: g, exp: SPRITES.fighter_fire}
      end,
      {dx: 0.4 * flip, dy: 0.15, ticks: d},
      {dx: 0.3 * flip, dy: 0.4, ticks: d},      
    ]
  end


  def self.copter_move_1
    [
      {dy: -0.4, ticks: 60},
      {ticks: 45},
      *repeat_shoot(Guns.copter_gun, 10, 30),
      {ticks: 120},
      {dy: 0.4, ticks: 70},
    ]
  end

  def self.down_round_out d=1
    gun = Guns.gunner_gun
    [
      {dy: -0.8, ticks: d * 2},
      {dy: -0.6, ticks: d},
      {dy: -0.4, ticks: d},
      {ticks: 60},
      *gun.map { |g| {shoot: g} },
      {ticks: 60},
      {rot: 10, ticks: 18},
      {ticks: 15},
      {dy: 0.8, ticks: 30},
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
      {
        x: 5, y: 0, w: 1, h: 1,
        vx: -0.4, vy: -0.4,
        flip_horizontally: true,
        spr: SPRITES.bullet_enemy_angle
      },
      {
        x: 2, y: 0, w: 1, h: 1,
        vx: 0.4, vy: -0.4,
        spr: SPRITES.bullet_enemy_angle
      },
    ]
  end

  def self.gunner_gun
    [
      {
        x: 3, y: 0, w: 1, h: 1,
        aim: true, vel: 0.6,
        spr: SPRITES.bullet_enemy_tiny,
      },
      {
        x: 4, y: 0, w: 1, h: 1,
        aim: true, vel: 0.6,
        spr: SPRITES.bullet_enemy_tiny,
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
# - Activate when in range (active_offset to tweak)
# - Bullets disappear on death
module Grunts  
  def self.bomber_left loc, slide
    {
      x: -6, y: loc * SHIP_BASE_SPEED,
      w: 6, h: 6,
      health: 6,
      moves: Moves.slide_shoot_leave(1, slide, Guns.bomber_gun),
      spr: SPRITES.enemy_bomber_01,
      spr_flash: SPRITES.enemy_bomber_01_flash,
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
      spr_flash: SPRITES.enemy_bomber_01_flash,
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
      spr_flash: SPRITES.enemy_diver_01_flash,
    }
  end

  def self.fighter x, y, flip = nil
    # maybe remove default move?
    flip = flip.nil? ? x > FLY_RANGE_W / 2 : flip
    {
      x: x, y: y * SHIP_BASE_SPEED,
      w: 8, h: 8,
      health: 12,
      moves: Moves.fighter_loop(flip ? -1 : 1),
      spr: SPRITES.enemy_fighter_01,
      spr_flash: SPRITES.enemy_fighter_01_flash,
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
      spr_flash: SPRITES.enemy_copter_01_flash,
      bullets: [],
      exp: SPRITES.explosion_02,
    }
  end

  def self.gunner x, y, d=8
    {
      x: x, y: y * SHIP_BASE_SPEED,
      w: 8, h: 8,
      health: 12,
      moves: Moves.down_round_out(d),
      spr: SPRITES.enemy_gunner_01,
      spr_flash: SPRITES.enemy_gunner_01_flash,
      bullets: [],
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

  def self.fighter_dance loc,
    loc = loc * 16
    [
      Grunts.fighter(-2, loc + 16),
      Grunts.fighter(10, loc),
      Grunts.fighter(10, loc + 64),
      Grunts.fighter(78, loc + 32),
      Grunts.fighter(78, loc + 96),
      Grunts.fighter(90, loc + 48),
    ].map do |g|
      flip = g.x > FLY_RANGE_W / 2 ? -1 : 1
      g.merge(moves: Moves.fighter_loop(flip))
    end
  end

  def self.fighter_duet x, loc
    flip = x > FLY_RANGE_W / 2 ? - 1 : 1
    loc = loc * 16
    [
      Grunts.fighter(x - 6, loc)
        .merge(moves: Moves
                 .fighter_loop(flip,
                               52 + flip * 8)),
      Grunts.fighter(x + 6, loc)
        .merge(moves: Moves
                 .fighter_loop(flip,
                               52 - flip * 8)),
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

  def self.gunner_stagger loc
    loc = loc * 16
    [
      Grunts.gunner(44, loc, 8),
      Grunts.gunner(32, loc + 20, 4),
      Grunts.gunner(56, loc + 40, 4),
      Grunts.gunner(10, loc + 80, 6),
      Grunts.gunner(78, loc + 60, 6),
    ]
  end
  
end

module Sequences
  def self.first_try loc
    [
      *Formations.gunner_stagger(loc + 8),
      *Formations.gunner_stagger(loc + 20),
      *Formations.gunner_stagger(loc + 32),
      *Formations.copter_two_shot(loc + 36),
      *Formations.flyer_trio_left(loc + 40),
      *Formations.bomber_drop(loc + 54),
      *Formations.fighter_dance(loc + 60)
    ]
  end

  def self.fighter_swarm loc
    [
      
      *Formations.fighter_dance(loc + 8),
      *Formations.fighter_dance(loc + 12),
      *Formations.fighter_duet(16, loc + 20),
      *Formations.fighter_duet(60, loc + 22),
      *Formations.fighter_duet(72, loc + 24),
      *Formations.fighter_dance(loc + 28),
      *Formations.fighter_dance(loc + 36),
      *Formations.fighter_dance(loc + 40),
      *Formations.fighter_dance(loc + 44),
    ]    
  end
end

$gtk.reset