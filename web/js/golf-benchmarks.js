// Heckle Golf Simulator - Canonical Club Benchmarks, D-Plane & Geometry Helpers
// Mirrors GolfSwingAnalyzer benchmarks in UI/GolferCamera/golf_swing_analyzer.gd
// so web portal analytics and in-app coaching stay 100% synchronized.

export const SKILL_LEVEL_NAMES = {
  high_handicap: "High Handicap (20+ HCP)",
  mid_handicap: "Mid Handicap (10–19 HCP)",
  scratch: "Scratch / Low HCP (0–9 HCP)",
  tour_pro: "Tour Pro (PGA/LPGA Benchmark)"
};

/**
 * Normalizes legacy web ("beginner", "low_handicap") and canonical skill keys.
 */
export function normalizeSkillLevel(lvl) {
  const key = String(lvl || "").trim().toLowerCase();
  if (key === "beginner" || key === "high_handicap") return "high_handicap";
  if (key === "low_handicap" || key === "scratch") return "scratch";
  if (key === "tour_pro" || key === "pro") return "tour_pro";
  return "mid_handicap";
}

// Per-club geometry & spin-loft defaults shared across skill tiers
const CLUB_META = {
  driver: { spin_loft_min: 10.0, spin_loft_max: 14.5, corridor_yds: 15, target_type: "fairway" },
  "3w":   { spin_loft_min: 13.0, spin_loft_max: 17.5, corridor_yds: 12, target_type: "fairway" },
  "5w":   { spin_loft_min: 16.0, spin_loft_max: 20.5, corridor_yds: 12, target_type: "fairway" },
  hybrid: { spin_loft_min: 18.0, spin_loft_max: 22.5, corridor_yds: 12, target_type: "fairway" },
  "4i":   { spin_loft_min: 20.0, spin_loft_max: 24.5, corridor_yds: 10, target_type: "green" },
  "5i":   { spin_loft_min: 22.0, spin_loft_max: 26.5, corridor_yds: 10, target_type: "green" },
  "6i":   { spin_loft_min: 24.0, spin_loft_max: 28.5, corridor_yds: 8,  target_type: "green" },
  "7i":   { spin_loft_min: 26.0, spin_loft_max: 30.5, corridor_yds: 8,  target_type: "green" },
  "8i":   { spin_loft_min: 28.0, spin_loft_max: 33.0, corridor_yds: 8,  target_type: "green" },
  "9i":   { spin_loft_min: 31.0, spin_loft_max: 36.0, corridor_yds: 6,  target_type: "green" },
  pw:     { spin_loft_min: 34.0, spin_loft_max: 40.0, corridor_yds: 6,  target_type: "green" },
  gw:     { spin_loft_min: 38.0, spin_loft_max: 44.0, corridor_yds: 6,  target_type: "green" },
  sw:     { spin_loft_min: 42.0, spin_loft_max: 48.0, corridor_yds: 6,  target_type: "green" },
  lw:     { spin_loft_min: 46.0, spin_loft_max: 52.0, corridor_yds: 6,  target_type: "green" }
};

function withMeta(clubsObj) {
  const out = {};
  for (const [k, v] of Object.entries(clubsObj)) {
    out[k] = { ...v, ...(CLUB_META[k] || {}) };
  }
  return out;
}

export const CLUB_BENCHMARKS = {
  mid_handicap: withMeta({
    driver: { name: "Driver", club_speed_min: 90.0, club_speed_max: 97.0, ball_speed_min: 128.0, ball_speed_max: 140.0, smash_min: 1.41, smash_max: 1.46, aoa_min: -2.5, aoa_max: 1.5, vla_min: 12.5, vla_max: 15.5, spin_min: 2500.0, spin_max: 3200.0, carry_min: 205.0, carry_max: 230.0, rollout_min: 15.0, rollout_max: 24.0, apex_min: 75.0, apex_max: 90.0, land_angle_min: 36.0, land_angle_max: 41.0 },
    "3w":   { name: "3-Wood", club_speed_min: 85.0, club_speed_max: 92.0, ball_speed_min: 122.0, ball_speed_max: 132.0, smash_min: 1.41, smash_max: 1.45, aoa_min: -2.0, aoa_max: 0.5, vla_min: 12.0, vla_max: 14.8, spin_min: 3400.0, spin_max: 4300.0, carry_min: 185.0, carry_max: 205.0, rollout_min: 14.0, rollout_max: 20.0, apex_min: 74.0, apex_max: 88.0, land_angle_min: 40.0, land_angle_max: 44.0 },
    "5w":   { name: "5-Wood", club_speed_min: 82.0, club_speed_max: 88.0, ball_speed_min: 116.0, ball_speed_max: 126.0, smash_min: 1.40, smash_max: 1.44, aoa_min: -2.5, aoa_max: 0.0, vla_min: 13.0, vla_max: 16.0, spin_min: 4000.0, spin_max: 4900.0, carry_min: 174.0, carry_max: 192.0, rollout_min: 10.0, rollout_max: 16.0, apex_min: 74.0, apex_max: 88.0, land_angle_min: 42.0, land_angle_max: 46.0 },
    hybrid: { name: "Hybrid", club_speed_min: 79.0, club_speed_max: 85.0, ball_speed_min: 112.0, ball_speed_max: 121.0, smash_min: 1.39, smash_max: 1.43, aoa_min: -3.0, aoa_max: -0.5, vla_min: 13.5, vla_max: 16.5, spin_min: 4200.0, spin_max: 5100.0, carry_min: 165.0, carry_max: 182.0, rollout_min: 8.0, rollout_max: 14.0, apex_min: 72.0, apex_max: 86.0, land_angle_min: 43.0, land_angle_max: 47.0 },
    "4i":   { name: "4-Iron", club_speed_min: 77.0, club_speed_max: 83.0, ball_speed_min: 107.0, ball_speed_max: 116.0, smash_min: 1.37, smash_max: 1.41, aoa_min: -3.0, aoa_max: -1.0, vla_min: 13.0, vla_max: 15.5, spin_min: 4200.0, spin_max: 5100.0, carry_min: 156.0, carry_max: 172.0, rollout_min: 8.0, rollout_max: 14.0, apex_min: 70.0, apex_max: 84.0, land_angle_min: 43.0, land_angle_max: 47.0 },
    "5i":   { name: "5-Iron", club_speed_min: 75.0, club_speed_max: 80.0, ball_speed_min: 102.0, ball_speed_max: 111.0, smash_min: 1.36, smash_max: 1.40, aoa_min: -3.2, aoa_max: -1.2, vla_min: 14.0, vla_max: 16.8, spin_min: 4600.0, spin_max: 5500.0, carry_min: 148.0, carry_max: 162.0, rollout_min: 6.0, rollout_max: 12.0, apex_min: 70.0, apex_max: 84.0, land_angle_min: 44.0, land_angle_max: 48.0 },
    "6i":   { name: "6-Iron", club_speed_min: 73.0, club_speed_max: 78.0, ball_speed_min: 97.0, ball_speed_max: 105.0, smash_min: 1.34, smash_max: 1.38, aoa_min: -3.5, aoa_max: -1.5, vla_min: 15.5, vla_max: 18.5, spin_min: 5000.0, spin_max: 6000.0, carry_min: 138.0, carry_max: 152.0, rollout_min: 5.0, rollout_max: 9.0, apex_min: 70.0, apex_max: 84.0, land_angle_min: 45.0, land_angle_max: 49.0 },
    "7i":   { name: "7-Iron", club_speed_min: 70.0, club_speed_max: 76.0, ball_speed_min: 92.0, ball_speed_max: 101.0, smash_min: 1.32, smash_max: 1.36, aoa_min: -3.8, aoa_max: -1.8, vla_min: 17.5, vla_max: 20.8, spin_min: 5400.0, spin_max: 6400.0, carry_min: 128.0, carry_max: 142.0, rollout_min: 4.0, rollout_max: 8.0, apex_min: 70.0, apex_max: 82.0, land_angle_min: 46.0, land_angle_max: 50.0 },
    "8i":   { name: "8-Iron", club_speed_min: 68.0, club_speed_max: 73.0, ball_speed_min: 87.0, ball_speed_max: 95.0, smash_min: 1.30, smash_max: 1.34, aoa_min: -4.0, aoa_max: -2.0, vla_min: 19.0, vla_max: 22.5, spin_min: 5900.0, spin_max: 7000.0, carry_min: 118.0, carry_max: 131.0, rollout_min: 3.0, rollout_max: 6.0, apex_min: 68.0, apex_max: 80.0, land_angle_min: 47.0, land_angle_max: 51.0 },
    "9i":   { name: "9-Iron", club_speed_min: 65.0, club_speed_max: 70.0, ball_speed_min: 81.0, ball_speed_max: 89.0, smash_min: 1.26, smash_max: 1.30, aoa_min: -4.2, aoa_max: -2.2, vla_min: 21.0, vla_max: 24.8, spin_min: 6400.0, spin_max: 7500.0, carry_min: 108.0, carry_max: 120.0, rollout_min: 2.0, rollout_max: 4.0, apex_min: 68.0, apex_max: 80.0, land_angle_min: 48.0, land_angle_max: 52.0 },
    pw:     { name: "Pitching Wedge", club_speed_min: 63.0, club_speed_max: 68.0, ball_speed_min: 75.0, ball_speed_max: 83.0, smash_min: 1.20, smash_max: 1.24, aoa_min: -4.5, aoa_max: -2.5, vla_min: 24.0, vla_max: 28.0, spin_min: 6800.0, spin_max: 8000.0, carry_min: 98.0, carry_max: 110.0, rollout_min: 1.0, rollout_max: 3.0, apex_min: 66.0, apex_max: 78.0, land_angle_min: 49.0, land_angle_max: 53.0 },
    gw:     { name: "Gap Wedge", club_speed_min: 60.0, club_speed_max: 65.0, ball_speed_min: 69.0, ball_speed_max: 76.0, smash_min: 1.16, smash_max: 1.20, aoa_min: -4.8, aoa_max: -2.8, vla_min: 26.0, vla_max: 30.5, spin_min: 7000.0, spin_max: 8200.0, carry_min: 86.0, carry_max: 98.0, rollout_min: 1.0, rollout_max: 3.0, apex_min: 64.0, apex_max: 76.0, land_angle_min: 50.0, land_angle_max: 54.0 },
    sw:     { name: "Sand Wedge", club_speed_min: 56.0, club_speed_max: 61.0, ball_speed_min: 62.0, ball_speed_max: 69.0, smash_min: 1.12, smash_max: 1.16, aoa_min: -5.0, aoa_max: -3.0, vla_min: 29.0, vla_max: 33.5, spin_min: 7200.0, spin_max: 8400.0, carry_min: 74.0, carry_max: 84.0, rollout_min: 0.0, rollout_max: 2.0, apex_min: 62.0, apex_max: 72.0, land_angle_min: 51.0, land_angle_max: 55.0 },
    lw:     { name: "Lob Wedge", club_speed_min: 52.0, club_speed_max: 57.0, ball_speed_min: 54.0, ball_speed_max: 61.0, smash_min: 1.05, smash_max: 1.10, aoa_min: -5.2, aoa_max: -3.2, vla_min: 32.0, vla_max: 37.0, spin_min: 6800.0, spin_max: 8000.0, carry_min: 60.0, carry_max: 70.0, rollout_min: 0.0, rollout_max: 2.0, apex_min: 58.0, apex_max: 68.0, land_angle_min: 52.0, land_angle_max: 56.0 }
  }),
  scratch: withMeta({
    driver: { name: "Driver", club_speed_min: 102.0, club_speed_max: 108.0, ball_speed_min: 150.0, ball_speed_max: 160.0, smash_min: 1.45, smash_max: 1.49, aoa_min: -1.0, aoa_max: 3.0, vla_min: 11.5, vla_max: 14.5, spin_min: 2300.0, spin_max: 2800.0, carry_min: 245.0, carry_max: 265.0, rollout_min: 18.0, rollout_max: 26.0, apex_min: 85.0, apex_max: 100.0, land_angle_min: 37.0, land_angle_max: 41.0 },
    "3w":   { name: "3-Wood", club_speed_min: 96.0, club_speed_max: 102.0, ball_speed_min: 142.0, ball_speed_max: 150.0, smash_min: 1.45, smash_max: 1.48, aoa_min: -2.5, aoa_max: -0.5, vla_min: 11.0, vla_max: 13.5, spin_min: 3500.0, spin_max: 4200.0, carry_min: 218.0, carry_max: 235.0, rollout_min: 14.0, rollout_max: 20.0, apex_min: 82.0, apex_max: 95.0, land_angle_min: 41.0, land_angle_max: 45.0 },
    "5w":   { name: "5-Wood", club_speed_min: 92.0, club_speed_max: 98.0, ball_speed_min: 135.0, ball_speed_max: 143.0, smash_min: 1.44, smash_max: 1.47, aoa_min: -3.0, aoa_max: -1.0, vla_min: 12.5, vla_max: 15.0, spin_min: 4100.0, spin_max: 4800.0, carry_min: 205.0, carry_max: 220.0, rollout_min: 10.0, rollout_max: 15.0, apex_min: 84.0, apex_max: 96.0, land_angle_min: 43.0, land_angle_max: 47.0 },
    hybrid: { name: "Hybrid", club_speed_min: 89.0, club_speed_max: 95.0, ball_speed_min: 130.0, ball_speed_max: 138.0, smash_min: 1.43, smash_max: 1.46, aoa_min: -3.5, aoa_max: -1.5, vla_min: 13.0, vla_max: 15.5, spin_min: 4400.0, spin_max: 5100.0, carry_min: 196.0, carry_max: 210.0, rollout_min: 8.0, rollout_max: 13.0, apex_min: 82.0, apex_max: 94.0, land_angle_min: 44.0, land_angle_max: 48.0 },
    "4i":   { name: "4-Iron", club_speed_min: 86.0, club_speed_max: 92.0, ball_speed_min: 123.0, ball_speed_max: 131.0, smash_min: 1.40, smash_max: 1.44, aoa_min: -3.8, aoa_max: -1.8, vla_min: 12.0, vla_max: 14.5, spin_min: 4500.0, spin_max: 5300.0, carry_min: 185.0, carry_max: 198.0, rollout_min: 8.0, rollout_max: 13.0, apex_min: 80.0, apex_max: 92.0, land_angle_min: 44.0, land_angle_max: 48.0 },
    "5i":   { name: "5-Iron", club_speed_min: 84.0, club_speed_max: 89.0, ball_speed_min: 118.0, ball_speed_max: 126.0, smash_min: 1.39, smash_max: 1.43, aoa_min: -4.0, aoa_max: -2.0, vla_min: 13.0, vla_max: 15.5, spin_min: 5000.0, spin_max: 5800.0, carry_min: 175.0, carry_max: 187.0, rollout_min: 6.0, rollout_max: 10.0, apex_min: 80.0, apex_max: 92.0, land_angle_min: 45.0, land_angle_max: 49.0 },
    "6i":   { name: "6-Iron", club_speed_min: 81.0, club_speed_max: 86.0, ball_speed_min: 113.0, ball_speed_max: 120.0, smash_min: 1.38, smash_max: 1.41, aoa_min: -4.2, aoa_max: -2.2, vla_min: 14.5, vla_max: 17.0, spin_min: 5700.0, spin_max: 6500.0, carry_min: 165.0, carry_max: 176.0, rollout_min: 5.0, rollout_max: 8.0, apex_min: 82.0, apex_max: 94.0, land_angle_min: 46.5, land_angle_max: 50.5 },
    "7i":   { name: "7-Iron", club_speed_min: 79.0, club_speed_max: 84.0, ball_speed_min: 108.0, ball_speed_max: 115.0, smash_min: 1.35, smash_max: 1.39, aoa_min: -4.5, aoa_max: -2.5, vla_min: 16.5, vla_max: 19.0, spin_min: 6300.0, spin_max: 7100.0, carry_min: 155.0, carry_max: 166.0, rollout_min: 3.0, rollout_max: 6.0, apex_min: 82.0, apex_max: 94.0, land_angle_min: 48.0, land_angle_max: 52.0 },
    "8i":   { name: "8-Iron", club_speed_min: 76.0, club_speed_max: 81.0, ball_speed_min: 102.0, ball_speed_max: 109.0, smash_min: 1.33, smash_max: 1.37, aoa_min: -4.8, aoa_max: -2.8, vla_min: 18.0, vla_max: 21.0, spin_min: 7100.0, spin_max: 7900.0, carry_min: 144.0, carry_max: 155.0, rollout_min: 2.0, rollout_max: 5.0, apex_min: 82.0, apex_max: 92.0, land_angle_min: 49.0, land_angle_max: 53.0 },
    "9i":   { name: "9-Iron", club_speed_min: 74.0, club_speed_max: 78.0, ball_speed_min: 96.0, ball_speed_max: 102.0, smash_min: 1.29, smash_max: 1.33, aoa_min: -5.0, aoa_max: -3.0, vla_min: 20.0, vla_max: 23.0, spin_min: 7700.0, spin_max: 8600.0, carry_min: 133.0, carry_max: 144.0, rollout_min: 1.0, rollout_max: 3.0, apex_min: 80.0, apex_max: 92.0, land_angle_min: 50.0, land_angle_max: 54.0 },
    pw:     { name: "Pitching Wedge", club_speed_min: 71.0, club_speed_max: 76.0, ball_speed_min: 89.0, ball_speed_max: 95.0, smash_min: 1.22, smash_max: 1.26, aoa_min: -5.2, aoa_max: -3.2, vla_min: 23.5, vla_max: 27.0, spin_min: 8200.0, spin_max: 9200.0, carry_min: 122.0, carry_max: 132.0, rollout_min: 0.0, rollout_max: 2.0, apex_min: 78.0, apex_max: 90.0, land_angle_min: 51.0, land_angle_max: 55.0 },
    gw:     { name: "Gap Wedge", club_speed_min: 68.0, club_speed_max: 73.0, ball_speed_min: 82.0, ball_speed_max: 88.0, smash_min: 1.19, smash_max: 1.23, aoa_min: -5.5, aoa_max: -3.5, vla_min: 25.5, vla_max: 29.5, spin_min: 8500.0, spin_max: 9500.0, carry_min: 108.0, carry_max: 118.0, rollout_min: 0.0, rollout_max: 2.0, apex_min: 76.0, apex_max: 88.0, land_angle_min: 52.0, land_angle_max: 56.0 },
    sw:     { name: "Sand Wedge", club_speed_min: 64.0, club_speed_max: 69.0, ball_speed_min: 74.0, ball_speed_max: 80.0, smash_min: 1.15, smash_max: 1.19, aoa_min: -5.8, aoa_max: -3.8, vla_min: 28.5, vla_max: 32.5, spin_min: 8700.0, spin_max: 9700.0, carry_min: 92.0, carry_max: 102.0, rollout_min: 0.0, rollout_max: 1.0, apex_min: 72.0, apex_max: 84.0, land_angle_min: 53.0, land_angle_max: 57.0 },
    lw:     { name: "Lob Wedge", club_speed_min: 59.0, club_speed_max: 64.0, ball_speed_min: 64.0, ball_speed_max: 70.0, smash_min: 1.09, smash_max: 1.13, aoa_min: -6.0, aoa_max: -4.0, vla_min: 31.5, vla_max: 36.0, spin_min: 8200.0, spin_max: 9200.0, carry_min: 74.0, carry_max: 84.0, rollout_min: 0.0, rollout_max: 1.0, apex_min: 68.0, apex_max: 78.0, land_angle_min: 54.0, land_angle_max: 58.0 }
  }),
  tour_pro: withMeta({
    driver: { name: "Driver", club_speed_min: 112.0, club_speed_max: 118.0, ball_speed_min: 167.0, ball_speed_max: 174.0, smash_min: 1.46, smash_max: 1.50, aoa_min: -2.0, aoa_max: 2.5, vla_min: 10.0, vla_max: 13.0, spin_min: 2200.0, spin_max: 2700.0, carry_min: 275.0, carry_max: 295.0, rollout_min: 18.0, rollout_max: 28.0, apex_min: 95.0, apex_max: 110.0, land_angle_min: 37.0, land_angle_max: 42.0 },
    "3w":   { name: "3-Wood", club_speed_min: 105.0, club_speed_max: 111.0, ball_speed_min: 156.0, ball_speed_max: 163.0, smash_min: 1.46, smash_max: 1.50, aoa_min: -3.5, aoa_max: -1.5, vla_min: 10.0, vla_max: 12.5, spin_min: 3300.0, spin_max: 4000.0, carry_min: 240.0, carry_max: 258.0, rollout_min: 15.0, rollout_max: 22.0, apex_min: 90.0, apex_max: 102.0, land_angle_min: 42.0, land_angle_max: 46.0 },
    "5w":   { name: "5-Wood", club_speed_min: 101.0, club_speed_max: 107.0, ball_speed_min: 149.0, ball_speed_max: 156.0, smash_min: 1.45, smash_max: 1.49, aoa_min: -4.0, aoa_max: -2.0, vla_min: 11.5, vla_max: 14.0, spin_min: 4000.0, spin_max: 4700.0, carry_min: 228.0, carry_max: 244.0, rollout_min: 10.0, rollout_max: 16.0, apex_min: 92.0, apex_max: 104.0, land_angle_min: 45.0, land_angle_max: 49.0 },
    hybrid: { name: "Hybrid", club_speed_min: 98.0, club_speed_max: 104.0, ball_speed_min: 143.0, ball_speed_max: 150.0, smash_min: 1.44, smash_max: 1.48, aoa_min: -4.5, aoa_max: -2.5, vla_min: 12.0, vla_max: 14.5, spin_min: 4200.0, spin_max: 5000.0, carry_min: 220.0, carry_max: 235.0, rollout_min: 8.0, rollout_max: 14.0, apex_min: 90.0, apex_max: 100.0, land_angle_min: 45.0, land_angle_max: 50.0 },
    "4i":   { name: "4-Iron", club_speed_min: 94.0, club_speed_max: 99.0, ball_speed_min: 135.0, ball_speed_max: 142.0, smash_min: 1.42, smash_max: 1.46, aoa_min: -4.5, aoa_max: -2.5, vla_min: 10.5, vla_max: 13.0, spin_min: 4400.0, spin_max: 5200.0, carry_min: 202.0, carry_max: 216.0, rollout_min: 8.0, rollout_max: 14.0, apex_min: 88.0, apex_max: 98.0, land_angle_min: 45.0, land_angle_max: 49.0 },
    "5i":   { name: "5-Iron", club_speed_min: 91.0, club_speed_max: 96.0, ball_speed_min: 131.0, ball_speed_max: 137.0, smash_min: 1.41, smash_max: 1.45, aoa_min: -4.8, aoa_max: -2.8, vla_min: 11.5, vla_max: 14.0, spin_min: 4900.0, spin_max: 5700.0, carry_min: 192.0, carry_max: 205.0, rollout_min: 6.0, rollout_max: 12.0, apex_min: 90.0, apex_max: 100.0, land_angle_min: 46.0, land_angle_max: 50.0 },
    "6i":   { name: "6-Iron", club_speed_min: 89.0, club_speed_max: 94.0, ball_speed_min: 126.0, ball_speed_max: 132.0, smash_min: 1.39, smash_max: 1.43, aoa_min: -5.0, aoa_max: -3.0, vla_min: 13.0, vla_max: 15.5, spin_min: 5800.0, spin_max: 6600.0, carry_min: 182.0, carry_max: 194.0, rollout_min: 5.0, rollout_max: 10.0, apex_min: 90.0, apex_max: 100.0, land_angle_min: 48.0, land_angle_max: 52.0 },
    "7i":   { name: "7-Iron", club_speed_min: 87.0, club_speed_max: 92.0, ball_speed_min: 120.0, ball_speed_max: 126.0, smash_min: 1.36, smash_max: 1.40, aoa_min: -5.2, aoa_max: -3.2, vla_min: 15.0, vla_max: 17.5, spin_min: 6600.0, spin_max: 7500.0, carry_min: 170.0, carry_max: 182.0, rollout_min: 3.0, rollout_max: 7.0, apex_min: 92.0, apex_max: 102.0, land_angle_min: 49.0, land_angle_max: 53.0 },
    "8i":   { name: "8-Iron", club_speed_min: 84.0, club_speed_max: 89.0, ball_speed_min: 114.0, ball_speed_max: 120.0, smash_min: 1.34, smash_max: 1.38, aoa_min: -5.5, aoa_max: -3.5, vla_min: 17.0, vla_max: 19.5, spin_min: 7600.0, spin_max: 8500.0, carry_min: 158.0, carry_max: 170.0, rollout_min: 2.0, rollout_max: 5.0, apex_min: 90.0, apex_max: 100.0, land_angle_min: 50.0, land_angle_max: 54.0 },
    "9i":   { name: "9-Iron", club_speed_min: 82.0, club_speed_max: 87.0, ball_speed_min: 108.0, ball_speed_max: 114.0, smash_min: 1.30, smash_max: 1.34, aoa_min: -5.8, aoa_max: -3.8, vla_min: 19.0, vla_max: 22.0, spin_min: 8300.0, spin_max: 9200.0, carry_min: 146.0, carry_max: 158.0, rollout_min: 1.0, rollout_max: 4.0, apex_min: 88.0, apex_max: 98.0, land_angle_min: 51.0, land_angle_max: 55.0 },
    pw:     { name: "Pitching Wedge", club_speed_min: 80.0, club_speed_max: 85.0, ball_speed_min: 100.0, ball_speed_max: 106.0, smash_min: 1.23, smash_max: 1.28, aoa_min: -6.0, aoa_max: -4.0, vla_min: 22.5, vla_max: 26.0, spin_min: 8800.0, spin_max: 9800.0, carry_min: 136.0, carry_max: 146.0, rollout_min: 0.0, rollout_max: 2.0, apex_min: 88.0, apex_max: 96.0, land_angle_min: 52.0, land_angle_max: 56.0 },
    gw:     { name: "Gap Wedge", club_speed_min: 76.0, club_speed_max: 81.0, ball_speed_min: 93.0, ball_speed_max: 99.0, smash_min: 1.21, smash_max: 1.25, aoa_min: -6.2, aoa_max: -4.2, vla_min: 24.5, vla_max: 28.5, spin_min: 9100.0, spin_max: 10100.0, carry_min: 120.0, carry_max: 130.0, rollout_min: 0.0, rollout_max: 2.0, apex_min: 84.0, apex_max: 92.0, land_angle_min: 53.0, land_angle_max: 57.0 },
    sw:     { name: "Sand Wedge", club_speed_min: 71.0, club_speed_max: 76.0, ball_speed_min: 84.0, ball_speed_max: 90.0, smash_min: 1.17, smash_max: 1.21, aoa_min: -6.5, aoa_max: -4.5, vla_min: 27.5, vla_max: 31.5, spin_min: 9400.0, spin_max: 10400.0, carry_min: 102.0, carry_max: 112.0, rollout_min: 0.0, rollout_max: 1.0, apex_min: 78.0, apex_max: 86.0, land_angle_min: 54.0, land_angle_max: 58.0 },
    lw:     { name: "Lob Wedge", club_speed_min: 65.0, club_speed_max: 70.0, ball_speed_min: 73.0, ball_speed_max: 79.0, smash_min: 1.11, smash_max: 1.15, aoa_min: -6.8, aoa_max: -4.8, vla_min: 30.5, vla_max: 35.0, spin_min: 9000.0, spin_max: 10000.0, carry_min: 82.0, carry_max: 92.0, rollout_min: 0.0, rollout_max: 1.0, apex_min: 72.0, apex_max: 80.0, land_angle_min: 55.0, land_angle_max: 60.0 }
  }),
  high_handicap: withMeta({
    driver: { name: "Driver", club_speed_min: 78.0, club_speed_max: 86.0, ball_speed_min: 106.0, ball_speed_max: 120.0, smash_min: 1.34, smash_max: 1.40, aoa_min: -3.5, aoa_max: 1.0, vla_min: 13.5, vla_max: 17.0, spin_min: 2900.0, spin_max: 3800.0, carry_min: 165.0, carry_max: 192.0, rollout_min: 12.0, rollout_max: 20.0, apex_min: 60.0, apex_max: 75.0, land_angle_min: 35.0, land_angle_max: 40.0 },
    "3w":   { name: "3-Wood", club_speed_min: 74.0, club_speed_max: 81.0, ball_speed_min: 100.0, ball_speed_max: 111.0, smash_min: 1.34, smash_max: 1.39, aoa_min: -2.5, aoa_max: 1.0, vla_min: 13.0, vla_max: 16.5, spin_min: 3600.0, spin_max: 4700.0, carry_min: 150.0, carry_max: 170.0, rollout_min: 12.0, rollout_max: 18.0, apex_min: 60.0, apex_max: 74.0, land_angle_min: 38.0, land_angle_max: 43.0 },
    "5w":   { name: "5-Wood", club_speed_min: 71.0, club_speed_max: 77.0, ball_speed_min: 95.0, ball_speed_max: 105.0, smash_min: 1.33, smash_max: 1.38, aoa_min: -2.5, aoa_max: 0.5, vla_min: 14.0, vla_max: 17.5, spin_min: 4000.0, spin_max: 5100.0, carry_min: 140.0, carry_max: 158.0, rollout_min: 10.0, rollout_max: 15.0, apex_min: 60.0, apex_max: 74.0, land_angle_min: 40.0, land_angle_max: 45.0 },
    hybrid: { name: "Hybrid", club_speed_min: 68.0, club_speed_max: 74.0, ball_speed_min: 90.0, ball_speed_max: 100.0, smash_min: 1.32, smash_max: 1.37, aoa_min: -2.8, aoa_max: 0.0, vla_min: 14.5, vla_max: 18.0, spin_min: 4100.0, spin_max: 5200.0, carry_min: 132.0, carry_max: 148.0, rollout_min: 8.0, rollout_max: 13.0, apex_min: 58.0, apex_max: 72.0, land_angle_min: 41.0, land_angle_max: 46.0 },
    "4i":   { name: "4-Iron", club_speed_min: 66.0, club_speed_max: 72.0, ball_speed_min: 86.0, ball_speed_max: 95.0, smash_min: 1.30, smash_max: 1.35, aoa_min: -2.5, aoa_max: 0.0, vla_min: 14.0, vla_max: 17.0, spin_min: 4000.0, spin_max: 5000.0, carry_min: 124.0, carry_max: 138.0, rollout_min: 8.0, rollout_max: 14.0, apex_min: 56.0, apex_max: 70.0, land_angle_min: 41.0, land_angle_max: 45.0 },
    "5i":   { name: "5-Iron", club_speed_min: 64.0, club_speed_max: 69.0, ball_speed_min: 82.0, ball_speed_max: 90.0, smash_min: 1.29, smash_max: 1.34, aoa_min: -2.8, aoa_max: -0.2, vla_min: 15.0, vla_max: 18.0, spin_min: 4200.0, spin_max: 5200.0, carry_min: 116.0, carry_max: 130.0, rollout_min: 6.0, rollout_max: 12.0, apex_min: 56.0, apex_max: 70.0, land_angle_min: 42.0, land_angle_max: 46.0 },
    "6i":   { name: "6-Iron", club_speed_min: 62.0, club_speed_max: 67.0, ball_speed_min: 78.0, ball_speed_max: 86.0, smash_min: 1.28, smash_max: 1.33, aoa_min: -3.0, aoa_max: -0.5, vla_min: 16.5, vla_max: 19.5, spin_min: 4500.0, spin_max: 5600.0, carry_min: 108.0, carry_max: 121.0, rollout_min: 5.0, rollout_max: 9.0, apex_min: 56.0, apex_max: 70.0, land_angle_min: 43.0, land_angle_max: 47.0 },
    "7i":   { name: "7-Iron", club_speed_min: 59.0, club_speed_max: 65.0, ball_speed_min: 74.0, ball_speed_max: 82.0, smash_min: 1.26, smash_max: 1.31, aoa_min: -3.2, aoa_max: -0.8, vla_min: 18.5, vla_max: 22.0, spin_min: 4800.0, spin_max: 5900.0, carry_min: 98.0, carry_max: 112.0, rollout_min: 4.0, rollout_max: 8.0, apex_min: 56.0, apex_max: 68.0, land_angle_min: 44.0, land_angle_max: 48.0 },
    "8i":   { name: "8-Iron", club_speed_min: 57.0, club_speed_max: 62.0, ball_speed_min: 70.0, ball_speed_max: 77.0, smash_min: 1.24, smash_max: 1.29, aoa_min: -3.5, aoa_max: -1.0, vla_min: 20.0, vla_max: 23.5, spin_min: 5200.0, spin_max: 6300.0, carry_min: 88.0, carry_max: 101.0, rollout_min: 3.0, rollout_max: 6.0, apex_min: 54.0, apex_max: 66.0, land_angle_min: 45.0, land_angle_max: 49.0 },
    "9i":   { name: "9-Iron", club_speed_min: 54.0, club_speed_max: 59.0, ball_speed_min: 65.0, ball_speed_max: 72.0, smash_min: 1.21, smash_max: 1.26, aoa_min: -3.8, aoa_max: -1.2, vla_min: 22.0, vla_max: 26.0, spin_min: 5500.0, spin_max: 6600.0, carry_min: 78.0, carry_max: 90.0, rollout_min: 2.0, rollout_max: 5.0, apex_min: 54.0, apex_max: 66.0, land_angle_min: 46.0, land_angle_max: 50.0 },
    pw:     { name: "Pitching Wedge", club_speed_min: 52.0, club_speed_max: 57.0, ball_speed_min: 60.0, ball_speed_max: 67.0, smash_min: 1.16, smash_max: 1.21, aoa_min: -4.0, aoa_max: -1.5, vla_min: 25.0, vla_max: 29.5, spin_min: 5800.0, spin_max: 7000.0, carry_min: 68.0, carry_max: 80.0, rollout_min: 1.0, rollout_max: 3.0, apex_min: 52.0, apex_max: 64.0, land_angle_min: 47.0, land_angle_max: 51.0 },
    gw:     { name: "Gap Wedge", club_speed_min: 49.0, club_speed_max: 54.0, ball_speed_min: 55.0, ball_speed_max: 61.0, smash_min: 1.12, smash_max: 1.17, aoa_min: -4.2, aoa_max: -1.8, vla_min: 27.0, vla_max: 32.0, spin_min: 5900.0, spin_max: 7100.0, carry_min: 58.0, carry_max: 70.0, rollout_min: 1.0, rollout_max: 3.0, apex_min: 50.0, apex_max: 62.0, land_angle_min: 48.0, land_angle_max: 52.0 },
    sw:     { name: "Sand Wedge", club_speed_min: 46.0, club_speed_max: 51.0, ball_speed_min: 49.0, ball_speed_max: 55.0, smash_min: 1.08, smash_max: 1.13, aoa_min: -4.5, aoa_max: -2.0, vla_min: 30.0, vla_max: 35.0, spin_min: 6000.0, spin_max: 7200.0, carry_min: 48.0, carry_max: 60.0, rollout_min: 0.0, rollout_max: 2.0, apex_min: 48.0, apex_max: 58.0, land_angle_min: 49.0, land_angle_max: 53.0 },
    lw:     { name: "Lob Wedge", club_speed_min: 43.0, club_speed_max: 48.0, ball_speed_min: 43.0, ball_speed_max: 49.0, smash_min: 1.02, smash_max: 1.07, aoa_min: -4.5, aoa_max: -2.0, vla_min: 33.0, vla_max: 39.0, spin_min: 5600.0, spin_max: 6800.0, carry_min: 38.0, carry_max: 48.0, rollout_min: 0.0, rollout_max: 2.0, apex_min: 46.0, apex_max: 56.0, land_angle_min: 50.0, land_angle_max: 54.0 }
  })
};

/**
 * Classifies a raw club name into one of the 14 discrete benchmark keys (or "putter").
 */
export function classifyClubDiscrete(clubName) {
  const c = String(clubName || "").toLowerCase().trim();
  if (!c || c === "all") return "driver";
  if (c.includes("putt") || c === "pt") return "putter";
  if (["dr", "1w", "driver"].includes(c) || c.includes("driver")) return "driver";
  if (["3w", "3-wood", "3 wood"].includes(c)) return "3w";
  if (["5w", "5-wood", "5 wood", "4w", "7w"].includes(c) || c.includes("wood") || c.includes("fw")) return "5w";
  if (["2h", "3h", "4h", "5h", "hybrid", "rescue"].includes(c) || c.includes("hybrid")) return "hybrid";
  if (["1i", "2i", "3i", "4i", "3-iron", "4-iron", "3 iron", "4 iron"].includes(c)) return "4i";
  if (["5i", "5-iron", "5 iron"].includes(c)) return "5i";
  if (["6i", "6-iron", "6 iron"].includes(c)) return "6i";
  if (["7i", "7-iron", "7 iron"].includes(c)) return "7i";
  if (["8i", "8-iron", "8 iron"].includes(c)) return "8i";
  if (["9i", "9-iron", "9 iron"].includes(c)) return "9i";
  if (["pw", "pitching", "pitching wedge"].includes(c)) return "pw";
  if (["gw", "aw", "gap", "approach", "gap wedge", "approach wedge", "50", "52"].includes(c)) return "gw";
  if (["sw", "sand", "sand wedge", "54", "56"].includes(c)) return "sw";
  if (["lw", "lob", "lob wedge", "58", "60"].includes(c)) return "lw";
  if (c.includes("wedge")) return "pw";
  if (c.includes("iron")) return "7i";
  return "driver";
}

/**
 * Broad club category helper ("driver", "wood", "hybrid", "long_iron", "mid_iron", "wedge", "putter").
 */
export function classifyClubCategory(clubName) {
  const d = classifyClubDiscrete(clubName);
  if (d === "putter") return "putter";
  if (d === "driver") return "driver";
  if (d === "3w" || d === "5w") return "wood";
  if (d === "hybrid") return "hybrid";
  if (d === "4i" || d === "5i") return "long_iron";
  if (d === "6i" || d === "7i" || d === "8i" || d === "9i") return "mid_iron";
  return "wedge";
}

export function getClubBenchmark(clubName, skillLevel = "mid_handicap") {
  const tier = normalizeSkillLevel(skillLevel);
  const tierData = CLUB_BENCHMARKS[tier] || CLUB_BENCHMARKS.mid_handicap;
  const key = classifyClubDiscrete(clubName);
  return tierData[key] || tierData.driver;
}

/**
 * Returns a realistic lateral target corridor (± yards) scaled by club or carry distance.
 */
export function getTargetCorridorYds(clubName, avgCarryYds = 0) {
  const raw = String(clubName || "").trim().toLowerCase();
  if (!raw || raw === "all") {
    if (avgCarryYds > 0) {
      return Math.max(5, Math.min(16, Math.round(avgCarryYds * 0.065)));
    }
    return 12;
  }
  const key = classifyClubDiscrete(raw);
  return CLUB_META[key]?.corridor_yds ?? 12;
}

/**
 * Classifies a shot into the 9-cell D-Plane ball flight matrix.
 * Sign convention:
 *  - faceAngle > 0 = Open (starts Right for RH, Left for LH); < 0 = Closed
 *  - clubPath  > 0 = In-to-Out; < 0 = Out-to-In
 *  - faceToPath = faceAngle - clubPath (> 0 = Open to Path / Fade-Slice; < 0 = Closed to Path / Draw-Hook)
 */
export function classifyBallFlight(faceAngle, clubPath, faceToPath, isLefty = false) {
  const fa = faceAngle != null && Number.isFinite(faceAngle) ? faceAngle : null;
  const cp = clubPath != null && Number.isFinite(clubPath) ? clubPath : null;
  let ftp = faceToPath != null && Number.isFinite(faceToPath) ? faceToPath : null;
  if (ftp == null && fa != null && cp != null) ftp = fa - cp;

  // Approximate D-plane start direction (~80% face + 20% path)
  const startMetric = fa != null ? (cp != null ? fa * 0.8 + cp * 0.2 : fa) : 0;
  const curveMetric = ftp != null ? ftp : 0;

  let startClass = "straight";
  if (startMetric > 1.2) startClass = "push";
  else if (startMetric < -1.2) startClass = "pull";

  let curveClass = "straight";
  if (curveMetric > 1.2) curveClass = "fade";
  else if (curveMetric < -1.2) curveClass = "draw";

  let shape = "Straight";
  if (startClass === "pull" && curveClass === "draw") shape = "Pull-Hook";
  else if (startClass === "pull" && curveClass === "straight") shape = "Straight-Pull";
  else if (startClass === "pull" && curveClass === "fade") shape = "Pull-Fade";
  else if (startClass === "straight" && curveClass === "draw") shape = "Straight-Draw";
  else if (startClass === "straight" && curveClass === "straight") shape = "Straight";
  else if (startClass === "straight" && curveClass === "fade") shape = "Straight-Fade";
  else if (startClass === "push" && curveClass === "draw") shape = "Push-Draw";
  else if (startClass === "push" && curveClass === "straight") shape = "Straight-Push";
  else if (startClass === "push" && curveClass === "fade") shape = "Push-Slice";

  // Physical world left/right direction based on handedness
  let startDir = "Center";
  if (startClass === "push") startDir = isLefty ? "Left" : "Right";
  else if (startClass === "pull") startDir = isLefty ? "Right" : "Left";

  let curveDir = "Straight";
  if (curveClass === "fade") curveDir = isLefty ? "Left" : "Right";
  else if (curveClass === "draw") curveDir = isLefty ? "Right" : "Left";

  // Functional stock shot: controlled Push-Draw, Pull-Fade, or Straight with |FTP| <= 2.8°
  const absFtp = Math.abs(curveMetric);
  const absStart = Math.abs(startMetric);
  const isFunctionalStock =
    absFtp <= 2.8 &&
    absStart <= 4.0 &&
    (shape === "Straight" || shape === "Push-Draw" || shape === "Pull-Fade" ||
      (absFtp <= 2.0 && absStart <= 1.8));

  return { shape, startDir, curveDir, startClass, curveClass, isFunctionalStock };
}

/**
 * Computes a 2D covariance-rotated dispersion ellipse for [{ x, y }].
 * Uses 80% (~sqrt(3.219)) and 95% (~sqrt(5.991)) chi-square radii.
 */
export function computeCovarianceEllipse(points) {
  if (!Array.isArray(points) || points.length < 2) {
    return {
      valid: false,
      meanX: points?.[0]?.x ?? 0,
      meanY: points?.[0]?.y ?? 0,
      stdMajor: 0,
      stdMinor: 0,
      rx80: 0,
      ry80: 0,
      rx95: 0,
      ry95: 0,
      angleRad: 0,
      area80: 0
    };
  }

  const n = points.length;
  let sumX = 0;
  let sumY = 0;
  for (const p of points) {
    sumX += p.x;
    sumY += p.y;
  }
  const meanX = sumX / n;
  const meanY = sumY / n;

  let cxx = 0;
  let cyy = 0;
  let cxy = 0;
  for (const p of points) {
    const dx = p.x - meanX;
    const dy = p.y - meanY;
    cxx += dx * dx;
    cyy += dy * dy;
    cxy += dx * dy;
  }
  cxx /= n;
  cyy /= n;
  cxy /= n;

  const trace = cxx + cyy;
  const diff = Math.hypot(cxx - cyy, 2 * cxy);
  const lambda1 = Math.max(0, (trace + diff) / 2);
  const lambda2 = Math.max(0, (trace - diff) / 2);

  const stdMajor = Math.sqrt(lambda1);
  const stdMinor = Math.sqrt(lambda2);
  const angleRad =
    Math.abs(cxy) < 1e-9 && Math.abs(cxx - cyy) < 1e-9
      ? 0
      : 0.5 * Math.atan2(2 * cxy, cxx - cyy);

  const k80 = 1.7941; // sqrt(3.2189)
  const k95 = 2.4477; // sqrt(5.9915)
  const rx80 = Math.round(stdMajor * k80 * 10) / 10;
  const ry80 = Math.round(stdMinor * k80 * 10) / 10;
  const rx95 = Math.round(stdMajor * k95 * 10) / 10;
  const ry95 = Math.round(stdMinor * k95 * 10) / 10;
  const area80 = Math.round(Math.PI * rx80 * ry80 * 10) / 10;

  return {
    valid: true,
    meanX: Math.round(meanX * 10) / 10,
    meanY: Math.round(meanY * 10) / 10,
    stdMajor: Math.round(stdMajor * 10) / 10,
    stdMinor: Math.round(stdMinor * 10) / 10,
    rx80,
    ry80,
    rx95,
    ry95,
    angleRad,
    area80
  };
}

/**
 * Estimates potential carry at the player's actual clubhead speed (or ball speed)
 * and decomposes missing yards into Strike (Smash), Launch/Spin Window, and Curvature.
 */
export function computeDistanceLossBreakdown(summary, clubKey = "driver", skillLevel = "mid_handicap") {
  if (!summary || summary.avgCarry <= 0) {
    return {
      hasData: false,
      potentialCarryYds: 0,
      totalLostYds: 0,
      smashLossYds: 0,
      launchSpinLossYds: 0,
      curveLossYds: 0,
      topOpportunity: "Insufficient Data"
    };
  }

  const effectiveClub = clubKey && clubKey !== "all" ? clubKey : "driver";
  const bench = getClubBenchmark(effectiveClub, skillLevel);
  const refBench = getClubBenchmark(effectiveClub, "scratch");
  const midRefCarry = (refBench.carry_min + refBench.carry_max) * 0.5;
  const midRefBall = (refBench.ball_speed_min + refBench.ball_speed_max) * 0.5;
  const carryPerMph = midRefBall > 0 ? midRefCarry / midRefBall : 1.55;

  const optSmash = Math.max(bench.smash_max, summary.avgSmash || 0);
  const avgCarry = summary.avgCarry;

  let potentialCarry = avgCarry;
  let smashLoss = 0;

  if (summary.avgClubSpeed != null && summary.avgClubSpeed > 20) {
    const potBallSpeed = summary.avgClubSpeed * optSmash;
    potentialCarry = Math.max(avgCarry, potBallSpeed * carryPerMph);
    const actualBallSpeed =
      summary.avgBallSpeed != null && summary.avgBallSpeed > 15
        ? summary.avgBallSpeed
        : summary.avgClubSpeed * (summary.avgSmash || optSmash);
    const speedGap = Math.max(0, potBallSpeed - actualBallSpeed);
    smashLoss = speedGap * carryPerMph;
  } else if (summary.avgBallSpeed != null && summary.avgBallSpeed > 20) {
    potentialCarry = Math.max(avgCarry, summary.avgBallSpeed * carryPerMph);
  }

  // Curvature loss from excessive face-to-path / spin axis (> 2.5°)
  const absCurveDeg =
    summary.avgAbsFtp != null
      ? summary.avgAbsFtp
      : summary.avgSpinAxis != null
        ? Math.abs(summary.avgSpinAxis) / 2.2
        : 0;
  let curveLoss = absCurveDeg > 2.5 ? (absCurveDeg - 2.5) * 1.6 : 0;

  // Launch / spin penalty estimate when VLA or Spin misses club benchmark
  let launchSpinLoss = 0;
  if (summary.avgVla != null) {
    if (summary.avgVla < bench.vla_min) launchSpinLoss += (bench.vla_min - summary.avgVla) * 1.4;
    else if (summary.avgVla > bench.vla_max) launchSpinLoss += (summary.avgVla - bench.vla_max) * 1.1;
  }
  if (summary.avgSpin != null) {
    if (summary.avgSpin > bench.spin_max + 200) {
      launchSpinLoss += ((summary.avgSpin - bench.spin_max) / 500) * 3.5;
    } else if (summary.avgSpin < bench.spin_min - 300) {
      launchSpinLoss += ((bench.spin_min - summary.avgSpin) / 500) * 3.0;
    }
  }

  const totalGap = Math.max(0, potentialCarry - avgCarry);
  if (totalGap > 0) {
    smashLoss = Math.min(smashLoss, totalGap);
    const remAfterSmash = Math.max(0, totalGap - smashLoss);
    curveLoss = Math.min(curveLoss, remAfterSmash);
    launchSpinLoss = Math.max(0, remAfterSmash - curveLoss);
  } else {
    smashLoss = 0;
    curveLoss = 0;
    launchSpinLoss = 0;
  }

  const smashRounded = Math.round(smashLoss * 10) / 10;
  const launchRounded = Math.round(launchSpinLoss * 10) / 10;
  const curveRounded = Math.round(curveLoss * 10) / 10;
  const totalLost = Math.round((smashRounded + launchRounded + curveRounded) * 10) / 10;

  let topOpportunity = "Optimized Carry";
  if (totalLost >= 2.0) {
    if (smashRounded >= launchRounded && smashRounded >= curveRounded) {
      topOpportunity = "Strike Efficiency (Smash)";
    } else if (launchRounded >= curveRounded) {
      topOpportunity = "Launch & Spin Window";
    } else {
      topOpportunity = "Curvature Control";
    }
  }

  return {
    hasData: true,
    potentialCarryYds: Math.round((avgCarry + totalLost) * 10) / 10,
    totalLostYds: totalLost,
    smashLossYds: smashRounded,
    launchSpinLossYds: launchRounded,
    curveLossYds: curveRounded,
    topOpportunity
  };
}
