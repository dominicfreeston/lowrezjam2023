
class Intro
  attr_gtk

  def tick
    my.phase ||= :start
    my.phase_start_time ||= state.tick_count

    args.lowrez.primitives << SPRITES.background
    
    case my.phase
    when :start
      audio[:victory] ||= { input: "sounds/victory.wav", looping: false,}
      sprite = SPRITES.logo_take_2
      fi = my.phase_start_time
             .frame_index sprite.count, sprite.first.duration, true
      args.lowrez.primitives << sprite[fi]

      if state.tick_count > my.phase_start_time + 120 || $input.shoot_now?
        my.phase = :transition
        my.phase_start_time = nil
      end
      
    when :transition
      sprite = SPRITES.logo_transition
      fi = my.phase_start_time
             .frame_index sprite.count, sprite.first.duration, false
      args.lowrez.primitives << sprite[fi || (sprite.count - 1)]

      if fi.nil? || $input.shoot_now?
        my.phase = :finish
        my.phase_start_time = nil        
      end
      
    when :finish
      sprite = SPRITES.logo_transition
      fi = my.phase_start_time
             .frame_index 4, 20, true
      
      args.lowrez.primitives << [
        SPRITES.star_background.merge(a: (state.tick_count - my.phase_start_time) * 2),
        sprite.last,
        unless fi == 0
          {
            x: 32, y: 16,
            text: "shoot to start",
            font: LOWREZ_FONT_PATH,
            alignment_enum: 1,
            size_enum: LOWREZ_FONT_SM
          }.merge!(COLOR3)
        end
      ]

      if $input.shoot_now?
        $current_scene = $game
      end
      
    end

  end

  def my # local state
    state.intro_state
  end

   def reset_me
    state.intro_state = {}
  end
end


class Outro
  attr_gtk
  
  def tick
    my.phase ||= :slide_in
    my.phase_start_time ||= args.tick_count

    x_offset = 64
    y_offset = 48
    score_offset = 0
    fi = 0
    
    case my.phase
    when :slide_in
      progress = args.easing.ease my.phase_start_time,
                                state.tick_count,
                                60,
                                :flip, :quint
      x_offset *= progress
      y_offset = 0

      if progress == 0
        my.phase = :slide_out
        my.phase_start_time = args.tick_count
      end

    when :slide_out
      progress = args.easing.ease my.phase_start_time,
                                state.tick_count,
                                30,
                                :flip, :quad, :flip
      x_offset = 0
      y_offset *= progress
      score_alpha = 255 * progress
      score_offset = 12 * progress * progress

      if progress == 1
        my.phase = :show_score
        my.phase_start_time = args.tick_count
      end

    when :show_score
      score_alpha = 255
      score_offset = 12

      fi = my.phase_start_time
             .frame_index 12, 20, true
    end

    if my.won
      lines = ["YOU", "WON!"]
    else
      lines = ["GAME", "OVER"]
    end
    
    args.lowrez.primitives << [
      SPRITES.background,
      {
        x: 32 - x_offset, y: 64 - 16 + y_offset,
        text: lines[0],
        font: LOWREZ_FONT_PATH,
        alignment_enum: 1,
        vertical_alignment_enum: 2,
        size_enum: LOWREZ_FONT_LG
      }.merge!(COLOR3),
      {
        x: 32 + x_offset, y: 16 - y_offset,
        text: lines[1],
        font: LOWREZ_FONT_PATH,
        alignment_enum: 1,
        vertical_alignment_enum: 0,
        size_enum: LOWREZ_FONT_LG
      }.merge!(COLOR3),
      if my.phase != :slide_in
         [
           {
             x: 32, y: 34 + score_offset,
             a: score_alpha,
             text: "score",
             font: LOWREZ_FONT_PATH,
             alignment_enum: 1,
             vertical_alignment_enum: 0,
             size_enum: LOWREZ_FONT_MD
           }.merge!(COLOR3),
           {
             x: 32, y: 30 + score_offset,
             a: score_alpha,
             text: args.state.game_state.score || 0,
             font: LOWREZ_FONT_PATH,
             alignment_enum: 1,
             vertical_alignment_enum: 2,
             size_enum: LOWREZ_FONT_MD
           }.merge!(COLOR3),
         ]
      end,
      if fi % 6 != 0 && !my.won
        if fi < 6
          lines = ["shoot to", "continue"]
        else
          lines = ["bomb to", "start again"]
        end
        [
          {
            x: 32, y: 16,
            text: lines[0],
            font: LOWREZ_FONT_PATH,
            alignment_enum: 1,
            vertical_alignment_enum: 0,
            size_enum: LOWREZ_FONT_SM
          }.merge!(COLOR3),
          {
            x: 32, y: 14,
            text: lines[1],
            font: LOWREZ_FONT_PATH,
            alignment_enum: 1,
            vertical_alignment_enum: 2,
            size_enum: LOWREZ_FONT_SM
          }.merge!(COLOR3),
        ]
      end,
      if my.won && my.phase == :show_score
        [
          {
            x: 32, y: 26,
            text: "thanks to",
            font: LOWREZ_FONT_PATH,
            alignment_enum: 1,
            size_enum: LOWREZ_FONT_SM
          }.merge!(COLOR3),
          {
            x: 32, y: 20,
            text: "you the world",
            font: LOWREZ_FONT_PATH,
            alignment_enum: 1,
            size_enum: LOWREZ_FONT_SM
          }.merge!(COLOR3),
          {
            x: 32, y: 14,
            text: "is now safe",
            font: LOWREZ_FONT_PATH,
            alignment_enum: 1,
            size_enum: LOWREZ_FONT_SM
          }.merge!(COLOR3),
        ]
      end,
    ]

    return unless my.phase == :show_score
    
    if my.won &&
       $input.shoot_now? ||
       $input.bomb_now?

      reset_me
      $intro.reset_me
      $game.reset_me
      $current_scene = $intro

      # leaky!
      audio[:music] = nil
      audio[:boss_music] = nil
      audio[:alarm] = nil
    
    elsif $input.shoot_now?
      
      reset_me
      $game.reset_player
      $current_scene = $game
      
    end
  end
  
  def my # local state
    state.outro_state
  end

  def reset_me
    state.outro_state = {}
  end
end


class UserInput
  attr_gtk

  def initialize
    @shoot = [:space, :enter, :x]
    @bomb = [:shift, :z, :c]
  end
  
  def shoot?
    @shoot.reduce(false) { |r, k| r || inputs.keyboard.send(k) } 
  end

  def shoot_now?
    @shoot.reduce(false) { |r, k| r || inputs.keyboard.key_down.send(k) }
  end

  def bomb_now?
    @bomb.reduce(false) { |r, k| r || inputs.keyboard.key_down.send(k) } 
  end
end
