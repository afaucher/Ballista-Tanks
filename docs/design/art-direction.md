# Ballista Tanks: art direction

## Anchor
The style contract is the first Gemini "player's view" shot (2026-10-26), saved as
`art/anchors/cockpit.jpg`. Every later concept is prompted against it ("same art style as this
image"). Like Bridge to Friendship's anchors, it cannot be regenerated identically, so keep a copy.

`art/anchors/arena_style_only.webp` is the same style zoomed out, and **only** a style reference:
its layout is wrong (a flat, real-castle ring with a sky, hills and trees outside). Never use it
for layout.

## What the anchor sets
- **Look:** stylised, hand-painted 3D in the Supercell / Clash Royale family. Chunky shapes,
  soft bevels, slightly toy-like but not plastic.
- **Stone:** big grey blocks with rounded, chipped edges and visible mortar lines; cobbled road
  surfaces; crenellations as fat square merlons.
- **Wood:** warm orange-brown planks and beams with painted grain; iron straps and rivets.
- **Team colour:** saturated blue and red, used on tank hulls, banners and roof tiles. Gold trim
  and a gold crown emblem on banners.
- **Light:** bright midday sun, soft shadows, light blue sky with soft clouds, a little dust kicked
  up by treads.
- **Tank:** short tracked hull in team colour; the driver sits exposed in a bucket helmet directly
  behind the ballista; a small team pennant on a pole at the back.
- **Ballista:** curved laminated wooden bow, thick twisted rope string tied off with knots, iron
  limb caps, a big steel broadhead bolt down the centre line.

## Camera and HUD (from the anchor)
- Third person, low, right behind the driver's helmet. The ballista bow spans most of the screen
  width and the bolt points at the reticle.
- Ring reticle at screen centre; a dotted arc shows a bolt's flight.
- Top centre: two team score bars, each capped with a team shield.
- Top left: minimap in an ornate stone-and-gold frame.
- Bottom right: round "Bolt Ready" badge with the bolt icon, plus a small shield ability icon.

## Interior, not exterior (2026-10-26)
The cube arena is a castle **interior**: stone halls rather than a castle on a landscape. A later
Gemini cutaway (a cube of stone halls) got the architecture close. An interior fits the cube
because it is indoors anyway:
- **Barrel vaults and rounded wall bases are the quarter-pipes.** Vaulted architecture is made of
  curves already.
- **Arches are overpasses,** galleries and balconies are elevated roads with balustrades,
  stairwells become ramps and spiral ramps (no steps), corridors and doorways are tunnels and
  chokepoints, and columns are pillars.
- The light at the core reads as a **giant hanging chandelier or brazier**: warm and gold.
- Red and blue banners, wooden beams, iron fittings. No trees, sky or water features.
- Stay cheerful and toy-like, like the anchors. Not a dark dungeon.
- A second interior cutaway (still mostly single-gravity) fixed the palette: **cool grey stone**
  in big chunky blocks, not warm sandstone. Its other ideas: arches carrying roads over other
  roads, a tank driving the underside of an arch, wooden scaffolds, team-coloured gatehouses.
- In the gray-box (`scripts/world/look.gd`): triplanar masonry on every face, a near-white warm
  brazier light, and a cool ambient. The brazier's chains run to the eight corners, out of the
  sightlines down the middle of each face.

## Still open
- The anchor's arena is a flat castle. The cube arena (game-concept.md) has to be drawn in this
  style: curved quarter-pipe edges in the same stone, castles on every face.
- Inside a closed cube there is no sky, horizon or landscape: looking "up" you see the opposite
  face. The light needs a source inside the cube. A candidate is a small sun or giant lantern
  floating at the cube's centre, which lights every face the same way.
