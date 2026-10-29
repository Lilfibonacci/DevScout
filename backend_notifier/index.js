/**
 * نقطه ورود کرون‌جاب ابری DevScout
 * اجرای دوره‌ای توسط GitHub Actions، سرور یا cron سیستم
 */

const fs = require('fs');
const path = require('path');
const { scrapeAll } = require('./scraper');
const { initFirebase, sendJobPushNotification } = require('./fcm');

const HISTORY_FILE = path.join(__dirname, 'history.json');

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
    // حداکثر ۸۰۰ شناسه اخیر را نگه دار تا فایل سبک بماند
    if (list.length > 800) {
      list = list.slice(list.length - 600);
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

async function main() {
  console.log(`\n======================================================`);
  console.log(`[DevScout Cloud Notifier] Starting check at ${new Date().toISOString()}`);
  console.log(`======================================================`);

  initFirebase();

  const history = loadHistory();
  const isFirstRun = history.size === 0;

  console.log(`🔍 [1/3] Scraping live listings from Ponisha, Karlancer, Jobinja, JobVision...`);
  const allJobs = await scrapeAll();
  console.log(`📊 Found ${allJobs.length} total active Flutter & Android opportunities.`);

  if (allJobs.length === 0) {
    console.log('ℹ️ No listings scraped in this cycle. Exiting cleanly.');
    return;
  }

  if (isFirstRun) {
    console.log(`⚡ [First Run Initialization] Marking ${allJobs.length} current jobs as baseline...`);
    for (const job of allJobs) {
      history.add(job.id);
    }
    saveHistory(history);

    // در اولین بار اجرا، جدیدترین آگهی را به عنوان اعلان تست ارسال کن
    const sample = allJobs[0];
    console.log(`🚀 Sending initial verification push for: "${sample.title}" (${sample.source})`);
    await sendJobPushNotification(sample);
    console.log(`✅ Baseline established. Future runs will push newly posted jobs instantly!`);
    return;
  }

  // پیدا کردن آگهی‌هایی که در دیتابیس تاریخچه ثبت نشده‌اند
  const newJobs = allJobs.filter((job) => !history.has(job.id));
  console.log(`🔔 [2/3] New un-notified jobs detected: ${newJobs.length}`);

  if (newJobs.length === 0) {
    console.log(`✨ All listings are up-to-date. No new push needed.`);
    return;
  }

  // ارسال اعلان حداکثر برای ۳ آگهی جدید اخیر در هر اجرا تا کاربر اسپم نشود
  const toNotify = newJobs.slice(0, 3);
  let sentCount = 0;

  console.log(`📤 [3/3] Dispatching high-priority FCM notifications...`);
  for (const job of toNotify) {
    const success = await sendJobPushNotification(job);
    if (success) {
      sentCount++;
    }
    // اضافه کردن به تاریخچه تا هرگز مجدداً ارسال نشود
    history.add(job.id);
  }

  // اضافه کردن بقیه آگهی‌های جدید هم به تاریخچه
  for (const job of newJobs) {
    history.add(job.id);
  }

  saveHistory(history);
  console.log(`🎉 [Done] Successfully dispatched ${sentCount} FCM notifications to subscribed phones!`);
}

main().catch((err) => {
  console.error('Fatal Runner Error:', err);
  process.exit(1);
});
