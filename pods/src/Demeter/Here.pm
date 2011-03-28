package Demeter::Here;
sub here {return substr($INC{'Demeter/Here.pm'}, 0, -7)};
1;
