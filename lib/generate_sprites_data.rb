module CodeGen

  def self.generate_sprites_data

    output = "# This file is auto-generated from the sprites data.\n"
    output += "# To re-generate it with the latest data, run:\n"
    output += "# './dragonruby mygame --eval lib/generate_sprites_data.rb --no-tick'\n"
    output += "SPRITES = {\n"
    $gtk.list_files("sprites").each do |s|
      next unless s.end_with? ".png"
      
      path = "sprites/" + s
      name = s.delete_suffix(".png") 
      key = s.gsub("-", "_").delete_suffix!(".png")

      ## Sprite sheet
      if $gtk.stat_file "sprites/#{name}.json"
            
        frames = $gtk.parse_json_file("sprites/#{name}.json")["frames"]
        
        output += "  #{key}: [\n"
        frames.each do |f|
          d = f["duration"]
          d = (d.to_i / 1000 * 60).to_i
          f = f["frame"]
          x = f["x"]; y = f["y"]; w = f["w"]; h = f["h"]
          
          output += "    {w: #{w}, h: #{h}, tile_x: #{x}, tile_y: #{y}, tile_w: #{w}, tiles_h: #{h}, path: \"#{path}\", duration: #{d}}.sprite!,\n"
        end
        output += "  ],\n"

      ## Single sprite
      else
        w, h = $gtk.calcspritebox path
        output += "  #{key}: {w: #{w}, h: #{h}, path: '#{path}'}.sprite!,\n"
      end
    end

    output += "}"
    file = "app/sprites.rb"
    $gtk.write_file file, output

    puts "The following output has been written to '#{file}':\n#{output}"
  end

end
  
if $gtk.cli_arguments.has_key?(:eval)
  
  CodeGen.generate_sprites_data
  
end
