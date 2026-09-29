const test = require('node:test');
const assert = require('node:assert/strict');
const {
  mapAssignment, diffRows, resolveStatus, stripHtml,
} = require('../canvasMap');
const { normalizeDomain, nextLink } = require('../canvasApi');
const { partitionChanges } = require('../calendarEvents');
const { buildGoogleEvent } = require('../eventBuilder');
const { eventIdFor, toGoogleEvent } = require('../canvasCalendar');

const course = { id: 7, name: 'Intro to Systems', course_code: 'COS10004' };
const NOW = new Date('2026-09-29T00:00:00Z');
const raw = (over = {}) => ({
  id: 1, name: 'Essay', due_at: '2026-10-05T13:59:00Z', points_possible: 20,
  description: '<p>Write &amp; submit</p>', html_url: 'https://x/1', ...over,
});

test('mapAssignment: maps fields and derives status', () => {
  const r = mapAssignment(raw(), course, 'u1', NOW);
  assert.equal(r.id, '1');
  assert.equal(r.course_id, '7');
  assert.equal(r.description, 'Write & submit');
  assert.equal(r.status, 'upcoming');
  assert.equal(r.due_date, 'Oct 5, 2026');
});

test('resolveStatus covers every branch', () => {
  assert.equal(resolveStatus({ graded: true }, NOW), 'graded');
  assert.equal(resolveStatus({ submitted: true }, NOW), 'submitted');
  assert.equal(resolveStatus({ dueAt: '2026-09-28T00:00:00Z' }, NOW), 'overdue');
  assert.equal(resolveStatus({ dueAt: '2026-09-30T00:00:00Z' }, NOW), 'due_soon');
  assert.equal(resolveStatus({ dueAt: null }, NOW), 'upcoming');
});

test('content hash ignores time-dependent status but tracks real changes', () => {
  const a = mapAssignment(raw(), course, 'u1', NOW);
  const later = mapAssignment(raw(), course, 'u1', new Date('2026-10-06T00:00:00Z'));
  assert.notEqual(a.status, later.status);
  assert.equal(a.content_hash, later.content_hash);
  const moved = mapAssignment(raw({ due_at: '2026-10-09T13:59:00Z' }), course, 'u1', NOW);
  assert.notEqual(a.content_hash, moved.content_hash);
});

test('diffRows: added / updated / removed, and protects failed groups', () => {
  const stored = [
    { id: '1', course_id: '7', content_hash: 'same' },
    { id: '2', course_id: '7', content_hash: 'old' },
    { id: '3', course_id: '7', content_hash: 'gone' },
    { id: '4', course_id: '9', content_hash: 'in failed course' },
  ];
  const fresh = [
    { id: '1', content_hash: 'same' },
    { id: '2', content_hash: 'new' },
    { id: '5', content_hash: 'brand new' },
  ];
  const d = diffRows(fresh, stored, new Set(['9']), (r) => r.course_id);
  assert.deepEqual(d.added.map((r) => r.id), ['5']);
  assert.deepEqual(d.updated.map((r) => r.id), ['2']);
  assert.deepEqual(d.removed.map((r) => r.id), ['3']); // '4' protected
});

test('normalizeDomain: accepts instructure, rejects everything else', () => {
  assert.equal(normalizeDomain('https://Swinburne.instructure.com/'), 'swinburne.instructure.com');
  assert.throws(() => normalizeDomain('evil.example.com'));
  assert.throws(() => normalizeDomain('169.254.169.254'));
  assert.throws(() => normalizeDomain('instructure.com.evil.io'));
  assert.throws(() => normalizeDomain('localhost'));
});

test('nextLink parses Canvas Link headers', () => {
  const h = '<https://a/api/v1/x?page=1>; rel="current", <https://a/api/v1/x?page=2>; rel="next"';
  assert.equal(nextLink(h), 'https://a/api/v1/x?page=2');
  assert.equal(nextLink('<https://a>; rel="last"'), null);
});

test('stripHtml', () => assert.equal(stripHtml('<b>a</b>&nbsp;&lt;b&gt;'), 'a <b>'));

test('partitionChanges: keeps wall-clock time, separates deletions', () => {
  const { upserts, deletedIds } = partitionChanges([
    { id: 'a', summary: 'COS10004 Lecture', start: { dateTime: '2026-09-29T09:30:00+10:00' }, end: { dateTime: '2026-09-29T11:00:00+10:00' } },
    { id: 'b', status: 'cancelled' },
    { id: 'c', summary: 'Holiday', start: { date: '2026-10-01' }, end: { date: '2026-10-02' } },
  ], 'u1');
  assert.deepEqual(deletedIds, ['b']);
  assert.equal(upserts[0].start_time, '09:30');
  assert.equal(upserts[0].end_time, '11:00');
  assert.equal(upserts[0].course_code, 'COS10004');
  assert.equal(upserts[1].is_all_day, true);
});

test('buildGoogleEvent: all-day end is exclusive', () => {
  const e = buildGoogleEvent({ title: 'x', date: '2026-10-31', is_all_day: true });
  assert.equal(e.end.date, '2026-11-01');
});

test('canvas calendar event ids are deterministic and Google-valid', () => {
  const id = eventIdFor('u1', '42');
  assert.equal(id, eventIdFor('u1', '42'));
  assert.match(id, /^[a-v0-9]{5,1024}$/);
  assert.notEqual(id, eventIdFor('u1', '43'));
});

test('toGoogleEvent ends at the deadline and marks submitted work', () => {
  const ev = toGoogleEvent({ id: '1', title: 'Essay', course_code: 'COS1', due_at: '2026-10-05T14:00:00.000Z', submitted: true, points: 10 });
  assert.equal(ev.end.dateTime, '2026-10-05T14:00:00.000Z');
  assert.equal(ev.start.dateTime, '2026-10-05T13:30:00.000Z');
  assert.ok(ev.summary.startsWith('✓ COS1: Essay'));
});

test('buildGoogleEvent: timed events carry the client utc offset', () => {
  const e = buildGoogleEvent({ title: 'x', date: '2026-10-01', start_time: '09:00', end_time: '10:30', utc_offset: '+10:00' });
  assert.equal(e.start.dateTime, '2026-10-01T09:00:00+10:00');
  assert.equal(e.end.dateTime, '2026-10-01T10:30:00+10:00');
  const bad = buildGoogleEvent({ title: 'x', date: '2026-10-01', start_time: '09:00', utc_offset: 'evil' });
  assert.equal(bad.start.dateTime, '2026-10-01T09:00:00Z');
});
