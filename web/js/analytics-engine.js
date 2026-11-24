// Heckle Golf Simulator - Player Portal Improvement Analytics Engine
// Computes trend analysis, D-plane ball flight, covariance ellipses, distance-loss breakdown,
// club-calibrated benchmarks, incremental micro-milestone coaching, and rich SVG charts.

import {
  normalizeSkillLevel,
  classifyClubDiscrete,
  classifyClubCategory,
  getClubBenchmark,
  getTargetCorridorYds,
  classifyBallFlight,
  computeCovarianceEllipse,
  computeDistanceLossBreakdown
} from "./golf-benchmarks.js";

const round1 = (v) => Math.round(v * 10) / 10;
const round2 = (v) => Math.round(v * 100) / 100;

function readNullableNumber(raw, keys) {
  for (const k of keys) {
    if (raw[k] != null && raw[k] !== "" && raw[k] !== "---" && raw[k] !== "N/A") {
      const n = Number(raw[k]);
      if (Number.isFinite(n)) return n;
    }
  }
  return null;
}

/**
 * Normalizes a raw shot object from Firestore sync/stats into consistent telemetry units.
 * Distances converted to yards, apex in feet, impact offsets in mm, angles in degrees.
 */
export function normalizeShot(raw, index = 0) {
  if (!raw || typeof raw !== "object") return null;

  const t = Number(raw.t ?? raw.timestamp ?? raw.created_at ?? index);
  const id = String(raw.id ?? `shot_${index}`);
  const club = String(raw.club ?? raw.Club ?? raw.c_name ?? "").trim();

  // Distances: stored in meters in Firestore sync/stats; convert to yards (* 1.09361)
  const carryRaw = Number(raw.CarryDistance ?? raw.c ?? raw.carry_yds ?? raw.carry_m ?? 0);
  const carryYds = raw.carry_yds != null ? Number(raw.carry_yds) : carryRaw * 1.09361;

  const totalRaw = Number(raw.TotalDistance ?? raw.tot ?? raw.total_yds ?? raw.total_m ?? carryRaw);
  const totalYds = raw.total_yds != null ? Number(raw.total_yds) : totalRaw * 1.09361;

  const rolloutRaw = readNullableNumber(raw, ["Rollout", "rollout"]);
  const rolloutYds = raw.rollout_yds != null
    ? Number(raw.rollout_yds)
    : (rolloutRaw != null ? rolloutRaw * 1.09361 : Math.max(0, totalYds - carryYds));

  // Offline / Side Distance: meters -> yards (Negative = Left, Positive = Right in world coords)
  const sideRaw = Number(raw.SideDistance ?? raw.Offline ?? raw.sd ?? 0);
  const signedOfflineYds = raw.offline_yds != null ? Number(raw.offline_yds) : sideRaw * 1.09361;
  const absOfflineYds = Math.abs(signedOfflineYds);

  // Speed telemetry
  const ballSpeed = Number(raw.BallSpeed ?? raw.Speed ?? raw.bs ?? raw.ball_speed_mph ?? 0);
  const clubSpeed = Number(raw.ClubSpeed ?? raw.cs ?? raw.club_speed_mph ?? 0);

  let smash = Number(raw.SmashFactor ?? raw.sf ?? raw.smash ?? 0);
  if (smash <= 0.05 && clubSpeed > 5 && ballSpeed > 5) {
    smash = ballSpeed / clubSpeed;
  }

  // Delivery angles
  const faceAngle = readNullableNumber(raw, ["FaceAngle", "ClubFaceAngle", "fa"]);
  const clubPath = readNullableNumber(raw, ["ClubPath", "Path", "cp"]);
  let faceToPath = readNullableNumber(raw, ["FaceToPath", "ftp"]);
  if (faceToPath == null && faceAngle != null && clubPath != null) {
    faceToPath = faceAngle - clubPath;
  }

  const attackAngle = readNullableNumber(raw, ["AttackAngle", "AngleOfAttack", "aoa", "attack_angle"]);
  const dynamicLoft = readNullableNumber(raw, ["DynamicLoft", "dynamic_loft"]);
  const spinLoft = (dynamicLoft != null && attackAngle != null)
    ? round1(dynamicLoft - attackAngle)
    : null;

  // Launch angles & spin
  const vla = readNullableNumber(raw, ["VLA", "LaunchAngle", "VerticalLaunchAngle", "vla"]);
  const hla = readNullableNumber(raw, ["HLA", "HorizontalLaunchAngle", "hla"]);
  const totalSpin = Number(raw.TotalSpin ?? raw.sp ?? raw.spin_rpm ?? 0);
  const backSpin = readNullableNumber(raw, ["BackSpin", "back_spin"]);
  const sideSpin = readNullableNumber(raw, ["SideSpin", "side_spin"]);
  let spinAxis = readNullableNumber(raw, ["SpinAxis", "spin_axis", "SideSpinAxis"]);
  if (spinAxis == null && backSpin != null && backSpin > 0 && sideSpin != null) {
    spinAxis = (Math.atan2(sideSpin, backSpin) * 180) / Math.PI;
  }

  // Trajectory
  let apexFt = readNullableNumber(raw, ["apex_ft"]);
  if (apexFt == null) {
    const apexM = readNullableNumber(raw, ["Apex", "apex", "PeakHeight", "MaxHeight"]);
    if (apexM != null && apexM > 0) apexFt = apexM * 3.28084;
  }
  const descentAngle = readNullableNumber(raw, ["DescentAngle", "descent_angle", "landing_angle", "LandAngle"]);
  const hangTime = readNullableNumber(raw, ["HangTime", "hang_time", "flight_time"]);

  // Impact location (mm from center face: + = Toe / High, - = Heel / Low)
  const hi = readNullableNumber(raw, ["HorizontalFaceImpact", "hi", "impact_offset_horizontal"]);
  const vi = readNullableNumber(raw, ["VerticalFaceImpact", "vi", "impact_offset_vertical"]);
  const impactOffsetMm = (hi != null && vi != null) ? Math.hypot(hi, vi) : null;

  return {
    id,
    t,
    index,
    club,
    carryYds: round1(carryYds),
    totalYds: round1(totalYds),
    rolloutYds: round1(Math.max(0, rolloutYds)),
    signedOfflineYds: round1(signedOfflineYds),
    absOfflineYds: round1(absOfflineYds),
    ballSpeed: ballSpeed > 0 ? round1(ballSpeed) : null,
    clubSpeed: clubSpeed > 0 ? round1(clubSpeed) : null,
    smash: smash > 0.1 ? round2(smash) : null,
    faceAngle: faceAngle != null ? round1(faceAngle) : null,
    clubPath: clubPath != null ? round1(clubPath) : null,
    faceToPath: faceToPath != null ? round1(faceToPath) : null,
    attackAngle: attackAngle != null ? round1(attackAngle) : null,
    dynamicLoft: dynamicLoft != null ? round1(dynamicLoft) : null,
    spinLoft,
    vla: vla != null ? round1(vla) : null,
    hla: hla != null ? round1(hla) : null,
    totalSpin: totalSpin > 0 ? Math.round(totalSpin) : null,
    backSpin: backSpin != null && backSpin > 0 ? Math.round(backSpin) : null,
    sideSpin: sideSpin != null ? Math.round(sideSpin) : null,
    spinAxis: spinAxis != null ? round1(spinAxis) : null,
    apexFt: apexFt != null && apexFt > 0 ? round1(apexFt) : null,
    descentAngle: descentAngle != null && descentAngle > 0 ? round1(descentAngle) : null,
    hangTime: hangTime != null && hangTime > 0 ? round2(hangTime) : null,
    hi: hi != null ? round1(hi) : null,
    vi: vi != null ? round1(vi) : null,
    impactOffsetMm: impactOffsetMm != null ? round1(impactOffsetMm) : null
  };
}

/**
 * Aggregates all shots across all clubs in syncStats.clubs.
 */
export function aggregateAllClubsShots(clubsDict) {
  if (!clubsDict || typeof clubsDict !== "object") return [];
  const allShots = [];

  for (const [clubKey, rawArray] of Object.entries(clubsDict)) {
    if (!Array.isArray(rawArray)) continue;
    rawArray.forEach((raw, idx) => {
      const s = normalizeShot({ ...raw, club: raw.club || clubKey }, idx);
      if (s) allShots.push(s);
    });
  }

  allShots.sort((a, b) => a.t - b.t);
  allShots.forEach((s, idx) => { s.index = idx + 1; });
  return allShots;
}

/**
 * Extracts normalized shots for a single club.
 */
export function getClubShots(clubsDict, clubKey) {
  if (!clubsDict || !clubKey) return [];
  const targetKey = Object.keys(clubsDict).find(k => k.toLowerCase() === clubKey.toLowerCase());
  if (!targetKey) return [];
  const rawArray = clubsDict[targetKey];
  if (!Array.isArray(rawArray)) return [];

  const shots = rawArray.map((raw, idx) => normalizeShot({ ...raw, club: clubKey }, idx)).filter(Boolean);
  shots.sort((a, b) => a.t - b.t);
  shots.forEach((s, idx) => { s.index = idx + 1; });
  return shots;
}

/**
 * Computes trailing moving average for a numeric array so trendlines match chronological learning.
 */
export function computeRollingAverage(arr, windowSize = 5) {
  if (!arr || arr.length === 0) return [];
  const w = Math.max(1, windowSize);
  const result = [];
  for (let i = 0; i < arr.length; i++) {
    const start = Math.max(0, i - w + 1);
    const slice = arr.slice(start, i + 1).filter(v => v != null && !isNaN(v));
    if (slice.length === 0) {
      result.push(null);
    } else {
      const sum = slice.reduce((acc, v) => acc + v, 0);
      result.push(round1(sum / slice.length));
    }
  }
  return result;
}

function calcStdDev(values, mean) {
  if (!values || values.length < 2) return 0;
  const variance = values.reduce((acc, v) => acc + (v - mean) ** 2, 0) / values.length;
  return round1(Math.sqrt(variance));
}

/**
 * Clusters chronologically sorted shots into distinct practice/round sessions.
 * Gaps > gapSeconds (default 45 min = 2700s) start a new session when real unix timestamps exist.
 */
export function groupShotsIntoSessions(shots, gapSeconds = 2700, options = {}) {
  if (!Array.isArray(shots) || shots.length === 0) {
    return { sessions: [], fatigue: null };
  }

  const buckets = [];
  let current = [shots[0]];

  for (let i = 1; i < shots.length; i++) {
    const prev = shots[i - 1];
    const curr = shots[i];
    const hasUnixTs = curr.t >= 1_000_000_000 && prev.t >= 1_000_000_000;
    if (hasUnixTs && (curr.t - prev.t) > gapSeconds) {
      buckets.push(current);
      current = [curr];
    } else {
      current.push(curr);
    }
  }
  buckets.push(current);

  const sessions = buckets.map((bucket, idx) => {
    const startTs = bucket[0].t;
    const endTs = bucket[bucket.length - 1].t;
    const hasDate = startTs >= 1_000_000_000;
    const dateLabel = hasDate
      ? new Date(startTs * 1000).toLocaleDateString(undefined, { month: "short", day: "numeric" })
      : `Block ${idx + 1}`;
    const summary = summarizeShotGroup(bucket, options);
    return {
      sessionIndex: idx + 1,
      label: dateLabel,
      startTs,
      endTs,
      shotCount: bucket.length,
      shots: bucket,
      summary
    };
  });

  // In-session fatigue detection on latest session when >= 20 shots
  let fatigue = null;
  const latest = sessions[sessions.length - 1];
  if (latest && latest.shots.length >= 20) {
    const early = summarizeShotGroup(latest.shots.slice(0, 10), options);
    const late = summarizeShotGroup(latest.shots.slice(-10), options);
    const offlineDrift = round1(late.avgAbsOffline - early.avgAbsOffline);
    const smashDrift = (late.avgSmash != null && early.avgSmash != null)
      ? round2(late.avgSmash - early.avgSmash) : null;
    const carryDrift = round1(late.avgCarry - early.avgCarry);
    const isFatigued = offlineDrift >= 2.5 || (smashDrift != null && smashDrift <= -0.03) || carryDrift <= -6.0;
    fatigue = {
      sessionLabel: latest.label,
      shotCount: latest.shots.length,
      offlineDrift,
      smashDrift,
      carryDrift,
      isFatigued
    };
  }

  return { sessions, fatigue };
}

/**
 * Calculates comprehensive summary metrics for a list of shots.
 */
export function summarizeShotGroup(shots, options = {}) {
  const clubKey = options.clubKey || "all";
  const skillLevel = normalizeSkillLevel(options.skillLevel);
  const isLefty = Boolean(options.isLefty);

  if (!shots || shots.length === 0) {
    const defaultCorridor = getTargetCorridorYds(clubKey, 0);
    return {
      count: 0,
      corridorYds: defaultCorridor,
      avgAbsOffline: 0,
      avgSignedOffline: 0,
      stdDevOffline: 0,
      pctInFairway: 0,
      pctLeft: 0,
      pctRight: 0,
      avgAbsFace: null,
      avgSignedFace: null,
      stdDevFace: null,
      faceCount: 0,
      avgAbsPath: null,
      avgSignedPath: null,
      stdDevPath: null,
      pathCount: 0,
      avgAbsFtp: null,
      avgSignedFtp: null,
      stdDevFtp: null,
      ftpCount: 0,
      avgSmash: null,
      smashCount: 0,
      avgCarry: 0,
      avgTotalYds: 0,
      avgRollYds: 0,
      maxCarryYds: 0,
      minCarryYds: 0,
      stdDevCarry: 0,
      carryConsistencyPct: null,
      avgBallSpeed: null,
      avgClubSpeed: null,
      avgVla: null,
      vlaCount: 0,
      avgHla: null,
      hlaCount: 0,
      avgAoa: null,
      aoaCount: 0,
      avgDynamicLoft: null,
      dynamicLoftCount: 0,
      avgSpinLoft: null,
      spinLoftCount: 0,
      avgSpin: null,
      spinCount: 0,
      avgBackSpin: null,
      avgSideSpin: null,
      avgSpinAxis: null,
      spinAxisCount: 0,
      avgApexFt: null,
      apexCount: 0,
      avgDescentAngle: null,
      descentCount: 0,
      avgHangTime: null,
      avgHi: null,
      avgVi: null,
      hiViCount: 0,
      avgImpactOffsetMm: null,
      impactCount: 0,
      ballFlight: { counts: {}, pcts: {}, totalClassified: 0, dominantShape: null, dominantPct: 0, pctFunctionalStock: 0 },
      missAttribution: { startPct: 50, curvePct: 50, missPattern: "centered_consistent", hasData: false },
      aimShift: { shiftYds: 0, shiftDir: "On Target", projectedPctInFairway: 0, gainPct: 0 },
      dispersionEllipse: { valid: false, meanX: 0, meanY: 0, rx80: 0, ry80: 0, rx95: 0, ry95: 0, angleRad: 0, area80: 0 },
      strikeQuadrants: null,
      stoppingPower: null
    };
  }

  const n = shots.length;
  const carryList = [];
  let carrySum = 0;
  shots.forEach((s) => {
    if (s.carryYds > 0) {
      carrySum += s.carryYds;
      carryList.push(s.carryYds);
    }
  });
  const prelimAvgCarry = carryList.length > 0 ? carrySum / carryList.length : 0;
  const corridorYds = getTargetCorridorYds(clubKey, prelimAvgCarry);

  let absOfflineSum = 0, signedOfflineSum = 0;
  let inFairwayCount = 0, leftMissCount = 0, rightMissCount = 0;
  const signedOfflines = [];

  const faceVals = [], pathVals = [], ftpVals = [];
  let absFaceSum = 0, signedFaceSum = 0, faceCount = 0;
  let absPathSum = 0, signedPathSum = 0, pathCount = 0;
  let absFtpSum = 0, signedFtpSum = 0, ftpCount = 0;
  let smashSum = 0, smashCount = 0;
  let totalSum = 0, totalCount = 0, rollSum = 0, rollCount = 0;
  let ballSpeedSum = 0, ballSpeedCount = 0, clubSpeedSum = 0, clubSpeedCount = 0;
  let vlaSum = 0, vlaCount = 0, hlaSum = 0, hlaCount = 0;
  let aoaSum = 0, aoaCount = 0, dynLoftSum = 0, dynLoftCount = 0, spinLoftSum = 0, spinLoftCount = 0;
  let spinSum = 0, spinCount = 0, backSpinSum = 0, backSpinCount = 0, sideSpinSum = 0, sideSpinCount = 0;
  let spinAxisSum = 0, spinAxisCount = 0;
  let apexSum = 0, apexCount = 0, descentSum = 0, descentCount = 0, hangSum = 0, hangCount = 0;
  let hiSum = 0, viSum = 0, hiViCount = 0, impactOffsetSum = 0, impactCount = 0;

  let startMagSum = 0, curveMagSum = 0, attrCount = 0;
  const flightCounts = {};
  let totalClassified = 0;
  let functionalStockCount = 0;
  const ellipsePoints = [];

  const quadAgg = {
    center: { count: 0, smashSum: 0, smashCount: 0, carrySum: 0, carryCount: 0, axisSum: 0, axisCount: 0 },
    toe:    { count: 0, smashSum: 0, smashCount: 0, carrySum: 0, carryCount: 0, axisSum: 0, axisCount: 0 },
    heel:   { count: 0, smashSum: 0, smashCount: 0, carrySum: 0, carryCount: 0, axisSum: 0, axisCount: 0 },
    high:   { count: 0, smashSum: 0, smashCount: 0, carrySum: 0, carryCount: 0, axisSum: 0, axisCount: 0 },
    low:    { count: 0, smashSum: 0, smashCount: 0, carrySum: 0, carryCount: 0, axisSum: 0, axisCount: 0 }
  };

  shots.forEach((s) => {
    absOfflineSum += s.absOfflineYds;
    signedOfflineSum += s.signedOfflineYds;
    signedOfflines.push(s.signedOfflineYds);

    if (s.absOfflineYds <= corridorYds) {
      inFairwayCount++;
    } else if (s.signedOfflineYds < -corridorYds) {
      leftMissCount++;
    } else {
      rightMissCount++;
    }

    if (s.carryYds > 0) {
      ellipsePoints.push({ x: s.carryYds, y: s.signedOfflineYds });
    }

    if (s.faceAngle != null) {
      absFaceSum += Math.abs(s.faceAngle);
      signedFaceSum += s.faceAngle;
      faceVals.push(s.faceAngle);
      faceCount++;
    }
    if (s.clubPath != null) {
      absPathSum += Math.abs(s.clubPath);
      signedPathSum += s.clubPath;
      pathVals.push(s.clubPath);
      pathCount++;
    }
    if (s.faceToPath != null) {
      absFtpSum += Math.abs(s.faceToPath);
      signedFtpSum += s.faceToPath;
      ftpVals.push(s.faceToPath);
      ftpCount++;
    }

    if (s.faceAngle != null || s.clubPath != null) {
      const bf = classifyBallFlight(s.faceAngle, s.clubPath, s.faceToPath, isLefty);
      flightCounts[bf.shape] = (flightCounts[bf.shape] || 0) + 1;
      totalClassified++;
      if (bf.isFunctionalStock) functionalStockCount++;
    }

    const startMetric = s.hla != null ? s.hla : (s.faceAngle != null ? s.faceAngle * 0.8 + (s.clubPath ?? 0) * 0.2 : null);
    const curveMetric = s.faceToPath != null ? s.faceToPath : (s.spinAxis != null ? s.spinAxis / 2.2 : null);
    if (startMetric != null && curveMetric != null) {
      startMagSum += Math.abs(startMetric);
      curveMagSum += Math.abs(curveMetric);
      attrCount++;
    }

    if (s.smash != null && s.smash > 0.5) {
      smashSum += s.smash;
      smashCount++;
    }
    if (s.totalYds > 0) {
      totalSum += s.totalYds;
      totalCount++;
      if (s.carryYds > 0) {
        rollSum += Math.max(0, s.totalYds - s.carryYds);
        rollCount++;
      }
    }
    if (s.ballSpeed != null && s.ballSpeed > 0) { ballSpeedSum += s.ballSpeed; ballSpeedCount++; }
    if (s.clubSpeed != null && s.clubSpeed > 0) { clubSpeedSum += s.clubSpeed; clubSpeedCount++; }
    if (s.vla != null) { vlaSum += s.vla; vlaCount++; }
    if (s.hla != null) { hlaSum += s.hla; hlaCount++; }
    if (s.attackAngle != null) { aoaSum += s.attackAngle; aoaCount++; }
    if (s.dynamicLoft != null) { dynLoftSum += s.dynamicLoft; dynLoftCount++; }
    if (s.spinLoft != null) { spinLoftSum += s.spinLoft; spinLoftCount++; }
    if (s.totalSpin != null && s.totalSpin > 0) { spinSum += s.totalSpin; spinCount++; }
    if (s.backSpin != null && s.backSpin > 0) { backSpinSum += s.backSpin; backSpinCount++; }
    if (s.sideSpin != null) { sideSpinSum += s.sideSpin; sideSpinCount++; }
    if (s.spinAxis != null) { spinAxisSum += s.spinAxis; spinAxisCount++; }
    if (s.apexFt != null) { apexSum += s.apexFt; apexCount++; }
    if (s.descentAngle != null) { descentSum += s.descentAngle; descentCount++; }
    if (s.hangTime != null) { hangSum += s.hangTime; hangCount++; }

    if (s.hi != null && s.vi != null) {
      hiSum += s.hi;
      viSum += s.vi;
      hiViCount++;

      const offset = Math.hypot(s.hi, s.vi);
      const recordQuad = (bucket) => {
        bucket.count++;
        if (s.smash != null && s.smash > 0.5) { bucket.smashSum += s.smash; bucket.smashCount++; }
        if (s.carryYds > 0) { bucket.carrySum += s.carryYds; bucket.carryCount++; }
        if (s.spinAxis != null) { bucket.axisSum += s.spinAxis; bucket.axisCount++; }
      };
      if (offset <= 6.0) recordQuad(quadAgg.center);
      else if (s.hi > 6.0) recordQuad(quadAgg.toe);
      else if (s.hi < -6.0) recordQuad(quadAgg.heel);
      if (s.vi > 6.0 && offset > 6.0) recordQuad(quadAgg.high);
      else if (s.vi < -6.0 && offset > 6.0) recordQuad(quadAgg.low);
    }
    if (s.impactOffsetMm != null) {
      impactOffsetSum += s.impactOffsetMm;
      impactCount++;
    }
  });

  const avgCarry = carryList.length > 0 ? carrySum / carryList.length : 0;
  const maxCarryYds = carryList.length > 0 ? Math.max(...carryList) : 0;
  const minCarryYds = carryList.length > 0 ? Math.min(...carryList) : 0;
  const stdDevCarry = calcStdDev(carryList, avgCarry);
  const carryConsistencyPct = avgCarry > 5 && carryList.length >= 2 ? round1((stdDevCarry / avgCarry) * 100) : null;

  const avgSignedOffline = round1(signedOfflineSum / n);
  const stdDevOffline = calcStdDev(signedOfflines, signedOfflineSum / n);
  const pctInFairway = Math.round((inFairwayCount / n) * 100);

  // Aim Shift simulation: shift entire shot pattern by -avgSignedOffline
  let shiftedInCorridor = 0;
  shots.forEach((s) => {
    if (Math.abs(s.signedOfflineYds - avgSignedOffline) <= corridorYds) {
      shiftedInCorridor++;
    }
  });
  const projectedPctInFairway = Math.round((shiftedInCorridor / n) * 100);
  const aimShift = {
    shiftYds: round1(Math.abs(avgSignedOffline)),
    shiftDir: avgSignedOffline > 0.5 ? "Left" : (avgSignedOffline < -0.5 ? "Right" : "On Target"),
    projectedPctInFairway,
    gainPct: Math.max(0, projectedPctInFairway - pctInFairway)
  };

  // Dominant Ball Flight
  const flightPcts = {};
  let dominantShape = null;
  let dominantCount = 0;
  for (const [shape, cnt] of Object.entries(flightCounts)) {
    flightPcts[shape] = Math.round((cnt / totalClassified) * 100);
    if (cnt > dominantCount) {
      dominantCount = cnt;
      dominantShape = shape;
    }
  }
  const ballFlight = {
    counts: flightCounts,
    pcts: flightPcts,
    totalClassified,
    dominantShape,
    dominantPct: totalClassified > 0 ? Math.round((dominantCount / totalClassified) * 100) : 0,
    pctFunctionalStock: totalClassified > 0 ? Math.round((functionalStockCount / totalClassified) * 100) : 0
  };

  // Miss Attribution & One-Way vs Two-Way Pattern
  let startPct = 50, curvePct = 50;
  if (attrCount > 0 && (startMagSum + curveMagSum) > 0.1) {
    startPct = Math.round((startMagSum / (startMagSum + curveMagSum)) * 100);
    curvePct = 100 - startPct;
  }
  let missPattern = "centered_consistent";
  if (n >= 4) {
    if (Math.abs(avgSignedOffline) >= stdDevOffline * 0.75 && Math.abs(avgSignedOffline) >= corridorYds * 0.35) {
      missPattern = "one_way_bias";
    } else if (stdDevOffline >= corridorYds * 0.85 && Math.abs(avgSignedOffline) < stdDevOffline * 0.6) {
      missPattern = "two_way_miss";
    }
  }
  const missAttribution = { startPct, curvePct, missPattern, hasData: attrCount > 0 };

  const dispersionEllipse = computeCovarianceEllipse(ellipsePoints);

  let strikeQuadrants = null;
  if (hiViCount > 0) {
    const summarizeQuad = (q) => ({
      count: q.count,
      pct: Math.round((q.count / hiViCount) * 100),
      avgSmash: q.smashCount > 0 ? round2(q.smashSum / q.smashCount) : null,
      avgCarry: q.carryCount > 0 ? round1(q.carrySum / q.carryCount) : null,
      avgSpinAxis: q.axisCount > 0 ? round1(q.axisSum / q.axisCount) : null
    });
    strikeQuadrants = {
      total: hiViCount,
      center: summarizeQuad(quadAgg.center),
      toe: summarizeQuad(quadAgg.toe),
      heel: summarizeQuad(quadAgg.heel),
      high: summarizeQuad(quadAgg.high),
      low: summarizeQuad(quadAgg.low)
    };
  }

  const avgDescentAngle = descentCount > 0 ? round1(descentSum / descentCount) : null;
  const avgSpin = spinCount > 0 ? Math.round(spinSum / spinCount) : null;
  const clubCat = classifyClubCategory(clubKey);
  let stoppingPower = null;
  if (["long_iron", "mid_iron", "wedge"].includes(clubCat) && (avgDescentAngle != null || avgSpin != null)) {
    const bench = getClubBenchmark(clubKey, skillLevel);
    const descOk = avgDescentAngle != null ? avgDescentAngle >= bench.land_angle_min : true;
    const descLow = avgDescentAngle != null ? avgDescentAngle < bench.land_angle_min - 4.0 : false;
    const spinLow = avgSpin != null ? avgSpin < bench.spin_min - 600 : false;
    let grade = "Playable";
    if (descLow || (spinLow && !descOk)) grade = "Low Stopping Power";
    else if ((avgDescentAngle != null && avgDescentAngle >= bench.land_angle_min + 1.0) && (avgSpin == null || avgSpin >= bench.spin_min)) {
      grade = "Tour Hold";
    }
    stoppingPower = { grade, avgDescentAngle, targetDescentMin: bench.land_angle_min, avgSpin, targetSpinMin: bench.spin_min };
  }

  return {
    count: n,
    corridorYds,
    avgAbsOffline: round1(absOfflineSum / n),
    avgSignedOffline,
    stdDevOffline,
    pctInFairway,
    pctLeft: Math.round((leftMissCount / n) * 100),
    pctRight: Math.round((rightMissCount / n) * 100),
    avgAbsFace: faceCount > 0 ? round1(absFaceSum / faceCount) : null,
    avgSignedFace: faceCount > 0 ? round1(signedFaceSum / faceCount) : null,
    stdDevFace: faceCount >= 2 ? calcStdDev(faceVals, signedFaceSum / faceCount) : null,
    faceCount,
    avgAbsPath: pathCount > 0 ? round1(absPathSum / pathCount) : null,
    avgSignedPath: pathCount > 0 ? round1(signedPathSum / pathCount) : null,
    stdDevPath: pathCount >= 2 ? calcStdDev(pathVals, signedPathSum / pathCount) : null,
    pathCount,
    avgAbsFtp: ftpCount > 0 ? round1(absFtpSum / ftpCount) : null,
    avgSignedFtp: ftpCount > 0 ? round1(signedFtpSum / ftpCount) : null,
    stdDevFtp: ftpCount >= 2 ? calcStdDev(ftpVals, signedFtpSum / ftpCount) : null,
    ftpCount,
    avgSmash: smashCount > 0 ? round2(smashSum / smashCount) : null,
    smashCount,
    avgCarry: round1(avgCarry),
    avgTotalYds: totalCount > 0 ? round1(totalSum / totalCount) : round1(avgCarry),
    avgRollYds: rollCount > 0 ? round1(rollSum / rollCount) : 0,
    maxCarryYds: round1(maxCarryYds),
    minCarryYds: round1(minCarryYds),
    stdDevCarry,
    carryConsistencyPct,
    avgBallSpeed: ballSpeedCount > 0 ? round1(ballSpeedSum / ballSpeedCount) : null,
    avgClubSpeed: clubSpeedCount > 0 ? round1(clubSpeedSum / clubSpeedCount) : null,
    avgVla: vlaCount > 0 ? round1(vlaSum / vlaCount) : null,
    vlaCount,
    avgHla: hlaCount > 0 ? round1(hlaSum / hlaCount) : null,
    hlaCount,
    avgAoa: aoaCount > 0 ? round1(aoaSum / aoaCount) : null,
    aoaCount,
    avgDynamicLoft: dynLoftCount > 0 ? round1(dynLoftSum / dynLoftCount) : null,
    dynamicLoftCount: dynLoftCount,
    avgSpinLoft: spinLoftCount > 0 ? round1(spinLoftSum / spinLoftCount) : null,
    spinLoftCount,
    avgSpin,
    spinCount,
    avgBackSpin: backSpinCount > 0 ? Math.round(backSpinSum / backSpinCount) : null,
    avgSideSpin: sideSpinCount > 0 ? Math.round(sideSpinSum / sideSpinCount) : null,
    avgSpinAxis: spinAxisCount > 0 ? round1(spinAxisSum / spinAxisCount) : null,
    spinAxisCount,
    avgApexFt: apexCount > 0 ? round1(apexSum / apexCount) : null,
    apexCount,
    avgDescentAngle,
    descentCount,
    avgHangTime: hangCount > 0 ? round2(hangSum / hangCount) : null,
    avgHi: hiViCount > 0 ? round1(hiSum / hiViCount) : null,
    avgVi: hiViCount > 0 ? round1(viSum / hiViCount) : null,
    hiViCount,
    avgImpactOffsetMm: impactCount > 0 ? round1(impactOffsetSum / impactCount) : null,
    impactCount,
    ballFlight,
    missAttribution,
    aimShift,
    dispersionEllipse,
    strikeQuadrants,
    stoppingPower
  };
}

/**
 * Selects the #1 highest-ROI root cause and builds a progressive 3-step micro-milestone ladder.
 */
function buildIncrementalFocus(recent, baseline, clubKey, skillLevel, isLefty, benchmark, distanceLoss) {
  const candidates = [];
  const clubCat = classifyClubCategory(clubKey);
  const effectiveClub = clubKey && clubKey !== "all" ? clubKey : "driver";
  const bench = benchmark || getClubBenchmark(effectiveClub, skillLevel);

  // 1. Gear-effect / off-center strike
  if (recent.avgImpactOffsetMm != null && recent.avgImpactOffsetMm >= 7.5) {
    const cur = recent.avgImpactOffsetMm;
    const isToe = (recent.avgHi ?? 0) > 4.0;
    const isHeel = (recent.avgHi ?? 0) < -4.0;
    const issueKey = (isToe && (recent.avgSpinAxis ?? 0) < -4.0)
      ? "toe_gear_hook"
      : (isHeel && (recent.avgSpinAxis ?? 0) > 4.0)
        ? "heel_gear_slice"
        : "off_center_strike";
    const s1 = round1(Math.max(6.5, cur - 2.5));
    const s2 = round1(Math.max(5.0, s1 - 1.5));
    candidates.push({
      strokes: round1(Math.min(4.2, (cur - 5.0) * 0.45 + (distanceLoss?.smashLossYds || 0) * 0.08)),
      issueKey,
      title: "Center Clubface Strike Location",
      why: `Averaging ${cur.toFixed(1)} mm off-center (${isToe ? "toe bias" : isHeel ? "heel bias" : "scattered"}), costing ball speed and triggering gear-effect curve.`,
      metricKey: "impactOffsetMm",
      metricLabel: "Sweet Spot Offset",
      unit: "mm",
      direction: "lower",
      currentValue: cur,
      targetValue: 5.0,
      milestones: [
        { step: 1, label: `Keep average strike under ${s1} mm`, targetVal: s1, passRule: `7/10 shots within ${s1} mm of center`, status: cur <= s1 ? "achieved" : "active" },
        { step: 2, label: `Tighten strike cluster under ${s2} mm`, targetVal: s2, passRule: `7/10 shots within ${s2} mm of center`, status: cur <= s2 ? "achieved" : (cur <= s1 ? "active" : "upcoming") },
        { step: 3, label: `Sustain Tour-level ≤ 5.0 mm centering`, targetVal: 5.0, passRule: `8/10 shots ≤ 5.0 mm`, status: cur <= 5.0 ? "achieved" : "upcoming" }
      ]
    });
  }

  // 2. Smash Factor
  if (recent.avgSmash != null && recent.avgSmash < bench.smash_min) {
    const cur = recent.avgSmash;
    const gap = bench.smash_min - cur;
    const s1 = round2(Math.min(bench.smash_min, cur + gap * 0.4));
    const s2 = round2(Math.min(bench.smash_min, cur + gap * 0.75));
    candidates.push({
      strokes: round1(Math.min(3.8, gap * 28 + (distanceLoss?.smashLossYds || 0) * 0.08)),
      issueKey: "low_smash",
      title: `Raise ${bench.name} Smash Factor`,
      why: `Averaging ${cur.toFixed(2)} vs ${bench.smash_min.toFixed(2)}–${bench.smash_max.toFixed(2)} target (${distanceLoss?.smashLossYds ? `-${distanceLoss.smashLossYds} yds` : "energy leak"}).`,
      metricKey: "smash",
      metricLabel: "Smash Factor",
      unit: "",
      direction: "higher",
      currentValue: cur,
      targetValue: bench.smash_min,
      milestones: [
        { step: 1, label: `Average ${s1.toFixed(2)}+ Smash over 10 shots`, targetVal: s1, passRule: `7/10 strikes ≥ ${s1.toFixed(2)}`, status: cur >= s1 ? "achieved" : "active" },
        { step: 2, label: `Reach ${s2.toFixed(2)}+ Smash consistently`, targetVal: s2, passRule: `7/10 strikes ≥ ${s2.toFixed(2)}`, status: cur >= s2 ? "achieved" : (cur >= s1 ? "active" : "upcoming") },
        { step: 3, label: `Lock in ${bench.smash_min.toFixed(2)}+ target efficiency`, targetVal: bench.smash_min, passRule: `8/10 strikes ≥ ${bench.smash_min.toFixed(2)}`, status: cur >= bench.smash_min ? "achieved" : "upcoming" }
      ]
    });
  }

  // 3. Face-to-Path Curvature (skip if functional stock draw/fade with tight dispersion!)
  if (recent.avgAbsFtp != null && recent.avgAbsFtp > 2.8 && recent.ballFlight.pctFunctionalStock < 60) {
    const cur = recent.avgAbsFtp;
    const s1 = round1(Math.max(2.6, cur * 0.72));
    const s2 = round1(Math.max(2.0, cur * 0.48));
    const ftpSign = (recent.avgSignedFtp ?? 0) >= 0;
    const issueKey = ftpSign ? "face_open" : "face_closed";
    candidates.push({
      strokes: round1(Math.min(4.5, (cur - 2.0) * 0.75 + (recent.pctInFairway < 50 ? 1.0 : 0.3))),
      issueKey,
      title: "Tighten Face-to-Path Curvature",
      why: `Averaging ${cur.toFixed(1)}° Face-to-Path (${ftpSign ? "slice/fade" : "hook/draw"} spin), driving ${recent.missAttribution.curvePct}% of your lateral curve.`,
      metricKey: "faceToPath",
      metricLabel: "Face-to-Path Gap",
      unit: "°",
      direction: "lower",
      currentValue: cur,
      targetValue: 2.0,
      milestones: [
        { step: 1, label: `Bring Face-to-Path under ±${s1.toFixed(1)}°`, targetVal: s1, passRule: `7/10 shots within ±${s1.toFixed(1)}°`, status: cur <= s1 ? "achieved" : "active" },
        { step: 2, label: `Narrow Face-to-Path under ±${s2.toFixed(1)}°`, targetVal: s2, passRule: `7/10 shots within ±${s2.toFixed(1)}°`, status: cur <= s2 ? "achieved" : (cur <= s1 ? "active" : "upcoming") },
        { step: 3, label: `Sustain ±2.0° stock curve control`, targetVal: 2.0, passRule: `8/10 shots within ±2.0°`, status: cur <= 2.0 ? "achieved" : "upcoming" }
      ]
    });
  }

  // 4. Start-Line / Club Face Control
  if (recent.avgAbsFace != null && recent.avgAbsFace > 2.4 && (recent.missAttribution.startPct >= 45 || recent.stdDevFace >= 2.5)) {
    const cur = recent.avgAbsFace;
    const s1 = round1(Math.max(2.0, cur * 0.72));
    const s2 = round1(Math.max(1.5, cur * 0.5));
    const issueKey = recent.missAttribution.missPattern === "two_way_miss"
      ? "two_way_miss"
      : ((recent.avgSignedFace ?? 0) >= 0 ? "face_open" : "face_closed");
    candidates.push({
      strokes: round1(Math.min(4.0, (cur - 1.5) * 0.65)),
      issueKey,
      title: recent.missAttribution.missPattern === "two_way_miss" ? "Stabilize Two-Way Face Control" : "Square Club Face Start Line",
      why: `Face angle is averaging ±${cur.toFixed(1)}° off square, accounting for ${recent.missAttribution.startPct}% of miss direction.`,
      metricKey: "faceAngle",
      metricLabel: "Face Angle Deviation",
      unit: "°",
      direction: "lower",
      currentValue: cur,
      targetValue: 1.5,
      milestones: [
        { step: 1, label: `Keep Face Angle within ±${s1.toFixed(1)}°`, targetVal: s1, passRule: `7/10 shots within ±${s1.toFixed(1)}°`, status: cur <= s1 ? "achieved" : "active" },
        { step: 2, label: `Tighten Face Angle within ±${s2.toFixed(1)}°`, targetVal: s2, passRule: `7/10 shots within ±${s2.toFixed(1)}°`, status: cur <= s2 ? "achieved" : (cur <= s1 ? "active" : "upcoming") },
        { step: 3, label: `Sustain ±1.5° square start-line window`, targetVal: 1.5, passRule: `8/10 shots within ±1.5°`, status: cur <= 1.5 ? "achieved" : "upcoming" }
      ]
    });
  }

  // 5. Offline Dispersion fallback (when LM lacks face/path)
  if (candidates.length === 0 && recent.avgAbsOffline > recent.corridorYds * 0.7) {
    const cur = recent.avgAbsOffline;
    const target = round1(recent.corridorYds * 0.7);
    const s1 = round1(Math.max(target, cur * 0.8));
    const s2 = round1(Math.max(target, cur * 0.65));
    candidates.push({
      strokes: round1(Math.min(3.5, (cur / recent.corridorYds) * 1.4)),
      issueKey: "offline_expanding",
      title: `Tighten ±${recent.corridorYds} yd Target Corridor Rate`,
      why: `Averaging ±${cur.toFixed(1)} yds offline (${recent.pctInFairway}% inside corridor${recent.aimShift.gainPct >= 8 ? `; aiming ${recent.aimShift.shiftYds} yds ${recent.aimShift.shiftDir} could lift this to ${recent.aimShift.projectedPctInFairway}%` : ""}).`,
      metricKey: "absOffline",
      metricLabel: "Avg Offline Dispersion",
      unit: "yds",
      direction: "lower",
      currentValue: cur,
      targetValue: target,
      milestones: [
        { step: 1, label: `Reduce avg offline under ${s1} yds`, targetVal: s1, passRule: `6/10 shots inside ±${recent.corridorYds} yds`, status: cur <= s1 ? "achieved" : "active" },
        { step: 2, label: `Reduce avg offline under ${s2} yds`, targetVal: s2, passRule: `7/10 shots inside ±${recent.corridorYds} yds`, status: cur <= s2 ? "achieved" : (cur <= s1 ? "active" : "upcoming") },
        { step: 3, label: `Sustain ≤ ${target} yds average miss`, targetVal: target, passRule: `8/10 shots inside ±${recent.corridorYds} yds`, status: cur <= target ? "achieved" : "upcoming" }
      ]
    });
  }

  if (candidates.length === 0) {
    return {
      title: "Maintain & Transfer Stock Ball Flight",
      issueKey: "Pure Ball Strike",
      estimatedStrokesSaved: 0.3,
      why: `Key metrics are tracking cleanly inside ${SKILL_LEVEL_NAMES_LOCAL[skillLevel] || "your"} target windows.`,
      metricKey: "corridorPct",
      metricLabel: "Target Corridor Hit Rate",
      unit: "%",
      direction: "higher",
      currentValue: recent.pctInFairway,
      targetValue: 75,
      clubKey: effectiveClub,
      milestones: [
        { step: 1, label: "Hit 7/10 shots inside target corridor", targetVal: 70, passRule: "70% target hit rate", status: recent.pctInFairway >= 70 ? "achieved" : "active" },
        { step: 2, label: "Alternate targets every shot (random practice)", targetVal: 75, passRule: "75% random transfer rate", status: "upcoming" },
        { step: 3, label: "Sustain stock curve under course pressure", targetVal: 80, passRule: "80% target rate", status: "upcoming" }
      ]
    };
  }

  candidates.sort((a, b) => b.strokes - a.strokes);
  const top = candidates[0];
  return {
    ...top,
    estimatedStrokesSaved: Math.max(0.5, top.strokes),
    clubKey: effectiveClub
  };
}

const SKILL_LEVEL_NAMES_LOCAL = {
  high_handicap: "High Handicap",
  mid_handicap: "Mid Handicap",
  scratch: "Scratch",
  tour_pro: "Tour Pro"
};

/**
 * Main analytics computation function.
 * Evaluates baseline vs recent shots, computes progress trends, sessions, distance loss,
 * club-calibrated benchmarks, and incremental micro-milestones.
 */
export function computeImprovementAnalytics(shots, sampleWindowMode = "last10", options = {}) {
  const clubKey = options.clubKey || "all";
  const skillLevel = normalizeSkillLevel(options.skillLevel);
  const isLefty = Boolean(options.isLefty);

  if (!shots || shots.length === 0) {
    return { hasData: false, totalShots: 0, clubKey, skillLevel, isLefty };
  }

  const totalShots = shots.length;
  const effectiveClub = clubKey !== "all" ? clubKey : (shots[shots.length - 1]?.club || "driver");
  const benchmark = getClubBenchmark(effectiveClub, skillLevel);
  const summaryOpts = { clubKey, skillLevel, isLefty };
  const { sessions, fatigue } = groupShotsIntoSessions(shots, 2700, summaryOpts);

  if (totalShots === 1) {
    const single = summarizeShotGroup(shots, summaryOpts);
    const distanceLoss = computeDistanceLossBreakdown(single, effectiveClub, skillLevel);
    return {
      hasData: true,
      singleShot: true,
      totalShots: 1,
      clubKey,
      skillLevel,
      isLefty,
      benchmark,
      corridorYds: single.corridorYds,
      recent: single,
      baseline: single,
      sessions,
      fatigue,
      distanceLoss,
      activeFocus: buildIncrementalFocus(single, single, clubKey, skillLevel, isLefty, benchmark, distanceLoss),
      shots
    };
  }

  // Split into Baseline and Recent sets based on sampleWindowMode
  let baselineShots = [];
  let recentShots = [];

  if (sampleWindowMode === "sessions" && sessions.length >= 2) {
    recentShots = sessions[sessions.length - 1].shots;
    baselineShots = sessions[sessions.length - 2].shots;
  } else if (sampleWindowMode === "last25") {
    const windowSize = Math.min(25, Math.floor(totalShots / 2));
    recentShots = shots.slice(totalShots - windowSize);
    baselineShots = shots.slice(Math.max(0, totalShots - windowSize * 2), totalShots - windowSize);
  } else if (sampleWindowMode === "all") {
    const mid = Math.floor(totalShots / 2);
    baselineShots = shots.slice(0, mid);
    recentShots = shots.slice(mid);
  } else {
    // "last10" (also graceful fallback when "sessions" selected with < 2 sessions)
    const windowSize = Math.min(10, Math.floor(totalShots / 2));
    recentShots = shots.slice(totalShots - windowSize);
    baselineShots = shots.slice(Math.max(0, totalShots - windowSize * 2), totalShots - windowSize);
  }

  if (baselineShots.length === 0) baselineShots = recentShots.slice(0, 1);
  if (recentShots.length === 0) recentShots = baselineShots.slice();

  const baseline = summarizeShotGroup(baselineShots, summaryOpts);
  const recent = summarizeShotGroup(recentShots, summaryOpts);

  // 1. Offline Dispersion Analysis
  const offlineDelta = round1(recent.avgAbsOffline - baseline.avgAbsOffline);
  let offlineStatus = "consistent";
  let offlineBadge = "Consistent Dispersion";
  let offlineImprovementText = "Holding steady (±0.3 yds)";

  if (offlineDelta <= -0.4) {
    offlineStatus = "improving";
    offlineBadge = "Nearing Centerline (Tighter)";
    const pctGain = baseline.avgAbsOffline > 0 ? Math.round((Math.abs(offlineDelta) / baseline.avgAbsOffline) * 100) : 0;
    offlineImprovementText = `↓ ${Math.abs(offlineDelta).toFixed(1)} yds closer to center (${pctGain}% tighter dispersion)`;
  } else if (offlineDelta >= 0.4) {
    offlineStatus = "expanding";
    offlineBadge = "Expanding Further Offline";
    offlineImprovementText = `↑ ${offlineDelta.toFixed(1)} yds further offline`;
  }

  // 2. Club Face Angle Analysis
  let faceStatus = "no_data", faceBadge = "No LM Data", faceDelta = null, faceImprovementText = "Face telemetry not provided";
  if (recent.avgAbsFace != null && baseline.avgAbsFace != null) {
    faceDelta = round1(recent.avgAbsFace - baseline.avgAbsFace);
    if (faceDelta <= -0.2) {
      faceStatus = "improving";
      faceBadge = "Squaring Up (Closer to 0°)";
      faceImprovementText = `↓ ${Math.abs(faceDelta).toFixed(1)}° closer to square (0.0°)`;
    } else if (faceDelta >= 0.2) {
      faceStatus = "expanding";
      faceBadge = "Drifting Off-Square";
      faceImprovementText = `↑ ${faceDelta.toFixed(1)}° deviation from square`;
    } else {
      faceStatus = "consistent";
      faceBadge = "Consistent Face Angle";
      faceImprovementText = "Face angle stable (±0.1°)";
    }
  }

  // 3. Club Path Analysis
  let pathStatus = "no_data", pathBadge = "No LM Data", pathDelta = null, pathImprovementText = "Path telemetry not provided";
  if (recent.avgAbsPath != null && baseline.avgAbsPath != null) {
    pathDelta = round1(recent.avgAbsPath - baseline.avgAbsPath);
    if (pathDelta <= -0.2) {
      pathStatus = "improving";
      pathBadge = "Straightening Path (Closer to 0°)";
      pathImprovementText = `↓ ${Math.abs(pathDelta).toFixed(1)}° closer to neutral (0.0°)`;
    } else if (pathDelta >= 0.2) {
      pathStatus = "expanding";
      pathBadge = "Path Deviation Increasing";
      pathImprovementText = `↑ ${pathDelta.toFixed(1)}° deviation from straight`;
    } else {
      pathStatus = "consistent";
      pathBadge = "Consistent Swing Path";
      pathImprovementText = "Swing path stable (±0.1°)";
    }
  }

  // 4. Face-to-Path Curvature Analysis
  let ftpStatus = "no_data", ftpBadge = "No LM Data", ftpDelta = null, ftpImprovementText = "";
  if (recent.avgAbsFtp != null && baseline.avgAbsFtp != null) {
    ftpDelta = round1(recent.avgAbsFtp - baseline.avgAbsFtp);
    if (ftpDelta <= -0.2) {
      ftpStatus = "improving";
      ftpBadge = "Straighter Flight (Curvature Reduced)";
      ftpImprovementText = `↓ ${Math.abs(ftpDelta).toFixed(1)}° tighter face-to-path alignment`;
    } else if (ftpDelta >= 0.2) {
      ftpStatus = "expanding";
      ftpBadge = "Increased Curve / Spin Tilt";
      ftpImprovementText = `↑ ${ftpDelta.toFixed(1)}° face-to-path gap`;
    } else {
      ftpStatus = "consistent";
      ftpBadge = "Consistent Curvature";
      ftpImprovementText = "Face-to-path stable";
    }
  }

  // 5. Smash Factor & Strike Offset
  let smashStatus = "no_data", smashDelta = null, smashImprovementText = "";
  if (recent.avgSmash != null && baseline.avgSmash != null) {
    smashDelta = round2(recent.avgSmash - baseline.avgSmash);
    if (smashDelta >= 0.02) {
      smashStatus = "improving";
      smashImprovementText = `↑ +${smashDelta.toFixed(2)} higher compression`;
    } else if (smashDelta <= -0.02) {
      smashStatus = "declining";
      smashImprovementText = `↓ ${Math.abs(smashDelta).toFixed(2)} smash factor`;
    } else {
      smashStatus = "consistent";
      smashImprovementText = "Consistent ball compression";
    }
  }

  let impactStatus = "no_data", impactDelta = null, impactImprovementText = "";
  if (recent.avgImpactOffsetMm != null && baseline.avgImpactOffsetMm != null) {
    impactDelta = round1(recent.avgImpactOffsetMm - baseline.avgImpactOffsetMm);
    if (impactDelta <= -0.3) {
      impactStatus = "improving";
      impactImprovementText = `↓ ${Math.abs(impactDelta).toFixed(1)} mm closer to sweet spot`;
    } else if (impactDelta >= 0.3) {
      impactStatus = "expanding";
      impactImprovementText = `↑ ${impactDelta.toFixed(1)} mm off-center strike`;
    } else {
      impactStatus = "consistent";
      impactImprovementText = "Consistent contact location";
    }
  }

  const carryDelta = round1(recent.avgCarry - baseline.avgCarry);
  const carryDispersionDelta = round1(recent.stdDevCarry - baseline.stdDevCarry);
  const totalDelta = round1(recent.avgTotalYds - baseline.avgTotalYds);
  const ballSpeedDelta = (recent.avgBallSpeed != null && baseline.avgBallSpeed != null)
    ? round1(recent.avgBallSpeed - baseline.avgBallSpeed) : null;
  const clubSpeedDelta = (recent.avgClubSpeed != null && baseline.avgClubSpeed != null)
    ? round1(recent.avgClubSpeed - baseline.avgClubSpeed) : null;
  const vlaDelta = (recent.avgVla != null && baseline.avgVla != null)
    ? round1(recent.avgVla - baseline.avgVla) : null;
  const spinDelta = (recent.avgSpin != null && baseline.avgSpin != null)
    ? Math.round(recent.avgSpin - baseline.avgSpin) : null;
  const aoaDelta = (recent.avgAoa != null && baseline.avgAoa != null)
    ? round1(recent.avgAoa - baseline.avgAoa) : null;
  const spinLoftDelta = (recent.avgSpinLoft != null && baseline.avgSpinLoft != null)
    ? round1(recent.avgSpinLoft - baseline.avgSpinLoft) : null;

  const distanceLoss = computeDistanceLossBreakdown(recent, effectiveClub, skillLevel);
  const activeFocus = buildIncrementalFocus(recent, baseline, clubKey, skillLevel, isLefty, benchmark, distanceLoss);

  return {
    hasData: true,
    totalShots,
    clubKey,
    skillLevel,
    isLefty,
    benchmark,
    corridorYds: recent.corridorYds,
    baselineShotsCount: baselineShots.length,
    recentShotsCount: recentShots.length,
    baseline,
    recent,
    sessions,
    fatigue,
    distanceLoss,
    activeFocus,
    offline: { status: offlineStatus, badge: offlineBadge, delta: offlineDelta, text: offlineImprovementText },
    face: { status: faceStatus, badge: faceBadge, delta: faceDelta, text: faceImprovementText },
    path: { status: pathStatus, badge: pathBadge, delta: pathDelta, text: pathImprovementText },
    faceToPath: { status: ftpStatus, badge: ftpBadge, delta: ftpDelta, text: ftpImprovementText },
    smash: { status: smashStatus, delta: smashDelta, text: smashImprovementText },
    impact: { status: impactStatus, delta: impactDelta, text: impactImprovementText },
    distance: { carryDelta, totalDelta, carryDispersionDelta },
    speed: { ballSpeedDelta, clubSpeedDelta },
    launch: { vlaDelta, aoaDelta, spinLoftDelta },
    spin: { spinDelta },
    shots
  };
}

/**
 * Generates an inline Bullet Range Gauge HTML bar comparing baseline & recent values against optimal window.
 */
export function generateBulletGaugeHtml(value, targetMin, targetMax, scaleMin, scaleMax, baselineValue = null, unit = "") {
  if (value == null || !Number.isFinite(value) || scaleMax <= scaleMin) return "";
  const pct = (v) => Math.max(2, Math.min(98, ((v - scaleMin) / (scaleMax - scaleMin)) * 100));
  const optStart = pct(targetMin);
  const optWidth = Math.max(6, pct(targetMax) - optStart);
  const valPct = pct(value);
  const inOpt = value >= targetMin && value <= targetMax;
  const nearOpt = value >= targetMin - (targetMax - targetMin) * 0.5 && value <= targetMax + (targetMax - targetMin) * 0.5;
  const dotColor = inOpt ? "#22c55e" : (nearOpt ? "#eab308" : "#ef4444");
  const baseMarker = (baselineValue != null && Number.isFinite(baselineValue))
    ? `<span class="bullet-dot-baseline" style="left:${pct(baselineValue).toFixed(1)}%;" title="Baseline: ${baselineValue}${unit}"></span>`
    : "";

  return `
    <div class="bullet-gauge-wrap" title="Current: ${value}${unit} • Target: ${targetMin}–${targetMax}${unit}">
      <div class="bullet-track">
        <div class="bullet-zone-optimal" style="left:${optStart.toFixed(1)}%; width:${optWidth.toFixed(1)}%;"></div>
        ${baseMarker}
        <span class="bullet-dot-recent" style="left:${valPct.toFixed(1)}%; background:${dotColor};"></span>
      </div>
    </div>
  `;
}

/**
 * Generates an SVG line/scatter chart showing directional offline dispersion relative to target line 0.
 */
export function generateOfflineTrendChartSvg(shots, options = {}) {
  if (!shots || shots.length === 0) return "";

  const width = options.width || 700;
  const height = options.height || 240;
  const isLefty = Boolean(options.isLefty);
  const corridorYds = options.corridorYds || getTargetCorridorYds(options.clubKey || "all");
  const padL = 64, padR = 25, padT = 25, padB = 40;
  const plotW = width - padL - padR;
  const plotH = height - padT - padB;

  const maxVal = shots.reduce((acc, s) => Math.max(acc, s.absOfflineYds), corridorYds + 5);
  const scaleLimit = Math.max(corridorYds + 5, Math.ceil(maxVal / 5) * 5);

  const zeroY = padT + plotH / 2;
  const getY = (yds) => zeroY - (yds / scaleLimit) * (plotH / 2);
  const getX = (idx) => padL + (shots.length > 1 ? (idx / (shots.length - 1)) * plotW : plotW / 2);

  const corridorTop = Math.max(padT, getY(corridorYds));
  const corridorBottom = Math.min(height - padB, getY(-corridorYds));
  const corridorH = corridorBottom - corridorTop;

  const gridSteps = [-scaleLimit, -corridorYds, 0, corridorYds, scaleLimit];
  let gridSvg = "";
  gridSteps.forEach((step) => {
    const y = getY(step);
    const isZero = step === 0;
    const isCorridor = Math.abs(step) === corridorYds;
    const stroke = isZero ? "#22c55e" : (isCorridor ? "rgba(34, 197, 94, 0.4)" : "rgba(255, 255, 255, 0.08)");
    const dash = isZero ? "4 3" : (isCorridor ? "2 2" : "none");
    const label = isZero ? "🎯 0 Target" : `${step > 0 ? "+" : ""}${step} yds`;

    gridSvg += `
      <line x1="${padL}" y1="${y}" x2="${width - padR}" y2="${y}" stroke="${stroke}" stroke-width="${isZero ? 2 : 1}" stroke-dasharray="${dash}" />
      <text x="${padL - 8}" y="${y + 4}" fill="${isZero ? "#22c55e" : "var(--muted)"}" font-size="10" font-weight="${isZero ? "700" : "500"}" text-anchor="end">${label}</text>
    `;
  });

  const offlineValues = shots.map(s => s.signedOfflineYds);
  const rolling = computeRollingAverage(offlineValues, Math.min(5, Math.max(2, Math.floor(shots.length / 3))));

  let trendPath = "";
  rolling.forEach((val, i) => {
    if (val == null) return;
    trendPath += (trendPath === "" ? `M ${getX(i)} ${getY(val)}` : ` L ${getX(i)} ${getY(val)}`);
  });

  let dotsSvg = "";
  shots.forEach((s, i) => {
    const x = getX(i);
    const y = getY(s.signedOfflineYds);
    const inCorridor = s.absOfflineYds <= corridorYds;
    const dotColor = inCorridor ? "#22c55e" : (s.absOfflineYds <= corridorYds * 1.75 ? "#eab308" : "#ef4444");
    const sideText = s.signedOfflineYds === 0 ? "Dead Center" : (s.signedOfflineYds < 0 ? `${Math.abs(s.signedOfflineYds)} yds Left` : `${s.signedOfflineYds} yds Right`);
    const titleText = `Shot #${s.index}${s.club ? " (" + s.club + ")" : ""}: ${sideText} • Carry: ${s.carryYds} yds`;
    dotsSvg += `<circle cx="${x}" cy="${y}" r="4.5" fill="${dotColor}" stroke="#0b131e" stroke-width="1.5"><title>${titleText}</title></circle>`;
  });

  const topHint = isLefty ? "PULL / HOOK RIGHT (+)" : "PUSH / SLICE RIGHT (+)";
  const botHint = isLefty ? "PUSH / SLICE LEFT (-)" : "PULL / HOOK LEFT (-)";

  return `
    <svg viewBox="0 0 ${width} ${height}" class="analytics-svg-chart" style="width:100%; height:auto;" aria-label="Offline Dispersion Trend Chart">
      <rect x="${padL}" y="${corridorTop}" width="${plotW}" height="${corridorH}" fill="rgba(34, 197, 94, 0.08)" rx="4" />
      <text x="${width - padR - 8}" y="${corridorTop + 14}" fill="rgba(34, 197, 94, 0.7)" font-size="10" font-weight="600" text-anchor="end">±${corridorYds} yd Target Corridor</text>
      <text x="${padL + 10}" y="${padT + 12}" fill="rgba(255,255,255,0.35)" font-size="9" font-weight="600">${topHint}</text>
      <text x="${padL + 10}" y="${height - padB - 6}" fill="rgba(255,255,255,0.35)" font-size="9" font-weight="600">${botHint}</text>
      ${gridSvg}
      ${trendPath ? `<path d="${trendPath}" fill="none" stroke="#38bdf8" stroke-width="2.5" stroke-linejoin="round" stroke-linecap="round" />` : ""}
      ${dotsSvg}
      <text x="${padL}" y="${height - 12}" fill="var(--muted)" font-size="10">Oldest Shot (Shot #1)</text>
      <text x="${width - padR}" y="${height - 12}" fill="var(--muted)" font-size="10" text-anchor="end">Latest Shot (Shot #${shots.length})</text>
    </svg>
  `;
}

/**
 * Generates an SVG chart showing Face Angle and Club Path converging to 0.0°.
 */
export function generateDeliveryTrendChartSvg(shots, options = {}) {
  const validShots = shots.filter(s => s.faceAngle != null || s.clubPath != null);
  if (validShots.length === 0) {
    return `<div class="empty-chart-fallback"><p>No club face or path data recorded yet. Connect a launch monitor with club delivery telemetry to track delivery angles!</p></div>`;
  }

  const width = options.width || 700;
  const height = options.height || 240;
  const isLefty = Boolean(options.isLefty);
  const padL = 60, padR = 25, padT = 25, padB = 40;
  const plotW = width - padL - padR;
  const plotH = height - padT - padB;

  const maxDeg = validShots.reduce((acc, s) => {
    const f = s.faceAngle != null ? Math.abs(s.faceAngle) : 0;
    const p = s.clubPath != null ? Math.abs(s.clubPath) : 0;
    return Math.max(acc, f, p);
  }, 6);
  const scaleDeg = Math.max(5, Math.ceil(maxDeg / 2) * 2);

  const zeroY = padT + plotH / 2;
  const getY = (deg) => zeroY - (deg / scaleDeg) * (plotH / 2);
  const getX = (idx) => padL + (validShots.length > 1 ? (idx / (validShots.length - 1)) * plotW : plotW / 2);

  const gridSteps = [-scaleDeg, -2, 0, 2, scaleDeg];
  let gridSvg = "";
  gridSteps.forEach((deg) => {
    const y = getY(deg);
    const isZero = deg === 0;
    const stroke = isZero ? "#22c55e" : "rgba(255, 255, 255, 0.08)";
    const dash = isZero ? "4 3" : "none";
    const label = isZero ? "🎯 0.0° Square" : `${deg > 0 ? "+" : ""}${deg}°`;
    gridSvg += `
      <line x1="${padL}" y1="${y}" x2="${width - padR}" y2="${y}" stroke="${stroke}" stroke-width="${isZero ? 2 : 1}" stroke-dasharray="${dash}" />
      <text x="${padL - 8}" y="${y + 4}" fill="${isZero ? "#22c55e" : "var(--muted)"}" font-size="10" font-weight="${isZero ? "700" : "500"}" text-anchor="end">${label}</text>
    `;
  });

  const win = Math.min(5, Math.max(2, Math.floor(validShots.length / 3)));
  const rollingFace = computeRollingAverage(validShots.map(s => s.faceAngle), win);
  const rollingPath = computeRollingAverage(validShots.map(s => s.clubPath), win);

  let facePath = "", pathPath = "";
  const faceCoords = [], pathCoords = [];
  rollingFace.forEach((val, i) => {
    if (val == null) return;
    const x = getX(i), y = getY(val);
    facePath += (facePath === "" ? `M ${x} ${y}` : ` L ${x} ${y}`);
    faceCoords.push({ i, x, y });
  });
  rollingPath.forEach((val, i) => {
    if (val == null) return;
    const x = getX(i), y = getY(val);
    pathPath += (pathPath === "" ? `M ${x} ${y}` : ` L ${x} ${y}`);
    pathCoords.push({ i, x, y });
  });

  // Shaded Face-to-Path gap polygon when both lines exist
  let gapPolygon = "";
  if (faceCoords.length >= 2 && pathCoords.length === faceCoords.length) {
    const topPts = faceCoords.map(c => `${c.x},${c.y}`).join(" ");
    const botPts = [...pathCoords].reverse().map(c => `${c.x},${c.y}`).join(" ");
    gapPolygon = `<polygon points="${topPts} ${botPts}" fill="rgba(245, 158, 11, 0.12)" />`;
  }

  let dotsSvg = "";
  validShots.forEach((s, i) => {
    const x = getX(i);
    if (s.faceAngle != null) {
      const faceStr = s.faceAngle === 0 ? "0.0° Square" : (s.faceAngle > 0 ? `${s.faceAngle}° Open` : `${Math.abs(s.faceAngle)}° Closed`);
      dotsSvg += `<circle cx="${x}" cy="${getY(s.faceAngle)}" r="3.5" fill="#f59e0b" stroke="#0b131e" stroke-width="1"><title>Shot #${s.index}: Face Angle ${faceStr}</title></circle>`;
    }
    if (s.clubPath != null) {
      const pathStr = s.clubPath === 0 ? "0.0° Straight" : (s.clubPath > 0 ? `${s.clubPath}° In-to-Out` : `${Math.abs(s.clubPath)}° Out-to-In`);
      dotsSvg += `<circle cx="${x}" cy="${getY(s.clubPath)}" r="3.5" fill="#38bdf8" stroke="#0b131e" stroke-width="1"><title>Shot #${s.index}: Club Path ${pathStr}</title></circle>`;
    }
  });

  const topZone = isLefty ? "OPEN FACE (L) / IN-TO-OUT (L) (+)" : "OPEN FACE (R) / IN-TO-OUT (R) (+)";
  const botZone = isLefty ? "CLOSED FACE (R) / OUT-TO-IN (R) (-)" : "CLOSED FACE (L) / OUT-TO-IN (L) (-)";

  return `
    <svg viewBox="0 0 ${width} ${height}" class="analytics-svg-chart" style="width:100%; height:auto;" aria-label="Face & Path Delivery Trend Chart">
      <text x="${padL + 10}" y="${padT + 12}" fill="rgba(255,255,255,0.35)" font-size="9" font-weight="600">${topZone}</text>
      <text x="${padL + 10}" y="${height - padB - 6}" fill="rgba(255,255,255,0.35)" font-size="9" font-weight="600">${botZone}</text>
      ${gridSvg}
      ${gapPolygon}
      ${facePath ? `<path d="${facePath}" fill="none" stroke="#f59e0b" stroke-width="2.5" stroke-linejoin="round" stroke-linecap="round" />` : ""}
      ${pathPath ? `<path d="${pathPath}" fill="none" stroke="#38bdf8" stroke-width="2.5" stroke-linejoin="round" stroke-linecap="round" />` : ""}
      ${dotsSvg}
      <text x="${padL}" y="${height - 12}" fill="var(--muted)" font-size="10">Oldest Shot</text>
      <text x="${width - padR}" y="${height - 12}" fill="var(--muted)" font-size="10" text-anchor="end">Latest Shot</text>
    </svg>
  `;
}

/**
 * Generates an SVG chart showing club-calibrated Smash Factor progression & optimal band.
 */
export function generateStrikeTrendChartSvg(shots, options = {}) {
  const validShots = shots.filter(s => (s.smash != null && s.smash > 0.5) || s.impactOffsetMm != null);
  if (validShots.length === 0) {
    return `<div class="empty-chart-fallback"><p>No smash factor or impact location telemetry recorded yet.</p></div>`;
  }

  const clubKey = options.clubKey && options.clubKey !== "all" ? options.clubKey : (validShots[validShots.length - 1]?.club || "driver");
  const skillLevel = normalizeSkillLevel(options.skillLevel);
  const bench = getClubBenchmark(clubKey, skillLevel);

  const width = options.width || 700;
  const height = options.height || 240;
  const padL = 60, padR = 25, padT = 25, padB = 40;
  const plotW = width - padL - padR;
  const plotH = height - padT - padB;

  const smashVals = validShots.map(s => s.smash).filter(v => v != null);
  const dataMin = smashVals.length ? Math.min(...smashVals) : bench.smash_min - 0.1;
  const dataMax = smashVals.length ? Math.max(...smashVals) : bench.smash_max + 0.04;

  const minSmash = round2(Math.max(0.85, Math.min(bench.smash_min - 0.16, dataMin - 0.04)));
  const maxSmash = round2(Math.min(1.56, Math.max(bench.smash_max + 0.05, dataMax + 0.03)));
  const span = Math.max(0.15, maxSmash - minSmash);

  const getY = (val) => padT + plotH - ((Math.max(minSmash, Math.min(maxSmash, val)) - minSmash) / span) * plotH;
  const getX = (idx) => padL + (validShots.length > 1 ? (idx / (validShots.length - 1)) * plotW : plotW / 2);

  const yOptTop = getY(bench.smash_max);
  const yOptBottom = getY(bench.smash_min);
  const optH = Math.max(4, yOptBottom - yOptTop);

  const steps = [minSmash, round2(minSmash + span * 0.35), bench.smash_min, bench.smash_max];
  const uniqueSteps = [...new Set(steps.map(v => v.toFixed(2)))].map(Number).sort((a, b) => a - b);

  let gridSvg = "";
  uniqueSteps.forEach((val) => {
    const y = getY(val);
    const isTour = val >= bench.smash_min;
    const stroke = isTour ? "rgba(34, 197, 94, 0.35)" : "rgba(255, 255, 255, 0.08)";
    gridSvg += `
      <line x1="${padL}" y1="${y}" x2="${width - padR}" y2="${y}" stroke="${stroke}" stroke-width="1" />
      <text x="${padL - 8}" y="${y + 4}" fill="${isTour ? "#22c55e" : "var(--muted)"}" font-size="10" font-weight="${isTour ? "700" : "500"}" text-anchor="end">${val.toFixed(2)}</text>
    `;
  });

  const rolling = computeRollingAverage(
    validShots.map(s => s.smash),
    Math.min(5, Math.max(2, Math.floor(validShots.length / 3)))
  );

  let trendPath = "";
  rolling.forEach((val, i) => {
    if (val == null) return;
    const x = getX(i), y = getY(val);
    trendPath += (trendPath === "" ? `M ${x} ${y}` : ` L ${x} ${y}`);
  });

  let dotsSvg = "";
  validShots.forEach((s, i) => {
    if (s.smash == null) return;
    const x = getX(i), y = getY(s.smash);
    const isGood = s.smash >= bench.smash_min;
    const isOk = s.smash >= bench.smash_min - 0.05;
    const dotCol = isGood ? "#22c55e" : (isOk ? "#eab308" : "#ef4444");
    dotsSvg += `
      <circle cx="${x}" cy="${y}" r="4" fill="${dotCol}" stroke="#0b131e" stroke-width="1.5">
        <title>Shot #${s.index} (${s.club || bench.name}): Smash ${s.smash.toFixed(2)}${s.impactOffsetMm != null ? ` • ${s.impactOffsetMm}mm off-center` : ""}</title>
      </circle>
    `;
  });

  const zoneTitle = `${options.clubKey === "all" ? "Bag" : bench.name} Optimal Smash (${bench.smash_min.toFixed(2)}–${bench.smash_max.toFixed(2)})`;

  return `
    <svg viewBox="0 0 ${width} ${height}" class="analytics-svg-chart" style="width:100%; height:auto;" aria-label="Smash Factor Strike Consistency Chart">
      <rect x="${padL}" y="${yOptTop}" width="${plotW}" height="${optH}" fill="rgba(34, 197, 94, 0.11)" rx="3" />
      <text x="${width - padR - 8}" y="${Math.max(padT + 12, yOptTop + 13)}" fill="rgba(34, 197, 94, 0.8)" font-size="10" font-weight="600" text-anchor="end">${zoneTitle}</text>
      ${gridSvg}
      ${trendPath ? `<path d="${trendPath}" fill="none" stroke="#22c55e" stroke-width="2.5" stroke-linejoin="round" stroke-linecap="round" />` : ""}
      ${dotsSvg}
      <text x="${padL}" y="${height - 12}" fill="var(--muted)" font-size="10">Oldest Shot</text>
      <text x="${width - padR}" y="${height - 12}" fill="var(--muted)" font-size="10" text-anchor="end">Latest Shot</text>
    </svg>
  `;
}

/**
 * Generates a 2D D-Plane Matrix SVG (Club Path X vs Face Angle Y) with Face = Path diagonal & 9 flight zones.
 */
export function generateDPlaneMatrixSvg(shots, options = {}) {
  const validShots = (shots || []).filter(s => s.faceAngle != null && s.clubPath != null);
  if (validShots.length === 0) {
    return `<div class="empty-chart-fallback"><p>D-Plane matrix requires both Club Path and Face Angle telemetry.</p></div>`;
  }

  const width = options.width || 520;
  const height = options.height || 300;
  const isLefty = Boolean(options.isLefty);
  const padL = 56, padR = 24, padT = 26, padB = 40;
  const plotW = width - padL - padR;
  const plotH = height - padT - padB;

  const maxAngle = validShots.reduce((m, s) => Math.max(m, Math.abs(s.faceAngle), Math.abs(s.clubPath)), 6);
  const lim = Math.max(6, Math.ceil(maxAngle / 2) * 2);

  const getX = (pathDeg) => padL + ((Math.max(-lim, Math.min(lim, pathDeg)) + lim) / (2 * lim)) * plotW;
  const getY = (faceDeg) => padT + plotH - ((Math.max(-lim, Math.min(lim, faceDeg)) + lim) / (2 * lim)) * plotH;
  const cx = getX(0), cy = getY(0);

  // Diagonal Face = Path (zero curve) line
  const diagStart = `${getX(-lim)},${getY(-lim)}`;
  const diagEnd = `${getX(lim)},${getY(lim)}`;

  let sumF = 0, sumP = 0, dots = "";
  validShots.forEach((s, i) => {
    sumF += s.faceAngle;
    sumP += s.clubPath;
    const x = getX(s.clubPath);
    const y = getY(s.faceAngle);
    const bf = classifyBallFlight(s.faceAngle, s.clubPath, s.faceToPath, isLefty);
    const col = bf.isFunctionalStock ? "#22c55e" : (Math.abs(s.faceToPath ?? 0) > 3.5 ? "#ef4444" : "#f59e0b");
    const opacity = (0.35 + (i / Math.max(1, validShots.length - 1)) * 0.65).toFixed(2);
    dots += `<circle cx="${x}" cy="${y}" r="4.5" fill="${col}" fill-opacity="${opacity}" stroke="#0b131e" stroke-width="1"><title>Shot #${s.index}: ${bf.shape} (Path ${s.clubPath}°, Face ${s.faceAngle}°, FTP ${s.faceToPath ?? round1(s.faceAngle - s.clubPath)}°)</title></circle>`;
  });

  const avgX = getX(sumP / validShots.length);
  const avgY = getY(sumF / validShots.length);

  return `
    <svg viewBox="0 0 ${width} ${height}" class="analytics-svg-chart" style="width:100%; height:auto;" aria-label="D-Plane 9-Flight Matrix">
      <rect x="${getX(-1.5)}" y="${getY(1.5)}" width="${getX(1.5) - getX(-1.5)}" height="${getY(-1.5) - getY(1.5)}" fill="rgba(34, 197, 94, 0.12)" rx="4" />
      <line x1="${padL}" y1="${cy}" x2="${width - padR}" y2="${cy}" stroke="rgba(255,255,255,0.2)" stroke-width="1" />
      <line x1="${cx}" y1="${padT}" x2="${cx}" y2="${height - padB}" stroke="rgba(255,255,255,0.2)" stroke-width="1" />
      <line x1="${diagStart.split(",")[0]}" y1="${diagStart.split(",")[1]}" x2="${diagEnd.split(",")[0]}" y2="${diagEnd.split(",")[1]}" stroke="rgba(56, 189, 248, 0.55)" stroke-width="1.5" stroke-dasharray="4 3" />
      <text x="${padL + 6}" y="${padT + 14}" fill="rgba(255,255,255,0.4)" font-size="9" font-weight="700">PULL-FADE / SLICE</text>
      <text x="${width - padR - 6}" y="${padT + 14}" fill="rgba(255,255,255,0.4)" font-size="9" font-weight="700" text-anchor="end">PUSH-DRAW (OPEN+I-O)</text>
      <text x="${padL + 6}" y="${height - padB - 6}" fill="rgba(255,255,255,0.4)" font-size="9" font-weight="700">PULL-HOOK (CLOSED+O-I)</text>
      <text x="${width - padR - 6}" y="${height - padB - 6}" fill="rgba(255,255,255,0.4)" font-size="9" font-weight="700" text-anchor="end">CLOSED + IN-TO-OUT</text>
      <text x="${padL - 8}" y="${cy + 3}" fill="var(--muted)" font-size="10" text-anchor="end">Face 0°</text>
      <text x="${padL - 8}" y="${padT + 8}" fill="var(--muted)" font-size="9" text-anchor="end">+${lim}° Open</text>
      <text x="${padL - 8}" y="${height - padB}" fill="var(--muted)" font-size="9" text-anchor="end">-${lim}° Closed</text>
      <text x="${cx}" y="${height - 12}" fill="var(--muted)" font-size="10" text-anchor="middle">Club Path (°)  [ - Out-In | + In-Out ]</text>
      ${dots}
      <circle cx="${avgX}" cy="${avgY}" r="7" fill="none" stroke="#ffffff" stroke-width="2.2"><title>Session Average: Path ${(sumP / validShots.length).toFixed(1)}°, Face ${(sumF / validShots.length).toFixed(1)}°</title></circle>
      <circle cx="${avgX}" cy="${avgY}" r="2.5" fill="#ffffff" />
    </svg>
  `;
}

/**
 * Generates a Launch Optimizer scatter SVG (Launch Angle VLA vs Spin RPM) with club/skill optimal box.
 */
export function generateLaunchOptimizerSvg(shots, options = {}) {
  const validShots = (shots || []).filter(s => s.vla != null && s.totalSpin != null);
  if (validShots.length === 0) {
    return `<div class="empty-chart-fallback"><p>Launch Optimizer requires Launch Angle (VLA) and Spin Rate telemetry.</p></div>`;
  }

  const clubKey = options.clubKey && options.clubKey !== "all" ? options.clubKey : (validShots[validShots.length - 1]?.club || "driver");
  const bench = getClubBenchmark(clubKey, normalizeSkillLevel(options.skillLevel));

  const width = options.width || 520;
  const height = options.height || 300;
  const padL = 62, padR = 24, padT = 24, padB = 40;
  const plotW = width - padL - padR;
  const plotH = height - padT - padB;

  const vlaMin = Math.max(0, Math.floor(Math.min(bench.vla_min - 4, ...validShots.map(s => s.vla)) - 1));
  const vlaMax = Math.ceil(Math.max(bench.vla_max + 4, ...validShots.map(s => s.vla)) + 1);
  const spinMin = Math.max(500, Math.floor(Math.min(bench.spin_min - 800, ...validShots.map(s => s.totalSpin)) / 500) * 500);
  const spinMax = Math.ceil(Math.max(bench.spin_max + 1200, ...validShots.map(s => s.totalSpin)) / 500) * 500;

  const getX = (vla) => padL + ((vla - vlaMin) / Math.max(1, vlaMax - vlaMin)) * plotW;
  const getY = (sp) => padT + plotH - ((sp - spinMin) / Math.max(500, spinMax - spinMin)) * plotH;

  const boxX = getX(bench.vla_min);
  const boxW = Math.max(8, getX(bench.vla_max) - boxX);
  const boxY = getY(bench.spin_max);
  const boxH = Math.max(8, getY(bench.spin_min) - boxY);

  let dots = "", sumV = 0, sumS = 0;
  validShots.forEach((s) => {
    sumV += s.vla;
    sumS += s.totalSpin;
    const inBox = s.vla >= bench.vla_min && s.vla <= bench.vla_max && s.totalSpin >= bench.spin_min && s.totalSpin <= bench.spin_max;
    const col = inBox ? "#22c55e" : "#f59e0b";
    dots += `<circle cx="${getX(s.vla)}" cy="${getY(s.totalSpin)}" r="4.2" fill="${col}" stroke="#0b131e" stroke-width="1"><title>Shot #${s.index}: ${s.vla}° VLA • ${s.totalSpin.toLocaleString()} rpm</title></circle>`;
  });

  const avgX = getX(sumV / validShots.length);
  const avgY = getY(sumS / validShots.length);

  return `
    <svg viewBox="0 0 ${width} ${height}" class="analytics-svg-chart" style="width:100%; height:auto;" aria-label="Launch Angle vs Spin Optimizer">
      <rect x="${boxX}" y="${boxY}" width="${boxW}" height="${boxH}" fill="rgba(34, 197, 94, 0.14)" stroke="rgba(34, 197, 94, 0.65)" stroke-width="1.5" rx="4" />
      <text x="${boxX + boxW / 2}" y="${Math.max(padT + 12, boxY - 5)}" fill="#4ade80" font-size="9" font-weight="700" text-anchor="middle">${bench.name} Optimal Window</text>
      <line x1="${padL}" y1="${padT}" x2="${padL}" y2="${height - padB}" stroke="rgba(255,255,255,0.18)" />
      <line x1="${padL}" y1="${height - padB}" x2="${width - padR}" y2="${height - padB}" stroke="rgba(255,255,255,0.18)" />
      <text x="${padL - 8}" y="${padT + 8}" fill="var(--muted)" font-size="9" text-anchor="end">${spinMax.toLocaleString()} rpm</text>
      <text x="${padL - 8}" y="${height - padB}" fill="var(--muted)" font-size="9" text-anchor="end">${spinMin.toLocaleString()} rpm</text>
      <text x="${padL}" y="${height - 12}" fill="var(--muted)" font-size="9">${vlaMin}° VLA</text>
      <text x="${width - padR}" y="${height - 12}" fill="var(--muted)" font-size="9" text-anchor="end">${vlaMax}° VLA</text>
      <text x="${padL + plotW / 2}" y="${height - 12}" fill="var(--muted)" font-size="10" text-anchor="middle">Launch Angle (VLA°)</text>
      ${dots}
      <circle cx="${avgX}" cy="${avgY}" r="6.5" fill="none" stroke="#ffffff" stroke-width="2"><title>Average: ${(sumV / validShots.length).toFixed(1)}° • ${Math.round(sumS / validShots.length).toLocaleString()} rpm</title></circle>
      <circle cx="${avgX}" cy="${avgY}" r="2.2" fill="#ffffff" />
    </svg>
  `;
}

/**
 * Generates a Top-Down Covariance Dispersion Target SVG (Fairway corridor or Green + 15'/30' rings).
 */
export function generateDispersionTargetSvg(shots, options = {}) {
  const validShots = (shots || []).filter(s => s.carryYds > 0);
  if (validShots.length === 0) {
    return `<div class="empty-chart-fallback"><p>Hit shots with carry distance recorded to plot top-down landing dispersion.</p></div>`;
  }

  const clubKey = options.clubKey && options.clubKey !== "all" ? options.clubKey : (validShots[validShots.length - 1]?.club || "driver");
  const clubCat = classifyClubCategory(clubKey);
  const isGreen = ["long_iron", "mid_iron", "wedge"].includes(clubCat);
  const corridorYds = options.corridorYds || getTargetCorridorYds(clubKey);

  const width = options.width || 520;
  const height = options.height || 300;
  const padL = 56, padR = 24, padT = 22, padB = 34;
  const plotW = width - padL - padR;
  const plotH = height - padT - padB;

  const carries = validShots.map(s => s.carryYds);
  const avgCarry = carries.reduce((a, b) => a + b, 0) / carries.length;
  const maxOff = Math.max(corridorYds + 6, ...validShots.map(s => s.absOfflineYds + 4));
  const minC = Math.max(0, Math.floor(Math.min(...carries) / 10) * 10 - 15);
  const maxC = Math.ceil(Math.max(...carries) / 10) * 10 + 15;

  const getX = (offYds) => padL + ((offYds + maxOff) / (2 * maxOff)) * plotW;
  const getY = (carry) => padT + plotH - ((carry - minC) / Math.max(10, maxC - minC)) * plotH;
  const centerX = getX(0);
  const pinY = getY(avgCarry);

  // Target background: Fairway corridor or Green + rings
  let targetBg = "";
  if (isGreen) {
    const rxGreen = Math.max(18, Math.abs(getX(12) - centerX));
    const ryGreen = Math.max(18, Math.abs(getY(avgCarry + 12) - pinY));
    const r30 = Math.max(10, Math.abs(getX(10) - centerX)); // 30 ft = 10 yds
    targetBg = `
      <ellipse cx="${centerX}" cy="${pinY}" rx="${rxGreen}" ry="${ryGreen}" fill="rgba(34, 197, 94, 0.14)" stroke="rgba(74, 222, 128, 0.45)" stroke-width="1.5" />
      <circle cx="${centerX}" cy="${pinY}" r="${r30}" fill="none" stroke="rgba(74, 222, 128, 0.35)" stroke-dasharray="3 3" />
      <circle cx="${centerX}" cy="${pinY}" r="3.5" fill="#fde047" />
    `;
  } else {
    const fLeft = getX(-corridorYds);
    const fWidth = getX(corridorYds) - fLeft;
    targetBg = `
      <rect x="${fLeft}" y="${padT}" width="${fWidth}" height="${plotH}" fill="rgba(34, 197, 94, 0.10)" stroke="rgba(34, 197, 94, 0.35)" stroke-dasharray="4 3" rx="4" />
      <text x="${fLeft + fWidth / 2}" y="${padT + 14}" fill="rgba(74, 222, 128, 0.75)" font-size="9" font-weight="700" text-anchor="middle">±${corridorYds} yd Fairway</text>
    `;
  }

  // Covariance ellipse in screen space
  const ptsScreen = validShots.map(s => ({ x: getX(s.signedOfflineYds), y: getY(s.carryYds) }));
  const ell = computeCovarianceEllipse(ptsScreen);
  let ellipseSvg = "";
  if (ell.valid && ell.rx80 > 2 && ell.ry80 > 2) {
    const deg = (ell.angleRad * 180) / Math.PI;
    ellipseSvg = `
      <ellipse cx="${ell.meanX}" cy="${ell.meanY}" rx="${ell.rx80}" ry="${ell.ry80}"
        transform="rotate(${deg.toFixed(1)} ${ell.meanX} ${ell.meanY})"
        fill="rgba(56, 189, 248, 0.12)" stroke="#38bdf8" stroke-width="2" />
    `;
  }

  let dots = "";
  validShots.forEach((s) => {
    const col = s.absOfflineYds <= corridorYds ? "#22c55e" : (s.absOfflineYds <= corridorYds * 1.7 ? "#eab308" : "#ef4444");
    dots += `<circle cx="${getX(s.signedOfflineYds)}" cy="${getY(s.carryYds)}" r="3.8" fill="${col}" stroke="#0b131e" stroke-width="1"><title>Shot #${s.index}: ${s.carryYds} yds carry • ${s.signedOfflineYds >= 0 ? s.signedOfflineYds + "R" : Math.abs(s.signedOfflineYds) + "L"}</title></circle>`;
  });

  return `
    <svg viewBox="0 0 ${width} ${height}" class="analytics-svg-chart" style="width:100%; height:auto;" aria-label="Top-Down Covariance Dispersion Target">
      ${targetBg}
      <line x1="${centerX}" y1="${padT}" x2="${centerX}" y2="${height - padB}" stroke="rgba(255,255,255,0.22)" stroke-dasharray="3 3" />
      ${ellipseSvg}
      ${dots}
      <text x="${padL - 6}" y="${padT + 10}" fill="var(--muted)" font-size="9" text-anchor="end">${maxC} yd</text>
      <text x="${padL - 6}" y="${height - padB}" fill="var(--muted)" font-size="9" text-anchor="end">${minC} yd</text>
      <text x="${padL}" y="${height - 10}" fill="var(--muted)" font-size="9">-${Math.round(maxOff)} yds Left</text>
      <text x="${centerX}" y="${height - 10}" fill="var(--muted)" font-size="9" text-anchor="middle">Target Line</text>
      <text x="${width - padR}" y="${height - 10}" fill="var(--muted)" font-size="9" text-anchor="end">+${Math.round(maxOff)} yds Right</text>
    </svg>
  `;
}

const BAG_SORT_ORDER = [
  "Dr", "3w", "5w", "7w", "2H", "3H", "4H", "5H",
  "1i", "2i", "3i", "4i", "5i", "6i", "7i", "8i", "9i",
  "Pw", "Gw", "Sw", "Lw"
];

/**
 * Generates a Full-Bag Gapping & Consistency Waterfall SVG from clubSummary.
 */
export function generateBagGappingChartSvg(clubSummary, options = {}) {
  if (!clubSummary || typeof clubSummary !== "object") return "";
  const entries = [];

  BAG_SORT_ORDER.forEach((orderKey) => {
    const matchKey = Object.keys(clubSummary).find(k => k.toLowerCase() === orderKey.toLowerCase());
    if (!matchKey) return;
    const s = clubSummary[matchKey];
    if (!s || !s.count || Number(s.carry_yds || 0) <= 0) return;
    const carry = Number(s.carry_yds || 0);
    const total = Math.max(carry, Number(s.total_yds || carry));
    entries.push({ club: matchKey, carry, total, rollout: Math.max(0, total - carry), count: s.count });
  });

  if (entries.length < 2) return "";

  const width = options.width || 720;
  const rowH = 30;
  const padL = 70, padR = 110, padT = 28, padB = 22;
  const height = padT + padB + entries.length * rowH;
  const plotW = width - padL - padR;
  const maxDist = Math.max(100, Math.ceil(Math.max(...entries.map(e => e.total)) / 25) * 25 + 15);
  const getX = (yds) => padL + (yds / maxDist) * plotW;

  let rowsSvg = "";
  entries.forEach((e, idx) => {
    const y = padT + idx * rowH;
    const carryW = Math.max(4, getX(e.carry) - padL);
    const rollW = Math.max(0, getX(e.total) - getX(e.carry));

    let gapText = "";
    let gapCol = "#94a3b8";
    if (idx > 0) {
      const gap = Math.round(entries[idx - 1].carry - e.carry);
      if (gap < 8) {
        gapText = `⚠ ${gap}y overlap`;
        gapCol = "#f59e0b";
      } else if (gap > 18) {
        gapText = `⚠ ${gap}y gap`;
        gapCol = "#ef4444";
      } else {
        gapText = `${gap}y gap`;
        gapCol = "#4ade80";
      }
    }

    rowsSvg += `
      <text x="${padL - 8}" y="${y + 15}" fill="#e2e8f0" font-size="11" font-weight="700" text-anchor="end">${e.club}</text>
      <rect x="${padL}" y="${y + 4}" width="${carryW}" height="15" fill="#22c55e" rx="3" opacity="0.88" />
      ${rollW > 1 ? `<rect x="${padL + carryW}" y="${y + 4}" width="${rollW}" height="15" fill="#38bdf8" rx="2" opacity="0.7" />` : ""}
      <text x="${padL + carryW + rollW + 6}" y="${y + 15}" fill="#cbd5e1" font-size="10">${Math.round(e.carry)} / ${Math.round(e.total)} yd</text>
      ${gapText ? `<text x="${width - 6}" y="${y + 15}" fill="${gapCol}" font-size="9.5" font-weight="700" text-anchor="end">${gapText}</text>` : ""}
    `;
  });

  return `
    <svg viewBox="0 0 ${width} ${height}" class="analytics-svg-chart" style="width:100%; height:auto;" aria-label="Full-Bag Gapping Chart">
      <text x="${padL}" y="16" fill="#4ade80" font-size="10" font-weight="700">■ Carry Yards</text>
      <text x="${padL + 95}" y="16" fill="#38bdf8" font-size="10" font-weight="700">■ Rollout</text>
      <text x="${width - 6}" y="16" fill="var(--muted)" font-size="10" text-anchor="end">Adjacent Carry Gap</text>
      ${rowsSvg}
    </svg>
  `;
}

/**
 * Generates a Session-over-Session progression SVG comparing offline dispersion & smash across sessions.
 */
export function generateSessionTrendChartSvg(sessions, options = {}) {
  if (!Array.isArray(sessions) || sessions.length < 2) return "";

  const width = options.width || 700;
  const height = options.height || 200;
  const padL = 55, padR = 55, padT = 26, padB = 38;
  const plotW = width - padL - padR;
  const plotH = height - padT - padB;

  const maxOff = Math.max(15, ...sessions.map(s => s.summary.avgAbsOffline + 2));
  const getX = (i) => padL + (i / (sessions.length - 1)) * plotW;
  const getOffY = (v) => padT + plotH - (v / maxOff) * plotH;
  const getSmashY = (v) => padT + plotH - ((Math.max(1.0, Math.min(1.52, v)) - 1.0) / 0.52) * plotH;

  let offPath = "", smashPath = "", pointsSvg = "";
  sessions.forEach((sess, i) => {
    const x = getX(i);
    const yOff = getOffY(sess.summary.avgAbsOffline);
    offPath += (offPath === "" ? `M ${x} ${yOff}` : ` L ${x} ${yOff}`);
    pointsSvg += `<circle cx="${x}" cy="${yOff}" r="4.5" fill="#38bdf8" stroke="#0b131e" stroke-width="1.5"><title>${sess.label} (${sess.shotCount} shots): ±${sess.summary.avgAbsOffline} yds offline</title></circle>`;
    pointsSvg += `<text x="${x}" y="${height - 12}" fill="var(--muted)" font-size="9.5" text-anchor="middle">${sess.label}</text>`;

    if (sess.summary.avgSmash != null) {
      const ySm = getSmashY(sess.summary.avgSmash);
      smashPath += (smashPath === "" ? `M ${x} ${ySm}` : ` L ${x} ${ySm}`);
      pointsSvg += `<circle cx="${x}" cy="${ySm}" r="4" fill="#22c55e" stroke="#0b131e" stroke-width="1.5"><title>${sess.label}: ${sess.summary.avgSmash.toFixed(2)} Smash</title></circle>`;
    }
  });

  return `
    <svg viewBox="0 0 ${width} ${height}" class="analytics-svg-chart" style="width:100%; height:auto;" aria-label="Session-over-Session Progression">
      <line x1="${padL}" y1="${height - padB}" x2="${width - padR}" y2="${height - padB}" stroke="rgba(255,255,255,0.15)" />
      <text x="${padL - 6}" y="${padT + 8}" fill="#38bdf8" font-size="9" text-anchor="end">±${Math.round(maxOff)}y</text>
      <text x="${padL - 6}" y="${height - padB}" fill="#38bdf8" font-size="9" text-anchor="end">0y Off</text>
      <text x="${width - padR + 6}" y="${padT + 8}" fill="#22c55e" font-size="9">1.52 Sm</text>
      <text x="${width - padR + 6}" y="${height - padB}" fill="#22c55e" font-size="9">1.00 Sm</text>
      <path d="${offPath}" fill="none" stroke="#38bdf8" stroke-width="2.5" stroke-linejoin="round" />
      ${smashPath ? `<path d="${smashPath}" fill="none" stroke="#22c55e" stroke-width="2.5" stroke-dasharray="5 3" stroke-linejoin="round" />` : ""}
      ${pointsSvg}
    </svg>
  `;
}

/**
 * Generates prioritized, handedness-aware, club-calibrated, gear-effect-aware coaching insights
 * ranked by estimated strokes-gained impact.
 */
export function generateCoachingInsights(analytics) {
  if (!analytics || !analytics.hasData || analytics.totalShots < 2) {
    return [
      {
        icon: "💡",
        title: "Log More Swings",
        desc: "Hit a series of shots on the launch monitor to uncover your directional dispersion, D-plane flight pattern, and incremental focus plan.",
        isIssue: false,
        strokesImpact: 0
      }
    ];
  }

  const { recent, offline, face, path, faceToPath, smash, impact, isLefty, clubKey, skillLevel, benchmark, distanceLoss, fatigue } = analytics;
  const effectiveClub = clubKey && clubKey !== "all" ? clubKey : "driver";
  const bench = benchmark || getClubBenchmark(effectiveClub, skillLevel || "mid_handicap");
  const clubCat = classifyClubCategory(effectiveClub);
  const insights = [];

  // Gear-effect detection: when strike is clearly Toe or Heel with neutral Face-to-Path
  const hasToeGearHook = recent.avgHi != null && recent.avgHi >= 6.0 && (recent.avgSpinAxis ?? 0) <= -4.0 && (recent.avgAbsFtp == null || recent.avgAbsFtp <= 2.2);
  const hasHeelGearSlice = recent.avgHi != null && recent.avgHi <= -6.0 && (recent.avgSpinAxis ?? 0) >= 4.0 && (recent.avgAbsFtp == null || recent.avgAbsFtp <= 2.2);
  const hasLowFaceSpin = clubCat === "driver" && recent.avgVi != null && recent.avgVi <= -6.0 && (recent.avgSpin ?? 0) > bench.spin_max;

  if (hasToeGearHook) {
    insights.push({
      icon: "📍",
      title: "Toe Strike Gear-Effect Hook (Not a Closed Face)",
      desc: `Contact averages ${recent.avgHi.toFixed(1)} mm toward the toe while Face-to-Path is neutral (${recent.avgAbsFtp != null ? recent.avgAbsFtp.toFixed(1) + "°" : "square"}). Gear effect—not a closed face—is creating the hook spin.`,
      isIssue: true,
      issueKey: "toe_gear_hook",
      strokesImpact: 3.4
    });
  } else if (hasHeelGearSlice) {
    insights.push({
      icon: "📍",
      title: "Heel Strike Gear-Effect Slice",
      desc: `Contact averages ${Math.abs(recent.avgHi).toFixed(1)} mm toward the heel while delivery path/face remain fairly neutral. Centering contact slightly away from the hosel eliminates heel gear-effect fade/slice.`,
      isIssue: true,
      issueKey: "heel_gear_slice",
      strokesImpact: 3.4
    });
  }

  if (hasLowFaceSpin) {
    insights.push({
      icon: "🚀",
      title: "Low-Face Driver Strike Spiking Spin",
      desc: `Average impact is ${Math.abs(recent.avgVi).toFixed(1)} mm low on the face with ${recent.avgSpin.toLocaleString()} rpm spin. Teeing slightly higher and catching center-high immediately drops spin and adds carry.`,
      isIssue: true,
      issueKey: "low_face_spin",
      strokesImpact: 2.8
    });
  }

  // 1. Offline Dispersion & Miss Pattern (One-Way vs Two-Way vs Aim Shift)
  if (recent.missAttribution?.missPattern === "two_way_miss") {
    insights.push({
      icon: "⚠️",
      title: "Two-Way Miss Pattern Detected",
      desc: `Shots are missing both left (${recent.pctLeft}%) and right (${recent.pctRight}%) with ±${recent.stdDevOffline.toFixed(1)} yds spread. Focus on 80% tempo and face stability before adjusting aim.`,
      isIssue: true,
      issueKey: "two_way_miss",
      strokesImpact: 3.6
    });
  } else if (offline.status === "improving") {
    insights.push({
      icon: "🎯",
      title: "Dispersion Tightening Towards Target Centerline",
      desc: `Lateral dispersion improved by ${Math.abs(offline.delta).toFixed(1)} yds (now ±${recent.avgAbsOffline.toFixed(1)} yds avg, ${recent.pctInFairway}% inside ±${recent.corridorYds} yd corridor).`,
      isIssue: false,
      strokesImpact: 1.5
    });
  } else if (offline.status === "expanding" || recent.pctInFairway < 45) {
    const missSide = recent.avgSignedOffline < 0 ? "left" : "right";
    const aimHint = recent.aimShift.gainPct >= 10
      ? ` Shifting aim ${recent.aimShift.shiftYds} yds ${recent.aimShift.shiftDir} would immediately raise corridor hits from ${recent.pctInFairway}% → ${recent.aimShift.projectedPctInFairway}%.`
      : "";
    insights.push({
      icon: "⚠️",
      title: recent.missAttribution?.missPattern === "one_way_bias" ? `Consistent ${missSide.toUpperCase()} Miss Bias` : "Dispersion Expanding Off-Centerline",
      desc: `Shots average ${Math.abs(recent.avgSignedOffline).toFixed(1)} yds ${missSide} (${recent.pctInFairway}% inside ±${recent.corridorYds} yds). ${recent.missAttribution.startPct}% is start line, ${recent.missAttribution.curvePct}% is curve.${aimHint}`,
      isIssue: true,
      issueKey: "offline_expanding",
      strokesImpact: 3.0
    });
  }

  // 2. Functional Stock Ball Flight vs Real Face/Path Flaw
  const functionalStockDominant = recent.ballFlight?.pctFunctionalStock >= 60 && recent.pctInFairway >= 55;
  if (functionalStockDominant) {
    insights.push({
      icon: "✨",
      title: `Functional Stock ${recent.ballFlight.dominantShape} (${recent.ballFlight.pctFunctionalStock}% of Swings)`,
      desc: `Your face and path complement each other into a playable ${recent.ballFlight.dominantShape} landing reliably in the target corridor. Protect this stock shape rather than chasing 0.0°.`,
      isIssue: false,
      strokesImpact: 0.5
    });
  } else {
    // Face Angle
    if (face.status === "improving") {
      insights.push({
        icon: "🏌️",
        title: "Club Face Squaring Up to Target",
        desc: `Club face angle moved ${Math.abs(face.delta).toFixed(1)}° closer to 0.0° square than baseline, stabilizing initial start line.`,
        isIssue: false,
        strokesImpact: 1.2
      });
    } else if (!hasToeGearHook && !hasHeelGearSlice && (face.status === "expanding" || (recent.avgAbsFace != null && recent.avgAbsFace >= 2.5))) {
      const faceTendency = (recent.avgSignedFace ?? 0) >= 0 ? "open" : "closed";
      const startWord = faceTendency === "open" ? (isLefty ? "left" : "right") : (isLefty ? "right" : "left");
      insights.push({
        icon: "🔄",
        title: `Club Face Drifting ${faceTendency.toUpperCase()} at Impact`,
        desc: `Face averages ${Math.abs(recent.avgSignedFace ?? 0).toFixed(1)}° ${faceTendency} (starting the ball ${startWord}). Stabilize lead-wrist angle through impact to square your start line.`,
        isIssue: true,
        issueKey: faceTendency === "open" ? "face_open" : "face_closed",
        strokesImpact: 2.9
      });
    }

    // Swing Path
    if (path.status === "improving") {
      insights.push({
        icon: "📐",
        title: "Swing Path Straightening Down Target Line",
        desc: `Swing path improved ${Math.abs(path.delta).toFixed(1)}° closer to neutral (0.0°).`,
        isIssue: false,
        strokesImpact: 1.1
      });
    } else if (path.status === "expanding" || (recent.avgAbsPath != null && recent.avgAbsPath >= 3.0)) {
      const pathTendency = (recent.avgSignedPath ?? 0) > 0 ? "in-to-out" : "out-to-in";
      insights.push({
        icon: "📐",
        title: `Prominent ${pathTendency.toUpperCase()} Swing Path`,
        desc: `Swing path averages ${Math.abs(recent.avgSignedPath ?? 0).toFixed(1)}° ${pathTendency}. ${pathTendency === "out-to-in" ? "Drop the club from the inside in transition to stop cutting across the ball." : "Turn your chest through impact so your arms don't get trapped behind you."}`,
        isIssue: true,
        issueKey: pathTendency === "out-to-in" ? "path_out_to_in" : "path_in_to_out",
        strokesImpact: 2.6
      });
    }

    // Face-to-Path
    if (faceToPath.status === "improving") {
      insights.push({
        icon: "✨",
        title: "Tighter Face-to-Path Alignment",
        desc: `Face-to-path narrowed to ${recent.avgAbsFtp.toFixed(1)}°, producing noticeably straighter curvature.`,
        isIssue: false,
        strokesImpact: 1.0
      });
    } else if (!hasToeGearHook && !hasHeelGearSlice && (faceToPath.status === "expanding" || (recent.avgAbsFtp != null && recent.avgAbsFtp >= 3.0))) {
      insights.push({
        icon: "🌀",
        title: "Elevated Face-to-Path Curvature",
        desc: `Face-to-path gap averages ${recent.avgAbsFtp.toFixed(1)}°, creating ${isLefty ? ((recent.avgSignedFtp ?? 0) > 0 ? "leftward fade/slice" : "rightward draw/hook") : ((recent.avgSignedFtp ?? 0) > 0 ? "rightward fade/slice" : "leftward draw/hook")} curve.`,
        isIssue: true,
        issueKey: "face_to_path_curve",
        strokesImpact: 3.1
      });
    }
  }

  // 3. Strike Quality, Smash & Distance Loss Breakdown
  if (smash.status === "improving") {
    insights.push({
      icon: "⚡",
      title: "Cleaner Ball Strike & Energy Transfer",
      desc: `Smash factor rose to ${recent.avgSmash.toFixed(2)} (target ${bench.smash_min.toFixed(2)}–${bench.smash_max.toFixed(2)}), unlocking stronger ball speed.`,
      isIssue: false,
      strokesImpact: 1.3
    });
  } else if (smash.status === "declining" || (recent.avgSmash != null && recent.avgSmash < bench.smash_min - 0.03)) {
    insights.push({
      icon: "⚡",
      title: `Sub-Optimal ${bench.name} Smash Factor (${recent.avgSmash.toFixed(2)})`,
      desc: `Below your ${bench.smash_min.toFixed(2)}–${bench.smash_max.toFixed(2)} benchmark${distanceLoss?.smashLossYds >= 3 ? ` (~${distanceLoss.smashLossYds} yds of missing carry)` : ""}. Focus on centered strikes at 80% tempo.`,
      isIssue: true,
      issueKey: "low_smash",
      strokesImpact: 3.2
    });
  }

  if (impact.status === "improving") {
    insights.push({
      icon: "🎯",
      title: "Contact Centered on Sweet Spot",
      desc: `Impact moved ${Math.abs(impact.delta).toFixed(1)} mm closer to dead center (${recent.avgImpactOffsetMm.toFixed(1)} mm avg).`,
      isIssue: false,
      strokesImpact: 1.2
    });
  } else if (!hasToeGearHook && !hasHeelGearSlice && recent.avgImpactOffsetMm != null && recent.avgImpactOffsetMm >= 8.0) {
    const hBias = recent.avgHi > 1 ? "toe-side" : (recent.avgHi < -1 ? "heel-side" : "centered");
    const vBias = recent.avgVi > 1 ? "high-face" : (recent.avgVi < -1 ? "low-face" : "");
    insights.push({
      icon: "📍",
      title: "Off-Center Face Strike Pattern",
      desc: `Contact averages ${recent.avgImpactOffsetMm.toFixed(1)} mm off-center (${[hBias, vBias].filter(Boolean).join(", ")}). Centering contact recovers lost ball speed immediately.`,
      isIssue: true,
      issueKey: "off_center_strike",
      strokesImpact: 2.7
    });
  }

  // 4. Spin Loft, Launch Window & Green-Holding Stopping Power
  if (recent.avgSpinLoft != null && ["long_iron", "mid_iron", "wedge"].includes(clubCat)) {
    if (recent.avgSpinLoft > bench.spin_loft_max + 2.5 && (recent.avgSmash == null || recent.avgSmash < bench.smash_min)) {
      insights.push({
        icon: "🔧",
        title: `High Spin Loft / Early Release (${recent.avgSpinLoft.toFixed(1)}°)`,
        desc: `Dynamic loft minus AoA is above your ${bench.name} target (${bench.spin_loft_min}–${bench.spin_loft_max}°), indicating added loft/flipping at impact.`,
        isIssue: true,
        issueKey: "high_spin_loft",
        strokesImpact: 2.5
      });
    }
  }

  if (recent.stoppingPower?.grade === "Low Stopping Power") {
    insights.push({
      icon: "⛳",
      title: `Low Green-Stopping Power (${recent.stoppingPower.avgDescentAngle != null ? recent.stoppingPower.avgDescentAngle.toFixed(1) + "° Descent" : recent.stoppingPower.avgSpin + " rpm"})`,
      desc: `${bench.name} approaches need ≥${bench.land_angle_min}° descent angle and sufficient spin to hold greens instead of releasing off the back.`,
      isIssue: true,
      issueKey: "low_descent_angle",
      strokesImpact: 2.3
    });
  } else if (clubKey !== "all" && recent.avgSpin != null && recent.avgVla != null) {
    if (clubCat === "driver" && recent.avgSpin > bench.spin_max + 400 && recent.avgVla < bench.vla_min) {
      insights.push({
        icon: "🚀",
        title: "High Spin / Low Launch Driver Window",
        desc: `Averaging ${recent.avgSpin.toLocaleString()} rpm spin at ${recent.avgVla.toFixed(1)}° launch (target ${bench.vla_min}–${bench.vla_max}°, ${bench.spin_min}–${bench.spin_max} rpm). Sweeping upward adds carry.`,
        isIssue: true,
        issueKey: "high_spin",
        strokesImpact: 2.4
      });
    }
  }

  // 5. Distance Loss Summary & Fatigue Drift
  if (distanceLoss?.hasData && distanceLoss.totalLostYds >= 8 && clubKey !== "all") {
    insights.push({
      icon: "📏",
      title: `Missing ${distanceLoss.totalLostYds.toFixed(0)} yds at Your Swing Speed`,
      desc: `At ${recent.avgClubSpeed ? recent.avgClubSpeed.toFixed(1) + " mph club speed" : recent.avgBallSpeed?.toFixed(1) + " mph ball speed"}, optimal carry is ~${distanceLoss.potentialCarryYds.toFixed(0)} yds: Strike (${distanceLoss.smashLossYds}y), Launch/Spin (${distanceLoss.launchSpinLossYds}y), Curve (${distanceLoss.curveLossYds}y).`,
      isIssue: false,
      strokesImpact: 1.8
    });
  }

  if (fatigue?.isFatigued) {
    insights.push({
      icon: "🔋",
      title: `Late-Session Fatigue Drift Detected (${fatigue.shotCount} Shots)`,
      desc: `Last 10 shots drifted ${fatigue.offlineDrift > 0 ? "+" + fatigue.offlineDrift + " yds offline" : ""} ${fatigue.carryDrift < -4 ? `and lost ${Math.abs(fatigue.carryDrift)} yds carry` : ""} vs your opening 10 swings. Take a 60-second breather every 15 balls.`,
      isIssue: true,
      issueKey: "fatigue_drift",
      strokesImpact: 2.0
    });
  }

  insights.sort((a, b) => (b.strokesImpact || 0) - (a.strokesImpact || 0));
  return insights;
}
