* #variable= 4 #constraint= 2
* We're calculating the probability of Tired=low in the paper by Sang et al.
* Note that this is not the most straightforward encoding because it's meant to
* demonstrate the syntax and the capabilities of the format.
w 1 0.5 0.5
w 2 1 0.2 1
w 2 -1 0.6 1
w 3 1 0.4 1
w 3 -1 0.3 1
w 4 1 0.4 1
w 4 -1 0.1 1
1 x2 +1 x3 +1 x4 = 1;
2 x2 >= 1;
