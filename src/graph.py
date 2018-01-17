#!/usr/bin/env python3
# Made by kk

import os, sys

import matplotlib.pyplot as p

points = []
for line in sys.stdin:
    points.append(line.split()), print(*points[-1])

if 0 == os.fork():
    p.legend(handles=[p.plot(*zip(*points), label='l = f(λ)')[0]]), p.show()
