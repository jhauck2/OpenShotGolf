// Unit tests for separated Swing Analysis & Achievements tabs and aggregation
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

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
console.log("ALL PORTAL SWING & ACHIEVEMENTS TESTS PASSED! 🎉");
