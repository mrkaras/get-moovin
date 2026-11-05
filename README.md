# Get Moovin'

An endless stockyard runner starring the Get Moovin' bull. Built for Godot 4.7 (GL Compatibility renderer).

Open the folder in Godot (Import → select `project.godot`) and press **F5**.

## Controls

| Key | Action |
| --- | --- |
| Arrows / A D | Move left / right |
| Space / W / Up | Jump (press again mid-air to double jump) |
| Shift / J / X | Charge, horns first (uses the charge meter) |
| S / Down | Slam down when airborne |
| Esc / P | Pause |

Gamepad: left stick to move, A to jump, X to charge, Back to pause.

## Rules

- **Steel fences**: jump them, or charge through them.
- **Drafting gates**: too tall to clear easily, so charge through them for bonus points.
- **Chickens**: charge into them or stomp on them. Walking into one costs a life.
- **Hay bales**: +25 points, refill some charge, and add 5 kg to the bull's live weight.
- **Lightning**: a glowing target marks where it will strike. Move out of the way.

You have 3 lives. The run gets faster the longer you last. Your high score is saved.

## Layout

- `scenes/main.tscn`: the main scene
- `scripts/main.gd`: game states, spawning, collisions, scoring
- `scripts/bull.gd`: player movement and animation
- `scripts/obstacle.gd`: fences, gates, chickens, hay and lightning (drawn in code)
- `scripts/background.gd`: parallax stormy stockyard
- `scripts/hud.gd`: HUD, title, pause and game-over screens
- `scripts/fx.gd`: particles and score popups
- `scripts/sfx.gd`: sound effects generated in code (no audio files)
- `assets/bull.png`: the bull, cut out of `assets/source/bull_watch.jpg` by `tools/make_sprite.gd`
- `tools/playtest.gd`: automated smoke test that saves screenshots

## Promo trailer

`promo/get_moovin_trailer.mp4` is a 32-second 1280×720 trailer rendered from the real game.
`trailer/trailer.tscn` plays the game on autopilot with scripted obstacles, captions and title cards,
and `trailer/music.gd` synthesises the soundtrack. To re-render it with Godot's Movie Maker:

```
godot --path . --resolution 1280x720 --fixed-fps 30 --write-movie promo/trailer_raw.avi res://trailer/trailer.tscn
```

Movie Maker writes an MJPEG AVI. Convert it with ffmpeg if you want a smaller MP4:

```
ffmpeg -i promo/trailer_raw.avi -c:v libx264 -crf 18 -pix_fmt yuv420p -c:a aac -b:a 192k promo/get_moovin_trailer.mp4
```
