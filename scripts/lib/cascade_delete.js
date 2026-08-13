/**
 * Cascade delete for a restaurant document.
 *
 * Firestore does not delete a document's subcollections when the
 * document itself is deleted. Deleting a restaurant doc without
 * walking its votes, comments, and insiderNotes subcollections
 * first leaves them permanently orphaned, invisible to any query
 * filtered by cityId but still enumerable via a collectionGroup
 * scan. This is the traceable cause of the 163 orphaned vote
 * documents found in production on 2026-08-07: an earlier version
 * of set_houston_launch_order.js batch-deleted seven restaurant
 * docs this way.
 *
 * A Firestore trigger (onRestaurantDeleted, functions/src/index.ts)
 * now does this same cleanup for every restaurant deletion in
 * production, regardless of source. This helper exists for scripts
 * that want the counts up front, in a dry run, before a deploy of
 * that trigger is guaranteed to be live, or when running against a
 * project where it is not.
 */

/**
 * Deletes all docs from a query in batches of 500.
 * @param {FirebaseFirestore.Firestore} db
 * @param {FirebaseFirestore.Query} query
 * @returns {Promise<number>} Number of docs deleted.
 */
async function deleteInBatches(db, query) {
  let totalDeleted = 0;
  let snapshot = await query.limit(500).get();

  while (!snapshot.empty) {
    const batch = db.batch();
    for (const doc of snapshot.docs) {
      batch.delete(doc.ref);
    }
    await batch.commit();
    totalDeleted += snapshot.size;
    snapshot = await query.limit(500).get();
  }

  return totalDeleted;
}

/**
 * Counts (and optionally deletes) the votes, comments, and
 * insiderNotes subcollections under a restaurant doc.
 *
 * Always counts. Only deletes, and deletes the restaurant doc
 * itself, when confirm is true, so this is safe to call in a dry
 * run to report what a removal would orphan.
 *
 * @param {FirebaseFirestore.Firestore} db
 * @param {FirebaseFirestore.DocumentReference} restaurantRef
 * @param {{confirm: boolean}} options
 * @returns {Promise<{votes: number, comments: number, insiderNotes: number}>}
 */
async function cascadeDeleteRestaurant(db, restaurantRef, {confirm}) {
  const [votesSnap, commentsSnap, notesSnap] = await Promise.all([
    restaurantRef.collection("votes").get(),
    restaurantRef.collection("comments").get(),
    restaurantRef.collection("insiderNotes").get(),
  ]);

  const counts = {
    votes: votesSnap.size,
    comments: commentsSnap.size,
    insiderNotes: notesSnap.size,
  };

  if (confirm) {
    await deleteInBatches(db, restaurantRef.collection("votes"));
    await deleteInBatches(db, restaurantRef.collection("comments"));
    await deleteInBatches(db, restaurantRef.collection("insiderNotes"));
    await restaurantRef.delete();
  }

  return counts;
}

module.exports = {cascadeDeleteRestaurant, deleteInBatches};
