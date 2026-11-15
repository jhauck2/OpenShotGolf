// Targeted test for Heckle Golf Player Portal Improvement Analytics Engine
import assert from "node:assert/strict";
import {
  normalizeShot,
  aggregateAllClubsShots,
  computeRollingAverage,
  computeImprovementAnalytics,
  generateOfflineTrendChartSvg,
  generateDeliveryTrendChartSvg,
  generateStrikeTrendChartSvg,
  generateCoachingInsights
} from "../web/js/analytics-engine.js";

console.log("=== Running Player Portal Analytics Tests ===");

// 1. Test Shot Normalization
{
  const rawShot1 = {
    t: 1730000000,
    CarryDistance: 200.0, // meters -> ~218.7 yards
    TotalDistance: 220.0, // meters -> ~240.6 yards
    SideDistance: -4.5,   // meters -> ~-4.9 yards (left)
    BallSpeed: 140.0,
    ClubSpeed: 95.0,
    FaceAngle: 1.5,
    ClubPath: -1.2,
    HorizontalFaceImpact: 2.0,
    VerticalFaceImpact: 3.0
  };

  const s1 = normalizeShot(rawShot1, 1);
  assert.equal(s1.index, 1);
  assert.ok(Math.abs(s1.carryYds - 218.7) < 0.2, `Expected carry ~218.7, got ${s1.carryYds}`);
  assert.ok(s1.signedOfflineYds < 0, "Expected negative signed offline (left)");
  assert.ok(Math.abs(s1.signedOfflineYds - (-4.9)) < 0.2);
  assert.ok(Math.abs(s1.absOfflineYds - 4.9) < 0.2);
  assert.equal(s1.faceAngle, 1.5);
  assert.equal(s1.clubPath, -1.2);
  assert.ok(Math.abs(s1.faceToPath - 2.7) < 0.1, `Expected FaceToPath 2.7, got ${s1.faceToPath}`);
  assert.ok(Math.abs(s1.impactOffsetMm - 3.6) < 0.2, `Expected impact offset ~3.6, got ${s1.impactOffsetMm}`);
  console.log("✓ Shot normalization passed");
}

// 2. Test Aggregating Clubs
{
  const mockClubs = {
    "Dr": [
      { t: 100, c: 220, tot: 240, sd: 5 },
      { t: 200, c: 225, tot: 245, sd: 2 }
    ],
    "7i": [
      { t: 150, c: 140, tot: 145, sd: -1 }
    ]
  };

  const agg = aggregateAllClubsShots(mockClubs);
  assert.equal(agg.length, 3);
  assert.equal(agg[0].t, 100);
  assert.equal(agg[1].t, 150);
  assert.equal(agg[2].t, 200);
  assert.equal(agg[0].index, 1);
  assert.equal(agg[2].index, 3);
  console.log("✓ All clubs aggregation passed");
}

// 3. Test Rolling Average
{
  const values = [10, 20, 30, 40, 50];
  const rolling = computeRollingAverage(values, 3);
  assert.equal(rolling.length, 5);
  // index 2: avg of [20, 30, 40] = 30
  assert.equal(rolling[2], 30);
  console.log("✓ Rolling average calculation passed");
}

// 4. Test Offline Nearing Zero Trend (Player Improving)
{
  // Baseline shots: offline ~ 15 yds
  // Recent shots: offline ~ 3 yds (nearing zero!)
  const mockShots = [
    { t: 1, c: 200, tot: 210, sd: 14, fa: 3.5, cp: -2.5, cs: 90, bs: 130 },
    { t: 2, c: 200, tot: 210, sd: -13, fa: -3.0, cp: 2.0, cs: 90, bs: 130 },
    { t: 3, c: 200, tot: 210, sd: 12, fa: 2.8, cp: -2.0, cs: 90, bs: 130 },
    { t: 4, c: 200, tot: 210, sd: -15, fa: -3.2, cp: 2.2, cs: 90, bs: 130 },
    // Recent shots: much closer to 0
    { t: 5, c: 200, tot: 210, sd: 2, fa: 0.5, cp: -0.3, cs: 90, bs: 135 },
    { t: 6, c: 200, tot: 210, sd: -1, fa: -0.2, cp: 0.2, cs: 90, bs: 135 },
    { t: 7, c: 200, tot: 210, sd: 1.5, fa: 0.3, cp: -0.2, cs: 90, bs: 136 },
    { t: 8, c: 200, tot: 210, sd: -0.5, fa: 0.0, cp: 0.1, cs: 90, bs: 136 }
  ].map((raw, idx) => normalizeShot(raw, idx + 1));

  const analytics = computeImprovementAnalytics(mockShots, "all");
  assert.equal(analytics.hasData, true);
  assert.equal(analytics.totalShots, 8);
  assert.equal(analytics.offline.status, "improving", "Offline should be marked improving");
  assert.ok(analytics.offline.delta < 0, "Offline delta should be negative (nearing 0)");
  assert.equal(analytics.face.status, "improving", "Face angle should be marked improving (squaring up to 0°)");
  assert.ok(analytics.face.delta < 0, "Face angle delta should be negative (closer to 0°)");
  assert.equal(analytics.path.status, "improving", "Club path should be marked improving (straightening to 0°)");
  assert.ok(analytics.path.delta < 0, "Club path delta should be negative (closer to 0°)");

  console.log("✓ Offline nearing zero & delivery straightening tests passed");
  console.log(`  - Offline delta: ${analytics.offline.delta} yds (${analytics.offline.text})`);
  console.log(`  - Face delta: ${analytics.face.delta}° (${analytics.face.text})`);
  console.log(`  - Path delta: ${analytics.path.delta}° (${analytics.path.text})`);
}

// 5. Test Offline Drifting Away Trend (Player Expanding)
{
  const mockShots = [
    // Baseline shots: tight to center
    { t: 1, c: 200, tot: 210, sd: 1, fa: 0.2, cp: 0.1 },
    { t: 2, c: 200, tot: 210, sd: -1, fa: -0.2, cp: -0.1 },
    // Recent shots: spraying offline
    { t: 3, c: 200, tot: 210, sd: 18, fa: 4.5, cp: -3.5 },
    { t: 4, c: 200, tot: 210, sd: -20, fa: -5.0, cp: 4.0 }
  ].map((raw, idx) => normalizeShot(raw, idx + 1));

  const analytics = computeImprovementAnalytics(mockShots, "all");
  assert.equal(analytics.offline.status, "expanding");
  assert.ok(analytics.offline.delta > 0);
  assert.equal(analytics.face.status, "expanding");
  assert.equal(analytics.path.status, "expanding");
  console.log("✓ Expanding offline & diverging delivery tests passed");
}

// 6. Test SVG Chart Generators
{
  const mockShots = [
    { t: 1, c: 200, tot: 210, sd: 4, fa: 1.5, cp: -1.0, bs: 140, cs: 95, hi: 1, vi: 1 },
    { t: 2, c: 205, tot: 215, sd: -2, fa: -0.5, cp: 0.5, bs: 142, cs: 96, hi: 0, vi: 0 }
  ].map((raw, idx) => normalizeShot(raw, idx + 1));

  const offlineSvg = generateOfflineTrendChartSvg(mockShots);
  assert.ok(offlineSvg.includes("<svg"), "Must contain <svg");
  assert.ok(offlineSvg.includes("Target Corridor"), "Must contain Target Corridor");

  const deliverySvg = generateDeliveryTrendChartSvg(mockShots);
  assert.ok(deliverySvg.includes("<svg"), "Must contain <svg");
  assert.ok(deliverySvg.includes("Square"), "Must contain Square reference");

  const strikeSvg = generateStrikeTrendChartSvg(mockShots);
  assert.ok(strikeSvg.includes("<svg"), "Must contain <svg");
  assert.ok(strikeSvg.includes("Smash Factor"), "Must contain Smash Factor");

  console.log("✓ SVG chart generators passed");
}

// 7. Test AI Coaching Insights
{
  const mockShots = [
    { t: 1, c: 200, tot: 210, sd: 12, fa: 3.0, cp: -2.0, cs: 90, bs: 125 },
    { t: 2, c: 200, tot: 210, sd: 14, fa: 3.2, cp: -2.2, cs: 90, bs: 126 },
    { t: 3, c: 210, tot: 220, sd: 1.5, fa: 0.2, cp: 0.1, cs: 92, bs: 135 },
    { t: 4, c: 212, tot: 222, sd: 1.0, fa: 0.1, cp: -0.1, cs: 92, bs: 136 }
  ].map((raw, idx) => normalizeShot(raw, idx + 1));

  const analytics = computeImprovementAnalytics(mockShots, "all");
  const insights = generateCoachingInsights(analytics);
  assert.ok(Array.isArray(insights) && insights.length >= 2, "Should return multiple insights");
  assert.ok(insights.some(i => i.title.toLowerCase().includes("dispersion") || i.title.toLowerCase().includes("centerline")));
  assert.ok(insights.some(i => i.title.toLowerCase().includes("face") || i.title.toLowerCase().includes("squaring")));

  console.log("✓ Coaching insights generation passed");
}

console.log("\nALL ANALYTICS TESTS PASSED SUCCESSFULLY! 🎉");
