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
Object.defineProperty(exports, "__esModule", { value: true });
exports.toggleCompanyStatusHttp = exports.updateCompanyPlanHttp = exports.getCompanyFullDetailsHttp = exports.getDashboardStatsHttp = exports.updateUserPermissionsHttp = exports.getCompanyUsersHttp = exports.getCompaniesHttp = exports.getSystemLogsHttp = exports.createCompanyHttp = exports.verifyDeveloperKey = exports.cleanExpiredSessions = exports.developerLogout = exports.developerLogin = void 0;
const https_1 = require("firebase-functions/v2/https");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const admin = __importStar(require("firebase-admin"));
const crypto = __importStar(require("crypto"));
const cors_config_1 = require("../config/cors.config");
const cors = require("cors")(cors_config_1.corsOptions);
// Shared DB instance
const db = admin.firestore();
/* =========================================================
   SESSION-BASED AUTHENTICATION SYSTEM
 ========================================================= */
const loginAttempts = new Map(); // IP -> [timestamps]
function checkRateLimit(ip) {
    const now = Date.now();
    const attempts = loginAttempts.get(ip) || [];
    const recentAttempts = attempts.filter(t => now - t < 60000);
    if (recentAttempts.length >= 5) {
        return false;
    }
    recentAttempts.push(now);
    loginAttempts.set(ip, recentAttempts);
    return true;
}
function hashToken(token) {
    return crypto.createHash('sha256').update(token).digest('hex');
}
async function verifyDeveloperSession(req) {
    const token = req.headers['x-session-token'];
    if (!token)
        throw new Error("No session token provided");
    // @ts-ignore
    const tokenHash = hashToken(token);
    const sessionsSnap = await db.collection("developer_sessions")
        .where("tokenHash", "==", tokenHash)
        .limit(1)
        .get();
    if (sessionsSnap.empty)
        throw new Error("Invalid or expired session");
    const sessionDoc = sessionsSnap.docs[0];
    const sessionData = sessionDoc.data();
    const now = admin.firestore.Timestamp.now();
    if (sessionData.expiresAt < now) {
        await sessionDoc.ref.delete();
        throw new Error("Session expired");
    }
    return { valid: true, sessionId: sessionDoc.id };
}
// Support legacy key check
function verifyDevKey(req) {
    const key = req.headers['x-developer-key'];
    // @ts-ignore
    const SECRET = process.env.DEVELOPER_KEY || "s3cr3t_k3y_v1";
    if (key !== SECRET)
        throw new Error("Invalid Developer Key");
}
/* =========================================================
   EXPORTS
 ========================================================= */
exports.developerLogin = (0, https_1.onRequest)((req, res) => {
    cors(req, res, async () => {
        try {
            if (req.method !== "POST") {
                res.status(405).json({ error: "Method not allowed" });
                return;
            }
            // @ts-ignore
            const clientIp = req.headers['x-forwarded-for'] || req.connection.remoteAddress || 'unknown';
            if (!checkRateLimit(clientIp)) {
                res.status(429).json({ error: "Too many login attempts. Please try again later." });
                return;
            }
            const { masterKey } = req.body;
            if (!masterKey) {
                res.status(400).json({ error: "Master key required" });
                return;
            }
            // @ts-ignore
            const MASTER_KEY = process.env.DEVELOPER_MASTER_KEY || process.env.DEVELOPER_KEY || "s3cr3t_k3y_v1";
            if (masterKey !== MASTER_KEY) {
                res.status(401).json({ error: "Invalid master key" });
                return;
            }
            const token = crypto.randomBytes(32).toString('hex');
            const tokenHash = hashToken(token);
            const expiresAt = admin.firestore.Timestamp.fromMillis(Date.now() + 86400000);
            const userAgent = req.headers['user-agent'] || 'unknown';
            await db.collection("developer_sessions").add({
                tokenHash,
                expiresAt,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                ip: clientIp,
                userAgent
            });
            res.json({ success: true, token, expiresAt: expiresAt.toMillis() });
        }
        catch (e) {
            console.error("developerLogin error:", e);
            res.status(500).json({ error: e.message });
        }
    });
});
exports.developerLogout = (0, https_1.onRequest)((req, res) => {
    cors(req, res, async () => {
        try {
            if (req.method !== "POST") {
                res.status(405).json({ error: "Method not allowed" });
                return;
            }
            // @ts-ignore
            const token = req.headers['x-session-token'];
            if (!token) {
                res.status(400).json({ error: "No session token provided" });
                return;
            }
            // @ts-ignore
            const tokenHash = hashToken(token);
            const sessionsSnap = await db.collection("developer_sessions")
                .where("tokenHash", "==", tokenHash).limit(1).get();
            if (!sessionsSnap.empty) {
                await sessionsSnap.docs[0].ref.delete();
            }
            res.json({ success: true });
        }
        catch (e) {
            res.status(500).json({ error: e.message });
        }
    });
});
exports.cleanExpiredSessions = (0, scheduler_1.onSchedule)("every 6 hours", async (event) => {
    try {
        const now = admin.firestore.Timestamp.now();
        const expiredSnap = await db.collection("developer_sessions")
            .where("expiresAt", "<", now).get();
        if (expiredSnap.empty)
            return;
        const batch = db.batch();
        expiredSnap.docs.forEach(doc => batch.delete(doc.ref));
        await batch.commit();
        console.log(`Cleaned ${expiredSnap.size} expired sessions`);
    }
    catch (e) {
        console.error("cleanExpiredSessions error:", e);
    }
});
exports.verifyDeveloperKey = (0, https_1.onRequest)((req, res) => {
    cors(req, res, () => {
        try {
            verifyDevKey(req);
            res.json({ success: true });
        }
        catch (e) {
            res.status(401).json({ error: e.message });
        }
    });
});
exports.createCompanyHttp = (0, https_1.onRequest)((req, res) => {
    cors(req, res, async () => {
        try {
            if (req.method !== "POST") {
                res.status(405).end();
                return;
            }
            await verifyDeveloperSession(req);
            const { companyName, ownerEmail, ownerPassword, plan, limits } = req.body;
            if (!companyName || !ownerEmail || !ownerPassword)
                throw new Error("Missing fields");
            const companyRef = await db.collection("companies").add({
                name: companyName,
                plan: plan || "starter",
                limits: limits || { vehicleCount: 10, dispatchCount: 3, managerCount: 1 },
                status: "active",
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            const userRecord = await admin.auth().createUser({
                email: ownerEmail,
                password: ownerPassword,
                displayName: companyName + " Admin",
            });
            await db.collection("users").doc(userRecord.uid).set({
                name: companyName + " Admin",
                email: ownerEmail,
                role: "manager",
                companyId: companyRef.id,
                permissions: ["super_manager"],
                isActive: true,
                softDeleted: false,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            await companyRef.update({ ownerId: userRecord.uid });
            res.json({ success: true, companyId: companyRef.id });
        }
        catch (e) {
            res.status(400).json({ error: e.message });
        }
    });
});
exports.getSystemLogsHttp = (0, https_1.onRequest)((req, res) => {
    cors(req, res, async () => {
        try {
            await verifyDeveloperSession(req);
            const [jobsSnap, usersSnap, companiesSnap] = await Promise.all([
                db.collection("jobs").orderBy("timestamps.createdAt", "desc").limit(20).get(),
                db.collection("users").orderBy("createdAt", "desc").limit(20).get(),
                db.collection("companies").orderBy("createdAt", "desc").limit(10).get()
            ]);
            const logs = [];
            const companyIdsToFetch = new Set();
            jobsSnap.forEach(doc => {
                var _a, _b;
                const data = doc.data();
                if (data.companyId)
                    companyIdsToFetch.add(data.companyId);
                logs.push({
                    type: 'JOB_CREATED',
                    message: `Job ${data.referenceNo} created`,
                    timestamp: (_b = (_a = data.timestamps) === null || _a === void 0 ? void 0 : _a.createdAt) === null || _b === void 0 ? void 0 : _b.toDate(),
                    companyId: data.companyId,
                    details: data
                });
            });
            usersSnap.forEach(doc => {
                var _a;
                const data = doc.data();
                if (data.companyId)
                    companyIdsToFetch.add(data.companyId);
                logs.push({
                    type: 'USER_CREATED',
                    message: `User ${data.name} (${data.role}) created`,
                    timestamp: (_a = data.createdAt) === null || _a === void 0 ? void 0 : _a.toDate(),
                    companyId: data.companyId,
                    details: data
                });
            });
            companiesSnap.forEach(doc => {
                var _a;
                logs.push({
                    type: 'COMPANY_CREATED',
                    message: `Company ${doc.data().name} created`,
                    timestamp: (_a = doc.data().createdAt) === null || _a === void 0 ? void 0 : _a.toDate(),
                    companyId: doc.id,
                    companyName: doc.data().name,
                    details: doc.data()
                });
            });
            if (companyIdsToFetch.size > 0) {
                const refs = Array.from(companyIdsToFetch).map(id => db.collection("companies").doc(id));
                const companyDocs = await db.getAll(...refs);
                const companyMap = {};
                companyDocs.forEach(doc => {
                    if (doc.exists)
                        companyMap[doc.id] = doc.data().name;
                });
                logs.forEach(log => {
                    if (!log.companyName && log.companyId) {
                        log.companyName = companyMap[log.companyId] || "Unknown Company";
                    }
                });
            }
            logs.sort((a, b) => b.timestamp - a.timestamp);
            res.json({ success: true, logs: logs.slice(0, 50) });
        }
        catch (e) {
            res.status(400).json({ error: e.message });
        }
    });
});
exports.getCompaniesHttp = (0, https_1.onRequest)((req, res) => {
    cors(req, res, async () => {
        try {
            await verifyDeveloperSession(req);
            const snap = await db.collection("companies").orderBy("createdAt", "desc").get();
            const companies = snap.docs.map(d => (Object.assign({ id: d.id }, d.data())));
            res.json({ success: true, companies });
        }
        catch (e) {
            res.status(400).json({ error: e.message });
        }
    });
});
exports.getCompanyUsersHttp = (0, https_1.onRequest)((req, res) => {
    cors(req, res, async () => {
        try {
            await verifyDeveloperSession(req);
            // @ts-ignore
            const { companyId } = req.query;
            if (!companyId)
                throw new Error("Missing companyId");
            const snap = await db.collection("users")
                .where("companyId", "==", companyId)
                .where("softDeleted", "==", false).get();
            const users = snap.docs.map(d => (Object.assign({ id: d.id }, d.data())));
            res.json({ success: true, users });
        }
        catch (e) {
            res.status(400).json({ error: e.message });
        }
    });
});
exports.updateUserPermissionsHttp = (0, https_1.onRequest)((req, res) => {
    cors(req, res, async () => {
        try {
            if (req.method !== "POST") {
                res.status(405).end();
                return;
            }
            await verifyDeveloperSession(req);
            const { userId, permissions } = req.body;
            if (!userId || !Array.isArray(permissions))
                throw new Error("Invalid params");
            await db.collection("users").doc(userId).update({ permissions });
            res.json({ success: true });
        }
        catch (e) {
            res.status(400).json({ error: e.message });
        }
    });
});
exports.getDashboardStatsHttp = (0, https_1.onRequest)((req, res) => {
    cors(req, res, async () => {
        try {
            await verifyDeveloperSession(req);
            const [companiesSnap, usersSnap, vehiclesSnap, jobsSnap] = await Promise.all([
                db.collection("companies").count().get(),
                db.collection("users").where("softDeleted", "==", false).count().get(),
                db.collection("vehicles").where("isActive", "==", true).count().get(),
                db.collection("jobs").where("timestamps.createdAt", ">=", admin.firestore.Timestamp.fromMillis(Date.now() - 86400000)).count().get()
            ]);
            res.json({
                success: true,
                stats: {
                    totalCompanies: companiesSnap.data().count,
                    totalUsers: usersSnap.data().count,
                    activeVehicles: vehiclesSnap.data().count,
                    jobsLast24h: jobsSnap.data().count
                }
            });
        }
        catch (e) {
            res.status(400).json({ error: e.message });
        }
    });
});
exports.getCompanyFullDetailsHttp = (0, https_1.onRequest)((req, res) => {
    cors(req, res, async () => {
        try {
            await verifyDeveloperSession(req);
            // @ts-ignore
            const { companyId } = req.query;
            if (!companyId)
                throw new Error("Missing companyId");
            const companySnap = await db.collection("companies").doc(companyId).get();
            if (!companySnap.exists)
                throw new Error("Company not found");
            const companyData = companySnap.data();
            const usersSnap = await db.collection("users")
                .where("companyId", "==", companyId)
                .where("softDeleted", "==", false).get();
            const users = usersSnap.docs.map(d => (Object.assign({ id: d.id }, d.data())));
            const jobsSnap = await db.collection("jobs")
                .where("companyId", "==", companyId)
                .orderBy("timestamps.createdAt", "desc").limit(20).get();
            const jobs = jobsSnap.docs.map(d => (Object.assign({ id: d.id }, d.data())));
            const vehiclesSnap = await db.collection("vehicles")
                .where("companyId", "==", companyId)
                .where("isActive", "==", true).count().get();
            const usage = {
                managerCount: users.filter((u) => u.role === 'manager').length,
                dispatchCount: users.filter((u) => u.role === 'dispatch').length,
                driverCount: users.filter((u) => u.role === 'driver').length,
                vehicleCount: vehiclesSnap.data().count
            };
            res.json({
                success: true,
                data: {
                    company: Object.assign({ id: companySnap.id }, companyData),
                    users,
                    recentJobs: jobs,
                    usage
                }
            });
        }
        catch (e) {
            res.status(400).json({ error: e.message });
        }
    });
});
exports.updateCompanyPlanHttp = (0, https_1.onRequest)((req, res) => {
    cors(req, res, async () => {
        try {
            if (req.method !== "POST") {
                res.status(405).end();
                return;
            }
            await verifyDeveloperSession(req);
            const { companyId, plan, limits } = req.body;
            if (!companyId)
                throw new Error("Missing companyId");
            const updateData = {};
            if (plan)
                updateData.plan = plan;
            if (limits)
                updateData.limits = limits;
            await db.collection("companies").doc(companyId).update(updateData);
            res.json({ success: true });
        }
        catch (e) {
            res.status(400).json({ error: e.message });
        }
    });
});
exports.toggleCompanyStatusHttp = (0, https_1.onRequest)((req, res) => {
    cors(req, res, async () => {
        try {
            if (req.method !== "POST") {
                res.status(405).end();
                return;
            }
            await verifyDeveloperSession(req);
            const { companyId, status } = req.body;
            if (!companyId || !["active", "inactive"].includes(status))
                throw new Error("Invalid parameters");
            await db.collection("companies").doc(companyId).update({
                status: status,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            res.json({ success: true, status });
        }
        catch (e) {
            res.status(400).json({ error: e.message });
        }
    });
});
//# sourceMappingURL=developer.js.map