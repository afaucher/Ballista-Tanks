"""One track link, at the origin: length along z, outer face toward +y, symmetric in x.
TankModel lays dims.json's "belt" count of them round the belt path and moves them as it drives.

A bevelled rubber block with a raised tread bar, like the concept's chunky links.
"""

import common
import dims
import track


def build():
    _, _, _, _, _, pitch = track.belt()
    mb = common.MeshBuilder("track_link")
    mb.box((0, 0, 0), (dims.TRACK_W, dims.BELT_T, pitch * 0.86), "track")
    mb.box((0, dims.BELT_T * 0.55, 0), (dims.TRACK_W * 0.86, dims.BELT_T * 0.35, pitch * 0.32), "track")
    obj = mb.build(bevel=0.025, segments=2, angle=30)
    return common.finish([obj], "track_link", texture_size=128)
