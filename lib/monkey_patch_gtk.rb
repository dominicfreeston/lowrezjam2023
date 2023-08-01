module GTK
  module DirectionalInputHelperMethods
        # see https://github.com/DragonRuby/dragonruby-game-toolkit-contrib/blob/main/dragon/directional_input_helper_methods.rb
    
    # Patch left_right and up_down behaviour to
    # respect the most recently pressed key when both
    # directions are pressed, rather than favour one fixed
    # direction like the original implementation does.

    # Another equally "accurate" solution would be to return
    # 0 when both are pressed, meaning no movement.
    
    # The rationale for choosing this approach is that
    # when changing direction it's fairly likely that the
    # will player keep pressing the prior direction for a few frames.
    # This approach makes the controls feel more responsive.
    
    # because this confused me at first:
    # the `<=>` works because left, right up and down
    # store the tick they were pressed and nil when not
    # rather than a bool as you might think when reading `if inputs.left`
    # (i.e. it works as true/false but provides extra information - nice!)
    
    def left_right
      (self.right || 0) <=> (self.left || 0)
    end
    
    def up_down
      (self.up || 0) <=> (self.down || 0)
    end
  end
end
