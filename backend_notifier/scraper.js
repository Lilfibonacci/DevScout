/**
 * ماژول اسکرپر سرور ابری DevScout
 * اسکرپ هم‌زمان و مطمئن ۴ سایت: پونیشا، کارلنسر، جابینجا و جاب‌ویژن
 */

const axios = require('axios');
const cheerio = require('cheerio');
const https = require('https');

const HEADERS = {
  'User-Agent':
    'Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36',
  'Accept':
    'text/html,application/xhtml+xml,application/xml;q=0.9,application/json,*/*;q=0.8',
  'Accept-Language': 'fa-IR,fa;q=0.9,en-US;q=0.8,en;q=0.7',
};

// حل مشکل گواهی SSL برای سرور کاندیدای جاب‌ویژن (Certum CA)
const insecureHttpsAgent = new https.Agent({
  rejectUnauthorized: false,
});

const MOBILE_KEYWORDS = [
  'flutter',
  'فلاتر',
  'dart',
  'دارت',
  'android',
  'اندروید',
  'kotlin',
  'کاتلین',
  'mobile',
  'موبایل',
  'اپلیکیشن',
  'ساخت اپ',
  'توسعه اپ',
  'react native',
  'ری اکت نیتیو',
  'ios',
];

function isRelevantMobileJob(title) {
  const lower = (title || '').toLowerCase();
  return MOBILE_KEYWORDS.some((kw) => lower.includes(kw));
}

function cleanText(text) {
  if (!text) return '';
  return text.replace(/\s+/g, ' ').trim();
}

function formatToman(num) {
  if (!num || isNaN(num)) return '';
  return Number(num).toLocaleString('fa-IR');
}

/**
 * ۱. پونیشا (Ponisha.ir)
 */
async function scrapePonisha() {
  const jobs = [];
  const queries = ['flutter', 'android'];

  for (const q of queries) {
    try {
      const url = `https://ponisha.ir/search/projects?query=${encodeURIComponent(q)}`;
      const { data: html } = await axios.get(url, {
        headers: HEADERS,
        timeout: 12000,
      });

      const $ = cheerio.load(html);
      const nextDataScript = $('script#__NEXT_DATA__').html();
      if (!nextDataScript) continue;

      const nextData = JSON.parse(nextDataScript);
      const queriesList =
        nextData.props?.pageProps?.dehydratedState?.queries || [];

      for (const queryObj of queriesList) {
        const stateData = queryObj.state?.data;
        if (stateData && Array.isArray(stateData.data)) {
          for (const item of stateData.data) {
            const id = `ponisha_${item.id}`;
            if (jobs.some((j) => j.id === id)) continue;

            const title = cleanText(item.title);
            if (!title) continue;

            const minAmount = item.amount_min;
            const maxAmount = item.amount_max;
            let budget = 'بودجه توافقی';
            if (minAmount && maxAmount && maxAmount > 0) {
              budget = `${formatToman(minAmount)} تا ${formatToman(maxAmount)} تومان`;
            }

            const slug = item.slug || '';
            const originalUrl = slug
              ? `https://ponisha.ir/project/${item.id}/${encodeURIComponent(slug)}`
              : `https://ponisha.ir/project/${item.id}`;

            const isFlutter =
              title.toLowerCase().includes('flutter') ||
              title.toLowerCase().includes('فلاتر');

            jobs.push({
              id,
              title,
              company: '',
              source: 'پونیشا',
              salaryOrBudget: budget,
              city: 'سراسر ایران (آنلاین)',
              workMode: 'دورکاری',
              tabCategory: 'freelance',
              topic: isFlutter ? 'flutter_jobs' : 'android_jobs',
              originalUrl,
              publishedAt: item.approved_at
                ? new Date(item.approved_at).toISOString()
                : new Date().toISOString(),
            });
          }
        }
      }
    } catch (err) {
      console.warn(`[Ponisha Scrape Warning for ${q}]:`, err.message);
    }
  }

  return jobs;
}

/**
 * ۲. کارلنسر (Karlancer.com)
 */
async function scrapeKarlancer() {
  const jobs = [];
  const queries = ['flutter', 'اندروید'];

  for (const q of queries) {
    try {
      const url = `https://www.karlancer.com/search?q=${encodeURIComponent(q)}`;
      const { data: html } = await axios.get(url, {
        headers: HEADERS,
        timeout: 12000,
      });

      const $ = cheerio.load(html);
      const ngStateScript = $('script#ng-state').html();
      if (!ngStateScript) continue;

      const ngState = JSON.parse(ngStateScript);

      for (const key of Object.keys(ngState)) {
        if (key === '__nghData__') continue;
        const projectsObj = ngState[key]?.b?.data?.projects;
        if (projectsObj && Array.isArray(projectsObj.data)) {
          for (const raw of projectsObj.data) {
            if (raw.is_expired) continue;
            const id = `karlancer_${raw.id}`;
            if (jobs.some((j) => j.id === id)) continue;

            const title = cleanText(raw.title);
            if (!title) continue;

            let budget = 'بودجه توافقی';
            if (raw.min_budget && raw.max_budget) {
              budget = `${formatToman(raw.min_budget)} تا ${formatToman(raw.max_budget)} تومان`;
            }

            const city = raw.country || 'سراسر ایران';
            const isOnsite = raw.is_onsite === true;
            const slug = raw.url || '';
            const originalUrl = slug
              ? `https://www.karlancer.com/projects/${encodeURIComponent(slug)}`
              : `https://www.karlancer.com/search?q=flutter`;

            const isFlutter =
              title.toLowerCase().includes('flutter') ||
              title.toLowerCase().includes('فلاتر');

            jobs.push({
              id,
              title,
              company: '',
              source: 'کارلنسر',
              salaryOrBudget: budget,
              city,
              workMode: isOnsite ? 'حضوری' : 'دورکاری',
              tabCategory: 'freelance',
              topic: isFlutter ? 'flutter_jobs' : 'android_jobs',
              originalUrl,
              publishedAt: raw.ladder_at || new Date().toISOString(),
            });
          }
        }
      }
    } catch (err) {
      console.warn(`[Karlancer Scrape Warning for ${q}]:`, err.message);
    }
  }

  return jobs;
}

/**
 * ۳. جابینجا (Jobinja.ir)
 */
const JOBINJA_HEADERS = {
  'User-Agent':
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36',
  'Accept':
    'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
  'Accept-Language': 'fa,en-US;q=0.9,en;q=0.8',
  'Cache-Control': 'no-cache',
  'Pragma': 'no-cache',
  'Sec-Ch-Ua': '"Google Chrome";v="129", "Not=A?Brand";v="8", "Chromium";v="129"',
  'Sec-Ch-Ua-Mobile': '?0',
  'Sec-Ch-Ua-Platform': '"Windows"',
  'Sec-Fetch-Dest': 'document',
  'Sec-Fetch-Mode': 'navigate',
  'Sec-Fetch-Site': 'none',
  'Sec-Fetch-User': '?1',
  'Upgrade-Insecure-Requests': '1',
};

async function scrapeJobinja() {
  const jobs = [];
  const keywords = ['flutter', 'android'];

  for (const kw of keywords) {
    try {
      const url = `https://jobinja.ir/jobs?filters%5Bkeywords%5D%5B0%5D=${encodeURIComponent(kw)}&sort_by=published_at_desc`;
      const { data: html } = await axios.get(url, {
        headers: JOBINJA_HEADERS,
        timeout: 12000,
      });

      const $ = cheerio.load(html);
      $('.o-listView__item, .c-jobListView__item').each((_, el) => {
        const titleLink = $(el).find('a.c-jobListView__titleLink').first();
        if (!titleLink.length) return;

        const rawTitle = cleanText(titleLink.text());
        const passedTime = cleanText(
          $(el).find('.c-jobListView__passedDays').first().text() || ''
        );
        const title = rawTitle.replace(passedTime, '').trim();
        const href = titleLink.attr('href') || '';
        if (!title || !href) return;

        const cleanHref = href.split('?')[0];
        const id = `jobinja_${Buffer.from(cleanHref).toString('base64').replace(/[^a-zA-Z0-9]/g, '').slice(0, 16)}`;
        if (jobs.some((j) => j.id === id)) return;

        const metaItems = $(el)
          .find('.c-jobListView__metaItem')
          .map((i, m) => cleanText($(m).text()))
          .get()
          .filter(Boolean);

        const company = metaItems[0] || 'شرکت معتبر در جابینجا';
        const city = metaItems[1] || 'تهران';
        const contractRaw = metaItems[2] || 'تمام‌وقت';

        const isRemote =
          title.includes('دورکار') ||
          contractRaw.includes('دورکار') ||
          title.toLowerCase().includes('remote');

        const originalUrl = href.startsWith('http')
          ? href
          : `https://jobinja.ir${href}`;

        const isFlutter =
          title.toLowerCase().includes('flutter') ||
          title.toLowerCase().includes('فلاتر');

        jobs.push({
          id,
          title,
          company,
          source: 'جابینجا',
          salaryOrBudget: 'توافقی',
          city,
          workMode: isRemote ? 'دورکاری' : 'حضوری',
          tabCategory: 'employment',
          topic: isFlutter ? 'flutter_jobs' : 'android_jobs',
          originalUrl,
          publishedAt: new Date().toISOString(),
        });
      });
    } catch (err) {
      console.warn(`[Jobinja Scrape Warning for ${kw}]:`, err.message);
    }
  }

  return jobs;
}

/**
 * ۴. جاب‌ویژن (JobVision.ir)
 */
async function scrapeJobVision() {
  const jobs = [];
  const keywords = ['flutter', 'اندروید'];

  for (const kw of keywords) {
    try {
      const response = await axios.post(
        'https://candidateapi.jobvision.ir/api/v1/JobPost/List',
        {
          page: 1,
          pageSize: 30,
          keyword: kw,
          sortBy: 0,
        },
        {
          headers: {
            ...HEADERS,
            'Content-Type': 'application/json',
            'Origin': 'https://jobvision.ir',
            'Referer': 'https://jobvision.ir/',
          },
          httpsAgent: insecureHttpsAgent,
          timeout: 12000,
        }
      );

      const jobPosts = response.data?.data?.jobPosts || [];
      for (const raw of jobPosts) {
        const id = `jobvision_${raw.id}`;
        if (jobs.some((j) => j.id === id)) continue;

        const title = cleanText(raw.title);
        if (!title) continue;
        if (!isRelevantMobileJob(title)) continue;

        const company =
          raw.company?.nameFa ||
          raw.company?.nameEn ||
          'شرکت معتبر در جاب‌ویژن';

        const cityFa =
          raw.location?.city?.titleFa ||
          raw.location?.province?.titleFa ||
          'تهران';

        const isRemote = raw.properties?.isRemote === true;
        const salaryText =
          raw.salary?.titleFa || (typeof raw.salary === 'string' ? raw.salary : 'توافقی');

        const isFlutter =
          title.toLowerCase().includes('flutter') ||
          title.toLowerCase().includes('فلاتر');

        jobs.push({
          id,
          title,
          company,
          source: 'جاب‌ویژن',
          salaryOrBudget: salaryText,
          city: cityFa,
          workMode: isRemote ? 'دورکاری' : 'حضوری',
          tabCategory: 'employment',
          topic: isFlutter ? 'flutter_jobs' : 'android_jobs',
          originalUrl: `https://jobvision.ir/jobs/${raw.id}`,
          publishedAt: raw.activationTime?.date || new Date().toISOString(),
        });
      }
    } catch (err) {
      console.warn(`[JobVision Scrape Warning for ${kw}]:`, err.message);
    }
  }

  return jobs;
}

/**
 * اجرای هم‌زمان تمام اسکرپرها
 */
async function scrapeAll() {
  const [ponisha, karlancer, jobinja, jobvision] = await Promise.allSettled([
    scrapePonisha(),
    scrapeKarlancer(),
    scrapeJobinja(),
    scrapeJobVision(),
  ]);

  const all = [
    ...(ponisha.status === 'fulfilled' ? ponisha.value : []),
    ...(karlancer.status === 'fulfilled' ? karlancer.value : []),
    ...(jobinja.status === 'fulfilled' ? jobinja.value : []),
    ...(jobvision.status === 'fulfilled' ? jobvision.value : []),
  ];

  // حذف شناسه‌های تکراری و مرتب‌سازی جدیدترین به قدیمی‌ترین
  const unique = [];
  const seen = new Set();
  for (const j of all) {
    if (!seen.has(j.id)) {
      seen.add(j.id);
      unique.push(j);
    }
  }

  unique.sort(
    (a, b) => new Date(b.publishedAt).getTime() - new Date(a.publishedAt).getTime()
  );

  return unique;
}

module.exports = {
  scrapeAll,
  scrapePonisha,
  scrapeKarlancer,
  scrapeJobinja,
  scrapeJobVision,
};
