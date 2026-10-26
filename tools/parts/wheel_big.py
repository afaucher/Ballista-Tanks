"""Big wheel: the front and rear wheels each track runs round."""

import dims
import wheels


def build():
    return wheels.wheel("wheel_big", dims.WHEEL_BIG_R, 0.09)
