### New Features
- Added a **Power Calibration** slider (`-10%` to `+10%`, defaulting to `0%`) under **Settings → Gameplay** so players can fine-tune launch monitor ball speed if their monitor reads consistently high or low.
- Added selectable **Golf Ball Type** options (`Standard Ball`, `Soft Ball`, and `Distance Ball`) in player profiles (Create Profile, Edit Profile, and Profile Details) so your chosen ball carries across courses, the driving range, minigames, and launch monitor play.
- `Standard Ball` remains the default and preserves existing ball physics unchanged; `Soft Ball` adds a touch more spin and spinback response with slightly higher launch drag and reduced rollout for extra stopping power; `Distance Ball` delivers slightly faster ball speed, lower spin, and increased rollout for maximum yardage.
- Expanded the **Online Player Profile Improvement Analytics** tab with deeper telemetry details (launch angle, total spin rate, ball/club head speeds, total distance and rollout, and toe/heel/high/low face strike bias) plus an interactive **"Drills to Work On"** option that surfaces targeted practice drills for the issues detected in your shot data.
- Made **Swing Analysis & Recommendations** issues on the Online Player Profile interactive: you can now select any issue from Current Month, All-Time, Prior Months history, or the issue dropdown to view what is happening, how it affects ball flight, step-by-step fix instructions, recommended practice drills, and video tutorials.

### Improvements
- Upgraded the **Closest to Pin** minigame to match the **Driving Range** on High graphics: added dynamic **Sky3D** sky, sun lighting, and atmospheric haze; replaced the legacy tee box with the natural outdoor **driving range hitting bays**; and enabled the High-fidelity realistic turf shader, swaying 3D trees, and desktop lighting/shadows.
- Upgraded the **Putting Practice** minigame to use High-fidelity graphics: dynamic **Sky3D** sky and lighting, realistic volumetric **3D trees**, championship bentgrass green mowing stripes with full PBR textures, lush rough grass shading, and a 360° distant mountain backdrop with extended surrounding terrain.
- Updated **Putting Practice** hole markers so flags appear in all non-target holes while the active hole you are putting toward has its flag removed and is highlighted by the glowing target ring.
- Refreshed the **Chipping Practice** minigame with a distant-horizon 360° lakeside golf course panorama backdrop, dynamic **Sky3D** sky and clouds, animated reflective lake water, an organic grassy teeing peninsula with high-resolution PBR grass textures, rock shoreline, and tee markers, and cleaner island greens with better-proportioned trees, flowering shrubs, and a sleek target ring so flags and greens stay clearly visible.
- Overhauled the **Fade / Draw (Shape Practice)** minigame visuals: replaced the flat barrier walls with realistic weathered concrete paneled walls featuring world-space concrete grain, recessed slab joints, base plinths, two-tier coping cornices, vertical pilasters, gate pillars with pennant flags, and clearly positioned `WALL XXX YD` signs; upgraded the ground and tee box to high-resolution PBR turf textures with triplanar world-space tiling, mowing stripes, and a flush mowed rough collar; and added a distant horizon tree line and mountain backdrop with atmospheric haze.
- Upgraded the **Loft Control / Tic-Tac-Toe** minigame visuals so you no longer hit into an empty void: added sculpted rolling green hills with the High-quality realistic striped fairway/rough turf shader, 3D grass blades around the tee box, high-fidelity volumetric 3D range trees, a distant mountain horizon, crisp yardage lines, a framed hitting mat with tee markers, and a sleek dark-steel 3x3 target frame with base anchor feet, rear support struts, and glossy sky-reflective glass panes.

### Bug Fixes
- Fixed fairway and rough rollout friction so default fairway roll distances are no longer slowed down by the green speed recalibration multiplier (keeping fairway roll faster than rough and aligned with standard club rollout).
- Fixed an issue on Low graphics quality ("minimum trees") where hidden higher-tier trees and canopies could still collide with the golf ball after switching quality in-game or loading converted courses.
- Fixed an issue on large downloaded courses where tee shots starting far from the course origin could falsely trigger out-of-bounds immediately on the tee, leaving the ball on the tee.

### Shot Data Analysis & Tee-Shot View
- Open a movable Shot Data Analysis window from beside the Stats button. Review launch monitor readings in editable player-and-club groups, rename or create groups, move shots between groups, and exclude individual shots from group averages.
- Compare best-shot or group-average flight paths and view color-matched landing dispersion, with excluded shots still visible in a dimmed style.
- Keep using the range controls while Shot Data Analysis is open; its window no longer blocks interaction with the main screen.
- Open Shot Data Analysis as a regular desktop window instead of a popup, and place it on a second monitor when one is available.
- Fixed startup script errors that could prevent the range and minigames from loading.
- Keep player selection, settings, and range buttons usable while the non-modal analysis window is open.
- Fixed a crash when the shot list refreshes after changing clubs or recording another shot.
- Use a newly created custom group for the next shot, including when the player or club changed before the shot.
- Prevent creating another custom group until the pending group has received a shot.
- Show landing dispersion left-to-right from tee to landing, aligned to the flight chart with one shared 50-yard distance ruler.
- Organize shot spreadsheet stats under clear categories and hide player metadata and internal fields that are not useful for shot analysis.
- Delete a shot group and its shots from the analysis window without affecting shots stored on the range.
- Upload shot-analysis sessions to Firebase and review, visualize, download as CSV, or delete them from the signed-in Player Portal.
- Keep the Shot Data Analysis window’s standard minimize and maximize controls visible.
- Display apex height in feet and scale the yardage range to keep dispersion circles within the chart while showing the full distance range.
- Remove duplicate Ball Speed and aim/target-only columns while retaining all other launch-monitor fields in shot analysis.
- Add Descent Angle as the first stat in the Ball Flight category.
- Match shot-analysis table values and chart distance labels to the range's selected imperial or metric units.
- View tee shots from a fixed, raised position behind the tee, clear of HUD controls, with the inset hiding on landing.
- Fixed an error at the end of a hole that could interrupt tournament score handling.
- Make the tee-shot flight window portrait-oriented and one-third larger for a clearer view.
- Overlay the tee-shot view over the minimap at one-third larger, with a solid, cleanly rendered flight tracer.
- Keep the tee-shot camera fixed in a slightly higher, farther-back position throughout the flight.
- Fixed a loading error that could prevent the course from opening after selecting Play.
- Raise the tee-shot camera and aim it downrange above the canopy to keep the view clear of trees.
- Animate the tee-shot window as it grows from minimap size and shrinks back when the shot ends.
- Keep the tee-shot ball marker and solid tracer confined to the inset so they do not alter the main game view.
- Pull the tee-shot camera back to keep the tee box in frame, and clip the tracer to the inset window.
- Let the tee-shot sound play before the inset opens, then reveal the flight view after its longer resize transition; use the same duration when it closes.
- Keep the ball still until the tee-shot inset finishes opening, and preserve the course picture's portrait shape throughout the resize.
- Expand the tee-shot window before playing the hit sound and launching the ball, and clear the previous flight tracer before the next expansion.
- Keep the tee-shot window visible through its full closing animation when the ball comes to rest, including multiplayer turn changes.
- Allow the tee-shot inset content to shrink with the window instead of forcing an immediate return to minimap size.
- Show the behind-the-tee view full-screen during tee shots, then return to the course view and restore the HUD after the shot.
- Reduce tee-shot flight stuttering by skipping the hidden main view's duplicate course rendering.
- Improve tee-shot flight smoothness by reducing extra rendering and updating only the moving end of the tracer.
- Further reduce tee-shot flight rendering load while preserving the flight view's on-screen size.
- Update the tee-shot tracer less often while keeping the ball marker moving smoothly during flight.
- Turn the tee-shot overhead view on or off from Course Play’s Immersion Menu.
- Show the course on the left and the overhead tee-shot flight view on the right during tee shots.
- Fixed a script parsing issue when reading the overhead tee-shot setting.
