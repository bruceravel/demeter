

d(x,y,z)=sqrt((x*sin(acos(z)))**2 + (y-x*z)**2)
n=0.3
m=200

unset key
set title  "{/*1.3 Distribution of nearly collinear double scattering paths}"
set xlabel "{/*1.2 Half path length &{aa}({\305})}"
set ylabel "{/*1.2 angle (degrees)}"

plot 'twod' using 1:4 with points ps 0.1 pt 7 lc rgbcolor 'magenta',\
     'bin2d' using 1:2:(($3/m)<n?n:($3/m)) with points ps variable pt 7 lc rgbcolor "cyan",\
     'bin2d' using 1:($2+0.0):3 with labels font "Drois sans,6" tc rgbcolor "black"
     

#plot 'twod' using (($1+$2+d($2,$3,$4))/2):(180*acos($4)/3.14159) with points ps 0.1 pt 7
