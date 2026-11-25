/**
 * ماژول ارسال نوتیفیکیشن فایربیس (Firebase Cloud Messaging)
 * این ماژول پیام‌های Push با اولویت بالا (High Priority) ارسال می‌کند تا حتی اگر اپ کاملاً بسته باشد،
 * سرویس Google Play Services در اندروید اعلان را فوراً در نوار اعلان نمایش دهد (دقیقاً مثل تلگرام).
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

let isInitialized = false;

function initFirebase() {
  if (isInitialized) return true;

  try {
    // ۱. بررسی متغیر محیطی حاوی کلید سرویس فایربیس (برای گیت‌هاب اکشنز یا کلود)
    if (process.env.FIREBASE_SERVICE_ACCOUNT_KEY) {
      let raw = process.env.FIREBASE_SERVICE_ACCOUNT_KEY.trim();
      // پشتیبانی از فرمت Base64
      if (raw.startsWith('ey') || !raw.startsWith('{')) {
        raw = Buffer.from(raw, 'base64').toString('utf8');
      }
      const serviceAccount = JSON.parse(raw);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
      isInitialized = true;
      console.log(`✅ Firebase Admin initialized for project "${serviceAccount.project_id}" from FIREBASE_SERVICE_ACCOUNT_KEY env var.`);
      return true;
    }

    // ۲. بررسی وجود فایل محلی serviceAccountKey.json
    const keyPath = path.join(__dirname, 'serviceAccountKey.json');
    if (fs.existsSync(keyPath)) {
      const serviceAccount = require(keyPath);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
      isInitialized = true;
      console.log('✅ Firebase Admin initialized from serviceAccountKey.json file.');
      return true;
    }

    // ۳. استفاده از پیش‌فرض گوگل (GOOGLE_APPLICATION_CREDENTIALS)
    if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
      admin.initializeApp({
        credential: admin.credential.applicationDefault(),
      });
      isInitialized = true;
      console.log('✅ Firebase Admin initialized from GOOGLE_APPLICATION_CREDENTIALS.');
      return true;
    }

    console.warn(
      '⚠️ هشدار: کلید فایربیس یافت نشد! برای ارسال نوتیفیکیشن واقعی به گوشی، فایل serviceAccountKey.json را قرار دهید یا متغیر FIREBASE_SERVICE_ACCOUNT_KEY را تنظیم کنید.'
    );
    return false;
  } catch (err) {
    console.error('❌ خطا در راه‌اندازی Firebase Admin:', err.message);
    return false;
  }
}

/**
 * ساخت شرط تاپیک برای ارسال دقیقاً یک پیام واحد بدون تکرار بین دسته‌بندی و تخصص
 */
function buildFcmCondition(job) {
  const categoryTopic =
    job.tabCategory === 'freelance'
      ? 'freelance_projects'
      : 'employment_jobs';

  const skillsText = Array.isArray(job.skills) ? job.skills.join(' ') : '';
  const combined = `${job.title || ''} ${job.description || ''} ${skillsText}`;

  const isFlutter =
    job.isFlutter === true ||
    /flutter|فلاتر|dart|دارت/i.test(combined) ||
    job.topic === 'flutter_jobs';
  const isAndroid =
    job.isAndroid === true ||
    /android|اندروید|kotlin|کاتلین|\bjava\b|جاوا/i.test(combined);

  let roleExpr;
  if (isFlutter && !isAndroid) {
    roleExpr = "'flutter_jobs' in topics";
  } else if (isAndroid && !isFlutter) {
    roleExpr = "'android_jobs' in topics";
  } else {
    roleExpr = "('flutter_jobs' in topics || 'android_jobs' in topics)";
  }

  return `${roleExpr} && '${categoryTopic}' in topics`;
}

function truncateStr(val, maxLen) {
  if (val === undefined || val === null) return '';
  const str = String(val).trim();
  if (str.length <= maxLen) return str;
  return `${str.slice(0, Math.max(0, maxLen - 1))}…`;
}

/**
 * ساخت پیلود کامل و ایمن زیر سقف ۴۰۹۶ بایت FCM برای باز شدن آنی جزئیات در اپ
 */
function buildSafeFcmData(job) {
  const workMode =
    job.workModeKey ||
    (String(job.workMode || '').includes('دورکار')
      ? 'remote'
      : String(job.workMode || '').includes('هیبرید')
        ? 'hybrid'
        : 'onSite');

  const sourceKey =
    job.sourceKey ||
    (String(job.id || '').split('_')[0] || 'jobinja');

  const skillsArray = Array.isArray(job.skills)
    ? job.skills.slice(0, 5).map((s) => String(s))
    : [];

  const data = {
    id: String(job.id || ''),
    jobId: String(job.id || ''),
    title: truncateStr(job.title || '', 180),
    company: truncateStr(job.company || job.companyOrClient || '', 120),
    source: truncateStr(job.source || '', 40),
    sourceKey: String(sourceKey),
    salary: truncateStr(job.salaryOrBudget || 'توافقی', 100),
    city: truncateStr(job.city || 'ایران', 80),
    workMode: String(workMode),
    contractType: truncateStr(job.contractType || '', 80),
    description: truncateStr(job.description || '', 700),
    skills: JSON.stringify(skillsArray),
    publishedAt: String(job.publishedAt || new Date().toISOString()),
    publishedTimeText: truncateStr(job.publishedTimeText || 'جدید', 40),
    proposalsCountText: truncateStr(job.proposalsCountText || '', 60),
    isUrgent: job.isUrgent === true ? 'true' : 'false',
    url: String(job.originalUrl || ''),
    click_action: 'FLUTTER_NOTIFICATION_CLICK',
  };

  if (Buffer.byteLength(JSON.stringify(data), 'utf8') > 3400) {
    data.description = truncateStr(job.description || '', 300);
  }
  if (Buffer.byteLength(JSON.stringify(data), 'utf8') > 3400) {
    data.description = truncateStr(job.description || '', 120);
  }
  if (Buffer.byteLength(JSON.stringify(data), 'utf8') > 3400) {
    data.description = '';
  }
  if (Buffer.byteLength(JSON.stringify(data), 'utf8') > 3400) {
    data.skills = '[]';
    data.title = truncateStr(job.title || '', 100);
    data.company = truncateStr(job.company || job.companyOrClient || '', 60);
    data.contractType = truncateStr(job.contractType || '', 40);
  }

  return data;
}

/**
 * ارسال یک پیام پوش آنی یکتا به ترکیب تاپیک‌ها (بدون ارسال تکراری)
 */
async function sendJobPushNotification(job) {
  if (!initFirebase()) {
    console.log(
      `[MOCK PUSH] آگهی آماده ارسال بود ولی فایربیس تنظیم نشده است: "${job.title}" (${job.source})`
    );
    return false;
  }

  const condition = buildFcmCondition(job);
  const safeTag = String(job.id)
    .replace(/[^a-zA-Z0-9_.-]/g, '_')
    .slice(0, 64);

  // ساخت بدنه اعلان
  const title = `🔔 ${job.source}: ${job.title}`;
  const body = job.company
    ? `🏢 ${job.company} | 📍 ${job.city} (${job.workMode})\n💰 ${job.salaryOrBudget}`
    : `📍 ${job.city} (${job.workMode}) | 💰 ${job.salaryOrBudget}`;

  const message = {
    condition,
    notification: {
      title,
      body,
    },
    data: buildSafeFcmData(job),
    android: {
      priority: 'high',
      collapseKey: safeTag,
      notification: {
        channelId: 'job_radar_high_importance_channel',
        tag: safeTag,
        sound: 'default',
        priority: 'max',
        visibility: 'public',
        icon: 'ic_launcher',
        clickAction: 'FLUTTER_NOTIFICATION_CLICK',
      },
    },
  };

  try {
    const response = await admin.messaging().send(message);
    console.log(
      `🚀 [FCM Push Sent] -> Condition: (${condition}) | ID: ${job.id} | Response: ${response}`
    );
    return true;
  } catch (err) {
    console.error(`❌ [FCM Push Error] for ${job.id}:`, err.message);
    return false;
  }
}

/**
 * ارسال اعلان تستی فوری برای بررسی کارکرد روی گوشی بسته
 */
async function sendTestPushNotification({ title, body } = {}) {
  if (!initFirebase()) {
    throw new Error(
      'فایربیس متصل نیست. لطفاً کلید serviceAccountKey.json را قرار دهید.'
    );
  }

  const testTitle = title || '🔔 تست اعلان DevScout مثل تلگرام (اپ بسته است)';
  const testBody =
    body ||
    'این اعلان از طریق سرور ابری فایربیس و بدون مصرف باتری ارسال شده است. ضربه بزنید تا برنامه باز شود!';

  const testJob = {
    id: 'test_cloud_push',
    title: testTitle,
    company: 'DevScout Cloud',
    source: 'پونیشا',
    sourceKey: 'ponisha',
    salaryOrBudget: 'توافقی',
    city: 'سراسر ایران (آنلاین)',
    workMode: 'دورکاری',
    workModeKey: 'remote',
    contractType: 'تست پوش نوتیفیکیشن',
    description: testBody,
    skills: ['Flutter', 'Firebase'],
    publishedTimeText: 'هم‌اکنون',
    publishedAt: new Date().toISOString(),
    originalUrl: 'https://ponisha.ir',
    isUrgent: false,
  };

  const message = {
    topic: 'flutter_jobs',
    notification: {
      title: testTitle,
      body: testBody,
    },
    data: buildSafeFcmData(testJob),
    android: {
      priority: 'high',
      collapseKey: 'test_cloud_push',
      notification: {
        channelId: 'job_radar_high_importance_channel',
        tag: 'test_cloud_push',
        sound: 'default',
        priority: 'max',
        visibility: 'public',
        icon: 'ic_launcher',
        clickAction: 'FLUTTER_NOTIFICATION_CLICK',
      },
    },
  };

  const response = await admin.messaging().send(message);
  console.log(`✅ [Test Push Sent] Message ID: ${response}`);
  return response;
}

module.exports = {
  initFirebase,
  sendJobPushNotification,
  sendTestPushNotification,
  buildFcmCondition,
  buildSafeFcmData,
};
