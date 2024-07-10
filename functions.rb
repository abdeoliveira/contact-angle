
parameters_file = ARGV[0]
if parameters_file.nil? then puts 'Missing parameters file. ABORTED.'; abort end 
tmp = parameters_file.split('/').last
@workdir = parameters_file.split(tmp).first+'/'
load parameters_file



@cpus = ARGV[1]
@cpus ||= 1
@cpus = @cpus.to_i



#IMPORTS RAW IMAGE AND DECOLORIZE 
def import_image(file)
  image = MiniMagick::Image.open(file)
  image.colorspace "Gray"
  x0 = (FRACTION_CUT_HORIZONTAL*image.width).to_i
  y0 = (FRACTION_CUT_SKY*image.height).to_i
  dx = (image.width-2*x0).to_i
  dy = (image.height).to_i
  image.crop "#{dx}x#{dy}+#{x0}+#{y0}"
  return image
end




# SELF-EXPLANATORY
def get_image_data(image)
  @pixels = image.get_pixels
  @columns = image.width
  @lines = image.height
end



# CREATE DIRECTORY IF IT DOESN'T EXISTS 
def create_directory(dir)
  dir = @workdir+dir
  system 'mkdir', '-p', dir
  return dir
end


# STRIP PATHFILE 
def filename(pathfile)
  return pathfile.sub(@workdir,'')
end



def write_data(file,dir,x,y,p)
  dir = create_directory(dir)
  file.sub!(IMAGE_PATTERN,'.dat')
  xyfile = dir + 'xy-' + file 
  File.write(xyfile,'',mode:'w')
  x.each.with_index do |c,i|
    c = c.round(p)
    l = y[i].round(p)
    File.write(xyfile,"#{c} #{l}\n",mode:'a')
  end
end



# LOAD TRANSFORMED PIXELS INTO IMAGE
def write_image(file,write)
  dir = create_directory('images/')
  dimension = [@columns,@lines]
  image2 = MiniMagick::Image.get_image_from_pixels(@pixels, dimension,'rgb',8,'png')
  if write then image2.write(dir+file) end
  return image2
end



# BOUNDARY CONDITIONS
def  boundary(c,l)
  if c >= @columns then c = @columns - 1 end
  if c < 0 then c = 0 end
  if l >= @lines then l = @lines - 1 end
  if l < 0 then l = 0 end
  return c,l
end




#BLACK PIXEL MEASUREMENT
def black_pixel(c,l)
  c = c.to_i
  l = l.to_i
  c,l = boundary(c,l)
  red   = @pixels[l][c][0]
  green = @pixels[l][c][1]
  blue  = @pixels[l][c][2]
  white = red + green + blue 
  white = white.to_f/765
  black = 1 - white
  return black
end




# CHANGE PIXEL COLOR
def change_pixels(c,l,s,color)
  c = c.to_i
  l = l.to_i
  r,g,b = color
  (c-s..c+s).each do |x|
    (l-s..l+s).each do |y|
      x,y = boundary(x,y)
      @pixels[y][x][0] = r
      @pixels[y][x][1] = g
      @pixels[y][x][2] = b
    end
  end
end



# AVERAGE PIXEL COLOR OVER A SQUARE REGION
def square_pixel(c,l,s)
  c = c.to_i
  l = l.to_i
  sumblack = 0
  count = 0
  (c-s..c+s).each do |x|
    (l-s..l+s).each do |y|
      count += 1
      sumblack += black_pixel(x,y)
    end
  end
  return sumblack/count
end



# FIND POSITION OF DROP APEX (x0,y0).
def drop_top
  ydelta = 5
  x = []
  y = []
  xtmp = []
  @columns.times do |c|
    @lines.times do |l|
      if square_pixel(c,l,3) > @tolerance then x << c; y << l; break end 
    end
  end
  y0 = y.sort.first
  y.each.with_index do |v,j|
    if v - y0 < ydelta
      xtmp << x[j]
    end
  end
  x0 = (xtmp.first + xtmp.last)/2
  return x0,y0
end





# FIND VERTICAL POSITION OF LOWER BASE
def find_bottom(y0)
  margin = 0.1
  sumy = 0
  count = 0
  margin = (margin*@columns).to_i
  [*0..margin,*@columns-margin..@columns].each do |c|
    count += 1
    @lines.times do |l|
      if square_pixel(c,l,3) > @tolerance then sumy += l; break end
    end
  end
  return sumy/count
end





# FINDS DROP PROFILE SIDES (SIGNAL = -1 FOR LEFT AND +1 FOR RIGHT)
def drop_profile(x0,y0,signal)

  theta_points = 100
  
  delta_theta = Math::PI/2/theta_points
  radius = @lines
  drho = 1
    rho = []
    x = []
    y = []
    xx = 0
    yy = 0
    theta_points.times do |i|
      theta = delta_theta*i
      radius.downto(0) do |r|
        c = x0 + signal*r*Math.sin(theta)
        l = radius - r*Math.cos(theta)
        if square_pixel(c,l,3) > @tolerance 
          x << c
          y << l
          rho << r.to_f/radius
          break 
        end
      end
    end 
    (rho.length-drho).times do |i|
      drdtheta = (rho[i+drho]-rho[i-drho])/(2*drho*delta_theta)
      if drdtheta > BORDER_TOLERANCE and i > rho.length/10
        xx = x[i]
        yy = y[i]
        break
      end
    end
  return x,y,xx,yy
end





# AVERAGES PIXEL COLOR OVER A SMALL REGION IN THE SKY. THEN
# CALCULATES A TOLERANCE FACTOR FOR DROP DETECTION.
def calculate_tolerance
  margin = 0.1
  sumblack = 0
  count = 0
  margin = (margin*@lines).to_i
  (0..margin).each do |l|
    @columns.times do |c|
      count += 1
      sumblack += black_pixel(c,l) 
    end
  end
  @tolerance = FACTOR_COLOR*sumblack/count
end
