set term wxt enhanced
set encoding iso_8859_15

ss=0.00619
f(x) = (1/sqrt(2*ss*3.14159)) * exp(-1*(x-2.85)**2/(2*ss))

set xrange [2.5:3.1]

n=20
plot 'RDFDAT20K' u 1:($2/n) title '20K distribution' w impulses,\
     f(x) title '{Gaussian with fitted {/Symbol s}^2}'