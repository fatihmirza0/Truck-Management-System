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
exports.saveMarketingContentHttp = exports.getBlogPostBySlugHttp = exports.getPublicBlogsHttp = exports.getBlogPostsHttp = exports.getInquiriesHttp = exports.submitInquiryHttp = exports.saveBlogPostHttp = exports.toggleCompanyStatusHttp = exports.updateCompanyPlanHttp = exports.getCompanyFullDetailsHttp = exports.getDashboardStatsHttp = exports.updateUserPermissionsHttp = exports.getCompanyUsersHttp = exports.getCompaniesHttp = exports.getSystemLogsHttp = exports.createCompanyHttp = exports.cleanExpiredSessions = exports.developerLogout = exports.developerLogin = void 0;
const https_1 = require("firebase-functions/v2/https");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const admin = __importStar(require("firebase-admin"));
const crypto = __importStar(require("crypto"));
// import { corsOptions } from "../config/cors.config"; // No longer needed for native CORS
// Shared DB instance
const db = admin.firestore();
/* =========================================================
   SESSION-BASED AUTHENTICATION SYSTEM
 ========================================================= */
async function checkRateLimitFirestore(ip, action, maxAttempts = 5, windowMs = 60000) {
    const now = Date.now();
    const cleanIp = ip.replace(/[^a-zA-Z0-9]/g, '_');
    const docRef = db.collection("rate_limits").doc(`${cleanIp}_${action}`);
    try {
        const snap = await docRef.get();
        if (!snap.exists) {
            await docRef.set({
                attempts: [now],
                expiresAt: admin.firestore.Timestamp.fromMillis(now + windowMs)
            });
            return true;
        }
        const data = snap.data();
        const attempts = data.attempts || [];
        const recentAttempts = attempts.filter(t => now - t < windowMs);
        if (recentAttempts.length >= maxAttempts) {
            return false;
        }
        recentAttempts.push(now);
        await docRef.set({
            attempts: recentAttempts,
            expiresAt: admin.firestore.Timestamp.fromMillis(now + windowMs)
        });
        return true;
    }
    catch (err) {
        console.error("Rate limit check error:", err);
        return true; // Fallback to allow requests if DB is unavailable
    }
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
/* =========================================================
   EXPORTS
 ========================================================= */
exports.developerLogin = (0, https_1.onRequest)({ cors: true }, async (req, res) => {
    try {
        if (req.method !== "POST") {
            res.status(405).json({ error: "Method not allowed" });
            return;
        }
        // @ts-ignore
        const clientIp = req.headers['x-forwarded-for'] || req.connection.remoteAddress || 'unknown';
        const isAllowed = await checkRateLimitFirestore(clientIp, "dev_login", 5, 60000);
        if (!isAllowed) {
            res.status(429).json({ error: "Too many login attempts. Please try again later." });
            return;
        }
        const { masterKey } = req.body;
        if (!masterKey) {
            res.status(400).json({ error: "Master key required" });
            return;
        }
        // @ts-ignore
        const MASTER_KEY = process.env.DEVELOPER_MASTER_KEY;
        if (!MASTER_KEY || MASTER_KEY === "s3cr3t_k3y_v1") {
            console.error("CRITICAL: DEVELOPER_MASTER_KEY is not set or using insecure default key.");
            res.status(500).json({ error: "Server configuration error" });
            return;
        }
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
exports.developerLogout = (0, https_1.onRequest)({ cors: true }, async (req, res) => {
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
exports.cleanExpiredSessions = (0, scheduler_1.onSchedule)("every 6 hours", async (event) => {
    try {
        const now = admin.firestore.Timestamp.now();
        const expiredSnap = await db.collection("developer_sessions")
            .where("expiresAt", "<", now).get();
        if (!expiredSnap.empty) {
            const batch = db.batch();
            expiredSnap.docs.forEach(doc => batch.delete(doc.ref));
            await batch.commit();
            console.log(`Cleaned ${expiredSnap.size} expired sessions`);
        }
        // Clean expired rate limits
        const expiredLimitsSnap = await db.collection("rate_limits")
            .where("expiresAt", "<", now).get();
        if (!expiredLimitsSnap.empty) {
            const batch = db.batch();
            expiredLimitsSnap.docs.forEach(doc => batch.delete(doc.ref));
            await batch.commit();
            console.log(`Cleaned ${expiredLimitsSnap.size} expired rate limits`);
        }
    }
    catch (e) {
        console.error("cleanExpiredSessions error:", e);
    }
});
exports.createCompanyHttp = (0, https_1.onRequest)({ cors: true }, async (req, res) => {
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
exports.getSystemLogsHttp = (0, https_1.onRequest)({ cors: true }, async (req, res) => {
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
exports.getCompaniesHttp = (0, https_1.onRequest)({ cors: true }, async (req, res) => {
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
exports.getCompanyUsersHttp = (0, https_1.onRequest)({ cors: true }, async (req, res) => {
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
exports.updateUserPermissionsHttp = (0, https_1.onRequest)({ cors: true }, async (req, res) => {
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
exports.getDashboardStatsHttp = (0, https_1.onRequest)({ cors: true }, async (req, res) => {
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
exports.getCompanyFullDetailsHttp = (0, https_1.onRequest)({ cors: true }, async (req, res) => {
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
            .where("isActive", "==", true).get();
        const vehicles = vehiclesSnap.docs.map(d => (Object.assign({ id: d.id }, d.data())));
        const totalJobsSnap = await db.collection("jobs")
            .where("companyId", "==", companyId).count().get();
        const usage = {
            managerCount: users.filter((u) => u.role === 'manager').length,
            dispatchCount: users.filter((u) => u.role === 'dispatch').length,
            driverCount: users.filter((u) => u.role === 'driver').length,
            vehicleCount: vehicles.length,
            jobCount: totalJobsSnap.data().count
        };
        res.json({
            success: true,
            data: {
                company: Object.assign({ id: companySnap.id }, companyData),
                users,
                recentJobs: jobs,
                vehicles,
                usage
            }
        });
    }
    catch (e) {
        res.status(400).json({ error: e.message });
    }
});
exports.updateCompanyPlanHttp = (0, https_1.onRequest)({ cors: true }, async (req, res) => {
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
exports.toggleCompanyStatusHttp = (0, https_1.onRequest)({ cors: true }, async (req, res) => {
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
exports.saveBlogPostHttp = (0, https_1.onRequest)({ cors: true }, async (req, res) => {
    try {
        if (req.method !== "POST") {
            res.status(405).end();
            return;
        }
        await verifyDeveloperSession(req);
        const { id, title, slug, excerpt, content, coverImage, category, published } = req.body;
        if (!title || !slug)
            throw new Error("Missing title or slug");
        const postData = {
            title,
            slug,
            excerpt,
            content,
            coverImage,
            category,
            published,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        };
        if (id) {
            await db.collection("blogs").doc(id).update(postData);
            res.json({ success: true, id });
        }
        else {
            postData.views = 0;
            postData.createdAt = admin.firestore.FieldValue.serverTimestamp();
            const docRef = await db.collection("blogs").add(postData);
            res.json({ success: true, id: docRef.id });
        }
    }
    catch (e) {
        res.status(400).json({ error: e.message });
    }
});
exports.submitInquiryHttp = (0, https_1.onRequest)({ cors: true }, async (req, res) => {
    try {
        if (req.method !== "POST") {
            res.status(405).end();
            return;
        }
        // @ts-ignore
        const clientIp = req.headers['x-forwarded-for'] || req.connection.remoteAddress || 'unknown';
        const isAllowed = await checkRateLimitFirestore(clientIp, "submit_inquiry", 5, 600000); // Max 5 inquiries per 10 mins
        if (!isAllowed) {
            res.status(429).json({ error: "Too many requests. Please try again later." });
            return;
        }
        const { firstName, lastName, email, phone, companyName } = req.body;
        await db.collection("inquiries").add({
            firstName,
            lastName,
            email,
            phone,
            companyName,
            createdAt: admin.firestore.FieldValue.serverTimestamp()
        });
        res.json({ success: true });
    }
    catch (e) {
        res.status(400).json({ error: e.message });
    }
});
exports.getInquiriesHttp = (0, https_1.onRequest)({ cors: true }, async (req, res) => {
    try {
        await verifyDeveloperSession(req);
        const snap = await db.collection("inquiries").orderBy("createdAt", "desc").get();
        const inquiries = snap.docs.map(d => (Object.assign({ id: d.id }, d.data())));
        res.json({ success: true, inquiries });
    }
    catch (e) {
        res.status(400).json({ error: e.message });
    }
});
exports.getBlogPostsHttp = (0, https_1.onRequest)({ cors: true }, async (req, res) => {
    // Set CORS headers explicitly
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type, x-session-token');
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
    }
    try {
        await verifyDeveloperSession(req);
        const snap = await db.collection("blogs").orderBy("createdAt", "desc").get();
        const posts = snap.docs.map(d => (Object.assign({ id: d.id }, d.data())));
        res.json({ success: true, posts });
    }
    catch (e) {
        res.status(400).json({ error: e.message });
    }
});
exports.getPublicBlogsHttp = (0, https_1.onRequest)({ cors: true }, async (req, res) => {
    // Set CORS headers explicitly
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
    }
    try {
        // No auth required - public endpoint
        const snap = await db.collection("blogs")
            .where("published", "==", true)
            .orderBy("createdAt", "desc")
            .get();
        const posts = snap.docs.map(d => (Object.assign({ id: d.id }, d.data())));
        res.json({ success: true, posts });
    }
    catch (e) {
        res.status(400).json({ error: e.message });
    }
});
exports.getBlogPostBySlugHttp = (0, https_1.onRequest)({ cors: true }, async (req, res) => {
    // Set CORS headers explicitly
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
    }
    try {
        const { slug } = req.query;
        if (!slug || typeof slug !== 'string') {
            res.status(400).json({ error: 'Slug parameter required' });
            return;
        }
        const snap = await db.collection("blogs")
            .where("slug", "==", slug)
            .where("published", "==", true)
            .limit(1)
            .get();
        if (snap.empty) {
            res.status(404).json({ error: 'Post not found' });
            return;
        }
        const post = Object.assign({ id: snap.docs[0].id }, snap.docs[0].data());
        res.json({ success: true, post });
    }
    catch (e) {
        res.status(400).json({ error: e.message });
    }
});
exports.saveMarketingContentHttp = (0, https_1.onRequest)({ cors: true }, async (req, res) => {
    try {
        if (req.method !== "POST") {
            res.status(405).end();
            return;
        }
        await verifyDeveloperSession(req);
        const { content } = req.body;
        if (!content)
            throw new Error("Missing content");
        await db.collection("metadata").doc("landingContent").set(Object.assign(Object.assign({}, content), { updatedAt: admin.firestore.FieldValue.serverTimestamp() }));
        res.json({ success: true });
    }
    catch (e) {
        res.status(400).json({ error: e.message });
    }
});
//# sourceMappingURL=developer.js.map