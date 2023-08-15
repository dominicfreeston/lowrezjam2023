require 'lib/monkey_patch_gtk.rb'
require 'lib/lowrez.rb'
require 'app/sprites.rb'
require 'app/constants.rb'
require 'app/enemies.rb'
require 'app/debug.rb'
require 'app/sides.rb'

$music_enabled = !$gtk.platform?(:web)

class Game
  attr_gtk
  
  def tick
    my.pause = !my.pause if inputs.keyboard.key_down.escape
    
    # $gtk.slowmo! 2
    my.tick_count ||= 0    
    setup unless my.setup

    my.phase ||= :level
    my.phase = :victory if my.phase == :boss &&
                           my.boss&.empty? &&
                           my.explosion_queue&.empty?

    if my.phase == :level && my.grunts.empty?
      my.phase = $music_enabled ? :transition : :boss
    end
    
    setup_boss if my.phase == :boss

    update_level_music

    if !my.pause
      my.tick_count += 1
      update_bullets
      update_player
      update_grunts
      update_boss
      update_explosions
    end
    
    render_screen
    
    # render_logo
    
    @invincible = !@invincible if inputs.keyboard.key_down.i

    render_debug args

    args.lowrez.primitives << [1, 2].map do |n|
      {
        x: 26 + n* 4,
        y: 32,
        w: 2,
        h: 8,
        anchor_x: 0.5,
        anchor_y: 0.5,
      }.merge!(COLOR2).solid!
    end if my.pause

    if my.phase == :victory
      $outro.my.won = true
      $current_scene = $outro
    end
  end


  def reset_player
    my.score = 0
    my.lives = 3
    my.bombs = 3
    reset_help_location
  end
  
  def setup
    my.player = {x: FLY_RANGE_W / 2 - 8,
                 y: 0, r_y: 16, w_y: 0,
                 w: 16, h: 16,
                 speed: 0}

    my.help1 = {w: 8, h: 8}
    my.help2 = {w: 8, h: 8}

    reset_player

    my.explosions = []
    my.apb = [] # active player bullets
    my.aeb = [] # active enemy bullets

    y = 4

    my.grunts = []

    y = 0
    
    y, s = Sequences.part_1(y)
    my.grunts += s

    y, s = Sequences.part_2(y + 2)
    my.grunts += s

    y, s = Sequences.part_3(y + 4)
    my.grunts += s

    y, s = Sequences.part_4(y + 4)
    my.grunts += s

    y, s = Sequences.part_5(y + 4)
    my.grunts += s
        
    my.setup = true
    
  end

  def setup_boss
    my.boss ||= (
      [
        {
          x: 15, y: 2, w: 6, h: 6, health: 150,
          name: "left_side", score: 20,
          spr: SPRITES.boss_left_eye_close,
          spr_flash: SPRITES.boss_left_eye_flash,
          spr_hurt: SPRITES.boss_left_eye_hurt,
          back_spr: SPRITES.boss_left,
          moves: Moves.boss_slide_down_last,
        },
        {
          x: 35, y: 2, w: 6, h: 6, health: 200,
          name: "center_left", score: 30,
          spr: SPRITES.boss_center_left_eye_close,
          spr_flash: SPRITES.boss_center_left_eye_flash,
          spr_hurt: SPRITES.boss_center_left_eye_hurt,
          back_spr: SPRITES.boss_center_left,
          moves: Moves.boss_slide_down_next,
        },
        {
          x: 45, y: 6, w: 6, h: 6, health: 250,
          name: "center", score: 50,
          spr: SPRITES.boss_center_eye_close,
          spr_flash: SPRITES.boss_center_eye_flash,
          spr_hurt: SPRITES.boss_center_eye_hurt,
          back_spr: SPRITES.boss_center,
          moves: Moves.boss_slide_down_first,
        },
        {
          x: 56, y: 2, w: 6, h: 6, health: 200,
          name: "center_right", score: 30,
          spr: SPRITES.boss_center_right_eye_close,
          spr_flash: SPRITES.boss_center_right_eye_flash,
          spr_hurt: SPRITES.boss_center_right_eye_hurt,
          back_spr: SPRITES.boss_center_right,
          moves: Moves.boss_slide_down_next,
        },
        {
          x: 74, y: 2, w: 6, h: 6, health: 150,
          name: "right_side", score: 20,
          spr: SPRITES.boss_right_eye_close,
          spr_flash: SPRITES.boss_right_eye_flash,
          spr_hurt: SPRITES.boss_right_eye_hurt,
          back_spr: SPRITES.boss_right,
          moves: Moves.boss_slide_down_last,
        },
      ]
    ).map do |b|

      b.spr_frame = 3
      b.active = false
      b.flash = 0
      
      b.sx = b.x
      b.sy = b.y

      b.y += my.player.w_y + 64
      
      b
    end
  end
  
  def reset_help_location
    
    my.help1.x = 0
    my.help1.y = my.player.w_y - 8
    my.help2.x = FLY_RANGE_W - 8
    my.help2.y = my.player.w_y - 8

  end

  
  def update_level_music
    return unless $music_enabled
    
    my.current_music&.paused = my.pause
    audio[:alarm]&.paused = my.pause


    if my.current_music
      my.current_music.gain = if (my.player_reset_timer || 0) > 0 ||
                                 my.pause
                                0.2
                              else
                                [my.current_music.gain + 0.01, 1].min
                              end
    end

    return if my.pause
    
    if my.phase == :level
      audio[:music] ||= { input: "sounds/kir-snes.ogg", looping: true, gain: 0.1 }
      my.current_music = audio[:music]
      
      
    elsif audio[:music] && audio[:music].gain > 0 ## transition
      
      audio[:music].gain -= 0.015
      
    elsif my.phase == :victory
      
      audio[:boss_music] = nil
      my.current_music = nil
      audio[:victory_music] ||= { input: "sounds/victory.wav", looping: false }
      
    else
      my.phase = :boss
      
      audio[:music] = nil

      audio[:alarm] ||= {
        input: "sounds/alarm.wav",
        looping: true, gain: 0.5
      } if !my.alarm_playcount
      
      my.alarm_playcount ||= 0
      my.alarm_playtime ||= 0
      
      if audio[:alarm]

        playtime = (audio[:alarm][:playtime] || 0)
        my.alarm_playcount += 1 if playtime < my.alarm_playtime
        my.alarm_playtime = playtime
        audio[:alarm].looping = false if my.alarm_playcount >= 3
        audio[:alarm].gain -= 0.002 if not audio[:alarm].looping
        
      end      

      audio[:boss_music] ||= { input: "sounds/boss.ogg", looping: true, gain: 0.0 }
      my.current_music = audio[:boss_music]
      audio[:boss_music].gain = [audio[:boss_music].gain + 0.002, 1].min
    end
  end
  
    
  def update_player
    
    p = my.player

    ## only do collisions when player is active
    if my.player_reset_timer.nil?
      
      # should maybe have made the player this size and then centered sprite
      # around it like I do for everything else but oh well!
      hitbox = {x: p.x + 7, y: p.y + 7, w: 2, h: 2}.quantize!
      
      obstacles = (my.aeb + my.grunts + (my.boss || [])).map do |t|
        t.quantize.merge!(og: t)
      end
      
      collisions = geometry.find_all_intersect_rect hitbox, obstacles

      unless collisions.empty? || @invincible

        outputs.sounds << "sounds/death.wav" if $music_enabled
        
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

      $current_scene = $outro if my.lives == 0 && my.player_reset_timer == 1
       
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

    if $input.shoot? &&
       my.tick_count > (p.last_shot || 0) + BULLET_GAP


      if (my.bomb_ticks || 0) <= 0 && $music_enabled
        audio[:shoot] = { input: "sounds/shoot.wav", looping: false, gain: 0.5}
      end
      
      shoot = true
      p.last_shot = my.tick_count
      # launch bullets based on visible position
      l = p.quantize
    
      my.apb += BULLET_POSITIONS.map do |b|
        {x: l.x + b.x, y: l.y + b.y, w: 1, h: 1}
      end
      
    end

    if $input.bomb_now? &&
       my.bombs > 0 &&
       my.tick_count > (p.last_bomb || 0) + BOMB_LENGTH
      p.last_bomb = my.tick_count
      trigger_bomb
    end

    update_bomb
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

  
  def trigger_bomb
    if $music_enabled
      audio[:bomb1] = {input:"sounds/bomb.wav"}    
      audio[:bomb2] = {input: "sounds/bomb-2.wav"}
    end
    my.current_music.gain = 0.1

    my.bombs -= 1
    my.bomb_ticks = BOMB_LENGTH

    mid = FLY_RANGE_W.idiv(2)
    add_explosion(
      {
        x: mid + (my.player.x + 8 - mid) * CAMERA_RATIO_W,
        y: my.player.w_y + 32,
        w: 0,
        h: 0,
        exp: SPRITES.explosion_bomb,
      }
    )
    
  end

  
  def update_bomb

    return unless (my.bomb_ticks || 0) > 0
    
    my.bomb_ticks -= 1

    my.aeb = []
    
    my.grunts.reverse_each do |g|
      
      next unless g.active
      
      g.health -= 1
      g.flash = 1

      destroy_grunt g if g.health <= 0
      
    end

    my.boss&.reverse_each do |g|
      
      next unless g.active
      
      g.health -= 1
      g.flash = 1

      # rely on main boss update to handle death
      
    end
  end
  
  def apply_shoot g
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
      g.bullets << bullet if g.bullets
      g.moves.shift

      g.moves = nil if g.moves.empty?
    end
  end

  def apply_moves g
    g.y += SHIP_BASE_SPEED
    Moves.apply_next_move g
  end
  
  def update_grunts
    
    my.grunts.reverse_each do |g|
      
      # by default become active when just above the visible line
      g.active ||= g.y < my.player.w_y + 64 + (g.active_offset || 0)
      next unless g.active

      # shoot all bullets
      apply_shoot g
      
      # move
      apply_moves g
      my.grunts.delete g if !g.moves

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

    outputs.sounds << "sounds/explosion.wav" if $music_enabled
    
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
                                    false,
                                    my.tick_count

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

    rot = [0, 90, 180, 360].sample
    my.explosions << {x: g.x + (g.w - ex.w) / 2,
                      y: g.y + (g.h - ex.h) / 2,
                      start_tick: my.tick_count,
                      spr: explosion.map { |e| e.merge(angle: rot) },
                      moves: g.moves&.map { |m| m.dup }}
  end


  def update_boss
    return unless my.boss
    my.boss_start ||= my.tick_count
    
    my.boss_end ||= 400
    t = my.boss_end
    if my.tick_count > my.boss_start + t
      my.boss_sequence = nil
    end
    
     my.boss_sequence ||= [
      [t += 60, :center_copter],
      [t += 40, :middle_barrage],
      [t += 40, :side_homing],
      [t += 60, :side_homing],
      [t += 40, :close_center],
      [t += 20, :center_copter],
      [t += 20, :center_copter],
      [t += 40, :center_copter],
      [t += 20, :center_copter],
      [t += 40, :close_center_cluster],
      [t += 40, :side_barrage],
      [t += 20, :side_barrage],
      [t += 60, :side_barrage],
      [t += 0, :open_center_cluster],
    ]
    my.boss_end = t

    # can move elsewhere?
    my.explosion_queue ||= []
    my.explosion_queue.reverse_each do |e|
      e.y += SHIP_BASE_SPEED
      e.delay -= 1

      if e.delay <= 0
        add_explosion e
        my.explosion_queue.delete e
      end
    end


    my.boss_sequence.each do |pattern|
      t, s = pattern
      if my.tick_count == my.boss_start + t
        BossPatterns.send s, my.boss        
      end
    end

    my.boss.reverse_each do |g|
      g.flash ||= 0
      g.flash -= 1 if g.flash
      
      g.moves ||= Moves.boss_head_move

      apply_shoot g
      # g.sy += SHIP_BASE_SPEED
      apply_moves g
      
      bullets = my.apb.map { |b| b.quantize.merge!(og: b) }
      collisions = $geometry.find_all_intersect_rect g, bullets
      
      if g.active && !collisions.empty?
        g.health -= collisions.length
        g.flash = 2
      end
    
      # Get killed?
      if g.health < 0
        my.boss.delete g
        outputs.sounds << "sounds/explosion.wav" if $music_enabled
        add_explosion g.merge(exp: SPRITES.explosion_02)

        my.explosion_queue += [
          g.merge(x: g.x - 4, delay: 15 + (rand * 60).to_i),
          g.merge(x: g.x + 4, delay: 15 + (rand * 60).to_i),
          g.merge(x: g.y - 4, delay: 15 + (rand * 60).to_i),
          g.merge(x: g.y + 4, delay: 15 + (rand * 60).to_i)
        ]

        my.score += g.score
      end

      my.apb = my.apb.difference collisions.map { |c| c.og }
    end

  end

  
  def boss_sprites
    return nil unless my.boss
    
    [
      my.boss.map do |b|
        b.back_spr
           .merge(
             x: 0,
             y: (b.y - b.sy).floor
           )
           .translate!(my.camera) if b.back_spr
      end,

      my.boss.map do |b|
        main_spr = (b.health >= 30 ? b.spr : b.spr_hurt)

        (b.flash > 0 ? b.spr_flash : main_spr[b.spr_frame])
          .merge(
            x: (b.x - b.sx).floor,
            y: (b.y - b.sy).floor,
          )
          .translate!(my.camera)
      end,
    ]
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
            to_render(my.player, player_sprite),
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

        boss_sprites,
        
        my.apb.map { |b| to_render(b, SPRITES.bullet_player) },
        my.aeb.map { |b| to_render(b) },
        
        #my.aeb.map { |b| to_debug(b) },
        
        my.grunts.filter_map { |e| to_render(e) if e.active },
        
        # my.boss&.map { |b| to_debug(b) },
      ])
  end

  def player_sprite
    dx = inputs.left_right
    if dx == 0 || my.player.speed < 0.8
      SPRITES.player
    else
      SPRITES.player_turn.merge(flip_horizontally: dx < 0)
    end
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

    if actor.spr_hurt && (h = actor.health) && h < 12
      sprite = actor.spr_hurt
    end
    
    if actor.flash && actor.flash > 0
      sprite = actor.spr_flash
      actor.flash -= 1
      return nil if !sprite
    end
    
    sprite ||= override || actor.spr || actor
    
    if sprite.is_a? Array
      fi = (actor.start_tick || 0)
             .frame_index sprite.count, sprite.first.duration, true, my.tick_count
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

  def reset_me
    state.game_state = {}
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
  $input ||= UserInput.new
  $intro ||= Intro.new
  $outro ||= Outro.new
  $game ||= Game.new

  $input.args = args
  $intro.args = args
  $outro.args = args
  $game.args = args

  reset if args.state.tick_count == 0
  
  args.lowrez.background_color = COLOR3
  $gtk.reset_next_tick if args.inputs.keyboard.r
  
  $current_scene.tick
end


def reset
  $current_scene = $intro
  $game.my.setup = false
  $gtk.reset_sprites
end



