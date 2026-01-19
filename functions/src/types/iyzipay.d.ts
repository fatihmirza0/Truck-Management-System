declare module 'iyzipay' {
    class Iyzipay {
        constructor(config: { apiKey: string; secretKey: string; uri: string });
        checkoutFormInitialize: any;
        subscription: any;
    }
    export = Iyzipay;
}
