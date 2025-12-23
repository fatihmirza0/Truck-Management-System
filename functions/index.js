const {onRequest} = require("firebase-functions/v2/https");
const {onCall} = require("firebase-functions/v2/https");
const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {setGlobalOptions} = require("firebase-functions/v2");
const admin = require("firebase-admin");
const cors = require("cors")({ origin: true });

// Global ayarlar
setGlobalOptions({maxInstances: 10});

// Firebase Admin'i SADECE BİR KEZ başlat
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
exports.createDriverHttp = onRequest((req, res) => {
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
        activePlate: plate ?? null,
        jobStatus: "available",
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
exports.softDeleteUserHttp = onRequest((req, res) => {
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
   JOB ACTIONS (APPROVE / REJECT / COMPLETE) - CALLABLE
========================================================= */
exports.jobAction = onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      if (req.method !== "POST") return res.status(405).end();

      const decoded = await verifyAuth(req);
      const caller = await getUser(decoded.uid);
      requireRole(caller, ["admin", "manager", "dispatch", "driver"]);

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
          reviewedBy: decoded.uid,
        });
      } else if (action === "reject") {
        if (!reason) throw new Error("Rejection reason required");
        batch.update(jobRef, {
          status: "rejected",
          rejectionReason: reason,
          "timestamps.reviewedAt": now,
          reviewedBy: decoded.uid,
        });
      } else if (action === "complete") {
        // Driver sadece kendi işini tamamlayabilir
        const job = jobSnap.data();
        if (caller.role === "driver" && job.driverId !== decoded.uid) {
          throw new Error("Unauthorized");
        }

        batch.update(jobRef, {
          status: "completed",
          "timestamps.completedAt": now,
        });

        // Driver'ı müsait yap
        if (job.driverId) {
          batch.update(db.collection("users").doc(job.driverId), {
            jobStatus: "available",
          });
        }
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
/* =========================================================
   SYNC ACTIVE PLATE FROM VEHICLES
========================================================= */
exports.syncActivePlateFromVehicles = onRequest(async (req, res) => {
  try {
    const vehiclesSnap = await db
      .collection("vehicles")
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
/* =========================================================
   FCM NOTIFICATIONS - JOB CREATED
   Dispatch iş oluşturur → SADECE MANAGER'A bildirim
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
        // ========================================
        // SADECE MANAGER'LARA BİLDİRİM GÖNDER
        // ========================================
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
                doc.ref.update({fcmToken: admin.firestore.FieldValue.delete()}),
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

          // B) DISPATCH'E (İŞİ ATAYAN) BİLDİRİM
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



