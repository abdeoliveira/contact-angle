#!/usr/bin/ruby
require 'mini_magick'
require 'parallel'
load './functions.rb'


list = Dir[@workdir+"*"+IMAGE_PATTERN]


Parallel.each(list, in_processes: @cpus) do |pathfile|
  
  file = filename(pathfile)
  
  image  = import_image(pathfile)
  get_image_data(image)
 


  calculate_tolerance



  x0,y0 = drop_top
  


  ybottom = find_bottom(y0)
  image.crop "0x#{ybottom}+0+0"
  get_image_data(image)
  image = write_image(file,false)
  


  x_left,y_left,x1,y1 = drop_profile(x0,y0,-1)
  x_right,y_right,x2,y2 = drop_profile(x0,y0,1)

  
  
  x = []
  y = []
  size = 2
  color = [0,255,0]
  x_left.each.with_index do |c,i|
    l = y_left[i]
    if c > x1 and l < y1 
      change_pixels(c,l,size,color) 
      x << c
      y << @lines - l
    end
  end


  x_right.each.with_index do |c,i|
    l = y_right[i]
    if c < x2 and l < y2 
      change_pixels(c,l,size,color) 
      x << c
      y << @lines - l
    end
  end
  

  size = 3
  color = [255,0,0]
  change_pixels(x0,y0,size,color)
  change_pixels(x1,y1,size,color)
  change_pixels(x2,y2,size,color)
  
  image = write_image(file,true)
  
  write_data(file,'data/',x,y)

  puts file
end
#============================================

