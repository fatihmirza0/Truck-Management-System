"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.PaymentFactory = void 0;
const IyzicoProvider_1 = require("./IyzicoProvider");
const PaddleProvider_1 = require("./PaddleProvider");
class PaymentFactory {
    /**
     * Get the appropriate payment provider instance.
     * @param countryCode Two-letter ISO country code (e.g., 'TR', 'US')
     */
    static getProvider(countryCode, config) {
        if (countryCode && countryCode.toUpperCase() === 'TR') {
            return new IyzicoProvider_1.IyzicoProvider(config === null || config === void 0 ? void 0 : config.iyzico);
        }
        return new PaddleProvider_1.PaddleProvider(config === null || config === void 0 ? void 0 : config.paddle);
    }
}
exports.PaymentFactory = PaymentFactory;
//# sourceMappingURL=PaymentFactory.js.map