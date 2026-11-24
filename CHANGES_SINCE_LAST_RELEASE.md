### New Features
- Added a **Power Calibration** slider (`-10%` to `+10%`, defaulting to `0%`) under **Settings → Gameplay** so players can fine-tune launch monitor ball speed if their monitor reads consistently high or low.
- Added selectable **Golf Ball Type** options (`Standard Ball`, `Soft Ball`, and `Distance Ball`) in player profiles (Create Profile, Edit Profile, and Profile Details) so your chosen ball carries across courses, the driving range, minigames, and launch monitor play.
- `Standard Ball` remains the default and preserves existing ball physics unchanged; `Soft Ball` adds a touch more spin and spinback response with slightly higher launch drag and reduced rollout for extra stopping power; `Distance Ball` delivers slightly faster ball speed, lower spin, and increased rollout for maximum yardage.
- Expanded the **Online Player Profile Improvement Analytics** tab with deeper telemetry details (launch angle, total spin rate, ball/club head speeds, total distance and rollout, and toe/heel/high/low face strike bias) plus an interactive **"Drills to Work On"** option that surfaces targeted practice drills for the issues detected in your shot data.
- Made **Swing Analysis & Recommendations** issues on the Online Player Profile interactive: you can now select any issue from Current Month, All-Time, Prior Months history, or the issue dropdown to view what is happening, how it affects ball flight, step-by-step fix instructions, recommended practice drills, and video tutorials.
- Restored the Main Menu to the clean 2 rows of 4 layout (Courses, Multiplayer, Practice, Range on the top row; History, Leaderboards, Players, Mini Games on the bottom row) with balanced vertical centering and seamless 4-way focus navigation.
- Maintained the core backend architecture, recommendation engine, and 3D Training Arena in the codebase for continued refinement ahead of public player release.

### Improvements
- Improved ball ground interaction and rollout physics: reduced excessive rollout on very low wormburner shots; tuned iron backspin behavior so lower-spin irons roll out more naturally (around 8–12 yards forward near 5,000 RPM, with more release as spin drops); refined the 7,500–9,000 RPM zone to bounce slightly forward and check to a stop; and tuned greens above 9,000 RPM to pull backwards progressively more as spin rate increases.
- Upgraded the **Closest to Pin** minigame to match the **Driving Range** on High graphics: added dynamic **Sky3D** sky, sun lighting, and atmospheric haze; replaced the legacy tee box with the natural outdoor **driving range hitting bays**; and enabled the High-fidelity realistic turf shader, swaying 3D trees, and desktop lighting/shadows.
- Upgraded the **Putting Practice** minigame to use High-fidelity graphics: dynamic **Sky3D** sky and lighting, realistic volumetric **3D trees**, championship bentgrass green mowing stripes with full PBR textures, lush rough grass shading, and a 360° distant mountain backdrop with extended surrounding terrain.
- Updated **Putting Practice** hole markers so flags appear in all non-target holes while the active hole you are putting toward has its flag removed and is highlighted by the glowing target ring.
- Refreshed the **Chipping Practice** minigame with a distant-horizon 360° lakeside golf course panorama backdrop, dynamic **Sky3D** sky and clouds, animated reflective lake water, an organic grassy teeing peninsula with high-resolution PBR grass textures, rock shoreline, and tee markers, and cleaner island greens with better-proportioned trees, flowering shrubs, and a sleek target ring so flags and greens stay clearly visible.
- Overhauled the **Fade / Draw (Shape Practice)** minigame visuals: replaced the flat barrier walls with realistic weathered concrete paneled walls featuring world-space concrete grain, recessed slab joints, base plinths, two-tier coping cornices, vertical pilasters, gate pillars with pennant flags, and clearly positioned `WALL XXX YD` signs; upgraded the ground and tee box to high-resolution PBR turf textures with triplanar world-space tiling, mowing stripes, and a flush mowed rough collar; and added a distant horizon tree line and mountain backdrop with atmospheric haze.
- Upgraded the **Loft Control / Tic-Tac-Toe** minigame visuals so you no longer hit into an empty void: added sculpted rolling green hills with Course Play's High-quality 2048px fairway and rough textures and realistic striped turf shader, Course Play's high-quality volumetric 3D range trees, a distant mountain horizon, crisp yardage lines, a framed hitting mat with tee markers, and a sleek dark-steel 3x3 target frame with base anchor feet, rear support struts, and glossy sky-reflective glass panes.
- Added detailed Bluetooth diagnostic logging when connecting to a **Blue Tees Rainmaker** launch monitor so debug logs capture discovered device services, characteristics, and incoming data packets for troubleshooting.
- Added an in-game screenshot capture hotkey (press **F12** anytime to instantly save a clean high-resolution screenshot to the captures folder), built an automated visual preview capture system for testing and UI reviews with automatic runaway process watchdogs, and added an automated pre-commit cleanup hook.

### Bug Fixes
- Fixed fairway and rough rollout friction so default fairway roll distances are no longer slowed down by the green speed recalibration multiplier (keeping fairway roll faster than rough and aligned with standard club rollout).
- Fixed an issue on Low graphics quality ("minimum trees") where hidden higher-tier trees and canopies could still collide with the golf ball after switching quality in-game or loading converted courses.
- Fixed an issue on large downloaded courses where tee shots starting far from the course origin could falsely trigger out-of-bounds immediately on the tee, leaving the ball on the tee.
- Fixed cross-device cloud profile syncing so signing in with the same cloud account on a new device (such as your phone or a second computer) automatically restores your Primary Profile, mapped bag, club data, and lifetime round stats.
- Fixed the **Sync Now** button in the Players menu so manual cloud syncs complete properly instead of being skipped as already in progress.
- Fixed online multiplayer match win/loss tracking so round winners are accurately recorded when a match finishes.
- Fixed an issue where bundled offline cached golf courses were missing from Windows, macOS, and Android release builds, so all platforms now include the full pre-cached course library out of the box.
- Fixed random silent crashes and memory leaks that could occur when switching between menus (such as the Players, Settings, Online Multiplayer, Course Setup, and Main Menu screens).
- Fixed an issue where surrounding roads and houses could be missing when downloading courses (such as Westridge Golf Course): improved OpenStreetMap mirror fallback and query coverage so roads, houses, and buildings around the entire course download reliably and stay cached on re-downloads.
- Fixed an issue where the golf hole cup and ball could occasionally appear floating above the turf on sloped greens, undulating tees, or downloaded/custom courses: the ball and hole now always snap directly to the rendered course ground surface, and hole cups sit flush with the slope of the green while keeping the flagstick standing straight up.

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
- Set the **Tee Shot View** toggle in Course Play’s Immersion Menu to **OFF** by default; once you enable or change it, your preference is saved and remembered for future sessions.
- Added a **Pop Out / Dock** option to the **Tee Shot Flight View** so desktop players can detach the shot view camera into its own draggable, resizable window (including on a second monitor). Once popped out, it stays open between shots and remembers both its popped-out state and window position/size across holes and sessions until you dock or close it.
- Added a bright, gently bobbing overhead 3D arrow pointing down at the center of the bullseye in **Closest to Pin** so the target is easy to spot from any yardage.

### Shot Analytics & Coaching Improvements (In-Game & Online Player Portal)
- **D-Plane 9-Shot Flight & Dispersion Upgrades**: Added 9-shape ball flight breakdown cards (straight, draw, fade, push-draw, pull-fade, and misses), true angled dispersion clusters with fairway/green target corridors, and "Best Overall" view mode balancing carry distance with accuracy.
- **Smarter Swing Diagnostics**: Added clubface gear-effect detection (distinguishing toe hooks, heel slices, and low-face driver spin spikes from swing path flaws), Spin Loft compression checks, approach landing angle warnings for green-holding trajectory, left-handed swing analysis accuracy, 9-iron mid-iron classification, camera-angle-aware tempo and head-stability checks, and protection against flagging intentional stock draws or fades that finish near your target.
- **Missing Yards & Bag Gapping Visuals**: Added interactive target range gauges, Launch Optimizer trajectory-vs-spin windows, Carry & Rollout bag gapping ladders that flag club overlaps or distance gaps, and Missing Yards breakdowns showing how much distance can be recovered from cleaner contact, spin, or curve.
- **Active "One-Thing Focus" Coaching & 10-Ball Range Drills**: Pick a prioritized focus plan with a 3-step milestone ladder synced across the simulator and Web Player Portal, track your flaw rate per shot and month-over-month progress, and open the new **Practice Drills** tracker in the Driving Range to score 10-ball rep blocks with instant pass/fail feedback and milestone advancement.

### Course Visuals & Performance Fixes
- **Smooth Ground-Conforming Cart Paths**: Rebuilt cart paths with a 5-column terrain-conforming profile matched to exact course ground triangles so paths drape smoothly over hills and ridges without floating edges or terrain clipping through the middle.
- **Clean Sand Bunkers Without Protruding Edges**: Smoothed and constrained 3D bunker lips to follow the exact terrain slope and stay cleanly along the bunker perimeter, preventing inverted lips or stray edges from poking out through the middle of the sand.
- **Deeper Sculpted Concave Sand Bunkers & Grass Lips**: Reshaped sand traps into deep concave bowls with lush raised overhanging grassy rims, crisp turf-to-sand borders, and finer, natural curved sand raking (automatically upgraded once for previously downloaded courses).
- **Crisper Bunker Borders Without Sand Halos or Dark Curbs**: Aligned bunker lip edges directly to each trap's true sand rim with smooth anti-aliased grass-to-sand borders, cleared legacy sand bleed around bunker edges on upgraded courses, and blended the raised turf bank naturally with surrounding fairways and rough.
- **Gap-Free Cart Paths & Seamless Bridge Connections**: Prevented steep hillcrests and sharp bends from cutting slits across cart paths, closed small path breaks and T-junctions, and stitched cart paths cleanly onto both ends of wooden pond bridges on both newly downloaded and upgraded courses.
- **Faster Course Loading & No Gameplay Re-Sampling**: Course bunker lips, cart paths, and detail geometry are now finalized once during course download (and upgraded once automatically for older saved courses), eliminating redundant terrain re-sampling during course load and gameplay.
- **Crisper Long-Distance Visibility & Deeper Horizon Fog**: Switched High graphics atmospheric fog to true depth-based fog starting well past typical playable hole distances (~415 yards) and removed subtle full-screen bloom softness across courses, the driving range, and minigames, eliminating near- and mid-range haze while keeping a gentle, natural aerial fade on the far horizon.
- **Accurate Sand Trap, Fringe, and Rough Lie Boundaries**: Fixed zone detection and terrain graphics so lies match what you see on the ground—balls inside sand traps (including near the rim and inside deep sculpted bunkers) now reliably register as **Sand** instead of Rough or Fringe, and the green collar/fringe visual border, 3D rough grass blades, and putting/fringe detection now all line up cleanly at the same boundary.
