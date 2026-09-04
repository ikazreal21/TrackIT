const COLORS = {
    teal: '#2FE0A8',
    orange: '#F6915A',
    peri: '#8B93B8',
    ringBlue: '#7C8CF8',
    green: '#4ADE80',
    track: 'rgba(255, 255, 255, 0.15)',
    tealDim: 'rgba(47, 224, 168, 0.12)',
    orangeDim: 'rgba(246, 145, 90, 0.12)',
    periDim: 'rgba(139, 147, 184, 0.14)',
    blueDim: 'rgba(124, 140, 248, 0.12)',
};

const TYPE_COLORS = {
    HEART_RATE: COLORS.orange,
    STEPS: COLORS.teal,
    DISTANCE_DELTA: COLORS.ringBlue,
    ACTIVE_ENERGY_BURNED: COLORS.orange,
    TOTAL_CALORIES_BURNED: COLORS.orange,
    BASAL_ENERGY_BURNED: COLORS.orange,
    SLEEP_SESSION: COLORS.peri,
    SLEEP_ASLEEP: COLORS.peri,
    SLEEP_LIGHT: COLORS.peri,
    SLEEP_DEEP: '#3F4A9E',
    SLEEP_REM: '#6C7BD6',
    SLEEP_AWAKE: '#E8EAF2',
    WEIGHT: COLORS.teal,
    HEIGHT: '#7A7A84',
};

const TYPE_LABELS = {
    HEART_RATE: 'Heart rate',
    STEPS: 'Steps',
    DISTANCE_DELTA: 'Distance',
    ACTIVE_ENERGY_BURNED: 'Active calories',
    TOTAL_CALORIES_BURNED: 'Total calories',
    BASAL_ENERGY_BURNED: 'Basal calories',
    SLEEP_SESSION: 'Sleep',
    SLEEP_ASLEEP: 'Asleep',
    SLEEP_LIGHT: 'Light',
    SLEEP_DEEP: 'Deep',
    SLEEP_REM: 'REM',
    SLEEP_AWAKE: 'Awake',
    WEIGHT: 'Weight',
    HEIGHT: 'Height',
};

const STAGE_ORDER = ['SLEEP_AWAKE', 'SLEEP_LIGHT', 'SLEEP_REM', 'SLEEP_DEEP', 'SLEEP_ASLEEP'];
const SLEEP_TYPES = ['SLEEP_SESSION', 'SLEEP_ASLEEP', 'SLEEP_LIGHT', 'SLEEP_DEEP', 'SLEEP_REM', 'SLEEP_AWAKE'];

let currentRange = 'week';
let charts = {};

function localISODate(d) {
    const m = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return d.getFullYear() + '-' + m + '-' + day;
}

function parseLocalDate(s) {
    const parts = s.split('-').map(Number);
    return new Date(parts[0], parts[1] - 1, parts[2]);
}

function shiftISO(days) {
    const d = new Date();
    d.setDate(d.getDate() + days);
    return localISODate(d);
}

const TZ_MIN = -new Date().getTimezoneOffset();

document.getElementById('rangeSelector').addEventListener('click', (e) => {
    const btn = e.target.closest('.range-btn');
    if (!btn) return;
    document.querySelectorAll('.range-btn').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    currentRange = btn.dataset.range;
    document.getElementById('datePickerGroup').hidden = currentRange !== 'custom';
    if (currentRange === 'custom') initDatePickers();
    loadDashboard();
});

function initDatePickers() {
    const startInput = document.getElementById('startDate');
    const endInput = document.getElementById('endDate');
    if (!startInput.value) {
        const now = new Date();
        const weekAgo = new Date(now);
        weekAgo.setDate(weekAgo.getDate() - 6);
        startInput.value = localISODate(weekAgo);
        endInput.value = localISODate(now);
    }
    startInput.onchange = () => loadDashboard();
    endInput.onchange = () => loadDashboard();
}

function getDateRange(range) {
    const now = new Date();
    const end = localISODate(now);
    let start;
    if (range === 'day') {
        start = end;
    } else if (range === 'week') {
        const d = new Date(now);
        d.setDate(d.getDate() - 6);
        start = localISODate(d);
    } else if (range === 'month') {
        const d = new Date(now);
        d.setDate(d.getDate() - 29);
        start = localISODate(d);
    } else if (range === 'custom') {
        start = document.getElementById('startDate').value || end;
        return { start, end: document.getElementById('endDate').value || end };
    }
    return { start, end };
}

function getBucket(range) {
    if (range === 'day') return 'hour';
    return 'day';
}

function chartDefaults() {
    return {
        responsive: true,
        maintainAspectRatio: false,
        animation: { duration: 600, easing: 'easeOutQuart' },
        plugins: {
            legend: { display: false },
            tooltip: {
                backgroundColor: '#F2F2F4',
                titleColor: '#141417',
                bodyColor: '#141417',
                borderColor: 'rgba(0,0,0,0.15)',
                borderWidth: 1,
                cornerRadius: 8,
                padding: 10,
                titleFont: { family: "'Space Grotesk'", weight: '600', size: 12 },
                bodyFont: { family: "'JetBrains Mono'", size: 11 },
                displayColors: true,
                boxPadding: 4,
                callbacks: {
                    label: function(ctx) {
                        const val = ctx.parsed.y;
                        return ctx.dataset.label + ': ' + (Math.round(val * 10) / 10).toLocaleString();
                    }
                }
            },
        },
        scales: {
            x: {
                ticks: { color: '#7A7A84', font: { family: "'JetBrains Mono'", size: 10 }, maxTicksLimit: 8 },
                grid: { display: false },
                border: { display: false },
            },
            y: {
                ticks: {
                    color: '#7A7A84',
                    font: { family: "'JetBrains Mono'", size: 10 },
                    maxTicksLimit: 5,
                    callback: function(val) { return Math.round(val * 10) / 10; }
                },
                grid: { color: 'rgba(255,255,255,0.06)', drawBorder: false },
                border: { display: false },
            },
        },
    };
}

function legendLabels() {
    return {
        color: '#7A7A84',
        font: { family: "'Space Grotesk'", size: 11 },
        boxWidth: 12,
        boxHeight: 12,
        padding: 16,
        usePointStyle: true,
        pointStyle: 'circle',
    };
}

function sleepScore(hours) {
    if (hours == null || hours <= 0) return null;
    if (hours > 9) return Math.max(0, Math.min(100, 100 - (hours - 9) * 15));
    return Math.max(0, Math.min(100, hours / 8 * 100));
}

function strainScore(steps, activeCal) {
    if (!steps && !activeCal) return null;
    return Math.max(0, Math.min(100, steps / 12000 * 60 + activeCal / 600 * 40));
}

function recoveryScore(sleep, strain) {
    if (sleep == null && strain == null) return null;
    if (sleep == null) return Math.max(0, Math.min(100, 100 - strain));
    if (strain == null) return sleep;
    return Math.max(0, Math.min(100, sleep * 0.65 + (100 - strain) * 0.35));
}

function deltaPct(current, baseline) {
    if (current == null || baseline == null || baseline === 0) return null;
    return (current - baseline) / baseline * 100;
}

function bandFor(score) {
    if (score >= 85) return 'Optimal';
    if (score >= 70) return 'Good';
    if (score >= 55) return 'Fair';
    return 'Poor';
}

function sleepInsight(score) {
    if (score == null) return 'No sleep recorded yet.';
    if (score >= 85) return 'Your sleep quality was excellent last night. Keep up your good sleep habits.';
    if (score >= 70) return 'Solid night. A slightly earlier bedtime could push this higher.';
    if (score >= 55) return 'Below your usual. Watch late screens and caffeine today.';
    return 'Rough night. Prioritize an early bedtime to recover.';
}

function strainInsight(score) {
    if (score == null) return 'No activity recorded yet.';
    if (score >= 85) return 'Big day of training. Fuel up and sleep well tonight.';
    if (score >= 70) return 'Strong output today. Keep the momentum going.';
    if (score >= 55) return 'Moderate day. A walk or short session fits well.';
    return 'Your strain level is low today. Consider taking it easy and prioritize recovery.';
}

function gaugeSVG(value01, color) {
    const dash = value01 == null ? '0 100' : (75 * Math.max(0, Math.min(1, value01))).toFixed(1) + ' 100';
    return '<svg viewBox="0 0 200 200" width="190" height="190">'
        + '<circle cx="100" cy="100" r="80" fill="none" stroke="rgba(255,255,255,0.15)" stroke-width="13" stroke-linecap="round" pathLength="100" stroke-dasharray="75 100" transform="rotate(135 100 100)"/>'
        + '<circle cx="100" cy="100" r="80" fill="none" stroke="' + color + '" stroke-width="13" stroke-linecap="round" pathLength="100" stroke-dasharray="' + dash + '" transform="rotate(135 100 100)"/>'
        + '</svg>';
}

function gaugeCenter(score, delta, color) {
    const scoreHtml = score == null
        ? '<div class="gauge-score" style="color:#7A7A84">--</div>'
        : '<div class="gauge-score" style="color:' + color + '">' + Math.round(score) + '</div>';
    const deltaHtml = delta == null ? '' :
        '<div class="gauge-delta">' + (delta >= 0 ? '&#8593;' : '&#8595;') + ' ' + Math.abs(Math.round(delta)) + '%</div>'
        + '<div class="gauge-cap">vs 7-day avg</div>';
    return '<div class="gauge-center">' + scoreHtml + deltaHtml + '</div>';
}

function ringsSVG(sleep, strain, recovery) {
    const ring = (r, v, color) => {
        const dash = v == null ? '0 100' : (100 * Math.max(0, Math.min(1, v))).toFixed(1) + ' 100';
        return '<circle cx="75" cy="75" r="' + r + '" fill="none" stroke="rgba(255,255,255,0.15)" stroke-width="11" stroke-linecap="round" pathLength="100" stroke-dasharray="100 100" transform="rotate(-90 75 75)"/>'
            + '<circle cx="75" cy="75" r="' + r + '" fill="none" stroke="' + color + '" stroke-width="11" stroke-linecap="round" pathLength="100" stroke-dasharray="' + dash + '" transform="rotate(-90 75 75)"/>';
    };
    return '<svg viewBox="0 0 150 150" width="150" height="150">'
        + ring(64, sleep == null ? null : sleep / 100, COLORS.teal)
        + ring(45, strain == null ? null : strain / 100, COLORS.orange)
        + ring(26, recovery == null ? null : recovery / 100, COLORS.ringBlue)
        + '</svg>';
}

function fmtInt(v) { return Math.round(v).toLocaleString(); }

function fmt1(v) {
    const r = Math.round(v * 10) / 10;
    return r % 1 === 0 ? r.toString() : r.toFixed(1);
}

function fmtDur(secs) {
    const h = Math.floor(secs / 3600);
    const m = Math.round((secs % 3600) / 60);
    if (h === 0) return m + ' min';
    return h + 'h ' + String(m).padStart(2, '0') + ' min';
}

async function getJSON(url) {
    const res = await fetch(url);
    return res.json();
}

async function loadDashboard() {
    const range = getDateRange(currentRange);
    const start = range.start;
    const end = range.end;
    const bucket = getBucket(currentRange);
    const tz = '&tz=' + TZ_MIN;
    const q = 'start_date=' + start + '&end_date=' + end + tz;

    document.getElementById('dateLine').textContent = formatDateRange(start, end);

    try {
        const today = localISODate(new Date());
        const week8 = shiftISO(-7);
        const night9 = shiftISO(-8);
        const [
            summaryData, recordsData, hrData, stepsData, distData,
            calData, totalCalData, sleepData, weightData,
            scoreSleep, scoreSteps, scoreCal, scoreHr, sleepSegs
        ] = await Promise.all([
            getJSON('/api/summary?' + q),
            getJSON('/api/records?limit=50&' + q),
            getJSON('/api/timeseries/HEART_RATE?bucket=' + bucket + '&' + q),
            getJSON('/api/timeseries/STEPS?bucket=' + bucket + '&' + q),
            getJSON('/api/timeseries/DISTANCE_DELTA?bucket=' + bucket + '&' + q),
            getJSON('/api/timeseries/ACTIVE_ENERGY_BURNED?bucket=' + bucket + '&' + q),
            getJSON('/api/timeseries/TOTAL_CALORIES_BURNED?bucket=' + bucket + '&' + q),
            getJSON('/api/sleep?bucket=' + bucket + '&' + q),
            getJSON('/api/timeseries/WEIGHT?bucket=' + bucket + '&' + q),
            getJSON('/api/sleep?bucket=day&start_date=' + night9 + '&end_date=' + today + tz),
            getJSON('/api/timeseries/STEPS?bucket=day&start_date=' + week8 + '&end_date=' + today + tz),
            getJSON('/api/timeseries/ACTIVE_ENERGY_BURNED?bucket=day&start_date=' + week8 + '&end_date=' + today + tz),
            getJSON('/api/timeseries/HEART_RATE?bucket=day&start_date=' + week8 + '&end_date=' + today + tz),
            getJSON('/api/records?types=' + SLEEP_TYPES.join(',') + '&limit=1000&start_date=' + shiftISO(-1) + '&end_date=' + today + tz),
        ]);

        const typeSummary = summaryData.summary || [];
        const records = recordsData.records || [];

        document.getElementById('recordStats').textContent =
            records.length + ' recent \u00B7 ' + typeSummary.reduce((a, s) => a + s.count, 0).toLocaleString() + ' in view';
        document.getElementById('recordCount').textContent = records.length + ' records';

        renderScores(scoreSleep.data || [], scoreSteps.data || [], scoreCal.data || [], scoreHr.data || [], today);
        renderHypno(sleepSegs.records || [], today);
        renderHRChart(hrData.data || []);
        renderStepsChart(stepsData.data || [], distData.data || []);
        renderCaloriesChart((calData.data || []).concat(totalCalData.data || []));
        renderWeightChart(weightData.data || []);
        renderDistribution(typeSummary);
        renderRecords(records);
    } catch (err) {
        console.error('Failed to load dashboard:', err);
    }
}

function formatDateRange(start, end) {
    const opts = { month: 'short', day: 'numeric' };
    const s = parseLocalDate(start).toLocaleDateString('en-US', opts);
    const e = parseLocalDate(end).toLocaleDateString('en-US', opts);
    if (s === e) {
        const today = localISODate(new Date());
        return (start === today ? 'Today, ' : '') + s;
    }
    return s + ' - ' + e;
}

function formatLabel(bucket, range) {
    const norm = bucket.replace('T', ' ').replace(' ', 'T');
    if (range === 'day' || norm.length > 10) {
        const parts = norm.split('T');
        const ymd = parts[0].split('-').map(Number);
        const h = parts[1] ? parseInt(parts[1].slice(0, 2), 10) : 0;
        return new Date(ymd[0], ymd[1] - 1, ymd[2], h).toLocaleTimeString('en-US', { hour: 'numeric', hour12: true });
    }
    return parseLocalDate(norm).toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
}

function bucketMap(data, pick) {
    const m = {};
    (data || []).forEach(d => { m[d.bucket] = pick(d); });
    return m;
}

function renderScores(sleepBuckets, stepsDaily, calDaily, hrDaily, today) {
    const nights = (sleepBuckets || []).filter(d => d.hours > 0).map(d => d.bucket).sort();
    const past = nights.filter(b => b <= today);
    const lastNight = past.length ? past[past.length - 1] : null;
    const hoursByDay = bucketMap(sleepBuckets, d => d.hours);
    const lastHours = lastNight ? hoursByDay[lastNight] : null;
    const priorNights = past.filter(b => b < lastNight).slice(-7);
    const priorAvg = priorNights.length
        ? priorNights.reduce((a, b) => a + hoursByDay[b], 0) / priorNights.length
        : null;

    const stepsByDay = bucketMap(stepsDaily, d => d.sum);
    const calByDay = bucketMap(calDaily, d => d.sum);
    const hrByDay = bucketMap(hrDaily, d => d.avg);
    const dayScore = (b) => strainScore(stepsByDay[b] || 0, calByDay[b] || 0);
    const strain = dayScore(today);
    const priorVals = [];
    for (let i = 1; i <= 7; i++) {
        const s = dayScore(shiftISO(-i));
        if (s != null) priorVals.push(s);
    }
    const priorStrain = priorVals.length ? priorVals.reduce((a, b) => a + b, 0) / priorVals.length : null;

    const sleep = sleepScore(lastHours);
    const recovery = recoveryScore(sleep, strain);
    const sleepDelta = deltaPct(lastHours, priorAvg);
    const strainDelta = strain != null && priorStrain != null && !isNaN(priorStrain) ? deltaPct(strain, priorStrain) : null;

    document.getElementById('balanceRings').innerHTML = ringsSVG(sleep, strain, recovery);
    document.getElementById('balanceStatus').textContent = recovery == null ? 'No data yet' : bandFor(recovery);
    document.getElementById('miniSteps').textContent = stepsByDay[today] != null ? fmtInt(stepsByDay[today]) : '--';
    document.getElementById('miniCal').textContent = calByDay[today] != null ? fmtInt(calByDay[today]) : '--';
    document.getElementById('miniHr').textContent = hrByDay[today] != null ? fmtInt(hrByDay[today]) : '--';

    document.getElementById('sleepGauge').innerHTML =
        gaugeSVG(sleep == null ? null : sleep / 100, COLORS.teal) + gaugeCenter(sleep, sleepDelta, COLORS.teal);
    document.getElementById('sleepStatus').textContent = sleep == null ? 'No data' : bandFor(sleep);
    document.getElementById('sleepInsight').textContent = sleepInsight(sleep);

    document.getElementById('strainGauge').innerHTML =
        gaugeSVG(strain == null ? null : strain / 100, COLORS.orange) + gaugeCenter(strain, strainDelta, COLORS.orange);
    document.getElementById('strainStatus').textContent = strain == null ? 'No data' : bandFor(strain);
    document.getElementById('strainInsight').textContent = strainInsight(strain);
}

function eveningKey(dateFrom) {
    const d = new Date(dateFrom);
    let e = new Date(d.getFullYear(), d.getMonth(), d.getDate());
    if (d.getHours() < 12) e = new Date(e.getTime() - 86400000);
    return localISODate(e);
}

function renderHypno(records, today) {
    const hypnoEl = document.getElementById('hypno');
    const axisEl = document.getElementById('hypnoAxis');
    const rowsEl = document.getElementById('stageRows');
    const spanEl = document.getElementById('sleepSpan');
    hypnoEl.innerHTML = '';
    axisEl.innerHTML = '';
    rowsEl.innerHTML = '';

    const stageRecs = (records || []).filter(r => STAGE_ORDER.includes(r.type));
    const byNight = {};
    stageRecs.forEach(r => {
        const k = eveningKey(r.date_from);
        (byNight[k] = byNight[k] || []).push(r);
    });
    const nights = Object.keys(byNight).sort();
    const past = nights.filter(k => k <= today);
    if (!past.length) {
        hypnoEl.innerHTML = '<div class="empty-note">No sleep recorded in this window.</div>';
        spanEl.textContent = '';
        return;
    }
    const evening = past[past.length - 1];
    const segs = byNight[evening]
        .map(r => ({ start: new Date(r.date_from).getTime(), end: new Date(r.date_to).getTime(), stage: r.type }))
        .filter(s => s.end > s.start)
        .sort((a, b) => a.start - b.start);
    if (!segs.length) {
        hypnoEl.innerHTML = '<div class="empty-note">No sleep recorded in this window.</div>';
        return;
    }
    const t0 = Math.min.apply(null, segs.map(s => s.start));
    const t1 = Math.max.apply(null, segs.map(s => s.end));
    const total = Math.max(1, t1 - t0);
    spanEl.textContent = parseLocalDate(evening).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }) + ' night';

    const present = STAGE_ORDER.filter(st => segs.some(s => s.stage === st));
    present.forEach(st => {
        const row = document.createElement('div');
        row.className = 'hypno-band';
        let cursor = t0;
        segs.filter(s => s.stage === st).forEach(s => {
            if (s.start > cursor) {
                const gap = document.createElement('div');
                gap.className = 'hypno-gap';
                gap.style.flexGrow = ((s.start - cursor) / total * 1000).toFixed(1);
                row.appendChild(gap);
            }
            const block = document.createElement('div');
            block.className = 'hypno-block';
            block.style.flexGrow = (Math.max(1, (s.end - s.start)) / total * 1000).toFixed(1);
            block.style.background = TYPE_COLORS[st] || COLORS.peri;
            block.title = (TYPE_LABELS[st] || st) + ' ' + fmtDur((s.end - s.start) / 1000);
            row.appendChild(block);
            cursor = s.end;
        });
        if (cursor < t1) {
            const gap = document.createElement('div');
            gap.className = 'hypno-gap';
            gap.style.flexGrow = ((t1 - cursor) / total * 1000).toFixed(1);
            row.appendChild(gap);
        }
        hypnoEl.appendChild(row);
    });

    for (let i = 0; i <= 4; i++) {
        const sp = document.createElement('span');
        sp.textContent = new Date(t0 + total * i / 4).toLocaleTimeString('en-US', { hour: 'numeric', hour12: true }).toLowerCase();
        axisEl.appendChild(sp);
    }

    const totals = {};
    segs.forEach(s => { totals[s.stage] = (totals[s.stage] || 0) + (s.end - s.start) / 1000; });
    const grand = Object.keys(totals).reduce((a, k) => a + totals[k], 0) || 1;
    present.forEach(st => {
        const secs = totals[st];
        const pct = Math.round(secs / grand * 100);
        const row = document.createElement('div');
        row.className = 'stage-row';
        row.innerHTML = '<div class="stage-top"><span class="stage-name">' + (TYPE_LABELS[st] || st) + ' &nbsp;' + pct + '%</span>'
            + '<span class="stage-dur">' + fmtDur(secs) + '</span></div>'
            + '<div class="stage-bar"><div class="stage-fill" style="width:' + pct + '%;background:' + (TYPE_COLORS[st] || COLORS.peri) + '"></div></div>';
        rowsEl.appendChild(row);
    });
}

function clearChart(id) {
    const canvas = document.getElementById(id);
    if (canvas) {
        const ctx = canvas.getContext('2d');
        ctx.clearRect(0, 0, canvas.width, canvas.height);
    }
}

function withLegend(defs) {
    const d = chartDefaults();
    d.plugins.legend = { display: true, position: 'top', align: 'end', labels: legendLabels() };
    return d;
}

function renderHRChart(data) {
    const id = 'hrChart';
    if (charts[id]) charts[id].destroy();
    if (!data.length) { clearChart(id); return; }
    const labels = data.map(d => formatLabel(d.bucket, currentRange));
    charts[id] = new Chart(document.getElementById(id), {
        type: 'line',
        data: {
            labels,
            datasets: [
                {
                    label: 'Avg',
                    data: data.map(d => Math.round(d.avg)),
                    borderColor: COLORS.orange,
                    borderWidth: 2,
                    fill: '+1',
                    backgroundColor: COLORS.orangeDim,
                    tension: 0.35,
                    pointRadius: data.length > 20 ? 0 : 3,
                    pointHoverRadius: 5,
                    pointBackgroundColor: COLORS.orange,
                },
                {
                    label: 'Min',
                    data: data.map(d => Math.round(d.min)),
                    borderColor: 'transparent',
                    borderWidth: 0,
                    fill: false,
                    tension: 0.35,
                    pointRadius: 0,
                },
                {
                    label: 'Max',
                    data: data.map(d => Math.round(d.max)),
                    borderColor: 'transparent',
                    borderWidth: 0,
                    fill: '-1',
                    backgroundColor: COLORS.orangeDim,
                    tension: 0.35,
                    pointRadius: 0,
                },
            ],
        },
        options: withLegend(),
    });
}

function renderStepsChart(stepsTs, distTs) {
    const id = 'stepsChart';
    if (charts[id]) charts[id].destroy();
    const allBuckets = Array.from(new Set(stepsTs.concat(distTs).map(d => d.bucket))).sort();
    if (!allBuckets.length) { clearChart(id); return; }
    const stepsByBucket = {};
    stepsTs.forEach(d => { stepsByBucket[d.bucket] = d.sum; });
    const distByBucket = {};
    distTs.forEach(d => { distByBucket[d.bucket] = Math.round(d.sum * 10) / 10; });
    charts[id] = new Chart(document.getElementById(id), {
        type: 'bar',
        data: {
            labels: allBuckets.map(b => formatLabel(b, currentRange)),
            datasets: [
                {
                    label: 'Steps',
                    data: allBuckets.map(b => Math.round(stepsByBucket[b] || 0)),
                    backgroundColor: COLORS.tealDim,
                    borderColor: COLORS.teal,
                    borderWidth: 1,
                    borderRadius: 4,
                    yAxisID: 'y',
                    order: 2,
                },
                {
                    label: 'Distance',
                    data: allBuckets.map(b => distByBucket[b] || 0),
                    type: 'line',
                    borderColor: COLORS.ringBlue,
                    borderWidth: 2,
                    pointBackgroundColor: COLORS.ringBlue,
                    pointRadius: 3,
                    tension: 0.35,
                    fill: false,
                    yAxisID: 'y1',
                    order: 1,
                },
            ],
        },
        options: (function() {
            const o = withLegend();
            o.scales.y1 = {
                position: 'right',
                ticks: { color: '#7A7A84', font: { family: "'JetBrains Mono'", size: 10 }, maxTicksLimit: 5 },
                grid: { display: false, drawBorder: false },
                border: { display: false },
            };
            return o;
        })(),
    });
}

function renderCaloriesChart(data) {
    const id = 'caloriesChart';
    if (charts[id]) charts[id].destroy();
    if (!data.length) { clearChart(id); return; }
    charts[id] = new Chart(document.getElementById(id), {
        type: 'bar',
        data: {
            labels: data.map(d => formatLabel(d.bucket, currentRange)),
            datasets: [{
                label: 'Calories',
                data: data.map(d => Math.round(d.sum)),
                backgroundColor: COLORS.orangeDim,
                borderColor: COLORS.orange,
                borderWidth: 1,
                borderRadius: 4,
            }],
        },
        options: chartDefaults(),
    });
}

function renderWeightChart(data) {
    const id = 'weightChart';
    if (charts[id]) charts[id].destroy();
    if (!data.length) { clearChart(id); return; }
    charts[id] = new Chart(document.getElementById(id), {
        type: 'line',
        data: {
            labels: data.map(d => formatLabel(d.bucket, currentRange)),
            datasets: [{
                label: 'Weight',
                data: data.map(d => Math.round(d.avg * 10) / 10),
                borderColor: COLORS.teal,
                borderWidth: 2,
                fill: true,
                backgroundColor: COLORS.tealDim,
                tension: 0.35,
                pointRadius: data.length > 15 ? 0 : 4,
                pointHoverRadius: 5,
                pointBackgroundColor: COLORS.teal,
            }],
        },
        options: chartDefaults(),
    });
}

function renderDistribution(typeSummary) {
    const id = 'distributionChart';
    if (charts[id]) charts[id].destroy();
    if (!typeSummary.length) { clearChart(id); return; }
    const sorted = typeSummary.slice().sort((a, b) => b.count - a.count);
    charts[id] = new Chart(document.getElementById(id), {
        type: 'doughnut',
        data: {
            labels: sorted.map(s => TYPE_LABELS[s.key] || s.key),
            datasets: [{
                data: sorted.map(s => s.count),
                backgroundColor: sorted.map(s => (TYPE_COLORS[s.key] || '#7A7A84') + '55'),
                borderColor: sorted.map(s => TYPE_COLORS[s.key] || '#7A7A84'),
                borderWidth: 2,
                hoverOffset: 6,
            }],
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            cutout: '65%',
            animation: { duration: 600, easing: 'easeOutQuart' },
            plugins: {
                legend: { display: true, position: 'bottom', labels: legendLabels() },
                tooltip: Object.assign({}, chartDefaults().plugins.tooltip, {
                    callbacks: {
                        label: function(ctx) {
                            return ctx.label + ': ' + Math.round(ctx.parsed).toLocaleString();
                        }
                    }
                }),
            },
        },
    });
}

function sleepDisplay(r) {
    const secs = (new Date(r.date_to) - new Date(r.date_from)) / 1000;
    if (!isFinite(secs) || secs <= 0) return '--';
    return fmt1(secs / 3600);
}

function renderRecords(records) {
    const list = document.getElementById('recordsList');
    const dots = {
        HEART_RATE: COLORS.orange,
        STEPS: COLORS.teal,
        DISTANCE_DELTA: COLORS.ringBlue,
        ACTIVE_ENERGY_BURNED: COLORS.orange,
        TOTAL_CALORIES_BURNED: COLORS.orange,
        BASAL_ENERGY_BURNED: COLORS.orange,
        WEIGHT: COLORS.teal,
    };
    if (!records.length) {
        list.innerHTML = '<div class="empty-note">No records in this window.<br>Sync from your phone to see data here.</div>';
        return;
    }
    list.innerHTML = records.map(r => {
        const label = TYPE_LABELS[r.type] || r.type.replace(/_/g, ' ');
        const time = new Date(r.date_from).toLocaleString('en-US', {
            month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit'
        });
        const isSleep = SLEEP_TYPES.includes(r.type);
        const isInt = ['HEART_RATE', 'STEPS', 'ACTIVE_ENERGY_BURNED', 'TOTAL_CALORIES_BURNED', 'BASAL_ENERGY_BURNED'].includes(r.type);
        const val = parseFloat(r.value);
        const displayVal = isSleep ? sleepDisplay(r) : (isInt ? fmtInt(val) : fmt1(val));
        let unit = r.unit || '';
        if (isSleep) unit = 'h';
        else if (r.type === 'DISTANCE_DELTA' && !unit) unit = 'm';
        return '<div class="record-item">'
            + '<div class="record-left">'
            + '<div class="record-dot" style="background:' + (dots[r.type] || COLORS.peri) + '"></div>'
            + '<div><div class="record-type">' + label + '</div>'
            + '<div class="record-time">' + time + '</div></div>'
            + '</div>'
            + '<div><span class="record-val">' + displayVal + '</span>'
            + '<span class="record-unit">' + unit + '</span></div>'
            + '</div>';
    }).join('');
}

document.addEventListener('DOMContentLoaded', loadDashboard);
