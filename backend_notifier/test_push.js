/**
 * اسکریپت تست سریع ارسال نوتیفیکیشن پوش فایربیس
 * نحوه اجرا:
 * node backend_notifier/test_push.js
 */

const { sendTestPushNotification } = require('./fcm');

async function run() {
  console.log('🚀 در حال ارسال نوتیفیکیشن تستی فایربیس به تمام گوشی‌های متصل (اپ‌های بسته)...');
  try {
    const res = await sendTestPushNotification({
      title: '🔔 اعلان تستی DevScout (پوش ابری مثل تلگرام)',
      body: 'اگر این پیام را در زمان بسته بودن اپلیکیشن مشاهده می‌کنید، اتصال سرور فایربیس و سیستم اعلان آنی ۱۰۰٪ موفقیت‌آمیز است!',
    });
    console.log('✅ نوتیفیکیشن تستی با موفقیت ارسال شد!');
    console.log('شناسه پیام فایربیس:', res);
  } catch (err) {
    console.error('❌ خطا در ارسال:', err.message);
    console.log('\nنکته: برای اتصال به فایربیس:');
    console.log('۱. فایل serviceAccountKey.json را در پوشه backend_notifier قرار دهید.');
    console.log('۲. یا متغیر FIREBASE_SERVICE_ACCOUNT_KEY را تنظیم نمایید.');
  }
}

run();
