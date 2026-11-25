const test = require('node:test');
const assert = require('node:assert/strict');

const {
  buildFcmCondition,
  buildSafeFcmData,
} = require('../fcm');
const {
  refreshActiveIdsLru,
  mergeHistorySets,
  filterFreshJobsForNotification,
} = require('../index');

test('buildFcmCondition builds single condition matching role and category', () => {
  const flutterFreelance = buildFcmCondition({
    title: 'توسعه اپلیکیشن با فلاتر',
    tabCategory: 'freelance',
    isFlutter: true,
    isAndroid: false,
  });
  assert.equal(
    flutterFreelance,
    "'flutter_jobs' in topics && 'freelance_projects' in topics"
  );

  const androidEmployment = buildFcmCondition({
    title: 'Senior Android Kotlin Developer',
    tabCategory: 'employment',
    isFlutter: false,
    isAndroid: true,
  });
  assert.equal(
    androidEmployment,
    "'android_jobs' in topics && 'employment_jobs' in topics"
  );

  const bothRoles = buildFcmCondition({
    title: 'Flutter & Android Mobile Developer',
    tabCategory: 'employment',
    isFlutter: true,
    isAndroid: true,
  });
  assert.equal(
    bothRoles,
    "('flutter_jobs' in topics || 'android_jobs' in topics) && 'employment_jobs' in topics"
  );

  const generalMobile = buildFcmCondition({
    title: 'برنامه‌نویس اپلیکیشن موبایل',
    tabCategory: 'freelance',
    isFlutter: false,
    isAndroid: false,
  });
  assert.equal(
    generalMobile,
    "('flutter_jobs' in topics || 'android_jobs' in topics) && 'freelance_projects' in topics"
  );
});

test('buildSafeFcmData emits all string values and caps UTF-8 payload size', () => {
  const longDesc = 'توسعه اپلیکیشن فروشگاهی فلاتر با امکانات کامل. '.repeat(120);
  const data = buildSafeFcmData({
    id: 'ponisha_999111',
    title: 'طراحی اپلیکیشن فروشگاهی فلاتر بسیار پیشرفته',
    company: '',
    source: 'پونیشا',
    sourceKey: 'ponisha',
    salaryOrBudget: '۲۰,۰۰۰,۰۰۰ تا ۴۰,۰۰۰,۰۰۰ تومان',
    city: 'سراسر ایران (آنلاین)',
    workMode: 'دورکاری',
    workModeKey: 'remote',
    contractType: 'پروژه‌ای / فریلنسری',
    description: longDesc,
    skills: ['Flutter', 'Dart', 'Bloc', 'REST API', 'Firebase'],
    publishedAt: '2026-11-25T20:00:00.000Z',
    publishedTimeText: 'لحظاتی پیش',
    proposalsCountText: '۳ پیشنهاد ثبت شده',
    isUrgent: true,
    originalUrl: 'https://ponisha.ir/project/999111',
  });

  for (const [key, val] of Object.entries(data)) {
    assert.equal(typeof val, 'string', `Expected data.${key} to be a string`);
  }

  assert.equal(data.id, 'ponisha_999111');
  assert.equal(data.jobId, 'ponisha_999111');
  assert.equal(data.sourceKey, 'ponisha');
  assert.equal(data.workMode, 'remote');
  assert.equal(data.isUrgent, 'true');
  assert.equal(data.click_action, 'FLUTTER_NOTIFICATION_CLICK');

  const byteLen = Buffer.byteLength(JSON.stringify(data), 'utf8');
  assert.ok(
    byteLen <= 3800,
    `Expected UTF-8 payload <= 3800 bytes, got ${byteLen}`
  );
});

test('sendJobPushNotification sends exactly one FCM message with condition and tag', async (t) => {
  const prevCreds = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  const adminPath = require.resolve('firebase-admin');
  const fcmPath = require.resolve('../fcm');
  const origAdminEntry = require.cache[adminPath];
  const origFcmEntry = require.cache[fcmPath];

  const sentMessages = [];
  process.env.GOOGLE_APPLICATION_CREDENTIALS = '/tmp/mock-creds.json';
  require.cache[adminPath] = {
    id: adminPath,
    filename: adminPath,
    loaded: true,
    exports: {
      initializeApp: () => ({}),
      credential: {
        applicationDefault: () => ({}),
        cert: () => ({}),
      },
      messaging: () => ({
        send: async (msg) => {
          sentMessages.push(msg);
          return 'projects/mock/messages/1';
        },
      }),
    },
  };
  delete require.cache[fcmPath];

  t.after(() => {
    if (prevCreds === undefined) {
      delete process.env.GOOGLE_APPLICATION_CREDENTIALS;
    } else {
      process.env.GOOGLE_APPLICATION_CREDENTIALS = prevCreds;
    }
    if (origAdminEntry) {
      require.cache[adminPath] = origAdminEntry;
    } else {
      delete require.cache[adminPath];
    }
    if (origFcmEntry) {
      require.cache[fcmPath] = origFcmEntry;
    } else {
      delete require.cache[fcmPath];
    }
  });

  const { sendJobPushNotification } = require('../fcm');
  const ok = await sendJobPushNotification({
    id: 'karlancer_555001',
    title: 'پروژه فلاتر فروشگاهی',
    company: '',
    source: 'کارلنسر',
    sourceKey: 'karlancer',
    salaryOrBudget: '۳۰,۰۰۰,۰۰۰ تومان',
    city: 'سراسر ایران',
    workMode: 'دورکاری',
    workModeKey: 'remote',
    tabCategory: 'freelance',
    isFlutter: true,
    isAndroid: false,
    originalUrl: 'https://www.karlancer.com/projects/555001',
    publishedAt: '2026-11-25T20:00:00.000Z',
  });

  assert.equal(ok, true);
  assert.equal(sentMessages.length, 1);

  const msg = sentMessages[0];
  assert.equal(msg.topic, undefined);
  assert.equal(
    msg.condition,
    "'flutter_jobs' in topics && 'freelance_projects' in topics"
  );
  assert.equal(msg.android.collapseKey, 'karlancer_555001');
  assert.equal(msg.android.notification.tag, 'karlancer_555001');
  assert.equal(msg.data.id, 'karlancer_555001');
  assert.equal(msg.data.title, 'پروژه فلاتر فروشگاهی');
});

test('history LRU refresh, merge, and freshness filter prevent re-notification', () => {
  const history = new Set(['old_1', 'active_1', 'old_2']);
  refreshActiveIdsLru(history, ['active_1']);
  assert.deepEqual(Array.from(history), ['old_1', 'old_2', 'active_1']);

  const merged = mergeHistorySets(new Set(['local_1', 'shared']), [
    'remote_1',
    'shared',
  ]);
  assert.deepEqual(Array.from(merged), ['remote_1', 'local_1', 'shared']);

  const nowMs = Date.parse('2026-11-25T20:00:00.000Z');
  const fresh = filterFreshJobsForNotification(
    [
      { id: 'fresh_job', publishedAt: '2026-11-25T18:00:00.000Z' },
      { id: 'old_job', publishedAt: '2026-11-01T18:00:00.000Z' },
      { id: 'no_date_job' },
    ],
    72,
    nowMs
  );
  assert.deepEqual(
    fresh.map((j) => j.id),
    ['fresh_job', 'no_date_job']
  );
});
