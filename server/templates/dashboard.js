const COLORS = {
    gold: '#E8B44A',
    blue: '#38BDF8',
    green: '#4ADE80',
    red: '#F87171',
    violet: '#A78BFA',
    orange: '#FB923C',
    goldDim: 'rgba(232, 180, 74, 0.15)',
    blueDim: 'rgba(56, 189, 248, 0.12)',
    greenDim: 'rgba(74, 222, 128, 0.12)',
    redDim: 'rgba(248, 113, 113, 0.12)',
    violetDim: 'rgba(167, 139, 250, 0.12)',
    orangeDim: 'rgba(251, 146, 60, 0.12)',
};

const TYPE_COLORS = {
    HEART_RATE: COLORS.red,
    STEPS: COLORS.green,
    DISTANCE_DELTA: COLORS.blue,
    ACTIVE_ENERGY_BURNED: COLORS.orange,
    TOTAL_CALORIES_BURNED: COLORS.orange,
    BASAL_ENERGY_BURNED: COLORS.gold,
    SLEEP_SESSION: COLORS.violet,
    SLEEP_ASLEEP: COLORS.violet,
    SLEEP_LIGHT: 'rgba(167, 139, 250, 0.6)',
    SLEEP_DEEP: 'rgba(167, 139, 250, 0.85)',
    SLEEP_REM: 'rgba(167, 139, 250, 0.4)',
    WEIGHT: COLORS.blue,
    HEIGHT: COLORS.blue,
};

const TYPE_DOT_CLASS = {
    HEART_RATE: 'heart',
    STEPS: 'steps',
    ACTIVE_ENERGY_BURNED: 'calories',
    TOTAL_CALORIES_BURNED: 'calories',
    BASAL_ENERGY_BURNED: 'calories',
    SLEEP_SESSION: 'sleep',
    SLEEP_ASLEEP: 'sleep',
    SLEEP_LIGHT: 'sleep',
    SLEEP_DEEP: 'sleep',
    SLEEP_REM: 'sleep',
    WEIGHT: 'weight',
    DISTANCE_DELTA: 'distance',
};

const TYPE_LABELS = {
    HEART_RATE: 'Heart Rate',
    STEPS: 'Steps',
    DISTANCE_DELTA: 'Distance',
    ACTIVE_ENERGY_BURNED: 'Active Calories',
    TOTAL_CALORIES_BURNED: 'Total Calories',
    BASAL_ENERGY_BURNED: 'Basal Calories',
    SLEEP_SESSION: 'Sleep',
    SLEEP_ASLEEP: 'Asleep',
    SLEEP_LIGHT: 'Light Sleep',
    SLEEP_DEEP: 'Deep Sleep',
    SLEEP_REM: 'REM Sleep',
    WEIGHT: 'Weight',
    HEIGHT: 'Height',
};

let currentRange = 'week';
let charts = {};

const themeToggle = document.getElementById('themeToggle');
const savedTheme = localStorage.getItem('trackit-theme');
if (savedTheme === 'light') {
    document.body.classList.add('light');
} else if (!savedTheme && window.matchMedia('(prefers-color-scheme: light)').matches) {
    document.body.classList.add('light');
}

themeToggle.addEventListener('click', () => {
    document.body.classList.toggle('light');
    const isLight = document.body.classList.contains('light');
    localStorage.setItem('trackit-theme', isLight ? 'light' : 'dark');
    Object.values(charts).forEach(c => c && c.destroy());
    charts = {};
    loadDashboard();
});

document.getElementById('rangeSelector').addEventListener('click', (e) => {
    const btn = e.target.closest('.range-btn');
    if (!btn) return;
    document.querySelectorAll('.range-btn').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    currentRange = btn.dataset.range;
    loadDashboard();
});

function getDateRange(range) {
    const now = new Date();
    const end = now.toISOString().slice(0, 10);
    let start;
    if (range === 'day') {
        start = end;
    } else if (range === 'week') {
        const d = new Date(now);
        d.setDate(d.getDate() - 6);
        start = d.toISOString().slice(0, 10);
    } else {
        const d = new Date(now);
        d.setDate(d.getDate() - 29);
        start = d.toISOString().slice(0, 10);
    }
    return { start, end };
}

function getBucket(range) {
    if (range === 'day') return 'hour';
    return 'day';
}

function getChartColors() {
    const isLight = document.body.classList.contains('light');
    return {
        text: isLight ? '#5A6A82' : '#8B9DC3',
        grid: isLight ? 'rgba(0,0,0,0.06)' : 'rgba(255,255,255,0.05)',
        tooltipBg: isLight ? '#1A2233' : '#F1F5F9',
        tooltipText: isLight ? '#F1F5F9' : '#1A2233',
    };
}

function chartDefaults() {
    const c = getChartColors();
    return {
        responsive: true,
        maintainAspectRatio: false,
        animation: { duration: 600, easing: 'easeOutQuart' },
        plugins: {
            legend: { display: false },
            tooltip: {
                backgroundColor: c.tooltipBg,
                titleColor: c.tooltipText,
                bodyColor: c.tooltipText,
                borderColor: 'rgba(128,128,128,0.2)',
                borderWidth: 1,
                cornerRadius: 8,
                padding: 10,
                titleFont: { family: "'Space Grotesk'", weight: '600', size: 12 },
                bodyFont: { family: "'JetBrains Mono'", size: 11 },
                displayColors: true,
                boxPadding: 4,
            },
        },
        scales: {
            x: {
                ticks: { color: c.text, font: { family: "'JetBrains Mono'", size: 10 }, maxTicksLimit: 8 },
                grid: { display: false },
                border: { display: false },
            },
            y: {
                ticks: { color: c.text, font: { family: "'JetBrains Mono'", size: 10 }, maxTicksLimit: 5 },
                grid: { color: c.grid, drawBorder: false },
                border: { display: false },
            },
        },
    };
}

async function loadDashboard() {
    const { start, end } = getDateRange(currentRange);
    const bucket = getBucket(currentRange);

    document.getElementById('dateRangeLabel').textContent = formatDateRange(start, end);

    try {
        const [summaryRes, recordsRes, hrTs, stepsTs, distTs, calTs, totalCalTs, sleepTs, weightTs] = await Promise.all([
            fetch(`/api/summary?start_date=${start}&end_date=${end}`),
            fetch(`/api/records?limit=50&start_date=${start}&end_date=${end}`),
            fetch(`/api/timeseries/HEART_RATE?bucket=${bucket}&start_date=${start}&end_date=${end}`),
            fetch(`/api/timeseries/STEPS?bucket=${bucket}&start_date=${start}&end_date=${end}`),
            fetch(`/api/timeseries/DISTANCE_DELTA?bucket=${bucket}&start_date=${start}&end_date=${end}`),
            fetch(`/api/timeseries/ACTIVE_ENERGY_BURNED?bucket=${bucket}&start_date=${start}&end_date=${end}`),
            fetch(`/api/timeseries/TOTAL_CALORIES_BURNED?bucket=${bucket}&start_date=${start}&end_date=${end}`),
            fetch(`/api/timeseries/SLEEP_SESSION?bucket=${bucket}&start_date=${start}&end_date=${end}`),
            fetch(`/api/timeseries/WEIGHT?bucket=${bucket}&start_date=${start}&end_date=${end}`),
        ]);

        const [summaryData, recordsData, hrData, stepsData, distData, calData, totalCalData, sleepData, weightData] = await Promise.all([
            summaryRes.json(),
            recordsRes.json(),
            hrTs.json(),
            stepsTs.json(),
            distTs.json(),
            calTs.json(),
            totalCalTs.json(),
            sleepTs.json(),
            weightTs.json(),
        ]);

        const typeSummary = summaryData.summary || [];
        const records = recordsData.records || [];

        updateMetricCards(typeSummary, hrData.data || [], stepsData.data || [], calData.data || [], totalCalData.data || [], sleepData.data || []);
        renderSparklines(hrData.data || [], stepsData.data || [], (calData.data || []).concat(totalCalData.data || []), sleepData.data || []);
        renderCharts(hrData.data || [], stepsData.data || [], distData.data || [], (calData.data || []).concat(totalCalData.data || []), sleepData.data || [], weightData.data || []);
        renderDistribution(typeSummary);
        renderRecords(records);
    } catch (err) {
        console.error('Failed to load dashboard:', err);
    }
}

function formatDateRange(start, end) {
    const opts = { month: 'short', day: 'numeric' };
    const s = new Date(start + 'T00:00:00').toLocaleDateString('en-US', opts);
    const e = new Date(end + 'T00:00:00').toLocaleDateString('en-US', opts);
    if (s === e) return s;
    return s + ' - ' + e;
}

function formatLabel(bucket, range) {
    if (range === 'day' || bucket.length > 10) {
        const d = new Date(bucket.length > 10 ? bucket + ':00:00' : bucket + 'T00:00:00');
        return d.toLocaleTimeString('en-US', { hour: 'numeric', hour12: true });
    }
    const d = new Date(bucket + 'T00:00:00');
    return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
}

function updateMetricCards(typeSummary, hrTs, stepsTs, calTs, totalCalTs, sleepTs) {
    const hrSummary = typeSummary.find(s => s.key === 'HEART_RATE');
    if (hrSummary) {
        document.getElementById('hrValue').textContent = Math.round(hrSummary.avg);
        document.getElementById('hrRange').textContent = Math.round(hrSummary.min) + ' - ' + Math.round(hrSummary.max);
    } else {
        document.getElementById('hrValue').textContent = '--';
        document.getElementById('hrRange').textContent = '-- --';
    }

    const stepsSummary = typeSummary.find(s => s.key === 'STEPS');
    if (stepsSummary) {
        document.getElementById('stepsValue').textContent = Math.round(stepsSummary.sum).toLocaleString();
        const dayCount = new Set(stepsTs.map(d => d.bucket)).size || 1;
        document.getElementById('stepsAvg').textContent = Math.round(stepsSummary.sum / dayCount).toLocaleString() + '/day';
    } else {
        document.getElementById('stepsValue').textContent = '--';
        document.getElementById('stepsAvg').textContent = '--';
    }

    const calSum = (typeSummary.find(s => s.key === 'ACTIVE_ENERGY_BURNED')?.sum || 0)
        + (typeSummary.find(s => s.key === 'TOTAL_CALORIES_BURNED')?.sum || 0);
    if (calSum > 0) {
        document.getElementById('caloriesValue').textContent = Math.round(calSum).toLocaleString();
        const allCalBuckets = new Set([...calTs, ...totalCalTs].map(d => d.bucket));
        const dayCount = allCalBuckets.size || 1;
        document.getElementById('caloriesAvg').textContent = Math.round(calSum / dayCount).toLocaleString() + '/day';
    } else {
        document.getElementById('caloriesValue').textContent = '--';
        document.getElementById('caloriesAvg').textContent = '--';
    }

    const sleepSummary = typeSummary.find(s => s.key === 'SLEEP_SESSION' || s.key === 'SLEEP_ASLEEP');
    if (sleepSummary) {
        const totalHrs = sleepSummary.sum / 3600;
        const dayCount = new Set(sleepTs.map(d => d.bucket)).size || 1;
        const avgHrs = totalHrs / dayCount;
        document.getElementById('sleepValue').textContent = totalHrs.toFixed(1);
        document.getElementById('sleepAvg').textContent = avgHrs.toFixed(1) + ' hrs/night';
    } else {
        document.getElementById('sleepValue').textContent = '--';
        document.getElementById('sleepAvg').textContent = '--';
    }
}

function renderSparklines(hrTs, stepsTs, calTs, sleepTs) {
    renderSparkline('hrSparkline', hrTs.map(d => d.avg), COLORS.red, COLORS.redDim);
    renderSparkline('stepsSparkline', stepsTs.map(d => d.sum), COLORS.green, COLORS.greenDim);
    renderSparkline('caloriesSparkline', calTs.map(d => d.sum), COLORS.orange, COLORS.orangeDim);
    renderSparkline('sleepSparkline', sleepTs.map(d => d.sum / 3600), COLORS.violet, COLORS.violetDim);
}

function renderSparkline(canvasId, data, color, fillColor) {
    const existing = Chart.getChart(canvasId);
    if (existing) existing.destroy();

    if (!data.length) {
        const ctx = document.getElementById(canvasId).getContext('2d');
        ctx.clearRect(0, 0, ctx.canvas.width, ctx.canvas.height);
        return;
    }

    new Chart(document.getElementById(canvasId), {
        type: 'line',
        data: {
            labels: data.map((_, i) => i),
            datasets: [{
                data,
                borderColor: color,
                borderWidth: 1.5,
                fill: true,
                backgroundColor: fillColor,
                tension: 0.4,
                pointRadius: 0,
                pointHoverRadius: 0,
            }],
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            animation: { duration: 400 },
            plugins: { legend: { display: false }, tooltip: { enabled: false } },
            scales: {
                x: { display: false },
                y: { display: false },
            },
            elements: { line: { borderCapStyle: 'round' } },
        },
    });
}

function clearChart(id) {
    const canvas = document.getElementById(id);
    if (canvas) {
        const ctx = canvas.getContext('2d');
        ctx.clearRect(0, 0, canvas.width, canvas.height);
    }
}

function renderCharts(hrTs, stepsTs, distTs, calTs, sleepTs, weightTs) {
    renderHRChart(hrTs);
    renderStepsChart(stepsTs, distTs);
    renderCaloriesChart(calTs);
    renderSleepChart(sleepTs);
    renderWeightChart(weightTs);
}

function renderHRChart(data) {
    const id = 'hrChart';
    if (charts[id]) charts[id].destroy();

    if (!data.length) { clearChart(id); return; }

    const labels = data.map(d => formatLabel(d.bucket, currentRange));
    const avgData = data.map(d => Math.round(d.avg));
    const minData = data.map(d => Math.round(d.min));
    const maxData = data.map(d => Math.round(d.max));

    charts[id] = new Chart(document.getElementById(id), {
        type: 'line',
        data: {
            labels,
            datasets: [
                {
                    label: 'Avg',
                    data: avgData,
                    borderColor: COLORS.red,
                    borderWidth: 2,
                    fill: '+1',
                    backgroundColor: COLORS.redDim,
                    tension: 0.35,
                    pointRadius: data.length > 20 ? 0 : 3,
                    pointHoverRadius: 5,
                    pointBackgroundColor: COLORS.red,
                },
                {
                    label: 'Min',
                    data: minData,
                    borderColor: 'transparent',
                    borderWidth: 0,
                    fill: false,
                    tension: 0.35,
                    pointRadius: 0,
                },
                {
                    label: 'Max',
                    data: maxData,
                    borderColor: 'transparent',
                    borderWidth: 0,
                    fill: '-1',
                    backgroundColor: COLORS.redDim,
                    tension: 0.35,
                    pointRadius: 0,
                },
            ],
        },
        options: {
            ...chartDefaults(),
            plugins: {
                ...chartDefaults().plugins,
                legend: {
                    display: true,
                    position: 'top',
                    align: 'end',
                    labels: {
                        color: getChartColors().text,
                        font: { family: "'Space Grotesk'", size: 11 },
                        boxWidth: 12,
                        boxHeight: 2,
                        padding: 16,
                        usePointStyle: false,
                    },
                },
            },
        },
    });
}

function renderStepsChart(stepsTs, distTs) {
    const id = 'stepsChart';
    if (charts[id]) charts[id].destroy();

    const allBuckets = [...new Set([...stepsTs.map(d => d.bucket), ...distTs.map(d => d.bucket)])].sort();
    if (!allBuckets.length) { clearChart(id); return; }

    const labels = allBuckets.map(b => formatLabel(b, currentRange));
    const stepsByBucket = Object.fromEntries(stepsTs.map(d => [d.bucket, d.sum]));
    const distByBucket = Object.fromEntries(distTs.map(d => [d.bucket, d.sum]));

    charts[id] = new Chart(document.getElementById(id), {
        type: 'bar',
        data: {
            labels,
            datasets: [
                {
                    label: 'Steps',
                    data: allBuckets.map(b => Math.round(stepsByBucket[b] || 0)),
                    backgroundColor: COLORS.greenDim,
                    borderColor: COLORS.green,
                    borderWidth: 1,
                    borderRadius: 4,
                    yAxisID: 'y',
                    order: 2,
                },
                {
                    label: 'Distance',
                    data: allBuckets.map(b => distByBucket[b] || 0),
                    type: 'line',
                    borderColor: COLORS.blue,
                    borderWidth: 2,
                    pointBackgroundColor: COLORS.blue,
                    pointRadius: 3,
                    tension: 0.35,
                    fill: false,
                    yAxisID: 'y1',
                    order: 1,
                },
            ],
        },
        options: {
            ...chartDefaults(),
            plugins: {
                ...chartDefaults().plugins,
                legend: {
                    display: true,
                    position: 'top',
                    align: 'end',
                    labels: {
                        color: getChartColors().text,
                        font: { family: "'Space Grotesk'", size: 11 },
                        boxWidth: 12,
                        boxHeight: 2,
                        padding: 16,
                    },
                },
            },
            scales: {
                ...chartDefaults().scales,
                y: {
                    ...chartDefaults().scales.y,
                    position: 'left',
                },
                y1: {
                    ...chartDefaults().scales.y,
                    position: 'right',
                    grid: { display: false, drawBorder: false },
                },
            },
        },
    });
}

function renderCaloriesChart(data) {
    const id = 'caloriesChart';
    if (charts[id]) charts[id].destroy();

    if (!data.length) { clearChart(id); return; }

    const labels = data.map(d => formatLabel(d.bucket, currentRange));

    charts[id] = new Chart(document.getElementById(id), {
        type: 'bar',
        data: {
            labels,
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

function renderSleepChart(data) {
    const id = 'sleepChart';
    if (charts[id]) charts[id].destroy();

    if (!data.length) { clearChart(id); return; }

    const labels = data.map(d => formatLabel(d.bucket, currentRange));
    const hours = data.map(d => +(d.sum / 3600).toFixed(1));

    charts[id] = new Chart(document.getElementById(id), {
        type: 'bar',
        data: {
            labels,
            datasets: [{
                label: 'Hours',
                data: hours,
                backgroundColor: COLORS.violetDim,
                borderColor: COLORS.violet,
                borderWidth: 1,
                borderRadius: 4,
            }],
        },
        options: {
            ...chartDefaults(),
            scales: {
                ...chartDefaults().scales,
                y: {
                    ...chartDefaults().scales.y,
                    title: { display: true, text: 'Hours', color: getChartColors().text, font: { size: 10 } },
                },
            },
        },
    });
}

function renderWeightChart(data) {
    const id = 'weightChart';
    if (charts[id]) charts[id].destroy();

    if (!data.length) { clearChart(id); return; }

    const labels = data.map(d => formatLabel(d.bucket, currentRange));

    charts[id] = new Chart(document.getElementById(id), {
        type: 'line',
        data: {
            labels,
            datasets: [{
                label: 'Weight',
                data: data.map(d => +d.avg.toFixed(1)),
                borderColor: COLORS.blue,
                borderWidth: 2,
                fill: true,
                backgroundColor: COLORS.blueDim,
                tension: 0.35,
                pointRadius: data.length > 15 ? 0 : 4,
                pointHoverRadius: 5,
                pointBackgroundColor: COLORS.blue,
            }],
        },
        options: chartDefaults(),
    });
}

function renderDistribution(typeSummary) {
    const id = 'distributionChart';
    if (charts[id]) charts[id].destroy();

    if (!typeSummary.length) { clearChart(id); return; }

    const sorted = [...typeSummary].sort((a, b) => b.count - a.count);
    const labels = sorted.map(s => TYPE_LABELS[s.key] || s.key);
    const colors = sorted.map(s => TYPE_COLORS[s.key] || '#6B7280');
    const borderColors = colors.map(c => c.replace(/[\d.]+\)$/, '1)'));

    charts[id] = new Chart(document.getElementById(id), {
        type: 'doughnut',
        data: {
            labels,
            datasets: [{
                data: sorted.map(s => s.count),
                backgroundColor: colors.map(c => c.includes('rgba') ? c : c + '33'),
                borderColor: colors,
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
                legend: {
                    display: true,
                    position: 'bottom',
                    labels: {
                        color: getChartColors().text,
                        font: { family: "'Space Grotesk'", size: 11 },
                        padding: 12,
                        boxWidth: 12,
                        boxHeight: 12,
                        usePointStyle: true,
                        pointStyle: 'circle',
                    },
                },
                tooltip: chartDefaults().plugins.tooltip,
            },
        },
    });
}

function renderRecords(records) {
    const list = document.getElementById('recordsList');
    const countEl = document.getElementById('recordCount');
    countEl.textContent = records.length + ' records';

    if (!records.length) {
        list.innerHTML = '<div class="empty-state"><svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/><polyline points="10 9 9 9 8 9"/></svg><p>No data yet</p><span>Sync from your phone to see records here</span></div>';
        return;
    }

    list.innerHTML = records.map(r => {
        const dotClass = TYPE_DOT_CLASS[r.type] || 'default';
        const label = TYPE_LABELS[r.type] || r.type.replace(/_/g, ' ');
        const time = new Date(r.date_from).toLocaleString('en-US', {
            month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit'
        });
        const val = parseFloat(r.value);
        const displayVal = r.type === 'STEPS' ? Math.round(val).toLocaleString() : val.toFixed(1);
        return '<div class="record-item">' +
            '<div class="record-left">' +
                '<div class="record-dot ' + dotClass + '"></div>' +
                '<div class="record-info">' +
                    '<span class="record-type">' + label + '</span>' +
                    '<span class="record-time">' + time + '</span>' +
                '</div>' +
            '</div>' +
            '<div class="record-right">' +
                '<span class="record-val">' + displayVal + '</span>' +
                '<span class="record-unit">' + (r.unit || '') + '</span>' +
            '</div>' +
        '</div>';
    }).join('');
}

document.addEventListener('DOMContentLoaded', loadDashboard);
