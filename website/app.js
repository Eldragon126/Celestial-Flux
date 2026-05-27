/* VECTOR ANOMALY — minimal site behavior */

const config = window.VECTOR_ANOMALY_SITE || {};

function initSiteConfig() {
	const yearNode = document.querySelector("[data-year]");
	if (yearNode) {
		yearNode.textContent = String(new Date().getFullYear());
	}

	const pressEmails = document.querySelectorAll("[data-press-email]");
	pressEmails.forEach((pressEmail) => {
		if (config.pressEmail) {
			pressEmail.href = `mailto:${config.pressEmail}`;
			pressEmail.textContent = config.pressEmail;
		}
	});

	const wishlistCta = document.querySelector("[data-wishlist-cta]");
	const steamLink = document.querySelector("[data-steam-link]");
	const footerSteam = document.querySelector("[data-footer-steam]");
	const footerDiscord = document.querySelector("[data-footer-discord]");
	const trailerLink = document.querySelector("[data-trailer-link]");
	const trailerFrame = document.querySelector("[data-trailer-frame]");

	if (config.steamUrl) {
		if (wishlistCta) {
			wishlistCta.href = config.steamUrl;
			wishlistCta.textContent = "Wishlist on Steam";
			wishlistCta.target = "_blank";
			wishlistCta.rel = "noopener";
		}
		if (steamLink) {
			steamLink.href = config.steamUrl;
			steamLink.hidden = false;
		}
		if (footerSteam) {
			footerSteam.href = config.steamUrl;
			footerSteam.hidden = false;
		}
	}

	if (config.discordUrl && footerDiscord) {
		footerDiscord.href = config.discordUrl;
		footerDiscord.hidden = false;
	}

	if (config.trailerUrl) {
		if (trailerLink) {
			trailerLink.href = config.trailerUrl;
			if (/youtube|youtu\.be|vimeo/.test(config.trailerUrl)) {
				trailerLink.target = "_blank";
				trailerLink.rel = "noopener";
			}
		}
		if (trailerFrame && isEmbeddable(config.trailerUrl)) {
			const idleOverlay = trailerFrame.querySelector("[data-trailer-idle]");
			if (idleOverlay) idleOverlay.classList.add("is-playing");
			const placeholder = trailerFrame.querySelector(".trailer-placeholder");
			if (placeholder) placeholder.remove();
			const iframe = document.createElement("iframe");
			iframe.src = embedUrl(config.trailerUrl);
			iframe.title = "Vector Anomaly trailer";
			iframe.setAttribute("allow", "accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture");
			iframe.allowFullscreen = true;
			iframe.loading = "lazy";
			trailerFrame.appendChild(iframe);
		}
	}
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

function initHeroRotator() {
	if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
		return;
	}
	const lines = document.querySelectorAll(".hero-rotator-line");
	if (lines.length < 2) {
		return;
	}

	let index = 0;
	window.setInterval(() => {
		lines[index].classList.remove("is-active");
		index = (index + 1) % lines.length;
		lines[index].classList.add("is-active");
	}, 4500);
}

function initHeader() {
	const header = document.querySelector("[data-header]");
	if (!header) {
		return;
	}
	const onScroll = () => header.classList.toggle("is-scrolled", window.scrollY > 20);
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

	nav.querySelectorAll("a").forEach((link) => link.addEventListener("click", close));
	window.addEventListener("keydown", (event) => {
		if (event.key === "Escape") {
			close();
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
		const button = form.querySelector("button[type='submit']");
		const input = form.querySelector('input[type="email"]');
		if (!button) {
			return;
		}
		const label = button.textContent;
		button.textContent = "You're on the list";
		button.disabled = true;
		if (input) {
			input.value = "";
		}
		window.setTimeout(() => {
			button.textContent = label;
			button.disabled = false;
		}, 2800);
	});
}

function initScrollProgress() {
	const bar = document.querySelector("[data-scroll-progress]");
	if (!bar) {
		return;
	}
	const onScroll = () => {
		const doc = document.documentElement;
		const max = Math.max(1, doc.scrollHeight - doc.clientHeight);
		const p = Math.min(1, Math.max(0, window.scrollY / max));
		bar.style.width = `${p * 100}%`;
	};
	onScroll();
	window.addEventListener("scroll", onScroll, { passive: true });
}

function initScrollReveal() {
	const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
	const heroEls = document.querySelectorAll(".hero [data-reveal]");
	const sectionEls = document.querySelectorAll("[data-reveal-section]");

	if (reduceMotion) {
		[...heroEls, ...sectionEls].forEach(el => el.classList.add("is-revealed"));
		return;
	}

	heroEls.forEach(el => {
		const delay = el.dataset.revealDelay ? parseInt(el.dataset.revealDelay, 10) * 160 : 0;
		setTimeout(() => el.classList.add("is-revealed"), delay + 250);
	});

	const observer = new IntersectionObserver((entries) => {
		entries.forEach(entry => {
			if (!entry.isIntersecting) return;
			entry.target.classList.add("is-revealed");
			observer.unobserve(entry.target);
		});
	}, { threshold: 0.12, rootMargin: "0px 0px -40px 0px" });

	sectionEls.forEach(el => observer.observe(el));
}

function initFooterTelemetry() {
	const el = document.querySelector("[data-signal-integrity] .ft-value");
	if (!el) return;
	const update = () => { el.textContent = String(82 + Math.floor(Math.random() * 13)); };
	update();
	window.setInterval(update, 3500);
}

initSiteConfig();
initScrollReveal();
initHeroCanvas();
initHeroRotator();
initHeader();
initMobileNav();
initMailingForm();
initScrollProgress();
initFooterTelemetry();

// ==================== HERO ORBIT CANVAS ====================

function initHeroCanvas() {
	const canvas = document.getElementById("vectorfall-canvas");
	if (!canvas) {
		return;
	}

	const ctx = canvas.getContext("2d");
	const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
	const wells = [
		{ radius: 88, color: "rgba(98,255,224,0.9)", phase: 0 },
		{ radius: 156, color: "rgba(255,200,87,0.75)", phase: 1.4 },
		{ radius: 238, color: "rgba(255,77,54,0.65)", phase: 2.8 },
	];
	const particles = Array.from({ length: 72 }, (_, index) => ({
		angle: index * 0.47,
		distance: 110 + (index % 17) * 28,
		speed: 0.12 + (index % 6) * 0.016,
	}));
	const player = { angle: 0.85, distance: 210, speed: 0.22 };

	let width = 0;
	let height = 0;
	let baseCenter = { x: 0, y: 0 };
	let center = { x: 0, y: 0 };
	let mouse = { x: 0, y: 0 };
	let mouseSmooth = { x: 0, y: 0 };
	let lastTime = performance.now();
	let instabilityStrength = 0;

	canvas.addEventListener("mousemove", (e) => {
		const rect = canvas.getBoundingClientRect();
		mouse.x = e.clientX - rect.left;
		mouse.y = e.clientY - rect.top;
	}, { passive: true });

	window.setInterval(() => {
		instabilityStrength = 1.0;
	}, 11000);

	function resize() {
		const ratio = window.devicePixelRatio || 1;
		width = canvas.clientWidth;
		height = canvas.clientHeight;
		canvas.width = Math.floor(width * ratio);
		canvas.height = Math.floor(height * ratio);
		ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
		baseCenter = { x: width * 0.62, y: height * 0.48 };
		mouse = { x: width * 0.5, y: height * 0.5 };
		mouseSmooth = { x: width * 0.5, y: height * 0.5 };
		center = { x: baseCenter.x, y: baseCenter.y };
		draw(performance.now());
	}

	function orbitPosition(angle, distance) {
		return {
			x: center.x + Math.cos(angle) * distance,
			y: center.y + Math.sin(angle * 1.06) * distance * 0.64,
		};
	}

	function drawTrail(points, color, lineWidth) {
		if (points.length < 2) {
			return;
		}
		ctx.beginPath();
		points.forEach((point, index) => {
			if (index === 0) {
				ctx.moveTo(point.x, point.y);
			} else {
				ctx.lineTo(point.x, point.y);
			}
		});
		ctx.strokeStyle = color;
		ctx.lineWidth = lineWidth;
		ctx.stroke();
	}

	function drawGrid(time) {
		const step = 48;
		ctx.strokeStyle = "rgba(98,255,224,0.04)";
		ctx.lineWidth = 1;
		const driftX = (time * 0.01) % step;
		const driftY = (time * 0.006) % step;
		for (let x = (center.x + driftX) % step; x < width; x += step) {
			ctx.beginPath();
			ctx.moveTo(x, 0);
			ctx.lineTo(x, height);
			ctx.stroke();
		}
		for (let y = (center.y + driftY) % step; y < height; y += step) {
			ctx.beginPath();
			ctx.moveTo(0, y);
			ctx.lineTo(width, y);
			ctx.stroke();
		}
	}

	function drawWell(well, time) {
		const pulse = Math.sin(time * 0.0012 + well.phase) * 0.1 + 1;
		const instabilityOffset = Math.sin(time * 0.08 + well.phase) * instabilityStrength * 8;
		const effectiveRadius = well.radius * pulse + instabilityOffset;

		ctx.beginPath();
		ctx.arc(center.x, center.y, effectiveRadius, 0, Math.PI * 2);
		ctx.strokeStyle = well.color;
		ctx.lineWidth = 1.4;
		ctx.stroke();

		for (let i = 0; i < 8; i += 1) {
			const angle = (Math.PI * 2 * i) / 8 + well.phase * 0.15 + time * 0.00012;
			const inner = effectiveRadius - 10;
			const outer = effectiveRadius + 8;
			ctx.beginPath();
			ctx.moveTo(
				center.x + Math.cos(angle) * inner,
				center.y + Math.sin(angle) * inner
			);
			ctx.lineTo(
				center.x + Math.cos(angle) * outer,
				center.y + Math.sin(angle) * outer
			);
			ctx.strokeStyle = well.color.replace("0.9", "0.35").replace("0.75", "0.3").replace("0.65", "0.28");
			ctx.lineWidth = 1;
			ctx.stroke();
		}
	}

	function drawEscapeArc() {
		ctx.beginPath();
		ctx.moveTo(center.x - 480, center.y + 200);
		ctx.quadraticCurveTo(
			center.x - 120,
			center.y - 180,
			center.x + 420,
			center.y + 100
		);
		ctx.strokeStyle = "rgba(255,77,54,0.35)";
		ctx.setLineDash([6, 10]);
		ctx.lineWidth = 1.5;
		ctx.stroke();
		ctx.setLineDash([]);
	}

	function drawParticle(particle) {
		const wobble = Math.sin(particle.angle * 1.6) * 18;
		const position = orbitPosition(particle.angle, particle.distance + wobble);

		const playerPos = orbitPosition(player.angle, player.distance);
		const dx = position.x - playerPos.x;
		const dy = position.y - playerPos.y;
		const dist = Math.sqrt(dx * dx + dy * dy);
		if (dist < 70 && dist > 0) {
			const influence = (70 - dist) / 70;
			position.x += (dx / dist) * influence * 5;
			position.y += (dy / dist) * influence * 5;
		}

		const trail = [];
		for (let step = 14; step >= 0; step -= 1) {
			trail.push(orbitPosition(particle.angle - step * 0.018, particle.distance + wobble));
		}
		drawTrail(trail, "rgba(98,255,224,0.16)", 1);
		ctx.beginPath();
		ctx.arc(position.x, position.y, 2, 0, Math.PI * 2);
		ctx.fillStyle = "rgba(244,251,255,0.7)";
		ctx.fill();
	}

	function drawPlayer() {
		const position = orbitPosition(player.angle, player.distance);
		const tangent = {
			x: -Math.sin(player.angle),
			y: Math.cos(player.angle * 1.06) * 0.64,
		};
		const tangentLen = Math.sqrt(tangent.x * tangent.x + tangent.y * tangent.y);
		const normTangent = tangentLen > 0
			? { x: tangent.x / tangentLen, y: tangent.y / tangentLen }
			: { x: tangent.x, y: tangent.y };
		const dotRadius = 4.5;
		const velocityEnd = {
			x: position.x + tangent.x * 46,
			y: position.y + tangent.y * 46,
		};
		const arrowStart = {
			x: position.x + normTangent.x * dotRadius,
			y: position.y + normTangent.y * dotRadius,
		};
		const trail = [];
		for (let step = 28; step >= 3; step -= 1) {
			trail.push(orbitPosition(player.angle - step * 0.022, player.distance));
		}
		drawTrail(trail, "rgba(255,200,87,0.5)", 2.2);

		ctx.beginPath();
		ctx.moveTo(arrowStart.x, arrowStart.y);
		ctx.quadraticCurveTo(
			(arrowStart.x + velocityEnd.x) * 0.5,
			(arrowStart.y + velocityEnd.y) * 0.5,
			velocityEnd.x,
			velocityEnd.y
		);
		ctx.strokeStyle = "rgba(255,200,87,0.7)";
		ctx.lineWidth = 1.6;
		ctx.stroke();

		ctx.beginPath();
		ctx.arc(position.x, position.y, dotRadius, 0, Math.PI * 2);
		ctx.fillStyle = "#f4fbff";
		ctx.fill();
		ctx.strokeStyle = "rgba(98,255,224,0.9)";
		ctx.lineWidth = 1.5;
		ctx.stroke();
	}

	function draw(time) {
		ctx.clearRect(0, 0, width, height);
		ctx.fillStyle = "#05070a";
		ctx.fillRect(0, 0, width, height);
		drawGrid(time);
		wells.forEach((well) => drawWell(well, time));
		drawEscapeArc();
		particles.forEach(drawParticle);
		drawPlayer();
	}

	function tick(now) {
		const delta = Math.min(now - lastTime, 40);
		lastTime = now;

		if (!reduceMotion) {
			player.angle += delta * 0.00009 * player.speed;
			for (const particle of particles) {
				particle.angle += delta * 0.00007 * particle.speed;
			}

			instabilityStrength = Math.max(0, instabilityStrength - delta * 0.0008);

			if (width >= 600) {
				mouseSmooth.x += (mouse.x - mouseSmooth.x) * 0.04;
				mouseSmooth.y += (mouse.y - mouseSmooth.y) * 0.04;
				center = {
					x: baseCenter.x + (mouseSmooth.x / width - 0.5) * -24,
					y: baseCenter.y + (mouseSmooth.y / height - 0.5) * -14,
				};
			} else {
				center = { x: baseCenter.x, y: baseCenter.y };
			}
		}

		draw(now);
		requestAnimationFrame(tick);
	}

	window.addEventListener("resize", resize);
	resize();
	requestAnimationFrame(tick);
}
