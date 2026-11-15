// Heckle Golf Simulator - Player Portal Improvement Analytics Engine
// Computes trend analysis, delivery comparisons, rolling averages, SVG charts, and coaching insights.

/**
 * Normalizes a raw shot object from Firestore sync/stats into consistent telemetry units.
 * Distances converted to yards, impact offsets in mm, angles in degrees.
 */
export function normalizeShot(raw, index = 0) {
  if (!raw || typeof raw !== "object") return null;

  // Timestamp
  const t = Number(raw.t ?? raw.timestamp ?? raw.created_at ?? index);
  const id = String(raw.id ?? `shot_${index}`);
  const club = String(raw.club ?? raw.Club ?? raw.c_name ?? "").trim();

  // Distances: stored in meters in Firestore sync/stats; convert to yards (* 1.09361)
  const carryRaw = Number(raw.CarryDistance ?? raw.c ?? raw.carry_yds ?? raw.carry_m ?? 0);
  const carryYds = raw.carry_yds != null ? Number(raw.carry_yds) : carryRaw * 1.09361;

  const totalRaw = Number(raw.TotalDistance ?? raw.tot ?? raw.total_yds ?? raw.total_m ?? carryRaw);
  const totalYds = raw.total_yds != null ? Number(raw.total_yds) : totalRaw * 1.09361;

  // Offline / Side Distance: meters -> yards
  // Negative = Left, Positive = Right
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

  // Delivery angles (null if launch monitor doesn't support them)
  let faceAngle = null;
  if (raw.FaceAngle != null || raw.ClubFaceAngle != null || raw.fa != null) {
    faceAngle = Number(raw.FaceAngle ?? raw.ClubFaceAngle ?? raw.fa);
  }

  let clubPath = null;
  if (raw.ClubPath != null || raw.Path != null || raw.cp != null) {
    clubPath = Number(raw.ClubPath ?? raw.Path ?? raw.cp);
  }

  let faceToPath = null;
  if (raw.FaceToPath != null || raw.ftp != null) {
    faceToPath = Number(raw.FaceToPath ?? raw.ftp);
  } else if (faceAngle != null && clubPath != null) {
    faceToPath = faceAngle - clubPath;
  }

  // Launch angles & spin
  let vla = null;
  if (raw.VLA != null || raw.LaunchAngle != null || raw.VerticalLaunchAngle != null || raw.vla != null) {
    vla = Number(raw.VLA ?? raw.LaunchAngle ?? raw.VerticalLaunchAngle ?? raw.vla);
  }

  let hla = null;
  if (raw.HLA != null || raw.HorizontalLaunchAngle != null || raw.hla != null) {
    hla = Number(raw.HLA ?? raw.HorizontalLaunchAngle ?? raw.hla);
  }

  const totalSpin = Number(raw.TotalSpin ?? raw.sp ?? raw.spin_rpm ?? 0);

  // Impact location (mm from center face)
  let hi = null;
  let vi = null;
  let impactOffsetMm = null;
  if (raw.HorizontalFaceImpact != null || raw.hi != null) {
    hi = Number(raw.HorizontalFaceImpact ?? raw.hi);
  }
  if (raw.VerticalFaceImpact != null || raw.vi != null) {
    vi = Number(raw.VerticalFaceImpact ?? raw.vi);
  }
  if (hi != null && vi != null) {
    impactOffsetMm = Math.hypot(hi, vi);
  }

  return {
    id,
    t,
    index,
    club,
    carryYds: Math.round(carryYds * 10) / 10,
    totalYds: Math.round(totalYds * 10) / 10,
    signedOfflineYds: Math.round(signedOfflineYds * 10) / 10,
    absOfflineYds: Math.round(absOfflineYds * 10) / 10,
    ballSpeed: ballSpeed > 0 ? Math.round(ballSpeed * 10) / 10 : null,
    clubSpeed: clubSpeed > 0 ? Math.round(clubSpeed * 10) / 10 : null,
    smash: smash > 0.1 ? Math.round(smash * 100) / 100 : null,
    faceAngle: faceAngle != null && !isNaN(faceAngle) ? Math.round(faceAngle * 10) / 10 : null,
    clubPath: clubPath != null && !isNaN(clubPath) ? Math.round(clubPath * 10) / 10 : null,
    faceToPath: faceToPath != null && !isNaN(faceToPath) ? Math.round(faceToPath * 10) / 10 : null,
    vla: vla != null && !isNaN(vla) ? Math.round(vla * 10) / 10 : null,
    hla: hla != null && !isNaN(hla) ? Math.round(hla * 10) / 10 : null,
    totalSpin: totalSpin > 0 ? Math.round(totalSpin) : null,
    hi: hi != null ? Math.round(hi * 10) / 10 : null,
    vi: vi != null ? Math.round(vi * 10) / 10 : null,
    impactOffsetMm: impactOffsetMm != null ? Math.round(impactOffsetMm * 10) / 10 : null
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

  // Sort chronologically
  allShots.sort((a, b) => a.t - b.t);
  allShots.forEach((s, idx) => { s.index = idx + 1; });
  return allShots;
}

/**
 * Extracts normalized shots for a single club.
 */
export function getClubShots(clubsDict, clubKey) {
  if (!clubsDict || !clubKey) return [];
  // Find case-insensitive match
  let targetKey = Object.keys(clubsDict).find(k => k.toLowerCase() === clubKey.toLowerCase());
  if (!targetKey) return [];
  const rawArray = clubsDict[targetKey];
  if (!Array.isArray(rawArray)) return [];

  const shots = rawArray.map((raw, idx) => normalizeShot({ ...raw, club: clubKey }, idx)).filter(Boolean);
  shots.sort((a, b) => a.t - b.t);
  shots.forEach((s, idx) => { s.index = idx + 1; });
  return shots;
}

/**
 * Computes simple moving average for a numeric array.
 */
export function computeRollingAverage(arr, windowSize = 5) {
  if (!arr || arr.length === 0) return [];
  const result = [];
  for (let i = 0; i < arr.length; i++) {
    const start = Math.max(0, i - Math.floor(windowSize / 2));
    const end = Math.min(arr.length, start + windowSize);
    const slice = arr.slice(start, end).filter(v => v != null && !isNaN(v));
    if (slice.length === 0) {
      result.push(null);
    } else {
      const sum = slice.reduce((acc, v) => acc + v, 0);
      result.push(Math.round((sum / slice.length) * 10) / 10);
    }
  }
  return result;
}

/**
 * Calculates summary metrics for a list of shots.
 */
function summarizeShotGroup(shots) {
  if (!shots || shots.length === 0) {
    return {
      count: 0,
      avgAbsOffline: 0,
      avgSignedOffline: 0,
      pctInFairway: 0,
      pctLeft: 0,
      pctRight: 0,
      avgAbsFace: null,
      avgSignedFace: null,
      faceCount: 0,
      avgAbsPath: null,
      avgSignedPath: null,
      pathCount: 0,
      avgAbsFtp: null,
      avgSignedFtp: null,
      ftpCount: 0,
      avgSmash: null,
      smashCount: 0,
      avgCarry: 0,
      stdDevCarry: 0,
      avgBallSpeed: null,
      avgClubSpeed: null,
      avgImpactOffsetMm: null,
      impactCount: 0
    };
  }

  const n = shots.length;
  let absOfflineSum = 0;
  let signedOfflineSum = 0;
  let inFairwayCount = 0;
  let leftMissCount = 0;
  let rightMissCount = 0;

  let absFaceSum = 0, signedFaceSum = 0, faceCount = 0;
  let absPathSum = 0, signedPathSum = 0, pathCount = 0;
  let absFtpSum = 0, signedFtpSum = 0, ftpCount = 0;
  let smashSum = 0, smashCount = 0;
  let carrySum = 0;
  const carryList = [];
  let ballSpeedSum = 0, ballSpeedCount = 0;
  let clubSpeedSum = 0, clubSpeedCount = 0;
  let impactOffsetSum = 0, impactCount = 0;

  shots.forEach((s) => {
    absOfflineSum += s.absOfflineYds;
    signedOfflineSum += s.signedOfflineYds;

    if (s.absOfflineYds <= 10.0) {
      inFairwayCount++;
    } else if (s.signedOfflineYds < -10.0) {
      leftMissCount++;
    } else {
      rightMissCount++;
    }

    if (s.faceAngle != null) {
      absFaceSum += Math.abs(s.faceAngle);
      signedFaceSum += s.faceAngle;
      faceCount++;
    }

    if (s.clubPath != null) {
      absPathSum += Math.abs(s.clubPath);
      signedPathSum += s.clubPath;
      pathCount++;
    }

    if (s.faceToPath != null) {
      absFtpSum += Math.abs(s.faceToPath);
      signedFtpSum += s.faceToPath;
      ftpCount++;
    }

    if (s.smash != null && s.smash > 0.5) {
      smashSum += s.smash;
      smashCount++;
    }

    if (s.carryYds > 0) {
      carrySum += s.carryYds;
      carryList.push(s.carryYds);
    }

    if (s.ballSpeed != null && s.ballSpeed > 0) {
      ballSpeedSum += s.ballSpeed;
      ballSpeedCount++;
    }

    if (s.clubSpeed != null && s.clubSpeed > 0) {
      clubSpeedSum += s.clubSpeed;
      clubSpeedCount++;
    }

    if (s.impactOffsetMm != null) {
      impactOffsetSum += s.impactOffsetMm;
      impactCount++;
    }
  });

  const avgCarry = carryList.length > 0 ? carrySum / carryList.length : 0;
  let stdDevCarry = 0;
  if (carryList.length > 1) {
    const variance = carryList.reduce((acc, val) => acc + Math.pow(val - avgCarry, 2), 0) / carryList.length;
    stdDevCarry = Math.sqrt(variance);
  }

  return {
    count: n,
    avgAbsOffline: Math.round((absOfflineSum / n) * 10) / 10,
    avgSignedOffline: Math.round((signedOfflineSum / n) * 10) / 10,
    pctInFairway: Math.round((inFairwayCount / n) * 100),
    pctLeft: Math.round((leftMissCount / n) * 100),
    pctRight: Math.round((rightMissCount / n) * 100),
    avgAbsFace: faceCount > 0 ? Math.round((absFaceSum / faceCount) * 10) / 10 : null,
    avgSignedFace: faceCount > 0 ? Math.round((signedFaceSum / faceCount) * 10) / 10 : null,
    faceCount,
    avgAbsPath: pathCount > 0 ? Math.round((absPathSum / pathCount) * 10) / 10 : null,
    avgSignedPath: pathCount > 0 ? Math.round((signedPathSum / pathCount) * 10) / 10 : null,
    pathCount,
    avgAbsFtp: ftpCount > 0 ? Math.round((absFtpSum / ftpCount) * 10) / 10 : null,
    avgSignedFtp: ftpCount > 0 ? Math.round((signedFtpSum / ftpCount) * 10) / 10 : null,
    ftpCount,
    avgSmash: smashCount > 0 ? Math.round((smashSum / smashCount) * 100) / 100 : null,
    smashCount,
    avgCarry: Math.round(avgCarry * 10) / 10,
    stdDevCarry: Math.round(stdDevCarry * 10) / 10,
    avgBallSpeed: ballSpeedCount > 0 ? Math.round((ballSpeedSum / ballSpeedCount) * 10) / 10 : null,
    avgClubSpeed: clubSpeedCount > 0 ? Math.round((clubSpeedSum / clubSpeedCount) * 10) / 10 : null,
    avgImpactOffsetMm: impactCount > 0 ? Math.round((impactOffsetSum / impactCount) * 10) / 10 : null,
    impactCount
  };
}

/**
 * Main analytics computation function.
 * Evaluates baseline vs recent shots, computes progress trends, metrics, and improvement badges.
 */
export function computeImprovementAnalytics(shots, sampleWindowMode = "last10") {
  if (!shots || shots.length === 0) {
    return { hasData: false, totalShots: 0 };
  }

  const totalShots = shots.length;

  if (totalShots === 1) {
    const single = summarizeShotGroup(shots);
    return {
      hasData: true,
      singleShot: true,
      totalShots: 1,
      recent: single,
      baseline: single,
      shots
    };
  }

  // Split into Baseline and Recent sets based on chosen sample window
  let baselineShots = [];
  let recentShots = [];

  if (sampleWindowMode === "last10") {
    const windowSize = Math.min(10, Math.floor(totalShots / 2));
    recentShots = shots.slice(totalShots - windowSize);
    baselineShots = shots.slice(Math.max(0, totalShots - (windowSize * 2)), totalShots - windowSize);
  } else if (sampleWindowMode === "last25") {
    const windowSize = Math.min(25, Math.floor(totalShots / 2));
    recentShots = shots.slice(totalShots - windowSize);
    baselineShots = shots.slice(Math.max(0, totalShots - (windowSize * 2)), totalShots - windowSize);
  } else {
    // "all": First 50% vs Second 50%
    const mid = Math.floor(totalShots / 2);
    baselineShots = shots.slice(0, mid);
    recentShots = shots.slice(mid);
  }

  if (baselineShots.length === 0) baselineShots = recentShots.slice(0, 1);
  if (recentShots.length === 0) recentShots = baselineShots.slice();

  const baseline = summarizeShotGroup(baselineShots);
  const recent = summarizeShotGroup(recentShots);

  // 1. Offline Dispersion Analysis (Nearing Zero vs Expanding)
  const offlineDelta = Math.round((recent.avgAbsOffline - baseline.avgAbsOffline) * 10) / 10;
  let offlineStatus = "consistent";
  let offlineBadge = "Consistent Dispersion";
  let offlineImprovementText = "";

  if (offlineDelta <= -0.4) {
    offlineStatus = "improving";
    offlineBadge = "Nearing Centerline (Tighter)";
    const pctGain = baseline.avgAbsOffline > 0
      ? Math.round((Math.abs(offlineDelta) / baseline.avgAbsOffline) * 100)
      : 0;
    offlineImprovementText = `↓ ${Math.abs(offlineDelta).toFixed(1)} yds closer to center (${pctGain}% tighter dispersion)`;
  } else if (offlineDelta >= 0.4) {
    offlineStatus = "expanding";
    offlineBadge = "Expanding Further Offline";
    offlineImprovementText = `↑ ${offlineDelta.toFixed(1)} yds further offline`;
  } else {
    offlineStatus = "consistent";
    offlineBadge = "Consistent Dispersion";
    offlineImprovementText = `Holding steady (±0.3 yds)`;
  }

  // 2. Club Face Angle Analysis (Squaring Up to 0.0° vs Drifting Off)
  let faceStatus = "no_data";
  let faceBadge = "No LM Data";
  let faceDelta = null;
  let faceImprovementText = "Face telemetry not provided";

  if (recent.avgAbsFace != null && baseline.avgAbsFace != null) {
    faceDelta = Math.round((recent.avgAbsFace - baseline.avgAbsFace) * 10) / 10;
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
      faceImprovementText = `Face angle stable (±0.1°)`;
    }
  }

  // 3. Club Path Analysis (Straightening to 0.0° vs Steepening)
  let pathStatus = "no_data";
  let pathBadge = "No LM Data";
  let pathDelta = null;
  let pathImprovementText = "Path telemetry not provided";

  if (recent.avgAbsPath != null && baseline.avgAbsPath != null) {
    pathDelta = Math.round((recent.avgAbsPath - baseline.avgAbsPath) * 10) / 10;
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
      pathImprovementText = `Swing path stable (±0.1°)`;
    }
  }

  // 4. Face-to-Path Curvature Analysis (Nearing 0.0° for Straight Flight)
  let ftpStatus = "no_data";
  let ftpBadge = "No LM Data";
  let ftpDelta = null;
  let ftpImprovementText = "";

  if (recent.avgAbsFtp != null && baseline.avgAbsFtp != null) {
    ftpDelta = Math.round((recent.avgAbsFtp - baseline.avgAbsFtp) * 10) / 10;
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
      ftpImprovementText = `Face-to-path stable`;
    }
  }

  // 5. Strike Quality (Smash Factor & Sweet Spot Offset)
  let smashStatus = "no_data";
  let smashDelta = null;
  let smashImprovementText = "";

  if (recent.avgSmash != null && baseline.avgSmash != null) {
    smashDelta = Math.round((recent.avgSmash - baseline.avgSmash) * 100) / 100;
    if (smashDelta >= 0.02) {
      smashStatus = "improving";
      smashImprovementText = `↑ +${smashDelta.toFixed(2)} higher compression`;
    } else if (smashDelta <= -0.02) {
      smashStatus = "declining";
      smashImprovementText = `↓ ${Math.abs(smashDelta).toFixed(2)} smash factor`;
    } else {
      smashStatus = "consistent";
      smashImprovementText = `Consistent ball compression`;
    }
  }

  // Impact offset mm
  let impactStatus = "no_data";
  let impactDelta = null;
  let impactImprovementText = "";
  if (recent.avgImpactOffsetMm != null && baseline.avgImpactOffsetMm != null) {
    impactDelta = Math.round((recent.avgImpactOffsetMm - baseline.avgImpactOffsetMm) * 10) / 10;
    if (impactDelta <= -0.3) {
      impactStatus = "improving";
      impactImprovementText = `↓ ${Math.abs(impactDelta).toFixed(1)} mm closer to sweet spot`;
    } else if (impactDelta >= 0.3) {
      impactStatus = "expanding";
      impactImprovementText = `↑ ${impactDelta.toFixed(1)} mm off-center strike`;
    } else {
      impactStatus = "consistent";
      impactImprovementText = `Consistent contact location`;
    }
  }

  // Distance change
  const carryDelta = Math.round((recent.avgCarry - baseline.avgCarry) * 10) / 10;
  const carryDispersionDelta = Math.round((recent.stdDevCarry - baseline.stdDevCarry) * 10) / 10;

  return {
    hasData: true,
    totalShots,
    baselineShotsCount: baselineShots.length,
    recentShotsCount: recentShots.length,
    baseline,
    recent,
    offline: {
      status: offlineStatus,
      badge: offlineBadge,
      delta: offlineDelta,
      text: offlineImprovementText
    },
    face: {
      status: faceStatus,
      badge: faceBadge,
      delta: faceDelta,
      text: faceImprovementText
    },
    path: {
      status: pathStatus,
      badge: pathBadge,
      delta: pathDelta,
      text: pathImprovementText
    },
    faceToPath: {
      status: ftpStatus,
      badge: ftpBadge,
      delta: ftpDelta,
      text: ftpImprovementText
    },
    smash: {
      status: smashStatus,
      delta: smashDelta,
      text: smashImprovementText
    },
    impact: {
      status: impactStatus,
      delta: impactDelta,
      text: impactImprovementText
    },
    distance: {
      carryDelta,
      carryDispersionDelta
    },
    shots
  };
}

/**
 * Generates an SVG line/scatter chart showing directional offline dispersion relative to target line 0.
 */
export function generateOfflineTrendChartSvg(shots, options = {}) {
  if (!shots || shots.length === 0) return "";

  const width = options.width || 700;
  const height = options.height || 240;
  const padL = 60, padR = 25, padT = 25, padB = 40;
  const plotW = width - padL - padR;
  const plotH = height - padT - padB;

  // Determine max offline scale (symmetric around 0)
  const maxVal = shots.reduce((acc, s) => Math.max(acc, s.absOfflineYds), 15);
  const scaleLimit = Math.max(15, Math.ceil(maxVal / 5) * 5); // e.g. 15, 20, 25, 30

  const zeroY = padT + plotH / 2;
  const getY = (yds) => zeroY - (yds / scaleLimit) * (plotH / 2);
  const getX = (idx) => padL + (shots.length > 1 ? (idx / (shots.length - 1)) * plotW : plotW / 2);

  // Fairway corridor zone (±10 yards)
  const corridorTop = Math.max(padT, getY(10));
  const corridorBottom = Math.min(height - padB, getY(-10));
  const corridorH = corridorBottom - corridorTop;

  // Grid lines: -scaleLimit, -10, 0, +10, +scaleLimit
  const gridSteps = [-scaleLimit, -10, 0, 10, scaleLimit];

  let gridSvg = "";
  gridSteps.forEach((step) => {
    const y = getY(step);
    const isZero = step === 0;
    const isCorridor = Math.abs(step) === 10;
    const stroke = isZero ? "#22c55e" : (isCorridor ? "rgba(34, 197, 94, 0.4)" : "rgba(255, 255, 255, 0.08)");
    const dash = isZero ? "4 3" : (isCorridor ? "2 2" : "none");
    const strokeW = isZero ? 2 : 1;
    const label = isZero ? "🎯 0 Target" : `${step > 0 ? "+" : ""}${step} yds`;

    gridSvg += `
      <line x1="${padL}" y1="${y}" x2="${width - padR}" y2="${y}" stroke="${stroke}" stroke-width="${strokeW}" stroke-dasharray="${dash}" />
      <text x="${padL - 8}" y="${y + 4}" fill="${isZero ? '#22c55e' : 'var(--muted)'}" font-size="10" font-weight="${isZero ? '700' : '500'}" text-anchor="end">${label}</text>
    `;
  });

  // Rolling trendline (moving average)
  const offlineValues = shots.map(s => s.signedOfflineYds);
  const rolling = computeRollingAverage(offlineValues, Math.min(5, Math.max(2, Math.floor(shots.length / 3))));

  let trendPath = "";
  rolling.forEach((val, i) => {
    if (val == null) return;
    const x = getX(i);
    const y = getY(val);
    trendPath += (trendPath === "" ? `M ${x} ${y}` : ` L ${x} ${y}`);
  });

  // Shot dots
  let dotsSvg = "";
  shots.forEach((s, i) => {
    const x = getX(i);
    const y = getY(s.signedOfflineYds);
    const inCorridor = s.absOfflineYds <= 10.0;
    const dotColor = inCorridor ? "#22c55e" : (s.absOfflineYds <= 18 ? "#eab308" : "#ef4444");
    const sideText = s.signedOfflineYds === 0 ? "Dead Center" : (s.signedOfflineYds < 0 ? `${Math.abs(s.signedOfflineYds)} yds Left` : `${s.signedOfflineYds} yds Right`);
    const titleText = `Shot #${s.index}${s.club ? ' (' + s.club + ')' : ''}: ${sideText} • Carry: ${s.carryYds} yds`;

    dotsSvg += `
      <g class="chart-shot-dot" tabindex="0">
        <circle cx="${x}" cy="${y}" r="4.5" fill="${dotColor}" stroke="#0b131e" stroke-width="1.5">
          <title>${titleText}</title>
        </circle>
      </g>
    `;
  });

  return `
    <svg viewBox="0 0 ${width} ${height}" class="analytics-svg-chart" style="width:100%; height:auto;" aria-label="Offline Dispersion Trend Chart">
      <!-- Target corridor zone -->
      <rect x="${padL}" y="${corridorTop}" width="${plotW}" height="${corridorH}" fill="rgba(34, 197, 94, 0.08)" rx="4" />
      <text x="${width - padR - 8}" y="${corridorTop + 14}" fill="rgba(34, 197, 94, 0.6)" font-size="10" font-weight="600" text-anchor="end">±10 yd Target Corridor</text>

      <!-- Side zone indicators -->
      <text x="${padL + 10}" y="${padT + 12}" fill="rgba(255,255,255,0.3)" font-size="9" font-weight="600">PUSH / SLICE RIGHT (+)</text>
      <text x="${padL + 10}" y="${height - padB - 6}" fill="rgba(255,255,255,0.3)" font-size="9" font-weight="600">PULL / HOOK LEFT (-)</text>

      <!-- Grid lines -->
      ${gridSvg}

      <!-- Rolling Average Trendline -->
      ${trendPath ? `<path d="${trendPath}" fill="none" stroke="#38bdf8" stroke-width="2.5" stroke-linejoin="round" stroke-linecap="round" />` : ''}

      <!-- Shot dots -->
      ${dotsSvg}

      <!-- Bottom Axis (Shot sequence) -->
      <text x="${padL}" y="${height - 12}" fill="var(--muted)" font-size="10">Oldest Shot (Shot #1)</text>
      <text x="${width - padR}" y="${height - 12}" fill="var(--muted)" font-size="10" text-anchor="end">Latest Shot (Shot #${shots.length})</text>
    </svg>
  `;
}

/**
 * Generates an SVG chart showing Face Angle and Club Path converging to 0.0° (straight).
 */
export function generateDeliveryTrendChartSvg(shots, options = {}) {
  // Filter to shots that have delivery telemetry
  const validShots = shots.filter(s => s.faceAngle != null || s.clubPath != null);
  if (validShots.length === 0) {
    return `
      <div class="empty-chart-fallback">
        <p>No club face or path data recorded yet. Connect a launch monitor with club delivery telemetry to track delivery angles!</p>
      </div>
    `;
  }

  const width = options.width || 700;
  const height = options.height || 240;
  const padL = 60, padR = 25, padT = 25, padB = 40;
  const plotW = width - padL - padR;
  const plotH = height - padT - padB;

  // Find max deviation degrees
  const maxDeg = validShots.reduce((acc, s) => {
    const f = s.faceAngle != null ? Math.abs(s.faceAngle) : 0;
    const p = s.clubPath != null ? Math.abs(s.clubPath) : 0;
    return Math.max(acc, f, p);
  }, 6);
  const scaleDeg = Math.max(5, Math.ceil(maxDeg / 2) * 2);

  const zeroY = padT + plotH / 2;
  const getY = (deg) => zeroY - (deg / scaleDeg) * (plotH / 2);
  const getX = (idx) => padL + (validShots.length > 1 ? (idx / (validShots.length - 1)) * plotW : plotW / 2);

  // Grid lines: -scaleDeg, -2, 0, +2, +scaleDeg
  const gridSteps = [-scaleDeg, -2, 0, 2, scaleDeg];
  let gridSvg = "";
  gridSteps.forEach((deg) => {
    const y = getY(deg);
    const isZero = deg === 0;
    const stroke = isZero ? "#22c55e" : "rgba(255, 255, 255, 0.08)";
    const dash = isZero ? "4 3" : "none";
    const strokeW = isZero ? 2 : 1;
    const label = isZero ? "🎯 0.0° Square" : `${deg > 0 ? "+" : ""}${deg}°`;

    gridSvg += `
      <line x1="${padL}" y1="${y}" x2="${width - padR}" y2="${y}" stroke="${stroke}" stroke-width="${strokeW}" stroke-dasharray="${dash}" />
      <text x="${padL - 8}" y="${y + 4}" fill="${isZero ? '#22c55e' : 'var(--muted)'}" font-size="10" font-weight="${isZero ? '700' : '500'}" text-anchor="end">${label}</text>
    `;
  });

  // Face angle trend
  const faceValues = validShots.map(s => s.faceAngle);
  const rollingFace = computeRollingAverage(faceValues, Math.min(5, Math.max(2, Math.floor(validShots.length / 3))));

  let facePath = "";
  rollingFace.forEach((val, i) => {
    if (val == null) return;
    const x = getX(i);
    const y = getY(val);
    facePath += (facePath === "" ? `M ${x} ${y}` : ` L ${x} ${y}`);
  });

  // Club path trend
  const pathValues = validShots.map(s => s.clubPath);
  const rollingPath = computeRollingAverage(pathValues, Math.min(5, Math.max(2, Math.floor(validShots.length / 3))));

  let pathPath = "";
  rollingPath.forEach((val, i) => {
    if (val == null) return;
    const x = getX(i);
    const y = getY(val);
    pathPath += (pathPath === "" ? `M ${x} ${y}` : ` L ${x} ${y}`);
  });

  // Dots
  let dotsSvg = "";
  validShots.forEach((s, i) => {
    const x = getX(i);
    if (s.faceAngle != null) {
      const yF = getY(s.faceAngle);
      const faceStr = s.faceAngle === 0 ? "0.0° Square" : (s.faceAngle > 0 ? `${s.faceAngle}° Open` : `${Math.abs(s.faceAngle)}° Closed`);
      dotsSvg += `
        <circle cx="${x}" cy="${yF}" r="3.5" fill="#f59e0b" stroke="#0b131e" stroke-width="1">
          <title>Shot #${s.index}: Face Angle ${faceStr}</title>
        </circle>
      `;
    }
    if (s.clubPath != null) {
      const yP = getY(s.clubPath);
      const pathStr = s.clubPath === 0 ? "0.0° Straight" : (s.clubPath > 0 ? `${s.clubPath}° In-to-Out` : `${Math.abs(s.clubPath)}° Out-to-In`);
      dotsSvg += `
        <circle cx="${x}" cy="${yP}" r="3.5" fill="#38bdf8" stroke="#0b131e" stroke-width="1">
          <title>Shot #${s.index}: Club Path ${pathStr}</title>
        </circle>
      `;
    }
  });

  return `
    <svg viewBox="0 0 ${width} ${height}" class="analytics-svg-chart" style="width:100%; height:auto;" aria-label="Face & Path Delivery Trend Chart">
      <!-- Upper / lower zone hints -->
      <text x="${padL + 10}" y="${padT + 12}" fill="rgba(255,255,255,0.3)" font-size="9" font-weight="600">OPEN FACE / IN-TO-OUT PATH (+)</text>
      <text x="${padL + 10}" y="${height - padB - 6}" fill="rgba(255,255,255,0.3)" font-size="9" font-weight="600">CLOSED FACE / OUT-TO-IN PATH (-)</text>

      <!-- Grid -->
      ${gridSvg}

      <!-- Trend lines -->
      ${facePath ? `<path d="${facePath}" fill="none" stroke="#f59e0b" stroke-width="2.5" stroke-linejoin="round" stroke-linecap="round" />` : ''}
      ${pathPath ? `<path d="${pathPath}" fill="none" stroke="#38bdf8" stroke-width="2.5" stroke-linejoin="round" stroke-linecap="round" />` : ''}

      <!-- Dots -->
      ${dotsSvg}

      <!-- Bottom Axis -->
      <text x="${padL}" y="${height - 12}" fill="var(--muted)" font-size="10">Oldest Shot</text>
      <text x="${width - padR}" y="${height - 12}" fill="var(--muted)" font-size="10" text-anchor="end">Latest Shot</text>
    </svg>
  `;
}

/**
 * Generates an SVG chart showing Smash Factor progression and impact centering.
 */
export function generateStrikeTrendChartSvg(shots, options = {}) {
  const validShots = shots.filter(s => (s.smash != null && s.smash > 0.5) || s.impactOffsetMm != null);
  if (validShots.length === 0) {
    return `
      <div class="empty-chart-fallback">
        <p>No smash factor or impact location telemetry recorded yet.</p>
      </div>
    `;
  }

  const width = options.width || 700;
  const height = options.height || 240;
  const padL = 60, padR = 25, padT = 25, padB = 40;
  const plotW = width - padL - padR;
  const plotH = height - padT - padB;

  // Plot Smash Factor (min 1.0, max 1.55)
  const minSmash = 1.15;
  const maxSmash = 1.52;

  const getY = (val) => padT + plotH - ((val - minSmash) / (maxSmash - minSmash)) * plotH;
  const getX = (idx) => padL + (validShots.length > 1 ? (idx / (validShots.length - 1)) * plotW : plotW / 2);

  // Target optimal smash line (1.45–1.50)
  const yOptTop = getY(1.50);
  const yOptBottom = getY(1.45);
  const optH = yOptBottom - yOptTop;

  // Grid steps
  const steps = [1.20, 1.30, 1.40, 1.45, 1.50];
  let gridSvg = "";
  steps.forEach((val) => {
    const y = getY(val);
    const isTour = val >= 1.45;
    const stroke = isTour ? "rgba(34, 197, 94, 0.35)" : "rgba(255, 255, 255, 0.08)";
    gridSvg += `
      <line x1="${padL}" y1="${y}" x2="${width - padR}" y2="${y}" stroke="${stroke}" stroke-width="1" />
      <text x="${padL - 8}" y="${y + 4}" fill="${isTour ? '#22c55e' : 'var(--muted)'}" font-size="10" font-weight="${isTour ? '700' : '500'}" text-anchor="end">${val.toFixed(2)}</text>
    `;
  });

  // Rolling smash
  const smashValues = validShots.map(s => s.smash || 1.30);
  const rolling = computeRollingAverage(smashValues, Math.min(5, Math.max(2, Math.floor(validShots.length / 3))));

  let trendPath = "";
  rolling.forEach((val, i) => {
    if (val == null) return;
    const x = getX(i);
    const y = getY(val);
    trendPath += (trendPath === "" ? `M ${x} ${y}` : ` L ${x} ${y}`);
  });

  // Dots
  let dotsSvg = "";
  validShots.forEach((s, i) => {
    if (s.smash == null) return;
    const x = getX(i);
    const y = getY(s.smash);
    const isGood = s.smash >= 1.42;
    dotsSvg += `
      <circle cx="${x}" cy="${y}" r="4" fill="${isGood ? '#22c55e' : '#eab308'}" stroke="#0b131e" stroke-width="1.5">
        <title>Shot #${s.index}: Smash Factor ${s.smash.toFixed(2)}${s.impactOffsetMm != null ? ` • ${s.impactOffsetMm}mm off-center` : ''}</title>
      </circle>
    `;
  });

  return `
    <svg viewBox="0 0 ${width} ${height}" class="analytics-svg-chart" style="width:100%; height:auto;" aria-label="Smash Factor Strike Consistency Chart">
      <!-- Optimal Smash Zone -->
      <rect x="${padL}" y="${yOptTop}" width="${plotW}" height="${optH}" fill="rgba(34, 197, 94, 0.1)" rx="3" />
      <text x="${width - padR - 8}" y="${yOptTop + 14}" fill="rgba(34, 197, 94, 0.7)" font-size="10" font-weight="600" text-anchor="end">Optimal Smash Factor Zone (1.45 - 1.50)</text>

      ${gridSvg}

      ${trendPath ? `<path d="${trendPath}" fill="none" stroke="#22c55e" stroke-width="2.5" stroke-linejoin="round" stroke-linecap="round" />` : ''}

      ${dotsSvg}

      <text x="${padL}" y="${height - 12}" fill="var(--muted)" font-size="10">Oldest Shot</text>
      <text x="${width - padR}" y="${height - 12}" fill="var(--muted)" font-size="10" text-anchor="end">Latest Shot</text>
    </svg>
  `;
}

/**
 * Generates automated AI coaching observations and practice recommendations.
 */
export function generateCoachingInsights(analytics) {
  if (!analytics || !analytics.hasData || analytics.totalShots < 2) {
    return [
      {
        icon: "💡",
        title: "Log More Swings",
        desc: "Hit a series of shots on the launch monitor to uncover your directional dispersion and club delivery trends."
      }
    ];
  }

  const { recent, baseline, offline, face, path, faceToPath, smash, impact } = analytics;
  const insights = [];

  // 1. Offline & Directional Accuracy
  if (offline.status === "improving") {
    insights.push({
      icon: "🎯",
      title: "Dispersion Tightening Towards Target Centerline",
      desc: `Great progress! Your lateral dispersion improved by ${Math.abs(offline.delta).toFixed(1)} yards. Your recent shots are averaging ${recent.avgAbsOffline.toFixed(1)} yards from target center (with ${recent.pctInFairway}% landing in the fairway corridor).`
    });
  } else if (offline.status === "expanding") {
    const missSide = recent.avgSignedOffline < 0 ? "left" : "right";
    insights.push({
      icon: "⚠️",
      title: "Dispersion Expanding Off-Centerline",
      desc: `Your recent shots are drifting further offline (+${offline.delta.toFixed(1)} yds), primarily missing to the ${missSide} (${Math.abs(recent.avgSignedOffline).toFixed(1)} yds avg). Review your address alignment and takeaway path.`
    });
  } else {
    insights.push({
      icon: "🎯",
      title: "Solid, Repeatable Dispersion",
      desc: `Your lateral dispersion has remained very consistent, averaging ±${recent.avgAbsOffline.toFixed(1)} yards from the target line with a ${recent.pctInFairway}% fairway hold rate.`
    });
  }

  // 2. Club Face Control (Squaring Up)
  if (face.status === "improving") {
    insights.push({
      icon: "🏌️",
      title: "Club Face Squaring Up to Target",
      desc: `Your club face angle is nearing 0.0° square at impact (${Math.abs(face.delta).toFixed(1)}° closer to 0° than baseline). This squaring trend directly reduces unwanted curve and slice misses.`
    });
  } else if (face.status === "expanding") {
    const faceTendency = recent.avgSignedFace > 0 ? "open" : "closed";
    insights.push({
      icon: "🔄",
      title: `Club Face Drifting ${faceTendency.toUpperCase()} at Impact`,
      desc: `Your club face is averaging ${Math.abs(recent.avgSignedFace).toFixed(1)}° ${faceTendency} relative to the target line. Focus on maintaining a neutral lead wrist through impact to square the club face.`
    });
  }

  // 3. Swing Path Mechanics
  if (path.status === "improving") {
    insights.push({
      icon: "📐",
      title: "Swing Path Straightening Down Target Line",
      desc: `Your swing path delivery has improved by ${Math.abs(path.delta).toFixed(1)}° closer to neutral (0.0°). You are swinging much straighter down your target line.`
    });
  } else if (path.status === "expanding") {
    const pathTendency = recent.avgSignedPath > 0 ? "in-to-out" : "out-to-in";
    insights.push({
      icon: "📐",
      title: `Prominent ${pathTendency.toUpperCase()} Swing Path`,
      desc: `Your path is averaging ${Math.abs(recent.avgSignedPath).toFixed(1)}° ${pathTendency}. ${pathTendency === 'out-to-in' ? 'Work on dropping the club into the slot from the inside to eliminate the over-the-top pull/slice.' : 'Work on turning the chest through the strike to prevent getting stuck too far inside.'}`
    });
  }

  // 4. Face-to-Path Alignment
  if (faceToPath.status === "improving") {
    insights.push({
      icon: "✨",
      title: "Tighter Face-to-Path Alignment",
      desc: `Your face-to-path differential narrowed to ${recent.avgAbsFtp.toFixed(1)}°, producing straighter ball flights with dramatically reduced sidespin curvature.`
    });
  }

  // 5. Strike Quality / Smash Factor
  if (smash.status === "improving") {
    insights.push({
      icon: "⚡",
      title: "Cleaner Ball Strike & Energy Transfer",
      desc: `Your smash factor has increased to ${recent.avgSmash.toFixed(2)}, demonstrating more efficient energy transfer and compression at impact.`
    });
  } else if (impact.status === "improving") {
    insights.push({
      icon: "🎯",
      title: "Contact Centered on Sweet Spot",
      desc: `Your strike location has converged ${Math.abs(impact.delta).toFixed(1)} mm closer to the sweet spot (averaging only ${recent.avgImpactOffsetMm.toFixed(1)} mm off dead-center).`
    });
  }

  return insights;
}
