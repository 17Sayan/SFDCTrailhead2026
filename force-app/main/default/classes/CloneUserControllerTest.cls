@isTest
private class CloneUserControllerTest {

    @TestSetup
    static void setupTestData() {
        Profile stdProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User sourceUser = new User(
            FirstName        = 'Source',
            LastName         = 'TestUser',
            Email            = 'source.testuser@clonetest.com',
            Username         = 'source.testuser.' + System.currentTimeMillis() + '@clonetest.com',
            Alias            = 'srcusr',
            CommunityNickname = 'srcTestUser' + System.currentTimeMillis(),
            ProfileId        = stdProfile.Id,
            LocaleSidKey     = 'en_US',
            LanguageLocaleKey = 'en_US',
            TimeZoneSidKey   = 'America/New_York',
            EmailEncodingKey = 'UTF-8',
            Department       = 'Engineering',
            Title            = 'Senior Developer',
            CompanyName      = 'Test Corp',
            Phone            = '555-0100',
            MobilePhone      = '555-0101',
            Fax              = '555-0102',
            IsActive         = true
        );
        insert sourceUser;
    }

    static User getSourceUser() {
        return [
            SELECT Id, ProfileId, UserRoleId, Department, Title, CompanyName,
                   Phone, MobilePhone, Fax, LocaleSidKey, LanguageLocaleKey,
                   TimeZoneSidKey, EmailEncodingKey, Username, Email,
                   Alias, CommunityNickname, IsActive
            FROM User
            WHERE Alias = 'srcusr'
            LIMIT 1
        ];
    }

    // Scenario 1 - Link button returns correct fields
    @isTest
    static void testGetUserDetails_ReturnsCorrectFields() {
        User src = getSourceUser();
        Test.startTest();
        User result = CloneUserController.getUserDetails(src.Id);
        Test.stopTest();
        Assert.isNotNull(result, 'getUserDetails should return a User record');
        Assert.areEqual(src.ProfileId, result.ProfileId, 'ProfileId must match');
        Assert.areEqual('Engineering', result.Department, 'Department must be returned');
        Assert.areEqual('Senior Developer', result.Title, 'Title must be returned');
    }

    // Scenario 2 - Pop-up loads data
    @isTest
    static void testGetUserDetails_ValidUser() {
        User src = getSourceUser();
        Test.startTest();
        User result = CloneUserController.getUserDetails(src.Id);
        Test.stopTest();
        Assert.isNotNull(result, 'User record should be returned for popup');
        Assert.areEqual(src.Id, result.Id, 'Returned user Id must match');
        Assert.areEqual('Test Corp', result.CompanyName, 'CompanyName should load');
    }

    @isTest
    static void testGetUserDetails_InvalidUser() {
        Test.startTest();
        try {
            CloneUserController.getUserDetails('005000000000000AAA');
            Assert.fail('Should throw AuraHandledException for invalid user');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().length() > 0, 'Error message should be non-empty');
        }
        Test.stopTest();
    }

    @isTest
    static void testGetPermissionSetAssignments() {
        User src = getSourceUser();
        Test.startTest();
        List<PermissionSetAssignment> psas = CloneUserController.getPermissionSetAssignments(src.Id);
        Test.stopTest();
        Assert.isNotNull(psas, 'Permission set list must not be null');
    }

    // Scenario 3 - No duplication of unique fields
    @isTest
    static void testCloneUser_UniqueFieldsRequired() {
        User src = getSourceUser();
        String ts = String.valueOf(System.currentTimeMillis());
        Map<String, Object> fields = new Map<String, Object>{
            'FirstName'         => 'Clone',
            'LastName'          => 'NewUser',
            'Email'             => 'clone.newuser@clonetest.com',
            'Username'          => 'clone.newuser.' + ts + '@clonetest.com',
            'Alias'             => 'clnusr',
            'CommunityNickname' => 'cloneNew' + ts,
            'ProfileId'         => src.ProfileId,
            'LocaleSidKey'      => src.LocaleSidKey,
            'LanguageLocaleKey' => src.LanguageLocaleKey,
            'TimeZoneSidKey'    => src.TimeZoneSidKey,
            'EmailEncodingKey'  => src.EmailEncodingKey,
            'Department'        => src.Department,
            'Title'             => src.Title,
            'sourceUserId'      => src.Id
        };
        Test.startTest();
        Id newUserId = CloneUserController.cloneUser(fields);
        Test.stopTest();
        User newUser = [SELECT Username, Email FROM User WHERE Id = :newUserId];
        Assert.areNotEqual(src.Username, newUser.Username, 'Username must be unique');
    }

    @isTest
    static void testCloneUser_DuplicateUsername_Fails() {
        User src = getSourceUser();
        Map<String, Object> fields = new Map<String, Object>{
            'FirstName'         => 'Dup',
            'LastName'          => 'User',
            'Email'             => 'dup.user@clonetest.com',
            'Username'          => src.Username,
            'Alias'             => 'dpusr',
            'CommunityNickname' => 'dupUser' + System.currentTimeMillis(),
            'ProfileId'         => src.ProfileId,
            'LocaleSidKey'      => 'en_US',
            'LanguageLocaleKey' => 'en_US',
            'TimeZoneSidKey'    => 'America/New_York',
            'EmailEncodingKey'  => 'UTF-8',
            'sourceUserId'      => src.Id
        };
        Test.startTest();
        try {
            CloneUserController.cloneUser(fields);
            Assert.fail('Should throw for duplicate Username');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().length() > 0, 'Error must describe issue');
        }
        Test.stopTest();
    }

    @isTest
    static void testCloneUser_SameEmailAllowed() {
        User src = getSourceUser();
        String ts = String.valueOf(System.currentTimeMillis());
        Map<String, Object> fields = new Map<String, Object>{
            'FirstName'         => 'EmailDup',
            'LastName'          => 'TestUser',
            'Email'             => src.Email,
            'Username'          => 'emaildup.' + ts + '@clonetest.com',
            'Alias'             => 'emdup',
            'CommunityNickname' => 'emailDup' + ts,
            'ProfileId'         => src.ProfileId,
            'LocaleSidKey'      => 'en_US',
            'LanguageLocaleKey' => 'en_US',
            'TimeZoneSidKey'    => 'America/New_York',
            'EmailEncodingKey'  => 'UTF-8',
            'sourceUserId'      => src.Id
        };
        Test.startTest();
        Id newUserId = CloneUserController.cloneUser(fields);
        Test.stopTest();
        Assert.isNotNull(newUserId, 'Same email with unique username should succeed');
    }

    // Scenario 4 - Clone licenses and permission sets
    @isTest
    static void testCloneUser_ClonesPermissionSets() {
        User src = getSourceUser();
        List<PermissionSetAssignment> srcPSAs = [
            SELECT PermissionSetId FROM PermissionSetAssignment
            WHERE AssigneeId = :src.Id AND PermissionSet.IsOwnedByProfile = false
        ];
        String ts = String.valueOf(System.currentTimeMillis());
        Map<String, Object> fields = new Map<String, Object>{
            'FirstName'         => 'PSClone',
            'LastName'          => 'TestUser',
            'Email'             => 'psclone@clonetest.com',
            'Username'          => 'psclone.' + ts + '@clonetest.com',
            'Alias'             => 'pscln',
            'CommunityNickname' => 'psClone' + ts,
            'ProfileId'         => src.ProfileId,
            'LocaleSidKey'      => 'en_US',
            'LanguageLocaleKey' => 'en_US',
            'TimeZoneSidKey'    => 'America/New_York',
            'EmailEncodingKey'  => 'UTF-8',
            'sourceUserId'      => src.Id
        };
        Test.startTest();
        Id newUserId = CloneUserController.cloneUser(fields);
        Test.stopTest();
        List<PermissionSetAssignment> newPSAs = [
            SELECT PermissionSetId FROM PermissionSetAssignment
            WHERE AssigneeId = :newUserId AND PermissionSet.IsOwnedByProfile = false
        ];
        Assert.areEqual(srcPSAs.size(), newPSAs.size(), 'Permission set count must match');
    }

    @isTest
    static void testCloneUser_ClonesProfileAndRole() {
        User src = getSourceUser();
        String ts = String.valueOf(System.currentTimeMillis());
        Map<String, Object> fields = new Map<String, Object>{
            'FirstName'         => 'RoleClone',
            'LastName'          => 'TestUser',
            'Email'             => 'roleclone@clonetest.com',
            'Username'          => 'roleclone.' + ts + '@clonetest.com',
            'Alias'             => 'rlcln',
            'CommunityNickname' => 'roleClone' + ts,
            'ProfileId'         => src.ProfileId,
            'UserRoleId'        => src.UserRoleId,
            'LocaleSidKey'      => 'en_US',
            'LanguageLocaleKey' => 'en_US',
            'TimeZoneSidKey'    => 'America/New_York',
            'EmailEncodingKey'  => 'UTF-8',
            'sourceUserId'      => src.Id
        };
        Test.startTest();
        Id newUserId = CloneUserController.cloneUser(fields);
        Test.stopTest();
        User newUser = [SELECT ProfileId, UserRoleId FROM User WHERE Id = :newUserId];
        Assert.areEqual(src.ProfileId, newUser.ProfileId, 'Profile must be cloned');
    }

    @isTest
    static void testCloneUser_PreservesLocaleSettings() {
        User src = getSourceUser();
        String ts = String.valueOf(System.currentTimeMillis());
        Map<String, Object> fields = new Map<String, Object>{
            'FirstName'         => 'LocaleClone',
            'LastName'          => 'TestUser',
            'Email'             => 'localeclone@clonetest.com',
            'Username'          => 'localeclone.' + ts + '@clonetest.com',
            'Alias'             => 'lccln',
            'CommunityNickname' => 'localeClone' + ts,
            'ProfileId'         => src.ProfileId,
            'LocaleSidKey'      => src.LocaleSidKey,
            'LanguageLocaleKey' => src.LanguageLocaleKey,
            'TimeZoneSidKey'    => src.TimeZoneSidKey,
            'EmailEncodingKey'  => src.EmailEncodingKey,
            'sourceUserId'      => src.Id
        };
        Test.startTest();
        Id newUserId = CloneUserController.cloneUser(fields);
        Test.stopTest();
        User newUser = [SELECT LocaleSidKey, LanguageLocaleKey, TimeZoneSidKey, EmailEncodingKey
                        FROM User WHERE Id = :newUserId];
        Assert.areEqual('en_US', newUser.LocaleSidKey, 'LocaleSidKey must be preserved');
        Assert.areEqual('America/New_York', newUser.TimeZoneSidKey, 'TimeZoneSidKey must be preserved');
    }

    // Scenario 5 - License limit exceeded shows reason
    @isTest
    static void testCheckLicenseAvailability() {
        User src = getSourceUser();
        Test.startTest();
        Boolean isAvailable = CloneUserController.checkLicenseAvailability(src.ProfileId);
        Test.stopTest();
        Assert.isNotNull(isAvailable, 'License check must return a result');
    }

    @isTest
    static void testCloneUser_LicenseLimitHandled() {
        User src = getSourceUser();
        String ts = String.valueOf(System.currentTimeMillis());
        Map<String, Object> fields = new Map<String, Object>{
            'FirstName'         => 'LicFail',
            'LastName'          => 'TestUser',
            'Email'             => 'licfail@clonetest.com',
            'Username'          => 'licfail.' + ts + '@clonetest.com',
            'Alias'             => 'lcfal',
            'CommunityNickname' => 'licFail' + ts,
            'ProfileId'         => src.ProfileId,
            'LocaleSidKey'      => 'en_US',
            'LanguageLocaleKey' => 'en_US',
            'TimeZoneSidKey'    => 'America/New_York',
            'EmailEncodingKey'  => 'UTF-8',
            'sourceUserId'      => src.Id
        };
        Test.startTest();
        try {
            Id newUserId = CloneUserController.cloneUser(fields);
            Assert.isNotNull(newUserId, 'Clone succeeds when licenses available');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().containsIgnoreCase('license'),
                'Error must contain license reason: ' + e.getMessage());
        }
        Test.stopTest();
    }

    // Scenario 6 - General error handling
    @isTest
    static void testCloneUser_MissingRequiredFields() {
        Map<String, Object> fields = new Map<String, Object>{
            'FirstName' => 'Missing',
            'LastName'  => 'Fields'
        };
        Test.startTest();
        try {
            CloneUserController.cloneUser(fields);
            Assert.fail('Should throw for missing required fields');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().length() > 0, 'Error must describe missing fields');
        }
        Test.stopTest();
    }

    @isTest
    static void testCloneUser_NullInput() {
        Test.startTest();
        try {
            CloneUserController.cloneUser(null);
            Assert.fail('Should throw for null input');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().length() > 0, 'Null-input error must be user-friendly');
        }
        Test.stopTest();
    }

    @isTest
    static void testGetUserDetails_NullId() {
        Test.startTest();
        try {
            CloneUserController.getUserDetails(null);
            Assert.fail('Should throw for null user Id');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().length() > 0, 'Error for null Id must be displayable');
        }
        Test.stopTest();
    }
}
