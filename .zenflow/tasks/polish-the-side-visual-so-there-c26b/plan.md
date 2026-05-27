# Polish Side Visual & Website Accuracy

Two-file fix: visual bug in `website/app.js` + content accuracy in `website/index.html`.

**Visual fix:** The player dot had a line drawn through it because the trail ended at the dot center and the velocity arrow also started from the dot center — together forming a continuous stroke through it. Fixed by (a) stopping the trail 3 steps before the current position so it fades before the dot, and (b) normalizing the tangent vector and starting the velocity arrow from the dot edge (4.5px offset) instead of its center.

**Content accuracy:** Cross-referenced HOW_TO_PLAY.md and ORBITRON_SYSTEMS.md. Updated three boss descriptions that didn't match documentation (Accretion Core, Null Vector Seraph, Tidal Rift Weaver) and corrected the run summary to reflect wave 35 as the actual endpoint plus the Rupture and Resonance Singularity finale.

### [x] Step: Fix player dot visual and update website content accuracy
