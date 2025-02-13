import { LightningElement, wire, track } from 'lwc';
import getAccountList from '@salesforce/apex/AccountHelper.getAccountList';
import sendAccountDetails from '@salesforce/apex/AccountHelper.sendAccountDetails';
import { refreshApex } from '@salesforce/apex';

const actions = [
    { label: 'Edit', name: 'edit' }
];

const columns = [
    { label: 'Account Name', fieldName: 'Name' },
    { label: 'Type', fieldName: 'Type' },
    { label: 'Annual Revenue', fieldName: 'AnnualRevenue', type: 'currency' },
    { label: 'Phone', fieldName: 'Phone', type: 'phone' },
    { label: 'Website', fieldName: 'Website', type: 'url' },
    { label: 'Rating', fieldName: 'Rating' },
    {
        type: 'action',
        typeAttributes: { rowActions: actions },
    },
];

export default class GetAccountdetailsifrequiredsaveaccountdetailstoo extends LightningElement {
    @track accList;
    @track error;
    @track isNewAccountFormVisible = false;
    @track newAccount = {
        Name: '',
        Type: '',
        AnnualRevenue: 0,
        Phone: '',
        Website: '',
        Rating: ''
    };
    columns = columns;

    @wire(getAccountList)
    wiredAccounts(result) {
        this.wiredAccountResult = result; // Store the wired result to use in refreshApex
        if (result.data) {
            this.accList = result.data;
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.accList = undefined;
        }
    }


    handleNewButtonClick() {
        this.isNewAccountFormVisible = true;
        this.newAccount = {}; 
    }

    handleCancelClick() {
        this.isNewAccountFormVisible = false;
    }

    handleInputChange(event) {
        const field = event.target.fieldName;
        this.newAccount[field] = event.target.value;
    }

    handleSubmitClick() {
        console.log('Name '+this.newAccount.Name);
        console.log('Type '+this.newAccount.Type);
        console.log('AnnualRevenue '+this.newAccount.AnnualRevenue);
        console.log('Phone '+this.newAccount.Phone);
        console.log('Website '+this.newAccount.Website);
        console.log('Rating '+this.newAccount.Rating);
        const accountResponse = JSON.stringify({
            Name: this.newAccount.Name,
            Type: this.newAccount.Type,
            AnnualRevenue: parseFloat(this.newAccount.AnnualRevenue),
            Phone: this.newAccount.Phone,
            Website: this.newAccount.Website,
            Rating: this.newAccount.Rating
        });
        sendAccountDetails({ acc: accountResponse })
            .then(() => {
                this.isNewAccountFormVisible = false;
                return refreshApex(this.wiredAccountResult); // Refresh the Apex call
            })
            .catch(error => {
                this.error = error;
            });
    }
    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        switch (actionName) {
            case 'edit':
                this.editAccount(row);
                break;
            default:
        }
    }

    editAccount(row) {
        this.newAccount = { ...row };
        this.isNewAccountFormVisible = true;
    }
}