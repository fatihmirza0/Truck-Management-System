const { onRequest } = require("firebase-functions/v2/https");
const { onCall } = require("firebase-functions/v2/https");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
const cors = require("cors")({ origin: true });
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onValueUpdated } = require("firebase-functions/v2/database");

setGlobalOptions({ maxInstances: 10 });

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
  // 🔥 COMPANY STATUS CHECK
  if (user.companyStatus === 'inactive' && user.role !== 'developer') {
    throw new Error("Company is inactive. Contact support.");
  }
}

/* =========================================================
   MULTI-TENANT SECURITY MIDDLEWARE
========================================================= */
async function ensureSameCompany(callerId, targetUserId) {
  const caller = await getUser(callerId);
  const target = await getUser(targetUserId);

  // If caller is developer, bypass company check (optional, but good for support)
  if (caller.role === 'developer') return { caller, target };

  if (!caller.companyId) throw new Error("Caller has no companyId");
  if (!target.companyId) throw new Error("Target has no companyId");
  if (caller.companyId !== target.companyId) {
    throw new Error("Cross-company access denied");
  }

  return { caller, target };
}

async function ensureJobBelongsToCompany(callerId, jobId) {
  const caller = await getUser(callerId);
  const jobSnap = await db.collection("jobs").doc(jobId).get();

  if (!jobSnap.exists) throw new Error("Job not found");
  const job = jobSnap.data();

  // Developer bypass
  if (caller.role === 'developer') return { caller, job };

  if (!caller.companyId) throw new Error("Caller has no companyId");
  if (!job.companyId) throw new Error("Job has no companyId");
  if (caller.companyId !== job.companyId) {
    throw new Error("Cross-company job access denied");
  }

  return { caller, job };
}

/* =========================================================
   CREATE DRIVER
========================================================= */
exports.createDriverHttp = onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      if (req.method !== "POST") return res.status(405).end();

      const decoded = await verifyAuth(req);
      const caller = await getUser(decoded.uid);
      requireRole(caller, ["dispatch", "admin", "manager"]); // 🔥 Added manager

      const { name, email, password, phone, plate } = req.body;
      if (!name || !email || !password || !phone || !plate) {
        throw new Error("Missing fields");
      }

      // 🔥 SAAS FIX: Driver receives same companyId as the Manager/Dispatch interacting
      const companyId = caller.companyId;
      if (!companyId) throw new Error("Caller has no companyId");

      // 🛑 LIMIT CHECK: Vehicle Count
      const companyDoc = await db.collection("companies").doc(companyId).get();
      const companyData = companyDoc.data();
      const vehicleLimit = companyData.limits?.vehicleCount || 10; // Default 10

      const currentVehicles = await db.collection("vehicles")
        .where("companyId", "==", companyId)
        .where("isActive", "==", true)
        .count()
        .get();

      if (currentVehicles.data().count >= vehicleLimit) {
        throw new Error(`Vehicle limit reached (${vehicleLimit}). Upgrade plan.`);
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
        companyId, // ✅ Multi-tenancy
        isActive: true,
        softDeleted: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastLoginAt: null,
        activePlate: plate ?? null,
        jobStatus: "available",
      });

      batch.set(db.collection("vehicles").doc(), {
        plate: plate.toUpperCase(),
        assignedDriverId: userRecord.uid,
        companyId, // ✅ Multi-tenancy
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
   Modified for SaaS: Assigns caller's companyId to new user/vehicle
 ========================================================= */
exports.createUserHttp = onRequest((req, res) => {
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

      // 🔥 SAAS FIX
      const companyId = caller.companyId;
      if (!companyId) throw new Error("Caller has no companyId");

      // 🛑 LIMIT CHECK: Manager/Dispatch Count
      const companyDoc = await db.collection("companies").doc(companyId).get();
      const companyData = companyDoc.data();

      if (role === 'manager') {
        const limit = companyData.limits?.managerCount || 1; // Default 1
        const current = await db.collection("users")
          .where("companyId", "==", companyId)
          .where("role", "==", "manager")
          .where("softDeleted", "==", false)
          .count().get();

        if (current.data().count >= limit) {
          throw new Error(`Manager limit reached (${limit}). Upgrade plan.`);
        }
      }

      if (role === 'dispatch') {
        const limit = companyData.limits?.dispatchCount || 3; // Default 3
        const current = await db.collection("users")
          .where("companyId", "==", companyId)
          .where("role", "==", "dispatch")
          .where("softDeleted", "==", false)
          .count().get();

        if (current.data().count >= limit) {
          throw new Error(`Dispatch limit reached (${limit}). Upgrade plan.`);
        }
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
        companyId, // ✅
        isActive: true,
        softDeleted: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastLoginAt: null,
      });

      if (role === "driver" && plate) {
        batch.set(db.collection("vehicles").doc(), {
          plate: plate.toUpperCase(),
          assignedDriverId: userRecord.uid,
          companyId, // ✅
          ownership: "driver",
          type: "truck",
          isActive: true,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        batch.update(db.collection("users").doc(userRecord.uid), {
          jobStatus: "available",
          activePlate: plate ?? null,
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
exports.updateUserHttp = onRequest((req, res) => {
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

      // 🔒 SECURITY: Ensure same company
      await ensureSameCompany(decoded.uid, uid);

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

        // Ensure companyId is consistent
        const companyId = caller.companyId;

        if (!vehicleSnap.empty) {
          batch.update(vehicleSnap.docs[0].ref, {
            plate: plate.toUpperCase(),
          });
        } else {
          batch.set(db.collection("vehicles").doc(), {
            plate: plate.toUpperCase(),
            assignedDriverId: uid,
            companyId, // ✅
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
exports.softDeleteUserHttp = onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      if (req.method !== "POST") return res.status(405).end();

      const decoded = await verifyAuth(req);
      const caller = await getUser(decoded.uid);
      requireRole(caller, ["admin", "manager"]);

      const { userId } = req.body;
      if (!userId) throw new Error("userId required");

      // 🔒 SECURITY: Ensure same company
      await ensureSameCompany(decoded.uid, userId);

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
   JOB ACTIONS (APPROVE / REJECT / COMPLETE) - isOnline FIX ✅
========================================================= */
exports.jobAction = onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      if (req.method !== "POST") return res.status(405).end();

      const decoded = await verifyAuth(req);
      const { jobId, action, reason } = req.body;
      if (!jobId || !action) throw new Error("jobId & action required");

      // 🔒 SECURITY: Ensure job belongs to caller's company
      const { caller, job } = await ensureJobBelongsToCompany(decoded.uid, jobId);
      requireRole(caller, ["admin", "manager", "dispatch", "driver"]);

      const jobRef = db.collection("jobs").doc(jobId);
      const now = admin.firestore.FieldValue.serverTimestamp();
      const batch = db.batch();

      if (action === "approve") {
        // ✅ Manager onayladığında driver BUSY olur
        batch.update(jobRef, {
          status: "approved",
          "timestamps.reviewedAt": now,
          reviewedBy: decoded.uid,
        });

        if (job.driverId) {
          // Firestore: jobStatus = busy
          batch.update(db.collection("users").doc(job.driverId), {
            jobStatus: "busy",
            currentJobId: jobId,
          });

          // ✅ RTDB: SADECE currentJobId güncelle, isOnline'a DOKUNMA
          try {
            await admin.database().ref(`locations/${job.driverId}`).update({
              currentJobId: jobId,
              timestamp: admin.database.ServerValue.TIMESTAMP,
              lastPing: admin.database.ServerValue.TIMESTAMP,
              offlineNotified: false, // Reset notification flag
            });
            console.log(`✅ RTDB: ${job.driverId} -> job approved`);
          } catch (rtdbError) {
            console.error("⚠️ RTDB update error:", rtdbError);
          }
        }

      } else if (action === "reject") {
        // ✅ Manager reddederse driver AVAILABLE olur
        if (!reason) throw new Error("Rejection reason required");

        batch.update(jobRef, {
          status: "rejected",
          rejectionReason: reason,
          "timestamps.reviewedAt": now,
          reviewedBy: decoded.uid,
        });

        if (job.driverId) {
          // ✅ Firestore: jobStatus = available
          batch.update(db.collection("users").doc(job.driverId), {
            jobStatus: "available",
            currentJobId: null,
          });

          // ✅ RTDB: currentJobId sil, isOnline'a DOKUNMA
          try {
            await admin.database().ref(`locations/${job.driverId}`).update({
              currentJobId: null,
              timestamp: admin.database.ServerValue.TIMESTAMP,
              lastPing: admin.database.ServerValue.TIMESTAMP,
              offlineNotified: false, // Reset notification flag
            });
            console.log(`✅ RTDB: ${job.driverId} -> job rejected`);
          } catch (rtdbError) {
            console.error("⚠️ RTDB update error:", rtdbError);
          }
        }

      } else if (action === "complete") {
        // ✅ Driver sadece kendi işini tamamlayabilir
        if (caller.role === "driver" && job.driverId !== decoded.uid) {
          throw new Error("Unauthorized");
        }

        batch.update(jobRef, {
          status: "completed",
          "timestamps.completedAt": now,
        });

        if (job.driverId) {
          // ✅ Firestore: jobStatus = available
          batch.update(db.collection("users").doc(job.driverId), {
            jobStatus: "available",
            currentJobId: null,
          });

          // ✅ RTDB: currentJobId sil, isOnline'a DOKUNMA
          try {
            await admin.database().ref(`locations/${job.driverId}`).update({
              currentJobId: null,
              timestamp: admin.database.ServerValue.TIMESTAMP,
              lastPing: admin.database.ServerValue.TIMESTAMP,
              offlineNotified: false, // Reset notification flag
            });
            console.log(`✅ RTDB: ${job.driverId} -> job completed`);
          } catch (rtdbError) {
            console.error("⚠️ RTDB update error:", rtdbError);
          }
        }

      } else {
        throw new Error("Invalid action");
      }

      // Log kaydet
      batch.set(jobRef.collection("logs").doc(), {
        action,
        performedBy: decoded.uid,
        performedAt: now,
        note: reason || null,
      });

      await batch.commit();

      console.log(`✅ Job ${action}: ${jobId} by ${decoded.uid}`);
      res.json({ success: true });

    } catch (e) {
      console.error("❌ jobAction error:", e);
      res.status(400).json({ error: e.message });
    }
  });
});
/* =========================================================
   SYNC ACTIVE PLATE FROM VEHICLES
========================================================= */
exports.syncActivePlateFromVehicles = onRequest(async (req, res) => {
  try {
    // 🔒 SECURITY: Require auth and filter by companyId
    const decoded = await verifyAuth(req);
    const caller = await getUser(decoded.uid);
    requireRole(caller, ["admin", "manager"]);

    const vehiclesSnap = await db
      .collection("vehicles")
      .where("companyId", "==", caller.companyId)  // 🔒 Filter by company
      .where("assignedDriverId", "!=", null)
      .get();

    const batch = db.batch();
    let updated = 0;
    let skipped = 0;

    for (const vehicleDoc of vehiclesSnap.docs) {
      const v = vehicleDoc.data();
      const driverId = v.assignedDriverId;

      if (!driverId) continue;

      const driverRef = db.collection("users").doc(driverId);
      const driverSnap = await driverRef.get();

      if (!driverSnap.exists) {
        console.warn(`Driver not found: ${driverId}`);
        skipped++;
        continue;
      }

      batch.update(driverRef, {
        activePlate: v.plate,
        activeVehicleId: vehicleDoc.id,
      });

      updated++;
    }

    if (updated > 0) await batch.commit();

    res.json({
      success: true,
      syncedDrivers: updated,
      skippedVehicles: skipped,
    });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: e.message });
  }
});

/* =========================================================
   FCM NOTIFICATIONS - JOB CREATED
========================================================= */
exports.notifyManagersOnJobCreated = onDocumentCreated(
  "jobs/{jobId}",
  async (event) => {
    const snap = event.data;
    if (!snap) {
      console.log("❌ Snap data yok");
      return;
    }

    const job = snap.data();
    const jobId = event.params.jobId;

    console.log("🚀 Yeni job oluşturuldu:", jobId);

    try {
      const managersSnapshot = await db
        .collection("users")
        .where("role", "==", "manager")
        .get();

      console.log(`👥 ${managersSnapshot.size} manager bulundu`);

      const tokens = [];
      managersSnapshot.forEach((doc) => {
        const data = doc.data();
        if (data.fcmToken) {
          tokens.push(data.fcmToken);
        }
      });

      console.log(`📱 ${tokens.length} aktif manager token bulundu`);

      if (tokens.length === 0) {
        console.log("⚠️ Bildirim gönderilebilecek manager yok");
        return;
      }

      const promises = tokens.map((token) => {
        return admin.messaging().send({
          notification: {
            title: "🚛 Yeni İş Ataması",
            body: `${job.driverName || "Bir sürücü"} için yeni iş oluşturuldu`,
          },
          data: {
            jobId: jobId,
            type: "new_job",
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
          token: token,
        }).catch(async (error) => {
          console.error(`❌ Token hatası (${token.substring(0, 20)}...):`, error.code);

          if (error.code === "messaging/invalid-registration-token" ||
            error.code === "messaging/registration-token-not-registered") {
            const userSnapshot = await db
              .collection("users")
              .where("fcmToken", "==", token)
              .get();

            const deletePromises = userSnapshot.docs.map((doc) =>
              doc.ref.update({ fcmToken: admin.firestore.FieldValue.delete() }),
            );

            await Promise.all(deletePromises);
          }
          return null;
        });
      });

      const results = await Promise.all(promises);
      const successCount = results.filter((r) => r !== null).length;

      console.log(`✅ ${successCount}/${tokens.length} manager bildirimi gönderildi`);
    } catch (error) {
      console.error("❌ Bildirim gönderme hatası:", error);
    }
  },
);

/* =========================================================
   FCM NOTIFICATIONS - JOB STATUS UPDATES
========================================================= */
exports.notifyOnJobStatusChange = onDocumentUpdated(
  "jobs/{jobId}",
  async (event) => {
    const beforeSnap = event.data.before;
    const afterSnap = event.data.after;

    if (!beforeSnap || !afterSnap) {
      return;
    }

    const before = beforeSnap.data();
    const after = afterSnap.data();
    const jobId = event.params.jobId;

    try {
      // ========================================
      // 1️⃣ JOB APPROVED → DISPATCH + DRIVER'A BİLDİRİM
      // ========================================
      if (before.status !== "approved" && after.status === "approved") {
        console.log("✅ Job onaylandı:", jobId);

        // A) DISPATCH'E BİLDİRİM
        if (after.createdBy) {
          const dispatchDoc = await db
            .collection("users")
            .doc(after.createdBy)
            .get();

          if (dispatchDoc.exists) {
            const dispatchData = dispatchDoc.data();
            if (dispatchData.fcmToken) {
              await admin.messaging().send({
                notification: {
                  title: "✅ İş Onaylandı!",
                  body: `Oluşturduğunuz iş onaylandı: ${after.driverName || "Sürücü"} - ${after.title || "İş detayı"}`,
                },
                data: {
                  jobId: jobId,
                  type: "job_approved",
                  click_action: "FLUTTER_NOTIFICATION_CLICK",
                },
                token: dispatchData.fcmToken,
              }).catch((error) => {
                console.error("❌ Dispatch bildirim hatası:", error.code);
                return null;
              });

              console.log("✅ Dispatch'e onay bildirimi gönderildi");
            }
          }
        }

        // B) DRIVER'A BİLDİRİM
        if (after.driverId) {
          const driverDoc = await db
            .collection("users")
            .doc(after.driverId)
            .get();

          if (driverDoc.exists) {
            const driverData = driverDoc.data();
            if (driverData.fcmToken) {
              await admin.messaging().send({
                notification: {
                  title: "🚛 Yeni İş Ataması!",
                  body: `Size yeni bir iş atandı: ${after.title || "Detayları görmek için tıklayın"}`,
                },
                data: {
                  jobId: jobId,
                  type: "new_job_assigned",
                  click_action: "FLUTTER_NOTIFICATION_CLICK",
                },
                token: driverData.fcmToken,
              }).catch(async (error) => {
                console.error("❌ Driver bildirim hatası:", error.code);

                if (error.code === "messaging/invalid-registration-token" ||
                  error.code === "messaging/registration-token-not-registered") {
                  await driverDoc.ref.update({
                    fcmToken: admin.firestore.FieldValue.delete(),
                  });
                }
              });

              console.log("✅ Driver'a iş ataması bildirimi gönderildi");
            }
          }
        }
      }

      // ========================================
      // 2️⃣ JOB COMPLETED → MANAGER + DISPATCH'E BİLDİRİM
      // ========================================
      if (before.status !== "completed" && after.status === "completed") {
        console.log("✅ Job tamamlandı:", jobId);

        // A) MANAGER'LARA BİLDİRİM
        const managersSnapshot = await db
          .collection("users")
          .where("role", "==", "manager")
          .get();

        const tokens = [];
        managersSnapshot.forEach((doc) => {
          const data = doc.data();
          if (data.fcmToken) {
            tokens.push(data.fcmToken);
          }
        });

        if (tokens.length > 0) {
          const promises = tokens.map((token) => {
            return admin.messaging().send({
              notification: {
                title: "✅ İş Tamamlandı",
                body: `${after.driverName || "Bir sürücü"} işi tamamladı`,
              },
              data: {
                jobId: jobId,
                type: "job_completed",
                click_action: "FLUTTER_NOTIFICATION_CLICK",
              },
              token: token,
            }).catch((error) => {
              console.error("❌ Manager bildirim hatası:", error.code);
              return null;
            });
          });

          await Promise.all(promises);
          console.log("✅ Manager'lara tamamlanma bildirimleri gönderildi");
        }

        // B) DISPATCH'E BİLDİRİM
        if (after.createdBy) {
          const dispatchDoc = await db
            .collection("users")
            .doc(after.createdBy)
            .get();

          if (dispatchDoc.exists) {
            const dispatchData = dispatchDoc.data();
            if (dispatchData.fcmToken) {
              await admin.messaging().send({
                notification: {
                  title: "🎉 İş Tamamlandı!",
                  body: `Atadığınız iş tamamlandı: ${after.driverName || "Sürücü"} - ${after.title || "İş detayı"}`,
                },
                data: {
                  jobId: jobId,
                  type: "job_completed_dispatch",
                  click_action: "FLUTTER_NOTIFICATION_CLICK",
                },
                token: dispatchData.fcmToken,
              }).catch((error) => {
                console.error("❌ Dispatch tamamlanma bildirimi hatası:", error.code);
                return null;
              });

              console.log("✅ Dispatch'e tamamlanma bildirimi gönderildi");
            }
          }
        }
      }
    } catch (error) {
      console.error("❌ Status change bildirim hatası:", error);
    }
  },
);

exports.updateLastLoginHttp = onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      if (req.method !== "POST") {
        return res.status(405).json({ error: "Method not allowed" });
      }

      const decoded = await verifyAuth(req);

      await db.collection("users").doc(decoded.uid).update({
        lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      res.json({ success: true });
    } catch (e) {
      console.error(e);
      res.status(401).json({ error: e.message });
    }
  });
});

exports.clearFcmTokenHttp = onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      const decoded = await verifyAuth(req);
      await db.collection("users").doc(decoded.uid).update({
        fcmToken: admin.firestore.FieldValue.delete(),
      });
      res.json({ success: true });
    } catch (e) {
      res.status(400).json({ error: e.message });
    }
  });
});

exports.getLiveDriverLocations = onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Headers", "Authorization, Content-Type");
  res.set("Access-Control-Allow-Methods", "GET, OPTIONS");

  if (req.method === "OPTIONS") {
    return res.status(204).send("");
  }

  try {
    const authHeader = req.headers.authorization || "";
    if (!authHeader.startsWith("Bearer ")) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    const token = authHeader.replace("Bearer ", "");
    const decoded = await admin.auth().verifyIdToken(token);

    const userSnap = await db.collection("users").doc(decoded.uid).get();

    if (!userSnap.exists) {
      return res.status(403).json({ error: "User not found" });
    }

    const user = userSnap.data();

    if (!["manager", "dispatch"].includes(user.role)) {
      return res.status(403).json({ error: "Forbidden" });
    }

    const rtdb = admin.database();

    const [locationsSnap, historySnap] = await Promise.all([
      rtdb.ref("locations").get(),
      rtdb.ref("history").get(),
    ]);

    const allLocations = locationsSnap.exists() ? locationsSnap.val() : {};
    const allHistory = historySnap.exists() ? historySnap.val() : {};

    // 🔒 SECURITY: Filter by companyId
    const locations = {};
    const history = {};

    // 🔥 OPTIMIZATION: Filter first using RTDB companyId data
    // Only fetch Firestore details for drivers that match companyId

    const driverIdsToFetch = [];

    for (const [driverId, data] of Object.entries(allLocations)) {
      // If RTDB has correct companyId, keep it
      if (data.companyId && data.companyId === user.companyId) {
        locations[driverId] = data; // Keep raw data first
        driverIdsToFetch.push(driverId);
      }
      // If RTDB has NO companyId (legacy), we must check Firestore
      else if (!data.companyId) {
        driverIdsToFetch.push(driverId);
      }
      // If mismatch, skip immediately (saves read)
    }

    // Batch fetch (or parallel fetch) details for candidate drivers
    // Firestore IN query limit is 10/30, so efficient parallel fetches are better

    // We can't do 'where in' easily with IDs in a list efficiently for >10 items without chunking.
    // Parallel gets are OK.

    const validDrivers = [];

    await Promise.all(driverIdsToFetch.map(async (driverId) => {
      try {
        const driverSnap = await db.collection("users").doc(driverId).get();
        if (driverSnap.exists) {
          const dData = driverSnap.data();
          if (dData.companyId === user.companyId) {
            // If it was legacy (no companyId in RTDB), add it now
            if (!locations[driverId]) {
              locations[driverId] = allLocations[driverId];
            }
            validDrivers.push(driverId);
          } else {
            // Mismatch found after fetch (legacy case), ensure removed
            delete locations[driverId];
          }
        } else {
          delete locations[driverId];
        }
      } catch (e) {
        console.warn(`Failed to verify driver ${driverId}`, e);
        delete locations[driverId];
      }
    }));

    // Filter history based on valid drivers
    for (const driverId of validDrivers) {
      if (allHistory[driverId]) {
        history[driverId] = allHistory[driverId];
      }
    }

    console.log(`✅ Live drivers (filtered): ${Object.keys(locations).length} (from ${Object.keys(allLocations).length})`);

    return res.status(200).json({
      success: true,
      locations,
      history,
    });

  } catch (error) {
    console.error("❌ getLiveDriverLocations error:", error);
    return res.status(500).json({
      error: "Internal server error",
      message: error.message,
    });
  }
});


/* =========================================================
   CHECK DRIVER OFFLINE - ✅ COMPLETE FIX
   - 3 dakika boyunca lastPing güncellemeyenleri OFFLINE yap
   - Busy olanlar için bildirim gönder (TEK SEFER)
   - isOnline: false YAPARAK DÜZELT
========================================================= */
exports.checkDriverOffline = onSchedule(
  {
    schedule: "every 2 minutes",
    timeZone: "Europe/Istanbul",
    region: "us-central1",
  },
  async () => {
    console.log("=".repeat(60));
    console.log("🚀 DRIVER OFFLINE CHECK STARTED");

    try {
      const now = Date.now();
      const OFFLINE_THRESHOLD = 180000; // 3 dakika

      // 1️⃣ RTDB'den TÜM location'ları al
      const locationsSnap = await admin.database().ref("locations").get();

      if (!locationsSnap.exists()) {
        console.log("ℹ️ No locations data in RTDB");
        return null;
      }

      const locations = locationsSnap.val();
      const updates = {}; // Batch update için
      const notifications = []; // Bildirim listesi

      let onlineCount = 0;
      let offlineCount = 0;
      let processedCount = 0;

      // 2️⃣ Her driver'ı kontrol et
      for (const [driverId, location] of Object.entries(locations)) {
        processedCount++;

        // 🔥 disconnectTest gibi test node'larını atla
        if (typeof location !== 'object' || location === null) {
          continue;
        }

        const lastPing = location.lastPing || 0;
        const isOnline = location.isOnline === true;
        const timeDiff = now - lastPing;

        // ✅ Zaten offline ise geç
        if (!isOnline) {
          offlineCount++;
          continue;
        }

        // ✅ 3 dakikadan fazla ping yoksa OFFLINE yap
        if (timeDiff > OFFLINE_THRESHOLD) {
          updates[`locations/${driverId}/isOnline`] = false;
          updates[`locations/${driverId}/timestamp`] = admin.database.ServerValue.TIMESTAMP;

          offlineCount++;
          console.log(`⚠️ ${driverId} marked offline (${Math.floor(timeDiff / 1000)}s)`);

          // 3️⃣ SADECE BUSY driver'lar için bildirim
          try {
            const driverDoc = await admin
              .firestore()
              .collection("users")
              .doc(driverId)
              .get();

            if (driverDoc.exists) {
              const driver = driverDoc.data();

              // 🔥 Busy + FCM token var + henüz bildirilmemiş
              if (
                driver.jobStatus === "busy" &&
                driver.fcmToken &&
                !location.offlineNotified
              ) {
                notifications.push({
                  driverId,
                  token: driver.fcmToken,
                  name: driver.name || "Sürücü",
                  plate: driver.activePlate || "—",
                });

                updates[`locations/${driverId}/offlineNotified`] = true;
              }
            }
          } catch (err) {
            console.error(`⚠️ Firestore read error for ${driverId}:`, err.message);
          }
        } else {
          onlineCount++;
        }
      }

      // 4️⃣ RTDB'yi toplu güncelle
      if (Object.keys(updates).length > 0) {
        await admin.database().ref().update(updates);
        console.log(`✅ Updated ${Object.keys(updates).length / 2} drivers to offline`);
      } else {
        console.log("ℹ️ No offline drivers to update");
      }

      // 5️⃣ Bildirimleri gönder
      if (notifications.length > 0) {
        console.log(`📤 Sending ${notifications.length} notifications`);

        for (const item of notifications) {
          try {
            await admin.messaging().send({
              token: item.token,
              notification: {
                title: "⚠️ Sürücü Bağlantısı Kesildi",
                body: `${item.name} (${item.plate}) konum göndermiyor.`,
              },
              data: {
                type: "driver_offline",
                driverId: item.driverId,
              },
              android: {
                priority: "high",
                notification: {
                  channelId: "driver_offline_channel",
                  sound: "default",
                },
              },
            });

            console.log(`✅ Notification sent → ${item.name}`);
          } catch (err) {
            console.error(`❌ Notification failed:`, err.code);

            // Token geçersizse temizle
            if (
              err.code === "messaging/invalid-registration-token" ||
              err.code === "messaging/registration-token-not-registered"
            ) {
              await admin
                .firestore()
                .collection("users")
                .doc(item.driverId)
                .update({
                  fcmToken: admin.firestore.FieldValue.delete(),
                });
            }
          }
        }
      }

      console.log(`📊 Stats: Processed=${processedCount} Online=${onlineCount} Offline=${offlineCount}`);
      console.log("✅ OFFLINE CHECK FINISHED");
      console.log("=".repeat(60));
      return null;
    } catch (err) {
      console.error("🔥 FATAL ERROR:", err);
      return null;
    }
  }
);

/* =========================================================
   DEVELOPER PANEL EXPORTS
   ========================================================= */
// index.js dosyasında, DEVELOPER PANEL EXPORTS kısmına

const devPanel = require("./developer_panel");
exports.verifyDeveloperKey = devPanel.verifyDeveloperKey;
exports.createCompanyHttp = devPanel.createCompanyHttp;
exports.getSystemLogsHttp = devPanel.getSystemLogsHttp;  // ✅ Bu satırı ekleyin
exports.getCompaniesHttp = devPanel.getCompaniesHttp;
exports.getCompanyUsersHttp = devPanel.getCompanyUsersHttp;
exports.updateUserPermissionsHttp = devPanel.updateUserPermissionsHttp;
exports.getDashboardStatsHttp = devPanel.getDashboardStatsHttp;
exports.getCompanyFullDetailsHttp = devPanel.getCompanyFullDetailsHttp;
exports.updateCompanyPlanHttp = devPanel.updateCompanyPlanHttp;
exports.toggleCompanyStatusHttp = devPanel.toggleCompanyStatusHttp; // ✅ Added
// Token & Session Management
exports.developerLogin = devPanel.developerLogin;
exports.developerLogout = devPanel.developerLogout;
exports.cleanExpiredSessions = devPanel.cleanExpiredSessions;

/* =========================================================
   CREATE JOB (HTTP)
   - Dispatches job creation to backend
   - Handles driver status update atomically
   - Enforces SaaS security
 ========================================================= */
exports.createJobHttp = onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      if (req.method !== "POST") return res.status(405).end();

      const decoded = await verifyAuth(req);
      const caller = await getUser(decoded.uid);
      requireRole(caller, ["admin", "manager", "dispatch"]);

      const {
        driverId,
        vehicleId,
        loadPort,
        unloadPort,
        cargoType,
        cargoDescription,
        cargoWeightKg,
        distanceKm
      } = req.body;

      if (!driverId || !vehicleId || !loadPort || !unloadPort) {
        throw new Error("Missing required fields");
      }

      // 🔒 SECURITY: Ensure caller has companyId
      const companyId = caller.companyId;
      if (!companyId) throw new Error("Caller has no companyId");

      // 🔒 SECURITY: Verify driver belongs to same company
      const driverSnap = await db.collection("users").doc(driverId).get();
      if (!driverSnap.exists) throw new Error("Driver not found");
      const driverData = driverSnap.data();

      if (driverData.companyId !== companyId) {
        throw new Error("Driver belongs to different company");
      }

      // 🔒 SECURITY: Verify vehicle belongs to same company
      const vehicleSnap = await db.collection("vehicles").doc(vehicleId).get();
      if (!vehicleSnap.exists) throw new Error("Vehicle not found");
      const vehicleData = vehicleSnap.data();

      if (vehicleData.companyId !== companyId) {
        throw new Error("Vehicle belongs to different company");
      }

      // Check if driver is available
      if (driverData.jobStatus === 'busy') {
        throw new Error("Driver is currently busy");
      }

      const timestamp = Date.now();
      const referenceNo = `JOB-${timestamp}`;

      const batch = db.batch();
      const jobRef = db.collection("jobs").doc();

      // 1. Create Job
      batch.set(jobRef, {
        referenceNo,
        companyId, // ✅ SAAS
        driverId,
        vehicleId,
        createdBy: decoded.uid,
        status: "pending", // Initially pending (or approved/assigned based on logic)
        rejectionReason: null,
        route: {
          loadPort: loadPort.trim(),
          unloadPort: unloadPort.trim(),
        },
        cargo: {
          type: cargoType?.trim() || "",
          description: cargoDescription?.trim() || "",
          weightKg: Number(cargoWeightKg) || 0,
        },
        distanceKm: Number(distanceKm) || 0,
        timestamps: {
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          reviewedAt: null,
        },
        softDeleted: false,
        driverName: driverData.name || "Unknown", // Snapshot for list performance
        vehiclePlate: vehicleData.plate || "Unknown", // Snapshot for list performance
      });

      // 2. Add Log
      const logRef = jobRef.collection("logs").doc();
      batch.set(logRef, {
        action: "created",
        performedBy: decoded.uid,
        performedAt: admin.firestore.FieldValue.serverTimestamp(),
        note: null,
      });

      // 3. Update Driver Status to BUSY
      batch.update(db.collection("users").doc(driverId), {
        jobStatus: "busy",
        currentJobId: jobRef.id
      });

      await batch.commit();

      res.json({ success: true, jobId: jobRef.id });

    } catch (e) {
      console.error("❌ createJobHttp error:", e);
      res.status(400).json({ error: e.message });
    }
  });
});

/* =========================================================
   MANAGER PANEL ENHANCEMENTS
   - getManagerDashboardData
   - getManagerLogs
   - updateCompanyGoals
========================================================= */

/**
 * Returns dashboard statistics, goals, and recent jobs for managers.
 * Strictly scoped to the caller's company.
 */
exports.getManagerDashboardData = onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      const decoded = await verifyAuth(req);
      const user = await getUser(decoded.uid);
      requireRole(user, ["manager", "admin"]);

      const companyId = user.companyId;
      if (!companyId) throw new Error("No company linked to user");

      // Calculate "Today" and "Month" starts
      const today = new Date();
      today.setHours(0, 0, 0, 0);

      const monthStart = new Date();
      monthStart.setDate(1);
      monthStart.setHours(0, 0, 0, 0);

      // Parallel fetching for performance
      const [
        companySnap,
        vehiclesCount,
        jobsCountToday,
        activeJobsCount,
        recentJobsSnap,
        totalDriversCount,
        activeDriversCount,
        jobsCountMonth,
        pendingJobsCount,
        approvedJobsCount,
        completedJobsTotal
      ] = await Promise.all([
        db.collection("companies").doc(companyId).get(),
        db.collection("vehicles").where("companyId", "==", companyId).where("isActive", "==", true).count().get(),
        db.collection("jobs").where("companyId", "==", companyId).where("timestamps.completedAt", ">=", admin.firestore.Timestamp.fromDate(today)).count().get(),
        db.collection("jobs").where("companyId", "==", companyId).where("status", "in", ["pending", "approved", "started"]).count().get(),
        db.collection("jobs").where("companyId", "==", companyId).orderBy("timestamps.createdAt", "desc").limit(10).get(),
        db.collection("users").where("companyId", "==", companyId).where("role", "==", "driver").count().get(),
        db.collection("users").where("companyId", "==", companyId).where("role", "==", "driver").where("isActive", "==", true).count().get(),
        db.collection("jobs").where("companyId", "==", companyId).where("timestamps.completedAt", ">=", admin.firestore.Timestamp.fromDate(monthStart)).count().get(),
        db.collection("jobs").where("companyId", "==", companyId).where("status", "==", "pending").count().get(),
        db.collection("jobs").where("companyId", "==", companyId).where("status", "==", "approved").count().get(),
        db.collection("jobs").where("companyId", "==", companyId).where("status", "==", "completed").count().get()
      ]);

      const companyData = companySnap.data();
      const recentJobs = recentJobsSnap.docs.map(doc => ({ id: doc.id, ...doc.data() }));

      res.json({
        success: true,
        stats: {
          totalVehicles: vehiclesCount.data().count,
          completedJobsToday: jobsCountToday.data().count,
          completedJobsMonth: jobsCountMonth.data().count,
          activeJobs: activeJobsCount.data().count,
          totalDrivers: totalDriversCount.data().count,
          activeDrivers: activeDriversCount.data().count,
          distribution: {
            pending: pendingJobsCount.data().count,
            approved: approvedJobsCount.data().count,
            completed: completedJobsTotal.data().count
          }
        },
        goals: companyData.goals || { monthlyJobTarget: 0, monthlyRevenueTarget: 0 },
        recentJobs: recentJobs
      });

    } catch (e) {
      console.error("getManagerDashboardData error:", e);
      res.status(400).json({ error: e.message });
    }
  });
});

/**
 * Returns an audit trail of activities within the manager's company.
 * Includes: Job creations, logins, status changes.
 */
exports.getManagerLogs = onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      const decoded = await verifyAuth(req);
      const user = await getUser(decoded.uid);
      requireRole(user, ["manager", "admin"]);

      const companyId = user.companyId;
      if (!companyId) throw new Error("No company linked to user");

      // Aggregate from multiple sources within the company
      const [jobsSnap, usersSnap] = await Promise.all([
        db.collection("jobs")
          .where("companyId", "==", companyId)
          .orderBy("timestamps.createdAt", "desc")
          .limit(30)
          .get(),
        db.collection("users")
          .where("companyId", "==", companyId)
          .orderBy("lastLoginAt", "desc")
          .limit(20)
          .get()
      ]);

      const logs = [];

      // 1. Job Creation Logs
      jobsSnap.forEach(doc => {
        const data = doc.data();
        logs.push({
          type: 'JOB_ACTIVITY',
          message: `İş oluşturuldu: ${data.referenceNo}`,
          description: `${data.createdByEmail || 'Bir kullanıcı'} tarafından oluşturuldu.`,
          timestamp: data.timestamps?.createdAt?.toDate(),
          status: data.status,
          id: doc.id
        });
      });

      // 2. Login Logs
      usersSnap.forEach(doc => {
        const data = doc.data();
        if (data.lastLoginAt) {
          logs.push({
            type: 'LOGIN_ACTIVITY',
            message: `Giriş yapıldı: ${data.name}`,
            description: `${data.email} uygulamaya giriş yaptı.`,
            timestamp: data.lastLoginAt.toDate(),
            id: doc.id
          });
        }
      });

      // Sort combined logs by timestamp
      logs.sort((a, b) => b.timestamp - a.timestamp);

      res.json({
        success: true,
        logs: logs.slice(0, 50)
      });

    } catch (e) {
      console.error("getManagerLogs error:", e);
      res.status(400).json({ error: e.message });
    }
  });
});

/**
 * Updates company goals (targets).
 */
exports.updateCompanyGoals = onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      if (req.method !== "POST") return res.status(405).end();

      const decoded = await verifyAuth(req);
      const user = await getUser(decoded.uid);
      requireRole(user, ["manager", "admin"]);

      const companyId = user.companyId;
      if (!companyId) throw new Error("No company linked to user");

      const { monthlyJobTarget, monthlyRevenueTarget } = req.body;

      await db.collection("companies").doc(companyId).update({
        goals: {
          monthlyJobTarget: parseInt(monthlyJobTarget) || 0,
          monthlyRevenueTarget: parseInt(monthlyRevenueTarget) || 0,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        }
      });

      res.json({ success: true });

    } catch (e) {
      console.error("updateCompanyGoals error:", e);
      res.status(400).json({ error: e.message });
    }
  });
});



exports.onCompanyStatusChange = onDocumentUpdated("companies/{companyId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();

  if (before.status === after.status) return;

  const companyId = event.params.companyId;
  const newStatus = after.status;

  console.log(`🔄 Syncing company status ${newStatus} to users of ${companyId}`);

  const usersSnap = await db.collection("users")
    .where("companyId", "==", companyId)
    .get();

  if (usersSnap.empty) return;

  const batch = db.batch();
  usersSnap.docs.forEach(doc => {
    batch.update(doc.ref, { companyStatus: newStatus });
  });

  await batch.commit();
  console.log(`✅ Synced status to ${usersSnap.size} users.`);
});