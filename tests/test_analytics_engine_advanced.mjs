import assert from "node:assert/strict";
import {
  normalizeSkillLevel,
  classifyClubDiscrete,
  classifyClubCategory,
  getClubBenchmark,
  getTargetCorridorYds,
  classifyBallFlight,
  computeCovarianceEllipse,
  computeDistanceLossBreakdown,
} from "../web/js/golf-benchmarks.js";
import {
  normalizeShot,
  computeImprovementAnalytics,
  generateBulletGaugeHtml,
  generateOfflineTrendChartSvg,
  generateDeliveryTrendChartSvg,
  generateStrikeTrendChartSvg,
  generateDPlaneMatrixSvg,
  generateLaunchOptimizerSvg,
  generateDispersionTargetSvg,
  generateBagGappingChartSvg,
  generateSessionTrendChartSvg,
  generateCoachingInsights,
} from "../web/js/analytics-engine.js";
import {
  getSwingIssueDetails,
  getDrillsForAnalyticsIssue,
} from "../web/js/swing-drills.js";

console.log("=== Running Advanced Analytics Engine & Coaching Tests ===");

// 1. Skill Normalization & 9i Classification
assert.equal(normalizeSkillLevel("beginner"), "high_handicap");
assert.equal(normalizeSkillLevel("low_handicap"), "scratch");
assert.equal(normalizeSkillLevel("tour_pro"), "tour_pro");
assert.equal(classifyClubDiscrete("9 Iron"), "9i");
assert.equal(classifyClubCategory("9i"), "mid_iron");
assert.equal(classifyClubCategory("9-Iron"), "mid_iron");
const scratch7i = getClubBenchmark("7i", "low_handicap");
assert.ok(scratch7i.spin_min >= 6000 && scratch7i.smash_min >= 1.32);
assert.equal(getTargetCorridorYds("Driver", 250), 15);
assert.equal(getTargetCorridorYds("7i", 160), 8);
assert.equal(getTargetCorridorYds("Pw", 120), 6);
console.log("  PASS: Benchmarks, skill normalization, and 9i -> mid_iron verified.");

// 2. D-Plane 9-Flight RH vs LH & Functional Stock Guard
const rhPushDraw = classifyBallFlight(2.0, 4.0, -2.0, false);
assert.equal(rhPushDraw.shape, "Push-Draw");
assert.equal(rhPushDraw.startDir, "Right");
assert.equal(rhPushDraw.curveDir, "Left");
assert.equal(rhPushDraw.isFunctionalStock, true);

const lhPushDraw = classifyBallFlight(2.0, 4.0, -2.0, true);
assert.equal(lhPushDraw.shape, "Push-Draw");
assert.equal(lhPushDraw.startDir, "Left");
assert.equal(lhPushDraw.curveDir, "Right");
assert.equal(lhPushDraw.isFunctionalStock, true);

const pullHook = classifyBallFlight(-4.5, 0.5, -5.0, false);
assert.equal(pullHook.shape, "Pull-Hook");
assert.equal(pullHook.isFunctionalStock, false);
console.log("  PASS: D-Plane 9-flight RH/LH & functional stock guard verified.");

// 3. Covariance Ellipse & Distance Loss Breakdown
const ell = computeCovarianceEllipse([
  { x: 240, y: -6 },
  { x: 250, y: 0 },
  { x: 260, y: 6 },
  { x: 248, y: -2 },
  { x: 252, y: 2 },
]);
assert.equal(ell.valid, true);
assert.ok(ell.rx80 > ell.ry80 && ell.area80 > 0);

const distLoss = computeDistanceLossBreakdown(
  {
    avgCarry: 215,
    avgClubSpeed: 100,
    avgSmash: 1.35,
    avgSpin: 3600,
    avgAbsSpinAxis: 10.0,
  },
  "Driver",
  "mid_handicap"
);
assert.equal(distLoss.hasData, true);
assert.ok(distLoss.totalLostYds > 5 && distLoss.smashLossYds > 0);
console.log("  PASS: Covariance ellipse & missing-yards distance loss verified.");

// 4. Session Grouping, Fatigue Drift & Active Focus Milestone Ladder
const baseTs = 1760000000;
const fatigueShots = [];
for (let i = 0; i < 10; i++) {
  fatigueShots.push(
    normalizeShot({
      club: "Driver",
      t: baseTs - 86400 + i * 60,
      carry_yds: 252,
      offline_yds: i % 2 === 0 ? 3 : -3,
      smash: 1.46,
      fa: 0.5,
      cp: 0.2,
      vla: 13.0,
      spin: 2350,
    }, i)
  );
}
for (let i = 0; i < 20; i++) {
  const late = i >= 10;
  fatigueShots.push(
    normalizeShot({
      club: "Driver",
      t: baseTs + i * 60,
      carry_yds: late ? 236 : 254,
      offline_yds: late ? 18 : 2,
      smash: late ? 1.37 : 1.46,
      fa: late ? 3.5 : 0.4,
      cp: late ? -2.0 : 0.4,
      hi: late ? -9 : 0,
      vi: late ? -8 : 1,
      vla: 12.0,
      spin: late ? 3400 : 2300,
    }, 10 + i)
  );
}
const analytics = computeImprovementAnalytics(fatigueShots, "sessions", {
  clubKey: "Driver",
  skillLevel: "mid_handicap",
});
assert.equal(analytics.hasData, true);
assert.equal(analytics.sessions.length, 2);
assert.equal(analytics.fatigue?.isFatigued, true);
assert.ok(analytics.activeFocus && Array.isArray(analytics.activeFocus.milestones) && analytics.activeFocus.milestones.length === 3);
console.log("  PASS: Session grouping, fatigue detection & 3-step Active Focus ladder verified.");

// 5. Gear Effect Insights & SVG Visual Generators
const toeHookShots = Array.from({ length: 6 }, (_, i) => normalizeShot({
  club: "Driver",
  t: baseTs + i * 30,
  carry_yds: 238,
  offline_yds: -15,
  smash: 1.41,
  fa: 0.2,
  cp: 0.5,
  ftp: -0.3,
  SpinAxis: -8.5,
  hi: 12.0,
  vi: 0.0,
  vla: 12.5,
  spin_rpm: 2100,
}, i));
const gearAnalytics = computeImprovementAnalytics(toeHookShots, "all", { clubKey: "Driver", skillLevel: "mid_handicap" });
const gearInsights = generateCoachingInsights(gearAnalytics);
assert.ok(gearInsights.some((ins) => ins.issueKey === "toe_gear_hook"), "Must detect Toe Gear-Effect Hook when FTP is neutral and Hi >= 6mm");

assert.ok(generateBulletGaugeHtml(1.41, 1.42, 1.48, 1.25, 1.52, 1.38, "").includes("bullet-gauge"));
assert.ok(generateOfflineTrendChartSvg(gearAnalytics.shots).includes("<svg"));
assert.ok(generateDeliveryTrendChartSvg(gearAnalytics.shots).includes("<svg"));
assert.ok(generateStrikeTrendChartSvg(gearAnalytics.shots).includes("<svg"));
assert.ok(generateDPlaneMatrixSvg(gearAnalytics.shots).includes("PUSH-DRAW"));
assert.ok(generateLaunchOptimizerSvg(gearAnalytics.shots, { clubKey: "Driver" }).includes("<svg"));
assert.ok(generateDispersionTargetSvg(gearAnalytics.shots, { clubKey: "Driver" }).includes("<svg"));
assert.ok(generateSessionTrendChartSvg(analytics.sessions).includes("<svg"));
assert.ok(generateBagGappingChartSvg({ Dr: { carry_yds: 245, total_yds: 268, count: 8 }, "7i": { carry_yds: 155, total_yds: 162, count: 10 } }).includes("<svg"));
console.log("  PASS: Gear-effect insights, bullet gauge HTML & all SVG visual generators verified.");

// 6. 3-Stage Drills Enrichment & New Issues
for (const key of ["toe_gear_hook", "heel_gear_slice", "low_face_spin", "high_spin_loft", "low_descent_angle", "fatigue_drift", "two_way_miss"]) {
  const details = getSwingIssueDetails(key);
  assert.ok(details && details.issueType, `Issue ${key} must resolve`);
  const drillInfo = getDrillsForAnalyticsIssue(key);
  assert.ok(drillInfo && Array.isArray(drillInfo.drills) && drillInfo.drills.length >= 1, `Drills for ${key} must exist`);
  assert.ok(Array.isArray(drillInfo.drills[0].stages) && drillInfo.drills[0].stages.length === 3, `Drill for ${key} must include 3 stages`);
  assert.ok(drillInfo.drills[0].monitorProof && drillInfo.drills[0].watchOutFor && drillInfo.drills[0].graduation);
}
console.log("  PASS: 3-stage drill enrichment, monitorProof, watchOutFor & graduation verified.");
console.log("=== ALL ADVANCED PORTAL ANALYTICS TESTS PASSED! ===");
