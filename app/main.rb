require 'lib/monkey_patch_gtk.rb'
require 'lib/lowrez.rb'
require 'app/sprites.rb'
require 'app/constants.rb'
require 'app/debug.rb'

# Thoughts on sizes and coordinates
# - use sub-pixel to track movement for the sake of speed variation but do all spawning, collision detection etc. based on actual pixel position. (maybe even have a separate rx, ry and update x y accordingly?)
# - even though there's also world coordiantes, do collisions based on screen coordinates? it should work out the same and arguably removes the risk of any inconsistencies?
# - remember that sprite size might be different to entity size

module Moves

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
      {shoot: gun},
      {ticks: 30},
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
  
end

module Grunts

  def self.bomber_gun
    {
      x: 2, y: 0, w: 2, h: 1,
      vy: -0.5,
      spr: SPRITES.bullet_enemy_large,
    }
  end
  
  def self.bomber_left loc, slide
    {x: -6, y: loc * SHIP_BASE_SPEED,
     w: 6, h: 6,
     health: 2,
     moves: Moves.slide_shoot_leave(1, slide, bomber_gun),
     spr: SPRITES.enemy_bomber_01,
     bullets: [],
     active: false,
     active_offset: -8,
    }
  end

  def self.bomber_right loc, slide
    {x: FLY_RANGE_W, y: loc * SHIP_BASE_SPEED,
     w: 6, h: 6,
     health: 2,
     moves: Moves.slide_shoot_leave(-1, slide, bomber_gun),
     spr: SPRITES.enemy_bomber_01,
     bullets: [],
     active: false,
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
      active: false,
    }
  end

  def self.flyer x, y, offset = 0
    flip = x > FLY_RANGE_W / 2
    {
      x: x, y: y * SHIP_BASE_SPEED,
      w: 8, h: 8,
      flip_horizontally: flip,
      health: 32,
      moves: Moves.diagonal(flip ? -1 : 1),
      spr: SPRITES.enemy_flying_01,
      spr_flash: SPRITES.enemy_flying_01_flash,
      exp: SPRITES.explosion_02,
      active: false,
      active_offset: offset,
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
  
end

class Game
  attr_gtk
  
  def tick
    
    setup if state.tick_count == 0

    update_bullets
    update_player
    update_grunts
    update_explosions

    render_screen

    $gtk.reset_next_tick if inputs.keyboard.r
  end

  
  def setup
    
    my.player = {x: FLY_RANGE_W / 2 - 8,
                 y: 0, r_y: 16, w_y: 0,
                 w: 16, h: 16,
                 speed: 0}
    
    my.help1 = my.player.merge(
      x: my.player.x + HELP1_POS.x,
      y: my.player.y + HELP1_POS.y,
      w: 8, h: 8)
    
    my.help2 = my.player.merge(
      x: my.player.x + HELP2_POS.x,
      y: my.player.y + HELP2_POS.y,
      w: 8, h: 8)

    my.explosions = []
    my.apb = [] # active player bullets
    my.aeb = [] # active enemy bullets


    my.grunts = [
      *Formations.bomber_drop(8),
      *Formations.bomber_drop(24),
      *Formations.diver_rush(16),

      *Formations.flyer_trio_left(8),
      *Formations.flyer_trio_right(16),
     ]
    
  end

  
  def update_player
    
    p = my.player

    p.w_y += SHIP_BASE_SPEED
    p.y = p.w_y + p.r_y
    
    if movement = inputs.directional_vector

      p.speed += 0.1
      p.x = (p.x + movement.x * [p.speed, SHIP_SPEED_X].min)
              .clamp(0, FLY_RANGE_W - 16)
      p.r_y = (p.r_y + movement.y * [p.speed, SHIP_SPEED_Y].min)
                .clamp(0, FLY_RANGE_H - 16)

    else

      p.speed = 0
      p.quantize!
      
    end

    if inputs.keyboard.space &&
       state.tick_count > (p.last_shot || 0) + BULLET_GAP

      shoot = true
      p.last_shot = state.tick_count
      # launch bullets based on visible position
      l = p.quantize
    
      my.apb += BULLET_POSITIONS.map do |b|
        {x: l.x + b.x, y: l.y + b.y, w: 1, h: 1}
      end
      
    end

    update_help my.help1, shoot, {x: p.x + HELP1_POS.x, y: p.y + HELP1_POS.y }
    update_help my.help2, shoot, {x: p.x + HELP2_POS.x, y: p.y + HELP2_POS.y }
    
  end

  
  def update_help help, shoot, target

    help.y +=  SHIP_BASE_SPEED
    
    a = help.angle_to target
    d = geometry.distance(help, target)
    speed = if d > 8 then SHIP_SPEED_X else [d, HELP_SPEED].min end

    
    help.x += a.vector_x * speed
    help.y += a.vector_y * speed
    

    if shoot
      l = help.quantize
      my.apb += HELP_BULLET_POS.map do |b|
        {x: l.x + b.x, y: l.y + b.y, w: 1, h: 1}
      end
    end
    
  end

  def update_grunts
    my.grunts.reverse_each do |g|

      # by default become active when just above the visible line
      g.active ||= g.y < my.player.w_y + 64 + (g.active_offset || 0)
      next unless g.active

      g.y += SHIP_BASE_SPEED

      if (move = g.moves&.first)
        if (gun = move.shoot)
          
          bullet = gun.dup
          bullet.x += g.x
          bullet.y += g.y
          
          my.aeb << bullet
          g.bullets << bullet unless move.persistent
          g.moves.shift
          
        else # default is movement
          
          g.x += (move.dx || 0)
          g.y += (move.dy || 0)
          move.ticks -= 1
          g.moves.shift unless move.ticks > 0
          
        end

        my.grunts.delete g if g.moves.empty?
      end
      
      collisions = $geometry.find_all_intersect_rect g, my.apb
      next if collisions.empty?
      
      g.health -= collisions.length
      g.flash = 2

      if g.health <= 0
        my.grunts.delete g
        my.aeb = my.aeb.difference g.bullets if g.bullets
        add_explosion g
      end
      
      my.apb = my.apb.difference collisions
      
    end
  end
  
  def update_bullets
    
    my.apb.reverse_each do |b|
      b.y += BULLET_SPEED + SHIP_BASE_SPEED
      my.apb.delete(b) if b.y > (my.player.w_y + 128)
    end

    my.aeb.reverse_each do |b|
      b.x += (b.vx || 0)
      b.y += (b.vy || 0) + SHIP_BASE_SPEED
      # TODO delete when out of range
    end
    
  end

  def update_explosions
    my.explosions.reverse_each do |e|
      e.y += SHIP_BASE_SPEED
      
      sprite = e.spr
      fi = e.start_tick.frame_index sprite.count,
                                    sprite.first.duration,
                                    false

      if fi
        e.merge!(sprite[fi])
      else
        my.explosions.delete e
      end

    end
  end

  def add_explosion g
    explosion = g.exp || SPRITES.explosion_01
    ex = explosion.first
    
    my.explosions << {x: g.x + (g.w - ex.w) / 2,
                      y: g.y + (g.h - ex.h) / 2,
                      start_tick: state.tick_count,
                      spr: explosion}
  end
  
  def render_screen

    args.lowrez.background_color = COLOR3
    
    my.camera = {
      x: ((my.player.x) * (CAMERA_RATIO_W - 1)),
      y: -my.player.w_y,
    }


    # TODO: Think about parallax for background
    b_off_1 = (my.player.w_y + 128).idiv(256) * 256
    b_off_2 = (my.player.w_y).idiv(256) * 256 + 128
    
    args.lowrez.primitives << (
      [
        SPRITES.star_background
          .merge(x: b_off_1 / 64 % -64, y: b_off_1)
          .translate!(my.camera),
        SPRITES.star_background
          .merge(x: b_off_2 / 64 % 64 - 64, y: b_off_2)
          .translate!(my.camera),
        
        to_render(my.player, SPRITES.player),
        to_render(my.help1, SPRITES.help1),
        to_render(my.help2, SPRITES.help2),


        #my.explosions.map { |e| to_debug(e) },
        my.explosions.map { |e| to_render(e) },
        

        my.apb.map { |b| to_render(b, SPRITES.bullet_player) },
        my.aeb.map { |b| to_render(b) },
        
        #my.aeb.map { |b| to_debug(b) },
        
        my.grunts.filter_map { |e| to_render(e) if e.active },
        
      ])

    render_debug args
    
  end

  
  def to_render(actor, override = nil)

    sprite = actor.flash && actor.flash > 0 && actor.spr_flash
    actor.flash -= 1 if actor.flash
    
    sprite ||= override || actor.spr || actor
    
    if sprite.is_a? Array
      fi = (actor.start_tick || 0)
             .frame_index sprite.count, sprite.first.duration, true
      sprite = sprite[fi]
    end
    
    actor
      .quantize
      .translate!({x: (actor.w - sprite.w).idiv(2),
                   y: (actor.h - sprite.h).idiv(2)})
      .translate!(my.camera)
      .merge!(sprite)

  end

  
  def to_debug actor
    actor.quantize.translate(my.camera).solid!.merge!({r: 255, g: 0, b: 0})
  end

  
  def my # local state
    state.game_state
  end
  
end


class Hash

  def quantize!
    
    self.x = self.x.floor.to_i
    self.y = self.y.floor.to_i
    self
    
  end

  
  def quantize
    
    self.dup.quantize!
    
  end

  def translate! camera

    self.x = (self.x + camera.x.floor.to_i)
    self.y = (self.y + camera.y.floor.to_i)
    self
    
  end

  def translate camera

    self.dup.translate! camera
    
  end
  
end


def tick args
  
  $game ||= Game.new
  $game.args = args
  $game.tick
  
end

$gtk.reset

def reset
  $gtk.reset_sprites
end


