import { PaymentGateway } from './PaymentGateway';
import { IyzicoProvider } from './IyzicoProvider';
import { PaddleProvider } from './PaddleProvider';

export class PaymentFactory {
    /**
     * Get the appropriate payment provider instance.
     * @param countryCode Two-letter ISO country code (e.g., 'TR', 'US')
     */
    static getProvider(countryCode: string, config?: any): PaymentGateway {
        if (countryCode && countryCode.toUpperCase() === 'TR') {
            return new IyzicoProvider(config?.iyzico);
        }
        return new PaddleProvider(config?.paddle);
    }
}
