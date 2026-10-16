import { LightningElement, api, wire } from 'lwc';
import getExpenseReportSummary from '@salesforce/apex/TravelEasyUiController.getExpenseReportSummary';
import { refreshApex } from '@salesforce/apex';

export default class SmartExpenseChecker extends LightningElement {
    @api recordId;
    summary;
    wiredSummaryResult;

    @wire(getExpenseReportSummary, { reportId: '$recordId' })
    wiredSummary(result) {
        this.wiredSummaryResult = result;
        if (result.data) {
            this.summary = result.data;
        } else if (result.error) {
            console.error('Error fetching summary', result.error);
        }
    }

    get varianceStyle() {
        if (!this.summary) return '';
        return this.summary.isOverBudget ? 'color: #ea001e; font-weight: bold;' : 'color: #2e844a; font-weight: bold;';
    }
}
