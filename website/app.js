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
	try {
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
	} catch (error) {
		return url;
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
			target.textContent = "Wishlist on Steam";
		} else if (safeExternalUrl(config.discordUrl)) {
			target.href = config.discordUrl;
			target.target = "_blank";
			target.rel = "noopener";
			target.textContent = "Join Discord";
		} else if (safeExternalUrl(config.demoUrl)) {
			target.href = config.demoUrl;
			target.target = "_blank";
			target.rel = "noopener";
			target.textContent = "Download Playtest";
		} else {
			target.href = "#wishlist";
			target.textContent = "Follow Development";
		}
		target.hidden = false;
	}

	document.querySelectorAll("[data-demo-link]").forEach((target) => {
		if (safeExternalUrl(config.demoUrl)) {
			target.href = config.demoUrl;
			target.target = "_blank";
			target.rel = "noopener";
			target.textContent = "Download Windows Build";
		} else {
			target.href = "#systems";
			target.textContent = "View Systems";
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
			const max = Math.max(1, document.body.scrollHeight - window.innerHeight);
			const scrollRatio = Math.min(1, window.scrollY / max);
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

function initActiveNavigation() {
	const links = [...document.querySelectorAll("[data-site-nav] a[href^='#']")];
	const sections = links.map((link) => document.querySelector(link.hash)).filter(Boolean);
	if (!links.length || !sections.length || !("IntersectionObserver" in window)) return;
	const observer = new IntersectionObserver((entries) => {
		const visible = entries.filter((entry) => entry.isIntersecting).sort((a, b) => b.intersectionRatio - a.intersectionRatio)[0];
		if (!visible) return;
		links.forEach((link) => {
			const active = link.hash === `#${visible.target.id}`;
			link.classList.toggle("is-active", active);
			if (active) link.setAttribute("aria-current", "location");
			else link.removeAttribute("aria-current");
		});
	}, { threshold: [0.12, 0.3], rootMargin: "-22% 0px -62% 0px" });
	sections.forEach((section) => observer.observe(section));
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
	const revealNodes = [...document.querySelectorAll(".reveal-section")];
	if (!revealNodes.length) return;

	if (reduceMotion) {
		revealNodes.forEach((node) => node.classList.add("is-revealed"));
		return;
	}

	const observer = new IntersectionObserver((entries) => {
		for (const entry of entries) {
			if (!entry.isIntersecting) continue;
			entry.target.classList.add("is-revealed");
			observer.unobserve(entry.target);
		}
	}, { threshold: 0.12, rootMargin: "0px 0px -40px 0px" });

	revealNodes.forEach((node) => observer.observe(node));
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
	const paths = Array.from({ length: 36 }, (_, index) => ({
		angle: index * 0.53,
		radius: 120 + (index % 12) * 46,
		speed: 0.00004 + (index % 5) * 0.000008,
		size: 1 + (index % 3) * 0.6,
	}));
	let lastTime = performance.now();
	let controller;

	const draw = (ctx, size, now, delta) => {
		ctx.clearRect(0, 0, size.width, size.height);
		const centerX = size.width * 0.52;
		const centerY = size.height * 0.5;
		const pulse = 1 + Math.sin(now * 0.001) * 0.018;

		ctx.strokeStyle = "rgba(255,255,255,0.10)";
		ctx.lineWidth = 1;
		for (let radius = 120; radius < Math.max(size.width, size.height); radius += 140) {
			ctx.beginPath();
			ctx.arc(centerX, centerY, radius * pulse, 0, Math.PI * 2);
			ctx.stroke();
		}

		ctx.strokeStyle = "rgba(255,200,91,0.32)";
		ctx.setLineDash([8, 14]);
		ctx.beginPath();
		ctx.moveTo(centerX - 620, centerY + 250);
		ctx.quadraticCurveTo(centerX - 120, centerY - 160, centerX + 680, centerY - 80);
		ctx.stroke();
		ctx.setLineDash([]);

		for (const path of paths) {
			if (!reduceMotion) path.angle += delta * path.speed;
			const wobble = Math.sin(path.angle * 2.2 + now * 0.0007) * 10;
			const x = centerX + Math.cos(path.angle) * (path.radius + wobble);
			const y = centerY + Math.sin(path.angle) * (path.radius + wobble);
			ctx.fillStyle = path.radius % 3 === 0 ? "rgba(255,200,91,0.5)" : "rgba(100,255,232,0.42)";
			ctx.fillRect(x - path.size * 0.5, y - path.size * 0.5, path.size, path.size);
		}
	};

	const tick = (now) => {
		const delta = Math.min(40, now - lastTime);
		lastTime = now;
		if (controller) draw(controller.context, controller.state, now, delta);
		if (!reduceMotion) window.requestAnimationFrame(tick);
	};

	controller = setupCanvas(canvas, draw);
	if (controller && !reduceMotion) window.requestAnimationFrame(tick);
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

		ctx.strokeStyle = "rgba(100,255,232,0.24)";
		for (let r = 54; r < 220; r += 48) {
			ctx.beginPath();
			ctx.arc(cx, cy, r + Math.sin(now * 0.001 + r) * 3, 0, Math.PI * 2);
			ctx.stroke();
		}

		ctx.fillStyle = "rgba(0,0,0,1)";
		ctx.strokeStyle = "rgba(255,255,255,0.8)";
		ctx.beginPath();
		ctx.arc(cx, cy, 18, 0, Math.PI * 2);
		ctx.fill();
		ctx.stroke();

		if (!reduceMotion) playerAngle += delta * 0.00125;
		const orbitRadius = Math.min(142, Math.min(size.width, size.height) * 0.32);
		const player = {
			x: cx + Math.cos(playerAngle) * orbitRadius,
			y: cy + Math.sin(playerAngle) * orbitRadius,
		};

		ctx.setLineDash([5, 8]);
		ctx.strokeStyle = "rgba(255,200,91,0.76)";
		ctx.beginPath();
		for (let i = 0; i < 80; i += 1) {
			const a = playerAngle - i * 0.035;
			const x = cx + Math.cos(a) * orbitRadius;
			const y = cy + Math.sin(a) * orbitRadius;
			if (i === 0) ctx.moveTo(x, y);
			else ctx.lineTo(x, y);
		}
		ctx.stroke();
		ctx.setLineDash([]);

		for (const point of points) {
			if (!reduceMotion) point.angle += delta * 0.00012;
			const x = cx + Math.cos(point.angle) * point.radius;
			const y = cy + Math.sin(point.angle) * point.radius;
			ctx.fillStyle = point.radius > 180 ? "rgba(255,85,64,0.56)" : "rgba(100,255,232,0.45)";
			ctx.fillRect(x - 1.5, y - 1.5, 3, 3);
		}

		ctx.fillStyle = "#ffffff";
		ctx.beginPath();
		ctx.arc(player.x, player.y, 5, 0, Math.PI * 2);
		ctx.fill();
		ctx.strokeStyle = "rgba(100,255,232,0.95)";
		ctx.stroke();
	};

	const tick = (now) => {
		const delta = Math.min(40, now - lastTime);
		lastTime = now;
		if (controller) draw(controller.context, controller.state, now, delta);
		if (!reduceMotion) window.requestAnimationFrame(tick);
	};

	controller = setupCanvas(canvas, draw);
	if (controller && !reduceMotion) window.requestAnimationFrame(tick);
}

function initBossLog() {
	const cards = [...document.querySelectorAll(".boss-card")];
	const readout = document.querySelector("[data-boss-readout]");
	if (!cards.length || !readout) return;

	const setActive = (card) => {
		cards.forEach((item) => item.classList.toggle("is-active", item === card));
		readout.textContent = `${card.dataset.wave} ${card.dataset.boss} - ${card.dataset.law}`;
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

	track.setAttribute("role", "region");
	track.setAttribute("aria-label", "Repeatable seed highlights");
	track.tabIndex = 0;

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

	track.addEventListener("keydown", (event) => {
		if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") return;
		event.preventDefault();
		index = event.key === "ArrowRight" ? (index + 1) % cards.length : (index + cards.length - 1) % cards.length;
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

initSiteConfig();
initHeader();
initMobileNav();
initActiveNavigation();
initScrollProgress();
initReveal();
initHeroField();
initTrailerSimulation();
initBossLog();
initClipConsole();
