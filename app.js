const TILE_SIZE = 256;
const MAP_ZOOM = 17;
const VISIT_RADIUS_METERS = 38;
const STORAGE_KEY = "route-mission-state-v1";

const els = {
  map: document.querySelector("#map"),
  tileLayer: document.querySelector("#tileLayer"),
  routeLayer: document.querySelector("#routeLayer"),
  missionLayer: document.querySelector("#missionLayer"),
  locationDot: document.querySelector("#locationDot"),
  accuracyRing: document.querySelector("#accuracyRing"),
  statusText: document.querySelector("#statusText"),
  progressValue: document.querySelector("#progressValue"),
  progressFill: document.querySelector("#progressFill"),
  progressHint: document.querySelector("#progressHint"),
  visitedCount: document.querySelector("#visitedCount"),
  distanceValue: document.querySelector("#distanceValue"),
  accuracyValue: document.querySelector("#accuracyValue"),
  durationValue: document.querySelector("#durationValue"),
  missionRadius: document.querySelector("#missionRadius"),
  radiusOutput: document.querySelector("#radiusOutput"),
  startButton: document.querySelector("#startButton"),
  stopButton: document.querySelector("#stopButton"),
  resetButton: document.querySelector("#resetButton"),
  demoButton: document.querySelector("#demoButton"),
  recenterButton: document.querySelector("#recenterButton"),
  locationPrompt: document.querySelector("#locationPrompt"),
  updateLocationButton: document.querySelector("#updateLocationButton"),
  dismissLocationButton: document.querySelector("#dismissLocationButton"),
  checkpointList: document.querySelector("#checkpointList"),
  missionState: document.querySelector("#missionState"),
};

const state = {
  center: { lat: 41.0082, lng: 28.9784 },
  current: null,
  path: [],
  checkpoints: [],
  active: false,
  watchId: null,
  startedAt: null,
  elapsedBeforePause: 0,
  distanceMeters: 0,
  followLocation: true,
  demoTimer: null,
  locationAsked: false,
};

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
}

function toRad(value) {
  return (value * Math.PI) / 180;
}

function toDeg(value) {
  return (value * 180) / Math.PI;
}

function haversine(a, b) {
  const earth = 6371000;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const lat1 = toRad(a.lat);
  const lat2 = toRad(b.lat);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
  return 2 * earth * Math.asin(Math.sqrt(h));
}

function destinationPoint(origin, distanceMeters, bearingDegrees) {
  const radius = 6371000;
  const bearing = toRad(bearingDegrees);
  const lat1 = toRad(origin.lat);
  const lng1 = toRad(origin.lng);
  const delta = distanceMeters / radius;

  const lat2 = Math.asin(
    Math.sin(lat1) * Math.cos(delta) +
      Math.cos(lat1) * Math.sin(delta) * Math.cos(bearing),
  );
  const lng2 =
    lng1 +
    Math.atan2(
      Math.sin(bearing) * Math.sin(delta) * Math.cos(lat1),
      Math.cos(delta) - Math.sin(lat1) * Math.sin(lat2),
    );

  return { lat: toDeg(lat2), lng: toDeg(lng2) };
}

function project(lat, lng, zoom = MAP_ZOOM) {
  const scale = TILE_SIZE * 2 ** zoom;
  const x = ((lng + 180) / 360) * scale;
  const sinLat = Math.sin(toRad(clamp(lat, -85.05112878, 85.05112878)));
  const y = (0.5 - Math.log((1 + sinLat) / (1 - sinLat)) / (4 * Math.PI)) * scale;
  return { x, y };
}

function unproject(x, y, zoom = MAP_ZOOM) {
  const scale = TILE_SIZE * 2 ** zoom;
  const lng = (x / scale) * 360 - 180;
  const n = Math.PI - (2 * Math.PI * y) / scale;
  const lat = toDeg(Math.atan(Math.sinh(n)));
  return { lat, lng };
}

function mapPoint(point) {
  const rect = els.map.getBoundingClientRect();
  const centerPx = project(state.center.lat, state.center.lng);
  const pointPx = project(point.lat, point.lng);
  return {
    x: rect.width / 2 + pointPx.x - centerPx.x,
    y: rect.height / 2 + pointPx.y - centerPx.y,
  };
}

function formatDistance(value) {
  if (value >= 1000) return `${(value / 1000).toFixed(2)} km`;
  return `${Math.round(value)} m`;
}

function formatDuration(ms) {
  const totalSeconds = Math.floor(ms / 1000);
  const minutes = String(Math.floor(totalSeconds / 60)).padStart(2, "0");
  const seconds = String(totalSeconds % 60).padStart(2, "0");
  return `${minutes}:${seconds}`;
}

function setStatus(text) {
  els.statusText.textContent = text;
}

function hideLocationPrompt() {
  els.locationPrompt.classList.add("is-hidden");
}

function showLocationPrompt() {
  if (state.current || state.locationAsked) return;
  els.locationPrompt.classList.remove("is-hidden");
}

function renderTiles() {
  const rect = els.map.getBoundingClientRect();
  const centerPx = project(state.center.lat, state.center.lng);
  const topLeftX = centerPx.x - rect.width / 2;
  const topLeftY = centerPx.y - rect.height / 2;
  const startX = Math.floor(topLeftX / TILE_SIZE);
  const startY = Math.floor(topLeftY / TILE_SIZE);
  const endX = Math.floor((topLeftX + rect.width) / TILE_SIZE);
  const endY = Math.floor((topLeftY + rect.height) / TILE_SIZE);
  const maxTile = 2 ** MAP_ZOOM;
  const fragment = document.createDocumentFragment();

  els.tileLayer.innerHTML = "";
  for (let x = startX; x <= endX; x += 1) {
    for (let y = startY; y <= endY; y += 1) {
      if (y < 0 || y >= maxTile) continue;
      const wrappedX = ((x % maxTile) + maxTile) % maxTile;
      const img = document.createElement("img");
      img.className = "tile";
      img.alt = "";
      img.draggable = false;
      img.src = `https://tile.openstreetmap.org/${MAP_ZOOM}/${wrappedX}/${y}.png`;
      img.style.left = `${x * TILE_SIZE - topLeftX}px`;
      img.style.top = `${y * TILE_SIZE - topLeftY}px`;
      fragment.append(img);
    }
  }

  els.tileLayer.append(fragment);
}

function renderRoute() {
  const rect = els.map.getBoundingClientRect();
  els.routeLayer.setAttribute("viewBox", `0 0 ${rect.width} ${rect.height}`);
  els.routeLayer.innerHTML = "";

  if (state.path.length < 2) return;

  const points = state.path
    .map((point) => {
      const p = mapPoint(point);
      return `${p.x.toFixed(1)},${p.y.toFixed(1)}`;
    })
    .join(" ");

  const shadow = document.createElementNS("http://www.w3.org/2000/svg", "polyline");
  shadow.setAttribute("points", points);
  shadow.setAttribute("fill", "none");
  shadow.setAttribute("stroke", "rgba(255,255,255,0.92)");
  shadow.setAttribute("stroke-width", "9");
  shadow.setAttribute("stroke-linecap", "round");
  shadow.setAttribute("stroke-linejoin", "round");

  const route = document.createElementNS("http://www.w3.org/2000/svg", "polyline");
  route.setAttribute("points", points);
  route.setAttribute("fill", "none");
  route.setAttribute("stroke", "var(--route)");
  route.setAttribute("stroke-width", "5");
  route.setAttribute("stroke-linecap", "round");
  route.setAttribute("stroke-linejoin", "round");

  els.routeLayer.append(shadow, route);
}

function renderMarkers() {
  els.missionLayer.innerHTML = "";
  const next = getNextCheckpoint();
  state.checkpoints.forEach((checkpoint, index) => {
    const pin = document.createElement("div");
    const point = mapPoint(checkpoint);
    pin.className = "checkpoint-pin";
    if (checkpoint.visited) pin.classList.add("visited");
    if (next?.id === checkpoint.id) pin.classList.add("active");
    pin.textContent = String(index + 1);
    pin.style.left = `${point.x}px`;
    pin.style.top = `${point.y}px`;
    els.missionLayer.append(pin);
  });

  if (!state.current) return;
  const current = mapPoint(state.current);
  els.locationDot.style.left = `${current.x}px`;
  els.locationDot.style.top = `${current.y}px`;
  els.accuracyRing.style.left = `${current.x}px`;
  els.accuracyRing.style.top = `${current.y}px`;

  const metersPerPixel = 156543.03392 * Math.cos(toRad(state.center.lat)) / 2 ** MAP_ZOOM;
  const radius = clamp((state.current.accuracy || 25) / metersPerPixel, 32, 220);
  els.accuracyRing.style.width = `${radius * 2}px`;
  els.accuracyRing.style.height = `${radius * 2}px`;
}

function renderList() {
  const next = getNextCheckpoint();
  els.checkpointList.innerHTML = "";
  state.checkpoints.forEach((checkpoint, index) => {
    const li = document.createElement("li");
    if (checkpoint.visited) li.classList.add("done");
    if (next?.id === checkpoint.id) li.classList.add("active");

    const currentDistance = state.current ? haversine(state.current, checkpoint) : 0;
    li.innerHTML = `
      <span class="list-number">${index + 1}</span>
      <span>${checkpoint.name}</span>
      <span class="distance-pill">${checkpoint.visited ? "Geçildi" : formatDistance(currentDistance)}</span>
    `;
    els.checkpointList.append(li);
  });
}

function getProgress() {
  const total = state.checkpoints.length;
  const visited = state.checkpoints.filter((checkpoint) => checkpoint.visited).length;
  const percent = total ? Math.round((visited / total) * 100) : 0;
  return { total, visited, percent };
}

function getElapsed() {
  if (!state.startedAt) return state.elapsedBeforePause;
  return state.elapsedBeforePause + Date.now() - state.startedAt;
}

function getNextCheckpoint() {
  return state.checkpoints.find((checkpoint) => !checkpoint.visited) || null;
}

function renderStats() {
  const progress = getProgress();
  els.progressValue.textContent = `${progress.percent}%`;
  els.progressFill.style.width = `${progress.percent}%`;
  els.visitedCount.textContent = `${progress.visited}/${progress.total}`;
  els.distanceValue.textContent = formatDistance(state.distanceMeters);
  els.accuracyValue.textContent = state.current?.accuracy ? `~${Math.round(state.current.accuracy)} m` : "-";
  els.durationValue.textContent = formatDuration(getElapsed());
  els.radiusOutput.textContent = `${els.missionRadius.value} m`;
  els.missionState.textContent = state.active ? "Aktif" : progress.total ? "Durakladı" : "Hazır";

  if (progress.percent === 100 && progress.total > 0) {
    els.progressHint.textContent = "Görev tamamlandı. Yeni alan için sıfırlayıp tekrar başlatabilirsin.";
  } else if (progress.total > 0) {
    const next = getNextCheckpoint();
    els.progressHint.textContent = next
      ? `Sıradaki nokta: ${next.name}. ${VISIT_RADIUS_METERS} m yakınına gelince işaretlenir.`
      : "Görev noktaları hesaplanıyor.";
  } else {
    els.progressHint.textContent = "Görevi başlatınca yakın çevrende kontrol noktaları oluşur.";
  }
}

function renderAll() {
  renderTiles();
  renderRoute();
  renderMarkers();
  renderList();
  renderStats();
}

function makeMission(origin) {
  const radius = Number(els.missionRadius.value);
  const bearings = [0, 45, 90, 135, 180, 225, 270, 315, 25, 115, 205, 295];
  const distancePattern = [0.34, 0.48, 0.62, 0.77, 0.9, 0.55, 0.72, 0.42, 1, 0.86, 0.68, 0.52];
  state.checkpoints = bearings.map((bearing, index) => ({
    id: crypto.randomUUID ? crypto.randomUUID() : `${Date.now()}-${index}`,
    name: `Kontrol ${index + 1}`,
    visited: false,
    ...destinationPoint(origin, radius * distancePattern[index], bearing),
  }));
}

function updateVisited() {
  if (!state.current) return;
  state.checkpoints.forEach((checkpoint) => {
    if (!checkpoint.visited && haversine(state.current, checkpoint) <= VISIT_RADIUS_METERS) {
      checkpoint.visited = true;
    }
  });
}

function addPosition(position) {
  const nextPoint = {
    lat: position.coords.latitude,
    lng: position.coords.longitude,
    accuracy: position.coords.accuracy,
    timestamp: position.timestamp || Date.now(),
  };
  const previous = state.path.at(-1);

  state.current = nextPoint;
  if (state.followLocation) state.center = { lat: nextPoint.lat, lng: nextPoint.lng };

  if (!previous || haversine(previous, nextPoint) >= 4) {
    if (previous) state.distanceMeters += haversine(previous, nextPoint);
    state.path.push(nextPoint);
  }

  if (state.active && state.checkpoints.length === 0) makeMission(nextPoint);
  updateVisited();
  saveState();
  setStatus(state.active ? "Canlı konum izleniyor" : "Konum alındı");
  hideLocationPrompt();
  renderAll();
}

function handlePositionError(error) {
  const message = {
    1: "Konum izni verilmedi",
    2: "Konum bulunamadı",
    3: "Konum isteği zaman aşımına uğradı",
  }[error.code] || "Konum alınamadı";
  setStatus(message);
  els.updateLocationButton.disabled = false;
}

function requestCurrentLocation() {
  state.locationAsked = true;
  els.updateLocationButton.disabled = true;

  if (!("geolocation" in navigator)) {
    setStatus("Bu tarayıcı konum desteği vermiyor");
    els.updateLocationButton.disabled = false;
    return;
  }

  setStatus("Konum izni bekleniyor");
  navigator.geolocation.getCurrentPosition(
    (position) => {
      els.updateLocationButton.disabled = false;
      addPosition(position);
    },
    handlePositionError,
    {
      enableHighAccuracy: true,
      maximumAge: 0,
      timeout: 12000,
    },
  );
}

function startMission() {
  state.active = true;
  state.startedAt = Date.now();
  els.startButton.disabled = true;
  els.stopButton.disabled = false;
  hideLocationPrompt();

  if (state.current && state.checkpoints.length === 0) makeMission(state.current);

  if ("geolocation" in navigator) {
    state.watchId = navigator.geolocation.watchPosition(addPosition, handlePositionError, {
      enableHighAccuracy: true,
      maximumAge: 1000,
      timeout: 12000,
    });
    setStatus("Konum izni bekleniyor");
  } else {
    setStatus("Bu tarayıcı konum desteği vermiyor");
  }

  saveState();
  renderAll();
}

function stopMission() {
  state.active = false;
  if (state.startedAt) {
    state.elapsedBeforePause += Date.now() - state.startedAt;
    state.startedAt = null;
  }
  if (state.watchId !== null) {
    navigator.geolocation.clearWatch(state.watchId);
    state.watchId = null;
  }
  clearDemo();
  els.startButton.disabled = false;
  els.stopButton.disabled = true;
  setStatus("Görev duraklatıldı");
  saveState();
  renderAll();
}

function resetMission() {
  stopMission();
  state.path = [];
  state.checkpoints = [];
  state.distanceMeters = 0;
  state.elapsedBeforePause = 0;
  state.startedAt = null;
  localStorage.removeItem(STORAGE_KEY);
  setStatus("Görev sıfırlandı");
  renderAll();
}

function clearDemo() {
  if (state.demoTimer) {
    clearInterval(state.demoTimer);
    state.demoTimer = null;
  }
}

function startDemoWalk() {
  clearDemo();
  const origin = state.current || state.center;
  state.active = true;
  state.startedAt ||= Date.now();
  state.path = [];
  state.distanceMeters = 0;
  makeMission(origin);
  els.startButton.disabled = true;
  els.stopButton.disabled = false;

  const demoRoute = [
    origin,
    ...state.checkpoints.map((checkpoint) => ({ lat: checkpoint.lat, lng: checkpoint.lng })),
  ];
  let segment = 0;
  let step = 0;
  setStatus("Demo yürüyüş oynatılıyor");

  state.demoTimer = setInterval(() => {
    const from = demoRoute[segment];
    const to = demoRoute[segment + 1];
    if (!to) {
      clearDemo();
      setStatus("Demo görev tamamlandı");
      renderAll();
      return;
    }

    step += 1;
    const t = step / 18;
    const lat = from.lat + (to.lat - from.lat) * t;
    const lng = from.lng + (to.lng - from.lng) * t;
    addPosition({ coords: { latitude: lat, longitude: lng, accuracy: 12 }, timestamp: Date.now() });

    if (step >= 18) {
      segment += 1;
      step = 0;
    }
  }, 180);
}

function recenter() {
  state.followLocation = true;
  if (state.current) {
    state.center = { lat: state.current.lat, lng: state.current.lng };
  }
  renderAll();
}

function saveState() {
  const snapshot = {
    center: state.center,
    current: state.current,
    path: state.path,
    checkpoints: state.checkpoints,
    elapsedBeforePause: getElapsed(),
    distanceMeters: state.distanceMeters,
    radius: els.missionRadius.value,
  };
  localStorage.setItem(STORAGE_KEY, JSON.stringify(snapshot));
}

function loadState() {
  try {
    const snapshot = JSON.parse(localStorage.getItem(STORAGE_KEY) || "null");
    if (!snapshot) return;
    state.center = snapshot.center || state.center;
    state.current = snapshot.current || null;
    state.path = snapshot.path || [];
    state.checkpoints = snapshot.checkpoints || [];
    state.elapsedBeforePause = snapshot.elapsedBeforePause || 0;
    state.distanceMeters = snapshot.distanceMeters || 0;
    if (snapshot.radius) els.missionRadius.value = snapshot.radius;
    setStatus(state.current ? "Kayıtlı görev yüklendi" : "Konum bekleniyor");
  } catch {
    localStorage.removeItem(STORAGE_KEY);
  }
}

function setupMapDrag() {
  let dragging = false;
  let start = null;
  let centerStart = null;

  els.map.addEventListener("pointerdown", (event) => {
    dragging = true;
    start = { x: event.clientX, y: event.clientY };
    centerStart = project(state.center.lat, state.center.lng);
    state.followLocation = false;
    els.map.setPointerCapture(event.pointerId);
  });

  els.map.addEventListener("pointermove", (event) => {
    if (!dragging) return;
    const dx = event.clientX - start.x;
    const dy = event.clientY - start.y;
    state.center = unproject(centerStart.x - dx, centerStart.y - dy);
    renderAll();
  });

  els.map.addEventListener("pointerup", () => {
    dragging = false;
  });
}

function tickDuration() {
  renderStats();
  requestAnimationFrame(() => {
    setTimeout(tickDuration, 500);
  });
}

function registerServiceWorker() {
  if ("serviceWorker" in navigator) {
    navigator.serviceWorker.register("sw.js").catch(() => {});
  }
}

els.startButton.addEventListener("click", startMission);
els.stopButton.addEventListener("click", stopMission);
els.resetButton.addEventListener("click", resetMission);
els.demoButton.addEventListener("click", startDemoWalk);
els.recenterButton.addEventListener("click", recenter);
els.updateLocationButton.addEventListener("click", requestCurrentLocation);
els.dismissLocationButton.addEventListener("click", () => {
  state.locationAsked = true;
  hideLocationPrompt();
});
els.missionRadius.addEventListener("input", () => {
  if (state.checkpoints.length === 0) renderStats();
  els.radiusOutput.textContent = `${els.missionRadius.value} m`;
});
els.missionRadius.addEventListener("change", () => {
  if (state.current && state.checkpoints.length === 0) saveState();
});
window.addEventListener("resize", renderAll);

loadState();
setupMapDrag();
renderAll();
showLocationPrompt();
tickDuration();
registerServiceWorker();
