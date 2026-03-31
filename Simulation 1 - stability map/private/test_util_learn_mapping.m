P1 = [  1  -1;
       1   1];
% Frame 2
P2 = [  -1   -1;
       -1  1];
% Frame 3
P3 = [ 1   1;
        -1  -1];

patterns = cat(3, P1, P2, P3);

lf1 = [30 -10 3 -7; 4 -3 10 -20; 5 7 -1 -4; 10 -3 5 13];
% Frame 2
lf2 = [-5 -20 2 -1;18 2 -3 -3; 8 -10 5 -4; 2 -4 -11 8];
% Frame 3
lf3 = [ 10 15 -3 9; -1 -7 5 -4; 3 -10 -1 2;-4 6 10 -9];

lf = cat(3, lf1, lf2, lf3);

map_idx = util_learn_mapping(lf,patterns,false);
disp(map_idx)