/* VECTOR ANOMALY wiki runtime */

const searchInput = document.querySelector("[data-wiki-search]");
const sections = [...document.querySelectorAll(".wiki-section")];
const navLinks = [...document.querySelectorAll("[data-wiki-nav] a")];
const searchShell = document.querySelector(".search-shell");

function addWikiChrome() {
	const progress = document.createElement("div");
	progress.className = "wiki-progress";
	progress.setAttribute("aria-hidden", "true");
	progress.innerHTML = "<i></i>";
	document.body.prepend(progress);
	const bar = progress.querySelector("i");
	const update = () => {
		const max = Math.max(1, document.documentElement.scrollHeight - window.innerHeight);
		bar.style.width = `${Math.min(100, (window.scrollY / max) * 100)}%`;
	};
	update();
	window.addEventListener("scroll", update, { passive: true });
}

function normalize(value) {
	return value.toLowerCase().replace(/\s+/g, " ").trim();
}

function initSearch() {
	if (!searchInput || !sections.length) return;

	const sectionIndex = sections.map((section) => ({
		section,
		text: normalize(`${section.dataset.topic || ""} ${section.textContent || ""}`),
	}));
	const status = document.createElement("p");
	status.className = "search-status";
	status.setAttribute("aria-live", "polite");
	searchShell?.appendChild(status);

	searchInput.addEventListener("input", () => {
		const query = normalize(searchInput.value);
		const tokens = query.split(" ").filter(Boolean);
		let visibleCount = 0;
		for (const item of sectionIndex) {
			const visible = !tokens.length || tokens.every((token) => item.text.includes(token));
			item.section.classList.toggle("is-hidden", !visible);
			if (visible) visibleCount += 1;
		}
		status.textContent = query ? `${visibleCount} system section${visibleCount === 1 ? "" : "s"} matched` : `${sections.length} system sections indexed`;
	});
	searchInput.dispatchEvent(new Event("input"));
	window.addEventListener("keydown", (event) => {
		if (event.key === "/" && document.activeElement !== searchInput) {
			event.preventDefault();
			searchInput.focus();
		}
		if (event.key === "Escape" && document.activeElement === searchInput) {
			searchInput.value = "";
			searchInput.dispatchEvent(new Event("input"));
			searchInput.blur();
		}
	});
}

function initActiveNav() {
	if (!sections.length || !navLinks.length) return;
	const linkById = new Map(navLinks.map((link) => [link.getAttribute("href")?.slice(1), link]));

	const setActive = (id) => {
		navLinks.forEach((link) => link.classList.toggle("is-active", link === linkById.get(id)));
	};

	const observer = new IntersectionObserver((entries) => {
		const visible = entries
			.filter((entry) => entry.isIntersecting)
			.sort((a, b) => b.intersectionRatio - a.intersectionRatio)[0];
		if (visible?.target?.id) setActive(visible.target.id);
	}, { threshold: [0.18, 0.34, 0.5], rootMargin: "-80px 0px -55% 0px" });

	sections.forEach((section) => observer.observe(section));
	if (location.hash) {
		setActive(location.hash.slice(1));
	} else {
		setActive(sections[0].id);
	}
}

initSearch();
initActiveNav();
addWikiChrome();
