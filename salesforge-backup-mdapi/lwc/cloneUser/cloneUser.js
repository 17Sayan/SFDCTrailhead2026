import { LightningElement, api, wire, track } from 'lwc';
import getUserDetails from '@salesforce/apex/CloneUserController.getUserDetails';
import cloneUserApex from '@salesforce/apex/CloneUserController.cloneUser';
import getPermissionSetAssignments from '@salesforce/apex/CloneUserController.getPermissionSetAssignments';
import checkLicenseAvailability from '@salesforce/apex/CloneUserController.checkLicenseAvailability';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

export default class CloneUser extends NavigationMixin(LightningElement) {
    @api recordId;
    @track sourceUser = {};
    @track permissionSets = [];
    @track isModalOpen = false;
    @track isLoading = false;
    @track errorMessage = '';
    @track licenseWarning = '';

    newFirstName = '';
    newLastName = '';
    newEmail = '';
    newUsername = '';
    newAlias = '';
    newCommunityNickname = '';

    @wire(getUserDetails, { userId: '$recordId' })
    wiredUser({ error, data }) {
        if (data) {
            this.sourceUser = data;
        } else if (error) {
            this.showToast('Error', error.body?.message || 'Failed to load user details', 'error');
        }
    }

    handleCloneClick() {
        this.isModalOpen = true;
        this.errorMessage = '';
        this.licenseWarning = '';
        this.isLoading = true;

        Promise.all([
            getPermissionSetAssignments({ userId: this.recordId }),
            checkLicenseAvailability({ profileId: this.sourceUser.ProfileId })
        ])
        .then(([psas, licenseAvailable]) => {
            this.permissionSets = psas;
            if (!licenseAvailable) {
                this.licenseWarning = 'No available licenses for this profile. The cloned user may not be created.';
            }
            this.isLoading = false;
        })
        .catch(error => {
            this.errorMessage = error.body?.message || 'Failed to load clone data';
            this.isLoading = false;
        });
    }

    handleCloseModal() {
        this.isModalOpen = false;
        this.errorMessage = '';
        this.licenseWarning = '';
        this.newFirstName = '';
        this.newLastName = '';
        this.newEmail = '';
        this.newUsername = '';
        this.newAlias = '';
        this.newCommunityNickname = '';
    }

    handleInputChange(event) {
        const field = event.target.dataset.field;
        if (field === 'FirstName') this.newFirstName = event.target.value;
        else if (field === 'LastName') this.newLastName = event.target.value;
        else if (field === 'Email') this.newEmail = event.target.value;
        else if (field === 'Username') this.newUsername = event.target.value;
        else if (field === 'Alias') this.newAlias = event.target.value;
        else if (field === 'CommunityNickname') this.newCommunityNickname = event.target.value;
    }

    handleClone() {
        if (!this.newFirstName || !this.newLastName || !this.newEmail || !this.newUsername || !this.newAlias) {
            this.errorMessage = 'Please fill in all required fields: First Name, Last Name, Email, Username, and Alias.';
            return;
        }

        this.isLoading = true;
        this.errorMessage = '';

        const fields = {
            FirstName: this.newFirstName,
            LastName: this.newLastName,
            Email: this.newEmail,
            Username: this.newUsername,
            Alias: this.newAlias,
            CommunityNickname: this.newCommunityNickname || this.newAlias,
            ProfileId: this.sourceUser.ProfileId,
            UserRoleId: this.sourceUser.UserRoleId,
            Department: this.sourceUser.Department,
            Title: this.sourceUser.Title,
            CompanyName: this.sourceUser.CompanyName,
            LocaleSidKey: this.sourceUser.LocaleSidKey,
            LanguageLocaleKey: this.sourceUser.LanguageLocaleKey,
            TimeZoneSidKey: this.sourceUser.TimeZoneSidKey,
            EmailEncodingKey: this.sourceUser.EmailEncodingKey,
            sourceUserId: this.recordId
        };

        cloneUserApex({ fields: fields })
            .then(newUserId => {
                this.isLoading = false;
                this.handleCloseModal();
                this.showToast('Success', 'User cloned successfully!', 'success');
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: newUserId,
                        objectApiName: 'User',
                        actionName: 'view'
                    }
                });
            })
            .catch(error => {
                this.isLoading = false;
                const msg = error.body?.message || 'An unexpected error occurred while cloning the user.';
                if (msg.toLowerCase().includes('license')) {
                    this.licenseWarning = msg;
                } else {
                    this.errorMessage = msg;
                }
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}