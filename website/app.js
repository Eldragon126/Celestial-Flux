/* VECTOR ANOMALY — site interactions + orbit visuals */

const config = window.VECTOR_ANOMALY_SITE || {};
const prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

// ==================== SITE CONFIG ====================

function initSiteConfig() {
	const steamLink = document.querySelector("[data-steam-link]");
	const steamBadge = document.querySelector("[data-steam-badge]");
	const pressEmail = document.querySelector("[data-press-email]");
	const seedDisplay = document.querySelector("[data-seed-display]");
	const yearNode = document.querySelector("[data-year]");

	if (yearNode) {
		yearNode.textContent = String(new Date().getFullYear());
	}

	if (seedDisplay && config.demoSeed) {
		seedDisplay.textContent = config.demoSeed;
	}

	if (pressEmail && config.pressEmail) {
		pressEmail.href = `mailto:${config.pressEmail}`;
		pressEmail.textContent = config.pressEmail;
	}

	if (config.steamUrl) {
		if (steamLink) {
			steamLink.href = config.steamUrl;
			steamLink.hidden = false;
			steamLink.textContent = "Steam Page";
		}
		if (steamBadge) {
			steamBadge.textContent = "Wishlist on Steam";
			steamBadge.style.cursor = "pointer";
			steamBadge.addEventListener("click", () => {
				window.open(config.steamUrl, "_blank", "noopener");
			});
		}
		const wishlistCta = document.querySelector("[data-wishlist-cta]");
		if (wishlistCta) {
			wishlistCta.href = config.steamUrl;
			wishlistCta.textContent = "Wishlist on Steam";
			wishlistCta.setAttribute("target", "_blank");
			wishlistCta.setAttribute("rel", "noopener");
		}
	}
}

// ==================== HERO CANVAS ====================

const heroCanvas = document.getElementById("vectorfall-canvas");
let heroCtx = null;
let heroRunning = true;
let heroMouse = { x: 0.62, y: 0.48 };

const gravityCenter = { x: 0, y: 0 };
const wells = [
	{ radius: 88, color: "rgba(98,255,224,0.9)", phase: 0 },
	{ radius: 156, color: "rgba(255,200,87,0.75)", phase: 1.4 },
	{ radius: 238, color: "rgba(255,77,54,0.65)", phase: 2.8 },
];

const player = { angle: 0.6, distance: 210, speed: 0.22, trail: [] };
const particles = Array.from({ length: 72 }, (_, index) => ({
	angle: index * 0.47,
	distance: 110 + (index % 17) * 28,
	speed: 0.12 + (index % 6) * 0.016,
	trail: [],
}));

const threats = Array.from({ length: 6 }, (_, index) => ({
	angle: index * 1.1 + 0.4,
	distance: 320 + index * 40,
	speed: 0.08 + index * 0.01,
}));

let heroWidth = 0;
let heroHeight = 0;
let heroLastTime = performance.now();
let apexFlash = 0;

function initHeroCanvas() {
	if (!heroCanvas) {
		return;
	}
	heroCtx = heroCanvas.getContext("2d");
	window.addEventListener("resize", resizeHero);
	document.addEventListener("visibilitychange", () => {
		heroRunning = !document.hidden;
	});
	heroCanvas.addEventListener("mousemove", (event) => {
		const rect = heroCanvas.getBoundingClientRect();
		heroMouse.x = (event.clientX - rect.left) / rect.width;
		heroMouse.y = (event.clientY - rect.top) / rect.height;
	});
	resizeHero();
	requestAnimationFrame(tickHero);
}

function resizeHero() {
	if (!heroCanvas || !heroCtx) {
		return;
	}
	const ratio = window.devicePixelRatio || 1;
	heroWidth = heroCanvas.clientWidth;
	heroHeight = heroCanvas.clientHeight;
	heroCanvas.width = Math.floor(heroWidth * ratio);
	heroCanvas.height = Math.floor(heroHeight * ratio);
	heroCtx.setTransform(ratio, 0, 0, ratio, 0, 0);
	gravityCenter.x = heroWidth * (0.55 + (heroMouse.x - 0.62) * 0.08);
	gravityCenter.y = heroHeight * (0.48 + (heroMouse.y - 0.48) * 0.06);
}

function orbitPosition(angle, distance, center = gravityCenter) {
	return {
		x: center.x + Math.cos(angle) * distance,
		y: center.y + Math.sin(angle * 1.06) * distance * 0.64,
	};
}

function drawTrail(ctx, trail, color, width) {
	if (trail.length < 2) {
		return;
	}
	ctx.beginPath();
	for (let index = 0; index < trail.length; index += 1) {
		const point = trail[index];
		if (index === 0) {
			ctx.moveTo(point.x, point.y);
		} else {
			ctx.lineTo(point.x, point.y);
		}
	}
	ctx.strokeStyle = color;
	ctx.lineWidth = width;
	ctx.stroke();
}

function drawHeroGrid(ctx) {
	const step = 48;
	ctx.strokeStyle = "rgba(98,255,224,0.04)";
	ctx.lineWidth = 1;
	for (let x = gravityCenter.x % step; x < heroWidth; x += step) {
		ctx.beginPath();
		ctx.moveTo(x, 0);
		ctx.lineTo(x, heroHeight);
		ctx.stroke();
	}
	for (let y = gravityCenter.y % step; y < heroHeight; y += step) {
		ctx.beginPath();
		ctx.moveTo(0, y);
		ctx.lineTo(heroWidth, y);
		ctx.stroke();
	}
}

function drawWell(ctx, well, time) {
	const pulse = Math.sin(time * 0.0012 + well.phase) * 0.1 + 1;
	ctx.beginPath();
	ctx.arc(gravityCenter.x, gravityCenter.y, well.radius * pulse, 0, Math.PI * 2);
	ctx.strokeStyle = well.color;
	ctx.lineWidth = 1.4;
	ctx.stroke();
}

function drawResonancePulse(ctx, time) {
	if (apexFlash <= 0) {
		return;
	}
	const alpha = apexFlash * 0.35;
	ctx.beginPath();
	ctx.arc(gravityCenter.x, gravityCenter.y, 120 + (1 - apexFlash) * 80, 0, Math.PI * 2);
	ctx.strokeStyle = `rgba(255,200,87,${alpha})`;
	ctx.lineWidth = 2;
	ctx.stroke();
}

function drawThreat(ctx, threat, time) {
	const position = orbitPosition(threat.angle, threat.distance);
	ctx.beginPath();
	ctx.moveTo(position.x, position.y);
	const toward = {
		x: gravityCenter.x - position.x,
		y: gravityCenter.y - position.y,
	};
	const len = Math.hypot(toward.x, toward.y) || 1;
	ctx.lineTo(
		position.x + (toward.x / len) * 36,
		position.y + (toward.y / len) * 36
	);
	ctx.strokeStyle = "rgba(255,77,54,0.55)";
	ctx.lineWidth = 1.2;
	ctx.stroke();
	ctx.beginPath();
	ctx.arc(position.x, position.y, 2.5, 0, Math.PI * 2);
	ctx.fillStyle = "rgba(255,77,54,0.85)";
	ctx.fill();
}

function drawHeroPlayer(ctx, time) {
	const position = orbitPosition(player.angle, player.distance);
	const tangent = {
		x: -Math.sin(player.angle),
		y: Math.cos(player.angle * 1.06) * 0.64,
	};
	const velocityScale = 42 + Math.sin(time * 0.002) * 8;
	const velocityEnd = {
		x: position.x + tangent.x * velocityScale,
		y: position.y + tangent.y * velocityScale,
	};

	player.trail.push(position);
	if (player.trail.length > 28) {
		player.trail.shift();
	}

	drawTrail(ctx, player.trail, "rgba(255,200,87,0.5)", 2.2);

	ctx.beginPath();
	ctx.moveTo(position.x, position.y);
	ctx.quadraticCurveTo(
		(position.x + velocityEnd.x) * 0.5,
		(position.y + velocityEnd.y) * 0.5,
		velocityEnd.x,
		velocityEnd.y
	);
	ctx.strokeStyle = "rgba(255,200,87,0.7)";
	ctx.lineWidth = 1.6;
	ctx.stroke();

	ctx.beginPath();
	ctx.arc(position.x, position.y, 4.5, 0, Math.PI * 2);
	ctx.fillStyle = "#f4fbff";
	ctx.fill();
	ctx.strokeStyle = "rgba(98,255,224,0.9)";
	ctx.lineWidth = 1.5;
	ctx.stroke();
}

function drawHeroParticle(ctx, particle, time) {
	const wobble = Math.sin(time * 0.001 + particle.angle * 1.6) * 18;
	const position = orbitPosition(particle.angle, particle.distance + wobble);
	particle.trail.push(position);
	if (particle.trail.length > 14) {
		particle.trail.shift();
	}
	drawTrail(ctx, particle.trail, "rgba(98,255,224,0.16)", 1);
	ctx.beginPath();
	ctx.arc(position.x, position.y, 2, 0, Math.PI * 2);
	ctx.fillStyle = "rgba(244,251,255,0.7)";
	ctx.fill();
}

function drawEscapeArc(ctx) {
	ctx.beginPath();
	ctx.moveTo(gravityCenter.x - 480, gravityCenter.y + 200);
	ctx.quadraticCurveTo(
		gravityCenter.x - 120,
		gravityCenter.y - 180,
		gravityCenter.x + 420,
		gravityCenter.y + 100
	);
	ctx.strokeStyle = "rgba(255,77,54,0.35)";
	ctx.setLineDash([6, 10]);
	ctx.lineWidth = 1.5;
	ctx.stroke();
	ctx.setLineDash([]);
}

function drawHeroFrame(time) {
	if (!heroCtx) {
		return;
	}
	heroCtx.clearRect(0, 0, heroWidth, heroHeight);
	heroCtx.fillStyle = "#05070a";
	heroCtx.fillRect(0, 0, heroWidth, heroHeight);
	drawHeroGrid(heroCtx);
	for (const well of wells) {
		drawWell(heroCtx, well, time);
	}
	drawResonancePulse(heroCtx, time);
	drawEscapeArc(heroCtx);
	for (const particle of particles) {
		drawHeroParticle(heroCtx, particle, time);
	}
	for (const threat of threats) {
		drawThreat(heroCtx, threat, time);
	}
	drawHeroPlayer(heroCtx, time);
}

function tickHero(now) {
	if (heroRunning && heroCtx) {
		const delta = Math.min(now - heroLastTime, 40);
		heroLastTime = now;

		if (!prefersReducedMotion) {
			player.angle += delta * 0.00009 * player.speed;
			for (const particle of particles) {
				particle.angle += delta * 0.00007 * particle.speed;
			}
			for (const threat of threats) {
				threat.angle += delta * 0.00005 * threat.speed;
			}
			gravityCenter.x = heroWidth * (0.55 + (heroMouse.x - 0.62) * 0.08);
			gravityCenter.y = heroHeight * (0.48 + (heroMouse.y - 0.48) * 0.06);

			if (Math.sin(player.angle * 3.2) > 0.97) {
				apexFlash = 1;
			}
		}

		if (apexFlash > 0) {
			apexFlash = Math.max(0, apexFlash - 0.02);
		}

		drawHeroFrame(now);
		updateFpsTelemetry();
	}

	requestAnimationFrame(tickHero);
}

let fpsFrames = 0;
let fpsLastSample = performance.now();

function updateFpsTelemetry() {
	fpsFrames += 1;
	const now = performance.now();
	if (now - fpsLastSample < 500) {
		return;
	}
	const fpsNode = document.querySelector('[data-telemetry="fps"]');
	if (fpsNode) {
		const fps = Math.round((fpsFrames * 1000) / (now - fpsLastSample));
		fpsNode.textContent = String(fps);
	}
	fpsFrames = 0;
	fpsLastSample = now;
}

// ==================== ORBIT DIAGRAM CANVAS ====================

function initOrbitDiagram() {
	const canvas = document.getElementById("orbit-diagram-canvas");
	if (!canvas) {
		return;
	}
	const ctx = canvas.getContext("2d");
	const center = { x: canvas.width / 2, y: canvas.height / 2 };
	let angle = 0.8;

	function drawDiagram() {
		ctx.clearRect(0, 0, canvas.width, canvas.height);
		ctx.fillStyle = "#0a1012";
		ctx.fillRect(0, 0, canvas.width, canvas.height);

		ctx.beginPath();
		ctx.arc(center.x, center.y, 130, 0, Math.PI * 2);
		ctx.strokeStyle = "rgba(98,255,224,0.45)";
		ctx.lineWidth = 1.5;
		ctx.stroke();

		ctx.beginPath();
		ctx.arc(center.x, center.y, 70, 0, Math.PI * 2);
		ctx.strokeStyle = "rgba(255,200,87,0.35)";
		ctx.lineWidth = 1;
		ctx.stroke();

		const playerPos = {
			x: center.x + Math.cos(angle) * 130,
			y: center.y + Math.sin(angle) * 82,
		};

		ctx.beginPath();
		ctx.moveTo(playerPos.x, playerPos.y);
		ctx.lineTo(playerPos.x + 55, playerPos.y - 30);
		ctx.strokeStyle = "rgba(255,200,87,0.85)";
		ctx.lineWidth = 2;
		ctx.stroke();

		ctx.beginPath();
		ctx.arc(center.x, center.y, 8, 0, Math.PI * 2);
		ctx.fillStyle = "rgba(98,255,224,0.3)";
		ctx.fill();

		ctx.beginPath();
		ctx.arc(playerPos.x, playerPos.y, 6, 0, Math.PI * 2);
		ctx.fillStyle = "#f4fbff";
		ctx.fill();

		ctx.beginPath();
		ctx.moveTo(center.x + 90, center.y - 100);
		ctx.quadraticCurveTo(center.x, center.y - 40, playerPos.x - 20, playerPos.y - 10);
		ctx.strokeStyle = "rgba(255,77,54,0.5)";
		ctx.setLineDash([4, 6]);
		ctx.stroke();
		ctx.setLineDash([]);

		if (!prefersReducedMotion) {
			angle += 0.008;
		}
		requestAnimationFrame(drawDiagram);
	}

	drawDiagram();
}

// ==================== UI INTERACTIONS ====================

function initTelemetry() {
	const phaseNode = document.querySelector('[data-telemetry="phase"]');
	const lawsNode = document.querySelector('[data-telemetry="laws"]');
	if (!phaseNode || !lawsNode) {
		return;
	}

	const phases = ["STABLE", "DRIFT", "COLLAPSING", "RUPTURE"];
	const laws = ["HOLDING", "BENDING", "UNSTABLE", "CRITICAL"];
	let index = 0;

	window.setInterval(() => {
		index = (index + 1) % phases.length;
		phaseNode.textContent = phases[index];
		lawsNode.textContent = laws[index];
		lawsNode.classList.toggle("telemetry-warn", index >= 2);
	}, 3200);
}

function initScrollReveal() {
	const nodes = document.querySelectorAll(".reveal");
	if (!nodes.length) {
		return;
	}

	if (prefersReducedMotion || !("IntersectionObserver" in window)) {
		nodes.forEach((node) => node.classList.add("is-visible"));
		return;
	}

	const observer = new IntersectionObserver(
		(entries) => {
			entries.forEach((entry) => {
				if (entry.isIntersecting) {
					entry.target.classList.add("is-visible");
					observer.unobserve(entry.target);
				}
			});
		},
		{ threshold: 0.12, rootMargin: "0px 0px -40px 0px" }
	);

	nodes.forEach((node) => observer.observe(node));
}

function initHeader() {
	const header = document.querySelector("[data-header]");
	if (!header) {
		return;
	}

	const onScroll = () => {
		header.classList.toggle("is-scrolled", window.scrollY > 24);
	};

	onScroll();
	window.addEventListener("scroll", onScroll, { passive: true });
}

function initMobileNav() {
	const toggle = document.querySelector("[data-nav-toggle]");
	const nav = document.querySelector("[data-site-nav]");
	if (!toggle || !nav) {
		return;
	}

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

	nav.querySelectorAll("a").forEach((link) => {
		link.addEventListener("click", close);
	});

	window.addEventListener("keydown", (event) => {
		if (event.key === "Escape") {
			close();
		}
	});
}

function initActiveNav() {
	const navLinks = document.querySelectorAll(".site-nav a[href^='#']");
	const sections = Array.from(navLinks)
		.map((link) => {
			const id = link.getAttribute("href").slice(1);
			const section = document.getElementById(id);
			return section ? { link, section } : null;
		})
		.filter(Boolean);

	if (!sections.length || !("IntersectionObserver" in window)) {
		return;
	}

	const observer = new IntersectionObserver(
		(entries) => {
			entries.forEach((entry) => {
				if (!entry.isIntersecting) {
					return;
				}
				sections.forEach(({ link, section }) => {
					link.classList.toggle("is-active", section === entry.target);
				});
			});
		},
		{ rootMargin: "-45% 0px -45% 0px", threshold: 0 }
	);

	sections.forEach(({ section }) => observer.observe(section));
}

function initCopySeed() {
	const button = document.querySelector("[data-copy-seed]");
	const display = document.querySelector("[data-seed-display]");
	const feedback = document.querySelector("[data-copy-feedback]");
	if (!button || !display) {
		return;
	}

	button.addEventListener("click", async () => {
		const text = display.textContent.trim();
		try {
			await navigator.clipboard.writeText(text);
			if (feedback) {
				feedback.hidden = false;
				window.setTimeout(() => {
					feedback.hidden = true;
				}, 2000);
			}
		} catch {
			window.prompt("Copy challenge seed:", text);
		}
	});
}

function initMailingForm() {
	const form = document.querySelector(".mailing-form");
	if (!form) {
		return;
	}
	form.addEventListener("submit", (event) => {
		event.preventDefault();
		const input = form.querySelector('input[type="email"]');
		const button = form.querySelector("button[type='submit']");
		if (!button) {
			return;
		}
		const original = button.textContent;
		button.textContent = "Signal Logged";
		button.disabled = true;
		if (input) {
			input.value = "";
		}
		window.setTimeout(() => {
			button.textContent = original;
			button.disabled = false;
		}, 2400);
	});
}

// ==================== BOOT ====================

initSiteConfig();
initHeroCanvas();
initOrbitDiagram();
initTelemetry();
initScrollReveal();
initHeader();
initMobileNav();
initActiveNav();
initCopySeed();
initMailingForm();
