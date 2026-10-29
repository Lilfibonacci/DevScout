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
      console.log('✅ Firebase Admin initialized from FIREBASE_SERVICE_ACCOUNT_KEY env var.');
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
 * ارسال پیام پوش آنی به تاپیک
 */
async function sendJobPushNotification(job) {
  if (!initFirebase()) {
    console.log(
      `[MOCK PUSH] آگهی آماده ارسال بود ولی فایربیس تنظیم نشده است: "${job.title}" (${job.source})`
    );
    return false;
  }

  // انتخاب تاپیک اصلی
  const mainTopic = job.topic || 'flutter_jobs';
  const categoryTopic =
    job.tabCategory === 'freelance'
      ? 'freelance_projects'
      : 'employment_jobs';

  // ساخت بدنه اعلان
  const title = `🔔 ${job.source}: ${job.title}`;
  const body = job.company
    ? `🏢 ${job.company} | 📍 ${job.city} (${job.workMode})\n💰 ${job.salaryOrBudget}`
    : `📍 ${job.city} (${job.workMode}) | 💰 ${job.salaryOrBudget}`;

  const message = {
    // ارسال به تاپیک مربوطه
    topic: mainTopic,
    notification: {
      title,
      body,
    },
    data: {
      id: String(job.id),
      jobId: String(job.id),
      url: String(job.originalUrl),
      source: String(job.source),
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
    },
    android: {
      priority: 'high',
      notification: {
        channelId: 'job_radar_high_importance_channel',
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
    console.log(`🚀 [FCM Push Sent] -> Topic: ${mainTopic} | ID: ${job.id} | Response: ${response}`);

    // همچنین به تاپیک دسته‌بندی فریلنسری / استخدامی هم فرستاده شود
    if (categoryTopic && categoryTopic !== mainTopic) {
      const catMessage = { ...message, topic: categoryTopic };
      await admin.messaging().send(catMessage);
    }

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

  const message = {
    topic: 'flutter_jobs',
    notification: {
      title: title || '🔔 تست اعلان DevScout مثل تلگرام (اپ بسته است)',
      body:
        body ||
        'این اعلان از طریق سرور ابری فایربیس و بدون مصرف باتری ارسال شده است. ضربه بزنید تا برنامه باز شود!',
    },
    data: {
      jobId: 'test_cloud_push',
      url: 'https://ponisha.ir',
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
    },
    android: {
      priority: 'high',
      notification: {
        channelId: 'job_radar_high_importance_channel',
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
};
