/**
 * Single Admin SDK initializer for every script in this directory,
 * with the target project pinned explicitly.
 *
 * Why pinned rather than left to ambient detection (GCLOUD_PROJECT,
 * gcloud config, the metadata server): a script that cannot resolve
 * a project does not fail, it reads nothing and reports zero. Zero
 * is also the correct answer for a healthy database, so an
 * unresolved project and a clean result are indistinguishable in the
 * output. That is worse than having no check at all, because it
 * produces false confidence rather than an obvious gap.
 *
 * This is not hypothetical. check_vote_timestamps.js records that an
 * earlier version of itself printed "(unknown)" for the project and
 * reported zero documents when it may not have reached any project.
 * scan_orphaned_docs.js shipped with the same defect and was caught
 * printing "(unknown)" beside a zero during a post-deploy check on
 * 2026-08-13, which is what prompted this helper.
 *
 * resolvedProjectId throws rather than returning a placeholder, so
 * the failure is loud at the top of a run instead of quiet in the
 * middle of a result.
 *
 * Running against the emulator still works: FIRESTORE_EMULATOR_HOST
 * routes the traffic regardless of the project name, and pinning
 * means every script shares one namespace there instead of each
 * inventing its own.
 */

const admin = require("firebase-admin");

/** The only project these scripts are intended to touch. */
const PROJECT_ID = "majorcitymusteats";

/**
 * Initializes the Admin SDK once, against the pinned project.
 * @returns {import("firebase-admin").app.App}
 */
function initAdminApp() {
  if (admin.apps.length === 0) {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
      projectId: PROJECT_ID,
    });
  }
  return admin.app();
}

/**
 * The resolved project id, guaranteed non-empty.
 *
 * Throws instead of returning "(unknown)": a script that cannot name
 * its target must not go on to print numbers about it.
 * @returns {string}
 */
function resolvedProjectId() {
  const id = admin.app().options.projectId;
  if (!id) {
    throw new Error(
      "No project id resolved. Refusing to continue: a script that " +
        "cannot name its target cannot report a trustworthy result."
    );
  }
  return id;
}

module.exports = {PROJECT_ID, initAdminApp, resolvedProjectId};
