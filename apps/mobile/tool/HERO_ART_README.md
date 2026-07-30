# Hero AI art (free-tier highlights)

High-visibility free-tier illustrations upgraded with AI flat preschool art (512×512 PNG, no text).

## Paths (under `assets/images/`)

**Stage 1**
- `img/s01/puppy.png`, `baby_face.png`, `ball.png`, `ball_bell.png`, `bath_splash.png`
- `img/s01/bear_wave.png`, `bell.png`, `big_drum.png`, `bird_leaf.png`, `bird_peek.png`
- `img/s01/bubbles.png`, `bunny_clap.png`, `clouds.png`, `color_glow.png`, `cup.png`
- `img/s01/elephant_stomp.png`

**Stage 2**
- `img/s02/cat.png`, `drum.png`, `duck.png`, `elephant.png`, `face.png`, `red_apple.png`

**Stage 3**
- `img/s03/apple.png`, `banana.png`, `bus.png`, `carrot.png`, `bear_eat.png`
- `img/s03/cat_up.png`, `duck_pond.png`, `frog_jump.png`, `foods.png`

**Stage 4**
- `img/s04/rainbow.png`, `family.png`, `weather.png`
- `img/s04/balloons10.png`, `four_shapes.png`

**Stage 5**
- `img/s05/seed_sprout.png`, `robot_start.png`, `cat.png`, `number_bonds.png`
- `img/s05/twenty_stars.png`, `jobs.png`

**Stage 6**
- `img/s06/flag.png`, `robo_sorting.png`, `rain_down.png`, `place_value.png`
- `img/s06/plant_flower.png`, `room_map.png`

**Stage 7**
- `img/s07/globe.png`, `coins.png`, `puppy_home.png`, `butterfly_cycle.png`
- `img/s07/wash_hands.png`, `clock_hour.png`

**Stage 8**
- `img/s08/array.png`, `array_grid.png`, `magnets.png`, `habitats.png`, `water_cycle.png`
- `img/s08/pond_life.png`, `scratch_blocks.png`

**Stage 9**
- `img/s09/chameleon_color.png`, `solar_system.png`, `bar_graph.png`
- `img/s09/pizza_quarters.png`, `pizza_whole.png`
- `img/s09/lemonade_sell.png`, `fossils.png`

**Stage 10**
- `img/s10/fraction_bars.png`, `robot_success.png`, `moon_journal.png`, `world_map.png`
- `img/s10/ballot_box.png`, `circuit.png`
- `img/s10/online_safety.png`, `bake_sale.png`, `solar_system.png`, `long_division.png`
- `img/s10/night_sky.png`, `scientific_method.png`

Remaining library art stays procedural (`tool/generate_art_batch.py`). Re-run AI only for new hero slots; keep the same path names so content JSON needs no remapping.

Style target: flat preschool, soft pastels, rounded shapes, no letters/text, square crop.

Install flow: generate JPG via Imagine → `PIL` resize to 512×512 RGB PNG into the matching `img/sNN/` path.

Coverage: hero AI highlights span **stages 1–10** (high-visibility slots).
