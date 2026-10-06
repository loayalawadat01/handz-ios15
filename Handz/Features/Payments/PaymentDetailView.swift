import SwiftUI

/// One payment, opened from Payment History: shows its receipt.
/// (The receipt knows whether you're the customer or the worker.)
struct PaymentDetailView: View {
    let payment: Payment
    let isWorkerView: Bool

    var body: some View {
        ReceiptView(paymentId: payment.id)
    }
}
