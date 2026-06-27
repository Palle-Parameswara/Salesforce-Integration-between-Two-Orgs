import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import sendToBackOffice from '@salesforce/apex/IntegrationRequestController.sendToBackOffice';

export default class SendToBackOffice extends LightningElement {
    @api recordId;
    isSending = false;

    async handleSend() {
        this.isSending = true;
        try {
            const result = await sendToBackOffice({ recordId: this.recordId });
            if (result && result.started) {
                this.showToast(
                    'Sync started',
                    result.message || 'Sync started. Refresh the record in a few seconds to see the result.',
                    'success'
                );
            } else {
                // Not started (e.g. already synced) — informational, not an error.
                this.showToast('Already synced', (result && result.message) || 'Nothing to send.', 'warning');
            }
        } catch (error) {
            this.showToast('Send failed', this.reduceError(error), 'error', 'sticky');
        } finally {
            this.isSending = false;
            // Refresh so the record shows the new "Sending" status straight away.
            getRecordNotifyChange([{ recordId: this.recordId }]);
        }
    }

    showToast(title, message, variant, mode) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant, mode: mode || 'dismissable' })
        );
    }

    reduceError(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        if (error && error.message) {
            return error.message;
        }
        return 'Unexpected error sending the request.';
    }
}
