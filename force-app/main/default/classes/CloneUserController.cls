public with sharing class CloneUserController {

    @AuraEnabled
    public static User getUserDetails(Id userId) {
        if (userId == null) {
            throw new AuraHandledException('User Id is required');
        }
        try {
            return [
                SELECT Id, Username, Email, Name, ProfileId, UserRoleId,
                       Department, Title, CompanyName, Phone, MobilePhone, Fax,
                       LocaleSidKey, LanguageLocaleKey, TimeZoneSidKey,
                       EmailEncodingKey, IsActive, Alias, CommunityNickname
                FROM User
                WHERE Id = :userId
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException('User not found: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static List<PermissionSetAssignment> getPermissionSetAssignments(Id userId) {
        return [
            SELECT Id, PermissionSetId, PermissionSet.Name, PermissionSet.Label
            FROM PermissionSetAssignment
            WHERE AssigneeId = :userId
            AND PermissionSet.IsOwnedByProfile = false
        ];
    }

    @AuraEnabled
    public static Boolean checkLicenseAvailability(Id profileId) {
        Profile p = [SELECT UserLicenseId FROM Profile WHERE Id = :profileId LIMIT 1];
        UserLicense ul = [SELECT TotalLicenses, UsedLicenses FROM UserLicense WHERE Id = :p.UserLicenseId LIMIT 1];
        return ul.TotalLicenses == 0 || ul.UsedLicenses < ul.TotalLicenses;
    }

    @AuraEnabled
    public static Id cloneUser(Map<String, Object> fields) {
        if (fields == null || fields.isEmpty()) {
            throw new AuraHandledException('No user fields provided. Please fill in the required fields.');
        }
        try {
            String sourceUserId = (String) fields.remove('sourceUserId');

            User newUser = new User();
            for (String key : fields.keySet()) {
                newUser.put(key, fields.get(key));
            }
            newUser.IsActive = true;
            insert newUser;

            if (String.isNotBlank(sourceUserId)) {
                List<PermissionSetAssignment> sourcePSAs = [
                    SELECT PermissionSetId
                    FROM PermissionSetAssignment
                    WHERE AssigneeId = :sourceUserId
                    AND PermissionSet.IsOwnedByProfile = false
                ];
                List<PermissionSetAssignment> newPSAs = new List<PermissionSetAssignment>();
                for (PermissionSetAssignment psa : sourcePSAs) {
                    newPSAs.add(new PermissionSetAssignment(
                        AssigneeId = newUser.Id,
                        PermissionSetId = psa.PermissionSetId
                    ));
                }
                if (!newPSAs.isEmpty()) {
                    insert newPSAs;
                }
            }

            return newUser.Id;
        } catch (DmlException e) {
            String msg = e.getMessage();
            if (msg.containsIgnoreCase('LICENSE_LIMIT_EXCEEDED')) {
                throw new AuraHandledException('License limit exceeded. No available licenses for this user profile. Please contact your Salesforce administrator.');
            }
            if (msg.containsIgnoreCase('DUPLICATE_USERNAME')) {
                throw new AuraHandledException('This username is already taken. Please choose a different username.');
            }
            throw new AuraHandledException('Failed to create user: ' + msg);
        } catch (Exception e) {
            throw new AuraHandledException('Unexpected error: ' + e.getMessage());
        }
    }
}
