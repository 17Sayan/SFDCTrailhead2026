public class DeactivateInactiveUsersScheduler implements Schedulable {
    
    
    public void execute(SchedulableContext context) {
        // Query for active users where LastLoginDate is null
        List<User> usersToDeactivate = [
            SELECT Id, Name, Email
            FROM User
            where lastlogindate=null and email='ziadane.zoom@gmail.com'
          //  WHERE LastLoginDate <LAST_N_DAYS:100 and IsActive =true and Profile.Name !='System Administrator' and Profile.Name='Customer Service' order by LastLoginDate
            ];

        if (!usersToDeactivate.isEmpty()) {
            for (User u : usersToDeactivate) {
                u.IsActive = false;
                u.LastName=+'Inactive';
            }

            // Perform the DML operation to update the user records
            try {
                update usersToDeactivate;
                System.debug('Deactivated ' + usersToDeactivate.size() + ' inactive users.');
            } catch (DmlException e) {
                //System.error('DML Exception while deactivating users: ' + e.getMessage());
                // Handle exceptions appropriately
            }
        }
    }

}