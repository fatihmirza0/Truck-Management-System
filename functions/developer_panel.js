const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const cors = require("cors")({ origin: true });
const crypto = require("crypto");

// Check if already initialized to avoid error
if (admin.apps.length === 0) {
    admin.initializeApp();
}
const db = admin.firestore();

/* =========================================================
   SESSION-BASED AUTHENTICATION SYSTEM
   - Token hashing with SHA-256
   - Rate limiting for brute force protection
   - Session management with expiry
 ========================================================= */

// In-memory rate limiter (simple implementation for development)
// For production, use Redis/Memorystore
const loginAttempts = new Map(); // IP -> [timestamps]

function checkRateLimit(ip) {
    const now = Date.now();
    const attempts = loginAttempts.get(ip) || [];

    // Remove attempts older than 1 minute
    const recentAttempts = attempts.filter(t => now - t < 60000);

    if (recentAttempts.length >= 5) {
        return false; // Rate limit exceeded
    }

    recentAttempts.push(now);
    loginAttempts.set(ip, recentAttempts);
    return true;
}

// Hash token with SHA-256
function hashToken(token) {
    return crypto.createHash('sha256').update(token).digest('hex');
}

// Verify developer session
async function verifyDeveloperSession(req) {
    const token = req.headers['x-session-token'];

    if (!token) {
        throw new Error("No session token provided");
    }

    // Hash the incoming token
    const tokenHash = hashToken(token);

    // Query Firestore for session with this hash
    const sessionsSnap = await db.collection("developer_sessions")
        .where("tokenHash", "==", tokenHash)
        .limit(1)
        .get();

    if (sessionsSnap.empty) {
        throw new Error("Invalid or expired session");
    }

    const sessionDoc = sessionsSnap.docs[0];
    const sessionData = sessionDoc.data();

    // Check if expired
    const now = admin.firestore.Timestamp.now();
    if (sessionData.expiresAt < now) {
        // Clean up expired session
        await sessionDoc.ref.delete();
        throw new Error("Session expired");
    }

    // Optional: IP matching (disabled by default)
    // const clientIp = req.headers['x-forwarded-for'] || req.connection.remoteAddress;
    // if (sessionData.ip && sessionData.ip !== clientIp) {
    //     throw new Error("IP mismatch");
    // }

    return { valid: true, sessionId: sessionDoc.id };
}

// Developer Login Endpoint
exports.developerLogin = onRequest((req, res) => {
    cors(req, res, async () => {
        try {
            if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });

            // Get client IP for rate limiting
            const clientIp = req.headers['x-forwarded-for'] || req.connection.remoteAddress || 'unknown';

            // Check rate limit
            if (!checkRateLimit(clientIp)) {
                return res.status(429).json({ error: "Too many login attempts. Please try again later." });
            }

            const { masterKey } = req.body;

            if (!masterKey) {
                return res.status(400).json({ error: "Master key required" });
            }

            // Verify master key
            const MASTER_KEY = process.env.DEVELOPER_MASTER_KEY || process.env.DEVELOPER_KEY || "s3cr3t_k3y_v1";

            if (masterKey !== MASTER_KEY) {
                return res.status(401).json({ error: "Invalid master key" });
            }

            // Generate session token (256-bit random)
            const token = crypto.randomBytes(32).toString('hex');

            // Hash the token for storage
            const tokenHash = hashToken(token);

            // Calculate expiry (24 hours from now)
            const expiresAt = admin.firestore.Timestamp.fromMillis(Date.now() + 86400000); // 24 hours

            // Get user agent
            const userAgent = req.headers['user-agent'] || 'unknown';

            // Store session in Firestore
            await db.collection("developer_sessions").add({
                tokenHash,
                expiresAt,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                ip: clientIp,
                userAgent
            });

            // Return plain token to client (only time it's ever sent)
            res.json({
                success: true,
                token,
                expiresAt: expiresAt.toMillis()
            });

        } catch (e) {
            console.error("developerLogin error:", e);
            res.status(500).json({ error: e.message });
        }
    });
});

// Developer Logout Endpoint
exports.developerLogout = onRequest((req, res) => {
    cors(req, res, async () => {
        try {
            if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });

            const token = req.headers['x-session-token'];

            if (!token) {
                return res.status(400).json({ error: "No session token provided" });
            }

            // Hash the token
            const tokenHash = hashToken(token);

            // Find and delete the session
            const sessionsSnap = await db.collection("developer_sessions")
                .where("tokenHash", "==", tokenHash)
                .limit(1)
                .get();

            if (!sessionsSnap.empty) {
                await sessionsSnap.docs[0].ref.delete();
            }

            res.json({ success: true });

        } catch (e) {
            console.error("developerLogout error:", e);
            res.status(500).json({ error: e.message });
        }
    });
});

// Scheduled function to clean expired sessions (runs every 6 hours)
exports.cleanExpiredSessions = onSchedule("every 6 hours", async (event) => {
    try {
        const now = admin.firestore.Timestamp.now();

        // Find all expired sessions
        const expiredSnap = await db.collection("developer_sessions")
            .where("expiresAt", "<", now)
            .get();

        if (expiredSnap.empty) {
            console.log("No expired sessions to clean");
            return;
        }

        // Batch delete for performance
        const batch = db.batch();
        expiredSnap.docs.forEach(doc => {
            batch.delete(doc.ref);
        });

        await batch.commit();
        console.log(`Cleaned ${expiredSnap.size} expired sessions`);

    } catch (e) {
        console.error("cleanExpiredSessions error:", e);
    }
});

/* =========================================================
   DEVELOPER PANEL (LEGACY - WILL BE UPDATED)
   - verifyDeveloperKey (deprecated, use session auth)
   - createCompanyHttp
   - getCompaniesHttp
   - updateUserPermissionsHttp
 ========================================================= */

// Helper to check Secret Key (DEPRECATED - for backward compatibility only)
function verifyDevKey(req) {
    const key = req.headers['x-developer-key'];
    // In production, use process.env.DEVELOPER_KEY
    // For now, hardcoding or using a fallback for dev environment if env not set
    const SECRET = process.env.DEVELOPER_KEY || "s3cr3t_k3y_v1";
    if (key !== SECRET) {
        throw new Error("Invalid Developer Key");
    }
}

exports.verifyDeveloperKey = onRequest((req, res) => {
    cors(req, res, () => {
        try {
            verifyDevKey(req);
            res.json({ success: true });
        } catch (e) {
            res.status(401).json({ error: e.message });
        }
    });
});

exports.createCompanyHttp = onRequest((req, res) => {
    cors(req, res, async () => {
        try {
            if (req.method !== "POST") return res.status(405).end();
            await verifyDeveloperSession(req);

            const { companyName, ownerEmail, ownerPassword, plan, limits } = req.body;
            if (!companyName || !ownerEmail || !ownerPassword) {
                throw new Error("Missing fields");
            }

            // 1. Create Company Doc
            const companyRef = await db.collection("companies").add({
                name: companyName,
                plan: plan || "starter",
                limits: limits || { vehicleCount: 10, dispatchCount: 3, managerCount: 1 }, // Default or Custom
                status: "active",
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            // 2. Create Owner User
            const userRecord = await admin.auth().createUser({
                email: ownerEmail,
                password: ownerPassword,
                displayName: companyName + " Admin",
            });

            // 3. Set User Doc with companyId
            await db.collection("users").doc(userRecord.uid).set({
                name: companyName + " Admin",
                email: ownerEmail,
                role: "manager",
                companyId: companyRef.id, // Linked to new company
                permissions: ["super_manager"],
                isActive: true,
                softDeleted: false,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            // 4. Update Company with Owner ID
            await companyRef.update({ ownerId: userRecord.uid });

            res.json({ success: true, companyId: companyRef.id });
        } catch (e) {
            console.error(e);
            res.status(400).json({ error: e.message });
        }
    });
});

/* =========================================================
   NEW: SYSTEM LOGS AUDIT
   - Aggregates recent critical events (Job Creation, User Creation, Company Creation)
 ========================================================= */
exports.getSystemLogsHttp = onRequest((req, res) => {
    cors(req, res, async () => {
        try {
            await verifyDeveloperSession(req);

            // Fetch recent 20 from each critical collection
            const [jobsSnap, usersSnap, companiesSnap] = await Promise.all([
                db.collection("jobs").orderBy("timestamps.createdAt", "desc").limit(20).get(),
                db.collection("users").orderBy("createdAt", "desc").limit(20).get(),
                db.collection("companies").orderBy("createdAt", "desc").limit(10).get()
            ]);

            const logs = [];
            const companyIdsToFetch = new Set();

            jobsSnap.forEach(doc => {
                const data = doc.data();
                if (data.companyId) companyIdsToFetch.add(data.companyId);
                logs.push({
                    type: 'JOB_CREATED',
                    message: `Job ${data.referenceNo} created`,
                    timestamp: data.timestamps?.createdAt?.toDate(),
                    companyId: data.companyId,
                    details: data
                });
            });

            usersSnap.forEach(doc => {
                const data = doc.data();
                if (data.companyId) companyIdsToFetch.add(data.companyId);
                logs.push({
                    type: 'USER_CREATED',
                    message: `User ${data.name} (${data.role}) created`,
                    timestamp: data.createdAt?.toDate(),
                    companyId: data.companyId,
                    details: data
                });
            });

            companiesSnap.forEach(doc => {
                // For company creation, we definitely know the name
                logs.push({
                    type: 'COMPANY_CREATED',
                    message: `Company ${doc.data().name} created`,
                    timestamp: doc.data().createdAt?.toDate(),
                    companyId: doc.id,
                    companyName: doc.data().name,
                    details: doc.data()
                });
            });

            // Fetch missing company names
            if (companyIdsToFetch.size > 0) {
                const refs = Array.from(companyIdsToFetch).map(id => db.collection("companies").doc(id));
                // Use getAll for efficient fetching
                const companyDocs = await db.getAll(...refs);

                const companyMap = {};
                companyDocs.forEach(doc => {
                    if (doc.exists) {
                        companyMap[doc.id] = doc.data().name;
                    }
                });

                // Enrich logs with companyName
                logs.forEach(log => {
                    if (!log.companyName && log.companyId) {
                        log.companyName = companyMap[log.companyId] || "Unknown Company";
                    }
                });
            }

            // Sort by time desc
            logs.sort((a, b) => b.timestamp - a.timestamp);

            res.json({ success: true, logs: logs.slice(0, 50) });
        } catch (e) {
            console.error(e);
            res.status(400).json({ error: e.message });
        }
    });
});

exports.getCompaniesHttp = onRequest((req, res) => {
    cors(req, res, async () => {
        try {
            await verifyDeveloperSession(req);

            const snap = await db.collection("companies").orderBy("createdAt", "desc").get();
            const companies = snap.docs.map(d => ({ id: d.id, ...d.data() }));

            res.json({ success: true, companies });
        } catch (e) {
            res.status(400).json({ error: e.message });
        }
    });
});

exports.getCompanyUsersHttp = onRequest((req, res) => {
    cors(req, res, async () => {
        try {
            await verifyDeveloperSession(req);
            const { companyId } = req.query;

            if (!companyId) throw new Error("Missing companyId");

            const snap = await db.collection("users")
                .where("companyId", "==", companyId)
                .where("softDeleted", "==", false)
                .get();

            const users = snap.docs.map(d => ({ id: d.id, ...d.data() }));

            res.json({ success: true, users });
        } catch (e) {
            res.status(400).json({ error: e.message });
        }
    });
});

exports.updateUserPermissionsHttp = onRequest((req, res) => {
    cors(req, res, async () => {
        try {
            if (req.method !== "POST") return res.status(405).end();
            await verifyDeveloperSession(req);

            const { userId, permissions } = req.body; // permissions: []
            if (!userId || !Array.isArray(permissions)) {
                throw new Error("Invalid params");
            }

            await db.collection("users").doc(userId).update({
                permissions: permissions
            });

            res.json({ success: true });
        } catch (e) {
            res.status(400).json({ error: e.message });
        }
    });
});

/* =========================================================
   NEW: DASHBOARD STATS (GOD MODE)
   - Total Companies
   - Total Users
   - Jobs Created (Last 24h)
   - Active Vehicles
 ========================================================= */
exports.getDashboardStatsHttp = onRequest((req, res) => {
    cors(req, res, async () => {
        try {
            await verifyDeveloperSession(req);

            // Parallel fetching for performance
            const [companiesSnap, usersSnap, vehiclesSnap, jobsSnap] = await Promise.all([
                db.collection("companies").count().get(),
                db.collection("users").where("softDeleted", "==", false).count().get(),
                db.collection("vehicles").where("isActive", "==", true).count().get(),
                // For jobs, we might want last 24h or total. Let's get TOTAL for now as "count" aggregation is cheap.
                // If we want last 24h, we need a query.
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
        } catch (e) {
            res.status(400).json({ error: e.message });
        }
    });
});

/* =========================================================
   NEW: COMPANY FULL DETAILS (GOD MODE)
   - Metadata, Users, Recent Jobs, Log Summary
 ========================================================= */
exports.getCompanyFullDetailsHttp = onRequest((req, res) => {
    cors(req, res, async () => {
        try {
            await verifyDeveloperSession(req);
            const { companyId } = req.query;
            if (!companyId) throw new Error("Missing companyId");

            // 1. Company Metadata
            const companySnap = await db.collection("companies").doc(companyId).get();
            if (!companySnap.exists) throw new Error("Company not found");
            const companyData = companySnap.data();

            // 2. Users (All)
            const usersSnap = await db.collection("users")
                .where("companyId", "==", companyId)
                .where("softDeleted", "==", false)
                .get();
            const users = usersSnap.docs.map(d => ({ id: d.id, ...d.data() }));

            // 3. Recent Jobs (Last 20)
            const jobsSnap = await db.collection("jobs")
                .where("companyId", "==", companyId)
                .orderBy("timestamps.createdAt", "desc")
                .limit(20)
                .get();
            const jobs = jobsSnap.docs.map(d => ({ id: d.id, ...d.data() }));

            // 4. Calculate Limits Usage (Derived from current data)
            const usage = {
                managerCount: users.filter(u => u.role === 'manager').length,
                dispatchCount: users.filter(u => u.role === 'dispatch').length,
                driverCount: users.filter(u => u.role === 'driver').length,
                // Vehicle count requires a separate query or we trust driver count ~ vehicle count
                // Let's query vehicles to be precise
            };

            const vehiclesSnap = await db.collection("vehicles")
                .where("companyId", "==", companyId)
                .where("isActive", "==", true)
                .count()
                .get();
            usage.vehicleCount = vehiclesSnap.data().count;

            res.json({
                success: true,
                data: {
                    company: { id: companySnap.id, ...companyData },
                    users,
                    recentJobs: jobs,
                    usage
                }
            });
        } catch (e) {
            console.error("getCompanyFullDetailsHttp error", e);
            res.status(400).json({ error: e.message });
        }
    });
});

/* =========================================================
   NEW: UPDATE COMPANY PLAN & LIMITS
   - Updates 'plan' string
   - Updates 'limits' map { vehicleCount, dispatchCount, managerCount }
 ========================================================= */
exports.updateCompanyPlanHttp = onRequest((req, res) => {
    cors(req, res, async () => {
        try {
            if (req.method !== "POST") return res.status(405).end();
            await verifyDeveloperSession(req);

            const { companyId, plan, limits } = req.body;
            if (!companyId) throw new Error("Missing companyId");

            const updateData = {};
            if (plan) updateData.plan = plan;
            if (limits) updateData.limits = limits; // Expect object { vehicleCount: 10, ... }

            await db.collection("companies").doc(companyId).update(updateData);

            res.json({ success: true });
        } catch (e) {
            res.status(400).json({ error: e.message });
        }
    });
});


