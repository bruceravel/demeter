set term wx font 'Droid Sans,12' enhanced
set encoding iso_8859_15
set style data points

unset key

set style line 1  lt 1 linecolor rgb 'blue'
set pointsize 1

kk=3
kr=1

set xrange [0:100]
set yrange [0:100]
#set xlabel 'area under {/Symbol c}(R), kw=2,'
set xlabel '{{/Symbol S}|{/Symbol c}(k)*k^2|'
#set ylabel '{{/Symbol S}|{/Symbol c}(k)*k^2|'
set ylabel "{Feff's C.W.I.F.}"

set arrow 1 from 0, 0  to 100,100 nohead
set arrow 2 from 0, 10 to 100,10  nohead
set arrow 3 from 10,0  to 10, 100 nohead

#5 9 13
plot 'rank.dat' u 4:5 with points pt 7
