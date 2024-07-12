#!/usr/bin/ruby
require 'gnuplot'


def array_to_float(array)
  tmp = []
  array.each do |v|
    tmp << v.to_f
  end
  return tmp
end



def python_ellipse_fit(pathfile)
  pydata = `./ellipse-fit.py "#{pathfile}"`.strip
  parameters, x, y, xx, yy, fitdata = pydata.delete('[').split(']')
  ellipse_parameters = parameters.split(' ')
  a,b,c,d,e,f = array_to_float(ellipse_parameters)
  xfit = x.split
  yfit = y.split
  ximage = xx.split
  yimage = yy.split
  fit = fitdata.split
  return a,b,c,d,e,f,xfit,yfit,ximage,yimage,fit
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


def gnuplot(xdata,ydata,file,range)

Gnuplot.open do |gp|
  Gnuplot::Plot.new( gp ) do |plot|
    
    plot.terminal "pdf"
    plot.output File.expand_path("../#{file}",'__FILE__')
  
    plot.xrange "[#{range[0]}:#{range[1]}]"
    plot.yrange "[#{range[2]}:#{range[3]}]"
    #plot.title  file
    plot.ylabel "y (pixel)"
    plot.xlabel "x (pixel)"

    x0 = xdata[0]    
    x1 = xdata[1]
    y0 = ydata[0]
    y1 = ydata[1]
    x2 = xdata[2]
    y2 = ydata[2]
    x3 = xdata[3]
    y3 = ydata[3]
    x4 = xdata[4]
    y4 = ydata[4]

    plot.data = [
      Gnuplot::DataSet.new( [x0,y0] ) { |ds|
        ds.with = "lines"
        ds.title = "left tangent"
      },
    
      Gnuplot::DataSet.new( [x1, y1] ) { |ds|
        ds.with = "lines"
        ds.title = "right tangent"
      },
      
      Gnuplot::DataSet.new( [x2, y2] ) { |ds|
        ds.with = "lines"
        ds.title = "fitted ellipse"
      },
      
      Gnuplot::DataSet.new( [x3, y3] ) { |ds|
        ds.with = "points pointtype 2 pointsize 0.5"
        ds.title = "image data"
      },
      
      Gnuplot::DataSet.new( [x4, y4] ) { |ds|
        ds.with = "points pointtype 5 pointsize 0.5 lc rgb 'black'"
        ds.title = "drop limits"
      }


    ]

  end
end
end

#===========================

#pathfile = ARGV[0]
puts "FILE;LEFT ANGLE; RIGHT ANGLE;AVERAGE ANGLE"
 dir = ARGV[0]
 list = Dir[dir+'xy-*.dat']
 
 list.each do |pathfile|
   xdata = []
   ydata = []

   file = pathfile.split('/').last
   @workdir = pathfile.sub(file,'')
   

   a,b,c,d,e,f,xfit,yfit,ximage,yimage,fitdata = python_ellipse_fit(pathfile)
   write_data('ellipse_'+file,xfit,yfit)
   xdata[2] = xfit
   ydata[2] = yfit


   xtmp = []
   ytmp = []
   ximage.each.with_index do |x,j|
      if j%5 == 0
        xtmp << x
        ytmp << yimage[j]
      end
   end
   xdata[3] = xtmp
   ydata[3] = ytmp



   border_file = pathfile.sub('xy-','borders-')
   x0,x1,x2,y0,y1,y2 = border_array(border_file)
   xdata[4] = [x1,x2]
   ydata[4] = [y1,y2]
  


   x1,dump = ellipse_fit_intercept(a,b,c,d,e,f,y1)
   dump,x2 = ellipse_fit_intercept(a,b,c,d,e,f,y2)
  


   range = (x2 - x1).to_i
   xx,yy,ang1 = tangent(x1,y1,range,a,b,c,d,e,f)
   write_data('tangent_left_'+file,xx,yy)
   xdata[0] = xx
   ydata[0] = yy



   xx,yy,ang2 = tangent(x2,y2,range,a,b,c,d,e,f)
   write_data('tangent_right_'+file,xx,yy)
   xdata[1] = xx
   ydata[1] = yy


   gnurange = []
   fitdata = array_to_float(fitdata)
   file = file.sub('xy-','').sub('.dat','')
   plotfile = @workdir+'fit-'+file+'.pdf'
   gnurange << xmin = fitdata[2] - fitdata[0] - 200
   gnurange << xmax = fitdata[2] + fitdata[0] + 200
   gnurange << ymin = fitdata[3] - fitdata[1] - 100
   gnurange << ymax = fitdata[3] + fitdata[1] + 300
   gnuplot(xdata,ydata,plotfile,gnurange)



   ang1 = ang1.abs.round(2)
   ang2 = ang2.abs.round(2)
   ang = ((ang1+ang2)/2).round(2)
   puts "#{file};#{ang1};#{ang2};#{ang}"
end
