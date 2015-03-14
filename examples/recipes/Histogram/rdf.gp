set term wxt enhanced
set encoding iso_8859_15

set style line 1  lt 1 linecolor rgb 'blue'         lw 1
set style line 2  lt 1 linecolor rgb 'red'          lw 2

#aa              = 13.6825          +/- 0.7044       (5.148%)
#ss              = 0.000982534      +/- 0.0001169    (11.9%)
ss=0.000982534
aa=13.6825
f(x) = (aa/sqrt(2*ss*3.14159)) * exp(-1*(x-2.85)**2/(2*ss))
#fit f(x) 'firstshell' u 1:2 via aa,ss

scale=12/2428.11196871
set multiplot 
set key top left vertical samplen 4 spacing 1.5 width 0 height 1 box

unset obj 20
set size 1,0.99
set origin 0,0.01

set xlabel '{/=16 Radial distance (Å)}' offset 0,0
set ylabel '{/=16 Bin population}' offset 0,0
set xrange [0:4.5]
plot 'RDFDAT20K' u 1:($2*scale) title '20K distribution' w impulses ls 1

unset key
unset xlabel
unset ylabel
set size 0.48,0.43
set origin 0.14,0.3
set xrange [2.65:3.0]
set obj 20 rect from graph -0.20, graph -0.23 to graph 1.09, graph 1.05 fs solid 0.15 fc rgb "#FFFFFF" behind
plot 'firstshell' u 1:($2*scale) title '' w impulses ls 1,\
     f(x)*scale title '' w lines ls 2

unset multiplot