/**
 * نقطه ورود کرون‌جاب و حلقه زنده (Real-Time 60s Loop) ابری DevScout
 * اجرای ۲۴/۷ توسط GitHub Actions با چک هر ۶۰ ثانیه و تاخیر نزدیک به صفر
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const { scrapeAll } = require('./scraper');
const { initFirebase, sendJobPushNotification } = require('./fcm');

const HISTORY_FILE = path.join(__dirname, 'history.json');
const REPO_ROOT = path.resolve(__dirname, '..');
const MAX_HISTORY_IDS = 5000;
const TRIM_HISTORY_IDS = 4000;
const MAX_NOTIFICATION_AGE_HOURS = 72;

const sessionHistory = new Set();

function loadHistory() {
  try {
    if (fs.existsSync(HISTORY_FILE)) {
      const data = JSON.parse(fs.readFileSync(HISTORY_FILE, 'utf8'));
      if (Array.isArray(data)) return new Set(data);
      if (Array.isArray(data.seenIds)) return new Set(data.seenIds);
    }
  } catch (e) {
    console.warn('⚠️ Could not parse history.json, starting fresh:', e.message);
  }
  return new Set();
}

function trimHistoryList(list) {
  if (list.length > MAX_HISTORY_IDS) {
    return list.slice(list.length - TRIM_HISTORY_IDS);
  }
  return list;
}

function refreshActiveIdsLru(historySet, activeIds) {
  for (const id of activeIds) {
    if (historySet.has(id)) {
      historySet.delete(id);
      historySet.add(id);
    }
  }
  return historySet;
}

function mergeHistorySets(localSet, remoteList) {
  const merged = new Set();
  if (Array.isArray(remoteList) || remoteList instanceof Set) {
    for (const id of remoteList) {
      if (id) merged.add(id);
    }
  }
  if (localSet) {
    for (const id of localSet) {
      if (!id) continue;
      if (merged.has(id)) merged.delete(id);
      merged.add(id);
    }
  }
  const trimmed = trimHistoryList(Array.from(merged));
  return new Set(trimmed);
}

function filterFreshJobsForNotification(
  newJobs,
  maxAgeHours = MAX_NOTIFICATION_AGE_HOURS,
  nowMs = Date.now()
) {
  const maxAgeMs = maxAgeHours * 60 * 60 * 1000;
  return newJobs.filter((job) => {
    if (!job || !job.publishedAt) return true;
    const publishedMs = new Date(job.publishedAt).getTime();
    if (Number.isNaN(publishedMs)) return true;
    return nowMs - publishedMs <= maxAgeMs;
  });
}

function saveHistory(historySet) {
  try {
    const list = trimHistoryList(Array.from(historySet));
    if (historySet.size > list.length) {
      historySet.clear();
      for (const id of list) historySet.add(id);
    }
    fs.writeFileSync(
      HISTORY_FILE,
      JSON.stringify(
        {
          lastRun: new Date().toISOString(),
          count: list.length,
          seenIds: list,
        },
        null,
        2
      )
    );
  } catch (e) {
    console.error('❌ Could not save history.json:', e.message);
  }
}

function readRemoteHistoryIds(branch) {
  try {
    const raw = execSync(`git show origin/${branch}:backend_notifier/history.json`, {
      cwd: REPO_ROOT,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    });
    const parsed = JSON.parse(raw);
    if (Array.isArray(parsed)) return parsed;
    if (Array.isArray(parsed.seenIds)) return parsed.seenIds;
  } catch (_) {}
  return [];
}

/**
 * ذخیره امن تاریخچه در گیت‌هاب بدون تداخل rebase و همگام‌سازی خودکار با ریموت
 */
function commitAndPushHistoryLive(historySet) {
  if (!process.env.GITHUB_ACTIONS) return;
  try {
    execSync('git config user.name "DevScout Cloud Bot"', { cwd: REPO_ROOT, stdio: 'ignore' });
    execSync('git config user.email "bot@devscout.app"', { cwd: REPO_ROOT, stdio: 'ignore' });

    const branch = execSync('git rev-parse --abbrev-ref HEAD', {
      cwd: REPO_ROOT,
      encoding: 'utf8',
    }).trim() || 'main';

    for (let attempt = 1; attempt <= 3; attempt++) {
      try {
        try {
          execSync('git rebase --abort', { cwd: REPO_ROOT, stdio: 'ignore' });
        } catch (_) {}

        execSync(`git fetch origin ${branch}`, { cwd: REPO_ROOT, stdio: 'ignore' });
        const remoteIds = readRemoteHistoryIds(branch);
        const merged = mergeHistorySets(historySet, remoteIds);
        historySet.clear();
        for (const id of merged) {
          historySet.add(id);
          sessionHistory.add(id);
        }
        saveHistory(historySet);

        execSync('git add backend_notifier/history.json backend_notifier/jobinja_cache.json', {
          cwd: REPO_ROOT,
          stdio: 'ignore',
        });
        const status = execSync('git status --porcelain backend_notifier/', {
          cwd: REPO_ROOT,
          encoding: 'utf8',
        }).trim();

        if (!status) {
          return;
        }

        execSync('git commit -m "chore(cloud): real-time update notified jobs history [skip ci]"', {
          cwd: REPO_ROOT,
          stdio: 'ignore',
        });
        execSync(`git push origin HEAD:${branch}`, { cwd: REPO_ROOT, stdio: 'ignore' });
        console.log('💾 [Git Sync] Real-time history.json synced to repository.');
        return;
      } catch (innerErr) {
        console.warn(`⚠️ [Git Sync Attempt ${attempt}/3]:`, innerErr.message);
        try {
          execSync(`git reset --mixed origin/${branch}`, { cwd: REPO_ROOT, stdio: 'ignore' });
        } catch (_) {}
      }
    }
  } catch (e) {
    console.warn('⚠️ [Git Sync Warning]:', e.message);
  }
}

async function runSingleCheckCycle(cycleNumber = 1) {
  console.log(`\n------------------------------------------------------`);
  console.log(`[DevScout Cycle #${cycleNumber}] Checking at ${new Date().toISOString()}`);
  console.log(`------------------------------------------------------`);

  const diskHistory = loadHistory();
  const history = mergeHistorySets(sessionHistory, diskHistory);
  const isFirstRun = history.size === 0;

  const allJobs = await scrapeAll();
  const bySource = {};
  for (const j of allJobs) {
    bySource[j.source] = (bySource[j.source] || 0) + 1;
  }
  console.log(`📊 Active opportunities (${allJobs.length} total):`, JSON.stringify(bySource));

  if (allJobs.length === 0) {
    console.log('ℹ️ No listings scraped in this cycle.');
    return;
  }

  refreshActiveIdsLru(history, allJobs.map((j) => j.id));

  if (isFirstRun) {
    console.log(`⚡ [First Run Initialization] Marking ${allJobs.length} current jobs as baseline...`);
    for (const job of allJobs) {
      history.add(job.id);
      sessionHistory.add(job.id);
    }
    saveHistory(history);

    const sample = allJobs[0];
    console.log(`🚀 Sending initial verification push for: "${sample.title}" (${sample.source})`);
    await sendJobPushNotification(sample);
    commitAndPushHistoryLive(history);
    return;
  }

  const newJobs = allJobs.filter((job) => !history.has(job.id));
  if (newJobs.length === 0) {
    for (const id of history) sessionHistory.add(id);
    saveHistory(history);
    console.log(`✨ Up-to-date. No new jobs since last 60s check.`);
    return;
  }

  console.log(`🔔 NEW JOBS DETECTED: ${newJobs.length}`);
  const freshJobs = filterFreshJobsForNotification(newJobs);
  const toNotify = freshJobs.slice(0, 3);
  let sentCount = 0;

  for (const job of toNotify) {
    const success = await sendJobPushNotification(job);
    if (success) {
      sentCount++;
    }
    history.add(job.id);
    sessionHistory.add(job.id);
    saveHistory(history);
  }

  for (const job of newJobs) {
    history.add(job.id);
    sessionHistory.add(job.id);
  }

  saveHistory(history);
  commitAndPushHistoryLive(history);
  console.log(`🎉 Dispatched ${sentCount} instant FCM notifications!`);
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function main() {
  initFirebase();

  const isLoopMode =
    process.argv.includes('--loop') || process.env.LOOP_MODE === 'true';

  if (!isLoopMode) {
    await runSingleCheckCycle(1);
    return;
  }

  const durationMinutes = Number(process.env.LOOP_DURATION_MINUTES || 320);
  const intervalSeconds = Number(process.env.CHECK_INTERVAL_SECONDS || 60);
  const endTime = Date.now() + durationMinutes * 60 * 1000;

  console.log(`======================================================`);
  console.log(`🚀 DevScout 24/7 Real-Time Loop Started!`);
  console.log(`⏱️  Check Interval: Every ${intervalSeconds} seconds`);
  console.log(`⏳ Session Duration: ${durationMinutes} minutes`);
  console.log(`======================================================`);

  let cycle = 1;
  while (Date.now() < endTime) {
    const cycleStart = Date.now();
    try {
      await runSingleCheckCycle(cycle);
    } catch (err) {
      console.error(`⚠️ Error in cycle #${cycle}:`, err.message);
    }
    cycle++;

    const elapsed = Date.now() - cycleStart;
    const waitMs = Math.max(5000, intervalSeconds * 1000 - elapsed);
    if (Date.now() + waitMs >= endTime) break;
    await sleep(waitMs);
  }

  console.log(`✅ Loop session (${durationMinutes}m) completed cleanly. Handing off to next runner!`);
}

if (require.main === module) {
  main().catch((err) => {
    console.error('Fatal Runner Error:', err);
    process.exit(1);
  });
}

module.exports = {
  loadHistory,
  saveHistory,
  trimHistoryList,
  refreshActiveIdsLru,
  mergeHistorySets,
  filterFreshJobsForNotification,
  runSingleCheckCycle,
};

