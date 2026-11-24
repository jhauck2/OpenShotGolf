// Heckle Golf Simulator - Swing Issue Fixes & Practice Drills Knowledge Base
// Maps recorded swing_issues (from GolfSwingAnalyzer) and telemetry analytics trends
// to actionable fixes, step-by-step practice drills, and HackMotion video tutorials.

export const HM_VIDEOS = {
  low_point: {
    id: "SprUtqdpP68",
    title: "Simple Low Point Drill You Can Do at the Range - Strike It Pure Every Time",
    url: "https://www.youtube.com/watch?v=SprUtqdpP68"
  },
  barrier_path: {
    id: "XklxkK1FsWg",
    title: "Perfect Your Swing Indoors: Golf Simulator Practice Tips",
    url: "https://www.youtube.com/watch?v=XklxkK1FsWg"
  },
  downswing_sequence: {
    id: "YQhfe1MOOKg",
    title: "2 Powerful Downswing Drills for Better Sequence and Clubface Control",
    url: "https://www.youtube.com/watch?v=YQhfe1MOOKg"
  },
  shaft_lean: {
    id: "fyi1k63ly_k",
    title: "2 Biggest Shaft Lean Mistakes (And How to Fix Them!)",
    url: "https://www.youtube.com/watch?v=fyi1k63ly_k"
  },
  one_metric_aoa: {
    id: "Gy1_w4pB5RE",
    title: "You Only Need to Fix ONE Metric | Combine TrackMan + HackMotion to Do It",
    url: "https://www.youtube.com/watch?v=Gy1_w4pB5RE"
  },
  sim_improvement: {
    id: "2bbjlF3nDYs",
    title: "Home Golf Simulator Tips for Better, Faster Improvement",
    url: "https://www.youtube.com/watch?v=2bbjlF3nDYs"
  }
};

const ISSUE_DATABASE = {
  "Low Smash Factor": {
    category: "Strike & Compression",
    cause: "Off-center contact (heel or toe) or glancing blow reducing energy transfer from clubhead to golf ball.",
    ballFlightEffect: "Significant carry distance loss, inconsistent launch, and excessive side-spin gear effect.",
    howToFix: "Focus on centered sweet-spot contact before swinging faster. Maintain steady spine posture through impact and swing at 80% tempo until strike location clusters near the center.",
    drills: [
      {
        name: "Impact Spray & Low Point Gate Drill",
        setup: "Apply dry-shampoo foot spray or impact tape to the clubface, and place a flat marker 2 inches behind the ball.",
        steps: [
          "Make 80% speed swings focusing on brushing the turf just ahead of the ball.",
          "Inspect the clubface mark after every 3 balls to identify heel or toe bias.",
          "Adjust setup distance slightly closer (for toe) or farther (for heel) until marks center."
        ],
        goal: "5 consecutive strikes within 5 mm of the sweet spot without touching the rear marker.",
        reps: "15 balls per session"
      }
    ],
    video: HM_VIDEOS.low_point
  },

  "Sub-Optimal Smash Factor": {
    category: "Strike & Compression",
    cause: "Minor off-center strike or slightly added dynamic loft at impact lowering ball-to-club speed efficiency.",
    ballFlightEffect: "Leaves 5–12 yards of potential carry distance on the table and widens front-to-back dispersion.",
    howToFix: "Slightly choke down 0.5 inches for control, keep your lead wrist flat through impact, and prioritize crisp compression over max swing speed.",
    drills: [
      {
        name: "Gate & Low Point Compression Drill",
        setup: "Place two tee or foam markers just wider than your clubhead on the mat, plus a line marker even with the ball.",
        steps: [
          "Hit half-to-three-quarter swings swinging cleanly through the gate.",
          "Ensure the divot or brush mark starts at or just in front of the ball line.",
          "Gradually build back to full speed only while keeping strikes centered."
        ],
        goal: "Raise Smash Factor by +0.03 or more over 10 consecutive shots.",
        reps: "10–15 balls"
      }
    ],
    video: HM_VIDEOS.low_point
  },

  "Slice / Open Face-to-Path": {
    category: "Face & Path",
    cause: "Clubface is significantly open relative to your swing path (often paired with an out-to-in over-the-top path).",
    ballFlightEffect: "Produces heavy left-to-right curve (for RH) that loses carry distance and misses fairways right.",
    howToFix: "Strengthen your lead-hand grip slightly (see 2–3 knuckles), flatten or bow your lead wrist in transition, and feel your trail elbow tuck toward your hip on the downswing.",
    drills: [
      {
        name: "HackMotion Barrier Path Drill",
        setup: "Place a headcover or foam block ~5 inches outside and slightly behind the golf ball.",
        steps: [
          "Make slow rehearsal swings missing the barrier by swinging from the inside.",
          "Hit 50% speed shots focusing on rolling the lead wrist toward the target through impact.",
          "Watch the launch monitor Face-to-Path number move closer to 0° (or slightly negative for a draw)."
        ],
        goal: "Reduce Face-to-Path differential below +2.0° without clipping the barrier.",
        reps: "15 balls"
      },
      {
        name: "Split-Hand Clubface Closure Drill",
        setup: "Grip the club with your trail hand 3 inches below your lead hand.",
        steps: [
          "Make waist-high to waist-high swings feeling how the trail forearm rotates to square the face.",
          "Transition back to a normal grip keeping that same release timing."
        ],
        goal: "Eliminate the hard-right curve and start shots on or left of target.",
        reps: "10 rehearsals + 10 balls"
      }
    ],
    video: HM_VIDEOS.barrier_path
  },

  "Fade / Open Face": {
    category: "Face & Path",
    cause: "Clubface is moderately open relative to the swing path at impact.",
    ballFlightEffect: "Mild-to-moderate left-to-right curve (RH); playable if controlled, but costs distance if unintentional.",
    howToFix: "Square the clubface earlier in the downswing by flexing (flattening) the lead wrist from the top and rotating your chest cleanly through impact.",
    drills: [
      {
        name: "Alignment Gate & Face Control Drill",
        setup: "Set two alignment sticks or tees 12 inches in front of the ball forming a narrow start-line gate.",
        steps: [
          "Hit 3/4 swings launching the ball cleanly through the gate.",
          "Feel the knuckles of your lead hand point slightly downward through the strike zone."
        ],
        goal: "Keep Face-to-Path within ±1.5° for a straighter flight.",
        reps: "12 balls"
      }
    ],
    video: HM_VIDEOS.downswing_sequence
  },

  "Hook / Closed Face-to-Path": {
    category: "Face & Path",
    cause: "Clubface is overly closed relative to an excessively in-to-out swing path.",
    ballFlightEffect: "Produces aggressive right-to-left curve (RH) with low spin that dives left and rolls out unpredictably.",
    howToFix: "Neutralize an overly strong grip, keep your body rotating through impact so your hands don't flip, and swing slightly more left (RH) through the finish.",
    drills: [
      {
        name: "Transition & Lead-Side Rotation Drill",
        setup: "Take your normal setup with a mid-iron; place an alignment rod along your toe line.",
        steps: [
          "Pause 1 second at the top of your backswing to quiet excessive hand flip.",
          "Initiate the downswing by turning your lead hip and chest toward the target simultaneously.",
          "Finish with the club exiting left of the target line (RH) with the toe pointing up, not rolled over."
        ],
        goal: "Bring Face-to-Path closer to 0.0° and start the ball straighter.",
        reps: "15 balls"
      }
    ],
    video: HM_VIDEOS.downswing_sequence
  },

  "Draw / Closed Face": {
    category: "Face & Path",
    cause: "Clubface is slightly closed relative to the path, creating draw curvature.",
    ballFlightEffect: "Moderate right-to-left curve (RH); can turn into an over-draw when timing is slightly quick.",
    howToFix: "Sync up hip and shoulder rotation through impact so the clubface stays square longer through the hitting zone.",
    drills: [
      {
        name: "Hold-Off Finish Drill",
        setup: "Hit 7-iron shots at 75% tempo.",
        steps: [
          "Feel the back of your lead hand stay facing the target well past impact.",
          "Abbreviate the follow-through at chest height with the clubface still square."
        ],
        goal: "Keep Face-to-Path within -1.5° to +1.0°.",
        reps: "10 balls"
      }
    ],
    video: HM_VIDEOS.downswing_sequence
  },

  "Steep Driver Attack Angle": {
    category: "Attack Angle & Low Point",
    cause: "Hitting downward on a teed driver instead of sweeping upward through the ball.",
    ballFlightEffect: "Increases backspin, lowers launch, and costs 15–30 yards of driver carry.",
    howToFix: "Tee the ball higher (half ball above crown), play it off your lead heel, and tilt your spine slightly away from the target at address.",
    drills: [
      {
        name: "Empty Ball Box Upward Sweep Drill",
        setup: "Place an empty golf ball sleeve box 10–12 inches directly in front of your teed driver ball.",
        steps: [
          "Set up with 60% weight on your trail foot and trail shoulder lower than lead shoulder.",
          "Swing upward through the ball so the clubhead passes cleanly over the box without hitting it."
        ],
        goal: "Achieve a positive (+2° to +5°) Attack Angle.",
        reps: "12 balls"
      }
    ],
    video: HM_VIDEOS.one_metric_aoa
  },

  "Steep Driver Off Turf": {
    category: "Attack Angle & Low Point",
    cause: "Descending too steeply when hitting driver off the deck.",
    ballFlightEffect: "Low, high-spin shots or thin/fat turf contact.",
    howToFix: "Widen your stance slightly and focus on a shallow, sweeping arc that clips the top of the grass.",
    drills: [
      {
        name: "Level Sweep Turf Brush Drill",
        setup: "Practice without a ball first on a clean mat or fairway lie.",
        steps: [
          "Make wide, rhythmic swings focusing on brushing the grass blades lightly at the bottom of the arc.",
          "Introduce a ball keeping the same wide, shallow radius."
        ],
        goal: "Clean turf contact with a near-level (-1° to +1°) Attack Angle.",
        reps: "10 balls"
      }
    ],
    video: HM_VIDEOS.one_metric_aoa
  },

  "Steep Wood Tee Shot": {
    category: "Attack Angle & Low Point",
    cause: "Chopping down steeply on a teed fairway wood.",
    ballFlightEffect: "High spin, ballooning trajectory, and lost distance.",
    howToFix: "Tee the ball low (just above turf height) and sweep the clubhead smoothly through the back of the ball.",
    drills: [
      {
        name: "Low Peg Sweeper Drill",
        setup: "Push a tee down until the ball sits barely 1/4 inch above the mat/turf.",
        steps: [
          "Focus on a wide takeaway and shallow transition.",
          "Sweep the ball cleanly off the low peg without digging into the mat."
        ],
        goal: "Level (-1° to -2°) Attack Angle with high smash factor.",
        reps: "12 balls"
      }
    ],
    video: HM_VIDEOS.low_point
  },

  "Scooping Wood Off Turf": {
    category: "Attack Angle & Low Point",
    cause: "Early release / hanging back trying to lift the ball into the air.",
    ballFlightEffect: "Thin tops, fat chunks behind the ball, and weak contact.",
    howToFix: "Shift weight onto your lead side early in the downswing and keep your sternum over or ahead of the ball at impact.",
    drills: [
      {
        name: "Forward Lean & Coin Sweeping Drill",
        setup: "Place a flat ball marker or coin 2 inches in front of your ball.",
        steps: [
          "Focus on brushing the turf at the coin—not behind the ball.",
          "Keep your chest moving toward the target through impact."
        ],
        goal: "Ball-first contact with a descending -1° to -3° strike.",
        reps: "12 balls"
      }
    ],
    video: HM_VIDEOS.shaft_lean
  },

  "Steep Wood Off Turf": {
    category: "Attack Angle & Low Point",
    cause: "Over-the-top or overly steep downswing plane with fairway woods.",
    ballFlightEffect: "Digging contact, high spin, and inconsistent distance.",
    howToFix: "Widen your backswing arc and feel the clubhead glide along the turf for 6 inches through the ball.",
    drills: [
      {
        name: "Low Point Turf Brush Drill",
        setup: "Place a tee flat on the mat 3 inches ahead of the ball.",
        steps: [
          "Make smooth swings sweeping the ball and clipping the forward tee on follow-through."
        ],
        goal: "Shallow divot/brush and clean center strike.",
        reps: "12 balls"
      }
    ],
    video: HM_VIDEOS.low_point
  },

  "Scooping Hybrid Off Turf": {
    category: "Attack Angle & Low Point",
    cause: "Flipping the wrists and leaning back at impact with a hybrid.",
    ballFlightEffect: "High, weak shots or topped/fat misses.",
    howToFix: "Transfer pressure to your lead foot as the backswing finishes and deliver the hands slightly ahead of the clubhead.",
    drills: [
      {
        name: "Towel Behind Ball Drill",
        setup: "Lay a folded towel flat 3–4 inches behind your golf ball.",
        steps: [
          "Hit shots without touching the towel on the downswing.",
          "Shift weight forward so your low point moves ahead of the ball."
        ],
        goal: "10 consecutive clean strikes without brushing the towel.",
        reps: "10–15 balls"
      }
    ],
    video: HM_VIDEOS.shaft_lean
  },

  "Steep Hybrid Strike": {
    category: "Attack Angle & Low Point",
    cause: "Attacking too steeply into the ball with a hybrid.",
    ballFlightEffect: "Excessive spin and loss of roll/carry.",
    howToFix: "Shallow the transition by letting your arms drop slightly as your hips turn.",
    drills: [
      {
        name: "Shallow Sweep Rhythm Drill",
        setup: "Use a 3/4 swing with smooth 3:1 tempo.",
        steps: [
          "Feel the clubhead brush the mat lightly rather than pounding into it.",
          "Hold your finish balanced on your lead leg."
        ],
        goal: "Attack angle between -2° and -4°.",
        reps: "12 balls"
      }
    ],
    video: HM_VIDEOS.low_point
  },

  "Excessive Driver Spin": {
    category: "Launch & Spin",
    cause: "High backspin (>3,000 rpm) caused by downward attack angle, high dynamic loft, or low-face strike.",
    ballFlightEffect: "Ball balloons into the air, loses rollout, and struggles in headwinds.",
    howToFix: "Hit slightly upward (+2° to +4°), tee the ball higher, and strike slightly above the center of the driver face.",
    drills: [
      {
        name: "High Tee & Upper-Center Strike Drill",
        setup: "Tee the ball 1/4 inch higher than usual and apply impact spray to the driver face.",
        steps: [
          "Set spine tilt slightly away from target.",
          "Focus on striking the ball cleanly on or slightly above the horizontal centerline."
        ],
        goal: "Bring driver spin into the 2,000–2,600 rpm optimal window.",
        reps: "12 balls"
      }
    ],
    video: HM_VIDEOS.one_metric_aoa
  },

  "Insufficient Driver Spin": {
    category: "Launch & Spin",
    cause: "Very low spin (<1,700 rpm), typically from high-toe strikes or excessively delofted impact.",
    ballFlightEffect: "Knuckleball shots that drop out of the air early and become directionally unstable.",
    howToFix: "Center your strike location and ensure enough loft/launch at impact to keep the ball airborne.",
    drills: [
      {
        name: "Centered Face Decal Drill",
        setup: "Place impact tape on the driver face and tee at standard height.",
        steps: [
          "Take 85% speed swings focusing on centered contact.",
          "Check that you are not striking high on the toe."
        ],
        goal: "Stabilize spin between 2,000–2,500 rpm.",
        reps: "10 balls"
      }
    ],
    video: HM_VIDEOS.sim_improvement
  },

  "Excessive Wood Spin": {
    category: "Launch & Spin",
    cause: "Steep strike or open face adding loft and backspin to fairway wood shots.",
    ballFlightEffect: "Ballooning shots that fall short of target distance.",
    howToFix: "Shallow your approach angle and square the face with gentle forward shaft lean.",
    drills: [
      {
        name: "Wide Arc & Shaft Lean Drill",
        setup: "Hit 3-wood or 5-wood off a low tee or clean lie.",
        steps: [
          "Keep your lead arm extended in the takeaway for a wide arc.",
          "Deliver the hands slightly ahead of the ball at impact."
        ],
        goal: "Reduce fairway wood spin into the 3,200–4,200 rpm range.",
        reps: "12 balls"
      }
    ],
    video: HM_VIDEOS.shaft_lean
  },

  "Low Wood Spin": {
    category: "Launch & Spin",
    cause: "Shut face or high-face strike producing too little spin.",
    ballFlightEffect: "Low-flying shots that struggle to hold greens.",
    howToFix: "Use a neutral grip and verify ball position isn't too far back in your stance.",
    drills: [
      {
        name: "Face Decal & Ball Position Check",
        setup: "Place ball 2 inches inside your lead heel.",
        steps: [
          "Make smooth swings checking impact marks on the face.",
          "Ensure loft is presented cleanly without shutting the face."
        ],
        goal: "Consistent mid-trajectory flight with 3,200+ rpm.",
        reps: "10 balls"
      }
    ],
    video: HM_VIDEOS.sim_improvement
  },

  "High Hybrid Spin": {
    category: "Launch & Spin",
    cause: "Steep chop or high-lofted flip increasing backspin.",
    ballFlightEffect: "Short, high-floating hybrid shots.",
    howToFix: "Sweep the hybrid cleanly with steady tempo and forward weight shift.",
    drills: [
      {
        name: "Sweeping Mat Tempo Drill",
        setup: "Hit hybrids using a 3-count backswing, 1-count downswing rhythm.",
        steps: [
          "Brush the mat smoothly through impact without digging."
        ],
        goal: "Bring hybrid spin into the 3,800–4,600 rpm range.",
        reps: "12 balls"
      }
    ],
    video: HM_VIDEOS.low_point
  },

  "Low Iron Spin": {
    category: "Launch & Spin",
    cause: "Thin/high-face strikes, closed face, or sweeping upward reducing iron compression.",
    ballFlightEffect: "Flyer-style iron shots that bounce over the back of greens.",
    howToFix: "Compress the ball with a descending blow and forward shaft lean (hands ahead of clubhead at impact).",
    drills: [
      {
        name: "Shaft Lean & Impact Bag / Towel Drill",
        setup: "Place a towel 3 inches behind the ball.",
        steps: [
          "Strike down and through the ball, taking a shallow brush *after* the ball.",
          "Feel your lead wrist flat/flexed through the strike."
        ],
        goal: "Crisp compression and predictable green-holding spin.",
        reps: "15 balls"
      }
    ],
    video: HM_VIDEOS.shaft_lean
  },

  "Low Driver Launch": {
    category: "Launch & Spin",
    cause: "Ball teed too low, ball position too far back, or downward attack angle.",
    ballFlightEffect: "Low bullets that lose carry distance.",
    howToFix: "Play the ball off your lead heel, tee it higher, and swing upward through impact.",
    drills: [
      {
        name: "High Launch Gate Drill",
        setup: "Imagine a 10-foot-tall crossbar 15 yards ahead of you.",
        steps: [
          "Tee the ball higher and tilt your shoulders slightly upward.",
          "Launch every drive cleanly over the imaginary crossbar."
        ],
        goal: "Achieve 11°–15° driver launch angle.",
        reps: "12 balls"
      }
    ],
    video: HM_VIDEOS.one_metric_aoa
  },

  "High Driver Launch / Pop-up": {
    category: "Launch & Spin",
    cause: "Steep downward chop hitting high on the face/crown, or teeing too high while flipping.",
    ballFlightEffect: "Sky-high pop-ups with massive distance loss.",
    howToFix: "Lower tee height slightly, keep your spine angle steady through impact, and avoid lunging at the ball.",
    drills: [
      {
        name: "Level Peg & Wrist Control Drill",
        setup: "Lower tee height so only 1/3 of the ball sits above the driver crown.",
        steps: [
          "Make 80% swings keeping your lead wrist flat through impact.",
          "Focus on center-face strikes."
        ],
        goal: "Keep driver launch under 16° with solid smash factor.",
        reps: "10 balls"
      }
    ],
    video: HM_VIDEOS.shaft_lean
  },

  "Low Wood Launch": {
    category: "Launch & Spin",
    cause: "Ball too far back in stance or steep downward angle delofting the fairway wood.",
    ballFlightEffect: "Low line drives that struggle to carry hazards.",
    howToFix: "Move ball position slightly forward (1–2 balls inside lead heel) and sweep through impact.",
    drills: [
      {
        name: "Forward Ball Position Sweep Drill",
        setup: "Use an alignment stick perpendicular to your stance to verify ball is 1–2 balls inside lead heel.",
        steps: [
          "Sweep the clubhead cleanly through the ball with a wide finish."
        ],
        goal: "Raise wood launch into the 11°–15° window.",
        reps: "12 balls"
      }
    ],
    video: HM_VIDEOS.low_point
  },

  "High Wood Launch / Scoop": {
    category: "Launch & Spin",
    cause: "Scooping/flipping the wrists through impact, adding excessive loft.",
    ballFlightEffect: "High, weak shots that lose distance into wind.",
    howToFix: "Keep hands slightly ahead of the ball at impact with a flat lead wrist.",
    drills: [
      {
        name: "Flat Wrist Punch Drill",
        setup: "Hit 3/4 punch shots with your fairway wood.",
        steps: [
          "Keep your lead wrist flat and chest rotating through impact.",
          "Finish with hands low and forward."
        ],
        goal: "Lower launch into the optimal 11°–15° window.",
        reps: "10 balls"
      }
    ],
    video: HM_VIDEOS.shaft_lean
  },

  "Launch Direction Deviation": {
    category: "Face & Path",
    cause: "Clubface is pointing significantly left or right of the target at impact (start line follows face angle ~75–85%).",
    ballFlightEffect: "Shots start immediately offline left or right of your intended target.",
    howToFix: "Check your aim and clubface alignment at address, and use a start-line gate to calibrate face direction.",
    drills: [
      {
        name: "3-Foot Start-Line Gate Drill",
        setup: "Place two tees 3 feet in front of the ball, spaced just wider than a golf ball, aligned to your target.",
        steps: [
          "Hit 7-iron shots at 75% speed trying to start every ball cleanly between the two tees."
        ],
        goal: "8 out of 10 shots start within ±1.5° of target line.",
        reps: "15 balls"
      }
    ],
    video: HM_VIDEOS.sim_improvement
  },

  "Early Extension Contact Loss": {
    category: "Body Mechanics",
    cause: "Hips thrusting toward the ball during the downswing, forcing your torso to stand up and causing heel/thin strikes.",
    ballFlightEffect: "Loss of posture, blocks/hooks, and inconsistent smash factor.",
    howToFix: "Maintain your hip depth (glutes back) through impact so your arms have room to swing freely.",
    drills: [
      {
        name: "Chair / Wall Glute Depth Drill",
        setup: "Place a golf bag or chair lightly touching your glutes at address.",
        steps: [
          "Make slow-to-medium swings keeping your trail glute on the chair in the backswing, then your lead glute on the chair through impact."
        ],
        goal: "Maintain spine angle and hip depth all the way to finish.",
        reps: "15 rehearsals + 10 balls"
      }
    ],
    video: HM_VIDEOS.downswing_sequence
  },

  "Early Extension": {
    category: "Body Mechanics",
    cause: "Pelvis moving toward the target line in the downswing, lifting the chest out of posture.",
    ballFlightEffect: "Forces hand-flip timing at impact, leading to two-way misses (blocks and hooks).",
    howToFix: "Rotate your lead hip *back* away from the ball in the downswing instead of thrusting toward it.",
    drills: [
      {
        name: "Lead-Hip Back Rotation Drill",
        setup: "Take your golf posture without a ball, hands across your chest.",
        steps: [
          "Turn into your backswing, then pull your lead hip pocket straight back toward the wall behind you as you turn through."
        ],
        goal: "Keep head and chest height steady through impact.",
        reps: "15 rehearsals"
      }
    ],
    video: HM_VIDEOS.downswing_sequence
  },

  "Over-the-Top Slice": {
    category: "Body Mechanics",
    cause: "Upper body/trail shoulder lunges forward to start the downswing, throwing the club outside the target line.",
    ballFlightEffect: "Out-to-in club path producing pulls or big slices.",
    howToFix: "Start the downswing from the ground up (lead hip shift/turn) while keeping your back to the target for a split second.",
    drills: [
      {
        name: "Pump & Drop-to-Slot Drill",
        setup: "Take the club to the top of your backswing.",
        steps: [
          "Pump your hands straight down toward your trail pocket while keeping your shoulders closed.",
          "On the third pump, swing smoothly through from the inside."
        ],
        goal: "Shift Club Path from out-to-in toward 0° or slightly in-to-out.",
        reps: "12 balls"
      }
    ],
    video: HM_VIDEOS.barrier_path
  },

  "Level Shoulders Causing Steep Driver Strike": {
    category: "Body Mechanics",
    cause: "Shoulders turning too flat or tilting toward the target at impact with the driver.",
    ballFlightEffect: "Steep downward driver strike, low launch, and high spin.",
    howToFix: "Set your trail shoulder noticeably lower than your lead shoulder at address and keep your head behind the ball through impact.",
    drills: [
      {
        name: "Reverse-K Spine Tilt Drill",
        setup: "Hold a driver across your shoulders at address.",
        steps: [
          "Tilt your spine slightly away from the target so the trail end of the club points toward the ball/ground behind it.",
          "Make swings maintaining that upward launch tilt."
        ],
        goal: "Positive driver Attack Angle (+2° to +5°).",
        reps: "10 rehearsals + 10 balls"
      }
    ],
    video: HM_VIDEOS.one_metric_aoa
  },

  "Hanging Back On Fairway Wood": {
    category: "Body Mechanics",
    cause: "Weight stays trapped on the trail foot through impact instead of shifting forward.",
    ballFlightEffect: "Fat turf contact behind the ball or topped shots.",
    howToFix: "Transfer pressure onto your lead foot before the club reaches hip height on the downswing.",
    drills: [
      {
        name: "Step-Through Follow-Through Drill",
        setup: "Hit 50% speed shots with a fairway wood or hybrid.",
        steps: [
          "After impact, allow your trail foot to step forward toward the target like a baseball throw."
        ],
        goal: "Full weight transfer onto lead leg and crisp turf brush.",
        reps: "10 balls"
      }
    ],
    video: HM_VIDEOS.low_point
  },

  "Restricted Shoulder Turn": {
    category: "Body Mechanics",
    cause: "Limited thoracic rotation in the backswing (<70°), forcing arms to lift steeply.",
    ballFlightEffect: "Loss of clubhead speed and steep over-the-top downswing.",
    howToFix: "Allow your trail hip to turn slightly with your shoulders and point your lead shoulder behind the ball at the top.",
    drills: [
      {
        name: "Cross-Arm 90° Shoulder Coil Drill",
        setup: "Cross an alignment stick across your chest and take your golf posture.",
        steps: [
          "Rotate until the lead end of the stick points directly at or past the golf ball.",
          "Hold for 2 seconds, feeling a stretch in your mid-back."
        ],
        goal: "Achieve 80°–90° full shoulder turn without swaying.",
        reps: "10 reps before hitting"
      }
    ],
    video: HM_VIDEOS.sim_improvement
  },

  "Lateral Hip Sway": {
    category: "Body Mechanics",
    cause: "Hips sliding laterally away from the target in the backswing instead of rotating in place.",
    ballFlightEffect: "Inconsistent low point (fat/thin misses) and weak power transfer.",
    howToFix: "Keep weight on the inside of your trail foot in the backswing and turn your trail hip pocket behind you.",
    drills: [
      {
        name: "Trail-Leg Alignment Stick Anti-Sway Drill",
        setup: "Stick an alignment rod vertically into the ground (or place a chair) touching the outside of your trail hip.",
        steps: [
          "Make backswings turning your hip away from the rod rather than bumping into it."
        ],
        goal: "Centered hip turn with zero lateral sway.",
        reps: "12 rehearsals + 10 balls"
      }
    ],
    video: HM_VIDEOS.downswing_sequence
  },

  "Stalled Hips at Impact": {
    category: "Body Mechanics",
    cause: "Pelvis stops rotating before impact, forcing the hands/arms to flip to catch up.",
    ballFlightEffect: "Erratic face control (hooks or blocks) and lost speed.",
    howToFix: "Keep your belt buckle turning continuously toward the target all the way through the ball.",
    drills: [
      {
        name: "Belt Buckle to Target Drill",
        setup: "Hit 3/4 iron shots focusing strictly on your finish.",
        steps: [
          "Ensure your belt buckle faces the target (or slightly left for RH) by the time your hands reach waist height post-impact."
        ],
        goal: "Open hips (~35°–45°) at impact with square clubface.",
        reps: "12 balls"
      }
    ],
    video: HM_VIDEOS.downswing_sequence
  },

  "Pure Ball Strike": {
    category: "Strike & Compression",
    cause: "All key launch monitor and delivery metrics are within pro/optimal target windows!",
    ballFlightEffect: "High energy transfer, tight dispersion, and predictable ball flight.",
    howToFix: "Keep reinforcing this exact tempo and setup routine—don't over-tweak when things are working.",
    drills: [
      {
        name: "Target-Switching Pressure Drill",
        setup: "Pick a different target corridor for every single shot on the range.",
        steps: [
          "Go through your full pre-shot routine before every ball.",
          "Score yourself on hitting 10-yard-wide target corridors."
        ],
        goal: "Maintain 70%+ target corridor accuracy across 10 consecutive shots.",
        reps: "10 balls"
      }
    ],
    video: HM_VIDEOS.sim_improvement
  },

  "Toe Gear-Effect Hook": {
    category: "Strike & Gear Effect",
    cause: "Contact toward the toe bends the face open at impact and imparts counter-clockwise gear-effect hook spin—even with a neutral Face-to-Path.",
    ballFlightEffect: "Ball starts near target or slightly right (RH) and dives left with lower spin and lost carry.",
    howToFix: "Stand 1/2 inch closer to the ball, check balance toward the balls of your feet, and feel your arms stay connected without standing up through impact.",
    drills: [
      {
        name: "Toe-Gate / Foot-Spray Centering Drill",
        setup: "Spray foot powder on the clubface and place a tee 1 inch outside the toe of the clubhead at address.",
        stages: [
          { stage: "Stage 1: Setup Check", desc: "Verify posture tilt and set the ball opposite the center-heel line of the clubface at address." },
          { stage: "Stage 2: 70% Tempo Block Reps", desc: "Hit 10 three-quarter swings without grazing the outer tee; inspect face spray every 3 shots." },
          { stage: "Stage 3: 100% Transfer Test", desc: "Hit 10 full-speed shots alternating targets, verifying center strike within ±6 mm." }
        ],
        steps: [
          "Make 70% speed swings keeping your hips back in posture through impact.",
          "Verify the impact mark moves off the toe toward the sweet spot."
        ],
        monitorProof: "Horizontal Impact moves from > +6 mm toward 0 mm and Spin Axis shifts closer to 0°.",
        watchOutFor: "Do not try to hold the face open with your hands—fixing strike location removes the hook spin automatically.",
        goal: "7 of 10 strikes within ±6 mm of center face.",
        graduation: "7/10 shots within ±6 mm Horizontal Impact",
        reps: "15 balls"
      }
    ],
    video: HM_VIDEOS.low_point
  },

  "Heel Gear-Effect Slice": {
    category: "Strike & Gear Effect",
    cause: "Contact near the heel produces clockwise gear-effect slice spin and lower smash factor even when swing path is neutral.",
    ballFlightEffect: "Weak fade/slice losing significant ball speed and leaking right (RH) / left (LH).",
    howToFix: "Step 1/2 inch farther from the ball at setup, keep weight centered over mid-foot, and prevent arms from reaching out toward the ball in transition.",
    drills: [
      {
        name: "Inside-Heel Gate Drill",
        setup: "Place a headcover or tee 1 inch inside the heel of the ball and apply foot spray to the face.",
        stages: [
          { stage: "Stage 1: Setup Check", desc: "Address the ball slightly toward the toe half of the clubhead and keep chest balanced over shoelaces." },
          { stage: "Stage 2: 70% Tempo Block Reps", desc: "Hit 10 smooth swings missing the inside heel tee completely." },
          { stage: "Stage 3: 100% Transfer Test", desc: "Hit 10 full swings checking Smash Factor and horizontal strike centering." }
        ],
        steps: [
          "Rehearse 3 slow swings avoiding the heel marker.",
          "Hit 10 shots feeling your hands return closer to your thighs at impact."
        ],
        monitorProof: "Horizontal Impact shifts from < -6 mm toward 0 mm and Smash Factor rises immediately.",
        watchOutFor: "Avoid pulling arms violently inside; simply stabilize posture and setup distance.",
        goal: "7 of 10 strikes centered without touching the heel tee.",
        graduation: "7/10 shots within ±6 mm Horizontal Impact",
        reps: "15 balls"
      }
    ],
    video: HM_VIDEOS.low_point
  },

  "Low-Face Driver Spin Spike": {
    category: "Strike & Launch Window",
    cause: "Striking below the driver equator engages vertical gear effect, spiking backspin and lowering launch.",
    ballFlightEffect: "Low launch that climbs steeply and stalls in the air, costing 15–25 yards of total distance.",
    howToFix: "Tee the ball half a ball above the driver crown, tilt your spine 8° away from target, and sweep slightly upward.",
    drills: [
      {
        name: "Upper-Equator Tee Height Drill",
        setup: "Tee the ball higher so half the ball sits above the driver crown, and apply face spray.",
        stages: [
          { stage: "Stage 1: Setup Check", desc: "Ball opposite lead heel, trail shoulder lower than lead shoulder, driver resting slightly behind ball." },
          { stage: "Stage 2: 70% Tempo Block Reps", desc: "Hit 8 smooth swings trying to clip the upper-center quadrant of the face." },
          { stage: "Stage 3: 100% Transfer Test", desc: "Hit 10 full drives tracking AoA (+1° to +4°) and BackSpin (< 2,800 rpm)." }
        ],
        steps: [
          "Check spray mark height after each ball—target 2–5 mm above center.",
          "Keep your head behind the ball through impact."
        ],
        monitorProof: "Vertical Impact rises to 0 to +5 mm, VLA increases 1–2°, and Spin drops 400–800 rpm.",
        watchOutFor: "Don't drop your trail shoulder excessively and hit the ground behind the tee.",
        goal: "Achieve positive Attack Angle and < 2,800 RPM driver spin.",
        graduation: "7/10 drives with Spin < 2,800 RPM and VLA 11°–15°",
        reps: "12–15 balls"
      }
    ],
    video: HM_VIDEOS.one_metric_aoa
  },

  "Two-Way Miss / Face Instability": {
    category: "Face & Start-Line Control",
    cause: "Large shot-to-shot swings in Face Angle and timing cause misses both left and right.",
    ballFlightEffect: "Wide dispersion ellipse and unpredictable start lines where aiming adjustments don't help.",
    howToFix: "Switch to 75% tempo swings, standardize your grip pressure (4/10), and build wrist stability through impact before chasing distance.",
    drills: [
      {
        name: "Differential Calibration & Start-Line Gate",
        setup: "Place two alignment sticks 8 feet ahead forming a narrow start-line gate.",
        stages: [
          { stage: "Stage 1: Setup Check", desc: "Verify neutral grip and clubface squareness to target stick before every rep." },
          { stage: "Stage 2: 70% Tempo Block Reps", desc: "Differential feel: hit 3 intentional draws, 3 intentional fades, then 4 straight gate shots." },
          { stage: "Stage 3: 100% Transfer Test", desc: "Hit 10 full shots trying to start every ball cleanly through the gate." }
        ],
        steps: [
          "Use the same 3-count rhythm on every swing.",
          "Track HLA / Face Angle spread rather than total distance."
        ],
        monitorProof: "Face Angle StdDev tightens under ±2.2° and shots cluster on one side or center.",
        watchOutFor: "Do not swing above 80% speed until 7 of 10 start cleanly inside the gate.",
        goal: "Eliminate the opposite-side miss and narrow Face StdDev below 2.2°.",
        graduation: "7/10 shots with |HLA| ≤ 2.0°",
        reps: "10–16 balls"
      }
    ],
    video: HM_VIDEOS.downswing_sequence
  },

  "High Spin Loft / Flipping": {
    category: "Compression & Shaft Lean",
    cause: "Hands flip/scoop through impact, adding excessive Dynamic Loft relative to Attack Angle and reducing compression.",
    ballFlightEffect: "High weak shots with low smash factor that fall short into any headwind.",
    howToFix: "Maintain a flat/bowed lead wrist through impact and rotate your torso forward so hands lead the clubhead at strike.",
    drills: [
      {
        name: "9-to-3 Forward Shaft Lean Punch Drill",
        setup: "Play the ball slightly back of center with a 7-iron or 8-iron.",
        stages: [
          { stage: "Stage 1: Setup Check", desc: "Pre-set hands slightly ahead of the ball (shaft leaning toward lead thigh) and feel lead wrist flat." },
          { stage: "Stage 2: 70% Tempo Block Reps", desc: "Make waist-to-waist 9-to-3 swings finishing with clubhead lower than hands and lead wrist flat." },
          { stage: "Stage 3: 100% Transfer Test", desc: "Blend the same impact feel into full swings." }
        ],
        steps: [
          "Take a shallow divot or brush mark strictly ahead of the ball.",
          "Hold your finish at waist height to inspect shaft lean."
        ],
        monitorProof: "Dynamic Loft drops 2–4°, AoA moves negative (-3° to -5°), and Smash Factor rises.",
        watchOutFor: "Ensure your torso keeps rotating open—leaning the shaft without body turn can cause pulls.",
        goal: "Lower Spin Loft into your club's optimal band and raise Smash Factor +0.03.",
        graduation: "7/10 shots hitting club Smash benchmark",
        reps: "15 balls"
      }
    ],
    video: HM_VIDEOS.shaft_lean
  },

  "Low Descent Angle / Won't Hold Green": {
    category: "Approach Stopping Power",
    cause: "Shallow landing trajectory (<43° descent) or insufficient spin prevents irons from stopping quickly on greens.",
    ballFlightEffect: "Approaches hit the green and bounce over the back pin.",
    howToFix: "Achieve a crisp descending strike (-3° to -5° AoA) with clean grooves and solid height to steepen landing angle to 45°+.",
    drills: [
      {
        name: "Apex & Steep Descent Compression Drill",
        setup: "Place a tee or towel 3 inches behind your iron ball position.",
        stages: [
          { stage: "Stage 1: Setup Check", desc: "Ball positioned center-forward with 55% weight on lead foot." },
          { stage: "Stage 2: 70% Tempo Block Reps", desc: "Strike down cleanly missing the rear towel, letting club loft launch the ball high." },
          { stage: "Stage 3: 100% Transfer Test", desc: "Hit full shots monitoring Descent Angle (target ≥45°) and Apex." }
        ],
        steps: [
          "Focus on hitting ball-first before turf.",
          "Monitor Descent Angle and BackSpin after each strike."
        ],
        monitorProof: "Descent Angle climbs above 45° and BackSpin matches (~Club # × 1,000 rpm).",
        watchOutFor: "Avoid scooping upward to add height—hitting down cleanly with speed creates real spin-lift.",
        goal: "Average 45°+ Descent Angle on mid/short irons.",
        graduation: "7/10 iron shots with Descent Angle ≥ 45°",
        reps: "12 balls"
      }
    ],
    video: HM_VIDEOS.shaft_lean
  },

  "In-Session Fatigue Drift": {
    category: "Tempo & Endurance",
    cause: "Late-session shots (>20 swings) lose posture and rhythm, widening dispersion and dropping ball speed.",
    ballFlightEffect: "Opening 10 shots look great, then late swings drift offline and lose carry.",
    howToFix: "Slow practice cadence: step back off the mat between shots, rest 60 seconds every 15 balls, and end high-focus blocks early when fatigue appears.",
    drills: [
      {
        name: "10-Ball Quality Reset Protocol",
        setup: "Commit to stepping off the hitting mat and taking 2 deep breaths after every 3 balls.",
        stages: [
          { stage: "Stage 1: Setup Check", desc: "Re-align feet and target before every single shot rather than raking-and-hitting." },
          { stage: "Stage 2: 70% Tempo Block Reps", desc: "Play a 10-ball scoring game where only routine-backed shots count." },
          { stage: "Stage 3: 100% Transfer Test", desc: "Maintain within ±2 mph ball speed and tight dispersion through ball #25." }
        ],
        steps: [
          "Step completely behind the ball to pick a target before each swing.",
          "Stop speed work as soon as Smash Factor dips below baseline."
        ],
        monitorProof: "Last 10 shots stay within 2 yds offline and 0.02 Smash of your opening 10.",
        watchOutFor: "Rapidly hitting ball after ball grooves fatigue faults instead of your best swing.",
        goal: "Zero drop-off between early and late session blocks.",
        graduation: "Maintain target corridor rate within 10% across full session",
        reps: "10-ball structured blocks"
      }
    ],
    video: HM_VIDEOS.sim_improvement
  }
};

// Analytics-specific issue keys (from telemetry trend detection in analytics-engine.js)
const ANALYTICS_ISSUE_ALIASES = {
  offline_expanding: {
    issueType: "Expanding Offline Dispersion",
    category: "Accuracy & Dispersion",
    cause: "Recent shots are drifting further from the target centerline than your earlier baseline.",
    ballFlightEffect: "Wider left-to-right miss pattern and fewer shots holding the target corridor.",
    howToFix: "Slow tempo to 80%, verify alignment with a target stick, and focus on squaring the clubface before adding speed.",
    drills: [
      ISSUE_DATABASE["Launch Direction Deviation"].drills[0],
      ISSUE_DATABASE["Fade / Open Face"].drills[0]
    ],
    video: HM_VIDEOS.sim_improvement
  },
  face_open: {
    issueType: "Open Club Face Tendency",
    ...ISSUE_DATABASE["Slice / Open Face-to-Path"]
  },
  face_closed: {
    issueType: "Closed Club Face Tendency",
    ...ISSUE_DATABASE["Hook / Closed Face-to-Path"]
  },
  path_out_to_in: {
    issueType: "Out-to-In Swing Path",
    ...ISSUE_DATABASE["Over-the-Top Slice"]
  },
  path_in_to_out: {
    issueType: "Excessive In-to-Out Path",
    ...ISSUE_DATABASE["Hook / Closed Face-to-Path"]
  },
  face_to_path_curve: {
    issueType: "High Face-to-Path Curvature",
    ...ISSUE_DATABASE["Fade / Open Face"]
  },
  low_smash: {
    issueType: "Reduced Strike Efficiency (Smash Factor)",
    ...ISSUE_DATABASE["Low Smash Factor"]
  },
  off_center_strike: {
    issueType: "Off-Center Face Contact",
    ...ISSUE_DATABASE["Sub-Optimal Smash Factor"]
  },
  high_spin: {
    issueType: "Elevated Backspin Rate",
    ...ISSUE_DATABASE["Excessive Driver Spin"]
  },
  low_launch: {
    issueType: "Low Launch Window",
    ...ISSUE_DATABASE["Low Driver Launch"]
  },
  toe_gear_hook: {
    issueType: "Toe Gear-Effect Hook",
    ...ISSUE_DATABASE["Toe Gear-Effect Hook"]
  },
  heel_gear_slice: {
    issueType: "Heel Gear-Effect Slice",
    ...ISSUE_DATABASE["Heel Gear-Effect Slice"]
  },
  low_face_spin: {
    issueType: "Low-Face Driver Spin Spike",
    ...ISSUE_DATABASE["Low-Face Driver Spin Spike"]
  },
  two_way_miss: {
    issueType: "Two-Way Miss / Face Instability",
    ...ISSUE_DATABASE["Two-Way Miss / Face Instability"]
  },
  high_spin_loft: {
    issueType: "High Spin Loft / Flipping",
    ...ISSUE_DATABASE["High Spin Loft / Flipping"]
  },
  low_descent_angle: {
    issueType: "Low Descent Angle / Won't Hold Green",
    ...ISSUE_DATABASE["Low Descent Angle / Won't Hold Green"]
  },
  fatigue_drift: {
    issueType: "In-Session Fatigue Drift",
    ...ISSUE_DATABASE["In-Session Fatigue Drift"]
  }
};

function enrichDrillProgression(drill, issueDetails) {
  const enriched = { ...drill };
  if (!Array.isArray(enriched.stages) || enriched.stages.length === 0) {
    enriched.stages = [
      { stage: "Stage 1: Setup Check", desc: enriched.setup || "Verify balanced posture, grip, and target alignment before starting." },
      { stage: "Stage 2: 70% Tempo Block Reps", desc: (enriched.steps && enriched.steps[0]) || issueDetails.howToFix || "Perform controlled 3/4 swings prioritizing feel over speed." },
      { stage: "Stage 3: 100% Transfer Test", desc: enriched.goal || "Step up to full speed and verify ball flight matches your target window." }
    ];
  }
  if (!enriched.monitorProof) {
    enriched.monitorProof = enriched.goal || "Confirm launch monitor metrics trend closer to your target corridor over 10 shots.";
  }
  if (!enriched.watchOutFor) {
    enriched.watchOutFor = "Avoid chasing distance during block drills—lock in the movement at 70–80% speed first.";
  }
  if (!enriched.graduation) {
    enriched.graduation = enriched.goal || "7 of 10 shots meeting target criteria.";
  }
  return enriched;
}

function enrichIssueDetails(details) {
  if (!details) return null;
  return {
    ...details,
    drills: Array.isArray(details.drills)
      ? details.drills.map((d) => enrichDrillProgression(d, details))
      : []
  };
}

/**
 * Looks up detailed fix instructions, causes, drills, and video metadata for any
 * swing issue string (from statsData.swing_issues) or analytics issue key.
 */
export function getSwingIssueDetails(issueName) {
  if (!issueName) return null;
  const key = String(issueName).trim();

  if (ISSUE_DATABASE[key]) {
    return enrichIssueDetails({ issueType: key, ...ISSUE_DATABASE[key] });
  }
  if (ANALYTICS_ISSUE_ALIASES[key]) {
    return enrichIssueDetails({ ...ANALYTICS_ISSUE_ALIASES[key] });
  }

  // Handle dynamic club-specific issues such as "Scooping / Upward Iron AoA"
  if (/scooping|upward.*aoa/i.test(key)) {
    return enrichIssueDetails({
      issueType: key,
      category: "Attack Angle & Low Point",
      cause: "Clubhead is bottoming out behind the ball and swinging upward into impact.",
      ballFlightEffect: "Thin, fat, or high-floating iron/wedge shots with inconsistent distance.",
      howToFix: "Shift weight onto your lead foot in transition and deliver your hands ahead of the clubhead so your low point is 1–2 inches past the ball.",
      drills: ISSUE_DATABASE["Scooping Hybrid Off Turf"].drills,
      video: HM_VIDEOS.shaft_lean
    });
  }

  // Keyword-based fallback so every recorded issue always provides helpful fix & drill advice
  const lower = key.toLowerCase();
  if (lower.includes("toe") && lower.includes("gear")) {
    return enrichIssueDetails({ issueType: key, ...ISSUE_DATABASE["Toe Gear-Effect Hook"] });
  }
  if (lower.includes("heel") && lower.includes("gear")) {
    return enrichIssueDetails({ issueType: key, ...ISSUE_DATABASE["Heel Gear-Effect Slice"] });
  }
  if (lower.includes("descent")) {
    return enrichIssueDetails({ issueType: key, ...ISSUE_DATABASE["Low Descent Angle / Won't Hold Green"] });
  }
  if (lower.includes("spin loft") || lower.includes("flip")) {
    return enrichIssueDetails({ issueType: key, ...ISSUE_DATABASE["High Spin Loft / Flipping"] });
  }
  if (lower.includes("slice") || lower.includes("open")) {
    return enrichIssueDetails({ issueType: key, ...ISSUE_DATABASE["Slice / Open Face-to-Path"] });
  }
  if (lower.includes("hook") || lower.includes("closed") || lower.includes("draw")) {
    return enrichIssueDetails({ issueType: key, ...ISSUE_DATABASE["Hook / Closed Face-to-Path"] });
  }
  if (lower.includes("steep")) {
    return enrichIssueDetails({ issueType: key, ...ISSUE_DATABASE["Steep Driver Attack Angle"] });
  }
  if (lower.includes("spin")) {
    return enrichIssueDetails({ issueType: key, ...ISSUE_DATABASE["Excessive Driver Spin"] });
  }
  if (lower.includes("launch")) {
    return enrichIssueDetails({ issueType: key, ...ISSUE_DATABASE["Low Driver Launch"] });
  }
  if (lower.includes("smash") || lower.includes("strike")) {
    return enrichIssueDetails({ issueType: key, ...ISSUE_DATABASE["Low Smash Factor"] });
  }

  return enrichIssueDetails({
    issueType: key,
    category: "Swing Mechanics",
    cause: `Recurring tendency detected for "${key}" during simulator sessions.`,
    ballFlightEffect: "Can reduce consistency in start line, strike quality, or distance control.",
    howToFix: "Use 3/4 tempo swings with an alignment stick down your target line to stabilize clubface control and centered contact.",
    drills: [
      {
        name: "3/4 Tempo Alignment & Gate Drill",
        setup: "Place an alignment stick parallel to your target line and two tees just wider than your clubhead.",
        steps: [
          "Hit 10 shots at 75% swing speed focusing on balanced posture.",
          "Verify ball starts on line and contact feels centered on the face."
        ],
        goal: "Build repeatable contact and directional control before returning to 100% speed.",
        reps: "10–15 balls"
      }
    ],
    video: HM_VIDEOS.sim_improvement
  });
}

/**
 * Returns recommended drills for an analytics coaching insight or detected telemetry issue key.
 */
export function getDrillsForAnalyticsIssue(issueKey) {
  return getSwingIssueDetails(issueKey);
}
