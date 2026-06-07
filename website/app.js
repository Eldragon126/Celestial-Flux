/* VECTOR ANOMALY website runtime */

const config = window.VECTOR_ANOMALY_SITE || {};
const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

function safeExternalUrl(url) {
	return typeof url === "string" && url.length > 0 && !/PLACEHOLDER/i.test(url);
}

function isEmbeddable(url) {
	return /youtube|youtu\.be|vimeo/.test(url);
}

function embedUrl(url) {
	if (url.includes("youtu.be/")) {
		const id = url.split("youtu.be/")[1]?.split(/[?&]/)[0];
		return `https://www.youtube-nocookie.com/embed/${id}`;
	}
	if (url.includes("youtube.com/watch")) {
		const id = new URL(url).searchParams.get("v");
		return `https://www.youtube-nocookie.com/embed/${id}`;
	}
	if (url.includes("vimeo.com/")) {
		const id = url.split("vimeo.com/")[1]?.split(/[?&]/)[0];
		return `https://player.vimeo.com/video/${id}`;
	}
	return url;
}

function initSiteConfig() {
	const yearNode = document.querySelector("[data-year]");
	if (yearNode) {
		yearNode.textContent = String(new Date().getFullYear());
	}

	document.querySelectorAll("[data-press-email]").forEach((node) => {
		if (config.pressEmail) {
			node.href = `mailto:${config.pressEmail}`;
			node.textContent = config.pressEmail;
		}
	});

	const steamTargets = [
		document.querySelector("[data-wishlist-cta]"),
		document.querySelector("[data-footer-steam]"),
	];
	for (const target of steamTargets) {
		if (!target) continue;
		if (safeExternalUrl(config.steamUrl)) {
			target.href = config.steamUrl;
			target.target = "_blank";
			target.rel = "noopener";
			target.hidden = false;
		} else {
			target.href = "#wishlist";
			target.hidden = false;
		}
	}

	document.querySelectorAll("[data-demo-link]").forEach((target) => {
		if (safeExternalUrl(config.demoUrl)) {
			target.href = config.demoUrl;
			target.target = "_blank";
			target.rel = "noopener";
		} else {
			target.href = "#sandbox";
		}
	});

	const discord = document.querySelector("[data-footer-discord]");
	if (discord && safeExternalUrl(config.discordUrl)) {
		discord.href = config.discordUrl;
		discord.hidden = false;
	}

	const twitter = document.querySelector("[data-twitter-link]");
	if (twitter && safeExternalUrl(config.twitterUrl)) {
		twitter.href = config.twitterUrl;
		twitter.hidden = false;
	}

	const trailerFrame = document.querySelector("[data-trailer-frame]");
	if (trailerFrame && safeExternalUrl(config.trailerUrl) && isEmbeddable(config.trailerUrl)) {
		const simulationWindow = trailerFrame.querySelector(".simulation-window");
		if (simulationWindow) {
			const iframe = document.createElement("iframe");
			iframe.src = embedUrl(config.trailerUrl);
			iframe.title = "Vector Anomaly trailer";
			iframe.loading = "lazy";
			iframe.allowFullscreen = true;
			iframe.setAttribute("allow", "accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture");
			simulationWindow.appendChild(iframe);
		}
	}
}

function initHeader() {
	const header = document.querySelector("[data-header]");
	const integrity = document.querySelector("[data-header-integrity]");
	if (!header) return;

	const updateHeader = () => {
		header.classList.toggle("is-scrolled", window.scrollY > 18);
		if (integrity) {
			const scrollRatio = Math.min(1, window.scrollY / Math.max(1, document.body.scrollHeight - window.innerHeight));
			const value = Math.max(23, Math.round(87 - scrollRatio * 46));
			integrity.textContent = `INTEGRITY: ${String(value).padStart(3, "0")}%`;
		}
	};

	updateHeader();
	window.addEventListener("scroll", updateHeader, { passive: true });
}

function initMobileNav() {
	const toggle = document.querySelector("[data-nav-toggle]");
	const nav = document.querySelector("[data-site-nav]");
	if (!toggle || !nav) return;

	const close = () => {
		toggle.setAttribute("aria-expanded", "false");
		nav.classList.remove("is-open");
		document.body.classList.remove("nav-open");
	};

	toggle.addEventListener("click", () => {
		const open = toggle.getAttribute("aria-expanded") !== "true";
		toggle.setAttribute("aria-expanded", open ? "true" : "false");
		nav.classList.toggle("is-open", open);
		document.body.classList.toggle("nav-open", open);
	});

	nav.querySelectorAll("a").forEach((link) => link.addEventListener("click", close));
	window.addEventListener("keydown", (event) => {
		if (event.key === "Escape") close();
	});
}

function initScrollProgress() {
	const bar = document.querySelector("[data-scroll-progress]");
	if (!bar) return;

	const update = () => {
		const max = Math.max(1, document.documentElement.scrollHeight - window.innerHeight);
		bar.style.width = `${Math.min(100, Math.max(0, (window.scrollY / max) * 100))}%`;
	};

	update();
	window.addEventListener("scroll", update, { passive: true });
}

function initReveal() {
	const revealNodes = [...document.querySelectorAll(".reveal, .reveal-section")];
	if (reduceMotion) {
		revealNodes.forEach((node) => node.classList.add("is-revealed"));
		return;
	}

	document.querySelectorAll(".reveal").forEach((node) => {
		window.setTimeout(() => node.classList.add("is-revealed"), 160);
	});

	const observer = new IntersectionObserver((entries) => {
		for (const entry of entries) {
			if (!entry.isIntersecting) continue;
			entry.target.classList.add("is-revealed");
			observer.unobserve(entry.target);
		}
	}, { threshold: 0.12, rootMargin: "0px 0px -40px 0px" });

	document.querySelectorAll(".reveal-section").forEach((node) => observer.observe(node));
}

function setupCanvas(canvas, draw) {
	if (!canvas) return null;
	const context = canvas.getContext("2d");
	const state = { width: 0, height: 0, ratio: 1 };

	const resize = () => {
		const rect = canvas.getBoundingClientRect();
		state.width = Math.max(1, rect.width);
		state.height = Math.max(1, rect.height);
		state.ratio = Math.min(2, window.devicePixelRatio || 1);
		canvas.width = Math.floor(state.width * state.ratio);
		canvas.height = Math.floor(state.height * state.ratio);
		context.setTransform(state.ratio, 0, 0, state.ratio, 0, 0);
		draw(context, state, performance.now(), 0);
	};

	window.addEventListener("resize", resize, { passive: true });
	resize();
	return { context, state, resize };
}

function initHeroField() {
	const canvas = document.getElementById("hero-field-canvas");
	const particles = Array.from({ length: 88 }, (_, index) => ({
		angle: index * 0.42,
		radius: 120 + (index % 18) * 31,
		speed: 0.00005 + (index % 7) * 0.000008,
		size: 1 + (index % 3) * 0.55,
	}));
	let lastTime = performance.now();
	let controller;

	const draw = (ctx, size, now, delta) => {
		ctx.clearRect(0, 0, size.width, size.height);
		ctx.fillStyle = "#000000";
		ctx.fillRect(0, 0, size.width, size.height);

		const centerX = size.width * 0.5;
		const centerY = size.height * 0.47;
		const pulse = 1 + Math.sin(now * 0.001) * 0.025;

		ctx.strokeStyle = "rgba(255,255,255,0.08)";
		ctx.lineWidth = 1;
		for (let radius = 110; radius < Math.max(size.width, size.height); radius += 110) {
			ctx.beginPath();
			ctx.arc(centerX, centerY, radius * pulse, 0, Math.PI * 2);
			ctx.stroke();
		}

		ctx.strokeStyle = "rgba(101,255,231,0.16)";
		ctx.beginPath();
		ctx.arc(centerX, centerY, 62 + Math.sin(now * 0.002) * 4, 0, Math.PI * 2);
		ctx.stroke();

		ctx.fillStyle = "rgba(101,255,231,0.74)";
		ctx.beginPath();
		ctx.arc(centerX, centerY, 3.5, 0, Math.PI * 2);
		ctx.fill();

		for (const particle of particles) {
			if (!reduceMotion) particle.angle += delta * particle.speed;
			const wobble = Math.sin(particle.angle * 2.1 + now * 0.0007) * 12;
			const x = centerX + Math.cos(particle.angle) * (particle.radius + wobble);
			const y = centerY + Math.sin(particle.angle * 0.82) * (particle.radius * 0.54 + wobble);
			ctx.fillStyle = particle.radius % 3 === 0 ? "rgba(255,202,95,0.48)" : "rgba(255,255,255,0.42)";
			ctx.fillRect(x - particle.size * 0.5, y - particle.size * 0.5, particle.size, particle.size);
		}

		ctx.strokeStyle = "rgba(255,74,50,0.25)";
		ctx.setLineDash([8, 14]);
		ctx.beginPath();
		ctx.moveTo(centerX - 520, centerY + 190);
		ctx.quadraticCurveTo(centerX - 130, centerY - 160, centerX + 520, centerY + 120);
		ctx.stroke();
		ctx.setLineDash([]);
	};

	const tick = (now) => {
		const delta = Math.min(40, now - lastTime);
		lastTime = now;
		if (controller) draw(controller.context, controller.state, now, delta);
		window.requestAnimationFrame(tick);
	};

	controller = setupCanvas(canvas, draw);
	if (controller) window.requestAnimationFrame(tick);
}

function initTrailerSimulation() {
	const canvas = document.getElementById("trailer-sim-canvas");
	const points = Array.from({ length: 34 }, (_, index) => ({
		angle: index * 0.34,
		radius: 70 + (index % 11) * 20,
	}));
	let lastTime = performance.now();
	let playerAngle = 0;
	let controller;

	const draw = (ctx, size, now, delta) => {
		ctx.clearRect(0, 0, size.width, size.height);
		ctx.fillStyle = "#000000";
		ctx.fillRect(0, 0, size.width, size.height);
		const cx = size.width * 0.5;
		const cy = size.height * 0.5;

		ctx.strokeStyle = "rgba(255,255,255,0.06)";
		ctx.lineWidth = 1;
		for (let x = 0; x <= size.width; x += 36) {
			ctx.beginPath();
			ctx.moveTo(x, 0);
			ctx.lineTo(x, size.height);
			ctx.stroke();
		}
		for (let y = 0; y <= size.height; y += 36) {
			ctx.beginPath();
			ctx.moveTo(0, y);
			ctx.lineTo(size.width, y);
			ctx.stroke();
		}

		ctx.strokeStyle = "rgba(101,255,231,0.24)";
		for (let r = 54; r < 220; r += 48) {
			ctx.beginPath();
			ctx.arc(cx, cy, r + Math.sin(now * 0.001 + r) * 3, 0, Math.PI * 2);
			ctx.stroke();
		}

		ctx.fillStyle = "rgba(0,0,0,1)";
		ctx.strokeStyle = "rgba(255,255,255,0.8)";
		ctx.lineWidth = 1;
		ctx.beginPath();
		ctx.arc(cx, cy, 18, 0, Math.PI * 2);
		ctx.fill();
		ctx.stroke();

		if (!reduceMotion) playerAngle += delta * 0.00125;
		const player = {
			x: cx + Math.cos(playerAngle) * 142,
			y: cy + Math.sin(playerAngle * 1.08) * 86,
		};

		ctx.setLineDash([5, 8]);
		ctx.strokeStyle = "rgba(255,202,95,0.72)";
		ctx.beginPath();
		for (let i = 0; i < 80; i += 1) {
			const a = playerAngle - i * 0.035;
			const x = cx + Math.cos(a) * 142;
			const y = cy + Math.sin(a * 1.08) * 86;
			if (i === 0) ctx.moveTo(x, y);
			else ctx.lineTo(x, y);
		}
		ctx.stroke();
		ctx.setLineDash([]);

		for (const point of points) {
			if (!reduceMotion) point.angle += delta * 0.00012;
			const x = cx + Math.cos(point.angle) * point.radius;
			const y = cy + Math.sin(point.angle * 0.9) * point.radius * 0.62;
			ctx.fillStyle = point.radius > 180 ? "rgba(255,74,50,0.52)" : "rgba(101,255,231,0.42)";
			ctx.fillRect(x - 1.5, y - 1.5, 3, 3);
		}

		ctx.fillStyle = "#ffffff";
		ctx.beginPath();
		ctx.arc(player.x, player.y, 5, 0, Math.PI * 2);
		ctx.fill();
		ctx.strokeStyle = "rgba(101,255,231,0.9)";
		ctx.stroke();
	};

	const tick = (now) => {
		const delta = Math.min(40, now - lastTime);
		lastTime = now;
		if (controller) draw(controller.context, controller.state, now, delta);
		window.requestAnimationFrame(tick);
	};

	controller = setupCanvas(canvas, draw);
	if (controller) window.requestAnimationFrame(tick);
}

function initSandbox() {
	const canvas = document.getElementById("slingshot-sandbox");
	if (!canvas) return;

	const speedNode = document.querySelector("[data-sandbox-speed]");
	const distanceNode = document.querySelector("[data-sandbox-distance]");
	const statusNode = document.querySelector("[data-sandbox-status]");
	const gradeNode = document.querySelector("[data-sandbox-grade]");
	const resetButton = document.querySelector("[data-sandbox-reset]");
	const demoButton = document.querySelector("[data-sandbox-demo]");

	const ctx = canvas.getContext("2d");
	const state = {
		width: 1,
		height: 1,
		ratio: 1,
		center: { x: 0, y: 0 },
		pocket: { x: 0, y: 0, radius: 74 },
		probe: { x: 0, y: 0, vx: 0, vy: 0 },
		trail: [],
		dragging: false,
		dragPoint: { x: 0, y: 0 },
		running: false,
		minDistance: Infinity,
		angleTravel: 0,
		lastAngle: 0,
		burst: 0,
		grade: "WAITING",
	};

	function resize() {
		const rect = canvas.getBoundingClientRect();
		state.width = Math.max(1, rect.width);
		state.height = Math.max(1, rect.height);
		state.ratio = Math.min(2, window.devicePixelRatio || 1);
		canvas.width = Math.floor(state.width * state.ratio);
		canvas.height = Math.floor(state.height * state.ratio);
		ctx.setTransform(state.ratio, 0, 0, state.ratio, 0, 0);
		resetProbe();
	}

	function resetProbe() {
		state.center = { x: state.width * 0.52, y: state.height * 0.5 };
		state.pocket = { x: state.width * 0.73, y: state.height * 0.36, radius: Math.min(84, state.width * 0.16) };
		state.probe = { x: state.width * 0.23, y: state.height * 0.58, vx: 0, vy: 0 };
		state.trail = [];
		state.dragging = false;
		state.running = false;
		state.minDistance = Infinity;
		state.angleTravel = 0;
		state.lastAngle = Math.atan2(state.probe.y - state.center.y, state.probe.x - state.center.x);
		state.burst = 0;
		state.grade = "WAITING";
		updateHud("DRAG FROM PROBE TO LAUNCH");
		drawSandbox();
	}

	function updateHud(status) {
		const speed = Math.sqrt(state.probe.vx * state.probe.vx + state.probe.vy * state.probe.vy);
		if (speedNode) speedNode.textContent = `VELOCITY: ${String(Math.round(speed * 100)).padStart(3, "0")}`;
		if (distanceNode) {
			const distance = Number.isFinite(state.minDistance) ? Math.round(state.minDistance) : "--";
			distanceNode.textContent = `PERIAPSIS: ${distance}`;
		}
		if (statusNode && status) statusNode.textContent = status;
		if (gradeNode) gradeNode.textContent = `GRADE: ${state.grade}`;
	}

	function pointerPosition(event) {
		const rect = canvas.getBoundingClientRect();
		return {
			x: event.clientX - rect.left,
			y: event.clientY - rect.top,
		};
	}

	function launchFrom(point) {
		const power = 0.026;
		state.probe.vx = (state.probe.x - point.x) * power;
		state.probe.vy = (state.probe.y - point.y) * power;
		state.running = true;
		state.dragging = false;
		state.trail = [];
		state.minDistance = Infinity;
		state.angleTravel = 0;
		state.grade = "ACTIVE";
		updateHud("VECTOR COMMITTED");
	}

	canvas.addEventListener("pointerdown", (event) => {
		const point = pointerPosition(event);
		state.dragging = true;
		state.dragPoint = point;
		state.running = false;
		canvas.setPointerCapture(event.pointerId);
		updateHud("RELEASE TO LAUNCH");
		drawSandbox();
	});

	canvas.addEventListener("pointermove", (event) => {
		if (!state.dragging) return;
		state.dragPoint = pointerPosition(event);
		drawSandbox();
	});

	canvas.addEventListener("pointerup", (event) => {
		if (!state.dragging) return;
		launchFrom(pointerPosition(event));
	});

	resetButton?.addEventListener("click", resetProbe);
	demoButton?.addEventListener("click", () => {
		state.dragPoint = { x: state.probe.x + 104, y: state.probe.y + 34 };
		launchFrom(state.dragPoint);
	});

	function simulatePrediction(start, velocity) {
		const points = [];
		const probe = { x: start.x, y: start.y, vx: velocity.vx, vy: velocity.vy };
		for (let i = 0; i < 170; i += 1) {
			applyPhysics(probe, 12);
			probe.x += probe.vx * 12;
			probe.y += probe.vy * 12;
			if (i % 3 === 0) points.push({ x: probe.x, y: probe.y });
			if (probe.x < -80 || probe.x > state.width + 80 || probe.y < -80 || probe.y > state.height + 80) break;
		}
		return points;
	}

	function applyPhysics(probe, dt) {
		const dx = state.center.x - probe.x;
		const dy = state.center.y - probe.y;
		const distanceSq = Math.max(900, dx * dx + dy * dy);
		const distance = Math.sqrt(distanceSq);
		const force = 4200 / distanceSq;
		const pocketDx = state.pocket.x - probe.x;
		const pocketDy = state.pocket.y - probe.y;
		const pocketDistance = Math.sqrt(pocketDx * pocketDx + pocketDy * pocketDy);
		const timeScale = pocketDistance < state.pocket.radius ? 0.44 : 1;
		probe.vx += (dx / distance) * force * dt * timeScale;
		probe.vy += (dy / distance) * force * dt * timeScale;
		probe.vx *= 0.9994;
		probe.vy *= 0.9994;
	}

	function updateSandbox(delta) {
		if (!state.running || state.dragging) return;
		const steps = Math.max(1, Math.ceil(delta / 12));
		const dt = Math.min(16, delta / steps) * 0.9;
		for (let i = 0; i < steps; i += 1) {
			applyPhysics(state.probe, dt);
			state.probe.x += state.probe.vx * dt;
			state.probe.y += state.probe.vy * dt;
			state.trail.push({ x: state.probe.x, y: state.probe.y });
			if (state.trail.length > 120) state.trail.shift();

			const dx = state.probe.x - state.center.x;
			const dy = state.probe.y - state.center.y;
			const dist = Math.sqrt(dx * dx + dy * dy);
			state.minDistance = Math.min(state.minDistance, dist);
			const angle = Math.atan2(dy, dx);
			let diff = angle - state.lastAngle;
			if (diff > Math.PI) diff -= Math.PI * 2;
			if (diff < -Math.PI) diff += Math.PI * 2;
			state.angleTravel += Math.abs(diff);
			state.lastAngle = angle;

			const speed = Math.sqrt(state.probe.vx * state.probe.vx + state.probe.vy * state.probe.vy);
			if (state.grade !== "APEX" && state.minDistance < 110 && state.angleTravel > 3.25 && dist > 190 && speed > 0.8) {
				state.grade = state.minDistance < 78 ? "APEX" : "PERFECT";
				state.burst = 1;
				updateHud("RESONANCE FLASH VERIFIED");
			}

			if (state.probe.x < -160 || state.probe.x > state.width + 160 || state.probe.y < -160 || state.probe.y > state.height + 160) {
				state.running = false;
				if (state.grade === "ACTIVE") state.grade = "ESCAPED";
				updateHud("PROBE EXITED FIELD");
			}
		}
		state.burst = Math.max(0, state.burst - delta * 0.0014);
	}

	function drawSandbox() {
		ctx.clearRect(0, 0, state.width, state.height);
		ctx.fillStyle = "#000000";
		ctx.fillRect(0, 0, state.width, state.height);

		ctx.strokeStyle = "rgba(255,255,255,0.06)";
		ctx.lineWidth = 1;
		for (let x = 0; x <= state.width; x += 34) {
			ctx.beginPath();
			ctx.moveTo(x, 0);
			ctx.lineTo(x, state.height);
			ctx.stroke();
		}
		for (let y = 0; y <= state.height; y += 34) {
			ctx.beginPath();
			ctx.moveTo(0, y);
			ctx.lineTo(state.width, y);
			ctx.stroke();
		}

		ctx.strokeStyle = "rgba(255,202,95,0.42)";
		ctx.setLineDash([6, 9]);
		ctx.beginPath();
		ctx.arc(state.pocket.x, state.pocket.y, state.pocket.radius, 0, Math.PI * 2);
		ctx.stroke();
		ctx.setLineDash([]);
		ctx.fillStyle = "rgba(255,202,95,0.035)";
		ctx.beginPath();
		ctx.arc(state.pocket.x, state.pocket.y, state.pocket.radius, 0, Math.PI * 2);
		ctx.fill();

		for (let r = 42; r <= 150; r += 36) {
			ctx.strokeStyle = r === 78 ? "rgba(101,255,231,0.36)" : "rgba(101,255,231,0.18)";
			ctx.beginPath();
			ctx.arc(state.center.x, state.center.y, r, 0, Math.PI * 2);
			ctx.stroke();
		}

		ctx.fillStyle = "#000000";
		ctx.strokeStyle = "#ffffff";
		ctx.beginPath();
		ctx.arc(state.center.x, state.center.y, 16, 0, Math.PI * 2);
		ctx.fill();
		ctx.stroke();

		if (state.trail.length > 1) {
			ctx.strokeStyle = "rgba(255,202,95,0.62)";
			ctx.lineWidth = 2;
			ctx.beginPath();
			for (let i = 0; i < state.trail.length; i += 1) {
				const p = state.trail[i];
				if (i === 0) ctx.moveTo(p.x, p.y);
				else ctx.lineTo(p.x, p.y);
			}
			ctx.stroke();
		}

		if (state.dragging) {
			const velocity = {
				vx: (state.probe.x - state.dragPoint.x) * 0.026,
				vy: (state.probe.y - state.dragPoint.y) * 0.026,
			};
			const prediction = simulatePrediction(state.probe, velocity);
			ctx.fillStyle = "rgba(101,255,231,0.75)";
			for (const point of prediction) {
				ctx.fillRect(point.x - 1.5, point.y - 1.5, 3, 3);
			}

			ctx.strokeStyle = "rgba(255,255,255,0.72)";
			ctx.beginPath();
			ctx.moveTo(state.probe.x, state.probe.y);
			ctx.lineTo(state.dragPoint.x, state.dragPoint.y);
			ctx.stroke();
		}

		if (state.burst > 0) {
			const alpha = Math.min(0.28, state.burst * 0.28);
			ctx.strokeStyle = `rgba(101,255,231,${alpha})`;
			ctx.lineWidth = 2;
			for (let i = 0; i < 3; i += 1) {
				ctx.beginPath();
				ctx.arc(state.probe.x, state.probe.y, 28 + i * 24 + (1 - state.burst) * 36, 0, Math.PI * 2);
				ctx.stroke();
			}
		}

		ctx.fillStyle = "#ffffff";
		ctx.beginPath();
		ctx.arc(state.probe.x, state.probe.y, 6, 0, Math.PI * 2);
		ctx.fill();
		ctx.strokeStyle = "rgba(101,255,231,0.95)";
		ctx.stroke();
	}

	let last = performance.now();
	function tick(now) {
		const delta = Math.min(40, now - last);
		last = now;
		if (!reduceMotion) updateSandbox(delta);
		drawSandbox();
		updateHud();
		window.requestAnimationFrame(tick);
	}

	window.addEventListener("resize", resize, { passive: true });
	resize();
	window.requestAnimationFrame(tick);
}

function initBossLog() {
	const cards = [...document.querySelectorAll(".boss-card")];
	const readout = document.querySelector("[data-mutation-readout]");
	if (!cards.length || !readout) return;

	const setActive = (card) => {
		cards.forEach((item) => item.classList.toggle("is-active", item === card));
		readout.textContent = `${card.dataset.boss}: ${card.dataset.law}`;
	};

	cards.forEach((card) => {
		card.addEventListener("mouseenter", () => setActive(card));
		card.addEventListener("focus", () => setActive(card));
	});
	setActive(cards[0]);
}

function initClipConsole() {
	const track = document.querySelector("[data-clip-track]");
	const cards = [...document.querySelectorAll(".clip-card")];
	const prev = document.querySelector("[data-clip-prev]");
	const next = document.querySelector("[data-clip-next]");
	const status = document.querySelector("[data-copy-status]");
	if (!track || !cards.length) return;
	let index = 0;

	const update = () => {
		track.style.transform = `translateX(${-index * 100}%)`;
		cards.forEach((card, i) => card.classList.toggle("is-active", i === index));
	};

	prev?.addEventListener("click", () => {
		index = (index + cards.length - 1) % cards.length;
		update();
	});

	next?.addEventListener("click", () => {
		index = (index + 1) % cards.length;
		update();
	});

	document.querySelectorAll("[data-copy-seed]").forEach((button) => {
		button.addEventListener("click", async () => {
			const card = button.closest(".clip-card");
			const seed = card?.dataset.seed || "";
			if (!seed) return;
			try {
				await navigator.clipboard.writeText(seed);
			} catch (error) {
				const temp = document.createElement("textarea");
				temp.value = seed;
				document.body.appendChild(temp);
				temp.select();
				document.execCommand("copy");
				temp.remove();
			}
			if (status) status.textContent = `COPY BUFFER: ${seed}`;
		});
	});

	update();
}

const codexEntries = {
	"vectorfall": {
		title: "VECTORFALL",
		description: "Vectorfall is the player-facing read of high-speed collapse: velocity, gravity, and threat direction converge into a survivable route.",
		points: [
			"Speed is information, not decoration.",
			"Clean tangent exits convert danger into recovery.",
			"The ship remains visible even during late-run escalation.",
		],
		mode: 0,
	},
	"arena-laws": {
		title: "ARENA LAWS",
		description: "Arena laws are seeded physics profiles. They change decision space before they change spectacle.",
		points: [
			"Mirror Well biases inversion and rebound.",
			"Tidal Skein increases moving tide pressure.",
			"Harmonic Boneyard rewards curved projectile routing.",
		],
		mode: 1,
	},
	"resonance": {
		title: "RESONANCE FIELDS",
		description: "Overlapping gravity sources produce tactical field rules with action-language labels.",
		points: [
			"Compression pulls inward.",
			"Inversion pushes outward.",
			"Slipstream, temporal scar, and harmonic orbit change routing.",
		],
		mode: 2,
	},
	"temporal": {
		title: "TEMPORAL SCARS",
		description: "Temporal scars are local time wounds. They slow threats without stealing player motion.",
		points: [
			"Time dilation is local by default.",
			"Projectile vectors bend through slow pockets.",
			"Pink-wall overload is capped by visual budgets.",
		],
		mode: 3,
	},
	"gravity-scars": {
		title: "GRAVITY SCARS",
		description: "Gravity scars are short-lived marks where spacetime was damaged by combat or mastery.",
		points: [
			"Curvature scars alter local drift.",
			"Inversion wakes push bodies away.",
			"Harmonic fractures can open tracked spacetime tears.",
		],
		mode: 4,
	},
};

function initCodex() {
	const title = document.querySelector("[data-codex-title]");
	const description = document.querySelector("[data-codex-description]");
	const points = document.querySelector("[data-codex-points]");
	const tabs = [...document.querySelectorAll("[data-codex-tab]")];
	const canvas = document.getElementById("codex-diagram");
	let active = "vectorfall";
	let controller;

	function renderEntry(key) {
		const entry = codexEntries[key] || codexEntries.vectorfall;
		active = key;
		if (title) title.textContent = entry.title;
		if (description) description.textContent = entry.description;
		if (points) {
			points.innerHTML = "";
			entry.points.forEach((point) => {
				const item = document.createElement("li");
				item.textContent = point;
				points.appendChild(item);
			});
		}
		tabs.forEach((tab) => tab.setAttribute("aria-selected", String(tab.dataset.codexTab === key)));
		drawCodexDiagram();
	}

	function drawCodexDiagram() {
		if (!controller) return;
		const { context: ctx, state: size } = controller;
		const entry = codexEntries[active] || codexEntries.vectorfall;
		ctx.clearRect(0, 0, size.width, size.height);
		ctx.fillStyle = "#000000";
		ctx.fillRect(0, 0, size.width, size.height);
		ctx.strokeStyle = "rgba(255,255,255,0.07)";
		for (let x = 0; x < size.width; x += 32) {
			ctx.beginPath();
			ctx.moveTo(x, 0);
			ctx.lineTo(x, size.height);
			ctx.stroke();
		}
		for (let y = 0; y < size.height; y += 32) {
			ctx.beginPath();
			ctx.moveTo(0, y);
			ctx.lineTo(size.width, y);
			ctx.stroke();
		}

		const cx = size.width * 0.5;
		const cy = size.height * 0.52;
		ctx.lineWidth = 1.5;

		if (entry.mode === 0) {
			ctx.strokeStyle = "rgba(255,202,95,0.8)";
			ctx.beginPath();
			ctx.moveTo(cx - 220, cy + 86);
			ctx.quadraticCurveTo(cx - 70, cy - 120, cx + 220, cy + 50);
			ctx.stroke();
		} else if (entry.mode === 1) {
			ctx.strokeStyle = "rgba(101,255,231,0.62)";
			for (let i = 0; i < 5; i += 1) {
				ctx.strokeRect(cx - 150 + i * 18, cy - 90 + i * 16, 260 - i * 24, 160 - i * 22);
			}
		} else if (entry.mode === 2) {
			ctx.strokeStyle = "rgba(101,255,231,0.7)";
			ctx.beginPath();
			ctx.arc(cx - 60, cy, 84, 0, Math.PI * 2);
			ctx.stroke();
			ctx.strokeStyle = "rgba(255,202,95,0.7)";
			ctx.beginPath();
			ctx.arc(cx + 60, cy, 84, 0, Math.PI * 2);
			ctx.stroke();
		} else if (entry.mode === 3) {
			ctx.strokeStyle = "rgba(255,74,50,0.72)";
			for (let i = 0; i < 7; i += 1) {
				ctx.beginPath();
				ctx.moveTo(cx - 190, cy - 70 + i * 24);
				ctx.quadraticCurveTo(cx, cy - 120 + i * 34, cx + 190, cy - 70 + i * 24);
				ctx.stroke();
			}
		} else {
			ctx.strokeStyle = "rgba(255,255,255,0.68)";
			ctx.beginPath();
			ctx.moveTo(cx - 170, cy - 80);
			ctx.lineTo(cx - 42, cy - 12);
			ctx.lineTo(cx - 120, cy + 92);
			ctx.lineTo(cx + 24, cy + 16);
			ctx.lineTo(cx + 112, cy + 88);
			ctx.lineTo(cx + 174, cy - 76);
			ctx.stroke();
		}

		ctx.fillStyle = "rgba(101,255,231,0.85)";
		ctx.beginPath();
		ctx.arc(cx, cy, 5, 0, Math.PI * 2);
		ctx.fill();
	}

	controller = setupCanvas(canvas, () => drawCodexDiagram());
	tabs.forEach((tab) => tab.addEventListener("click", () => renderEntry(tab.dataset.codexTab)));
	renderEntry(active);
	window.addEventListener("resize", drawCodexDiagram, { passive: true });
}

initSiteConfig();
initHeader();
initMobileNav();
initScrollProgress();
initReveal();
initHeroField();
initTrailerSimulation();
initSandbox();
initBossLog();
initClipConsole();
initCodex();
