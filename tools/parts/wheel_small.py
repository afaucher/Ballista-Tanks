"""Small road wheel: the two in the middle of each track."""

import dims
import wheels


def build():
    return wheels.wheel("wheel_small", dims.WHEEL_SMALL_R, 0.07)
