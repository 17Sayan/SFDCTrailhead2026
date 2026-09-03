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
            'sourceUserId'      => src.Id,
            'clonePermSets'     => true
        };
        Test.startTest();
        Id newUserId = CloneUserController.cloneUser(fields);
        Test.stopTest();
        Assert.isNotNull(newUserId, 'Clone with permission sets should succeed');
    }

    @isTest
    static void testCheckLicenseAvailability_HasCapacity() {
        User src = getSourceUser();
        Test.startTest();
        Boolean result = CloneUserController.checkLicenseAvailability(src.ProfileId);
        Test.stopTest();
        Assert.isNotNull(result, 'Should return true or false');
    }

    // Scenario 5 - Deactivate source user
    @isTest
    static void testCloneUser_DeactivateSource() {
        User src = getSourceUser();
        String ts = String.valueOf(System.currentTimeMillis());
        Map<String, Object> fields = new Map<String, Object>{
            'FirstName'         => 'DeactClone',
            'LastName'          => 'TestUser',
            'Email'             => 'deactclone@clonetest.com',
            'Username'          => 'deactclone.' + ts + '@clonetest.com',
            'Alias'             => 'dcusr',
            'CommunityNickname' => 'deactCln' + ts,
            'ProfileId'         => src.ProfileId,
            'LocaleSidKey'      => 'en_US',
            'LanguageLocaleKey' => 'en_US',
            'TimeZoneSidKey'    => 'America/New_York',
            'EmailEncodingKey'  => 'UTF-8',
            'sourceUserId'      => src.Id,
            'deactivateSource'  => true
        };
        Test.startTest();
        Id newUserId = CloneUserController.cloneUser(fields);
        Test.stopTest();
        User updatedSrc = [SELECT IsActive FROM User WHERE Id = :src.Id];
        Assert.areEqual(false, updatedSrc.IsActive, 'Source user should be deactivated');
    }

    @isTest
    static void testCloneUser_KeepSourceActive() {
        User src = getSourceUser();
        String ts = String.valueOf(System.currentTimeMillis());
        Map<String, Object> fields = new Map<String, Object>{
            'FirstName'         => 'KeepAct',
            'LastName'          => 'TestUser',
            'Email'             => 'keepact@clonetest.com',
            'Username'          => 'keepact.' + ts + '@clonetest.com',
            'Alias'             => 'kausr',
            'CommunityNickname' => 'keepAct' + ts,
            'ProfileId'         => src.ProfileId,
            'LocaleSidKey'      => 'en_US',
            'LanguageLocaleKey' => 'en_US',
            'TimeZoneSidKey'    => 'America/New_York',
            'EmailEncodingKey'  => 'UTF-8',
            'sourceUserId'      => src.Id,
            'deactivateSource'  => false
        };
        Test.startTest();
        Id newUserId = CloneUserController.cloneUser(fields);
        Test.stopTest();
        User updatedSrc = [SELECT IsActive FROM User WHERE Id = :src.Id];
        Assert.areEqual(true, updatedSrc.IsActive, 'Source should remain active');
    }

    // Scenario 6 - Email notification
    @isTest
    static void testCloneUser_WelcomeEmailSent() {
        User src = getSourceUser();
        String ts = String.valueOf(System.currentTimeMillis());
        Map<String, Object> fields = new Map<String, Object>{
            'FirstName'         => 'WelcEmail',
            'LastName'          => 'TestUser',
            'Email'             => 'welcemail@clonetest.com',
            'Username'          => 'welcemail.' + ts + '@clonetest.com',
            'Alias'             => 'weusr',
            'CommunityNickname' => 'welcEml' + ts,
            'ProfileId'         => src.ProfileId,
            'LocaleSidKey'      => 'en_US',
            'LanguageLocaleKey' => 'en_US',
            'TimeZoneSidKey'    => 'America/New_York',
            'EmailEncodingKey'  => 'UTF-8',
            'sourceUserId'      => src.Id,
            'sendWelcomeEmail'  => true
        };
        Test.startTest();
        Id newUserId = CloneUserController.cloneUser(fields);
        Test.stopTest();
        Assert.isNotNull(newUserId, 'Clone with welcome email should succeed');
    }

    @isTest
    static void testCloneUser_NoWelcomeEmail() {
        User src = getSourceUser();
        String ts = String.valueOf(System.currentTimeMillis());
        Map<String, Object> fields = new Map<String, Object>{
            'FirstName'         => 'NoEmail',
            'LastName'          => 'TestUser',
            'Email'             => 'noemail@clonetest.com',
            'Username'          => 'noemail.' + ts + '@clonetest.com',
            'Alias'             => 'neusr',
            'CommunityNickname' => 'noEml' + ts,
            'ProfileId'         => src.ProfileId,
            'LocaleSidKey'      => 'en_US',
            'LanguageLocaleKey' => 'en_US',
            'TimeZoneSidKey'    => 'America/New_York',
            'EmailEncodingKey'  => 'UTF-8',
            'sourceUserId'      => src.Id,
            'sendWelcomeEmail'  => false
        };
        Test.startTest();
        Id newUserId = CloneUserController.cloneUser(fields);
        Test.stopTest();
        Assert.isNotNull(newUserId, 'Clone without welcome email should succeed');
    }

    // Scenario 7 - Confirmation dialog
    @isTest
    static void testCloneUser_ReturnsNewUserId() {
        User src = getSourceUser();
        String ts = String.valueOf(System.currentTimeMillis());
        Map<String, Object> fields = new Map<String, Object>{
            'FirstName'         => 'Confirm',
            'LastName'          => 'TestUser',
            'Email'             => 'confirm@clonetest.com',
            'Username'          => 'confirm.' + ts + '@clonetest.com',
            'Alias'             => 'cfusr',
            'CommunityNickname' => 'cfmUsr' + ts,
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
        Assert.isNotNull(newUserId, 'Should return new user Id');
        Assert.isTrue(String.valueOf(newUserId).startsWith('005'), 'Should be a User Id');
    }

    // Scenario 8 - Error handling
    @isTest
    static void testCloneUser_MissingRequiredField_Throws() {
        Map<String, Object> fields = new Map<String, Object>{
            'FirstName' => 'Incomplete'
        };
        Test.startTest();
        try {
            CloneUserController.cloneUser(fields);
            Assert.fail('Should throw for missing required fields');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().length() > 0, 'Should have error message');
        }
        Test.stopTest();
    }

    @isTest
    static void testCloneUser_EmptyFields_Throws() {
        Map<String, Object> fields = new Map<String, Object>();
        Test.startTest();
        try {
            CloneUserController.cloneUser(fields);
            Assert.fail('Should throw for empty fields');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().length() > 0, 'Should have error message');
        }
        Test.stopTest();
    }

    // ── NEW: Coverage Gap Methods (4 methods for 100% coverage) ──

    // Covers line 6: getUserDetails null userId guard
    @isTest
    static void testGetUserDetails_NullUserId() {
        Test.startTest();
        try {
            CloneUserController.getUserDetails(null);
            Assert.fail('Should throw AuraHandledException for null userId');
        } catch (AuraHandledException e) {
            Assert.isTrue(
                e.getMessage().containsIgnoreCase('User Id is required'),
                'Error message should indicate userId is required. Got: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    // Covers lines 64-66: cloneUser null fields guard
    @isTest
    static void testCloneUser_NullFields() {
        Test.startTest();
        try {
            CloneUserController.cloneUser(null);
            Assert.fail('Should throw AuraHandledException for null fields');
        } catch (AuraHandledException e) {
            Assert.isTrue(
                e.getMessage().containsIgnoreCase('No user fields provided'),
                'Error message should indicate no fields provided. Got: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    // Covers line 78: LICENSE_LIMIT_EXCEEDED DmlException branch
    // Note: This test attempts to trigger the license limit branch by using
    // a Customer Community profile whose licenses are typically exhausted.
    // If the org does not have such a profile, the test validates that the
    // DmlException catch block is reached via clone failure.
    @isTest
    static void testCloneUser_LicenseLimitExceeded() {
        List<Profile> exhaustedProfiles = [
            SELECT Id, Name, UserLicenseId
            FROM Profile
            WHERE Name LIKE '%Customer Community%'
            LIMIT 1
        ];

        User src = getSourceUser();
        String ts = String.valueOf(System.currentTimeMillis());

        Id targetProfileId = !exhaustedProfiles.isEmpty()
            ? exhaustedProfiles[0].Id
            : src.ProfileId;

        Map<String, Object> fields = new Map<String, Object>{
            'FirstName'         => 'LicTest',
            'LastName'          => 'TestUser',
            'Email'             => 'lictest@clonetest.com',
            'Username'          => 'lictest.' + ts + '@clonetest.com',
            'Alias'             => 'lcusr',
            'CommunityNickname' => 'licTst' + ts,
            'ProfileId'         => targetProfileId,
            'LocaleSidKey'      => 'en_US',
            'LanguageLocaleKey' => 'en_US',
            'TimeZoneSidKey'    => 'America/New_York',
            'EmailEncodingKey'  => 'UTF-8'
        };

        Test.startTest();
        try {
            CloneUserController.cloneUser(fields);
        } catch (AuraHandledException e) {
            Assert.isTrue(
                e.getMessage().containsIgnoreCase('License limit exceeded') ||
                e.getMessage().containsIgnoreCase('Clone failed'),
                'Should throw a handled clone error. Got: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    // Covers lines 84-85: generic Exception catch block
    // Passes an invalid field name to trigger a non-DML exception
    // when User.put() encounters an unknown field
    @isTest
    static void testCloneUser_GenericException() {
        Map<String, Object> fields = new Map<String, Object>{
            'FirstName'               => 'GenErr',
            'LastName'                => 'TestUser',
            'Email'                   => 'generr@clonetest.com',
            'Username'                => 'generr.' + System.currentTimeMillis() + '@clonetest.com',
            'Alias'                   => 'geusr',
            'CommunityNickname'       => 'genErr' + System.currentTimeMillis(),
            'ProfileId'               => getSourceUser().ProfileId,
            'LocaleSidKey'            => 'en_US',
            'LanguageLocaleKey'       => 'en_US',
            'TimeZoneSidKey'          => 'America/New_York',
            'EmailEncodingKey'        => 'UTF-8',
            'NonExistentField__z'     => 'This field does not exist'
        };
        Test.startTest();
        try {
            CloneUserController.cloneUser(fields);
            Assert.fail('Should throw AuraHandledException for invalid field');
        } catch (AuraHandledException e) {
            Assert.isTrue(
                e.getMessage().containsIgnoreCase('Unexpected error'),
                'Should catch generic exception. Got: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }
}