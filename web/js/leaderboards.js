import { db, collection, query, where, orderBy, limit, getDocs, auth } from "./firebase-init.js";

const LB_CACHE_TTL_MS = 10 * 60 * 1000; // 10 minutes (Hole H21)

export const LEADERBOARD_CATEGORIES = [
  {
    id: "longest_drive",
    name: "Longest Drive",
    icon: "🚀",
    field: "longest_drive_yds",
    direction: "desc",
    formatVal: (val) => `${Number(val).toFixed(1)} yds`,
    emptyText: "No longest drive records yet. Grip it and rip it on the course or range!"
  },
  {
    id: "longest_putt",
    name: "Longest Putt",
    icon: "⛳",
    field: "longest_putt_ft",
    direction: "desc",
    formatVal: (val) => `${Number(val).toFixed(1)} ft`,
    emptyText: "No longest putt records yet. Sink a long putt in practice or course play!"
  },
  {
    id: "lowest_score_18",
    name: "Lowest Score (18H)",
    icon: "🏆",
    field: "best_to_par_18",
    direction: "asc",
    formatVal: (val, row) => {
      const parVal = Number(val);
      const parStr = parVal === 0 ? "E" : parVal > 0 ? `+${parVal}` : `${parVal}`;
      return row.best_gross_18 != null
        ? `${parStr} <span class="stat-sub">(${row.best_gross_18})</span>`
        : parStr;
    },
    emptyText: "No 18-hole rounds recorded yet. Finish 18 holes to post your score!"
  },
  {
    id: "lowest_score_9",
    name: "Lowest Score (9H)",
    icon: "🎯",
    field: "best_to_par_9",
    direction: "asc",
    formatVal: (val, row) => {
      const parVal = Number(val);
      const parStr = parVal === 0 ? "E" : parVal > 0 ? `+${parVal}` : `${parVal}`;
      return row.best_gross_9 != null
        ? `${parStr} <span class="stat-sub">(${row.best_gross_9})</span>`
        : parStr;
    },
    emptyText: "No 9-hole rounds recorded yet. Play a quick 9 holes to rank here!"
  },
  {
    id: "most_achievements",
    name: "Most Achievements",
    icon: "⭐",
    field: "achievements_count",
    direction: "desc",
    formatVal: (val) => `${val} unlocked`,
    emptyText: "No achievements recorded yet. Unlock achievements in-game to rank here!"
  },
  {
    id: "most_games",
    name: "Most Games Played",
    icon: "🕹️",
    field: "matches_played",
    direction: "desc",
    formatVal: (val) => `${val} rounds`,
    emptyText: "No rounds logged yet. Be the first to play and record your games!"
  },
  {
    id: "most_wins",
    name: "Most Wins",
    icon: "🥇",
    field: "wins",
    direction: "desc",
    formatVal: (val) => `${val} wins`,
    emptyText: "No multiplayer wins recorded yet. Challenge other players to claim the top spot!"
  }
];

let currentCategoryId = "longest_drive";

export function initLeaderboards() {
  const tabsContainer = document.getElementById("lb-tabs");
  if (!tabsContainer) return;

  tabsContainer.innerHTML = "";
  LEADERBOARD_CATEGORIES.forEach((cat, index) => {
    const li = document.createElement("li");
    const btn = document.createElement("button");
    btn.className = `lb-tab-btn ${index === 0 ? "active" : ""}`;
    btn.dataset.category = cat.id;
    btn.innerHTML = `${cat.icon} ${cat.name}`;
    btn.addEventListener("click", () => switchCategory(cat.id));
    li.appendChild(btn);
    tabsContainer.appendChild(li);
  });

  const refreshBtn = document.getElementById("lb-refresh-btn");
  if (refreshBtn) {
    refreshBtn.addEventListener("click", () => {
      loadCategory(currentCategoryId, true);
    });
  }

  loadCategory(currentCategoryId, false);
}

export function switchCategory(categoryId) {
  currentCategoryId = categoryId;
  document.querySelectorAll(".lb-tab-btn").forEach((btn) => {
    btn.classList.toggle("active", btn.dataset.category === categoryId);
  });
  loadCategory(categoryId, false);
}

async function loadCategory(categoryId, forceRefresh = false) {
  const category = LEADERBOARD_CATEGORIES.find((c) => c.id === categoryId);
  if (!category) return;

  const contentArea = document.getElementById("lb-content-area");
  const cacheStatusEl = document.getElementById("lb-cache-status");
  if (!contentArea) return;

  const cacheKey = `hgs_lb_${categoryId}`;

  // 1. Check sessionStorage cache
  if (!forceRefresh) {
    const cachedStr = sessionStorage.getItem(cacheKey);
    if (cachedStr) {
      try {
        const cached = JSON.parse(cachedStr);
        if (cached && Array.isArray(cached.data) && cached.data.length > 0) {
          const ageMs = Date.now() - cached.timestamp;
          if (ageMs < LB_CACHE_TTL_MS) {
            const remainingMins = Math.ceil((LB_CACHE_TTL_MS - ageMs) / 60000);
            if (cacheStatusEl) {
              cacheStatusEl.textContent = `Cached (refreshes in ~${remainingMins}m)`;
            }
            renderTable(contentArea, category, cached.data);
            return;
          }
        }
      } catch {
        // Corrupted cache - continue to fetch
      }
    }
  }

  // 2. Fetch from Cloud Firestore public_profiles collection
  renderLoading(contentArea);
  if (cacheStatusEl) {
    cacheStatusEl.textContent = "Fetching live rankings…";
  }

  try {
    let q;
    const filterPositive = (
      category.id === "longest_drive" ||
      category.id === "longest_putt" ||
      category.id === "most_achievements" ||
      category.id === "most_games" ||
      category.id === "most_wins"
    );
    if (filterPositive) {
      q = query(
        collection(db, "public_profiles"),
        where(category.field, ">", 0),
        orderBy(category.field, category.direction),
        limit(25)
      );
    } else {
      q = query(
        collection(db, "public_profiles"),
        orderBy(category.field, category.direction),
        limit(25)
      );
    }

    let snap;
    try {
      snap = await getDocs(q);
    } catch (queryErr) {
      if (filterPositive) {
        // Fallback to simple orderBy if composite index/where filter rejected
        q = query(
          collection(db, "public_profiles"),
          orderBy(category.field, category.direction),
          limit(25)
        );
        snap = await getDocs(q);
      } else {
        throw queryErr;
      }
    }

    const data = snap.docs.map((d) => ({ id: d.id, ...d.data() }));

    const filteredRows = (data || []).filter((r) => {
      const val = r[category.field];
      if (val == null) return false;
      if (filterPositive && Number(val) <= 0) {
        return false;
      }
      return true;
    });

    // Cache in sessionStorage only if we have actual valid non-zero rows
    if (filteredRows.length > 0) {
      sessionStorage.setItem(
        cacheKey,
        JSON.stringify({ timestamp: Date.now(), data: filteredRows })
      );
      if (cacheStatusEl) {
        cacheStatusEl.textContent = "Live data (cached for 10m)";
      }
    } else {
      sessionStorage.removeItem(cacheKey);
      if (cacheStatusEl) {
        cacheStatusEl.textContent = "Live data";
      }
    }
    renderTable(contentArea, category, filteredRows);
  } catch (err) {
    console.error(`Leaderboard error for ${categoryId}:`, err);
    sessionStorage.removeItem(cacheKey);
    renderError(contentArea, err.message);
    if (cacheStatusEl) {
      cacheStatusEl.textContent = "Offline or unavailable";
    }
  }
}

function renderLoading(container) {
  container.innerHTML = `
    <div class="loading-state">
      <div class="spinner"></div>
      <p>Loading leaderboard rankings…</p>
    </div>
  `;
}

function renderError(container, message) {
  container.innerHTML = `
    <div class="empty-state">
      <span class="empty-icon">⚠️</span>
      <p>Unable to load leaderboard data: ${escapeHtml(message)}</p>
      <button class="btn-refresh" style="margin-top:1rem;" onclick="window.hgsRefreshLeaderboard()">Try Again</button>
    </div>
  `;
}

function renderTable(container, category, rows) {
  const filterPositive = (
    category.id === "longest_drive" ||
    category.id === "longest_putt" ||
    category.id === "most_achievements" ||
    category.id === "most_games" ||
    category.id === "most_wins"
  );
  const filteredRows = (rows || []).filter((r) => {
    const val = r[category.field];
    if (val == null) return false;
    if (filterPositive && Number(val) <= 0) {
      return false;
    }
    return true;
  });

  if (!filteredRows || filteredRows.length === 0) {
    container.innerHTML = `
      <div class="empty-state">
        <span class="empty-icon">${category.icon}</span>
        <p>${category.emptyText}</p>
      </div>
    `;
    return;
  }

  let rowsHtml = "";
  filteredRows.forEach((row, i) => {
    const rank = i + 1;
    let rankBadge = `<span class="rank-badge rank-other">#${rank}</span>`;
    if (rank === 1) rankBadge = `<span class="rank-badge rank-1" title="1st Place">🥇 1</span>`;
    else if (rank === 2) rankBadge = `<span class="rank-badge rank-2" title="2nd Place">🥈 2</span>`;
    else if (rank === 3) rankBadge = `<span class="rank-badge rank-3" title="3rd Place">🥉 3</span>`;

    const displayName = escapeHtml(row.display_name || "Anonymous Golfer");
    const rawVal = row[category.field];
    const valDisplay = rawVal != null ? category.formatVal(rawVal, row) : "–";

    const currentUid = auth?.currentUser?.uid;
    const isCurrentUser = currentUid && (row.uid === currentUid || row.id === currentUid);
    const youBadge = isCurrentUser
      ? `<span class="badge" style="background: rgba(0, 212, 255, 0.2); color: #00d4ff; font-size: 0.72rem; font-weight: 700; margin-left: 0.5rem; padding: 2px 7px; border-radius: 4px; border: 1px solid rgba(0, 212, 255, 0.45); vertical-align: middle;">YOU</span>`
      : "";
    const rowClass = isCurrentUser ? "current-user-row" : "";
    const rowStyle = isCurrentUser ? "background: rgba(0, 212, 255, 0.08); border-left: 3px solid #00d4ff;" : "";

    rowsHtml += `
      <tr class="${rowClass}" style="${rowStyle}">
        <td style="width: 70px;">${rankBadge}</td>
        <td>
          <span style="font-weight: 600;">${displayName}</span>${youBadge}
        </td>
        <td style="text-align: right;">
          <span class="stat-highlight">${valDisplay}</span>
        </td>
      </tr>
    `;
  });

  container.innerHTML = `
    <div class="table-responsive">
      <table class="data-table">
        <thead>
          <tr>
            <th style="width: 70px;">Rank</th>
            <th>Player</th>
            <th style="text-align: right;">${escapeHtml(category.name)}</th>
          </tr>
        </thead>
        <tbody>
          ${rowsHtml}
        </tbody>
      </table>
    </div>
  `;
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

window.hgsRefreshLeaderboard = () => {
  loadCategory(currentCategoryId, true);
};
