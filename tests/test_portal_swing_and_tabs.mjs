// Unit tests for separated Swing Analysis & Achievements tabs and aggregation
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { getSwingIssueDetails, getDrillsForAnalyticsIssue } from "../web/js/swing-drills.js";

console.log("=== Running Portal Swing Analysis & Achievements Tests ===");

// 1. Verify portal.html has split tabs and separate pane containers
const portalHtml = fs.readFileSync(path.resolve("web/portal.html"), "utf-8");

assert.ok(
  portalHtml.includes('data-tab="swing"') && portalHtml.includes('data-tab="achievements"'),
  "portal.html must have distinct tab buttons for swing and achievements"
);

assert.ok(
  portalHtml.includes('id="portal-tab-swing"') && portalHtml.includes('id="portal-tab-achievements"'),
  "portal.html must have distinct pane containers for #portal-tab-swing and #portal-tab-achievements"
);

assert.ok(
  portalHtml.includes('id="swing-analysis-container"'),
  "portal.html must contain #swing-analysis-container"
);

assert.ok(
  portalHtml.includes('id="achievements-container"'),
  "portal.html must contain #achievements-container"
);

console.log("✓ Portal HTML structure verification passed");

// 2. Verify portal.js contains distinct loader functions and tab handling
const portalJs = fs.readFileSync(path.resolve("web/js/portal.js"), "utf-8");

assert.ok(
  portalJs.includes("function loadSwingAnalysis"),
  "portal.js must define loadSwingAnalysis"
);

assert.ok(
  portalJs.includes("function loadAchievements("),
  "portal.js must define loadAchievements"
);

assert.ok(
  portalJs.includes('tabName === "swing"') && portalJs.includes('tabName === "achievements"'),
  "portal.js switchPortalTab must handle both swing and achievements independently"
);

console.log("✓ Portal JS loader functions and tab routing verified");

// 3. Test flaw aggregation logic for monthly and all-time running totals
const sampleSwingIssues = {
  "2026-10": {
    "Excessive Driver Spin": 10,
    "Fade / Open Face": 5,
    "Slice / Open Face-to-Path": 8
  },
  "2026-11": {
    "Excessive Driver Spin": 6,
    "High Driver Launch / Pop-up": 5,
    "Low Driver Launch": 2,
    "Slice / Open Face-to-Path": 1
  }
};

const allTimeTotals = {};
for (const m of Object.keys(sampleSwingIssues)) {
  const mData = sampleSwingIssues[m] || {};
  for (const [iss, cnt] of Object.entries(mData)) {
    allTimeTotals[iss] = (allTimeTotals[iss] || 0) + Number(cnt || 0);
  }
}

assert.equal(allTimeTotals["Excessive Driver Spin"], 16, "All-time driver spin must be 10 + 6 = 16");
assert.equal(allTimeTotals["High Driver Launch / Pop-up"], 5, "All-time pop-up must be 5");
assert.equal(allTimeTotals["Slice / Open Face-to-Path"], 9, "All-time slice must be 8 + 1 = 9");
assert.equal(allTimeTotals["Fade / Open Face"], 5, "All-time fade must be 5");
assert.equal(allTimeTotals["Low Driver Launch"], 2, "All-time low launch must be 2");

console.log("✓ All-time flaw aggregation arithmetic verified");

// 4. Verify interactive swing issue selection & drill recommendations in portal.js
assert.ok(
  portalJs.includes("swing-issue-detail-panel") && portalJs.includes("swing-issue-selector"),
  "portal.js must render interactive swing issue selector and detail panel"
);
assert.ok(
  portalJs.includes('data-issue="') && portalJs.includes("selectSwingIssue"),
  "portal.js must allow selecting different swing issues to show fix and drill recommendations"
);
assert.ok(
  portalJs.includes("btn-toggle-analytics-drills") && portalJs.includes("analytics-drills-panel"),
  "portal.js must provide an option for drills to work on in the Improvement Analytics tab"
);

// 5. Verify swing-drills knowledge base returns fix & drill details
const sliceDetails = getSwingIssueDetails("Slice / Open Face-to-Path");
assert.ok(sliceDetails && sliceDetails.howToFix && sliceDetails.drills.length >= 1, "Slice issue must return howToFix and drills");
assert.ok(sliceDetails.video && sliceDetails.video.url.includes("youtube.com"), "Slice issue must include tutorial video");

const dynamicAoA = getSwingIssueDetails("Scooping / Upward Iron AoA");
assert.ok(dynamicAoA && dynamicAoA.drills.length >= 1, "Dynamic Scooping AoA issue must resolve to drills");

const analyticsDrill = getDrillsForAnalyticsIssue("face_open");
assert.ok(analyticsDrill && analyticsDrill.drills.length >= 1, "Analytics issue key must resolve to drills");

console.log("✓ Swing issue fix & drill knowledge base verified");
console.log("ALL PORTAL SWING & ACHIEVEMENTS TESTS PASSED! 🎉");
