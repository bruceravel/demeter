set term wxt font 'Droid Sans,11' enhanced
set encoding iso_8859_15

n=0.3
m=250

unset key
set title  "{/*1.3 Distribution of nearly collinear triple scattering paths}"
set xlabel "{/*1.2 Half path length &{aa}({\305})}"
set ylabel "{/*1.2 angle (degrees)}"

plot 'twod' using 1:5 with points ps 0.1 pt 7 lc rgbcolor 'brown',\
     'bin2d' using 1:2:(($5/m)<n?n:($5/m)) with points ps variable pt 7 lc rgbcolor "blue"
#     ,\
#     'bin2d' using 1:($2+0.0):3 with labels font "Drois sans,6" tc rgbcolor "black"
