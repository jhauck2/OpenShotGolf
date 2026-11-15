import {
  auth,
  db,
  provider,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  sendPasswordResetEmail,
  sendEmailVerification,
  updateProfile,
  signInWithPopup,
  GoogleAuthProvider,
  signOut,
  deleteUser,
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  collection,
  query,
  where,
  orderBy,
  limit,
  getDocs,
  writeBatch
} from "./firebase-init.js";
import { checkBudgetStatus, handleWriteError } from "./budget.js";
import {
  normalizeShot,
  aggregateAllClubsShots,
  getClubShots,
  computeImprovementAnalytics,
  generateOfflineTrendChartSvg,
  generateDeliveryTrendChartSvg,
  generateStrikeTrendChartSvg,
  generateCoachingInsights
} from "./analytics-engine.js";

const STANDARD_CLUBS = [
  "Dr", "3w", "5w", "2H", "3H", "4H", "1i", "2i", "3i", "4i",
  "5i", "6i", "7i", "8i", "9i", "Pw", "Gw", "Sw", "Lw", "Pt"
];

const STANDARD_14_BAG = [
  "Dr", "3w", "5w", "4H", "5i", "6i", "7i", "8i", "9i", "Pw", "Gw", "Sw", "Lw", "Pt"
];

const STANDARD_BAG_ORDER = [
  "Dr", "3w", "3W", "5w", "5W", "7w", "7W", "2H", "3H", "4H", "5H",
  "1i", "2i", "3i", "4i", "5i", "6i", "7i", "8i", "9i", "Pw", "PW", "Gw", "GW", "Sw", "SW", "Lw", "LW", "Pt"
];

const CLUB_LABELS = {
  Dr: "Driver",
  "3w": "3 Wood", "3W": "3 Wood",
  "5w": "5 Wood", "5W": "5 Wood",
  "7w": "7 Wood", "7W": "7 Wood",
  "2H": "2 Hybrid",
  "3H": "3 Hybrid",
  "4H": "4 Hybrid",
  "5H": "5 Hybrid",
  "1i": "1 Iron",
  "2i": "2 Iron",
  "3i": "3 Iron",
  "4i": "4 Iron",
  "5i": "5 Iron",
  "6i": "6 Iron",
  "7i": "7 Iron",
  "8i": "8 Iron",
  "9i": "9 Iron",
  Pw: "Pitching Wedge", PW: "Pitching Wedge",
  Gw: "Gap Wedge", GW: "Gap Wedge",
  Sw: "Sand Wedge", SW: "Sand Wedge",
  Lw: "Lob Wedge", LW: "Lob Wedge",
  Pt: "Putter"
};

const ACHIEVEMENT_LABELS = {
  first_par: { title: "First Par", desc: "Scored your first par on any hole" },
  first_birdie: { title: "First Birdie", desc: "Scored 1 under par on a hole" },
  first_eagle: { title: "First Eagle", desc: "Scored 2 under par on a hole" },
  hole_in_one: { title: "Ace / Hole in One", desc: "Holed out in a single shot" },
  long_drive: { title: "Long Drive", desc: "Crushed a drive over 300 yards" },
  long_putt: { title: "Monster Putt", desc: "Drained a putt longer than 30 feet" },
  round_under_par: { title: "Red Numbers", desc: "Finished an 18-hole round under par" },
  sand_save: { title: "Sand Save", desc: "Made par or better from a bunker" },
  green_in_regulation: { title: "Pure Striking", desc: "Hit 10+ greens in regulation" },
  range_grinder: { title: "Range Grinder", desc: "Hit 100+ balls on the driving range" },
  putting_master: { title: "Putting Master", desc: "Mastered the putting practice minigame" },
  chipping_master: { title: "Chipping Master", desc: "Mastered the chipping practice minigame" },
  heckle_veteran: { title: "Thick Skinned", desc: "Heard 50+ unique heckles" },
  multiplayer_winner: { title: "Match Winner", desc: "Won your first online multiplayer match" }
};

let currentUser = null;
let currentProfile = null;
let currentStats = null;
let currentTab = "overview";
let loadedTabs = { overview: false, "shot-analysis": false, analytics: false, matches: false, swing: false, achievements: false, settings: false };
let currentAnalyticsClub = "all";
let currentAnalyticsWindow = "last10";
let pendingDeviceCode = "";
let pendingLoopbackPort = "";
let deviceHandoffCompleted = false;
let activeConfirmCallback = null;
let toastTimeout = null;
let selectedShotAnalysis = null;

export function initPortal() {
  const urlParams = new URLSearchParams(window.location.search);
  pendingDeviceCode = (urlParams.get("device_code") || "").trim().toUpperCase();
  pendingLoopbackPort = (urlParams.get("port") || "").trim();

  bindAuthModeToggles();
  bindAuthForms();
  bindPortalTabs();
  bindPlayerManagement();

  // Listen to Auth state
  onAuthStateChanged(auth, async (user) => {
    currentUser = user;
    updateNavAuth(user);

    if (pendingDeviceCode && !deviceHandoffCompleted) {
      showAuthView();
      setTimeout(() => {
        document.getElementById("stats-signin")?.scrollIntoView({ behavior: "smooth" });
      }, 150);
      showFeedback(
        `Connecting to Heckle Golf Simulator (Code: ${pendingDeviceCode}). Click "Continue with Google" below to sign in to the game.`,
        false
      );
      return;
    }

    if (user) {
      showPortalView();
      await loadUserData(user);
    } else {
      showAuthView();
    }
  });

  // Check budget status on load
  checkBudgetStatus(false);
}

// ─── NAV AUTH UI ───
function updateNavAuth(user) {
  const btnSignin = document.getElementById("nav-signin-btn");
  const greeting = document.getElementById("user-greeting");
  const avatarEl = document.getElementById("user-avatar");
  const nameEl = document.getElementById("user-name");

  if (user) {
    if (btnSignin) btnSignin.style.display = "none";
    if (greeting) greeting.style.display = "flex";
    const initial = (user.displayName || user.email || "?").charAt(0).toUpperCase();
    if (avatarEl) avatarEl.textContent = initial;
    if (nameEl) nameEl.textContent = user.displayName ? user.displayName.split(" ")[0] : user.email.split("@")[0];
  } else {
    if (btnSignin) btnSignin.style.display = "";
    if (greeting) greeting.style.display = "none";
  }
}

// ─── AUTH MODE SWITCHING ───
function bindAuthModeToggles() {
  const btnSigninMode = document.getElementById("mode-btn-signin");
  const btnSignupMode = document.getElementById("mode-btn-signup");
  const linkForgot = document.getElementById("link-forgot-pw");
  const linkBackToSignin = document.getElementById("link-back-to-signin");
  const linkToSignup = document.getElementById("link-to-signup");

  if (btnSigninMode) btnSigninMode.addEventListener("click", () => setAuthMode("signin"));
  if (btnSignupMode) btnSignupMode.addEventListener("click", () => setAuthMode("signup"));
  if (linkForgot) linkForgot.addEventListener("click", () => setAuthMode("forgot"));
  if (linkBackToSignin) linkBackToSignin.addEventListener("click", () => setAuthMode("signin"));
  if (linkToSignup) linkToSignup.addEventListener("click", () => setAuthMode("signup"));
}

function setAuthMode(mode) {
  const signinForm = document.getElementById("signin-form");
  const signupForm = document.getElementById("signup-form");
  const forgotForm = document.getElementById("forgot-form");
  const btnSigninMode = document.getElementById("mode-btn-signin");
  const btnSignupMode = document.getElementById("mode-btn-signup");
  const googleBtn = document.getElementById("google-signin-btn");
  const divider = document.querySelector(".divider");
  const authModesContainer = document.querySelector(".auth-modes");

  clearFeedback();

  if (mode === "signin") {
    if (signinForm) signinForm.style.display = "";
    if (signupForm) signupForm.style.display = "none";
    if (forgotForm) forgotForm.style.display = "none";
    if (btnSigninMode) btnSigninMode.classList.add("active");
    if (btnSignupMode) btnSignupMode.classList.remove("active");
    if (googleBtn) googleBtn.style.display = "";
    if (divider) divider.style.display = "";
    if (authModesContainer) authModesContainer.style.display = "flex";
  } else if (mode === "signup") {
    if (signinForm) signinForm.style.display = "none";
    if (signupForm) signupForm.style.display = "";
    if (forgotForm) forgotForm.style.display = "none";
    if (btnSigninMode) btnSigninMode.classList.remove("active");
    if (btnSignupMode) btnSignupMode.classList.add("active");
    if (googleBtn) googleBtn.style.display = "";
    if (divider) divider.style.display = "";
    if (authModesContainer) authModesContainer.style.display = "flex";
  } else if (mode === "forgot") {
    if (signinForm) signinForm.style.display = "none";
    if (signupForm) signupForm.style.display = "none";
    if (forgotForm) forgotForm.style.display = "";
    if (googleBtn) googleBtn.style.display = "none";
    if (divider) divider.style.display = "none";
    if (authModesContainer) authModesContainer.style.display = "none";
  }
}

function showFeedback(message, isError = true) {
  const el = document.getElementById("auth-feedback");
  if (!el) return;
  el.className = `auth-feedback ${isError ? "error" : "success"}`;
  el.textContent = message;
}

function clearFeedback() {
  const el = document.getElementById("auth-feedback");
  if (!el) return;
  el.className = "auth-feedback";
  el.textContent = "";
}

// ─── BIND AUTH FORMS ───
function bindAuthForms() {
  // Sign In
  const signinForm = document.getElementById("signin-form");
  if (signinForm) {
    signinForm.addEventListener("submit", async (e) => {
      e.preventDefault();
      clearFeedback();
      const email = document.getElementById("email").value.trim();
      const password = document.getElementById("password").value;
      const btn = signinForm.querySelector("button[type='submit']");

      btn.textContent = "Signing In…";
      btn.disabled = true;

      try {
        await signInWithEmailAndPassword(auth, email, password);
      } catch (err) {
        showFeedback(formatAuthError(err.code || err.message), true);
        btn.textContent = "Sign In";
        btn.disabled = false;
      }
    });
  }

  // Create Account (Sign Up)
  const signupForm = document.getElementById("signup-form");
  if (signupForm) {
    signupForm.addEventListener("submit", async (e) => {
      e.preventDefault();
      clearFeedback();
      const name = document.getElementById("signup-name").value.trim();
      const email = document.getElementById("signup-email").value.trim();
      const password = document.getElementById("signup-password").value;
      const btn = signupForm.querySelector("button[type='submit']");

      if (name.length < 1 || name.length > 40) {
        showFeedback("Display Name must be between 1 and 40 characters.", true);
        return;
      }
      if (password.length < 6) {
        showFeedback("Password must be at least 6 characters.", true);
        return;
      }

      btn.textContent = "Creating Account…";
      btn.disabled = true;

      try {
        const cred = await createUserWithEmailAndPassword(auth, email, password);
        const newUser = cred.user;

        // 1. Update displayName
        await updateProfile(newUser, { displayName: name });

        // 2. Send email verification
        await sendEmailVerification(newUser);

        // 3. Initialize users/{uid} and profiles/{uid}
        const now = Math.floor(Date.now() / 1000);
        await setDoc(doc(db, "users", newUser.uid), {
          schema_version: 1,
          email_lower: newUser.email.toLowerCase(),
          display_name: name,
          created_at: now,
          last_login_at: now,
          leaderboard_opt_in: true,
          linked_cloud_uids: []
        }, { merge: true });

        await setDoc(doc(db, "profiles", newUser.uid), {
          schema_version: 1,
          owner_uid: newUser.uid,
          display_name: name,
          updated_at: now,
          rev: 1
        }, { merge: true });

        showFeedback("Account created! A verification email has been sent to " + email + ".", false);
      } catch (err) {
        const pauseMsg = await handleWriteError(err);
        if (pauseMsg) {
          showFeedback(pauseMsg, true);
        } else {
          showFeedback(formatAuthError(err.code || err.message), true);
        }
        btn.textContent = "Create Account";
        btn.disabled = false;
      }
    });
  }

  // Forgot Password
  const forgotForm = document.getElementById("forgot-form");
  if (forgotForm) {
    forgotForm.addEventListener("submit", async (e) => {
      e.preventDefault();
      clearFeedback();
      const email = document.getElementById("forgot-email").value.trim();
      const btn = forgotForm.querySelector("button[type='submit']");

      btn.textContent = "Sending Link…";
      btn.disabled = true;

      try {
        await sendPasswordResetEmail(auth, email);
        showFeedback("Password reset link sent! Check your inbox.", false);
        btn.textContent = "Send Reset Link";
        btn.disabled = false;
      } catch (err) {
        showFeedback(formatAuthError(err.code || err.message), true);
        btn.textContent = "Send Reset Link";
        btn.disabled = false;
      }
    });
  }

  // Google Sign-In
  const googleBtn = document.getElementById("google-signin-btn");
  if (googleBtn) {
    googleBtn.addEventListener("click", async () => {
      clearFeedback();
      try {
        const result = await signInWithPopup(auth, provider);
        const user = result.user;
        const credential = GoogleAuthProvider.credentialFromResult(result);
        const googleIdToken = credential ? credential.idToken : "";
        const now = Math.floor(Date.now() / 1000);

        if (pendingDeviceCode && googleIdToken) {
          try {
            const fbToken = await user.getIdToken();
            await fetch(
              `https://heckle-golf-sim-default-rtdb.firebaseio.com/auth_handoff/${encodeURIComponent(pendingDeviceCode)}.json?auth=${encodeURIComponent(fbToken)}`,
              {
                method: "PUT",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                  google_id_token: googleIdToken,
                  uid: user.uid,
                  created_at: now
                })
              }
            );
          } catch (_) {}

          if (pendingLoopbackPort) {
            try {
              await fetch(
                `http://127.0.0.1:${encodeURIComponent(pendingLoopbackPort)}/callback?code=${encodeURIComponent(pendingDeviceCode)}&id_token=${encodeURIComponent(googleIdToken)}`,
                { method: "GET", mode: "cors" }
              );
            } catch (_) {}
          }

          deviceHandoffCompleted = true;
          showFeedback(
            "✅ Signed in to Heckle Golf Simulator! You can now switch back to the game window.",
            false
          );
        }

        // Ensure users/{uid} and profiles/{uid} exist
        await setDoc(doc(db, "users", user.uid), {
          schema_version: 1,
          email_lower: user.email.toLowerCase(),
          display_name: user.displayName || user.email.split("@")[0],
          last_login_at: now,
          leaderboard_opt_in: true
        }, { merge: true });

        await setDoc(doc(db, "profiles", user.uid), {
          schema_version: 1,
          owner_uid: user.uid,
          display_name: user.displayName || user.email.split("@")[0],
          updated_at: now
        }, { merge: true });

        if (pendingDeviceCode && deviceHandoffCompleted) {
          setTimeout(async () => {
            showPortalView();
            await loadUserData(user);
          }, 2500);
        }
      } catch (err) {
        if (err.code !== "auth/popup-closed-by-user") {
          showFeedback(formatAuthError(err.code || err.message), true);
        }
      }
    });
  }

  // Nav scroll triggers or redirects
  const btnNavSignin = document.getElementById("nav-signin-btn");
  if (btnNavSignin) {
    btnNavSignin.addEventListener("click", () => {
      const statsElem = document.getElementById("stats-signin");
      if (statsElem) {
        statsElem.scrollIntoView({ behavior: "smooth" });
      } else {
        window.location.href = "portal.html";
      }
    });
  }
  const greetingEl = document.getElementById("user-greeting");
  if (greetingEl) {
    greetingEl.addEventListener("click", (e) => {
      if (e.target.id !== "signout-btn") {
        const statsElem = document.getElementById("stats-signin");
        if (statsElem) {
          statsElem.scrollIntoView({ behavior: "smooth" });
        } else {
          window.location.href = "portal.html";
        }
      }
    });
  }

  // Sign out buttons
  const signoutBtn = document.getElementById("signout-btn");
  if (signoutBtn) {
    signoutBtn.addEventListener("click", () => signOut(auth));
  }
  const portalSignoutBtn = document.getElementById("portal-signout-btn");
  if (portalSignoutBtn) {
    portalSignoutBtn.addEventListener("click", () => signOut(auth));
  }

  // Resend verification email
  const btnResendVerify = document.getElementById("btn-resend-verify");
  if (btnResendVerify) {
    btnResendVerify.addEventListener("click", async () => {
      if (!currentUser) return;
      btnResendVerify.textContent = "Sending…";
      btnResendVerify.disabled = true;
      try {
        await sendEmailVerification(currentUser);
        alert("Verification email sent to " + currentUser.email + ". Please check your inbox or spam folder.");
      } catch (err) {
        alert("Could not send verification email: " + err.message);
      } finally {
        btnResendVerify.textContent = "Resend Verification Email";
        btnResendVerify.disabled = false;
      }
    });
  }

  // Refresh verification status
  const btnCheckVerify = document.getElementById("btn-check-verify");
  if (btnCheckVerify) {
    btnCheckVerify.addEventListener("click", async () => {
      if (!currentUser) return;
      btnCheckVerify.textContent = "Checking…";
      btnCheckVerify.disabled = true;
      try {
        await currentUser.reload();
        await currentUser.getIdToken(true);
        updateVerificationBanner(currentUser);
        if (currentUser.emailVerified) {
          await checkIncomingLinkRequests(currentUser);
        }
      } catch (err) {
        alert("Could not refresh status: " + err.message);
      } finally {
        btnCheckVerify.textContent = "I've Verified (Refresh)";
        btnCheckVerify.disabled = false;
      }
    });
  }
}

function formatAuthError(codeOrMsg) {
  if (codeOrMsg.includes("user-not-found") || codeOrMsg.includes("wrong-password") || codeOrMsg.includes("invalid-credential")) {
    return "Invalid email or password.";
  }
  if (codeOrMsg.includes("email-already-in-use")) {
    return "An account with this email already exists.";
  }
  if (codeOrMsg.includes("weak-password")) {
    return "Password is too weak. Please use at least 6 characters.";
  }
  if (codeOrMsg.includes("invalid-email")) {
    return "Please enter a valid email address.";
  }
  return codeOrMsg;
}

// ─── PORTAL VIEW TOGGLING ───
function showAuthView() {
  const signinCard = document.querySelector(".signin-card");
  const playerPortal = document.getElementById("player-portal");
  const signinInfo = document.querySelector(".signin-info");

  if (signinCard) signinCard.style.display = "";
  if (playerPortal) playerPortal.style.display = "none";
  if (signinInfo) signinInfo.style.display = "";

  setAuthMode("signin");
  loadedTabs = { overview: false, "shot-analysis": false, analytics: false, matches: false, swing: false, achievements: false, settings: false };
  selectedShotAnalysis = null;
}

function showPortalView() {
  const signinCard = document.querySelector(".signin-card");
  const playerPortal = document.getElementById("player-portal");
  const signinInfo = document.querySelector(".signin-info");

  if (signinCard) signinCard.style.display = "none";
  if (playerPortal) playerPortal.style.display = "block";
  if (signinInfo) signinInfo.style.display = "none";
}

// ─── TAB NAVIGATION ───
function bindPortalTabs() {
  const tabBtns = document.querySelectorAll(".portal-tab-btn");
  tabBtns.forEach((btn) => {
    btn.addEventListener("click", () => {
      const tabName = btn.dataset.tab;
      switchPortalTab(tabName);
    });
  });
  document.getElementById("shot-analysis-refresh")?.addEventListener("click", () => {
    if (currentUser) loadShotAnalysisSessions(currentUser);
  });
  document.getElementById("shot-analysis-view-mode")?.addEventListener("change", renderSelectedShotAnalysis);
  window.addEventListener("resize", () => {
    if (selectedShotAnalysis && currentTab === "shot-analysis") drawShotAnalysisCharts(selectedShotAnalysis);
  });
}

function switchPortalTab(tabName) {
  currentTab = tabName;
  document.querySelectorAll(".portal-tab-btn").forEach((btn) => {
    btn.classList.toggle("active", btn.dataset.tab === tabName);
  });
  document.querySelectorAll(".portal-tab-pane").forEach((pane) => {
    pane.classList.toggle("active", pane.id === `portal-tab-${tabName}`);
  });

  // Lazy load tab data
  if (!loadedTabs[tabName] && currentUser) {
    if (tabName === "analytics") loadAnalyticsAndTrends(currentUser);
    else if (tabName === "shot-analysis") loadShotAnalysisSessions(currentUser);
    else if (tabName === "matches") loadRecentMatches(currentUser);
    else if (tabName === "swing") loadSwingAnalysis(currentUser);
    else if (tabName === "achievements") loadAchievements(currentUser);
    else if (tabName === "settings") loadSharedAccessAndSettings(currentUser);
  }
}

// ─── TAB: UPLOADED SHOT ANALYSIS ───
async function loadShotAnalysisSessions(user) {
  const container = document.getElementById("shot-analysis-list");
  if (!container) return;
  container.innerHTML = `<div class="loading-state"><div class="spinner"></div><p>Loading uploaded shot sessions…</p></div>`;

  try {
    const sessionsQuery = query(
      collection(db, "profiles", user.uid, "shot_analysis"),
      orderBy("created_at", "desc")
    );
    const snapshot = await getDocs(sessionsQuery);
    const sessions = snapshot.docs.map((sessionDoc) => ({ id: sessionDoc.id, ...sessionDoc.data() }));
    loadedTabs["shot-analysis"] = true;
    renderShotAnalysisSessions(sessions);
  } catch (err) {
    console.error("Shot analysis session fetch error:", err);
    container.innerHTML = `<div class="shot-analysis-error">Could not load shot analysis sessions: ${escapeHtml(err.message)}</div>`;
  }
}

function renderShotAnalysisSessions(sessions) {
  const container = document.getElementById("shot-analysis-list");
  if (!container) return;
  if (sessions.length === 0) {
    container.innerHTML = `<div class="empty-state"><span class="empty-icon">🎯</span><p>No uploaded shot data yet. From Shot Data Analysis on the range, choose “Upload to Portal”.</p></div>`;
    selectedShotAnalysis = null;
    document.getElementById("shot-analysis-detail")?.setAttribute("hidden", "");
    return;
  }

  container.innerHTML = `<div class="shot-analysis-session-list">${sessions.map((session) => {
    const timestamp = Number(session.created_at || 0);
    const dateText = timestamp ? new Date(timestamp * 1000).toLocaleString() : "Date unavailable";
    const records = Array.isArray(session.records) ? session.records : [];
    const groups = Array.isArray(session.groups) ? session.groups : [];
    const playerNames = [...new Set(records.map((record) => String(record.shot?.player_name || record.shot?.player || "")).filter(Boolean))];
    const summary = `${records.length} shots · ${groups.length} groups${playerNames.length ? ` · ${playerNames.map(escapeHtml).join(", ")}` : ""}`;
    return `
      <div class="shot-analysis-session" data-session-id="${escapeHtml(session.id)}">
        <div class="shot-analysis-session-info">
          <strong>${escapeHtml(dateText)}</strong>
          <span>${summary}</span>
        </div>
        <div class="shot-analysis-session-actions">
          <button class="btn-action-outline" data-shot-action="view">View</button>
          <button class="btn-action-outline" data-shot-action="csv">Download CSV</button>
          <button class="btn-action-outline btn-danger-outline" data-shot-action="delete">Delete</button>
        </div>
      </div>`;
  }).join("")}</div>`;

  container.querySelectorAll(".shot-analysis-session").forEach((row, index) => {
    const session = sessions[index];
    row.querySelector('[data-shot-action="view"]').addEventListener("click", () => {
      selectedShotAnalysis = session;
      renderSelectedShotAnalysis();
      document.getElementById("shot-analysis-detail")?.scrollIntoView({ behavior: "smooth", block: "start" });
    });
    row.querySelector('[data-shot-action="csv"]').addEventListener("click", () => downloadShotAnalysisCsv(session));
    row.querySelector('[data-shot-action="delete"]').addEventListener("click", async () => {
      const dateText = new Date(Number(session.created_at || 0) * 1000).toLocaleString();
      if (!confirm(`Delete the uploaded shot analysis from ${dateText}? This cannot be undone.`)) return;
      try {
        await deleteDoc(doc(db, "profiles", currentUser.uid, "shot_analysis", session.id));
        if (selectedShotAnalysis?.id === session.id) {
          selectedShotAnalysis = null;
          document.getElementById("shot-analysis-detail")?.setAttribute("hidden", "");
        }
        await loadShotAnalysisSessions(currentUser);
      } catch (err) {
        console.error("Shot analysis deletion failed:", err);
        alert(`Could not delete this shot analysis: ${err.message}`);
      }
    });
  });
}

function downloadShotAnalysisCsv(session) {
  const records = Array.isArray(session.records) ? session.records : [];
  const groups = Array.isArray(session.groups) ? session.groups : [];
  const groupLabels = new Map(groups.map((group) => [String(group.id), String(group.label || "Group")]));
  const keys = [...new Set(records.flatMap((record) => Object.keys(record.shot || {})))].sort();
  const createdAt = Number(session.created_at || 0);
  const sessionDate = createdAt ? new Date(createdAt * 1000).toISOString() : "";
  const rows = [["Session Date (UTC)", "Group", "Included", ...keys]];
  records.forEach((record) => {
    const shot = record.shot || {};
    const csvValue = (value) => typeof value === "string" && /^[=+\-@\t\r]/.test(value) ? `'${value}` : value;
    rows.push([
      sessionDate,
      csvValue(groupLabels.get(String(record.group_id)) || "Group"),
      record.included === false ? "false" : "true",
      ...keys.map((key) => {
        const value = shot[key];
        return csvValue(value != null && typeof value === "object" ? JSON.stringify(value) : value ?? "");
      })
    ]);
  });
  const csv = rows.map((row) => row.map((value) => `"${String(value).replace(/"/g, '""')}"`).join(",")).join("\r\n");
  const blob = new Blob(["\uFEFF", csv], { type: "text/csv;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = `shot-analysis-${session.id}.csv`;
  document.body.appendChild(link);
  link.click();
  link.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

const SHOT_STAT_CATEGORIES = ["Distance & Height", "Ball Speed", "Ball Flight", "Club & Face", "Spin", "Other"];
const SHOT_STAT_LABELS = {
  Speed: "Ball Speed", BallSpeed: "Ball Speed", ClubSpeed: "Club Speed",
  CarryDistance: "Carry", TotalDistance: "Distance", SideDistance: "Offline",
  TotalSpin: "Spin", BackSpin: "Back Spin", SideSpin: "Side Spin",
  SpinAxis: "Spin Axis", Apex: "Apex", LaunchAngle: "Launch Angle",
  VLA: "VLA", HLA: "HLA", DescentAngle: "Descent Angle", HangTime: "Hang Time"
};
const SHOT_GROUP_COLORS = ["#1ad9ff", "#ffb81f", "#ff4d5c", "#66e66b", "#c777ff", "#ff8533", "#59f2b8", "#f28cb7"];

function shotStatCategory(key) {
  const normalized = key.toLowerCase().replace(/[_ -]/g, "");
  if (["carrydistance", "totaldistance", "distance", "carry", "apex", "height", "peakheight", "hangtime"].includes(normalized)) return "Distance & Height";
  if (["speed", "ballspeed", "clubspeed", "smashfactor"].includes(normalized)) return "Ball Speed";
  if (["launchangle", "vla", "hla", "sidedistance", "offline", "direction", "shotdirection", "descentangle", "landingangle"].includes(normalized)) return "Ball Flight";
  if (["clubpath", "faceangle", "facetopath", "attackangle", "dynamicloft", "clubfaceangle", "facetotarget"].includes(normalized)) return "Club & Face";
  if (["totalspin", "backspin", "sidespin", "spinaxis", "spinrate"].includes(normalized)) return "Spin";
  return "Other";
}

function shotStatKeys(records) {
  const excluded = new Set([
    "aimdistance", "aimdistanceyards", "club", "player", "playername",
    "recordedinaverages", "shotreduction", "shotreductionm", "shottype",
    "targetdistance", "tracerpoints"
  ]);
  const keys = new Set();
  records.forEach((record) => Object.entries(record.shot || {}).forEach(([key, value]) => {
    const normalized = key.toLowerCase().replace(/[_ -]/g, "");
    if (excluded.has(normalized)) return;
    if (normalized === "speed" || normalized === "ballspeed") keys.add("BallSpeed");
    else if (normalized === "descentangle" || normalized === "landingangle") keys.add("DescentAngle");
    else keys.add(key);
  }));
  return [...keys].sort((a, b) => {
    const categoryDiff = SHOT_STAT_CATEGORIES.indexOf(shotStatCategory(a)) - SHOT_STAT_CATEGORIES.indexOf(shotStatCategory(b));
    if (categoryDiff === 0 && shotStatCategory(a) === "Ball Flight") {
      const descentA = ["descentangle", "landingangle"].includes(a.toLowerCase().replace(/[_ -]/g, ""));
      const descentB = ["descentangle", "landingangle"].includes(b.toLowerCase().replace(/[_ -]/g, ""));
      if (descentA !== descentB) return descentA ? -1 : 1;
    }
    return categoryDiff || (SHOT_STAT_LABELS[a] || a).localeCompare(SHOT_STAT_LABELS[b] || b);
  });
}

function shotStatUnit(key, units) {
  const normalized = key.toLowerCase().replace(/[_ -]/g, "");
  const imperial = units !== "metric";
  if (["carrydistance", "totaldistance", "distance", "carry", "sidedistance", "offline", "rollout"].includes(normalized)) return imperial ? "yd" : "m";
  if (["apex", "height", "peakheight"].includes(normalized)) return imperial ? "ft" : "m";
  if (["ballspeed", "speed", "clubspeed"].includes(normalized)) return imperial ? "mph" : "m/s";
  return "";
}

function shotAnalysisDisplayValue(shot, key, units) {
  const value = shotAnalysisValue(shot, key);
  if (typeof value !== "number") return value;
  const normalized = key.toLowerCase().replace(/[_ -]/g, "");
  if (["ballspeed", "speed", "clubspeed"].includes(normalized)) return units === "metric" ? value * 0.44704 : value;
  if (["carrydistance", "totaldistance", "distance", "carry", "sidedistance", "offline", "rollout"].includes(normalized)) return units === "metric" ? value : value * 1.09361;
  if (["apex", "height", "peakheight"].includes(normalized)) return units === "metric" ? value : value * 3.28084;
  return value;
}

function formatShotValue(value) {
  if (typeof value === "number") return Number.isInteger(value) ? String(value) : value.toFixed(2);
  if (value == null) return "—";
  if (typeof value === "object") return JSON.stringify(value);
  return String(value);
}

function shotAnalysisValue(shot, key) {
  if (key === "BallSpeed") return shot.BallSpeed ?? shot.Speed ?? null;
  if (key === "DescentAngle") return shot.DescentAngle ?? shot.descent_angle ?? shot.landing_angle ?? null;
  return Object.prototype.hasOwnProperty.call(shot, key) ? shot[key] : null;
}

function shotAnalysisDispersionStats(records, groupId, useDistance, units = "imperial") {
  const unitFactor = units === "metric" ? 1 : 1.09361;
  const values = records
    .filter((record) => String(record.group_id) === String(groupId) && record.included !== false)
    .map((record) => {
      const shot = record.shot || {};
      if (useDistance) {
        return Math.max(0, Number(shot.TotalDistance ?? shot.CarryDistance ?? 0) * unitFactor);
      }
      let meters = Number(shot.SideDistance || 0);
      const trace = shot.tracer_points;
      if (Math.abs(meters) < 0.001 && Array.isArray(trace) && trace.length > 1 && Array.isArray(trace[0]) && Array.isArray(trace.at(-1))) {
        meters = Number(trace.at(-1)[2] || 0) - Number(trace[0][2] || 0);
      }
      return meters * unitFactor;
    })
    .filter(Number.isFinite);
  if (!values.length) return { mean: 0, radius: 0 };
  const mean = values.reduce((sum, value) => sum + value, 0) / values.length;
  const variance = values.reduce((sum, value) => sum + (value - mean) ** 2, 0) / values.length;
  return { mean, radius: Math.max(Math.sqrt(variance) * 2, 5) };
}

function renderSelectedShotAnalysis() {
  const detail = document.getElementById("shot-analysis-detail");
  const session = selectedShotAnalysis;
  if (!detail || !session) return;
  detail.removeAttribute("hidden");
  const timestamp = Number(session.created_at || 0);
  document.getElementById("shot-analysis-detail-title").textContent =
    `Shot data · ${timestamp ? new Date(timestamp * 1000).toLocaleString() : "Date unavailable"}`;
  renderShotAnalysisTable(session);
  drawShotAnalysisCharts(session);
}

function renderShotAnalysisTable(session) {
  const container = document.getElementById("shot-analysis-table");
  const records = Array.isArray(session.records) ? session.records : [];
  const groups = Array.isArray(session.groups) ? session.groups : [];
  const units = session.display_units === "metric" ? "metric" : "imperial";
  const keys = shotStatKeys(records);
  const groupsHtml = groups.map((group) => {
    const groupRecords = records.filter((record) => String(record.group_id) === String(group.id));
    const columns = keys.map((key) => {
      const label = SHOT_STAT_LABELS[key] || key.replace(/_/g, " ");
      const unit = shotStatUnit(key, units);
      return `<th>${escapeHtml(unit ? `${label} (${unit})` : label)}</th>`;
    }).join("");
    const shotsHtml = groupRecords.map((record) => {
      const shot = record.shot || {};
      const className = record.included === false ? "excluded-shot" : "";
      return `<tr class="${className}"><td>${record.included === false ? "Excluded" : "Included"}</td>${keys.map((key) => {
        const value = shotAnalysisDisplayValue(shot, key, units);
        return `<td title="${escapeHtml(formatShotValue(value))}">${escapeHtml(formatShotValue(value))}</td>`;
      }).join("")}</tr>`;
    }).join("");
    const included = groupRecords.filter((record) => record.included !== false);
    const averages = keys.map((key) => {
      const numeric = included.map((record) => shotAnalysisDisplayValue(record.shot || {}, key, units)).filter((value) => typeof value === "number" && Number.isFinite(value));
      return numeric.length ? formatShotValue(numeric.reduce((sum, value) => sum + value, 0) / numeric.length) : "—";
    });
    return `<tbody>
      <tr class="category-heading"><th colspan="${keys.length + 1}">${escapeHtml(group.label || "Group")} · ${included.length} of ${groupRecords.length} included</th></tr>
      <tr><th>Use</th>${columns}</tr>
      ${shotsHtml}
      <tr class="average-row"><td>Average</td>${averages.map((value) => `<td>${escapeHtml(value)}</td>`).join("")}</tr>
    </tbody>`;
  }).join("");
  const categoryHeaders = [];
  keys.forEach((key) => {
    const category = shotStatCategory(key);
    const last = categoryHeaders[categoryHeaders.length - 1];
    if (last && last.name === category) last.count += 1;
    else categoryHeaders.push({ name: category, count: 1 });
  });
  const categoryRow = categoryHeaders.map((category) => `<th colspan="${category.count}">${escapeHtml(category.name)}</th>`).join("");
  container.innerHTML = `<table class="data-table shot-analysis-table">
    <thead><tr><th></th>${categoryRow}</tr></thead>${groupsHtml}
  </table>`;
}

function drawShotAnalysisCharts(session) {
  const canvas = document.getElementById("shot-analysis-canvas");
  if (!canvas) return;
  const bounds = canvas.getBoundingClientRect();
  if (!bounds.width || !bounds.height) return;
  const ratio = window.devicePixelRatio || 1;
  canvas.width = Math.round(bounds.width * ratio);
  canvas.height = Math.round(bounds.height * ratio);
  const ctx = canvas.getContext("2d");
  ctx.scale(ratio, ratio);
  const width = bounds.width, height = bounds.height;
  ctx.clearRect(0, 0, width, height);
  ctx.fillStyle = "#0e1624";
  ctx.fillRect(0, 0, width, height);
  const records = Array.isArray(session.records) ? session.records : [];
  const groups = Array.isArray(session.groups) ? session.groups : [];
  const units = session.display_units === "metric" ? "metric" : "imperial";
  const unitFactor = units === "metric" ? 1 : 1.09361;
  const distanceUnit = units === "metric" ? "m" : "yd";
  const apexUnitFactor = units === "metric" ? 1 : 3;
  const mode = document.getElementById("shot-analysis-view-mode")?.value || "best";
  const yards = (shot, total = false) => Math.max(0, Number(shot?.[total ? "TotalDistance" : "CarryDistance"] ?? shot?.TotalDistance ?? shot?.CarryDistance ?? 0) * unitFactor);
  const offline = (shot) => {
    let value = Number(shot?.SideDistance || 0);
    const trace = shot?.tracer_points;
    if (Math.abs(value) < 0.001 && Array.isArray(trace) && trace.length > 1 && Array.isArray(trace[0]) && Array.isArray(trace.at(-1))) {
      value = Number(trace.at(-1)[2] || 0) - Number(trace[0][2] || 0);
    }
    return value * unitFactor;
  };
  const includedFor = (group) => records.filter((record) => String(record.group_id) === String(group.id) && record.included !== false);
  const representatives = groups.map((group) => {
    const included = includedFor(group);
    if (!included.length) return null;
    if (mode === "best") return included.reduce((best, record) => yards(record.shot, true) > yards(best.shot, true) ? record : best);
    const average = {};
    ["CarryDistance", "TotalDistance", "Apex"].forEach((key) => {
      const nums = included.map((record) => record.shot?.[key]).filter((value) => typeof value === "number" && Number.isFinite(value));
      if (nums.length) average[key] = nums.reduce((sum, value) => sum + value, 0) / nums.length;
    });
    return { shot: average };
  });
  let maxFlightHeight = 5;
  const flightSeries = representatives.map((representative) => {
    if (!representative) return [];
    const shot = representative.shot || {};
    const trace = shot.tracer_points;
    if (Array.isArray(trace) && trace.length > 1 && trace.every((point) => Array.isArray(point) && point.length >= 3 && point.every(Number.isFinite))) {
      const start = trace[0];
      const points = trace.map((point) => [
        Math.hypot(point[0] - start[0], point[2] - start[2]) * unitFactor,
        Math.max(0, point[1] - start[1]) * unitFactor
      ]);
      maxFlightHeight = Math.max(maxFlightHeight, ...points.map((point) => point[1]));
      return points;
    }
    const distance = Math.max(1, yards(shot));
    const apex = Math.max(1, Number(shot.Apex || 0) * unitFactor);
    maxFlightHeight = Math.max(maxFlightHeight, apex);
    return Array.from({ length: 41 }, (_, index) => {
      const t = index / 40;
      return [distance * t, 4 * apex * t * (1 - t)];
    });
  });
  maxFlightHeight *= 1.3;
  let maxDistance = Math.max(
    0,
    ...records.map((record) => yards(record.shot, true)),
    ...representatives.filter(Boolean).map((record) => yards(record.shot, true)),
    ...flightSeries.flatMap((points) => points.map((point) => point[0])),
    ...groups.map((group) => {
      const dispersion = shotAnalysisDispersionStats(records, group.id, true, units);
      return dispersion.mean + dispersion.radius;
    })
  );
  maxDistance = Math.max(50, Math.ceil(maxDistance * 1.1 / 50) * 50);
  const left = 64, right = width - 18;
  const flightTop = 42, flightBottom = height * 0.30;
  const rulerY = height * 0.36;
  const dispersionTop = height * 0.52, dispersionBottom = height - 24;
  const xFor = (distance) => left + Math.max(0, Math.min(1, distance / maxDistance)) * (right - left);
  const drawText = (text, x, y, color = "#c5d0df", size = 11) => {
    ctx.fillStyle = color;
    ctx.font = `${size}px system-ui, sans-serif`;
    ctx.fillText(text, x, y);
  };
  drawText(`FLIGHT PATH · ${mode === "best" ? "BEST SHOT" : "GROUP AVERAGE"}`, 16, 20, "#c5d0df", 12);
  groups.forEach((group, index) => {
    const representative = representatives[index];
    const points = flightSeries[index];
    const color = SHOT_GROUP_COLORS[index % SHOT_GROUP_COLORS.length];
    const legendX = left + (index % Math.max(1, Math.floor((right - left) / 190))) * 190;
    const legendY = flightTop + 12 + Math.floor(index / Math.max(1, Math.floor((right - left) / 190))) * 14;
    drawText(String(group.label || "Group"), legendX, legendY, color, 10);
    if (!representative) return;
    ctx.beginPath();
    ctx.strokeStyle = color;
    ctx.lineWidth = 2;
    let apexIndex = 0;
    points.forEach((point, pointIndex) => {
      const px = xFor(point[0]);
      const py = flightBottom - (point[1] / maxFlightHeight) * (flightBottom - flightTop - 18);
      if (point[1] > points[apexIndex][1]) apexIndex = pointIndex;
      if (pointIndex === 0) ctx.moveTo(px, py);
      else ctx.lineTo(px, py);
    });
    ctx.stroke();
    const apexPoint = points[apexIndex];
    drawText(`APEX ${(apexPoint[1] * apexUnitFactor).toFixed(0)} ${units === "metric" ? "m" : "ft"}`, xFor(apexPoint[0]) + 4, flightBottom - (apexPoint[1] / maxFlightHeight) * (flightBottom - flightTop - 18) - 4, color, 9);
  });
  for (let distance = 0; distance <= maxDistance; distance += 50) {
    const x = xFor(distance);
    ctx.strokeStyle = "rgba(160,180,205,.2)";
    ctx.beginPath(); ctx.moveTo(x, flightTop); ctx.lineTo(x, flightBottom); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(x, dispersionTop); ctx.lineTo(x, dispersionBottom); ctx.stroke();
    ctx.strokeStyle = "rgba(220,230,245,.7)";
    ctx.beginPath(); ctx.moveTo(x, rulerY - 4); ctx.lineTo(x, rulerY + 4); ctx.stroke();
    drawText(`${distance} ${distanceUnit}`, Math.max(2, Math.min(width - 42, x - 16)), rulerY + 18, "#c5d0df", 9);
  }
  ctx.strokeStyle = "rgba(220,230,245,.55)";
  ctx.beginPath(); ctx.moveTo(left, rulerY); ctx.lineTo(right, rulerY); ctx.stroke();
  drawText("DISTANCE SCALE", 16, rulerY + 4, "#c5d0df", 10);
  drawText("LANDING DISPERSION · DIMMED SHOTS ARE EXCLUDED", 16, height * 0.46, "#c5d0df", 12);
  const lateralExtent = Math.max(
    0,
    ...records.map((record) => Math.abs(offline(record.shot))),
    ...groups.map((group) => {
      const dispersion = shotAnalysisDispersionStats(records, group.id, false, units);
      return Math.abs(dispersion.mean) + dispersion.radius;
    })
  );
  const lateralMax = Math.max(15, Math.ceil(lateralExtent * 1.15 / 5) * 5);
  const centerY = (dispersionTop + dispersionBottom) / 2;
  ctx.strokeStyle = "rgba(220,230,245,.45)";
  ctx.beginPath(); ctx.moveTo(left, centerY); ctx.lineTo(right, centerY); ctx.stroke();
  drawText("RIGHT", 18, dispersionTop + 12);
  drawText("LEFT", 18, dispersionBottom);
  groups.forEach((group, groupIndex) => {
    const color = SHOT_GROUP_COLORS[groupIndex % SHOT_GROUP_COLORS.length];
    const activePoints = [];
    records.forEach((record) => {
      if (String(record.group_id) !== String(group.id)) return;
      const x = xFor(yards(record.shot, true));
      const y = centerY - Math.max(-1, Math.min(1, offline(record.shot) / lateralMax)) * ((dispersionBottom - dispersionTop) / 2);
      ctx.globalAlpha = record.included === false ? 0.2 : 0.92;
      ctx.fillStyle = color;
      ctx.beginPath(); ctx.arc(x, y, record.included === false ? 3 : 4, 0, Math.PI * 2); ctx.fill();
      if (record.included !== false) activePoints.push([x, y]);
    });
    if (activePoints.length < 2) return;
    const meanX = activePoints.reduce((sum, point) => sum + point[0], 0) / activePoints.length;
    const meanY = activePoints.reduce((sum, point) => sum + point[1], 0) / activePoints.length;
    const varianceX = activePoints.reduce((sum, point) => sum + (point[0] - meanX) ** 2, 0) / activePoints.length;
    const varianceY = activePoints.reduce((sum, point) => sum + (point[1] - meanY) ** 2, 0) / activePoints.length;
    const radiusX = Math.min(Math.max(Math.sqrt(varianceX) * 2, 5), Math.max(0, Math.min(meanX - left, right - meanX) - 2));
    const radiusY = Math.min(Math.max(Math.sqrt(varianceY) * 2, 5), Math.max(0, Math.min(meanY - dispersionTop, dispersionBottom - meanY) - 2));
    if (radiusX < 1 || radiusY < 1) return;
    ctx.globalAlpha = 1;
    ctx.beginPath();
    for (let point = 0; point <= 40; point++) {
      const angle = Math.PI * 2 * point / 40;
      const x = meanX + Math.cos(angle) * radiusX;
      const y = meanY + Math.sin(angle) * radiusY;
      if (point === 0) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);
    }
    ctx.closePath();
    ctx.fillStyle = `${color}14`;
    ctx.strokeStyle = `${color}b8`;
    ctx.lineWidth = 1.5;
    ctx.fill();
    ctx.stroke();
  });
  ctx.globalAlpha = 1;
}

// ─── LOAD USER DATA (READ 1 & READ 2) ───
export async function ensurePublicProfileSynced(user, profile) {
  if (!user || !profile) return;
  try {
    const optIn = profile?.privacy?.leaderboard_opt_in !== false;
    if (!optIn) {
      try {
        await deleteDoc(doc(db, "public_profiles", user.uid));
      } catch {}
      return;
    }

    const lt = profile.lifetime || {};
    const rec = profile.records || {};
    const ach = profile.achievements || {};
    let achCount = 0;
    if (ach.unlocked && typeof ach.unlocked === "object") {
      achCount = Object.keys(ach.unlocked).length;
    }
    if (typeof lt.achievements_count === "number" && lt.achievements_count > achCount) {
      achCount = lt.achievements_count;
    }

    const longestDr = Number(lt.longest_drive_yds ?? rec.longest_drive ?? rec.longest_drive_yds ?? profile.longest_drive_yds ?? 0);
    const longestPt = Number(lt.longest_putt_ft ?? rec.longest_putt ?? rec.longest_putt_ft ?? profile.longest_putt_ft ?? 0);
    const matchesPl = Number(lt.matches_played ?? 0);
    const wins = Number(lt.wins ?? 0);

    const rawName = profile.display_name || user.displayName || user.email?.split("@")[0] || "Golfer";
    const displayName = String(rawName).trim().slice(0, 40) || "Golfer";

    const pubData = {
      schema_version: 1,
      uid: user.uid,
      display_name: displayName,
      avatar: String(profile.avatar || ""),
      longest_drive_yds: Math.min(Math.max(0, isNaN(longestDr) ? 0 : longestDr), 450.0),
      longest_putt_ft: Math.min(Math.max(0, isNaN(longestPt) ? 0 : longestPt), 180.0),
      achievements_count: Math.min(Math.max(0, isNaN(achCount) ? 0 : achCount), 100),
      matches_played: Math.min(Math.max(0, isNaN(matchesPl) ? 0 : matchesPl), 100000),
      wins: Math.min(Math.max(0, isNaN(wins) ? 0 : wins), 100000),
      updated_at: Math.floor(Date.now() / 1000)
    };

    const bg18 = Number(lt.best_gross_18 ?? rec.best_gross_18);
    if (!isNaN(bg18) && bg18 >= 18 && bg18 <= 250) {
      pubData.best_gross_18 = bg18;
      const btp18 = Number(lt.best_to_par_18 ?? rec.best_to_par_18);
      if (!isNaN(btp18) && btp18 >= -36 && btp18 <= 180) pubData.best_to_par_18 = btp18;
    }

    const bg9 = Number(lt.best_gross_9 ?? rec.best_gross_9);
    if (!isNaN(bg9) && bg9 >= 9 && bg9 <= 130) {
      pubData.best_gross_9 = bg9;
      const btp9 = Number(lt.best_to_par_9 ?? rec.best_to_par_9);
      if (!isNaN(btp9) && btp9 >= -18 && btp9 <= 90) pubData.best_to_par_9 = btp9;
    }

    // Write directly without merge: true to purge any legacy invalid fields
    await setDoc(doc(db, "public_profiles", user.uid), pubData);

    // Clear stale cached leaderboard entries
    sessionStorage.removeItem("hgs_lb_longest_drive");
    sessionStorage.removeItem("hgs_lb_longest_putt");
    sessionStorage.removeItem("hgs_lb_lowest_score_18");
    sessionStorage.removeItem("hgs_lb_lowest_score_9");
    sessionStorage.removeItem("hgs_lb_most_wins");
    sessionStorage.removeItem("hgs_lb_most_matches");
    sessionStorage.removeItem("hgs_lb_achievements");
  } catch (err) {
    console.warn("[Portal] Public leaderboard projection sync warning:", err);
  }
}

async function loadUserData(user) {
  updateUserHeader(user);
  updateVerificationBanner(user);

  try {
    // 1. Read 1: profiles/{uid}
    const profileSnap = await getDoc(doc(db, "profiles", user.uid));
    if (profileSnap.exists()) {
      currentProfile = profileSnap.data();
    } else {
      currentProfile = {
        schema_version: 1,
        owner_uid: user.uid,
        display_name: user.displayName || user.email.split("@")[0],
        updated_at: Math.floor(Date.now() / 1000)
      };
    }

    // Also fetch sync/stats if available to ensure full telemetry & records
    try {
      const statsSnap = await getDoc(doc(db, "profiles", user.uid, "sync", "stats"));
      if (statsSnap.exists()) {
        const syncStats = statsSnap.data();
        currentStats = syncStats;
        if (!currentProfile.lifetime) currentProfile.lifetime = {};
        const lt = currentProfile.lifetime;
        const rec = syncStats.records || {};
        const recDr = Number(rec.longest_drive_yds ?? rec.longest_drive ?? 0);
        if (recDr > Number(lt.longest_drive_yds ?? 0)) {
          lt.longest_drive_yds = recDr;
        }
        const recPt = Number(rec.longest_putt_ft ?? rec.longest_putt ?? 0);
        if (recPt > Number(lt.longest_putt_ft ?? 0)) {
          lt.longest_putt_ft = recPt;
        }

        if (syncStats.achievements && typeof syncStats.achievements === "object") {
          currentProfile.achievements = syncStats.achievements;
          const unl = syncStats.achievements.unlocked;
          if (unl && typeof unl === "object") {
            const achCount = Object.keys(unl).length;
            if (achCount > (lt.achievements_count || 0)) {
              lt.achievements_count = achCount;
            }
          }
        }

        if (syncStats.clubs && typeof syncStats.clubs === "object") {
          if (!currentProfile.club_summary) currentProfile.club_summary = {};
          for (const [clb, rawShots] of Object.entries(syncStats.clubs)) {
            if (!Array.isArray(rawShots) || rawShots.length === 0) continue;
            const existing = currentProfile.club_summary[clb] || {};
            let carrySum = 0, totalSum = 0, speedSum = 0, clubSpeedSum = 0, clubSpeedCount = 0;
            let smashSum = 0, smashCount = 0;
            let spinSum = 0, offlineSum = 0;
            let faceSum = 0, faceCount = 0, pathSum = 0, pathCount = 0, ftpSum = 0, ftpCount = 0;
            let vlaSum = 0, vlaCount = 0, hlaSum = 0, hlaCount = 0;
            let backSpinSum = 0, backSpinCount = 0, sideSpinSum = 0, sideSpinCount = 0, spinAxisSum = 0, spinAxisCount = 0;
            let aoaSum = 0, aoaCount = 0, dynLoftSum = 0, dynLoftCount = 0;
            let apexSum = 0, apexCount = 0, hangTimeSum = 0, hangTimeCount = 0, descentAngleSum = 0, descentAngleCount = 0, rolloutSum = 0, rolloutCount = 0;
            const impactPts = [];

            rawShots.forEach((s) => {
              const cm = Number(s.CarryDistance ?? s.c ?? 0);
              const tm = Number(s.TotalDistance ?? s.tot ?? 0);
              carrySum += cm * 1.09361;
              totalSum += tm * 1.09361;
              const bs = Number(s.BallSpeed ?? s.Speed ?? s.bs ?? 0);
              speedSum += bs;

              const cs = Number(s.ClubSpeed ?? s.cs ?? 0);
              if (cs > 0.01) {
                clubSpeedSum += cs;
                clubSpeedCount++;
              }

              let sf = Number(s.SmashFactor ?? s.sf ?? 0);
              if (sf <= 0 && cs > 0 && bs > 0) sf = bs / cs;
              if (sf > 0.05) {
                smashSum += sf;
                smashCount++;
              }

              spinSum += Number(s.TotalSpin ?? s.sp ?? 0);
              const sideM = Math.abs(Number(s.SideDistance ?? s.sd ?? 0));
              offlineSum += sideM * 1.09361;

              let curFa = null;
              if (s.FaceAngle != null || s.ClubFaceAngle != null || s.fa != null) {
                curFa = Number(s.FaceAngle ?? s.ClubFaceAngle ?? s.fa);
                faceSum += curFa;
                faceCount++;
              }
              let curCp = null;
              if (s.ClubPath != null || s.Path != null || s.cp != null) {
                curCp = Number(s.ClubPath ?? s.Path ?? s.cp);
                pathSum += curCp;
                pathCount++;
              }
              if (s.FaceToPath != null || s.ftp != null) {
                ftpSum += Number(s.FaceToPath ?? s.ftp);
                ftpCount++;
              } else if (curFa != null && curCp != null) {
                ftpSum += (curFa - curCp);
                ftpCount++;
              }

              if (s.VLA != null || s.LaunchAngle != null || s.VerticalLaunchAngle != null || s.vla != null) {
                vlaSum += Number(s.VLA ?? s.LaunchAngle ?? s.VerticalLaunchAngle ?? s.vla);
                vlaCount++;
              }
              if (s.HLA != null || s.HorizontalLaunchAngle != null || s.hla != null) {
                hlaSum += Number(s.HLA ?? s.HorizontalLaunchAngle ?? s.hla);
                hlaCount++;
              }

              if (s.BackSpin != null || s.back_spin != null) {
                const bVal = Number(s.BackSpin ?? s.back_spin);
                if (bVal > 0) {
                  backSpinSum += bVal;
                  backSpinCount++;
                }
              }
              if (s.SideSpin != null || s.side_spin != null) {
                sideSpinSum += Number(s.SideSpin ?? s.side_spin);
                sideSpinCount++;
              }
              if (s.SpinAxis != null || s.spin_axis != null) {
                spinAxisSum += Number(s.SpinAxis ?? s.spin_axis);
                spinAxisCount++;
              }

              if (s.AttackAngle != null || s.AngleOfAttack != null || s.aoa != null) {
                aoaSum += Number(s.AttackAngle ?? s.AngleOfAttack ?? s.aoa);
                aoaCount++;
              }
              if (s.DynamicLoft != null || s.dynamic_loft != null) {
                dynLoftSum += Number(s.DynamicLoft ?? s.dynamic_loft);
                dynLoftCount++;
              }

              if (s.Apex != null || s.apex != null || s.PeakHeight != null) {
                apexSum += Number(s.Apex ?? s.apex ?? s.PeakHeight) * 3.28084;
                apexCount++;
              } else if (s.apex_ft != null) {
                apexSum += Number(s.apex_ft);
                apexCount++;
              }

              if (s.HangTime != null || s.hang_time != null || s.flight_time != null) {
                hangTimeSum += Number(s.HangTime ?? s.hang_time ?? s.flight_time);
                hangTimeCount++;
              }
              if (s.DescentAngle != null || s.descent_angle != null) {
                descentAngleSum += Number(s.DescentAngle ?? s.descent_angle);
                descentAngleCount++;
              }

              if (s.Rollout != null || s.rollout != null) {
                rolloutSum += Number(s.Rollout ?? s.rollout) * 1.09361;
                rolloutCount++;
              } else if (tm > cm && cm > 0) {
                rolloutSum += (tm - cm) * 1.09361;
                rolloutCount++;
              }

              if (s.HorizontalFaceImpact != null || s.VerticalFaceImpact != null || s.hi != null || s.vi != null) {
                impactPts.push({
                  h: Math.round(Number(s.HorizontalFaceImpact ?? s.hi ?? 0) * 10) / 10,
                  v: Math.round(Number(s.VerticalFaceImpact ?? s.vi ?? 0) * 10) / 10
                });
              }
            });

            const n = rawShots.length;
            const avgCs = clubSpeedCount > 0 ? clubSpeedSum / clubSpeedCount : 0;
            const avgBs = speedSum / n;
            const recImpact = impactPts.slice(-50);

            currentProfile.club_summary[clb] = {
              count: existing.count ?? n,
              carry_yds: existing.carry_yds ?? (carrySum / n),
              total_yds: existing.total_yds ?? (totalSum / n),
              ball_speed_mph: existing.ball_speed_mph ?? avgBs,
              club_speed_mph: existing.avg_club_speed_mph ?? existing.club_speed_mph ?? avgCs,
              has_club_speed: existing.has_club_speed ?? (clubSpeedCount > 0 || avgCs > 0),
              smash: existing.avg_smash_factor ?? existing.smash ?? (smashCount > 0 ? smashSum / smashCount : (avgCs > 0 ? avgBs / avgCs : 0)),
              has_smash_factor: existing.has_smash_factor ?? (smashCount > 0 || (avgCs > 0 && avgBs > 0)),
              spin_rpm: existing.spin_rpm ?? Math.round(spinSum / n),
              avg_offline_yds: existing.avg_offline_yds ?? existing.offline_yds ?? (offlineSum / n),
              avg_face_angle: existing.avg_face_angle ?? (faceCount > 0 ? faceSum / faceCount : 0),
              has_face_angle: existing.has_face_angle ?? (faceCount > 0),
              face_angle_count: existing.face_angle_count ?? faceCount,
              avg_club_path: existing.avg_club_path ?? (pathCount > 0 ? pathSum / pathCount : 0),
              has_club_path: existing.has_club_path ?? (pathCount > 0),
              club_path_count: existing.club_path_count ?? pathCount,
              avg_face_to_path: existing.avg_face_to_path ?? (ftpCount > 0 ? ftpSum / ftpCount : 0),
              has_face_to_path: existing.has_face_to_path ?? (ftpCount > 0),
              avg_vla_deg: existing.avg_vla_deg ?? (vlaCount > 0 ? vlaSum / vlaCount : 0),
              has_vla: existing.has_vla ?? (vlaCount > 0),
              avg_hla_deg: existing.avg_hla_deg ?? (hlaCount > 0 ? hlaSum / hlaCount : 0),
              has_hla: existing.has_hla ?? (hlaCount > 0),
              avg_back_spin_rpm: existing.avg_back_spin_rpm ?? (backSpinCount > 0 ? backSpinSum / backSpinCount : 0),
              has_back_spin: existing.has_back_spin ?? (backSpinCount > 0),
              avg_side_spin_rpm: existing.avg_side_spin_rpm ?? (sideSpinCount > 0 ? sideSpinSum / sideSpinCount : 0),
              has_side_spin: existing.has_side_spin ?? (sideSpinCount > 0),
              avg_spin_axis_deg: existing.avg_spin_axis_deg ?? (spinAxisCount > 0 ? spinAxisSum / spinAxisCount : 0),
              has_spin_axis: existing.has_spin_axis ?? (spinAxisCount > 0),
              avg_attack_angle: existing.avg_attack_angle ?? (aoaCount > 0 ? aoaSum / aoaCount : 0),
              has_attack_angle: existing.has_attack_angle ?? (aoaCount > 0),
              avg_dynamic_loft: existing.avg_dynamic_loft ?? (dynLoftCount > 0 ? dynLoftSum / dynLoftCount : 0),
              has_dynamic_loft: existing.has_dynamic_loft ?? (dynLoftCount > 0),
              avg_apex_ft: existing.avg_apex_ft ?? (existing.avg_apex_m != null ? existing.avg_apex_m * 3.28084 : (apexCount > 0 ? apexSum / apexCount : 0)),
              has_apex: existing.has_apex ?? (apexCount > 0),
              avg_hang_time_s: existing.avg_hang_time_s ?? (hangTimeCount > 0 ? hangTimeSum / hangTimeCount : 0),
              has_hang_time: existing.has_hang_time ?? (hangTimeCount > 0),
              avg_descent_angle_deg: existing.avg_descent_angle_deg ?? (descentAngleCount > 0 ? descentAngleSum / descentAngleCount : 0),
              has_descent_angle: existing.has_descent_angle ?? (descentAngleCount > 0),
              avg_rollout_yds: existing.avg_rollout_yds ?? (existing.avg_rollout_m != null ? existing.avg_rollout_m * 1.09361 : (rolloutCount > 0 ? rolloutSum / rolloutCount : 0)),
              has_rollout: existing.has_rollout ?? (rolloutCount > 0),
              impact_points: existing.impact_points ?? recImpact,
              has_impact_data: existing.has_impact_data ?? (recImpact.length > 0)
            };
          }
        }
        if (syncStats.best_courses && typeof syncStats.best_courses === "object") {
          currentProfile.best_courses = {
            ...(syncStats.best_courses || {}),
            ...(currentProfile.best_courses || {})
          };
        }
      }
    } catch (e) {
      console.warn("[Portal] Could not load sync/stats:", e);
    }

    updateUserHeader(user, currentProfile);
    renderOverviewCards(currentProfile);
    renderProfilePreferencesSummary(currentProfile);
    renderClubSummary(currentProfile);
    await renderBestCourses(currentProfile);
    loadedTabs.overview = true;

    // Ensure public leaderboard projection has latest lifetime records
    await ensurePublicProfileSynced(user, currentProfile);

    // 2. Read 2: Check incoming link requests (if email is verified)
    if (user.emailVerified) {
      await checkIncomingLinkRequests(user);
    }
  } catch (err) {
    console.error("Error loading user profile:", err);
  }
}

function updateUserHeader(user, profile) {
  const avatarEl = document.getElementById("portal-avatar-initial");
  const nameEl = document.getElementById("portal-user-display-name");
  const emailEl = document.getElementById("portal-user-email");

  const displayName = profile?.display_name || user.displayName || user.email.split("@")[0];
  const initial = (displayName || "?").charAt(0).toUpperCase();
  if (avatarEl) avatarEl.textContent = initial;
  if (nameEl) nameEl.textContent = displayName;
  if (emailEl) emailEl.textContent = user.email;
}

function updateVerificationBanner(user) {
  const banner = document.getElementById("verification-banner");
  if (!banner) return;
  if (!user.emailVerified) {
    banner.classList.add("active");
  } else {
    banner.classList.remove("active");
  }
}

// ─── LINK REQUESTS & APPROVALS (REQUIREMENT 3) ───
async function checkIncomingLinkRequests(user) {
  const banner = document.getElementById("approvals-banner");
  const container = document.getElementById("approvals-list");
  if (!banner || !container) return;

  try {
    const emailLower = user.email.toLowerCase();
    const q = query(
      collection(db, "link_requests"),
      where("target_email_lower", "==", emailLower)
    );
    const snap = await getDocs(q);
    const pendingRequests = [];

    snap.forEach((d) => {
      const data = d.data();
      if (data.status === "pending") {
        pendingRequests.push({ id: d.id, ...data });
      }
    });

    if (pendingRequests.length === 0) {
      banner.classList.remove("active");
      container.innerHTML = "";
      return;
    }

    banner.classList.add("active");
    container.innerHTML = "";

    pendingRequests.forEach((req) => {
      const card = document.createElement("div");
      card.className = "approval-card";
      const requesterName = escapeHtml(req.requester_name || "A Golfer");
      const requesterEmail = escapeHtml(req.requester_email || "");

      card.innerHTML = `
        <div class="approval-meta">
          <strong>${requesterName}</strong> (${requesterEmail}) wants to sync your player stats on their simulator.
        </div>
        <div class="approval-btns">
          <button class="btn-approve" data-id="${req.id}">Approve Access</button>
          <button class="btn-deny" data-id="${req.id}">Deny</button>
        </div>
      `;

      card.querySelector(".btn-approve").addEventListener("click", () => approveLinkRequest(user, req));
      card.querySelector(".btn-deny").addEventListener("click", () => denyLinkRequest(user, req));
      container.appendChild(card);
    });
  } catch (err) {
    console.warn("Could not check incoming link requests:", err);
  }
}

async function approveLinkRequest(user, req) {
  if (!user.emailVerified) {
    alert("Please verify your email address before approving account link requests.");
    return;
  }

  try {
    const batch = writeBatch(db);
    const now = Math.floor(Date.now() / 1000);
    const displayName = user.displayName || user.email.split("@")[0];

    // Ensure profiles/{uid} exists
    batch.set(doc(db, "profiles", user.uid), {
      schema_version: 1,
      owner_uid: user.uid,
      display_name: displayName,
      updated_at: now
    }, { merge: true });

    // Add delegate
    batch.set(doc(db, "profiles", user.uid, "delegates", req.requester_uid), {
      delegate_uid: req.requester_uid,
      delegate_name: req.requester_name || "",
      delegate_email: req.requester_email || "",
      approved_at: now,
      request_id: req.id
    });

    // Update link request status
    batch.update(doc(db, "link_requests", req.id), {
      status: "approved",
      target_uid: user.uid,
      target_display_name: displayName,
      updated_at: now
    });

    await batch.commit();
    alert(`Access approved for ${req.requester_name || req.requester_email}! They can now select your profile on their simulator.`);
    await checkIncomingLinkRequests(user);
    if (loadedTabs.settings) {
      loadSharedAccessAndSettings(user);
    }
  } catch (err) {
    console.error("Approve link request failed:", err);
    const pauseMsg = await handleWriteError(err);
    alert(pauseMsg || ("Could not approve link request: " + err.message));
  }
}

async function denyLinkRequest(user, req) {
  if (!confirm(`Deny access request from ${req.requester_name || req.requester_email}?`)) {
    return;
  }

  try {
    const now = Math.floor(Date.now() / 1000);
    await updateDoc(doc(db, "link_requests", req.id), {
      status: "denied",
      target_uid: user.uid,
      updated_at: now
    });
    alert("Access request denied.");
    await checkIncomingLinkRequests(user);
  } catch (err) {
    console.error("Deny link request failed:", err);
    const pauseMsg = await handleWriteError(err);
    alert(pauseMsg || ("Could not deny link request: " + err.message));
  }
}

// ─── TAB 1: OVERVIEW & CLUBS ───
function renderOverviewCards(profile) {
  const lt = profile?.lifetime || {};

  // Matches
  const matchesEl = document.getElementById("stat-matches-played") || document.getElementById("stat-matches");
  if (matchesEl) matchesEl.textContent = lt.matches_played ?? 0;

  // Record W-L-T
  const recordEl = document.getElementById("stat-record");
  if (recordEl) {
    const wins = lt.wins ?? 0;
    const losses = lt.losses ?? 0;
    const ties = lt.ties ?? 0;
    recordEl.textContent = `${wins}W - ${losses}L - ${ties}T`;
  }

  // Scoring Avg to Par
  const avgParEl = document.getElementById("stat-avg-to-par") || document.getElementById("stat-avg-score");
  if (avgParEl) {
    if (lt.par_diff_matches && lt.par_diff_matches > 0) {
      const avg = lt.par_diff_sum / lt.par_diff_matches;
      avgParEl.textContent = `${avg > 0 ? "+" : ""}${avg.toFixed(1)}`;
    } else {
      avgParEl.textContent = "–";
    }
  }

  // Best 18H Score
  const best18El = document.getElementById("stat-best-18");
  if (best18El) {
    if (lt.best_to_par_18 != null) {
      const parVal = lt.best_to_par_18;
      const parStr = parVal === 0 ? "E" : parVal > 0 ? `+${parVal}` : `${parVal}`;
      best18El.textContent = lt.best_gross_18 != null ? `${parStr} (${lt.best_gross_18})` : parStr;
    } else {
      best18El.textContent = "–";
    }
  }

  // Longest Drive
  const driveEl = document.getElementById("stat-longest-drive");
  if (driveEl) {
    const dr = lt.longest_drive_yds ?? profile?.records?.longest_drive ?? profile?.records?.longest_drive_yds;
    driveEl.textContent = (dr && Number(dr) > 0) ? `${Number(dr).toFixed(1)} yds` : "–";
  }

  // Longest Putt
  const puttEl = document.getElementById("stat-longest-putt");
  if (puttEl) {
    const pt = lt.longest_putt_ft ?? profile?.records?.longest_putt ?? profile?.records?.longest_putt_ft;
    puttEl.textContent = (pt && Number(pt) > 0) ? `${Number(pt).toFixed(1)} ft` : "–";
  }

  // Achievements
  const achEl = document.getElementById("stat-achievements-count");
  if (achEl) {
    achEl.textContent = lt.achievements_count ?? 0;
  }
}

function formatSkillLevel(lvl) {
  switch (lvl) {
    case "beginner": return "Beginner (20+ Hcp)";
    case "mid_handicap": return "Mid Handicap (10-19)";
    case "low_handicap": return "Low Handicap (1-9)";
    case "scratch": return "Scratch / Pro (0 or Better)";
    default: return "Mid Handicap (10-19)";
  }
}

function formatBallGraphic(bg) {
  switch (bg) {
    case "single_line": return "Single Line";
    case "triple_track": return "Triple Track";
    case "visor": return "Visor Stripe";
    case "soccer_ball": return "Hex Soccer";
    case "truvis": return "Truvis High Contrast";
    default: return "Single Line";
  }
}

function renderProfilePreferencesSummary(profile) {
  const container = document.getElementById("profile-preferences-summary");
  if (!container) return;

  const tee = profile?.preferred_tee || "Blue";
  const skill = formatSkillLevel(profile?.skill_level);
  const dexterity = (profile?.handedness === 1) ? "Left-Handed" : "Right-Handed";
  const ball = formatBallGraphic(profile?.ball_graphic);

  container.innerHTML = `
    <div class="pref-badge">
      <span class="pref-icon">⛳</span>
      <div>
        <div class="pref-label">Preferred Tee</div>
        <div class="pref-val">${escapeHtml(tee)}</div>
      </div>
    </div>
    <div class="pref-badge">
      <span class="pref-icon">🎯</span>
      <div>
        <div class="pref-label">Skill Level</div>
        <div class="pref-val">${escapeHtml(skill)}</div>
      </div>
    </div>
    <div class="pref-badge">
      <span class="pref-icon">🏌️</span>
      <div>
        <div class="pref-label">Dexterity</div>
        <div class="pref-val">${escapeHtml(dexterity)}</div>
      </div>
    </div>
    <div class="pref-badge">
      <span class="pref-icon">⚪</span>
      <div>
        <div class="pref-label">Ball Graphic</div>
        <div class="pref-val">${escapeHtml(ball)}</div>
      </div>
    </div>
  `;
}

// ─── CLUB DELIVERY VISUALS & IMAGES ───
const CLUB_IMAGES = {
  driver_top: null,
  iron_top: null,
  driver_face: null,
  iron_face: null
};

function preloadClubImages() {
  const sources = {
    driver_top: "images/clubs/driver_top.png",
    iron_top: "images/clubs/iron_top.png",
    driver_face: "images/clubs/driver_face.png",
    iron_face: "images/clubs/iron_face.png"
  };
  for (const [k, src] of Object.entries(sources)) {
    const img = new Image();
    img.src = src;
    img.onload = () => {
      CLUB_IMAGES[k] = img;
    };
  }
}
preloadClubImages();

function classifyClubCategory(clubName) {
  const lower = String(clubName || "").toLowerCase();
  if (lower.startsWith("dr") || lower.includes("driver")) return "driver";
  if (lower.includes("wood") || lower.endsWith("w") || lower.includes("hybrid") || lower.endsWith("h")) return "wood";
  return "iron";
}

function drawPlaceholder(ctx, w, h) {
  ctx.fillStyle = "rgba(255, 255, 255, 0.35)";
  ctx.font = "28px sans-serif";
  ctx.textAlign = "center";
  ctx.fillText("ℹ️", w * 0.5, h * 0.45);

  ctx.fillStyle = "rgba(140, 175, 205, 0.75)";
  ctx.font = "11px sans-serif";
  ctx.fillText("Data not available for this launch monitor", w * 0.5, h * 0.62);
}

function drawBadge(ctx, w, h, text, strokeColor) {
  const badgeW = Math.min(w - 20, 130);
  const badgeH = 22;
  const badgeX = (w - badgeW) * 0.5;
  const badgeY = h - 26;

  ctx.fillStyle = "rgba(10, 18, 30, 0.9)";
  ctx.strokeStyle = strokeColor;
  ctx.lineWidth = 1;

  ctx.beginPath();
  ctx.roundRect(badgeX, badgeY, badgeW, badgeH, 4);
  ctx.fill();
  ctx.stroke();

  ctx.fillStyle = strokeColor;
  ctx.font = "bold 10px sans-serif";
  ctx.textAlign = "center";
  ctx.fillText(text, w * 0.5, badgeY + 15);
}

function drawHeatBloom(ctx, x, y, radius, color) {
  ctx.beginPath();
  ctx.arc(x, y, radius, 0, Math.PI * 2);
  ctx.fillStyle = color;
  ctx.fill();
}

function drawFaceAngleCanvas(canvas, faceAngle, hasData, clubCategory, isLefty, isAverage) {
  if (!canvas) return;
  const ctx = canvas.getContext("2d");
  const w = canvas.width;
  const h = canvas.height;
  ctx.clearRect(0, 0, w, h);

  if (!hasData) {
    drawPlaceholder(ctx, w, h);
    return;
  }

  const center = { x: w * 0.5, y: h * 0.43 };

  // 1. Concentric radar circles
  ctx.strokeStyle = "rgba(46, 72, 97, 0.35)";
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.arc(center.x, center.y, 44, 0, Math.PI * 2);
  ctx.stroke();
  ctx.beginPath();
  ctx.arc(center.x, center.y, 25, 0, Math.PI * 2);
  ctx.stroke();

  // 2. Target line
  ctx.save();
  ctx.setLineDash([4, 3]);
  ctx.strokeStyle = "rgba(128, 179, 230, 0.45)";
  ctx.lineWidth = 1.5;
  ctx.beginPath();
  ctx.moveTo(center.x, h - 28);
  ctx.lineTo(center.x, 18);
  ctx.stroke();
  ctx.restore();

  // Target arrowhead
  ctx.strokeStyle = "rgba(153, 217, 255, 0.85)";
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(center.x - 5, 22);
  ctx.lineTo(center.x, 14);
  ctx.lineTo(center.x + 5, 22);
  ctx.stroke();

  ctx.fillStyle = "rgba(153, 204, 242, 0.75)";
  ctx.font = "bold 9px sans-serif";
  ctx.textAlign = "center";
  ctx.fillText("TARGET", center.x, 11);

  // 3. Square reference line
  const refExtent = Math.min(w * 0.46, 80);
  ctx.strokeStyle = "rgba(255, 153, 38, 0.95)";
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(center.x - refExtent, center.y);
  ctx.lineTo(center.x + refExtent, center.y);
  ctx.stroke();

  ctx.fillStyle = "rgba(255, 179, 64, 0.9)";
  ctx.font = "bold 8px sans-serif";
  if (!isLefty) {
    ctx.textAlign = "right";
    ctx.fillText("0° SQ", center.x + refExtent - 4, center.y - 4);
  } else {
    ctx.textAlign = "left";
    ctx.fillText("0° SQ", center.x - refExtent + 4, center.y - 4);
  }

  // 4. Rotating Clubhead
  const isWood = (clubCategory === "driver" || clubCategory === "wood");
  const img = isWood ? CLUB_IMAGES.driver_top : CLUB_IMAGES.iron_top;
  const rotDeg = Math.min(Math.max(faceAngle, -25), 25);
  const effRotDeg = isLefty ? -rotDeg : rotDeg;
  const rotRad = (effRotDeg * Math.PI) / 180;

  if (img && img.complete && img.naturalWidth > 0) {
    ctx.save();
    ctx.translate(center.x, center.y);
    ctx.rotate(rotRad);
    const sc = Math.min(Math.max(w / 1100, 0.08), 0.13) * 1.45;
    ctx.scale(isLefty ? -sc : sc, sc);
    ctx.drawImage(img, -512, -512);
    ctx.restore();
  }

  // 5. Face line & angle arc
  const absAng = Math.abs(faceAngle);
  if (absAng >= 0.2) {
    const dirX = Math.cos(rotRad);
    const dirY = Math.sin(rotRad);
    ctx.strokeStyle = "rgba(217, 115, 250, 0.95)";
    ctx.lineWidth = 2.2;
    ctx.beginPath();
    ctx.moveTo(center.x - dirX * refExtent, center.y - dirY * refExtent);
    ctx.lineTo(center.x + dirX * refExtent, center.y + dirY * refExtent);
    ctx.stroke();

    const arcR = Math.min(refExtent * 0.65, 44);
    ctx.beginPath();
    if (!isLefty) {
      const startAng = rotRad >= 0 ? 0 : rotRad;
      const endAng = rotRad >= 0 ? rotRad : 0;
      ctx.arc(center.x, center.y, arcR, startAng, endAng);
    } else {
      const startAng = rotRad <= 0 ? Math.PI : (Math.PI + rotRad);
      const endAng = rotRad <= 0 ? (Math.PI + rotRad) : Math.PI;
      ctx.arc(center.x, center.y, arcR, startAng, endAng);
    }
    ctx.stroke();
  }

  // 6. Golf Ball
  const ballPos = { x: center.x, y: center.y - 12 };
  const ballR = 7;
  ctx.beginPath();
  ctx.arc(ballPos.x, ballPos.y, ballR, 0, Math.PI * 2);
  ctx.fillStyle = "#edf2f7";
  ctx.fill();
  ctx.strokeStyle = "rgba(150, 165, 180, 0.8)";
  ctx.lineWidth = 1.2;
  ctx.stroke();

  // Highlight
  ctx.beginPath();
  ctx.arc(ballPos.x - 2, ballPos.y - 2, 1.8, 0, Math.PI * 2);
  ctx.fillStyle = "rgba(255, 255, 255, 0.9)";
  ctx.fill();

  // 7. Badge
  const col = absAng <= 1.2 ? "#59f299" : (absAng <= 3.5 ? "#ffbf4d" : "#ff6161");
  let statusStr = absAng < 0.2 ? "SQUARE (0.0°)" : (faceAngle > 0 ? `${faceAngle.toFixed(1)}° OPEN` : `${absAng.toFixed(1)}° CLOSED`);
  if (isAverage) statusStr = "Avg " + statusStr;
  drawBadge(ctx, w, h, statusStr, col);
}

function drawImpactLocationCanvas(canvas, clubName, hMm, vMm, impactPoints, hasData, clubCategory) {
  if (!canvas) return;
  const ctx = canvas.getContext("2d");
  const w = canvas.width;
  const h = canvas.height;
  ctx.clearRect(0, 0, w, h);

  if (!hasData) {
    drawPlaceholder(ctx, w, h);
    return;
  }

  const isWood = (clubCategory === "driver" || clubCategory === "wood");
  const img = isWood ? CLUB_IMAGES.driver_face : CLUB_IMAGES.iron_face;

  const texW = Math.min(w * 0.96, (h - 26) * (1200 / 896));
  const texH = texW * (896 / 1200);
  const texPos = { x: (w - texW) * 0.5, y: (h - 20 - texH) * 0.5 + 8 };

  if (img && img.complete && img.naturalWidth > 0) {
    ctx.drawImage(img, texPos.x, texPos.y, texW, texH);
  }

  let sweetSpot, mmScale;
  if (isWood) {
    sweetSpot = { x: texPos.x + texW * 0.492, y: texPos.y + texH * 0.478 };
    mmScale = (texW * 0.38) / 54;
  } else {
    sweetSpot = { x: texPos.x + texW * 0.400, y: texPos.y + texH * 0.670 };
    mmScale = (texW * 0.36) / 48;
  }

  // Crosshairs
  ctx.save();
  ctx.setLineDash([3, 2]);
  ctx.strokeStyle = "rgba(89, 191, 255, 0.45)";
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(sweetSpot.x - 16, sweetSpot.y);
  ctx.lineTo(sweetSpot.x + 16, sweetSpot.y);
  ctx.moveTo(sweetSpot.x, sweetSpot.y - 16);
  ctx.lineTo(sweetSpot.x, sweetSpot.y + 16);
  ctx.stroke();
  ctx.restore();

  ctx.beginPath();
  ctx.arc(sweetSpot.x, sweetSpot.y, 1.8, 0, Math.PI * 2);
  ctx.fillStyle = "rgba(102, 217, 255, 0.85)";
  ctx.fill();

  // Heatmap or single strike
  if (impactPoints && impactPoints.length > 0) {
    impactPoints.forEach((pt) => {
      const ptX = sweetSpot.x - Number(pt.h || 0) * mmScale;
      const ptY = sweetSpot.y - Number(pt.v || 0) * mmScale;

      drawHeatBloom(ctx, ptX, ptY, 14, "rgba(26, 115, 230, 0.14)");
      drawHeatBloom(ctx, ptX, ptY, 8.5, "rgba(77, 217, 77, 0.24)");
      drawHeatBloom(ctx, ptX, ptY, 4.5, "rgba(255, 89, 26, 0.50)");
      drawHeatBloom(ctx, ptX, ptY, 2.2, "rgba(255, 230, 77, 0.80)");
    });

    drawBadge(ctx, w, h, `${impactPoints.length} SHOTS HEATMAP`, "#ffd966");
  } else {
    const ptX = sweetSpot.x - hMm * mmScale;
    const ptY = sweetSpot.y - vMm * mmScale;

    drawHeatBloom(ctx, ptX, ptY, 16, "rgba(26, 140, 255, 0.22)");
    drawHeatBloom(ctx, ptX, ptY, 10.5, "rgba(64, 217, 89, 0.42)");
    drawHeatBloom(ctx, ptX, ptY, 6, "rgba(255, 191, 38, 0.75)");
    drawHeatBloom(ctx, ptX, ptY, 3.2, "rgba(255, 64, 26, 0.95)");
    drawHeatBloom(ctx, ptX, ptY, 1.4, "rgba(255, 255, 255, 0.95)");

    const dist = Math.hypot(ptX - sweetSpot.x, ptY - sweetSpot.y);
    const col = dist < (6 * mmScale) ? "#59f299" : (dist < (14 * mmScale) ? "#ffbf4d" : "#ff6161");
    let desc = "SWEET SPOT (CENTER)";
    if (Math.abs(hMm) >= 3 || Math.abs(vMm) >= 3) {
      const hStr = Math.abs(hMm) >= 3 ? `${Math.abs(hMm).toFixed(0)}mm ${hMm > 0 ? "TOE" : "HEEL"}` : "";
      const vStr = Math.abs(vMm) >= 3 ? `${Math.abs(vMm).toFixed(0)}mm ${vMm > 0 ? "HIGH" : "LOW"}` : "";
      desc = [hStr, vStr].filter(Boolean).join(" • ");
    }
    drawBadge(ctx, w, h, desc, col);
  }
}

function drawClubPathCanvas(canvas, clubPath, hasData, clubCategory, isLefty, isAverage) {
  if (!canvas) return;
  const ctx = canvas.getContext("2d");
  const w = canvas.width;
  const h = canvas.height;
  ctx.clearRect(0, 0, w, h);

  if (!hasData) {
    drawPlaceholder(ctx, w, h);
    return;
  }

  const center = { x: w * 0.5, y: h * 0.50 };

  // 1. Radar circles
  ctx.strokeStyle = "rgba(46, 72, 97, 0.35)";
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.arc(center.x, center.y, 44, 0, Math.PI * 2);
  ctx.stroke();
  ctx.beginPath();
  ctx.arc(center.x, center.y, 25, 0, Math.PI * 2);
  ctx.stroke();

  // 2. Target line
  ctx.save();
  ctx.setLineDash([4, 3]);
  ctx.strokeStyle = "rgba(128, 179, 230, 0.45)";
  ctx.lineWidth = 1.5;
  ctx.beginPath();
  ctx.moveTo(center.x, h - 18);
  ctx.lineTo(center.x, 18);
  ctx.stroke();
  ctx.restore();

  // Arrowhead
  ctx.strokeStyle = "rgba(153, 217, 255, 0.85)";
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(center.x - 5, 22);
  ctx.lineTo(center.x, 14);
  ctx.lineTo(center.x + 5, 22);
  ctx.stroke();

  ctx.fillStyle = "rgba(153, 204, 242, 0.75)";
  ctx.font = "bold 9px sans-serif";
  ctx.textAlign = "center";
  ctx.fillText("TARGET", center.x, 11);

  // 3. Realistic clubhead at address
  const isWood = (clubCategory === "driver" || clubCategory === "wood");
  const img = isWood ? CLUB_IMAGES.driver_top : CLUB_IMAGES.iron_top;

  if (img && img.complete && img.naturalWidth > 0) {
    ctx.save();
    ctx.translate(center.x, center.y + 10);
    const sc = Math.min(Math.max(w / 1150, 0.07), 0.12) * 1.45;
    ctx.scale(isLefty ? -sc : sc, sc);
    ctx.drawImage(img, -512, -512);
    ctx.restore();
  }

  // 4. Ball at impact
  const ballR = 7;
  ctx.beginPath();
  ctx.arc(center.x, center.y, ballR, 0, Math.PI * 2);
  ctx.fillStyle = "#edf2f7";
  ctx.fill();
  ctx.strokeStyle = "rgba(150, 165, 180, 0.8)";
  ctx.lineWidth = 1.2;
  ctx.stroke();

  // 5. Dynamic Path Vector Arrow
  const effPath = isLefty ? -clubPath : clubPath;
  const pathRad = (Math.min(Math.max(effPath, -25), 25) * Math.PI) / 180;
  const dirForward = { x: Math.sin(pathRad), y: -Math.cos(pathRad) };

  const absPath = Math.abs(clubPath);
  const pathCol = absPath <= 1.5 ? "#59f299" : (absPath <= 4.0 ? "#ffbf4d" : "#ff5959");

  const arrowLen = 50;
  const pStart = { x: center.x - dirForward.x * (arrowLen * 0.8), y: center.y - dirForward.y * (arrowLen * 0.8) };
  const pEnd = { x: center.x + dirForward.x * (arrowLen * 0.88), y: center.y + dirForward.y * (arrowLen * 0.88) };

  ctx.strokeStyle = pathCol;
  ctx.lineWidth = 3.5;
  ctx.beginPath();
  ctx.moveTo(pStart.x, pStart.y);
  ctx.lineTo(pEnd.x, pEnd.y);
  ctx.stroke();

  // Arrowhead polygon
  const normalPath = { x: -dirForward.y, y: dirForward.x };
  const headLen = 12;
  const headW = 7;
  const tip = pEnd;
  const leftWing = { x: tip.x - dirForward.x * headLen + normalPath.x * headW, y: tip.y - dirForward.y * headLen + normalPath.y * headW };
  const rightWing = { x: tip.x - dirForward.x * headLen - normalPath.x * headW, y: tip.y - dirForward.y * headLen - normalPath.y * headW };

  ctx.fillStyle = pathCol;
  ctx.beginPath();
  ctx.moveTo(tip.x, tip.y);
  ctx.lineTo(leftWing.x, leftWing.y);
  ctx.lineTo(rightWing.x, rightWing.y);
  ctx.closePath();
  ctx.fill();

  // Deviation arc
  if (absPath >= 0.4) {
    const arcR = 34;
    const baseAng = -Math.PI * 0.5;
    const targetAng = baseAng + pathRad;
    ctx.strokeStyle = pathCol;
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.arc(center.x, center.y, arcR, Math.min(baseAng, targetAng), Math.max(baseAng, targetAng));
    ctx.stroke();
  }

  // Badge
  let statusStr = absPath < 0.2 ? "STRAIGHT (0.0°)" : (clubPath > 0 ? `${clubPath.toFixed(1)}° IN-TO-OUT` : `${absPath.toFixed(1)}° OUT-TO-IN`);
  if (isAverage) statusStr = "Avg " + statusStr;
  drawBadge(ctx, w, h, statusStr, pathCol);
}

function renderClubSummary(profile) {
  const container = document.getElementById("club-summary-container");
  if (!container) return;

  const summary = profile?.club_summary || {};
  const clubKeys = Object.keys(summary);

  if (clubKeys.length === 0) {
    container.innerHTML = `
      <div class="empty-state">
        <span class="empty-icon">🏌️</span>
        <p>No club shot data recorded yet. Take swings in the simulator to see your club averages and delivery visuals here!</p>
      </div>
    `;
    return;
  }

  const seenClubs = new Set();
  const sortedClubs = [];
  STANDARD_BAG_ORDER.forEach((c) => {
    const matchedKey = clubKeys.find(k => k.toLowerCase() === c.toLowerCase());
    if (matchedKey && !seenClubs.has(matchedKey.toLowerCase())) {
      seenClubs.add(matchedKey.toLowerCase());
      sortedClubs.push(matchedKey);
    }
  });
  clubKeys.forEach((c) => {
    if (!seenClubs.has(c.toLowerCase())) {
      seenClubs.add(c.toLowerCase());
      sortedClubs.push(c);
    }
  });

  const isLefty = profile?.handedness === 1;

  let cardsHtml = "";
  sortedClubs.forEach((clubKey) => {
    const s = summary[clubKey] || {};
    const clubName = CLUB_LABELS[clubKey] || CLUB_LABELS[clubKey.toLowerCase()] || CLUB_LABELS[clubKey.toUpperCase()] || clubKey;
    const carry = s.carry_yds != null ? Number(s.carry_yds).toFixed(1) : "–";
    const total = s.total_yds != null ? Number(s.total_yds).toFixed(1) : "–";
    const bSpeed = s.ball_speed_mph != null ? Number(s.ball_speed_mph).toFixed(1) : "–";
    const spin = s.spin_rpm != null ? Math.round(Number(s.spin_rpm)) : "–";
    const offline = s.avg_offline_yds != null ? Number(s.avg_offline_yds).toFixed(1) : (s.offline_yds != null ? Number(s.offline_yds).toFixed(1) : "–");
    const count = s.count ?? 0;
    const hasShots = count > 0;
    const drawerId = `drawer-${clubKey.toLowerCase().replace(/[^a-z0-9]/g, '_')}`;

    const renderLmTiles = (data) => {
      const tile = (lbl, val, isActive, col) => `
        <div class="portal-lm-tile ${isActive ? 'active' : 'inactive'}">
          <span class="portal-lm-val" style="${col ? 'color:' + col : ''}">${escapeHtml(val)}</span>
          <span class="portal-lm-lbl">${escapeHtml(lbl)}</span>
        </div>
      `;

      let html = "";
      // 1. Club Speed
      const hasCs = Boolean(data.has_club_speed || (data.club_speed_mph > 0));
      html += tile("Club Speed", hasCs ? `${Number(data.club_speed_mph).toFixed(1)} mph` : "–", hasCs, "#ffd24d");

      // 2. Smash Factor
      const hasSf = Boolean(data.has_smash_factor || (data.smash > 0.05));
      const sfVal = Number(data.smash || 0);
      const sfCol = sfVal >= 1.45 ? "#5af296" : "#ffd24d";
      html += tile("Smash Factor", hasSf ? sfVal.toFixed(2) : "–", hasSf, sfCol);

      // 3. Attack Angle
      const hasAoa = Boolean(data.has_attack_angle);
      const aoaVal = Number(data.avg_attack_angle || 0);
      html += tile("Attack Angle", hasAoa ? `${aoaVal >= 0 ? '+' : ''}${aoaVal.toFixed(1)}°` : "–", hasAoa, "#b3d9ff");

      // 4. Dynamic Loft
      const hasDl = Boolean(data.has_dynamic_loft);
      html += tile("Dynamic Loft", hasDl ? `${Number(data.avg_dynamic_loft).toFixed(1)}°` : "–", hasDl, "#d9c2ff");

      // 5. Launch (VLA)
      const hasVla = Boolean(data.has_vla);
      html += tile("Launch (VLA)", hasVla ? `${Number(data.avg_vla_deg).toFixed(1)}°` : "–", hasVla, "#d9c2ff");

      // 6. Launch Dir (HLA)
      const hasHla = Boolean(data.has_hla);
      const hlaVal = Number(data.avg_hla_deg || 0);
      let hlaStr = "–";
      if (hasHla) {
        if (Math.abs(hlaVal) < 0.05) hlaStr = "0.0°";
        else if (hlaVal > 0) hlaStr = `${hlaVal.toFixed(1)}° R`;
        else hlaStr = `${Math.abs(hlaVal).toFixed(1)}° L`;
      }
      html += tile("Launch Dir", hlaStr, hasHla, "#b3d9ff");

      // 7. Club Path
      const hasCp = Boolean(data.has_club_path);
      const cpVal = Number(data.avg_club_path || 0);
      let cpStr = "–";
      if (hasCp) {
        if (Math.abs(cpVal) < 0.05) cpStr = "0.0° Str";
        else if (cpVal > 0) cpStr = `${cpVal.toFixed(1)}° I-O`;
        else cpStr = `${Math.abs(cpVal).toFixed(1)}° O-I`;
      }
      html += tile("Club Path", cpStr, hasCp, "#72d6ff");

      // 8. Face Angle
      const hasFa = Boolean(data.has_face_angle);
      const faVal = Number(data.avg_face_angle || 0);
      let faStr = "–";
      if (hasFa) {
        if (Math.abs(faVal) < 0.05) faStr = "0.0° Sq";
        else if (faVal > 0) faStr = `${faVal.toFixed(1)}° O`;
        else faStr = `${Math.abs(faVal).toFixed(1)}° C`;
      }
      html += tile("Face Angle", faStr, hasFa, "#72d6ff");

      // 9. Face to Path
      const hasFtp = Boolean(data.has_face_to_path);
      const ftpVal = Number(data.avg_face_to_path || 0);
      let ftpStr = "–";
      if (hasFtp) {
        if (Math.abs(ftpVal) < 0.05) ftpStr = "0.0° Sq";
        else if (ftpVal > 0) ftpStr = `${ftpVal.toFixed(1)}° O`;
        else ftpStr = `${Math.abs(ftpVal).toFixed(1)}° C`;
      }
      html += tile("Face to Path", ftpStr, hasFtp, "#72d6ff");

      // 10. Back Spin
      const hasBs = Boolean(data.has_back_spin);
      html += tile("Back Spin", hasBs ? `${Math.round(data.avg_back_spin_rpm)} rpm` : "–", hasBs, "#ffffff");

      // 11. Side Spin
      const hasSs = Boolean(data.has_side_spin);
      const ssVal = Number(data.avg_side_spin_rpm || 0);
      let ssStr = "–";
      if (hasSs) {
        if (Math.abs(ssVal) < 5) ssStr = "0 rpm";
        else if (ssVal > 0) ssStr = `${Math.round(ssVal)} R`;
        else ssStr = `${Math.round(Math.abs(ssVal))} L`;
      }
      html += tile("Side Spin", ssStr, hasSs, "#ffffff");

      // 12. Spin Axis
      const hasSa = Boolean(data.has_spin_axis);
      const saVal = Number(data.avg_spin_axis_deg || 0);
      let saCol = "#72d6ff";
      if (Math.abs(saVal) > 9) saCol = "#ff7272";
      else if (Math.abs(saVal) > 4) saCol = "#ffb366";
      html += tile("Spin Axis", hasSa ? `${saVal >= 0 ? '+' : ''}${saVal.toFixed(1)}°` : "–", hasSa, saCol);

      // 13. Apex Height
      const hasApex = Boolean(data.has_apex);
      const apexVal = Number(data.avg_apex_ft || 0);
      html += tile("Apex Height", hasApex ? `${apexVal.toFixed(1)} ft` : "–", hasApex, "#5af296");

      // 14. Rollout
      const hasRo = Boolean(data.has_rollout);
      html += tile("Rollout", hasRo ? `${Number(data.avg_rollout_yds).toFixed(1)} yds` : "–", hasRo, "#5af296");

      // 15. Hang Time
      const hasHt = Boolean(data.has_hang_time);
      html += tile("Hang Time", hasHt ? `${Number(data.avg_hang_time_s).toFixed(1)} s` : "–", hasHt, "#d9c2ff");

      // 16. Descent Angle
      const hasDa = Boolean(data.has_descent_angle);
      html += tile("Descent Ang", hasDa ? `${Number(data.avg_descent_angle_deg).toFixed(1)}°` : "–", hasDa, "#d9c2ff");

      return html;
    };

    cardsHtml += `
      <div class="portal-club-card ${hasShots ? 'has-shots' : ''}" data-club="${escapeHtml(clubKey)}">
        <div class="portal-club-row">
          <!-- Club code & name -->
          <div class="portal-club-col-name">
            <span class="portal-club-code">${escapeHtml(clubKey)}</span>
            <span class="portal-club-fullname">${escapeHtml(clubName)} (${escapeHtml(clubKey)})</span>
          </div>

          <!-- Shot Count -->
          <div class="portal-club-col-count">
            <span class="portal-count-val">${count} shots</span>
            <span class="portal-count-sub">Recorded</span>
          </div>

          <!-- Metrics -->
          <div class="portal-club-col-stats">
            <div class="portal-metric-item">
              <span class="portal-metric-val val-gold">${total} yds</span>
              <span class="portal-metric-lbl">Avg Total</span>
            </div>
            <div class="portal-metric-item">
              <span class="portal-metric-val">${carry} yds</span>
              <span class="portal-metric-lbl">Avg Carry</span>
            </div>
            <div class="portal-metric-item">
              <span class="portal-metric-val">${bSpeed} mph</span>
              <span class="portal-metric-lbl">Avg Speed</span>
            </div>
            <div class="portal-metric-item">
              <span class="portal-metric-val">${spin} rpm</span>
              <span class="portal-metric-lbl">Avg Spin</span>
            </div>
            <div class="portal-metric-item">
              <span class="portal-metric-val">${offline} yds</span>
              <span class="portal-metric-lbl">Avg Offline</span>
            </div>
          </div>

          <!-- Buttons -->
          <div class="portal-club-col-actions">
            <button class="btn-toggle-visuals" data-drawer="${drawerId}" ${!hasShots ? 'disabled' : ''}>
              ▼ Expand
            </button>
            <button class="btn-clear-club-row" data-club="${escapeHtml(clubKey)}" data-club-name="${escapeHtml(clubName)}" data-count="${count}" ${!hasShots ? 'disabled' : ''} title="Clear shot data for ${escapeHtml(clubName)}">
              🗑
            </button>
          </div>
        </div>

        <!-- Drawer -->
        <div class="portal-club-drawer" id="${drawerId}" style="display: none;">
          <div class="portal-drawer-inner">
            <!-- Launch Monitor Club Averages Panel -->
            <div class="portal-lm-stats-panel">
              <div class="portal-lm-header">
                📡 LAUNCH MONITOR CLUB AVERAGES
              </div>
              <div class="portal-lm-grid">
                ${renderLmTiles(s)}
              </div>
            </div>

            <!-- Club Delivery Visuals Header & Grid -->
            <div class="portal-drawer-header">
              🏌 CLUB DELIVERY AVERAGES & STRIKE TENDENCIES
            </div>
            <div class="portal-visuals-grid">
              <!-- Visual Card 1: Face Angle -->
              <div class="portal-visual-panel">
                <div class="portal-visual-header">CLUB FACE ANGLE</div>
                <div class="portal-canvas-container">
                  <canvas id="canvas-face-${drawerId}" width="280" height="200"></canvas>
                </div>
              </div>

              <!-- Visual Card 2: Impact Location -->
              <div class="portal-visual-panel">
                <div class="portal-visual-header flex-header">
                  <span class="club-subtag">${escapeHtml(clubName.toUpperCase())}</span>
                  <span class="visual-title">IMPACT: ${escapeHtml(clubName.toUpperCase())}</span>
                </div>
                <div class="portal-canvas-container">
                  <canvas id="canvas-impact-${drawerId}" width="280" height="200"></canvas>
                </div>
              </div>

              <!-- Visual Card 3: Club Path -->
              <div class="portal-visual-panel">
                <div class="portal-visual-header">CLUB PATH</div>
                <div class="portal-canvas-container">
                  <canvas id="canvas-path-${drawerId}" width="280" height="200"></canvas>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    `;
  });

  container.innerHTML = `<div class="portal-clubs-list">${cardsHtml}</div>`;

  // Hook up drawer toggles
  container.querySelectorAll(".btn-toggle-visuals").forEach((btn) => {
    btn.addEventListener("click", () => {
      const drawerId = btn.getAttribute("data-drawer");
      const drawer = document.getElementById(drawerId);
      if (!drawer) return;

      const isOpening = drawer.style.display === "none";
      drawer.style.display = isOpening ? "block" : "none";
      btn.textContent = isOpening ? "▲ Collapse" : "▼ Expand";

      if (isOpening) {
        const card = btn.closest(".portal-club-card");
        const clubKey = card.getAttribute("data-club");
        const s = summary[clubKey] || {};
        const clubCategory = classifyClubCategory(clubKey);
        const clubName = CLUB_LABELS[clubKey] || clubKey;

        const faceCanvas = document.getElementById(`canvas-face-${drawerId}`);
        const impactCanvas = document.getElementById(`canvas-impact-${drawerId}`);
        const pathCanvas = document.getElementById(`canvas-path-${drawerId}`);

        const renderVisuals = () => {
          drawFaceAngleCanvas(
            faceCanvas,
            Number(s.avg_face_angle ?? 0),
            Boolean(s.has_face_angle ?? (s.face_angle_count > 0)),
            clubCategory,
            isLefty,
            true
          );

          drawImpactLocationCanvas(
            impactCanvas,
            clubName,
            0,
            0,
            s.impact_points || [],
            Boolean(s.has_impact_data ?? (s.impact_points && s.impact_points.length > 0)),
            clubCategory
          );

          drawClubPathCanvas(
            pathCanvas,
            Number(s.avg_club_path ?? 0),
            Boolean(s.has_club_path ?? (s.club_path_count > 0)),
            clubCategory,
            isLefty,
            true
          );
        };

        renderVisuals();
        // If images load slightly later, trigger redraw once cached
        setTimeout(renderVisuals, 150);
      }
    });
  });

  // Hook up clear buttons
  container.querySelectorAll(".btn-clear-club-row").forEach((btn) => {
    btn.addEventListener("click", () => {
      const code = btn.getAttribute("data-club");
      const name = btn.getAttribute("data-club-name");
      const cnt = btn.getAttribute("data-count");
      showConfirmModal({
        title: "Clear Club Shot Data",
        message: `Are you sure you want to clear shot data for ${name} (${code})?\n\nThis will reset all ${cnt} recorded shots for this club and cannot be undone.`,
        confirmText: "Clear Club Data",
        onConfirm: () => clearClubShotData(code)
      });
    });
  });
}

// ─── PLAYER PROFILE & STATS MANAGEMENT ───
async function clearClubShotData(clubKey) {
  if (!currentUser) return;
  try {
    const nowSec = Math.floor(Date.now() / 1000);

    // 1. Update sync/stats
    const statsRef = doc(db, "profiles", currentUser.uid, "sync", "stats");
    const statsSnap = await getDoc(statsRef);
    const statsData = statsSnap.exists() ? statsSnap.data() : { schema_version: 1, clubs: {}, tombstones: {}, records: {} };

    const clubs = { ...(statsData.clubs || {}) };
    for (const k of Object.keys(clubs)) {
      if (k.toLowerCase() === clubKey.toLowerCase()) {
        delete clubs[k];
      }
    }

    const tombstones = { ...(statsData.tombstones || {}) };
    const clearedClubs = { ...(tombstones.cleared_clubs || {}) };
    clearedClubs[clubKey] = nowSec;
    const stdKey = STANDARD_BAG_ORDER.find((sc) => sc.toLowerCase() === clubKey.toLowerCase());
    if (stdKey) {
      clearedClubs[stdKey] = nowSec;
    }
    tombstones.cleared_clubs = clearedClubs;

    const records = { ...(statsData.records || {}) };
    if (clubKey.toLowerCase() === "dr" || clubKey.toLowerCase() === "driver") {
      delete records.longest_drive;
      delete records.longest_drive_yds;
    } else if (clubKey.toLowerCase() === "pt" || clubKey.toLowerCase() === "putter") {
      delete records.longest_putt_ft;
    }

    const statsRev = (statsData.rev || 0) + 1;
    await setDoc(statsRef, {
      ...statsData,
      schema_version: 1,
      clubs,
      records,
      tombstones,
      rev: statsRev,
      updated_at: nowSec
    });

    // 2. Update profiles/{uid}
    const profRef = doc(db, "profiles", currentUser.uid);
    const profSnap = await getDoc(profRef);
    if (profSnap.exists()) {
      const profData = profSnap.data();
      const clubSummary = { ...(profData.club_summary || {}) };
      for (const k of Object.keys(clubSummary)) {
        if (k.toLowerCase() === clubKey.toLowerCase()) {
          delete clubSummary[k];
        }
      }
      const profRev = (profData.rev || 0) + 1;
      await updateDoc(profRef, {
        club_summary: clubSummary,
        rev: profRev,
        updated_at: nowSec,
        updated_by_uid: currentUser.uid
      });
      currentProfile = { ...profData, club_summary: clubSummary, rev: profRev };
    }

    if (currentStats) {
      currentStats.clubs = clubs;
    }
    renderClubSummary(currentProfile);
    if (loadedTabs.analytics) {
      populateAnalyticsClubSelector();
      renderAnalytics();
    }
    showToast(`✓ Shot data for ${CLUB_LABELS[clubKey] || clubKey} cleared.`);
  } catch (err) {
    console.error("Failed to clear club data:", err);
    const pauseMsg = await handleWriteError(err);
    showToast(pauseMsg || ("Failed to clear club data: " + (err.message || err)));
  }
}

async function clearAllBallHistory() {
  if (!currentUser) return;
  try {
    const nowSec = Math.floor(Date.now() / 1000);

    // 1. Update sync/stats
    const statsRef = doc(db, "profiles", currentUser.uid, "sync", "stats");
    const statsSnap = await getDoc(statsRef);
    const statsData = statsSnap.exists() ? statsSnap.data() : { schema_version: 1 };

    const tombstones = { ...(statsData.tombstones || {}) };
    tombstones.cleared_all_at = nowSec;

    const statsRev = (statsData.rev || 0) + 1;
    await setDoc(statsRef, {
      ...statsData,
      schema_version: 1,
      clubs: {},
      records: {},
      tombstones,
      rev: statsRev,
      updated_at: nowSec
    });

    // 2. Update profiles/{uid}
    const profRef = doc(db, "profiles", currentUser.uid);
    const profSnap = await getDoc(profRef);
    if (profSnap.exists()) {
      const profData = profSnap.data();
      const lifetime = { ...(profData.lifetime || {}) };
      lifetime.longest_drive_yds = 0;
      const profRev = (profData.rev || 0) + 1;
      await updateDoc(profRef, {
        club_summary: {},
        lifetime,
        rev: profRev,
        updated_at: nowSec,
        updated_by_uid: currentUser.uid
      });
      currentProfile = { ...profData, club_summary: {}, lifetime, rev: profRev };
    }

    if (currentStats) {
      currentStats.clubs = {};
    }
    renderOverviewCards(currentProfile);
    renderClubSummary(currentProfile);
    if (loadedTabs.analytics) {
      populateAnalyticsClubSelector();
      renderAnalytics();
    }
    showToast("✓ All ball history across all clubs has been cleared.");
  } catch (err) {
    console.error("Failed to clear ball history:", err);
    const pauseMsg = await handleWriteError(err);
    showToast(pauseMsg || ("Failed to clear ball history: " + (err.message || err)));
  }
}

async function clearSwingHistory() {
  if (!currentUser) return;
  try {
    const nowSec = Math.floor(Date.now() / 1000);

    const statsRef = doc(db, "profiles", currentUser.uid, "sync", "stats");
    const statsSnap = await getDoc(statsRef);
    const statsData = statsSnap.exists() ? statsSnap.data() : { schema_version: 1 };

    const tombstones = { ...(statsData.tombstones || {}) };
    tombstones.cleared_swing_issues_at = nowSec;

    const statsRev = (statsData.rev || 0) + 1;
    await setDoc(statsRef, {
      ...statsData,
      schema_version: 1,
      swing_issues: {},
      tombstones,
      rev: statsRev,
      updated_at: nowSec
    });

    if (currentStats) {
      currentStats.swing_issues = {};
      if (!currentStats.tombstones) currentStats.tombstones = {};
      currentStats.tombstones.cleared_swing_issues_at = nowSec;
      currentStats.rev = statsRev;
      currentStats.updated_at = nowSec;
    }
    loadedTabs.swing = false;

    const swingContainer = document.getElementById("swing-analysis-container") || document.getElementById("swing-issues-container");
    if (swingContainer) {
      swingContainer.innerHTML = `
        <div class="empty-state">
          <span class="empty-icon">🎯</span>
          <p>No swing recommendations recorded yet.<br>Turn on Shot Analysis and/or Golfer Camera during Driving Range, Course Play, or Practice to track swing fixes!</p>
        </div>
      `;
    }
    showToast("✓ Swing flaw and tendency history has been cleared.");
  } catch (err) {
    console.error("Failed to clear swing history:", err);
    const pauseMsg = await handleWriteError(err);
    showToast(pauseMsg || ("Failed to clear swing history: " + (err.message || err)));
  }
}

async function saveProfilePreferences(updates) {
  if (!currentUser) return;
  try {
    const nowSec = Math.floor(Date.now() / 1000);
    const profRef = doc(db, "profiles", currentUser.uid);
    const profSnap = await getDoc(profRef);
    const profData = profSnap.exists() ? profSnap.data() : {};
    const profRev = (profData.rev || 0) + 1;

    const finalName = (updates.displayName || profData.display_name || currentUser.displayName || "Golfer").trim();
    const newProf = {
      ...profData,
      schema_version: 1,
      display_name: finalName,
      preferred_tee: updates.preferredTee || profData.preferred_tee || "Blue",
      skill_level: updates.skillLevel || profData.skill_level || "mid_handicap",
      handedness: updates.handedness != null ? updates.handedness : (profData.handedness ?? 0),
      ball_graphic: updates.ballGraphic || profData.ball_graphic || "single_line",
      rev: profRev,
      updated_at: nowSec,
      updated_by_uid: currentUser.uid
    };

    await setDoc(profRef, newProf, { merge: true });

    // Update Firebase Auth user displayName if changed
    if (finalName && finalName !== currentUser.displayName) {
      try {
        await updateProfile(currentUser, { displayName: finalName });
      } catch (e) {
        console.warn("Could not update auth displayName:", e);
      }
    }

    // Update users/{uid}
    try {
      await updateDoc(doc(db, "users", currentUser.uid), {
        display_name: finalName,
        updated_at: nowSec
      });
    } catch {}

    // Update public_profiles/{uid} if present
    try {
      const pubSnap = await getDoc(doc(db, "public_profiles", currentUser.uid));
      if (pubSnap.exists()) {
        await updateDoc(doc(db, "public_profiles", currentUser.uid), {
          display_name: finalName,
          updated_at: nowSec
        });
      }
    } catch {}

    currentProfile = newProf;

    updateUserHeader(currentUser, currentProfile);
    renderProfilePreferencesSummary(currentProfile);
    await ensurePublicProfileSynced(currentUser, currentProfile);
    closeEditProfileModal();
    showToast("✓ Profile and preferences updated successfully.");
  } catch (err) {
    console.error("Failed to update profile:", err);
    const pauseMsg = await handleWriteError(err);
    showToast(pauseMsg || ("Failed to update profile: " + (err.message || err)));
  }
}

// ─── MODAL CONTROLLERS & TOAST ───
function showConfirmModal({ title, message, confirmText = "Confirm", onConfirm }) {
  const overlay = document.getElementById("confirm-modal-overlay");
  const titleEl = document.getElementById("confirm-modal-title");
  const descEl = document.getElementById("confirm-modal-message");
  const proceedBtn = document.getElementById("btn-confirm-proceed");

  if (!overlay) return;
  if (titleEl) titleEl.textContent = title;
  if (descEl) descEl.textContent = message;
  if (proceedBtn) proceedBtn.textContent = confirmText;
  activeConfirmCallback = onConfirm;

  overlay.classList.add("open");
  document.body.style.overflow = "hidden";
}

function closeConfirmModal() {
  const overlay = document.getElementById("confirm-modal-overlay");
  if (overlay) overlay.classList.remove("open");
  document.body.style.overflow = "";
  activeConfirmCallback = null;
}

function openEditProfileModal() {
  const overlay = document.getElementById("edit-profile-modal-overlay");
  if (!overlay) return;

  const nameInput = document.getElementById("input-edit-display-name");
  const teeSelect = document.getElementById("select-edit-preferred-tee");
  const handSelect = document.getElementById("select-edit-handedness");
  const skillSelect = document.getElementById("select-edit-skill-level");
  const ballSelect = document.getElementById("select-edit-ball-graphic");

  const p = currentProfile || {};
  if (nameInput) nameInput.value = p.display_name || currentUser?.displayName || currentUser?.email?.split("@")[0] || "";
  if (teeSelect) teeSelect.value = p.preferred_tee || "Blue";
  if (handSelect) handSelect.value = String(p.handedness ?? 0);
  if (skillSelect) skillSelect.value = p.skill_level || "mid_handicap";
  if (ballSelect) ballSelect.value = p.ball_graphic || "single_line";

  overlay.classList.add("open");
  document.body.style.overflow = "hidden";
}

function closeEditProfileModal() {
  const overlay = document.getElementById("edit-profile-modal-overlay");
  if (overlay) overlay.classList.remove("open");
  document.body.style.overflow = "";
}

function showToast(message) {
  const toast = document.getElementById("portal-toast");
  if (!toast) return;
  toast.textContent = message;
  toast.classList.add("active");
  if (toastTimeout) clearTimeout(toastTimeout);
  toastTimeout = setTimeout(() => {
    toast.classList.remove("active");
  }, 3500);
}

function bindPlayerManagement() {
  // Confirm modal buttons
  document.getElementById("btn-confirm-close")?.addEventListener("click", closeConfirmModal);
  document.getElementById("btn-confirm-cancel")?.addEventListener("click", closeConfirmModal);
  document.getElementById("btn-confirm-proceed")?.addEventListener("click", async () => {
    const btn = document.getElementById("btn-confirm-proceed");
    if (activeConfirmCallback) {
      if (btn) { btn.disabled = true; btn.textContent = "Processing…"; }
      try {
        await activeConfirmCallback();
      } finally {
        if (btn) { btn.disabled = false; }
        closeConfirmModal();
      }
    }
  });

  // Edit profile triggers
  document.getElementById("btn-edit-profile")?.addEventListener("click", openEditProfileModal);
  document.getElementById("portal-top-edit-profile-btn")?.addEventListener("click", openEditProfileModal);
  document.getElementById("btn-edit-profile-close")?.addEventListener("click", closeEditProfileModal);
  document.getElementById("btn-edit-profile-cancel")?.addEventListener("click", closeEditProfileModal);
  document.getElementById("btn-edit-profile-save")?.addEventListener("click", async () => {
    const nameInput = document.getElementById("input-edit-display-name");
    const teeSelect = document.getElementById("select-edit-preferred-tee");
    const handSelect = document.getElementById("select-edit-handedness");
    const skillSelect = document.getElementById("select-edit-skill-level");
    const ballSelect = document.getElementById("select-edit-ball-graphic");

    const updates = {
      displayName: nameInput?.value?.trim() || "",
      preferredTee: teeSelect?.value || "Blue",
      handedness: handSelect ? parseInt(handSelect.value, 10) : 0,
      skillLevel: skillSelect?.value || "mid_handicap",
      ballGraphic: ballSelect?.value || "single_line"
    };

    const saveBtn = document.getElementById("btn-edit-profile-save");
    if (saveBtn) { saveBtn.disabled = true; saveBtn.textContent = "Saving…"; }
    try {
      await saveProfilePreferences(updates);
    } finally {
      if (saveBtn) { saveBtn.disabled = false; saveBtn.textContent = "Save Profile"; }
    }
  });

  // Clear all ball history
  document.getElementById("btn-clear-all-history")?.addEventListener("click", () => {
    showConfirmModal({
      title: "Clear All Ball History",
      message: "Are you sure you want to clear your entire ball history across all clubs? This resets all your club average carries, speed, spin, and personal best records, and cannot be undone.",
      confirmText: "Clear All History",
      onConfirm: clearAllBallHistory
    });
  });

  // Clear swing flaw history
  document.getElementById("btn-clear-swing-history")?.addEventListener("click", () => {
    showConfirmModal({
      title: "Clear Swing Tendencies",
      message: "Are you sure you want to clear your swing tendency history? This resets all recorded swing flaws and improvement recommendations.",
      confirmText: "Clear Swing History",
      onConfirm: clearSwingHistory
    });
  });

  // View Analytics shortcut from Club Summary
  document.getElementById("btn-view-analytics-shortcut")?.addEventListener("click", () => {
    switchPortalTab("analytics");
  });

  // Close modals on overlay backdrop click
  ["confirm-modal-overlay", "edit-profile-modal-overlay"].forEach((id) => {
    const el = document.getElementById(id);
    if (el) {
      el.addEventListener("click", (e) => {
        if (e.target === el) {
          el.classList.remove("open");
          document.body.style.overflow = "";
        }
      });
    }
  });

  // Close modals on Escape key
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") {
      closeConfirmModal();
      closeEditProfileModal();
    }
  });
}

async function renderBestCourses(profile) {
  const container = document.getElementById("best-courses-container");
  if (!container) return;

  let bestCourses = {
    ...(currentStats?.best_courses || {}),
    ...(profile?.lifetime?.best_courses || {}),
    ...(profile?.best_courses || {})
  };
  let courseNames = Object.keys(bestCourses);

  // If no courses found in profile or stats, query recent completed matches as a seamless fallback
  if (courseNames.length === 0 && currentUser) {
    try {
      const snap = await getDocs(
        query(
          collection(db, "profiles", currentUser.uid, "matches"),
          limit(50)
        )
      );
      if (!snap.empty) {
        const derived = {};
        snap.forEach((docSnap) => {
          const m = docSnap.data();
          const cName = m.course_name;
          if (!cName || m.is_finished === false) return;
          const strokes = m.strokes != null ? Number(m.strokes) : null;
          const par = m.par != null ? Number(m.par) : null;
          let diff = m.to_par != null ? Number(m.to_par) : (strokes != null && par != null ? strokes - par : null);
          if (diff == null || isNaN(diff)) return;
          const holes = m.holes_count ? Number(m.holes_count) : (Array.isArray(m.holes) && m.holes.length > 0 ? m.holes.length : 18);

          if (!derived[cName] || diff < derived[cName].diff || (diff === derived[cName].diff && holes > (derived[cName].holes || 0))) {
            const diffSign = diff > 0 ? `+${diff}` : (diff === 0 ? "E" : `${diff}`);
            derived[cName] = {
              diff: diff,
              str: `${diffSign} (${holes} holes)`,
              strokes: strokes,
              holes: holes
            };
          }
        });
        if (Object.keys(derived).length > 0) {
          bestCourses = derived;
          courseNames = Object.keys(bestCourses);
          if (currentProfile) {
            currentProfile.best_courses = bestCourses;
          }
        }
      }
    } catch (e) {
      console.warn("[Portal] Error fetching matches for best courses fallback:", e);
    }
  }

  if (courseNames.length === 0) {
    container.innerHTML = `
      <div class="empty-state">
        <span class="empty-icon">⛳</span>
        <p>No course rounds recorded yet. Play a round in Heckle Golf to record your best courses!</p>
      </div>
    `;
    return;
  }

  // Sort courses alphabetically for clean display
  courseNames.sort((a, b) => a.localeCompare(b));

  let cardsHtml = "";
  courseNames.forEach((name) => {
    const c = bestCourses[name];
    if (!c || typeof c !== "object") return;
    const diffVal = c.diff != null ? Number(c.diff) : null;
    const diff = diffVal != null ? (diffVal === 0 ? "E" : diffVal > 0 ? `+${diffVal}` : `${diffVal}`) : "";
    const strokes = c.strokes != null ? `(${c.strokes} strokes)` : "";
    const holeMatch = typeof c.str === "string" ? c.str.match(/(\d+)\s*holes?/i) : null;
    const holes = c.holes ? `${c.holes} Holes` : (holeMatch ? `${holeMatch[1]} Holes` : "18 Holes");

    cardsHtml += `
      <div class="best-course-item">
        <div>
          <h4>${escapeHtml(name)}</h4>
          <span class="course-meta">${holes}</span>
        </div>
        <div class="best-course-score">
          ${diff} <span style="font-size: 0.85rem; font-weight: normal; color: var(--muted);">${strokes}</span>
        </div>
      </div>
    `;
  });

  container.innerHTML = `<div class="best-courses-grid">${cardsHtml}</div>`;
}

// ─── TAB: IMPROVEMENT ANALYTICS & TRENDS (LAZY-LOADED) ───
let analyticsControlsBound = false;

async function loadAnalyticsAndTrends(user) {
  const container = document.getElementById("analytics-content-container");
  if (!container) return;

  if (!currentStats) {
    container.innerHTML = `
      <div class="loading-state">
        <div class="spinner"></div>
        <p>Loading swing delivery &amp; offline analytics…</p>
      </div>
    `;
    try {
      const statsSnap = await getDoc(doc(db, "profiles", user.uid, "sync", "stats"));
      if (statsSnap.exists()) {
        currentStats = statsSnap.data();
      } else {
        currentStats = { schema_version: 1, clubs: {} };
      }
    } catch (e) {
      console.warn("[Portal] Error loading stats for analytics:", e);
      currentStats = { schema_version: 1, clubs: {} };
    }
  }

  loadedTabs.analytics = true;
  populateAnalyticsClubSelector();
  bindAnalyticsControls();
  renderAnalytics();
}

function populateAnalyticsClubSelector() {
  const clubSelect = document.getElementById("analytics-club-select");
  if (!clubSelect) return;

  const clubs = currentStats?.clubs || {};
  const availableClubKeys = Object.keys(clubs).filter(k => Array.isArray(clubs[k]) && clubs[k].length > 0);

  const prevVal = clubSelect.value || currentAnalyticsClub || "all";

  let totalAllShots = 0;
  availableClubKeys.forEach(k => { totalAllShots += clubs[k].length; });

  let optionsHtml = `<option value="all">All Recorded Clubs (${totalAllShots} shots)</option>`;

  const sortedKeys = [];
  STANDARD_BAG_ORDER.forEach(k => {
    const match = availableClubKeys.find(c => c.toLowerCase() === k.toLowerCase());
    if (match && !sortedKeys.includes(match)) sortedKeys.push(match);
  });
  availableClubKeys.forEach(k => {
    if (!sortedKeys.includes(k)) sortedKeys.push(k);
  });

  sortedKeys.forEach(k => {
    const count = clubs[k].length;
    const label = CLUB_LABELS[k] || CLUB_LABELS[k.toLowerCase()] || k;
    optionsHtml += `<option value="${escapeHtml(k)}">${escapeHtml(label)} (${count} shots)</option>`;
  });

  clubSelect.innerHTML = optionsHtml;
  if (sortedKeys.some(k => k.toLowerCase() === prevVal.toLowerCase()) || prevVal === "all") {
    clubSelect.value = prevVal;
    currentAnalyticsClub = prevVal;
  } else {
    clubSelect.value = "all";
    currentAnalyticsClub = "all";
  }
}

function bindAnalyticsControls() {
  if (analyticsControlsBound) return;
  analyticsControlsBound = true;

  const clubSelect = document.getElementById("analytics-club-select");
  const windowSelect = document.getElementById("analytics-window-select");
  const refreshBtn = document.getElementById("btn-refresh-analytics");

  clubSelect?.addEventListener("change", () => {
    currentAnalyticsClub = clubSelect.value;
    renderAnalytics();
  });

  windowSelect?.addEventListener("change", () => {
    currentAnalyticsWindow = windowSelect.value;
    renderAnalytics();
  });

  refreshBtn?.addEventListener("click", async () => {
    if (currentUser) {
      refreshBtn.disabled = true;
      refreshBtn.textContent = "Refreshing…";
      try {
        const statsSnap = await getDoc(doc(db, "profiles", currentUser.uid, "sync", "stats"));
        if (statsSnap.exists()) {
          currentStats = statsSnap.data();
        }
        populateAnalyticsClubSelector();
        renderAnalytics();
        showToast("✓ Improvement analytics refreshed");
      } catch (err) {
        console.warn("Could not refresh analytics:", err);
      } finally {
        refreshBtn.disabled = false;
        refreshBtn.textContent = "🔄 Refresh";
      }
    }
  });
}

function renderAnalytics() {
  const container = document.getElementById("analytics-content-container");
  if (!container) return;

  const clubs = currentStats?.clubs || {};
  let shots = [];

  if (currentAnalyticsClub === "all") {
    shots = aggregateAllClubsShots(clubs);
  } else {
    shots = getClubShots(clubs, currentAnalyticsClub);
  }

  if (shots.length === 0) {
    container.innerHTML = `
      <div class="empty-state" style="padding: 3rem 1.5rem;">
        <span class="empty-icon">📈</span>
        <h4 style="font-size: 1.15rem; color: var(--text); margin-bottom: 0.5rem;">No Shot Telemetry Recorded Yet</h4>
        <p style="max-width: 550px; margin: 0 auto; line-height: 1.5; color: var(--muted);">
          Take swings on the driving range or during course play in Heckle Golf with your launch monitor connected. As your shots record, this section will track whether your offline dispersion is nearing zero, if your club face and path are squaring up to straight, and calculate data-driven trends to measure your improvement!
        </p>
      </div>
    `;
    return;
  }

  const analytics = computeImprovementAnalytics(shots, currentAnalyticsWindow);
  const { recent, baseline, offline, face, path, faceToPath, smash, impact, distance } = analytics;

  // Format Helper Labels
  const formatFace = (deg) => {
    if (deg == null) return "–";
    if (Math.abs(deg) < 0.1) return "0.0° Square";
    return deg > 0 ? `${deg.toFixed(1)}° Open` : `${Math.abs(deg).toFixed(1)}° Closed`;
  };

  const formatPath = (deg) => {
    if (deg == null) return "–";
    if (Math.abs(deg) < 0.1) return "0.0° Straight";
    return deg > 0 ? `${deg.toFixed(1)}° In-Out` : `${Math.abs(deg).toFixed(1)}° Out-In`;
  };

  const formatOffline = (val) => {
    if (val == null) return "–";
    return `±${val.toFixed(1)} yds`;
  };

  const formatDeltaClass = (status) => {
    if (status === "improving") return "delta-improving";
    if (status === "expanding" || status === "declining") return "delta-expanding";
    return "delta-neutral";
  };

  // 1. Executive KPI Summary Cards
  const kpiGridHtml = `
    <div class="analytics-kpi-grid">
      <!-- 1. Offline Dispersion Card -->
      <div class="analytics-kpi-card">
        <div class="analytics-kpi-header">
          <span class="analytics-kpi-title">🎯 Offline Dispersion</span>
          <span class="analytics-trend-badge trend-${offline.status}">${escapeHtml(offline.badge)}</span>
        </div>
        <div class="analytics-kpi-val highlight">${formatOffline(recent.avgAbsOffline)}</div>
        <div class="analytics-kpi-sub">
          Target Corridor: <strong>${recent.pctInFairway}%</strong> (${recent.pctLeft}% Left / ${recent.pctRight}% Right)
        </div>
        <div style="font-size:0.78rem; color:var(--muted); border-top: 1px solid rgba(255,255,255,0.06); padding-top: 0.5rem;">
          ${escapeHtml(offline.text)}
        </div>
      </div>

      <!-- 2. Club Face Squaring Card -->
      <div class="analytics-kpi-card">
        <div class="analytics-kpi-header">
          <span class="analytics-kpi-title">🏌️ Club Face Alignment</span>
          <span class="analytics-trend-badge trend-${face.status}">${escapeHtml(face.badge)}</span>
        </div>
        <div class="analytics-kpi-val">${recent.avgAbsFace != null ? `±${recent.avgAbsFace.toFixed(1)}°` : "–"}</div>
        <div class="analytics-kpi-sub">
          Tendency: <strong>${formatFace(recent.avgSignedFace)}</strong>
        </div>
        <div style="font-size:0.78rem; color:var(--muted); border-top: 1px solid rgba(255,255,255,0.06); padding-top: 0.5rem;">
          ${escapeHtml(face.text)}
        </div>
      </div>

      <!-- 3. Club Swing Path Card -->
      <div class="analytics-kpi-card">
        <div class="analytics-kpi-header">
          <span class="analytics-kpi-title">📐 Club Swing Path</span>
          <span class="analytics-trend-badge trend-${path.status}">${escapeHtml(path.badge)}</span>
        </div>
        <div class="analytics-kpi-val">${recent.avgAbsPath != null ? `±${recent.avgAbsPath.toFixed(1)}°` : "–"}</div>
        <div class="analytics-kpi-sub">
          Delivery: <strong>${formatPath(recent.avgSignedPath)}</strong>
        </div>
        <div style="font-size:0.78rem; color:var(--muted); border-top: 1px solid rgba(255,255,255,0.06); padding-top: 0.5rem;">
          ${escapeHtml(path.text)}
        </div>
      </div>

      <!-- 4. Strike & Energy Efficiency Card -->
      <div class="analytics-kpi-card">
        <div class="analytics-kpi-header">
          <span class="analytics-kpi-title">⚡ Strike &amp; Efficiency</span>
          <span class="analytics-trend-badge trend-${smash.status}">${smash.status === 'improving' ? 'Higher Compression' : (smash.status === 'declining' ? 'Reduced Compression' : 'Solid Strike')}</span>
        </div>
        <div class="analytics-kpi-val highlight">${recent.avgSmash != null ? recent.avgSmash.toFixed(2) : (recent.avgCarry > 0 ? `${recent.avgCarry.toFixed(0)} yds` : "–")}</div>
        <div class="analytics-kpi-sub">
          ${recent.avgImpactOffsetMm != null ? `Sweet spot offset: <strong>${recent.avgImpactOffsetMm.toFixed(1)} mm</strong>` : `Avg Carry: <strong>${recent.avgCarry.toFixed(1)} yds</strong> (±${recent.stdDevCarry.toFixed(1)})`}
        </div>
        <div style="font-size:0.78rem; color:var(--muted); border-top: 1px solid rgba(255,255,255,0.06); padding-top: 0.5rem;">
          ${escapeHtml(smash.text || `Face-to-Path: ${recent.avgAbsFtp != null ? recent.avgAbsFtp.toFixed(1) + '°' : '–'}`)}
        </div>
      </div>
    </div>
  `;

  // 2. Interactive SVG Charts Grid
  const offlineSvg = generateOfflineTrendChartSvg(shots);
  const deliverySvg = generateDeliveryTrendChartSvg(shots);
  const strikeSvg = generateStrikeTrendChartSvg(shots);

  const chartsHtml = `
    <div class="analytics-charts-grid">
      <!-- Chart 1: Offline Dispersion -->
      <div class="analytics-chart-box">
        <div class="analytics-chart-header">
          <span class="analytics-chart-title">🎯 Directional Offline Dispersion Trend</span>
          <div class="analytics-chart-legend">
            <span class="legend-item"><span class="legend-dot" style="background:#22c55e;"></span> In Corridor (±10 yds)</span>
            <span class="legend-item"><span class="legend-dot" style="background:#ef4444;"></span> Off-Target</span>
            <span class="legend-item"><span class="legend-line" style="background:#38bdf8;"></span> Rolling Trend</span>
          </div>
        </div>
        ${offlineSvg}
      </div>

      <!-- Chart 2: Delivery Alignment (Face & Path) -->
      <div class="analytics-chart-box">
        <div class="analytics-chart-header">
          <span class="analytics-chart-title">📐 Club Face &amp; Path Convergence to Straight (0.0°)</span>
          <div class="analytics-chart-legend">
            <span class="legend-item"><span class="legend-line" style="background:#f59e0b;"></span> Face Angle</span>
            <span class="legend-item"><span class="legend-line" style="background:#38bdf8;"></span> Club Path</span>
            <span class="legend-item"><span class="legend-line" style="background:#22c55e; border-top: 2px dashed #22c55e;"></span> Straight (0°)</span>
          </div>
        </div>
        ${deliverySvg}
      </div>

      <!-- Chart 3: Strike & Smash Factor -->
      <div class="analytics-chart-box" style="grid-column: 1 / -1;">
        <div class="analytics-chart-header">
          <span class="analytics-chart-title">⚡ Energy Transfer &amp; Smash Factor Progression</span>
          <div class="analytics-chart-legend">
            <span class="legend-item"><span class="legend-dot" style="background:#22c55e;"></span> Shot Smash Factor</span>
            <span class="legend-item"><span class="legend-line" style="background:#22c55e;"></span> Moving Average</span>
            <span class="legend-item"><span class="legend-dot" style="background:rgba(34,197,94,0.3); border-radius:3px;"></span> Optimal Range (1.45–1.50)</span>
          </div>
        </div>
        ${strikeSvg}
      </div>
    </div>
  `;

  // 3. Detailed Comparison Table
  const tableRows = [
    {
      metric: "Lateral Offline Deviation (Distance from Centerline)",
      base: formatOffline(baseline.avgAbsOffline),
      rec: formatOffline(recent.avgAbsOffline),
      delta: `${offline.delta > 0 ? '+' : ''}${offline.delta.toFixed(1)} yds`,
      statusClass: formatDeltaClass(offline.status),
      verdict: offline.status === "improving" ? "🟢 Nearing Target Centerline" : (offline.status === "expanding" ? "🔴 Drifting Further Offline" : "🟡 Consistent Accuracy")
    },
    {
      metric: "Fairway / Target Corridor Accuracy (±10 yds)",
      base: `${baseline.pctInFairway}%`,
      rec: `${recent.pctInFairway}%`,
      delta: `${recent.pctInFairway >= baseline.pctInFairway ? '+' : ''}${(recent.pctInFairway - baseline.pctInFairway)}%`,
      statusClass: recent.pctInFairway >= baseline.pctInFairway ? "delta-improving" : "delta-expanding",
      verdict: recent.pctInFairway >= baseline.pctInFairway ? "🟢 Higher Target Rate" : "🔴 Wider Dispersion"
    },
    {
      metric: "Miss Bias Direction (Signed Centerline)",
      base: baseline.avgSignedOffline < 0 ? `${Math.abs(baseline.avgSignedOffline).toFixed(1)} yds Left` : `${baseline.avgSignedOffline.toFixed(1)} yds Right`,
      rec: recent.avgSignedOffline < 0 ? `${Math.abs(recent.avgSignedOffline).toFixed(1)} yds Left` : `${recent.avgSignedOffline.toFixed(1)} yds Right`,
      delta: `${Math.abs(recent.avgSignedOffline) < Math.abs(baseline.avgSignedOffline) ? '↓ Centering' : '↑ Biasing'}`,
      statusClass: Math.abs(recent.avgSignedOffline) <= Math.abs(baseline.avgSignedOffline) ? "delta-improving" : "delta-expanding",
      verdict: Math.abs(recent.avgSignedOffline) <= Math.abs(baseline.avgSignedOffline) ? "🟢 Less Bias" : "🟡 Tendency Noticeable"
    },
    {
      metric: "Club Face Angle Deviation (Degrees off Square)",
      base: baseline.avgAbsFace != null ? `±${baseline.avgAbsFace.toFixed(1)}°` : "–",
      rec: recent.avgAbsFace != null ? `±${recent.avgAbsFace.toFixed(1)}°` : "–",
      delta: face.delta != null ? `${face.delta > 0 ? '+' : ''}${face.delta.toFixed(1)}°` : "–",
      statusClass: formatDeltaClass(face.status),
      verdict: face.status === "improving" ? "🟢 Squaring Up to Target" : (face.status === "expanding" ? "🔴 Drifting Off Square" : "🟡 Stable Face Angle")
    },
    {
      metric: "Club Swing Path Deviation (Degrees off Straight)",
      base: baseline.avgAbsPath != null ? `±${baseline.avgAbsPath.toFixed(1)}°` : "–",
      rec: recent.avgAbsPath != null ? `±${recent.avgAbsPath.toFixed(1)}°` : "–",
      delta: path.delta != null ? `${path.delta > 0 ? '+' : ''}${path.delta.toFixed(1)}°` : "–",
      statusClass: formatDeltaClass(path.status),
      verdict: path.status === "improving" ? "🟢 Straightening Path" : (path.status === "expanding" ? "🔴 Steeper Deviation" : "🟡 Stable Path")
    },
    {
      metric: "Face-to-Path Differential (Curvature / Side Spin)",
      base: baseline.avgAbsFtp != null ? `${baseline.avgAbsFtp.toFixed(1)}°` : "–",
      rec: recent.avgAbsFtp != null ? `${recent.avgAbsFtp.toFixed(1)}°` : "–",
      delta: faceToPath.delta != null ? `${faceToPath.delta > 0 ? '+' : ''}${faceToPath.delta.toFixed(1)}°` : "–",
      statusClass: formatDeltaClass(faceToPath.status),
      verdict: faceToPath.status === "improving" ? "🟢 Straighter Ball Flight" : (faceToPath.status === "expanding" ? "🔴 Higher Curvature" : "🟡 Controlled Curve")
    },
    {
      metric: "Smash Factor (Ball Speed / Club Speed Compression)",
      base: baseline.avgSmash != null ? baseline.avgSmash.toFixed(2) : "–",
      rec: recent.avgSmash != null ? recent.avgSmash.toFixed(2) : "–",
      delta: smash.delta != null ? `${smash.delta > 0 ? '+' : ''}${smash.delta.toFixed(2)}` : "–",
      statusClass: formatDeltaClass(smash.status),
      verdict: smash.status === "improving" ? "🟢 More Efficient Compression" : (smash.status === "declining" ? "🔴 Lower Energy Transfer" : "🟡 Consistent Strike")
    },
    {
      metric: "Impact Distance from Sweet Spot (mm from Center Face)",
      base: baseline.avgImpactOffsetMm != null ? `${baseline.avgImpactOffsetMm.toFixed(1)} mm` : "–",
      rec: recent.avgImpactOffsetMm != null ? `${recent.avgImpactOffsetMm.toFixed(1)} mm` : "–",
      delta: impact.delta != null ? `${impact.delta > 0 ? '+' : ''}${impact.delta.toFixed(1)} mm` : "–",
      statusClass: formatDeltaClass(impact.status),
      verdict: impact.status === "improving" ? "🟢 Centering on Sweet Spot" : (impact.status === "expanding" ? "🔴 Off-Center Contact" : "🟡 Consistent Strike Point")
    },
    {
      metric: "Average Carry Distance (Yards)",
      base: `${baseline.avgCarry.toFixed(1)} yds`,
      rec: `${recent.avgCarry.toFixed(1)} yds`,
      delta: `${distance.carryDelta > 0 ? '+' : ''}${distance.carryDelta.toFixed(1)} yds`,
      statusClass: distance.carryDelta >= 0 ? "delta-improving" : "delta-neutral",
      verdict: distance.carryDelta >= 2 ? "🟢 Distance Gained" : "🟡 Maintained Distance"
    },
    {
      metric: "Carry Distance Consistency (Standard Deviation)",
      base: `±${baseline.stdDevCarry.toFixed(1)} yds`,
      rec: `±${recent.stdDevCarry.toFixed(1)} yds`,
      delta: `${distance.carryDispersionDelta > 0 ? '+' : ''}${distance.carryDispersionDelta.toFixed(1)} yds`,
      statusClass: distance.carryDispersionDelta <= 0 ? "delta-improving" : "delta-expanding",
      verdict: distance.carryDispersionDelta < -0.5 ? "🟢 Tighter Distance Grouping" : "🟡 Consistent Range"
    }
  ];

  let tableRowsHtml = "";
  tableRows.forEach(row => {
    tableRowsHtml += `
      <tr>
        <td style="font-weight: 600;">${escapeHtml(row.metric)}</td>
        <td style="color: var(--muted);">${escapeHtml(row.base)}</td>
        <td style="font-weight: 700; color: var(--text);">${escapeHtml(row.rec)}</td>
        <td class="${row.statusClass}">${escapeHtml(row.delta)}</td>
        <td>${escapeHtml(row.verdict)}</td>
      </tr>
    `;
  });

  const tableHtml = `
    <div class="analytics-table-card">
      <div class="analytics-table-header">
        <h4 class="analytics-table-title">📊 Baseline vs. Recent Performance Breakdown</h4>
        <p style="font-size:0.82rem; color:var(--muted); margin-top:0.25rem;">
          Comparing earlier recorded baseline shots against your most recent swings to evaluate game progress.
        </p>
      </div>
      <div class="table-responsive">
        <table class="analytics-table">
          <thead>
            <tr>
              <th>Metric</th>
              <th>Earlier Baseline</th>
              <th>Recent Shots</th>
              <th>Net Change</th>
              <th>Improvement Assessment</th>
            </tr>
          </thead>
          <tbody>
            ${tableRowsHtml}
          </tbody>
        </table>
      </div>
    </div>
  `;

  // 4. AI Coaching Recommendations
  const insights = generateCoachingInsights(analytics);
  let coachingItemsHtml = "";
  insights.forEach(item => {
    coachingItemsHtml += `
      <div class="coaching-item">
        <span class="coaching-icon">${item.icon}</span>
        <div class="coaching-body">
          <h4>${escapeHtml(item.title)}</h4>
          <p>${escapeHtml(item.desc)}</p>
        </div>
      </div>
    `;
  });

  const coachingHtml = `
    <div class="analytics-coaching-box">
      <div class="analytics-coaching-title">
        <span>💡 AI Swing Coach Observations &amp; Insights</span>
      </div>
      <div class="coaching-list">
        ${coachingItemsHtml}
      </div>
    </div>
  `;

  container.innerHTML = kpiGridHtml + chartsHtml + tableHtml + coachingHtml;
}

// ─── TAB: RECENT MATCHES (LAZY-LOADED) ───
async function loadRecentMatches(user) {
  const container = document.getElementById("recent-matches-container");
  if (!container) return;

  container.innerHTML = `
    <div class="loading-state">
      <div class="spinner"></div>
      <p>Loading recent matches…</p>
    </div>
  `;

  try {
    let snap;
    try {
      const q = query(
        collection(db, "profiles", user.uid, "matches"),
        orderBy("played_at", "desc"),
        limit(10)
      );
      snap = await getDocs(q);
      if (snap.empty) {
        const qFallback = query(
          collection(db, "profiles", user.uid, "matches"),
          limit(10)
        );
        snap = await getDocs(qFallback);
      }
    } catch {
      const qFallback = query(
        collection(db, "profiles", user.uid, "matches"),
        limit(10)
      );
      snap = await getDocs(qFallback);
    }
    const matches = snap.docs.map((d) => ({ id: d.id, ...d.data() }));

    loadedTabs.matches = true;

    if (matches.length === 0) {
      container.innerHTML = `
        <div class="empty-state">
          <span class="empty-icon">📋</span>
          <p>No match scorecards found yet. Complete a round in Heckle Golf to view your match history!</p>
        </div>
      `;
      return;
    }

    let listHtml = "";
    matches.forEach((m, idx) => {
      const courseName = escapeHtml(m.course_name || "Unknown Course");
      const playedTimestamp = m.played_at || m.created_at;
      const dateStr = playedTimestamp ? new Date(playedTimestamp * 1000).toLocaleDateString(undefined, { month: "short", day: "numeric", year: "numeric" }) : "";
      const holesCount = m.holes_count || 18;
      const strokes = m.strokes || "–";
      const toPar = m.to_par != null ? (m.to_par === 0 ? "E" : m.to_par > 0 ? `+${m.to_par}` : `${m.to_par}`) : "";
      const matchType = m.match_type === "multiplayer" ? "Multiplayer" : "Single Player";
      const isFinished = m.is_finished !== false;
      const statusBadge = isFinished
        ? `<span class="match-score-badge" style="background: rgba(34, 197, 94, 0.15); color: #4ade80; border: 1px solid rgba(34, 197, 94, 0.3);">Completed</span>`
        : `<span class="match-score-badge" style="background: rgba(234, 179, 8, 0.15); color: #facc15; border: 1px solid rgba(234, 179, 8, 0.3);">Partial Round</span>`;

      let holesTableHtml = "";
      if (m.holes && Array.isArray(m.holes) && m.holes.length > 0) {
        let holeHeaders = "";
        let parRow = "";
        let scoreRow = "";

        m.holes.forEach((h, hIdx) => {
          const hNum = h.hole_number || (hIdx + 1);
          holeHeaders += `<th style="padding: 0.4rem; text-align: center;">#${hNum}</th>`;
          parRow += `<td style="padding: 0.4rem; text-align: center; color: var(--muted);">${h.par ?? "–"}</td>`;
          scoreRow += `<td style="padding: 0.4rem; text-align: center; font-weight: 700; color: var(--green);">${h.score ?? "–"}</td>`;
        });

        holesTableHtml = `
          <button class="btn-toggle-scorecard" data-idx="${idx}">View Hole-by-Hole Scores ▼</button>
          <div class="scorecard-holes-table" id="scorecard-holes-${idx}">
            <div class="table-responsive">
              <table class="data-table" style="font-size: 0.8rem;">
                <thead><tr><th style="padding: 0.4rem;">Hole</th>${holeHeaders}</tr></thead>
                <tbody>
                  <tr><td style="padding: 0.4rem; font-weight: 600;">Par</td>${parRow}</tr>
                  <tr><td style="padding: 0.4rem; font-weight: 600;">Score</td>${scoreRow}</tr>
                </tbody>
              </table>
            </div>
          </div>
        `;
      }

      listHtml += `
        <div class="match-item">
          <div class="match-header">
            <span class="match-title">${courseName}</span>
            <span class="match-date">${dateStr}</span>
          </div>
          <div class="match-summary-row">
            <span><strong>${holesCount}</strong> Holes</span>
            <span><strong>${strokes}</strong> Total Strokes</span>
            ${toPar ? `<span class="match-score-badge">${toPar}</span>` : ""}
            <span>Type: <strong>${matchType}</strong></span>
            ${statusBadge}
          </div>
          ${holesTableHtml}
        </div>
      `;
    });

    container.innerHTML = listHtml;

    // Bind scorecard toggle buttons
    container.querySelectorAll(".btn-toggle-scorecard").forEach((btn) => {
      btn.addEventListener("click", () => {
        const idx = btn.dataset.idx;
        const panel = document.getElementById(`scorecard-holes-${idx}`);
        if (panel) {
          const isOpen = panel.classList.toggle("open");
          btn.textContent = isOpen ? "Hide Hole-by-Hole Scores ▲" : "View Hole-by-Hole Scores ▼";
        }
      });
    });
  } catch (err) {
    console.error("Recent matches fetch error:", err);
    container.innerHTML = `
      <div class="empty-state">
        <span class="empty-icon">⚠️</span>
        <p>Could not load matches: ${escapeHtml(err.message)}</p>
      </div>
    `;
  }
}

// ─── TAB 4: SWING ANALYSIS & RECOMMENDATIONS (LAZY-LOADED) ───
async function loadSwingAnalysis(user) {
  const swingContainer = document.getElementById("swing-analysis-container") || document.getElementById("swing-issues-container");
  if (!swingContainer) return;

  swingContainer.innerHTML = `
    <div class="loading-state">
      <div class="spinner"></div>
      <p>Loading swing recommendations &amp; tendencies…</p>
    </div>
  `;

  try {
    let statsData = currentStats;
    if (!statsData) {
      const statsSnap = await getDoc(doc(db, "profiles", user.uid, "sync", "stats"));
      statsData = statsSnap.exists() ? statsSnap.data() : {};
      currentStats = statsData;
    }
    loadedTabs.swing = true;

    const swingIssues = statsData.swing_issues || {};
    const months = Object.keys(swingIssues).sort().reverse();

    // Calculate all-time running totals across all months
    const allTimeTotals = {};
    for (const m of months) {
      const mData = swingIssues[m] || {};
      for (const [iss, cnt] of Object.entries(mData)) {
        allTimeTotals[iss] = (allTimeTotals[iss] || 0) + Number(cnt || 0);
      }
    }

    const allTimeKeys = Object.keys(allTimeTotals).sort((a, b) => allTimeTotals[b] - allTimeTotals[a]);

    if (allTimeKeys.length === 0) {
      swingContainer.innerHTML = `
        <div class="empty-state">
          <span class="empty-icon">🎯</span>
          <p>No swing recommendations recorded yet.<br>Turn on Shot Analysis and/or Golfer Camera during Driving Range, Course Play, or Practice to track swing fixes!</p>
        </div>
      `;
      return;
    }

    // Determine current month key and name
    const now = new Date();
    const currentMonthKey = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;
    const currentMonthName = now.toLocaleString("default", { month: "long", year: "numeric" });
    const curMonthData = swingIssues[currentMonthKey] || {};
    const curMonthIssues = Object.keys(curMonthData).sort((a, b) => curMonthData[b] - curMonthData[a]);

    let html = `<div class="swing-recommendations-wrapper">`;

    // 1. Current Month Running Totals
    html += `
      <div class="swing-section-block">
        <h4 class="swing-section-title">📅 Current Month Running Totals (${escapeHtml(currentMonthName)})</h4>
    `;

    if (curMonthIssues.length === 0) {
      html += `<p class="swing-section-empty">No swing recommendations recorded for ${escapeHtml(currentMonthName)}.</p>`;
    } else {
      html += `<div class="swing-cards-grid">`;
      curMonthIssues.forEach((issue) => {
        const count = curMonthData[issue];
        html += `
          <div class="swing-flaw-card">
            <div class="swing-flaw-info">
              <div class="swing-flaw-name">${escapeHtml(issue)}</div>
              <div class="swing-flaw-sub">This Month • Drill &amp; Fix Target</div>
            </div>
            <div class="swing-flaw-count">${count}</div>
          </div>
        `;
      });
      html += `</div>`;
    }
    html += `</div>`;

    // 2. All-Time Running Totals
    html += `
      <div class="swing-section-block" style="margin-top: 1.75rem;">
        <h4 class="swing-section-title" style="color: #fde047;">🏆 All-Time Running Totals</h4>
        <div class="swing-cards-grid">
    `;
    allTimeKeys.forEach((issue) => {
      const count = allTimeTotals[issue];
      html += `
        <div class="swing-flaw-card">
          <div class="swing-flaw-info">
            <div class="swing-flaw-name">${escapeHtml(issue)}</div>
            <div class="swing-flaw-sub">All Time • Total Flaw Count</div>
          </div>
          <div class="swing-flaw-count" style="color: #fde047;">${count}</div>
        </div>
      `;
    });
    html += `</div></div>`;

    // 3. Historical Monthly Breakdown (if more than 1 month exists or earlier months exist)
    const priorMonths = months.filter((m) => m !== currentMonthKey);
    if (priorMonths.length > 0) {
      html += `
        <div class="swing-section-block" style="margin-top: 1.75rem;">
          <h4 class="swing-section-title" style="color: var(--muted); font-size: 0.95rem;">📜 Prior Months History</h4>
          <div class="swing-issues-list" style="margin-top: 0.75rem;">
      `;
      priorMonths.forEach((month) => {
        const mData = swingIssues[month] || {};
        const mIssues = Object.keys(mData);
        let pillsHtml = "";
        mIssues.forEach((name) => {
          const count = mData[name];
          pillsHtml += `
            <div class="swing-pill">
              <strong>${escapeHtml(name)}</strong>
              <span class="count-badge">${count}x</span>
            </div>
          `;
        });
        html += `
          <div class="swing-month-card">
            <div class="swing-month-title">📅 ${escapeHtml(month)}</div>
            <div class="swing-tendencies">${pillsHtml}</div>
          </div>
        `;
      });
      html += `</div></div>`;
    }

    html += `</div>`;
    swingContainer.innerHTML = html;
  } catch (err) {
    console.error("Swing analysis error:", err);
    swingContainer.innerHTML = `<p class="empty-state">Could not load swing trends.</p>`;
  }
}

// ─── TAB 5: ACHIEVEMENTS (LAZY-LOADED) ───
async function loadAchievements(user) {
  const achContainer = document.getElementById("achievements-container") || document.getElementById("achievements-grid-container");
  if (!achContainer) return;

  achContainer.innerHTML = `
    <div class="loading-state">
      <div class="spinner"></div>
      <p>Loading achievements…</p>
    </div>
  `;

  try {
    let statsData = currentStats;
    if (!statsData) {
      const statsSnap = await getDoc(doc(db, "profiles", user.uid, "sync", "stats"));
      statsData = statsSnap.exists() ? statsSnap.data() : {};
      currentStats = statsData;
    }
    loadedTabs.achievements = true;

    const unlockedMap = statsData.achievements?.unlocked || {};
    const unlockedKeys = Object.keys(unlockedMap);

    if (unlockedKeys.length === 0) {
      achContainer.innerHTML = `
        <div class="empty-state">
          <span class="empty-icon">🏆</span>
          <p>No achievements unlocked yet. Play rounds and minigames to unlock achievements!</p>
        </div>
      `;
      return;
    }

    let achHtml = "";
    unlockedKeys.forEach((key) => {
      const meta = ACHIEVEMENT_LABELS[key] || { title: key.replace(/_/g, " "), desc: "Unlocked in-game challenge" };
      const ts = unlockedMap[key];
      const dateStr = ts ? new Date(ts * 1000).toLocaleDateString() : "";

      achHtml += `
        <div class="achievement-badge-card unlocked">
          <span class="achievement-icon">⭐</span>
          <div class="achievement-info">
            <h4>${escapeHtml(meta.title)}</h4>
            <p>${escapeHtml(meta.desc)}</p>
            ${dateStr ? `<p style="color: var(--green); font-size: 0.75rem;">Unlocked: ${dateStr}</p>` : ""}
          </div>
        </div>
      `;
    });
    achContainer.innerHTML = `<div class="achievements-grid">${achHtml}</div>`;
  } catch (err) {
    console.error("Achievements loading error:", err);
    achContainer.innerHTML = `<p class="empty-state">Could not load achievements.</p>`;
  }
}

// Backward compatibility helper
async function loadAchievementsAndSwing(user) {
  await Promise.all([loadSwingAnalysis(user), loadAchievements(user)]);
}

// ─── TAB 4: SHARED ACCESS & SETTINGS (REQUIREMENTS 3 & 4) ───
async function loadSharedAccessAndSettings(user) {
  loadedTabs.settings = true;
  await loadDelegatesList(user);
  await loadLeaderboardOptInStatus(user);
  bindAccountDeletion(user);
}

async function loadDelegatesList(user) {
  const container = document.getElementById("delegates-list-container");
  if (!container) return;

  container.innerHTML = `
    <div class="loading-state">
      <div class="spinner"></div>
      <p>Loading active simulator links…</p>
    </div>
  `;

  try {
    const snap = await getDocs(collection(db, "profiles", user.uid, "delegates"));
    const delegates = snap.docs.map((d) => ({ id: d.id, ...d.data() }));

    if (delegates.length === 0) {
      container.innerHTML = `
        <div class="empty-state" style="padding: 1.5rem;">
          <p>No secondary simulators or friends are currently linked to your profile.</p>
        </div>
      `;
      return;
    }

    let listHtml = "";
    delegates.forEach((d) => {
      const name = escapeHtml(d.delegate_name || "Linked Golfer");
      const email = escapeHtml(d.delegate_email || "");
      const dateStr = d.approved_at ? new Date(d.approved_at * 1000).toLocaleDateString() : "";

      listHtml += `
        <div class="delegate-item">
          <div class="delegate-info">
            <h4>${name}</h4>
            <p>${email}${dateStr ? ` · Approved on ${dateStr}` : ""}</p>
          </div>
          <button class="btn-revoke" data-delegate-uid="${d.delegate_uid || d.id}" data-request-id="${d.request_id || ""}">
            Revoke Access
          </button>
        </div>
      `;
    });

    container.innerHTML = listHtml;

    container.querySelectorAll(".btn-revoke").forEach((btn) => {
      btn.addEventListener("click", async () => {
        const delegateUid = btn.dataset.delegateUid;
        const requestId = btn.dataset.requestId;
        await revokeDelegateAccess(user, delegateUid, requestId);
      });
    });
  } catch (err) {
    console.error("Delegates fetch error:", err);
    container.innerHTML = `<p class="empty-state">Could not load delegates: ${escapeHtml(err.message)}</p>`;
  }
}

async function revokeDelegateAccess(user, delegateUid, requestId) {
  if (!confirm("Are you sure you want to revoke simulator access for this device?")) {
    return;
  }

  try {
    const batch = writeBatch(db);
    batch.delete(doc(db, "profiles", user.uid, "delegates", delegateUid));

    if (requestId) {
      batch.update(doc(db, "link_requests", requestId), {
        status: "revoked",
        updated_at: Math.floor(Date.now() / 1000)
      });
    }

    await batch.commit();
    alert("Simulator access has been revoked.");
    await loadDelegatesList(user);
  } catch (err) {
    console.error("Revoke access error:", err);
    const pauseMsg = await handleWriteError(err);
    alert(pauseMsg || ("Could not revoke access: " + err.message));
  }
}

// ─── LEADERBOARD OPT-IN / OPT-OUT (REQUIREMENT 4) ───
async function loadLeaderboardOptInStatus(user) {
  const toggle = document.getElementById("leaderboard-opt-in-toggle");
  if (!toggle) return;

  try {
    const userDocSnap = await getDoc(doc(db, "users", user.uid));
    let isOptedIn = true; // default true (Owner Decision D6)
    if (userDocSnap.exists()) {
      const data = userDocSnap.data();
      if (typeof data.leaderboard_opt_in === "boolean") {
        isOptedIn = data.leaderboard_opt_in;
      }
    }
    toggle.checked = isOptedIn;

    // Remove previous listeners
    const newToggle = toggle.cloneNode(true);
    toggle.parentNode.replaceChild(newToggle, toggle);

    newToggle.addEventListener("change", async () => {
      const checked = newToggle.checked;
      try {
        await updateDoc(doc(db, "users", user.uid), {
          leaderboard_opt_in: checked
        });

        if (!checked) {
          // Delete public_profiles doc
          await deleteDoc(doc(db, "public_profiles", user.uid));
          alert("Your profile has been removed from public leaderboards.");
        } else {
          // Re-create/update public_profiles doc
          const profSnap = await getDoc(doc(db, "profiles", user.uid));
          const p = profSnap.exists() ? profSnap.data() : {};
          const lt = p.lifetime || {};
          const displayName = p.display_name || user.displayName || user.email.split("@")[0];

          const pubData = {
            schema_version: 1,
            uid: user.uid,
            display_name: displayName,
            updated_at: Math.floor(Date.now() / 1000)
          };

          if (typeof lt.longest_drive_yds === "number" && lt.longest_drive_yds >= 0 && lt.longest_drive_yds <= 450) pubData.longest_drive_yds = lt.longest_drive_yds;
          if (typeof lt.longest_putt_ft === "number" && lt.longest_putt_ft >= 0 && lt.longest_putt_ft <= 180) pubData.longest_putt_ft = lt.longest_putt_ft;
          if (typeof lt.best_gross_18 === "number" && lt.best_gross_18 >= 18 && lt.best_gross_18 <= 250) pubData.best_gross_18 = lt.best_gross_18;
          if (typeof lt.best_to_par_18 === "number" && lt.best_to_par_18 >= -36 && lt.best_to_par_18 <= 180) pubData.best_to_par_18 = lt.best_to_par_18;
          if (typeof lt.best_gross_9 === "number" && lt.best_gross_9 >= 9 && lt.best_gross_9 <= 130) pubData.best_gross_9 = lt.best_gross_9;
          if (typeof lt.best_to_par_9 === "number" && lt.best_to_par_9 >= -18 && lt.best_to_par_9 <= 90) pubData.best_to_par_9 = lt.best_to_par_9;
          const pAch = p.achievements?.unlocked || {};
          const achTotal = Math.max(
            typeof lt.achievements_count === "number" ? lt.achievements_count : 0,
            typeof pAch === "object" ? Object.keys(pAch).length : 0
          );
          if (achTotal >= 0 && achTotal <= 100) pubData.achievements_count = achTotal;
          if (typeof lt.matches_played === "number" && lt.matches_played >= 0 && lt.matches_played <= 100000) pubData.matches_played = lt.matches_played;
          if (typeof lt.wins === "number" && lt.wins >= 0 && lt.wins <= 100000) pubData.wins = lt.wins;
          if (typeof lt.hole_in_ones === "number" && lt.hole_in_ones >= 0 && lt.hole_in_ones <= 1000) pubData.hole_in_ones = lt.hole_in_ones;

          await setDoc(doc(db, "public_profiles", user.uid), pubData, { merge: true });
          alert("Your profile is now visible on public leaderboards!");
        }
      } catch (err) {
        console.error("Leaderboard opt-in error:", err);
        const pauseMsg = await handleWriteError(err);
        alert(pauseMsg || ("Could not update privacy setting: " + err.message));
        newToggle.checked = !checked;
      }
    });
  } catch (err) {
    console.warn("Could not load user opt-in status:", err);
  }
}

// ─── ACCOUNT DELETION (REQUIREMENT 4) ───
function bindAccountDeletion(user) {
  const btnDelete = document.getElementById("btn-delete-account");
  if (!btnDelete) return;

  // Replace node to clear old listeners
  const newBtn = btnDelete.cloneNode(true);
  btnDelete.parentNode.replaceChild(newBtn, btnDelete);

  newBtn.addEventListener("click", async () => {
    const confirmation = prompt(
      "CAUTION: This will permanently delete your Heckle Golf profile, personal bests, club averages, match summaries, and account.\n\nType DELETE to confirm:"
    );

    if (confirmation !== "DELETE") {
      alert("Account deletion cancelled.");
      return;
    }

    newBtn.textContent = "Deleting Account…";
    newBtn.disabled = true;

    try {
      // 1. Delete uploaded shot-analysis sessions and their raw shot data.
      const shotAnalysisSnapshot = await getDocs(collection(db, "profiles", user.uid, "shot_analysis"));
      for (let start = 0; start < shotAnalysisSnapshot.docs.length; start += 450) {
        const batch = writeBatch(db);
        shotAnalysisSnapshot.docs.slice(start, start + 450).forEach((session) => {
          batch.delete(doc(db, "profiles", user.uid, "shot_analysis", session.id));
        });
        await batch.commit();
      }

      // 2. Delete public_profiles/{uid}
      try { await deleteDoc(doc(db, "public_profiles", user.uid)); } catch {}

      // 3. Delete profiles/{uid}/sync/stats
      try { await deleteDoc(doc(db, "profiles", user.uid, "sync", "stats")); } catch {}

      // 4. Delete profiles/{uid}
      try { await deleteDoc(doc(db, "profiles", user.uid)); } catch {}

      // 5. Delete users/{uid}
      try { await deleteDoc(doc(db, "users", user.uid)); } catch {}

      // 6. Delete Firebase Auth user
      await deleteUser(user);

      alert("Your account and cloud data have been completely deleted.");
      window.location.reload();
    } catch (err) {
      console.error("Account deletion failed:", err);
      if (err.code === "auth/requires-recent-login") {
        alert("This operation is sensitive and requires recent authentication. Please sign out and sign back in before deleting your account.");
      } else {
        const pauseMsg = await handleWriteError(err);
        alert(pauseMsg || ("Could not complete account deletion: " + err.message));
      }
      newBtn.textContent = "Delete Account & Cloud Data";
      newBtn.disabled = false;
    }
  });
}

function escapeHtml(str) {
  if (!str) return "";
  return String(str)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}
