(() => {
	"use strict";

	const STORAGE_KEY = "vector-anomaly-creator-draft-v4";
	const CHECK_KEY = "vector-anomaly-release-check-v1";
	const form = document.querySelector("[data-builder-form]");
	const output = document.querySelector("[data-manifest-output]");
	const status = document.querySelector("[data-builder-status]");
	const diagnostics = document.querySelector("[data-diagnostics]");
	const validationStatus = document.querySelector("[data-validation-status]");
	const validationList = document.querySelector("[data-validation-list]");
	const contractGraph = document.querySelector("[data-contract-graph]");
	let importedBase = null;

	const presets = {
		weapon: (network) => ({
			weapons: [{ id: "vector_lance", display_name: "Vector Lance", fire_mode: "projectile", network_category: network, base_weapon_id: "vector_bolt", pattern: "single", shot_count: 1, payload: { speed: 1120, damage_min: 12, damage_max: 18 } }],
		}),
		weave: (network) => ({
			law_weaves: [{ id: "apex_echo", display_name: "Apex Echo", hooks: ["slingshot_apex"], network_category: network, cooldown: 5, max_triggers: 4, conditions: [{ type: "min_wave", value: 3 }], effects: [{ action: "create_resonance_zone", zone_type: "harmonic_orbit", radius: 220, intensity: 0.6 }] }],
		}),
		challenge: (network) => ({
			challenge_cards: [{ id: "close_pass_protocol", display_name: "Close Pass Protocol", hooks: ["run_start", "slingshot_perfect"], network_category: network, max_triggers: 12, conditions: [{ type: "min_wave", value: 1 }], effects: [{ action: "tag_score_event", tag: "close_pass" }] }],
		}),
		visual: () => ({
			shader_packs: [{ id: "cold_lattice", display_name: "Cold Lattice", network_category: "local_visual", shader: "assets/cold_lattice.gdshader", tags: ["reduced-flash-ready"] }],
		}),
		level: (network) => ({
			level_packs: [{ id: "mirror_training", display_name: "Mirror Training", network_category: network, scene: "levels/mirror_training.tscn", tags: ["training", "gravity"] }],
		}),
		expansion: (network) => ({
			expansion_packs: [{ id: "rupture_protocol", display_name: "Rupture Protocol", network_category: network, tags: ["campaign", "bosses", "physics"] }],
			boss_rules: [{ id: "mirror_gravity", display_name: "Mirror Gravity", network_category: "deterministic_seed", tags: ["polarity", "orbit"] }],
		}),
	};

	function safeId(value, fallback = "my_vector_pack") {
		const clean = String(value || "").trim().toLowerCase().replace(/[^a-z0-9_-]+/g, "_").replace(/^_+|_+$/g, "");
		return clean || fallback;
	}

	function splitList(value) {
		return String(value || "").split(",").map((item) => item.trim()).filter(Boolean);
	}

	function parseDependencies(value) {
		return splitList(value).map((token) => {
			const optional = token.endsWith("?");
			const clean = optional ? token.slice(0, -1) : token;
			const [rawId, versionRange] = clean.split("@", 2);
			const dependency = { id: safeId(rawId, "dependency"), required: !optional };
			if (versionRange?.trim()) {
				const [minVersion, maxVersion] = versionRange.split("..", 2);
				if (minVersion?.trim()) dependency.min_version = minVersion.trim();
				if (maxVersion?.trim()) dependency.max_version = maxVersion.trim();
			}
			return dependency;
		});
	}

	function currentManifest() {
		const data = new FormData(form);
		const network = String(data.get("network") || "reliable_event");
		const preset = String(data.get("preset") || "weapon");
		const generatedContent = presets[preset](network);
		const manifest = importedBase ? JSON.parse(JSON.stringify(importedBase)) : {};
		const importedConflicts = new Map((importedBase?.conflicts || []).map((conflict) => [typeof conflict === "string" ? conflict : conflict.id, conflict]));
		Object.assign(manifest, {
			id: safeId(data.get("id")),
			display_name: String(data.get("display_name") || "My Vector Pack").trim(),
			author: String(data.get("author") || "Creator").trim(),
			version: String(data.get("version") || "1.0.0").trim(),
			schema_version: 4,
			description: String(data.get("description") || "").trim(),
			tags: Array.isArray(manifest.tags) && manifest.tags.length ? manifest.tags : ["community", "physics"],
			dependencies: parseDependencies(data.get("dependencies")),
			conflicts: splitList(data.get("conflicts")).map((id) => {
				const safeConflictId = safeId(id, "incompatible_pack");
				const imported = importedConflicts.get(safeConflictId);
				return typeof imported === "object" ? imported : { id: safeConflictId, reason: "overlapping physics contract" };
			}),
			load_after: Array.isArray(manifest.load_after) ? manifest.load_after : [],
			load_before: Array.isArray(manifest.load_before) ? manifest.load_before : [],
			content: importedBase?.content && typeof importedBase.content === "object" ? importedBase.content : generatedContent,
		});
		if (data.get("creator_options")) {
			manifest.options = Array.isArray(importedBase?.options) && importedBase.options.length ? importedBase.options : [
				{ id: "intensity", display_name: "Effect Intensity", description: "Scales this pack's authored pressure.", type: "float", default: 1, min: 0.25, max: 1.5, step: 0.05, network_category: network === "local_visual" ? "local_visual" : "deterministic_seed" },
				{ id: "reduced_flash_palette", display_name: "Reduced Flash Palette", type: "bool", default: true, network_category: "local_visual" },
			];
		} else {
			delete manifest.options;
		}
		return manifest;
	}

	function validate(manifest) {
		const errors = [];
		const warnings = [];
		if (!/^[a-z0-9_-]+$/.test(manifest.id)) errors.push("Mod ID must use lowercase letters, numbers, underscores, or hyphens.");
		if (!manifest.display_name) errors.push("Display name is required.");
		if (!manifest.author) errors.push("Author is required.");
		if (!manifest.version) errors.push("Version is required.");
		const dependencyIds = new Set();
		for (const dependency of manifest.dependencies) {
			if (dependency.id === manifest.id) errors.push("A mod cannot depend on itself.");
			if (dependencyIds.has(dependency.id)) warnings.push(`Dependency ${dependency.id} is listed more than once.`);
			dependencyIds.add(dependency.id);
			if (dependency.min_version && dependency.max_version && compareVersions(dependency.min_version, dependency.max_version) > 0) errors.push(`${dependency.id} has a minimum version above its maximum version.`);
		}
		for (const conflict of manifest.conflicts) {
			if (conflict.id === manifest.id) errors.push("A mod cannot conflict with itself.");
			if (dependencyIds.has(conflict.id)) errors.push(`${conflict.id} cannot be both a dependency and a conflict.`);
		}
		const entries = Object.values(manifest.content).flat();
		if (!entries.length) errors.push("At least one content entry is required.");
		if (entries.some((entry) => !entry.network_category)) errors.push("Every generated entry needs a network category.");
		if (entries.some((entry) => entry.network_category !== "local_visual") && !manifest.description) warnings.push("Gameplay packs should explain their physics contract in the description.");
		return { errors, warnings, entries };
	}

	function compareVersions(left, right) {
		const leftText = String(left).trim();
		const rightText = String(right).trim();
		const a = leftText.split("-", 1)[0].split(".").map((part) => Number.parseInt(part, 10) || 0);
		const b = rightText.split("-", 1)[0].split(".").map((part) => Number.parseInt(part, 10) || 0);
		for (let index = 0; index < Math.max(a.length, b.length); index += 1) {
			if ((a[index] || 0) !== (b[index] || 0)) return (a[index] || 0) - (b[index] || 0);
		}
		if (leftText.includes("-") !== rightText.includes("-")) return leftText.includes("-") ? -1 : 1;
		return 0;
	}

	function renderContractGraph(manifest) {
		contractGraph.replaceChildren();
		const nodes = [{ id: manifest.id, detail: `schema ${manifest.schema_version}`, kind: "root" }];
		for (const dependency of manifest.dependencies) {
			const range = [dependency.min_version, dependency.max_version].filter(Boolean).join(" → ") || "any version";
			nodes.push({ id: dependency.id, detail: range, kind: dependency.required === false ? "optional" : "required" });
		}
		for (const conflict of manifest.conflicts) nodes.push({ id: conflict.id, detail: "declared incompatible", kind: "conflict" });
		for (const item of nodes) {
			const node = document.createElement("article");
			node.className = `graph-node ${item.kind}`;
			const name = document.createElement("b");
			name.textContent = item.id;
			const detail = document.createElement("small");
			detail.textContent = item.detail;
			node.append(name, detail);
			contractGraph.appendChild(node);
		}
		if (nodes.length === 1) {
			const empty = document.createElement("article");
			empty.className = "graph-node optional";
			const name = document.createElement("b");
			name.textContent = "standalone pack";
			const detail = document.createElement("small");
			detail.textContent = "no dependency pressure";
			empty.append(name, detail);
			contractGraph.appendChild(empty);
		}
	}

	function saveDraft() {
		try {
			const values = Object.fromEntries(new FormData(form).entries());
			values.creator_options = form.elements.creator_options.checked;
			values.imported_base = importedBase;
			localStorage.setItem(STORAGE_KEY, JSON.stringify(values));
		} catch { /* storage is optional */ }
	}

	function render() {
		const manifest = currentManifest();
		const result = validate(manifest);
		output.textContent = JSON.stringify(manifest, null, 2);
		status.textContent = result.errors.length ? "BLOCKED" : result.warnings.length ? "READY WITH NOTES" : "READY";
		validationStatus.textContent = result.errors.length ? `${result.errors.length} BLOCKER${result.errors.length === 1 ? "" : "S"}` : "VALID";
		diagnostics.classList.toggle("has-errors", result.errors.length > 0);
		renderContractGraph(manifest);
		document.querySelector("[data-schema-readout]").textContent = String(manifest.schema_version);
		document.querySelector("[data-entry-readout]").textContent = String(result.entries.length);
		document.querySelector("[data-network-readout]").textContent = String(form.elements.network.value).replace("_", " ").toUpperCase();
		validationList.replaceChildren();
		const messages = [...result.errors, ...result.warnings];
		for (const message of messages.length ? messages : ["No blocking issues. Contract is ready for in-game validation."]) {
			const item = document.createElement("li");
			item.textContent = message;
			validationList.appendChild(item);
		}
		form.elements.id.value = manifest.id;
		form.elements.id.setAttribute("aria-invalid", String(!/^[a-z0-9_-]+$/.test(manifest.id)));
		saveDraft();
	}

	async function copyText(text) {
		try {
			await navigator.clipboard.writeText(text);
			return true;
		} catch {
			const area = document.createElement("textarea");
			area.value = text;
			area.style.position = "fixed";
			area.style.opacity = "0";
			document.body.appendChild(area);
			area.select();
			const copied = document.execCommand("copy");
			area.remove();
			return copied;
		}
	}

	function restoreDraft() {
		try {
			const values = JSON.parse(localStorage.getItem(STORAGE_KEY) || "null");
			if (!values) return;
			importedBase = values.imported_base && typeof values.imported_base === "object" ? values.imported_base : null;
			for (const [name, value] of Object.entries(values)) {
				if (name === "imported_base") continue;
				const field = form.elements[name];
				if (!field) continue;
				if (field.type === "checkbox") field.checked = Boolean(value);
				else field.value = String(value);
			}
		} catch { /* malformed old draft is ignored */ }
	}

	function importManifest(manifest) {
		if (!manifest || typeof manifest !== "object" || Array.isArray(manifest)) throw new Error("Manifest root must be an object.");
		importedBase = JSON.parse(JSON.stringify(manifest));
		form.elements.id.value = manifest.id || "imported_pack";
		form.elements.display_name.value = manifest.display_name || manifest.id || "Imported Pack";
		form.elements.author.value = manifest.author || "Creator";
		form.elements.version.value = String(manifest.version || "1.0.0");
		form.elements.description.value = manifest.description || "";
		form.elements.dependencies.value = (manifest.dependencies || []).map((dependency) => {
			if (typeof dependency === "string") return dependency;
			const range = dependency.min_version || dependency.max_version ? `@${dependency.min_version || ""}${dependency.max_version ? `..${dependency.max_version}` : ""}` : "";
			return `${dependency.id || "dependency"}${range}${dependency.required === false ? "?" : ""}`;
		}).join(", ");
		form.elements.conflicts.value = (manifest.conflicts || []).map((conflict) => typeof conflict === "string" ? conflict : conflict.id).filter(Boolean).join(", ");
		form.elements.creator_options.checked = Array.isArray(manifest.options) && manifest.options.length > 0;
		const firstBucket = Object.keys(manifest.content || {})[0] || "weapons";
		const presetByBucket = { weapons: "weapon", law_weaves: "weave", challenge_cards: "challenge", shader_packs: "visual", level_packs: "level", expansion_packs: "expansion" };
		form.elements.preset.value = presetByBucket[firstBucket] || "expansion";
		const firstEntry = Object.values(manifest.content || {}).flat()[0];
		if (firstEntry?.network_category) form.elements.network.value = firstEntry.network_category;
		render();
		status.textContent = "IMPORTED // REVIEW GENERATED CONTRACT";
	}

	form.addEventListener("input", render);
	document.querySelector("[data-copy-manifest]").addEventListener("click", async () => {
		status.textContent = await copyText(output.textContent) ? "COPIED" : "COPY BLOCKED // SELECT JSON";
	});
	document.querySelector("[data-download-manifest]").addEventListener("click", () => {
		const blob = new Blob([output.textContent], { type: "application/json" });
		const link = document.createElement("a");
		link.href = URL.createObjectURL(blob);
		link.download = "vector_anomaly_mod.json";
		link.click();
		URL.revokeObjectURL(link.href);
		status.textContent = "DOWNLOADED";
	});
	document.querySelector("[data-import-manifest]").addEventListener("change", async (event) => {
		const file = event.target.files?.[0];
		if (!file) return;
		try {
			importManifest(JSON.parse(await file.text()));
		} catch {
			status.textContent = "IMPORT FAILED // INVALID JSON";
		}
		event.target.value = "";
	});
	document.querySelector("[data-reset-manifest]").addEventListener("click", () => {
		try { localStorage.removeItem(STORAGE_KEY); } catch { /* optional */ }
		form.reset();
		importedBase = null;
		render();
		status.textContent = "DRAFT RESET";
	});
	form.elements.preset.addEventListener("change", () => {
		if (!importedBase) return;
		importedBase = null;
		render();
		status.textContent = "STARTER SURFACE CHANGED // IMPORTED CONTENT CLEARED";
	});

	const search = document.querySelector("[data-reference-search]");
	const filterButtons = [...document.querySelectorAll("[data-filter]")];
	const cards = [...document.querySelectorAll("[data-reference-grid] article")];
	let activeFilter = "all";
	function filterReference() {
		const query = search.value.trim().toLowerCase();
		let visible = 0;
		for (const card of cards) {
			const categoryMatch = activeFilter === "all" || card.dataset.category === activeFilter;
			const searchMatch = !query || card.textContent.toLowerCase().includes(query) || card.dataset.search.includes(query);
			card.hidden = !(categoryMatch && searchMatch);
			if (!card.hidden) visible += 1;
		}
		document.querySelector("[data-reference-empty]").hidden = visible > 0;
	}
	search.addEventListener("input", filterReference);
	for (const button of filterButtons) {
		button.addEventListener("click", () => {
			activeFilter = button.dataset.filter;
			filterButtons.forEach((item) => item.classList.toggle("is-active", item === button));
			filterReference();
		});
	}

	const checks = [...document.querySelectorAll(".ship-list input[type=checkbox]")];
	function updateReleaseScore() {
		const completed = checks.filter((check) => check.checked).length;
		const score = Math.round((completed / checks.length) * 100);
		document.querySelector("[data-release-score]").textContent = `${score}%`;
		document.querySelector("[data-release-bar]").style.width = `${score}%`;
		document.querySelector("[data-release-message]").textContent = score === 100 ? "PACKAGE READY // export the in-game creator report." : `${checks.length - completed} release gate${checks.length - completed === 1 ? "" : "s"} remain.`;
		try { localStorage.setItem(CHECK_KEY, JSON.stringify(checks.map((check) => check.checked))); } catch { /* optional */ }
	}
	try {
		const saved = JSON.parse(localStorage.getItem(CHECK_KEY) || "[]");
		checks.forEach((check, index) => { check.checked = Boolean(saved[index]); });
	} catch { /* optional */ }
	checks.forEach((check) => check.addEventListener("change", updateReleaseScore));

	const toggle = document.querySelector(".nav-toggle");
	const nav = document.querySelector(".topbar nav");
	toggle.addEventListener("click", () => {
		const open = nav.classList.toggle("open");
		toggle.setAttribute("aria-expanded", String(open));
	});
	nav.addEventListener("click", () => { nav.classList.remove("open"); toggle.setAttribute("aria-expanded", "false"); });

	const sections = [...document.querySelectorAll("main section[id]")];
	const navLinks = [...nav.querySelectorAll("a[href^='#']")];
	if ("IntersectionObserver" in window) {
		const observer = new IntersectionObserver((entries) => {
			const visible = entries.filter((entry) => entry.isIntersecting).sort((a, b) => b.intersectionRatio - a.intersectionRatio)[0];
			if (!visible) return;
			navLinks.forEach((link) => link.classList.toggle("is-active", link.hash === `#${visible.target.id}`));
		}, { rootMargin: "-25% 0px -65%", threshold: [0, 0.2, 0.5] });
		sections.forEach((section) => observer.observe(section));
	}
	const meter = document.querySelector("[data-scroll-meter]");
	window.addEventListener("scroll", () => {
		const max = Math.max(1, document.documentElement.scrollHeight - innerHeight);
		meter.style.width = `${Math.min(100, (scrollY / max) * 100)}%`;
	}, { passive: true });

	restoreDraft();
	render();
	updateReleaseScore();
})();
