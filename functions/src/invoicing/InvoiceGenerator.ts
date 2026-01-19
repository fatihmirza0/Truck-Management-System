import * as admin from 'firebase-admin';

export interface InvoiceDetails {
    userId: string;
    amount: number;
    currency: string;
    items: { name: string; price: number }[];
    taxRate: number; // e.g. 20 for 20%
}

export class InvoiceGenerator {
    /**
     * Generate an e-Invoice (Uyumsoft or Mock)
     */
    static async generateInvoice(details: InvoiceDetails): Promise<string> {
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
