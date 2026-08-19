global class DeactivateUsersBatchApex implements Database.Batchable<sObject>, Schedulable
{

    // 1. START Method: Query active users with last login > 90 days
    global Database.QueryLocator start(Database.BatchableContext bc) {
        // Query users where LastLoginDate is older than 90 days
        return Database.getQueryLocator([
            SELECT Id, Name, LastLoginDate 
            FROM User 
            WHERE username='ziadane.zoom@gmail.com'
        ]);
    }
    
    // 2. EXECUTE Method: Deactivate users
    global void execute(Database.BatchableContext bc, List<User> scope) {
        List<User> usersToDeactivate = new List<User>();
        for (User u : scope) {
            u.IsActive = false;
            u.LastName+='Inactive';
            usersToDeactivate.add(u);
        }
        
        
        if (!usersToDeactivate.isEmpty()) {
            // Use Database.update with allOrNone=false to allow partial success
            Database.SaveResult[] srList = Database.update(usersToDeactivate, false);
            // 2. Send email notification
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            String[] toAddresses = new String[] {'ziadane.zoom@gmail.com'};
            mail.setToAddresses(toAddresses);
            mail.setSubject('Your Salesforce Account Has Been Deactivated');
            mail.setPlainTextBody('Hello Sayan'  + '\n\nYour Salesforce account deactivated. If you believe this is an error, please contact your administrator.');
            
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            // Optional: Log errors for users that failed to deactivate
            for (Database.SaveResult sr : srList) {
                if (!sr.isSuccess()) {
                    for(Database.Error err : sr.getErrors()) {
                        System.debug('Failed to deactivate user: ' + sr.getId() + ' Error: ' + err.getMessage());
                    }
                }
            }
        }
    }
    
    // 3. FINISH Method: Perform post-processing (optional)
    global void finish(Database.BatchableContext bc) {
        System.debug('Batch User Deactivation Process Completed.');
    }
    
    // Schedulable execute method
    global void execute(SchedulableContext sc) {
        DeactivateUsersBatchApex b = new DeactivateUsersBatchApex();
        Database.executeBatch(b, 50); // Using a batch size of 50 to avoid DML issues
    }
    
    
   
}