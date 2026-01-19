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
exports.InvoiceGenerator = void 0;
const admin = __importStar(require("firebase-admin"));
class InvoiceGenerator {
    /**
     * Generate an e-Invoice (Uyumsoft or Mock)
     */
    static async generateInvoice(details) {
        const { userId, amount, currency, taxRate } = details;
        // 1. Calculate Tax
        const taxAmount = amount * (taxRate / 100);
        const totalAmount = amount + taxAmount;
        console.log(`Generating Invoice for ${userId}: ${amount} ${currency} + %${taxRate} VAT = ${totalAmount}`);
        // 2. Integration with E-Invoice Provider (Mock for now)
        // const uyumsoftClient = ...
        // const invoiceId = await uyumsoftClient.createInvoice(...)
        const mockInvoiceId = `GIB-${new Date().getFullYear()}-${Math.floor(Math.random() * 100000)}`;
        const pdfUrl = `https://api.uyumsoft.com/invoices/${mockInvoiceId}.pdf`; // Mock URL
        // 3. Save to Firestore
        await admin.firestore().collection('invoices').add({
            userId,
            invoiceNo: mockInvoiceId,
            amount: amount,
            taxAmount: taxAmount,
            totalAmount: totalAmount,
            currency: currency,
            taxRate: taxRate,
            pdfUrl: pdfUrl,
            items: details.items,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            status: 'issued'
        });
        return pdfUrl;
    }
}
exports.InvoiceGenerator = InvoiceGenerator;
//# sourceMappingURL=InvoiceGenerator.js.map