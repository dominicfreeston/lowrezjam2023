require 'lib/monkey_patch_gtk.rb'
require 'lib/lowrez.rb'
require 'app/sprites.rb'
require 'app/constants.rb'
require 'app/enemies.rb'
require 'app/debug.rb'
require 'app/playground.rb'

class Game
  attr_gtk
  
  def tick
    # $gtk.slowmo! 2
    
    setup if state.tick_count == 0

    update_bullets
    update_player
    update_grunts
    update_explosions

    args.lowrez.background_color = COLOR3
    render_screen
    
    # render_logo
    
    @invincible = !@invincible if inputs.keyboard.key_down.i
    $gtk.reset_next_tick if inputs.keyboard.r

    render_debug args
  end

  
  def setup
    my.player = {x: FLY_RANGE_W / 2 - 8,
                 y: 0, r_y: 16, w_y: 0,
                 w: 16, h: 16,
                 speed: 0}

    my.score = 0
    my.lives = 3
    my.bombs = 3
    
    my.help1 = {w: 8, h: 8}
    my.help2 = {w: 8, h: 8}

    reset_help_location

    my.explosions = []
    my.apb = [] # active player bullets
    my.aeb = [] # active enemy bullets
    
    my.grunts = [
      # *Formations.bomber_drop(8),
      # *Formations.bomber_drop(24),
      
      # *Formations.diver_rush(16),

      # *Formations.flyer_trio_left(8),
      # *Formations.flyer_trio_right(16),

      # *Formations.diver_rush(32),

      # *Formations.copter_two_shot(8),
      
      # *Formations.fighter_dance(16),

      # *Formations.fighter_duet(16, 8),
      # *Formations.fighter_duet(72, 16),

      *Sequences.fighter_swarm(0),
      
     ]
    
  end

  def reset_help_location
    
    my.help1.x = 0
    my.help1.y = my.player.w_y - 8
    my.help2.x = FLY_RANGE_W - 8
    my.help2.y = my.player.w_y - 8

  end
  
  def update_player
    
    p = my.player

    ## only do collisions when player is active
    if my.player_reset_timer.nil?
      
      # should maybe have made the player this size and then centered sprite
      # around it like I do for everything else but oh well!
      hitbox = {x: p.x + 7, y: p.y + 7, w: 2, h: 2}.quantize!
      
      obstacles = (my.aeb + my.grunts).map do |t|
        t.quantize.merge!(og: t)
      end
      
      collisions = geometry.find_all_intersect_rect hitbox, obstacles

      unless collisions.empty? || @invincible
        
        my.lives -= 1
        my.player_reset_timer = PLAYER_RESET_TIME
        add_explosion p.merge(exp: SPRITES.explosion_02)

        # explode with me!
        collisions.each do |c|
          g = c.og
          unless g.health.nil?
            g.health -= 32
            destroy_grunt g if g.health <= 0
          end
        end
        
      end
      
    elsif  my.player_reset_timer <= -PLAYER_RECOVERY_TIME
      
      my.player_reset_timer = nil
      
    elsif my.player_reset_timer <= 0 # player invincible
      
       my.player_reset_timer -= 1
       
    else # player resetting
      
      my.player_reset_timer -= 1

      p.r_y = 16
      p.x += (FLY_RANGE_W.idiv(2) - 8 - p.x).sign * 1
      p.quantize!
      
      reset_help_location
       
    end
    
    p.w_y += SHIP_BASE_SPEED
    p.y = p.w_y + p.r_y

    return if (my.player_reset_timer || 0) > 0

    if movement = inputs.directional_vector

      p.speed += 0.1
      p.x = (p.x + movement.x * [p.speed, SHIP_SPEED_X].min)
              .clamp(0, FLY_RANGE_W - 16)
      p.r_y = (p.r_y + movement.y * [p.speed, SHIP_SPEED_Y].min)
                .clamp(-4, FLY_RANGE_H - 16)

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

    if inputs.keyboard.x &&
       my.bombs > 0 &&
       state.tick_count > (p.last_bomb || 0) + 60
      p.last_bomb = state.tick_count
      apply_bomb
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

  
  def apply_bomb
    
    my.bombs -= 1
    
    my.grunts.reverse_each do |g|
      
      next unless g.active
      
      g.health -= 24
      g.flash = 12

      destroy_grunt g if g.health <= 0
      
    end
    
  end

  
  def update_grunts
    
    my.grunts.reverse_each do |g|
      
      # by default become active when just above the visible line
      g.active ||= g.y < my.player.w_y + 64 + (g.active_offset || 0)
      next unless g.active

      # shoot all bullets
      while (move = g.moves&.first) && (gun = move&.shoot)
        bullet = gun.dup
        bullet.x += g.x.floor
        bullet.y += g.y.floor

        # aimed bullets
        if v = bullet.vel
          t = {
            x: (my.player.x + my.player.w / 2).floor,
            y: (my.player.y + my.player.h / 2).floor,
          } 
          a = bullet.angle_to t
          bullet.vx = a.vector_x * v
          bullet.vy = a.vector_y * v
        end

        # Add a fire animation if present
        add_explosion g.merge(exp: move.exp) if move.exp
        
        my.aeb << bullet
        g.bullets << bullet
        g.moves.shift
      end

      g.y += SHIP_BASE_SPEED
      if move = g.moves&.first
        g.x += (move.dx || 0)
        g.y += (move.dy || 0)
        g.angle = (g.angle || 0) + move.rot if move.rot
        move.ticks -= 1
        g.moves.shift unless move.ticks > 0
       
        my.grunts.delete g if g.moves.empty?
      end

      # Get shot?
      bullets = my.apb.map { |b| b.quantize.merge!(og: b) }
      collisions = $geometry.find_all_intersect_rect g, bullets
      next if collisions.empty?
      
      g.health -= collisions.length
      g.flash = 2

      # Get killed?
      destroy_grunt g if g.health <= 0
      
      my.apb = my.apb.difference collisions.map { |c| c.og }
      
    end
  end

  
  def destroy_grunt g
    
    my.grunts.delete g
    my.aeb = my.aeb.difference g.bullets if g.bullets
    add_explosion g
    my.score += g.score || 1

  end

  
  def update_bullets
    
    my.apb.reverse_each do |b|
      b.y += BULLET_SPEED + SHIP_BASE_SPEED
      my.apb.delete(b) if b.y > (my.player.w_y + 128)
    end

    active_area = {x: 0, y: my.player.w_y, w: FLY_RANGE_W, h: FLY_RANGE_H}
    my.aeb.reverse_each do |b|
      b.x += (b.vx || 0)
      b.y += (b.vy || 0) + SHIP_BASE_SPEED
      my.aeb.delete(b) unless active_area.intersect_rect? b
    end
    
  end

  
  def update_explosions
    my.explosions.reverse_each do |e|
      e.y += SHIP_BASE_SPEED
      
      while e.moves&.first&.shoot
        e.moves.shift
      end
        
      if move = e&.moves&.first
        e.x += (move.dx || 0)
        e.y += (move.dy || 0)
        move.ticks -= 1
        e.moves.shift unless move.ticks > 0
      end
      
      sprite = e.spr
      fi = e.start_tick.frame_index sprite.count,
                                    sprite.first.duration,
                                    false

      if fi
        ex = sprite[fi]
        e.merge!(ex)
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
                      spr: explosion,
                      moves: g.moves&.map { |m| m.dup }}
  end

  
  def render_screen
    
    my.camera = {
      x: ((my.player.x) * (CAMERA_RATIO_W - 1)),
      y: -my.player.w_y,
    }


    # TODO: Think about parallax for background
    s = 256
    s2 = s * 2
    b_off_1 = (my.player.w_y + s).idiv(s2) * s2
    b_off_2 = (my.player.w_y).idiv(s2) * s2 + s

    p = my.player
    hitbox = {x: p.x + 7, y: p.y + 7, w: 2, h: 2}.quantize!
    
    args.lowrez.primitives << (
      [
        SPRITES.star_background
          .merge(x: b_off_1 / 1.31 % -64, y: b_off_1)
          .translate!(my.camera),
        SPRITES.star_background
          .merge(x: b_off_2 / 1.76 % 64 - 64, y: b_off_2)
          .translate!(my.camera),
        #to_debug(hitbox),

        
        my.explosions.map { |e| to_render(e) },
        # my.explosions.map { |e| to_debug(e) },
        (0...my.lives).map do |i|
          SPRITES.tiny_ship.merge(x: 1 + i * 6, y: 1)
        end,

        (0...my.bombs).map do |i|
          SPRITES.tiny_bomb.merge(x: 60 - 4 * i, y: 1)
        end,

        score_label(my.score),

        if my.player_reset_timer.nil?
          [
            to_render(my.player, SPRITES.player),
            to_render(my.help1, SPRITES.help1),
            to_render(my.help2, SPRITES.help2),
          ]
        elsif my.player_reset_timer <= 0
          [
            to_render(my.player, SPRITES.player_invincible),
            to_render(my.help1, SPRITES.help1),
            to_render(my.help2, SPRITES.help2),
          ]
        end,

        my.apb.map { |b| to_render(b, SPRITES.bullet_player) },
        my.aeb.map { |b| to_render(b) },
        
        #my.aeb.map { |b| to_debug(b) },
        
        my.grunts.filter_map { |e| to_render(e) if e.active },
        
      ])
  end

  def score_label score
    {
      x: 64, y: 63, text: score,
      font: LOWREZ_FONT_PATH,
      size_enum: LOWREZ_FONT_SM,
      alignment_enum: 2,
      vertical_alignment_enum: 2,
    }.merge!(COLOR2)
  end
  
  def to_render(actor, override = nil)

    if actor.flash && actor.flash > 0
      sprite = actor.spr_flash
      actor.flash -= 1
      return nil if !sprite
    end
    
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
