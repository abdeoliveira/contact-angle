#!/usr/bin/ruby


def array_to_float(array)
  tmp = []
  array.each do |v|
    tmp << v.to_f
  end
  return tmp
end



def python_ellipse_fit(pathfile)
  pydata = `./ellipse-fit.py "#{pathfile}"`.strip
  parameters, x, y = pydata.delete('[').split(']')
  ellipse_parameters = parameters.split(' ')
  a,b,c,d,e,f = array_to_float(ellipse_parameters)
  xplot = x.split(' ')
  yplot = y.split(' ')
  return a,b,c,d,e,f,xplot,yplot
end




def write_data(file,x,y)
  xyfile = @workdir + file 
  File.write(xyfile,'',mode:'w')
  x.each.with_index do |c,i|
    l = y[i]
    File.write(xyfile,"#{c} #{l}\n",mode:'a')
  end
end



def border_array(file)
  array = File.readlines(file)
  x0,y0 = array[0].split
  x1,y1 = array[1].split
  x2,y2 = array[2].split
  x0,x1,x2,y0,y1,y2 = array_to_float([x0,x1,x2,y0,y1,y2])
  return x0,x1,x2,y0,y1,y2
end



def tangent(xp,yp,range,a,b,c,d,e,f)
  yy = []
  xx = [*xp.to_i-range..xp.to_i+range]
  dydx = -(2*a*xp+b*yp+d)/(e+b*xp+2*c*yp)
  ang = Math.atan(dydx)*180/Math::PI
  beta = yp - dydx * xp
  xx.each do |x|
    yy << dydx * x + beta
  end
  return xx,yy,ang
end



def ellipse_fit_intercept(a,b,c,d,e,f,y)
  beta = (b*y+d)/a
  gamma = (c*y**2+e*y+f)/a
  x1 = (-beta - Math.sqrt(beta**2-4*gamma))/2
  x2 = (-beta + Math.sqrt(beta**2-4*gamma))/2
  return x1,x2
end 


#===========================

#pathfile = ARGV[0]

 dir = ARGV[0]
 list = Dir[dir+'xy-*.dat']
 
 list.each do |pathfile|
   file = pathfile.split('/').last
   @workdir = pathfile.sub(file,'')
   
   a,b,c,d,e,f,xplot,yplot = python_ellipse_fit(pathfile)

   write_data('ellipse_'+file,xplot,yplot)
   
   border_file = pathfile.sub('xy-','borders-')
   
   x0,x1,x2,y0,y1,y2 = border_array(border_file)
   
   x1,dump = ellipse_fit_intercept(a,b,c,d,e,f,y1)
   
   dump,x2 = ellipse_fit_intercept(a,b,c,d,e,f,y2)
   
   range = (x2 - x1).to_i
   
   xx,yy,ang1 = tangent(x1,y1,range,a,b,c,d,e,f)
   write_data('tangent_left_'+file,xx,yy)
   xx,yy,ang2 = tangent(x2,y2,range,a,b,c,d,e,f)
   write_data('tangent_right_'+file,xx,yy)
   
   ang1 = ang1.abs.round(2)
   ang2 = ang2.abs.round(2)
   ang = ((ang1+ang2)/2).round(2)
   file = file.sub('xy-','').sub('.dat','')
   puts "#{file};#{ang1};#{ang2};#{ang}"
end
