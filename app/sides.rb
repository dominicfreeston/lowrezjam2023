
class Intro
  attr_gtk

  def tick
    my.phase ||= :start
    my.phase_start_time ||= state.tick_count

    args.lowrez.primitives << SPRITES.background
    
    case my.phase
    when :start
      sprite = SPRITES.logo_take_2
      fi = my.phase_start_time
             .frame_index sprite.count, sprite.first.duration, true
      args.lowrez.primitives << sprite[fi]

      if state.tick_count > my.phase_start_time + 150 || $input.shoot_now?
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
        my.phase_start_time = nil
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
        my.phase_start_time = nil
      end

    when :show_score
      score_alpha = 255
      score_offset = 12

      fi = my.phase_start_time
             .frame_index 4, 20, true
    end
    
    args.lowrez.primitives << [
      SPRITES.background,
      {
        x: 32 - x_offset, y: 64 - 16 + y_offset,
        text: "GAME",
        font: LOWREZ_FONT_PATH,
        alignment_enum: 1,
        vertical_alignment_enum: 2,
        size_enum: LOWREZ_FONT_LG
      }.merge!(COLOR3),
      {
        x: 32 + x_offset, y: 16 - y_offset,
        text: "OVER",
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
      if fi != 0
        [
         {
            x: 32, y: 16,
            text: "shoot to",
            font: LOWREZ_FONT_PATH,
            alignment_enum: 1,
            vertical_alignment_enum: 0,
            size_enum: LOWREZ_FONT_SM
          }.merge!(COLOR3),
         {
            x: 32, y: 14,
            text: "start again",
            font: LOWREZ_FONT_PATH,
            alignment_enum: 1,
            vertical_alignment_enum: 2,
            size_enum: LOWREZ_FONT_SM
          }.merge!(COLOR3),
        ]
      end
    ]

    if $input.shoot_now?
      reset_me
      $game.reset_me
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
    @shoot = :space
    @bomb = :shift
  end
  
  def shoot?
    inputs.keyboard.send @shoot
  end

  def shoot_now?
    inputs.keyboard.key_down.send @shoot
  end

  def bomb_now?
    inputs.keyboard.key_down.send @bomb
  end
end
