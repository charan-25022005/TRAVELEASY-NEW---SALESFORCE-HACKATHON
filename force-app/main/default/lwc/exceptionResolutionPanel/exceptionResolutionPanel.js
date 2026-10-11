import { LightningElement, api, track } from 'lwc';
import resolveException from '@salesforce/apex/TravelEasyUiController.resolveException';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class ExceptionResolutionPanel extends LightningElement {
    @api recordId;
    @track selectedAction = 'Resolved';
    @track comments = '';
    @track isSubmitting = false;

    actionOptions = [
        { label: 'Resolve Exception', value: 'Resolved' },
        { label: 'Waive Exception', value: 'Waive' },
        { label: 'Approve with Exception', value: 'Approved' },
        { label: 'Reject / Flag Violation', value: 'Rejected' }
    ];

    handleActionChange(event) {
        this.selectedAction = event.detail.value;
    }

    handleCommentsChange(event) {
        this.comments = event.detail.value;
    }

    get isSubmitDisabled() {
        return !this.selectedAction || !this.comments || this.isSubmitting;
    }

    async handleSubmitDecision() {
        this.isSubmitting = true;
        try {
            const result = await resolveException({
                exceptionId: this.recordId,
                action: this.selectedAction,
                comments: this.comments
            });

            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: result,
                variant: 'success'
            }));

            // Clear inputs
            this.comments = '';
            // Refresh record view
            setTimeout(() => {
                window.location.reload();
            }, 1000);
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error updating exception',
                message: error.body ? error.body.message : error.message,
                variant: 'error'
            }));
        } finally {
            this.isSubmitting = false;
        }
    }
}
