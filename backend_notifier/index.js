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

function saveHistory(historySet) {
  try {
    let list = Array.from(historySet);
    // حداکثر ۱۰۰۰ شناسه اخیر را نگه دار تا فایل سبک بماند
    if (list.length > 1000) {
      list = list.slice(list.length - 800);
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

/**
 * ذخیره آنی تاریخچه در گیت‌هاب بلافاصله پس از ارسال نوتیفیکیشن جدید
 */
function commitAndPushHistoryLive() {
  if (!process.env.GITHUB_ACTIONS) return;
  try {
    execSync('git config user.name "DevScout Cloud Bot"', { cwd: REPO_ROOT, stdio: 'ignore' });
    execSync('git config user.email "bot@devscout.app"', { cwd: REPO_ROOT, stdio: 'ignore' });
    execSync('git add backend_notifier/history.json backend_notifier/jobinja_cache.json', {
      cwd: REPO_ROOT,
      stdio: 'ignore',
    });
    const status = execSync('git status --porcelain backend_notifier/', {
      cwd: REPO_ROOT,
      encoding: 'utf8',
    }).trim();
    if (status) {
      execSync('git commit -m "chore(cloud): real-time update notified jobs history [skip ci]"', {
        cwd: REPO_ROOT,
        stdio: 'ignore',
      });
      execSync('git pull --rebase || true', { cwd: REPO_ROOT, stdio: 'ignore' });
      execSync('git push || true', { cwd: REPO_ROOT, stdio: 'ignore' });
      console.log('💾 [Git Sync] Real-time history.json synced to repository.');
    }
  } catch (e) {
    console.warn('⚠️ [Git Sync Warning]:', e.message);
  }
}

async function runSingleCheckCycle(cycleNumber = 1) {
  console.log(`\n------------------------------------------------------`);
  console.log(`[DevScout Cycle #${cycleNumber}] Checking at ${new Date().toISOString()}`);
  console.log(`------------------------------------------------------`);

  const history = loadHistory();
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

  if (isFirstRun) {
    console.log(`⚡ [First Run Initialization] Marking ${allJobs.length} current jobs as baseline...`);
    for (const job of allJobs) {
      history.add(job.id);
    }
    saveHistory(history);

    const sample = allJobs[0];
    console.log(`🚀 Sending initial verification push for: "${sample.title}" (${sample.source})`);
    await sendJobPushNotification(sample);
    commitAndPushHistoryLive();
    return;
  }

  const newJobs = allJobs.filter((job) => !history.has(job.id));
  if (newJobs.length === 0) {
    console.log(`✨ Up-to-date. No new jobs since last 60s check.`);
    return;
  }

  console.log(`🔔 NEW JOBS DETECTED: ${newJobs.length}`);
  const toNotify = newJobs.slice(0, 3);
  let sentCount = 0;

  for (const job of toNotify) {
    const success = await sendJobPushNotification(job);
    if (success) {
      sentCount++;
    }
    history.add(job.id);
  }

  for (const job of newJobs) {
    history.add(job.id);
  }

  saveHistory(history);
  commitAndPushHistoryLive();
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

main().catch((err) => {
  console.error('Fatal Runner Error:', err);
  process.exit(1);
});

