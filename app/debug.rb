class Game
def render_debug args
  # if !args.state.grid_rendered
  #   65.map_with_index do |i|
  #     args.outputs.static_debug << {
  #       x:  LOWREZ_X_OFFSET,
  #       y:  LOWREZ_Y_OFFSET + (i * 10),
  #       x2: LOWREZ_X_OFFSET + LOWREZ_ZOOMED_SIZE,
  #       y2: LOWREZ_Y_OFFSET + (i * 10),
  #       r: 128,
  #       g: 128,
  #       b: 128,
  #       a: 80
  #     }.line!

  #     args.outputs.static_debug << {
  #       x:  LOWREZ_X_OFFSET + (i * 10),
  #       y:  LOWREZ_Y_OFFSET,
  #       x2: LOWREZ_X_OFFSET + (i * 10),
  #       y2: LOWREZ_Y_OFFSET + LOWREZ_ZOOMED_SIZE,
  #       r: 128,
  #       g: 128,
  #       b: 128,
  #       a: 80
  #     }.line!
  #   end
  # end

  args.state.grid_rendered = true

  args.state.last_click ||= 0
  args.state.last_up    ||= 0
  args.state.last_click   = args.state.tick_count if args.lowrez.mouse_down # you can also use args.lowrez.click
  args.state.last_up      = args.state.tick_count if args.lowrez.mouse_up
  args.state.label_style  = { size_enum: -1.5 }


  screen_position = to_render(my.player, {w: 0, h: 0})
  args.state.watch_list = [
    "frame_rate is:        #{args.gtk.current_framerate}",
    "tick_count is:       #{args.state.tick_count}",
    "mouse_position is:  #{args.lowrez.mouse_position.x}, #{args.lowrez.mouse_position.y}",
    "",
    "position:  #{my.player.x}",
    "           #{my.player.y}",
    "camera: #{my.camera.x}, #{my.camera.y}",
    "screen position:  #{screen_position.x}, #{screen_position.y}",
    "apb-count:   #{my.apb.length}",
    "",
    "enemy count: #{my.grunts.length}",
    "aeb-count:   #{my.aeb.length}",
    "",
    "invincible:   #{@invincible ? "yes" : "no"}",
  ]

  args.outputs.debug << args.state
                          .watch_list
                          .map_with_index do |text, i|
    {
      x: 5,
      y: 720 - (i * 20),
      text: text,
      size_enum: 0,
    }.label!.merge!(COLOR0)
  end

  
end
end
