/**
 * اسکریپت بک‌اند / کرون‌جاب اسکرپر و ارسال‌کننده نوتیفیکیشن آنی فایربیس (FCM)
 * قابل اجرا روی: GitHub Actions (رایگان)، Firebase Cloud Functions یا هر سرور Node.js
 *
 * وظیفه:
 * ۱. اسکرپ دوره‌ای پونیشا، کارلنسر، جابینجا و جاب‌ویژن برای آگهی‌های فلاتر، اندروید و ساخت اپلیکیشن
 * ۲. ارسال پوش نوتیفیکیشن آنی به تاپیک‌های اپلیکیشن اندروید (flutter_jobs, android_jobs, freelance_projects, employment_jobs)
 * ۳. ارسال لینک مستقیم آگهی (url) در بخش data تا با ضربه روی نوتیفیکیشن، دیپ‌لینک به سایت اصلی باز شود.
 */

const admin = require('firebase-admin');
const axios = require('axios');
const cheerio = require('cheerio');

// بارگذاری کلید سرویس اکانت فایربیس از متغیر محیطی یا فایل
// export GOOGLE_APPLICATION_CREDENTIALS="./serviceAccountKey.json"
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
});

const HEADERS = {
  'User-Agent':
    'Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36',
  'Accept-Language': 'fa-IR,fa;q=0.9,en;q=0.8',
};

async function scrapeJobinja() {
  const jobs = [];
  const url =
    'https://jobinja.ir/jobs?filters%5Bkeywords%5D%5B0%5D=flutter&sort_by=published_at_desc';
  const { data } = await axios.get(url, { headers: HEADERS, timeout: 10000 });
  const $ = cheerio.load(data);

  $('.o-listView__item, .c-jobListView__item').each((_, el) => {
    const titleEl = $(el).find('a.c-jobListView__titleLink').first();
    const title = titleEl.text().trim();
    const href = titleEl.attr('href');
    if (title && href) {
      const meta = $(el)
        .find('.c-jobListView__metaItem')
        .map((i, m) => $(m).text().trim())
        .get();
      jobs.push({
        id: `jobinja_${Buffer.from(href).toString('base64').slice(0, 16)}`,
        title,
        company: meta[0] || 'شرکت در جابینجا',
        city: meta[1] || 'تهران',
        salary: meta[2] || 'توافقی',
        source: 'جابینجا',
        topic: 'employment_jobs',
        url: href.startsWith('http') ? href : `https://jobinja.ir${href}`,
      });
    }
  });
  return jobs;
}

async function scrapeKarlancer() {
  const jobs = [];
  const url = 'https://www.karlancer.com/search?q=' + encodeURIComponent('فلاتر');
  const { data } = await axios.get(url, { headers: HEADERS, timeout: 10000 });
  const $ = cheerio.load(data);

  $('a[href*="/project/"]').each((_, el) => {
    const title = $(el).text().trim();
    const href = $(el).attr('href');
    if (title.length > 5 && href) {
      jobs.push({
        id: `karlancer_${Buffer.from(href).toString('base64').slice(0, 16)}`,
        title,
        company: 'کارفرمای کارلنسر',
        city: 'دورکاری',
        salary: 'بودجه توافقی',
        source: 'کارلنسر',
        topic: 'freelance_projects',
        url: href.startsWith('http') ? href : `https://www.karlancer.com${href}`,
      });
    }
  });
  return jobs;
}

async function sendFcmNotification(job) {
  const message = {
    topic: job.topic,
    notification: {
      title: `🔔 آگهی جدید در ${job.source}: ${job.title}`,
      body: `🏢 ${job.company} | 📍 ${job.city} | 💰 ${job.salary}`,
    },
    data: {
      id: job.id,
      url: job.url,
      source: job.source,
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
    },
    android: {
      priority: 'high',
      notification: {
        channelId: 'job_radar_high_importance_channel',
        clickAction: 'FLUTTER_NOTIFICATION_CLICK',
      },
    },
  };

  const response = await admin.messaging().send(message);
  console.log(`FCM Sent for ${job.title}:`, response);
}

async function run() {
  try {
    const [jobinjaJobs, karlancerJobs] = await Promise.allSettled([
      scrapeJobinja(),
      scrapeKarlancer(),
    ]);

    const all = [
      ...(jobinjaJobs.status === 'fulfilled' ? jobinjaJobs.value.slice(0, 2) : []),
      ...(karlancerJobs.status === 'fulfilled' ? karlancerJobs.value.slice(0, 2) : []),
    ];

    for (const job of all) {
      await sendFcmNotification(job);
    }
  } catch (err) {
    console.error('Worker error:', err);
  }
}

run();
