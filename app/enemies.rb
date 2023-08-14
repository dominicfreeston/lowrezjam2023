# Moves are sequences of simple steps
# - Shoot moves don't consume a tick
module Moves
  def self.apply_next_move g
    # move
    if move = g.moves&.first
      g.x += (move.dx || 0)
      g.y += (move.dy || 0)
      g.angle = (g.angle || 0) + move.rot if move.rot
      g.active = move.active if move.active != nil
      g.spr_frame = move.spr_frame if move.spr_frame

      move.ticks ||= 0
      move.ticks -= 1
      g.moves.shift unless move.ticks > 0

      g.moves = nil if g.moves.empty?
    end
  end
  
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


  def self.boss_open_eye
    [
      { spr_frame: 3, ticks: 6 },
      { spr_frame: 2, ticks: 6 },
      { spr_frame: 1, ticks: 6 },
      { spr_frame: 0, ticks: 6, active: true},
    ]
  end

  def self.boss_close_eye
    [
      { spr_frame: 0, ticks: 6, active: false},
      { spr_frame: 1, ticks: 6 },
      { spr_frame: 2, ticks: 6 },
      { spr_frame: 3, ticks: 6 },
    ]
  end
  
  def self.boss_slide_down_first
    [
      {ticks: 220},
      {dy: -0.25, ticks: 56},
      {ticks: 60},
      *boss_open_eye,
    ]
  end

  def self.boss_slide_down_next
    [
      {ticks: 220},
      {dy: -0.25, ticks: 56},
      {ticks: 80 + (rand * 60).to_i},
      *boss_open_eye,
    ]
  end

  def self.boss_slide_down_last
    [
      {ticks: 360},
      {dy: -0.25, ticks: 56},
      {ticks: 30 + (rand * 40).to_i},
      *boss_open_eye,
    ]
  end
  
  def self.boss_head_move
    xdir = rand < 0.5 ? -1 : 1
    ydir = rand < 0.5 ? -1 : 1
    [
      {ticks: 20 + (rand * 50).to_i},
      {dx: xdir * 0.04,
       dy: ydir * 0.01,
       ticks: 50},
      {ticks: 20 + (rand * 50).to_i},
      {dx: xdir * -0.04,
       dy: ydir * -0.01,
       ticks: 50},
    ]
  end

  def self.boss_middle_barrage
    repeat_shoot Guns.bomber_gun, 10, 10
  end
end

module BossPatterns
  def self.middle_barrage boss
    boss.each do |b|
      if b.name.include?("center") && b.active
        
        Moves.apply_next_move b while b.moves
        b.moves = Moves.boss_middle_barrage
      end
    end
  end

  def self.side_barrage boss
    boss.each do |b|
      if b.name.include?("side") && b.active
        
        Moves.apply_next_move b while b.moves
        dir = b.name.include?("left") ? 1 : -1
        b.moves = Guns.boss_side_gun(dir).map { |g| {shoot: g} }
      end
    end
  end

  def self.close_center boss
    boss.each do |b|
      if b.name == "center" && b.active
        
        Moves.apply_next_move b while b.moves
        b.moves = Moves.boss_close_eye
      end
    end
  end

  def self.close_center_cluster boss
    boss.each do |b|
      if b.name.include?("center") && b.active
        
        Moves.apply_next_move b while b.moves
        b.moves = Moves.boss_close_eye
      end
    end
  end

  def self.open_center_cluster boss
     boss.each do |b|
      if b.name.include?("center") && !b.active
        
        Moves.apply_next_move b while b.moves
        b.moves = Moves.boss_open_eye
      end
    end
  end

  def self.side_homing boss
    boss.each do |b|
      if b.name.include?("side") && b.active
        
        Moves.apply_next_move b while b.moves
        b.moves = Guns.gunner_gun.map { |g| {shoot: g} }
      end
    end
  end

  def self.center_copter boss
    boss.each do |b|
      if b.active &&
         b.name.include?("center")
        
        Moves.apply_next_move b while b.moves
        b.moves = Guns.copter_gun.map { |g| {shoot: g} }
      end
    end
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

  def self.boss_side_gun dir
    [
      {
        x: 2, y: 1, w: 1, h: 1,
        vx: 0, vy: -0.5,
        flip_horizontally: dir < 0,
        spr: SPRITES.bullet_enemy_small,
      },
      {
        x: 2, y: 1, w: 1, h: 1,
        vx: dir * 0.1, vy: -0.5,
        flip_horizontally: dir < 0,
        spr: SPRITES.bullet_enemy_small,
      },
      {
        x: 2, y: 1, w: 1, h: 1,
        vx: dir * 0.2, vy: -0.5,
        flip_horizontally: dir < 0,
        spr: SPRITES.bullet_enemy_small,
      },
      {
        x: 2, y: 2, w: 1, h: 1,
        vx: dir * 0.2, vy: -0.25,
        flip_horizontally: dir < 0,
        spr: SPRITES.bullet_enemy_angle,
      },
      {
        x: 2, y: 2, w: 1, h: 1,
        vx: dir * 0.3, vy: -0.25,
        flip_horizontally: dir < 0,
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
      health: 10,
      score: 2,
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
      score: 4,
      moves: Moves.diagonal(flip ? -1 : 1),
      spr: SPRITES.enemy_flying_01,
      spr_flash: SPRITES.enemy_flying_01_flash,
      spr_hurt: SPRITES.enemy_flying_01_hurt,
      exp: SPRITES.explosion_02,
      active_offset: offset,
    }
  end

  def self.copter x, y
    {
      x: x - 6, y: y * SHIP_BASE_SPEED,
      w: 12, h: 12,
      health: 60,
      score: 6,
      moves: Moves.copter_move_1,
      spr: SPRITES.enemy_copter_01,
      spr_flash: SPRITES.enemy_copter_01_flash,
      spr_hurt: SPRITES.enemy_copter_01_hurt,
      bullets: [],
      exp: SPRITES.explosion_02,
    }
  end

  def self.gunner x, y, d=8
    {
      x: x - 4, y: y * SHIP_BASE_SPEED,
      w: 8, h: 8,
      health: 12,
      score: 2,
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

  def self.bomber_swap loc
    loc = loc * 16
    [
      Grunts.bomber_left(loc, 72),
      Grunts.bomber_left(loc, 60),
      Grunts.bomber_right(loc, 72),
      Grunts.bomber_right(loc, 60),
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

  def self.copter_descent loc
    loc = loc * 16
    [
      Grunts.copter(60, loc),
      Grunts.copter(36, loc),
    ]
  end
  
  def self.copter_two_shot loc
    loc = loc * 16
    [
      Grunts.copter(26, loc),
      Grunts.copter(70, loc + 128),
    ]
  end

  def self.gunner_duo x, loc, d = 8, spread = 12
    loc = loc * 16
    [
      Grunts.gunner(x - spread, loc, d),
      Grunts.gunner(x + spread, loc, d),
    ]
  end
    
  def self.gunner_stagger loc
    loc = loc * 16
    [
      Grunts.gunner(48, loc, 8),
      Grunts.gunner(36, loc + 20, 4),
      Grunts.gunner(60, loc + 40, 4),
      Grunts.gunner(14, loc + 80, 6),
      Grunts.gunner(82, loc + 60, 6),
    ]
  end

  def self.gunner_pincer loc
    y = loc * 16
    [
      Grunts.gunner(16, (y += 0 * 16), 8),
      Grunts.gunner(80, (y += 2 * 16), 8),
      Grunts.gunner(16, (y += 2 * 16), 12),
      Grunts.gunner(80, (y += 2 * 16), 12),
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

  def self.part_1 loc
    y = loc
    s = [
      *Formations.gunner_duo(48, y += 8, 4, 12),
      *Formations.gunner_duo(32, y += 8, 10, 6),
      *Formations.gunner_duo(64, y += 8, 10, 6),
      
      *Formations.gunner_duo(48, y += 8, 4, 16),
      
      *Formations.fighter_duet(80, y += 8),
      *Formations.fighter_duet(16, y += 8),
      
      *Formations.diver_rush(y += 8),
      *Formations.diver_rush(y += 1),
      *Formations.diver_rush(y += 1),
      *Formations.diver_rush(y += 1),

      *Formations.bomber_drop(y += 0),
    ]
    return y, s
  end

  def self.part_2 loc
    y = loc
    s = [
      # pretty nice little combo here
      *Formations.flyer_trio_right(y += 0),
      *Formations.copter_two_shot(y += 8),

      *Formations.bomber_drop(y += 12),

      *Formations.gunner_stagger(y += 8),
      *Formations.fighter_duet(70, y += 8),
      *Formations.fighter_duet(26, y += 2),

      *Formations.diver_rush(y += 2),
      *Formations.diver_rush(y += 2),

      *Formations.bomber_drop(y += 0),
    ]
    return y, s
  end

  # swarm pincer
  def self.part_3 loc
    y = loc
    s = [
      *Sequences.fighter_swarm(y += 4),
      *Formations.gunner_pincer(y += 8),
      *Formations.gunner_pincer(y += 12),
      *Formations.gunner_pincer(y += 12),
      *Formations.gunner_pincer(y += 12),
    ]
    return y, s
  end

  # quite tough!
  def self.part_4 loc
    y = loc
    s = [
      *Formations.fighter_dance(y += 0),
      *Formations.copter_descent(y += 2),
      *Formations.gunner_pincer(y += 4),
      *Formations.diver_rush(y += 2),
      *Formations.diver_rush(y += 1),
      *Formations.diver_rush(y += 1),
      *Formations.diver_rush(y += 6),
      *Formations.diver_rush(y += 2),
      *Formations.bomber_drop(y += 0),
      *Formations.fighter_dance(y += 4),
    ]
    return y, s
  end

  def self.part_5 loc
    y = loc
    s = [
      *Formations.flyer_trio_left(y += 0),
      *Formations.flyer_trio_right(y += 2),
      *Formations.copter_descent(y += 4),
      *Formations.diver_rush(y += 8),
      *Formations.diver_rush(y += 1),
      *Formations.diver_rush(y += 1),
      *Formations.bomber_swap(y += 4),
      *Formations.bomber_drop(y += 8),
      *Formations.copter_two_shot(y += 4),
      *Formations.diver_rush(y += 8),
      *Formations.diver_rush(y += 1),
      *Formations.diver_rush(y += 1),
      *Formations.copter_descent(y += 8),
      *Sequences.fighter_swarm(y += 0),
      *Formations.diver_rush(y += 2),
      *Formations.diver_rush(y += 1),
      *Formations.diver_rush(y += 1),
      *Formations.flyer_trio_left(y += 8),
      *Formations.copter_two_shot(y += 4),
    ]
    return y, s
  end
end

