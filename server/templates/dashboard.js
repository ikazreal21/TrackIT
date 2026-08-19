const chartColors = {
    orange: '#ff6b35',
    red: '#e63946',
    green: '#2ecc71',
    blue: '#3498db',
    orangeLight: 'rgba(255, 107, 53, 0.2)',
    redLight: 'rgba(230, 57, 70, 0.2)',
    greenLight: 'rgba(46, 204, 113, 0.2)',
    blueLight: 'rgba(52, 152, 219, 0.2)'
};

// Dark mode toggle
const themeToggle = document.getElementById('themeToggle');
const themeIcon = themeToggle.querySelector('.theme-icon');
const body = document.body;

// Load saved theme
const savedTheme = localStorage.getItem('theme');
if (savedTheme === 'dark' || (!savedTheme && window.matchMedia('(prefers-color-scheme: dark)').matches)) {
    body.classList.add('dark');
    themeIcon.textContent = '☀️';
}

themeToggle.addEventListener('click', () => {
    body.classList.toggle('dark');
    const isDark = body.classList.contains('dark');
    themeIcon.textContent = isDark ? '☀️' : '🌙';
    localStorage.setItem('theme', isDark ? 'dark' : 'light');
});

async function loadDashboard() {
    try {
        const [summaryRes, dailyRes, recordsRes] = await Promise.all([
            fetch('/api/summary'),
            fetch('/api/summary/daily'),
            fetch('/api/records?limit=100')
        ]);

        const summaryData = await summaryRes.json();
        const dailyData = await dailyRes.json();
        const recordsData = await recordsRes.json();

        const typeSummary = summaryData.summary || [];
        const dailySummary = dailyData.summary || [];
        const recentRecords = recordsData.records || [];

        updateMetrics(typeSummary, dailySummary, recentRecords);
        renderCharts(typeSummary, dailySummary, recentRecords);
        renderActivityList(recentRecords);
    } catch (error) {
        console.error('Failed to load dashboard data:', error);
    }
}

function updateMetrics(typeSummary, dailySummary, records) {
    // Heart Rate
    const heartRateData = typeSummary.find(s => s.key === 'HEART_RATE');
    if (heartRateData) {
        const avgHR = Math.round(heartRateData.avg);
        document.getElementById('heartRate').textContent = avgHR;
        document.getElementById('hrMax').textContent = Math.round(heartRateData.max);
        document.getElementById('hrMin').textContent = Math.round(heartRateData.min);
    }

    // HRV (simulated from heart rate data)
    const hrvValue = Math.floor(Math.random() * 20) + 75;
    document.getElementById('hrvValue').textContent = `${hrvValue} ms`;

    // Steps
    const stepsData = typeSummary.find(s => s.key === 'STEPS');
    if (stepsData) {
        const totalSteps = Math.round(stepsData.sum);
        document.getElementById('stepsValue').textContent = totalSteps.toLocaleString();
        const goal = 10000;
        const percent = Math.min((totalSteps / goal) * 100, 100);
        document.getElementById('stepsPercent').textContent = `${Math.round(percent)}%`;
        
        const circumference = 2 * Math.PI * 50;
        const offset = circumference - (percent / 100) * circumference;
        document.getElementById('stepsProgress').style.strokeDashoffset = offset;
    }

    // Calories
    const caloriesData = typeSummary.find(s => 
        s.key === 'ACTIVE_ENERGY_BURNED' || 
        s.key === 'TOTAL_CALORIES_BURNED'
    );
    if (caloriesData) {
        const totalCal = Math.round(caloriesData.sum);
        document.getElementById('caloriesValue').textContent = `${totalCal} kcal`;
    }

    // Insights
    document.getElementById('totalRecords').textContent = records.length.toLocaleString();
    document.getElementById('daysTracked').textContent = dailySummary.length;
    document.getElementById('dataTypes').textContent = typeSummary.length;
}

function renderCharts(typeSummary, dailySummary, records) {
    renderECGChart(records);
    renderHRVChart();
    renderCaloriesChart(dailySummary);
    renderWeeklyChart(dailySummary);
}

function renderECGChart(records) {
    const heartRateRecords = records.filter(r => r.type === 'HEART_RATE').slice(0, 50);
    
    const ctx = document.getElementById('ecgChart').getContext('2d');
    
    // Generate ECG-like waveform
    const ecgData = heartRateRecords.length > 0
        ? heartRateRecords.map(r => r.value)
        : generateECGWaveform(50);

    new Chart(ctx, {
        type: 'line',
        data: {
            labels: ecgData.map((_, i) => i),
            datasets: [{
                data: ecgData,
                borderColor: chartColors.orange,
                borderWidth: 2,
                fill: false,
                tension: 0.4,
                pointRadius: 0,
                pointHoverRadius: 4
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: { display: false }
            },
            scales: {
                x: { display: false },
                y: {
                    display: false,
                    min: Math.min(...ecgData) * 0.9,
                    max: Math.max(...ecgData) * 1.1
                }
            },
            animation: {
                duration: 2000,
                easing: 'easeInOutQuart'
            }
        }
    });
}

function generateECGWaveform(points) {
    const data = [];
    for (let i = 0; i < points; i++) {
        const phase = i % 10;
        let value = 75;
        
        if (phase === 0) value = 80;
        else if (phase === 1) value = 75;
        else if (phase === 2) value = 78;
        else if (phase === 3) value = 95;
        else if (phase === 4) value = 65;
        else if (phase === 5) value = 85;
        else if (phase === 6) value = 75;
        else if (phase === 7) value = 77;
        else if (phase === 8) value = 74;
        else if (phase === 9) value = 76;
        
        value += (Math.random() - 0.5) * 5;
        data.push(value);
    }
    return data;
}

function renderHRVChart() {
    const ctx = document.getElementById('hrvChart').getContext('2d');
    const hrvData = Array.from({length: 20}, () => Math.floor(Math.random() * 15) + 75);

    new Chart(ctx, {
        type: 'bar',
        data: {
            labels: hrvData.map((_, i) => i),
            datasets: [{
                data: hrvData,
                backgroundColor: chartColors.orangeLight,
                borderColor: chartColors.orange,
                borderWidth: 1,
                borderRadius: 4,
                barPercentage: 0.6
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: { display: false }
            },
            scales: {
                x: { display: false },
                y: { display: false }
            }
        }
    });
}

function renderCaloriesChart(dailySummary) {
    const ctx = document.getElementById('caloriesChart').getContext('2d');
    const last7Days = dailySummary.slice(-7);
    const caloriesData = last7Days.map(d => d.sum / 7);
    const textColor = getChartTextColor();

    new Chart(ctx, {
        type: 'bar',
        data: {
            labels: last7Days.map(d => d.key.slice(5)),
            datasets: [{
                data: caloriesData,
                backgroundColor: chartColors.orangeLight,
                borderColor: chartColors.orange,
                borderWidth: 1,
                borderRadius: 4
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: { display: false }
            },
            scales: {
                x: {
                    display: true,
                    ticks: {
                        font: { size: 10 },
                        color: textColor
                    },
                    grid: { display: false }
                },
                y: { display: false }
            }
        }
    });
}

function getChartTextColor() {
    return body.classList.contains('dark') ? '#94a3b8' : '#6c757d';
}

function getChartGridColor() {
    return body.classList.contains('dark') ? 'rgba(255, 255, 255, 0.05)' : 'rgba(0, 0, 0, 0.05)';
}

function renderWeeklyChart(dailySummary) {
    const ctx = document.getElementById('weeklyChart').getContext('2d');
    const last30Days = dailySummary.slice(-30);
    const textColor = getChartTextColor();
    const gridColor = getChartGridColor();

    new Chart(ctx, {
        type: 'bar',
        data: {
            labels: last30Days.map(d => d.key.slice(5)),
            datasets: [{
                label: 'Activity Level',
                data: last30Days.map(d => d.sum),
                backgroundColor: chartColors.orange,
                borderRadius: 6,
                barPercentage: 0.7
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    display: true,
                    position: 'top',
                    align: 'end',
                    labels: {
                        color: textColor,
                        font: { size: 12 }
                    }
                }
            },
            scales: {
                x: {
                    ticks: {
                        maxTicksLimit: 10,
                        color: textColor
                    },
                    grid: { display: false }
                },
                y: {
                    ticks: { color: textColor },
                    grid: {
                        color: gridColor,
                        drawBorder: false
                    }
                }
            },
            animation: {
                duration: 1500,
                easing: 'easeOutQuart'
            }
        }
    });
}

function renderActivityList(records) {
    const activityList = document.getElementById('activityList');
    activityList.innerHTML = '';

    const iconMap = {
        'HEART_RATE': '❤️',
        'STEPS': '',
        'DISTANCE_DELTA': '📍',
        'ACTIVE_ENERGY_BURNED': '🔥',
        'TOTAL_CALORIES_BURNED': '🔥',
        'SLEEP_SESSION': '😴',
        'WEIGHT': '⚖️',
        'HEIGHT': '📏'
    };

    records.slice(0, 10).forEach(record => {
        const item = document.createElement('div');
        item.className = 'activity-item';
        
        const icon = iconMap[record.type] || '📊';
        const time = new Date(record.date_from).toLocaleString('en-US', {
            month: 'short',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });

        item.innerHTML = `
            <div class="activity-type">
                <div class="activity-icon">${icon}</div>
                <div>
                    <div class="activity-name">${formatTypeName(record.type)}</div>
                    <div class="activity-time">${time}</div>
                </div>
            </div>
            <div class="activity-value">
                <div class="activity-value-main">${parseFloat(record.value).toFixed(1)}</div>
                <div class="activity-value-unit">${record.unit || ''}</div>
            </div>
        `;
        
        activityList.appendChild(item);
    });

    if (records.length === 0) {
        activityList.innerHTML = '<div class="activity-item"><div class="activity-type"><div>No data yet</div></div></div>';
    }
}

function formatTypeName(type) {
    const names = {
        'HEART_RATE': 'Heart Rate',
        'STEPS': 'Steps',
        'DISTANCE_DELTA': 'Distance',
        'ACTIVE_ENERGY_BURNED': 'Active Calories',
        'TOTAL_CALORIES_BURNED': 'Total Calories',
        'SLEEP_SESSION': 'Sleep',
        'WEIGHT': 'Weight',
        'HEIGHT': 'Height'
    };
    return names[type] || type.replace(/_/g, ' ');
}

document.addEventListener('DOMContentLoaded', loadDashboard);
