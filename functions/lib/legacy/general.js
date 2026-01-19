"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.onCompanyStatusChange = exports.updateCompanyGoals = exports.getManagerLogs = exports.getManagerDashboardData = exports.createJobHttp = exports.checkDriverOffline = exports.getLiveDriverLocations = exports.clearFcmTokenHttp = exports.updateLastLoginHttp = exports.notifyOnJobStatusChange = exports.notifyManagersOnJobCreated = exports.syncActivePlateFromVehicles = exports.jobAction = exports.softDeleteUserHttp = exports.updateUserHttp = exports.createUserHttp = exports.createDriverHttp = void 0;
const https_1 = require("firebase-functions/v2/https");
const firestore_1 = require("firebase-functions/v2/firestore");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const v2_1 = require("firebase-functions/v2");
const admin = __importStar(require("firebase-admin"));
const axios_1 = __importDefault(require("axios"));
const cors_config_1 = require("../config/cors.config");
const cors = require("cors")(cors_config_1.corsOptions);
// Init Admin if needed
if (!admin.apps.length) {
    admin.initializeApp();
}
const db = admin.firestore();
(0, v2_1.setGlobalOptions)({ maxInstances: 10 });
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
    if (!snap.exists)
        throw new Error("User not found");
    return snap.data();
}
function requireRole(user, roles) {
    if (!roles.includes(user.role))
        throw new Error("Permission denied");
    if (user.isActive !== true || user.softDeleted === true) {
        throw new Error("User inactive");
    }
    // COMPANY STATUS CHECK
    if (user.companyStatus === 'inactive' && user.role !== 'developer') {
        throw new Error("Company is inactive. Contact support.");
    }
}
async function ensureSameCompany(callerId, targetUserId) {
    const caller = await getUser(callerId);
    const target = await getUser(targetUserId);
    if (caller.role === 'developer')
        return { caller, target };
    if (!caller.companyId)
        throw new Error("Caller has no companyId");
    if (!target.companyId)
        throw new Error("Target has no companyId");
    if (caller.companyId !== target.companyId)
        throw new Error("Cross-company access denied");
    return { caller, target };
}
async function ensureJobBelongsToCompany(callerId, jobId) {
    const caller = await getUser(callerId);
    const jobSnap = await db.collection("jobs").doc(jobId).get();
    if (!jobSnap.exists)
        throw new Error("Job not found");
    const job = jobSnap.data();
    if (caller.role === 'developer')
        return { caller, job };
    if (!caller.companyId)
        throw new Error("Caller has no companyId");
    if (!job.companyId)
        throw new Error("Job has no companyId");
    if (caller.companyId !== job.companyId)
        throw new Error("Cross-company job access denied");
    return { caller, job };
}
/* =========================================================
   EXPORTS
 ========================================================= */
// CREATE DRIVER
exports.createDriverHttp = (0, https_1.onRequest)((req, res) => {
    cors(req, res, async () => {
        var _a;
        try {
            if (req.method !== "POST") {
                res.status(405).end();
                return;
            }
            const decoded = await verifyAuth(req);
            const caller = await getUser(decoded.uid);
            requireRole(caller, ["dispatch", "admin", "manager"]);
            const { name, email, password, phone, plate } = req.body;
            if (!name || !email || !password || !phone || !plate)
                throw new Error("Missing fields");
            const companyId = caller.companyId;
            if (!companyId)
                throw new Error("Caller has no companyId");
            // LIMIT CHECK: Vehicle Count
            const companyDoc = await db.collection("companies").doc(companyId).get();
            const companyData = companyDoc.data();
            const vehicleLimit = ((_a = companyData.limits) === null || _a === void 0 ? void 0 : _a.vehicleCount) || 10;
            const currentVehicles = await db.collection("vehicles")
                .where("companyId", "==", companyId)
                .where("isActive", "==", true).count().get();
            if (currentVehicles.data().count >= vehicleLimit) {
                throw new Error(`Vehicle limit reached (${vehicleLimit}). Upgrade plan.`);
            }
            const userRecord = await admin.auth().createUser({ email, password, displayName: name });
            const batch = db.batch();
            batch.set(db.collection("users").doc(userRecord.uid), {
                name, email, phone, role: "driver", companyId, isActive: true, softDeleted: false,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                lastLoginAt: null, activePlate: plate !== null && plate !== void 0 ? plate : null, jobStatus: "available",
            });
            batch.set(db.collection("vehicles").doc(), {
                plate: plate.toUpperCase(), assignedDriverId: userRecord.uid, companyId,
                ownership: "driver", type: "truck", isActive: true,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            await batch.commit();
            res.json({ success: true, uid: userRecord.uid });
        }
        catch (e) {
            res.status(400).json({ error: e.message });
        }
    });
});
// CREATE USER (ADMIN / MANAGER)
exports.createUserHttp = (0, https_1.onRequest)((req, res) => {
    cors(req, res, async () => {
        var _a, _b;
        try {
            if (req.method !== "POST") {
                res.status(405).end();
                return;
            }
            const decoded = await verifyAuth(req);
            const caller = await getUser(decoded.uid);
            requireRole(caller, ["admin", "manager"]);
            const { name, email, password, phone, role, plate } = req.body;
            if (!name || !email || !password || !phone || !role)
                throw new Error("Missing fields");
            const companyId = caller.companyId;
            if (!companyId)
                throw new Error("Caller has no companyId");
            const companyDoc = await db.collection("companies").doc(companyId).get();
            const companyData = companyDoc.data();
            // LIMIT CHECKS
            if (role === 'manager') {
                const limit = ((_a = companyData.limits) === null || _a === void 0 ? void 0 : _a.managerCount) || 1;
                const current = await db.collection("users").where("companyId", "==", companyId).where("role", "==", "manager").where("softDeleted", "==", false).count().get();
                if (current.data().count >= limit)
                    throw new Error(`Manager limit reached (${limit}). Upgrade plan.`);
            }
            if (role === 'dispatch') {
                const limit = ((_b = companyData.limits) === null || _b === void 0 ? void 0 : _b.dispatchCount) || 3;
                const current = await db.collection("users").where("companyId", "==", companyId).where("role", "==", "dispatch").where("softDeleted", "==", false).count().get();
                if (current.data().count >= limit)
                    throw new Error(`Dispatch limit reached (${limit}). Upgrade plan.`);
            }
            const userRecord = await admin.auth().createUser({ email, password, displayName: name });
            const batch = db.batch();
            batch.set(db.collection("users").doc(userRecord.uid), {
                name, email, phone, role, companyId, isActive: true, softDeleted: false,
                createdAt: admin.firestore.FieldValue.serverTimestamp(), lastLoginAt: null,
            });
            if (role === "driver" && plate) {
                batch.set(db.collection("vehicles").doc(), {
                    plate: plate.toUpperCase(), assignedDriverId: userRecord.uid, companyId,
                    ownership: "driver", type: "truck", isActive: true,
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                });
                batch.update(db.collection("users").doc(userRecord.uid), {
                    jobStatus: "available", activePlate: plate !== null && plate !== void 0 ? plate : null,
                });
            }
            await batch.commit();
            res.json({ success: true, uid: userRecord.uid });
        }
        catch (e) {
            res.status(400).json({ error: e.message });
        }
    });
});
// UPDATE USER
exports.updateUserHttp = (0, https_1.onRequest)((req, res) => {
    cors(req, res, async () => {
        try {
            if (req.method !== "POST") {
                res.status(405).end();
                return;
            }
            const decoded = await verifyAuth(req);
            const caller = await getUser(decoded.uid);
            requireRole(caller, ["admin", "manager"]);
            const { uid, name, email, phone, role, plate } = req.body;
            if (!uid || !name || !email || !phone || !role)
                throw new Error("Missing fields");
            await ensureSameCompany(decoded.uid, uid);
            const batch = db.batch();
            batch.update(db.collection("users").doc(uid), { name, email, phone, role });
            if (role === "driver" && plate) {
                const vehicleSnap = await db.collection("vehicles").where("assignedDriverId", "==", uid).limit(1).get();
                const companyId = caller.companyId;
                if (!vehicleSnap.empty) {
                    batch.update(vehicleSnap.docs[0].ref, { plate: plate.toUpperCase() });
                }
                else {
                    batch.set(db.collection("vehicles").doc(), {
                        plate: plate.toUpperCase(), assignedDriverId: uid, companyId,
                        ownership: "driver", type: "truck", isActive: true,
                        createdAt: admin.firestore.FieldValue.serverTimestamp(),
                    });
                }
            }
            await batch.commit();
            res.json({ success: true });
        }
        catch (e) {
            res.status(400).json({ error: e.message });
        }
    });
});
// SOFT DELETE USER
exports.softDeleteUserHttp = (0, https_1.onRequest)((req, res) => {
    cors(req, res, async () => {
        try {
            if (req.method !== "POST") {
                res.status(405).end();
                return;
            }
            const decoded = await verifyAuth(req);
            const caller = await getUser(decoded.uid);
            requireRole(caller, ["admin", "manager"]);
            const { userId } = req.body;
            if (!userId)
                throw new Error("userId required");
            await ensureSameCompany(decoded.uid, userId);
            await db.collection("users").doc(userId).update({ softDeleted: true, isActive: false });
            res.json({ success: true });
        }
        catch (e) {
            res.status(400).json({ error: e.message });
        }
    });
});
// JOB ACTIONS
exports.jobAction = (0, https_1.onRequest)((req, res) => {
    cors(req, res, async () => {
        try {
            if (req.method !== "POST") {
                res.status(405).end();
                return;
            }
            const decoded = await verifyAuth(req);
            const { jobId, action, reason } = req.body;
            if (!jobId || !action)
                throw new Error("jobId & action required");
            const { caller, job } = await ensureJobBelongsToCompany(decoded.uid, jobId);
            requireRole(caller, ["admin", "manager", "dispatch", "driver"]);
            const jobRef = db.collection("jobs").doc(jobId);
            const now = admin.firestore.FieldValue.serverTimestamp();
            const batch = db.batch();
            if (action === "approve") {
                batch.update(jobRef, { status: "approved", "timestamps.reviewedAt": now, reviewedBy: decoded.uid });
                if (job.driverId) {
                    batch.update(db.collection("users").doc(job.driverId), { jobStatus: "busy", currentJobId: jobId });
                    try {
                        await admin.database().ref(`locations/${job.driverId}`).update({
                            currentJobId: jobId, timestamp: admin.database.ServerValue.TIMESTAMP, lastPing: admin.database.ServerValue.TIMESTAMP, offlineNotified: false
                        });
                    }
                    catch (rtdbError) {
                        console.error("RTDB error", rtdbError);
                    }
                }
            }
            else if (action === "reject") {
                if (!reason)
                    throw new Error("Rejection reason required");
                batch.update(jobRef, { status: "rejected", rejectionReason: reason, "timestamps.reviewedAt": now, reviewedBy: decoded.uid });
                if (job.driverId) {
                    batch.update(db.collection("users").doc(job.driverId), { jobStatus: "available", currentJobId: null });
                    try {
                        await admin.database().ref(`locations/${job.driverId}`).update({
                            currentJobId: null, timestamp: admin.database.ServerValue.TIMESTAMP, lastPing: admin.database.ServerValue.TIMESTAMP, offlineNotified: false
                        });
                    }
                    catch (rtdbError) {
                        console.error("RTDB error", rtdbError);
                    }
                }
            }
            else if (action === "complete") {
                if (caller.role === "driver" && job.driverId !== decoded.uid)
                    throw new Error("Unauthorized");
                batch.update(jobRef, { status: "completed", "timestamps.completedAt": now });
                if (job.driverId) {
                    batch.update(db.collection("users").doc(job.driverId), { jobStatus: "available", currentJobId: null });
                    try {
                        await admin.database().ref(`locations/${job.driverId}`).update({
                            currentJobId: null, timestamp: admin.database.ServerValue.TIMESTAMP, lastPing: admin.database.ServerValue.TIMESTAMP, offlineNotified: false
                        });
                    }
                    catch (rtdbError) {
                        console.error("RTDB error", rtdbError);
                    }
                }
            }
            else {
                throw new Error("Invalid action");
            }
            batch.set(jobRef.collection("logs").doc(), { action, performedBy: decoded.uid, performedAt: now, note: reason || null });
            await batch.commit();
            res.json({ success: true });
        }
        catch (e) {
            res.status(400).json({ error: e.message });
        }
    });
});
// SYNC ACTIVE PLATE
exports.syncActivePlateFromVehicles = (0, https_1.onRequest)(async (req, res) => {
    try {
        const decoded = await verifyAuth(req);
        const caller = await getUser(decoded.uid);
        requireRole(caller, ["admin", "manager"]);
        const vehiclesSnap = await db.collection("vehicles")
            .where("companyId", "==", caller.companyId)
            .where("assignedDriverId", "!=", null).get();
        const batch = db.batch();
        let updated = 0;
        for (const vehicleDoc of vehiclesSnap.docs) {
            const v = vehicleDoc.data();
            const driverId = v.assignedDriverId;
            if (!driverId)
                continue;
            const driverRef = db.collection("users").doc(driverId);
            const driverSnap = await driverRef.get();
            if (!driverSnap.exists)
                continue;
            batch.update(driverRef, { activePlate: v.plate, activeVehicleId: vehicleDoc.id });
            updated++;
        }
        if (updated > 0)
            await batch.commit();
        res.json({ success: true, syncedDrivers: updated });
    }
    catch (e) {
        res.status(500).json({ error: e.message });
    }
});
// NOTIFICATIONS
exports.notifyManagersOnJobCreated = (0, firestore_1.onDocumentCreated)("jobs/{jobId}", async (event) => {
    const snap = event.data;
    if (!snap)
        return;
    const job = snap.data();
    const jobId = event.params.jobId;
    try {
        const managersSnapshot = await db.collection("users").where("role", "==", "manager").get();
        const tokens = [];
        managersSnapshot.forEach(doc => { if (doc.data().fcmToken)
            tokens.push(doc.data().fcmToken); });
        if (tokens.length === 0)
            return;
        const promises = tokens.map(token => admin.messaging().send({
            notification: { title: "🚛 Yeni İş Ataması", body: `${job.driverName || "Bir sürücü"} için yeni iş oluşturuldu` },
            data: { jobId, type: "new_job", click_action: "FLUTTER_NOTIFICATION_CLICK" },
            token
        }).catch(() => null));
        await Promise.all(promises);
    }
    catch (error) {
        console.error("Notify error", error);
    }
});
exports.notifyOnJobStatusChange = (0, firestore_1.onDocumentUpdated)("jobs/{jobId}", async (event) => {
    var _a, _b, _c, _d;
    const beforeSnap = (_a = event.data) === null || _a === void 0 ? void 0 : _a.before;
    const afterSnap = (_b = event.data) === null || _b === void 0 ? void 0 : _b.after;
    if (!beforeSnap || !afterSnap)
        return;
    const before = beforeSnap.data();
    const after = afterSnap.data();
    const jobId = event.params.jobId;
    try {
        if (before.status !== "approved" && after.status === "approved") {
            if (after.createdBy) {
                const dispatchDoc = await db.collection("users").doc(after.createdBy).get();
                if (dispatchDoc.exists && ((_c = dispatchDoc.data()) === null || _c === void 0 ? void 0 : _c.fcmToken)) {
                    await admin.messaging().send({
                        notification: { title: "✅ İş Onaylandı!", body: `Oluşturduğunuz iş onaylandı.` },
                        data: { jobId, type: "job_approved", click_action: "FLUTTER_NOTIFICATION_CLICK" },
                        token: dispatchDoc.data().fcmToken
                    }).catch(() => null);
                }
            }
            if (after.driverId) {
                const driverDoc = await db.collection("users").doc(after.driverId).get();
                if (driverDoc.exists && ((_d = driverDoc.data()) === null || _d === void 0 ? void 0 : _d.fcmToken)) {
                    await admin.messaging().send({
                        notification: { title: "🚛 Yeni İş Ataması!", body: `Size yeni bir iş atandı.` },
                        data: { jobId, type: "new_job_assigned", click_action: "FLUTTER_NOTIFICATION_CLICK" },
                        token: driverDoc.data().fcmToken
                    }).catch(() => null);
                }
            }
        }
        if (before.status !== "completed" && after.status === "completed") {
            const managersSnapshot = await db.collection("users").where("role", "==", "manager").get();
            const tokens = [];
            managersSnapshot.forEach(doc => { if (doc.data().fcmToken)
                tokens.push(doc.data().fcmToken); });
            if (tokens.length > 0) {
                await Promise.all(tokens.map(token => admin.messaging().send({
                    notification: { title: "✅ İş Tamamlandı", body: `${after.driverName} işi tamamladı` },
                    data: { jobId, type: "job_completed", click_action: "FLUTTER_NOTIFICATION_CLICK" },
                    token
                }).catch(() => null)));
            }
        }
    }
    catch (e) {
        console.error(e);
    }
});
exports.updateLastLoginHttp = (0, https_1.onRequest)((req, res) => {
    cors(req, res, async () => {
        try {
            if (req.method !== "POST") {
                res.status(405).end();
                return;
            }
            const decoded = await verifyAuth(req);
            const user = await getUser(decoded.uid);
            const batch = db.batch();
            // Update user's last login timestamp
            batch.update(db.collection("users").doc(decoded.uid), {
                lastLoginAt: admin.firestore.FieldValue.serverTimestamp()
            });
            // Create a login activity log
            if (user.companyId) {
                const logRef = db.collection("logs").doc();
                batch.set(logRef, {
                    action: "LOGIN_ACTIVITY",
                    message: `${user.name || user.email} sisteme giriş yaptı`,
                    actorId: decoded.uid,
                    companyId: user.companyId,
                    type: "LOGIN_ACTIVITY", // Helper for filtering
                    createdAt: admin.firestore.FieldValue.serverTimestamp()
                });
            }
            await batch.commit();
            res.json({ success: true });
        }
        catch (e) {
            res.status(401).json({ error: e.message });
        }
    });
});
exports.clearFcmTokenHttp = (0, https_1.onRequest)((req, res) => {
    cors(req, res, async () => {
        try {
            const decoded = await verifyAuth(req);
            await db.collection("users").doc(decoded.uid).update({ fcmToken: admin.firestore.FieldValue.delete() });
            res.json({ success: true });
        }
        catch (e) {
            res.status(400).json({ error: e.message });
        }
    });
});
exports.getLiveDriverLocations = (0, https_1.onRequest)(async (req, res) => {
    cors(req, res, async () => {
        try {
            const authHeader = req.headers.authorization || "";
            if (!authHeader.startsWith("Bearer ")) {
                res.status(401).json({ error: "Unauthorized" });
                return;
            }
            const token = authHeader.replace("Bearer ", "");
            const decoded = await admin.auth().verifyIdToken(token);
            const userSnap = await db.collection("users").doc(decoded.uid).get();
            if (!userSnap.exists) {
                res.status(403).json({ error: "User not found" });
                return;
            }
            const user = userSnap.data();
            if (!["manager", "dispatch"].includes(user.role)) {
                res.status(403).json({ error: "Forbidden" });
                return;
            }
            const rtdb = admin.database();
            const locationsSnap = await rtdb.ref("locations").get();
            const allLocations = locationsSnap.exists() ? locationsSnap.val() : {};
            const locations = {};
            for (const [driverId, data] of Object.entries(allLocations)) {
                const d = data;
                if (d.companyId && d.companyId === user.companyId) {
                    locations[driverId] = d;
                }
            }
            res.status(200).json({ success: true, locations, history: {} });
        }
        catch (e) {
            res.status(500).json({ error: e.message });
        }
    });
});
exports.checkDriverOffline = (0, scheduler_1.onSchedule)({ schedule: "every 2 minutes", timeZone: "Europe/Istanbul", region: "us-central1" }, async () => {
    console.log("DRIVER OFFLINE CHECK STARTED");
    const OFFLINE_THRESHOLD = 180000;
    const now = Date.now();
    try {
        const locationsSnap = await admin.database().ref("locations").get();
        if (!locationsSnap.exists())
            return;
        const locations = locationsSnap.val();
        const updates = {};
        const notifications = [];
        for (const [driverId, location] of Object.entries(locations)) {
            const loc = location;
            if (typeof loc !== 'object' || loc === null)
                continue;
            const isOnline = loc.isOnline === true;
            const timeDiff = now - (loc.lastPing || 0);
            if (isOnline && timeDiff > OFFLINE_THRESHOLD) {
                updates[`locations/${driverId}/isOnline`] = false;
                updates[`locations/${driverId}/timestamp`] = admin.database.ServerValue.TIMESTAMP;
                // Notify if busy
                const driverDoc = await db.collection("users").doc(driverId).get();
                if (driverDoc.exists) {
                    const d = driverDoc.data();
                    if (d.jobStatus === "busy" && d.fcmToken && !loc.offlineNotified) {
                        notifications.push({ token: d.fcmToken, name: d.name, driverId });
                        updates[`locations/${driverId}/offlineNotified`] = true;
                    }
                }
            }
        }
        if (Object.keys(updates).length > 0)
            await admin.database().ref().update(updates);
        for (const item of notifications) {
            await admin.messaging().send({
                token: item.token,
                notification: { title: "⚠️ Sürücü Bağlantısı Kesildi", body: `${item.name} konum göndermiyor.` },
                data: { type: "driver_offline", driverId: item.driverId }
            }).catch(() => null);
        }
    }
    catch (e) {
        console.error(e);
    }
});
exports.createJobHttp = (0, https_1.onRequest)((req, res) => {
    cors(req, res, async () => {
        var _a, _b;
        try {
            if (req.method !== "POST") {
                res.status(405).end();
                return;
            }
            const decoded = await verifyAuth(req);
            const caller = await getUser(decoded.uid);
            requireRole(caller, ["admin", "manager", "dispatch"]);
            const { driverId, vehicleId, loadPort, unloadPort, cargoType, cargoDescription, cargoWeightKg } = req.body;
            if (!driverId || !vehicleId || !loadPort || !unloadPort)
                throw new Error("Missing required fields");
            const companyId = caller.companyId;
            if (!companyId)
                throw new Error("Caller has no companyId");
            const driverSnap = await db.collection("users").doc(driverId).get();
            const driverData = driverSnap.data();
            if (driverData.companyId !== companyId)
                throw new Error("Driver belongs to different company");
            if (driverData.jobStatus === 'busy')
                throw new Error("Driver is currently busy");
            const vehicleSnap = await db.collection("vehicles").doc(vehicleId).get();
            if (((_a = vehicleSnap.data()) === null || _a === void 0 ? void 0 : _a.companyId) !== companyId)
                throw new Error("Vehicle belongs to different company");
            // 🔥 SERVER-SIDE GEOCODING & DISTANCE (CORS FIX)
            const apiKey = "AIzaSyBW9ivbOndjriQ50cwHN6d3VUiWmQJ9VdE";
            let distanceKm = req.body.distanceKm || 0;
            try {
                // Geocode loadPort
                const loadRes = await axios_1.default.get(`https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(loadPort)}&key=${apiKey}`);
                const unloadRes = await axios_1.default.get(`https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(unloadPort)}&key=${apiKey}`);
                if (loadRes.data.status === "OK" && unloadRes.data.status === "OK") {
                    const origin = loadRes.data.results[0].geometry.location;
                    const dest = unloadRes.data.results[0].geometry.location;
                    // Get distance
                    const distRes = await axios_1.default.get(`https://maps.googleapis.com/maps/api/directions/json?origin=${origin.lat},${origin.lng}&destination=${dest.lat},${dest.lng}&key=${apiKey}`);
                    if (distRes.data.status === "OK") {
                        const route = distRes.data.routes[0];
                        if (route && route.legs && route.legs[0]) {
                            distanceKm = route.legs[0].distance.value / 1000; // meters to km
                        }
                    }
                }
            }
            catch (geoError) {
                console.error("Geocoding failed in Cloud Function:", geoError);
                // Fallback to 0 if distance wasn't provided, or keep what was provided
            }
            const batch = db.batch();
            const jobRef = db.collection("jobs").doc();
            const referenceNo = `JOB-${Date.now()}`;
            // 🔥 FLATTENED DATA STRUCTURE (FIXES "-" IN UI)
            batch.set(jobRef, {
                referenceNo,
                companyId,
                driverId,
                vehicleId,
                createdBy: decoded.uid,
                status: "pending",
                rejectionReason: null,
                loadPort,
                unloadPort,
                cargoType,
                cargoDescription,
                cargoWeightKg: Number(cargoWeightKg),
                distanceKm: Number(distanceKm),
                timestamps: {
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                    reviewedAt: null
                },
                softDeleted: false,
                driverName: driverData.name,
                vehiclePlate: (_b = vehicleSnap.data()) === null || _b === void 0 ? void 0 : _b.plate
            });
            batch.set(jobRef.collection("logs").doc(), {
                action: "created",
                performedBy: decoded.uid,
                performedAt: admin.firestore.FieldValue.serverTimestamp()
            });
            batch.update(db.collection("users").doc(driverId), {
                jobStatus: "busy",
                currentJobId: jobRef.id
            });
            await batch.commit();
            res.json({ success: true, jobId: jobRef.id });
        }
        catch (e) {
            res.status(400).json({ error: e.message });
        }
    });
});
exports.getManagerDashboardData = (0, https_1.onRequest)((req, res) => {
    cors(req, res, async () => {
        var _a;
        try {
            const decoded = await verifyAuth(req);
            const user = await getUser(decoded.uid);
            requireRole(user, ["manager", "admin"]);
            const companyId = user.companyId;
            if (!companyId)
                throw new Error("No company linked");
            const today = new Date();
            today.setHours(0, 0, 0, 0);
            const [companySnap, vehiclesCount, jobsCountToday, activeJobsCount] = await Promise.all([
                db.collection("companies").doc(companyId).get(),
                db.collection("vehicles").where("companyId", "==", companyId).where("isActive", "==", true).count().get(),
                db.collection("jobs").where("companyId", "==", companyId).where("timestamps.completedAt", ">=", admin.firestore.Timestamp.fromDate(today)).count().get(),
                db.collection("jobs").where("companyId", "==", companyId).where("status", "in", ["pending", "approved", "started"]).count().get()
            ]);
            res.json({
                success: true,
                stats: { totalVehicles: vehiclesCount.data().count, completedJobsToday: jobsCountToday.data().count, activeJobs: activeJobsCount.data().count },
                goals: ((_a = companySnap.data()) === null || _a === void 0 ? void 0 : _a.goals) || {}
            });
        }
        catch (e) {
            res.status(400).json({ error: e.message });
        }
    });
});
exports.getManagerLogs = (0, https_1.onRequest)((req, res) => {
    cors(req, res, async () => {
        try {
            const decoded = await verifyAuth(req);
            const user = await getUser(decoded.uid);
            requireRole(user, ["manager", "admin"]);
            const companyId = user.companyId;
            if (!companyId)
                throw new Error("No company linked");
            // Query the dedicated 'logs' collection instead of 'jobs'
            const logsSnap = await db.collection("logs")
                .where("companyId", "==", companyId)
                .orderBy("createdAt", "desc")
                .limit(40)
                .get();
            const logs = [];
            logsSnap.forEach(doc => {
                var _a;
                const data = doc.data();
                logs.push({
                    id: doc.id,
                    type: data.type || 'ACTIVITY',
                    action: data.action,
                    message: data.message || `${data.action} eylemi gerçekleştirildi`,
                    timestamp: (_a = data.createdAt) === null || _a === void 0 ? void 0 : _a.toDate(),
                    actorId: data.actorId || data.performedBy,
                    details: data
                });
            });
            res.json({ success: true, logs });
        }
        catch (e) {
            res.status(400).json({ error: e.message });
        }
    });
});
exports.updateCompanyGoals = (0, https_1.onRequest)((req, res) => {
    cors(req, res, async () => {
        try {
            if (req.method !== "POST") {
                res.status(405).end();
                return;
            }
            const decoded = await verifyAuth(req);
            const user = await getUser(decoded.uid);
            requireRole(user, ["manager", "admin"]);
            await db.collection("companies").doc(user.companyId).update({
                goals: Object.assign(Object.assign({}, req.body), { updatedAt: admin.firestore.FieldValue.serverTimestamp() })
            });
            res.json({ success: true });
        }
        catch (e) {
            res.status(400).json({ error: e.message });
        }
    });
});
exports.onCompanyStatusChange = (0, firestore_1.onDocumentUpdated)("companies/{companyId}", async (event) => {
    var _a, _b;
    const before = (_a = event.data) === null || _a === void 0 ? void 0 : _a.before.data();
    const after = (_b = event.data) === null || _b === void 0 ? void 0 : _b.after.data();
    if (before.status === after.status)
        return;
    const companyId = event.params.companyId;
    const usersSnap = await db.collection("users").where("companyId", "==", companyId).get();
    const batch = db.batch();
    usersSnap.docs.forEach(doc => batch.update(doc.ref, { companyStatus: after.status }));
    await batch.commit();
});
//# sourceMappingURL=general.js.map