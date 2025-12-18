const functions = require("firebase-functions");
const admin = require("firebase-admin");
const cors = require("cors")({ origin: true });

admin.initializeApp();
const db = admin.firestore();

/* =========================================================
   HELPERS
========================================================= */
async function verifyAuth(req) {
  const authHeader = req.headers.authorization || "";
  if (!authHeader.startsWith("Bearer ")) {
    throw new Error("Missing token");
  }
  const token = authHeader.replace("Bearer ", "");
  return admin.auth().verifyIdToken(token);
}

async function getUser(uid) {
  const snap = await db.collection("users").doc(uid).get();
  if (!snap.exists) throw new Error("User not found");
  return snap.data();
}

function requireRole(user, roles) {
  if (!roles.includes(user.role)) throw new Error("Permission denied");
  if (user.isActive !== true || user.softDeleted === true) {
    throw new Error("User inactive");
  }
}

/* =========================================================
   CREATE DRIVER
========================================================= */
exports.createDriverHttp = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      if (req.method !== "POST") return res.status(405).end();

      const decoded = await verifyAuth(req);
      const caller = await getUser(decoded.uid);
      requireRole(caller, ["dispatch", "admin"]);

      const { name, email, password, phone, plate } = req.body;
      if (!name || !email || !password || !phone || !plate) {
        throw new Error("Missing fields");
      }

      const userRecord = await admin.auth().createUser({
        email,
        password,
        displayName: name,
      });

      const batch = db.batch();

      batch.set(db.collection("users").doc(userRecord.uid), {
        name,
        email,
        phone,
        role: "driver",
        isActive: true,
        softDeleted: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastLoginAt: null,
      });

      batch.set(db.collection("vehicles").doc(), {
        plate: plate.toUpperCase(),
        assignedDriverId: userRecord.uid,
        ownership: "driver",
        type: "truck",
        isActive: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      await batch.commit();
      res.json({ success: true, uid: userRecord.uid });
    } catch (e) {
      console.error(e);
      res.status(400).json({ error: e.message });
    }
  });
});

/* =========================================================
   CREATE USER (ADMIN / MANAGER)
========================================================= */
exports.createUserHttp = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      if (req.method !== "POST") return res.status(405).end();

      const decoded = await verifyAuth(req);
      const caller = await getUser(decoded.uid);
      requireRole(caller, ["admin", "manager"]);

      const { name, email, password, phone, role, plate } = req.body;
      if (!name || !email || !password || !phone || !role) {
        throw new Error("Missing fields");
      }

      const userRecord = await admin.auth().createUser({
        email,
        password,
        displayName: name,
      });

      const batch = db.batch();

      batch.set(db.collection("users").doc(userRecord.uid), {
        name,
        email,
        phone,
        role,
        isActive: true,
        softDeleted: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastLoginAt: null,
      });

      if (role === "driver" && plate) {
        batch.set(db.collection("vehicles").doc(), {
          plate: plate.toUpperCase(),
          assignedDriverId: userRecord.uid,
          ownership: "driver",
          type: "truck",
          isActive: true,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      res.json({ success: true, uid: userRecord.uid });
    } catch (e) {
      console.error(e);
      res.status(400).json({ error: e.message });
    }
  });
});

/* =========================================================
   UPDATE USER
========================================================= */
exports.updateUserHttp = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      if (req.method !== "POST") return res.status(405).end();

      const decoded = await verifyAuth(req);
      const caller = await getUser(decoded.uid);
      requireRole(caller, ["admin", "manager"]);

      const { uid, name, email, phone, role, plate } = req.body;
      if (!uid || !name || !email || !phone || !role) {
        throw new Error("Missing fields");
      }

      const batch = db.batch();

      batch.update(db.collection("users").doc(uid), {
        name,
        email,
        phone,
        role,
      });

      if (role === "driver" && plate) {
        const vehicleSnap = await db
          .collection("vehicles")
          .where("assignedDriverId", "==", uid)
          .limit(1)
          .get();

        if (!vehicleSnap.empty) {
          batch.update(vehicleSnap.docs[0].ref, {
            plate: plate.toUpperCase(),
          });
        } else {
          batch.set(db.collection("vehicles").doc(), {
            plate: plate.toUpperCase(),
            assignedDriverId: uid,
            ownership: "driver",
            type: "truck",
            isActive: true,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();
      res.json({ success: true });
    } catch (e) {
      console.error(e);
      res.status(400).json({ error: e.message });
    }
  });
});

/* =========================================================
   SOFT DELETE USER
========================================================= */
exports.softDeleteUserHttp = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      if (req.method !== "POST") return res.status(405).end();

      const decoded = await verifyAuth(req);
      const caller = await getUser(decoded.uid);
      requireRole(caller, ["admin", "manager"]);

      const { userId } = req.body;
      if (!userId) throw new Error("userId required");

      await db.collection("users").doc(userId).update({
        softDeleted: true,
        isActive: false,
      });

      res.json({ success: true });
    } catch (e) {
      console.error(e);
      res.status(400).json({ error: e.message });
    }
  });
});

/* =========================================================
   JOB ACTIONS (APPROVE / REJECT / COMPLETE)
========================================================= */
exports.jobActionHttp = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      if (req.method !== "POST") return res.status(405).end();

      const decoded = await verifyAuth(req);
      const caller = await getUser(decoded.uid);
      requireRole(caller, ["admin", "manager", "dispatch"]);

      const { jobId, action, reason } = req.body;
      if (!jobId || !action) throw new Error("jobId & action required");

      const jobRef = db.collection("jobs").doc(jobId);
      const jobSnap = await jobRef.get();
      if (!jobSnap.exists) throw new Error("Job not found");

      const now = admin.firestore.FieldValue.serverTimestamp();
      const batch = db.batch();

      if (action === "approve") {
        batch.update(jobRef, {
          status: "approved",
          "timestamps.reviewedAt": now,
        });
      } else if (action === "reject") {
        if (!reason) throw new Error("Rejection reason required");
        batch.update(jobRef, {
          status: "rejected",
          rejectionReason: reason,
          "timestamps.reviewedAt": now,
        });
      } else if (action === "complete") {
        batch.update(jobRef, { status: "completed" });
      } else {
        throw new Error("Invalid action");
      }

      batch.set(jobRef.collection("logs").doc(), {
        action,
        performedBy: decoded.uid,
        performedAt: now,
        note: reason || null,
      });

      await batch.commit();
      res.json({ success: true });
    } catch (e) {
      console.error(e);
      res.status(400).json({ error: e.message });
    }
  });
});
