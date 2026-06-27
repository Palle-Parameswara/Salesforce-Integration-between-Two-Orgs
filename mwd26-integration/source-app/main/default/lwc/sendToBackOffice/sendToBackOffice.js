import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import sendRequest from '@salesforce/apex/IntegrationRequestService.sendRequest';

export default class SendToBackOffice extends LightningElement {
    @api recordId;
    isSending = false;

    async handleSend() {
        this.isSending = true;
        try {
            const result = await sendRequest({ recordId: this.recordId });
            if (result && result.success) {
                this.showToast('Success', result.message || 'Request sent to Back Office.', 'success');
            } else {
                this.showToast('Send failed', (result && result.message) || 'Unknown error.', 'error', 'sticky');
            }
        } catch (error) {
            this.showToast('Send failed', this.reduceError(error), 'error', 'sticky');
        } finally {
            this.isSending = false;
            // Refresh the record so the updated Status / Response / Sync Date fields display.
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
