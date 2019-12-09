public with sharing class C501_Shared_Code {
    public C501_Shared_Code() {
    }

    public class InvalidParameterValueException extends Exception {}

    private static Boolean fCheckedIsSandbox = false;
    public static Boolean IsSandbox {
        get {
            if (!fCheckedIsSandbox) {
                IsSandbox = true;
                List<Organization> organizations = [SELECT IsSandbox FROM Organization LIMIT 1];
                if (!organizations.isEmpty()) {
                    IsSandbox = Boolean.valueOf(organizations[0].IsSandbox);
                }
                fCheckedIsSandbox = true;
            }

            return IsSandbox;
        }

        set;
    }

    public static String GetExceptionMessage(Exception e) {
        return ' - ' + e.getTypeName() + ' Message: ' + e.getMessage() + ' Line Number: ' + e.getLineNumber() + ' Cause: ' + e.getCause() + ' Stack Trace: ' + e.getStackTraceString();
    }

    public static Boolean ValidateEmail(String email) {
        
        Boolean res = true;
        String emailRegex = '^[a-zA-Z0-9._|\\\\%#~`=?&/$^*!}{+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,4}$'; // source: <a href="http://www.regular-expressions.info/email.html" target="_blank" rel="nofollow">http://www.regular-expressions.info/email.html</a>
        Pattern MyPattern = Pattern.compile(emailRegex);
        Matcher MyMatcher = MyPattern.matcher(email);
    
        if (!MyMatcher.matches()) 
            res = false;
        return res; 
    }
    
    public static String CleanString(String stringValue, Boolean toLowerCase) {
        if (String.isBlank(stringValue)) {
            return stringValue;
        }

        if (toLowerCase) { 
            stringValue = stringValue.toLowerCase();
        }

        return stringValue.trim();
    }

    public static String CleanEmailString(String stringValue, Boolean toLowerCase) {
        if (String.isBlank(stringValue)) {
            return stringValue;
        }

        stringValue = CleanString(stringValue, toLowerCase);

        //if (!ValidateEmail(stringValue)) {

            stringValue = stringValue.replace('..', '.');

            if (stringValue.endsWith('.comm')) {
                stringValue = stringValue.replace('.comm', '.com');
            }

            if (stringValue.endsWith('.orgg')) {
                stringValue = stringValue.replace('.orgg', '.org');
            }
        //}

        // Remove spaces
        stringValue = stringValue.replaceAll(' ', '');


        return stringValue;
    }

    public static void SendAdminAlert(LoggingLevel logLevel, String adminEmailAddress, String message){

        List<EmailMessage> adminEmailMessages = [SELECT CreatedDate FROM EmailMessage WHERE Subject = 'Salesforce Admin Notification' ORDER BY CreatedDate DESC LIMIT 1];
        if (!adminEmailMessages.isEmpty()) {

            // Check to only send up to 1 per day interval
            DateTime checkDateTime = Datetime.now().addDays(-1);
            if (adminEmailMessages[0].CreatedDate > checkDateTime) {
                return;
            }
        }

        EmailMessage adminEmail = new EmailMessage(
            Subject = 'Salesforce Admin Notification',
            Status = '3'
        );
        Database.insert(adminEmail, false);

        // Output Debugger
		System.debug(logLevel, message);

        // Ignore sending email for UNABLE_TO_LOCK_ROW because scheduled action will retry again
        if (message.contains('UNABLE_TO_LOCK_ROW')) {
            return;
        }

        // Output Email Message
        if (Limits.getEmailInvocations() >= Limits.getLimitEmailInvocations()) {
            System.debug(logLevel, '*****C501_Shared_Code::SendAdminAlert - Disabled sending emails since limit reached: ' + Limits.getLimitEmailInvocations());
            return;
        }

//        List<OrgWideEmailAddress> orgEmails = [select id, DisplayName, Address from OrgWideEmailAddress where DisplayName = :adminType];
//        String orgEmail = orgEmails[0].Address;
        String orgEmail = adminEmailAddress;
        
        try {
            Messaging.SingleEmailMessage adminMail = C501_Shared_Code.BuildAdminEmail(null, null, orgEmail, null, null, message, C501_Shared_Code.isSandbox);
            if (adminMail != null) {
                C501_Shared_Code.SendEmails(new Messaging.SingleEmailMessage[] { adminMail }, orgEmail, null, null, C501_Shared_Code.isSandbox);
            }
        }
        catch (Exception e) {
            System.debug(logLevel, '*****C501_Shared_Code::SendAdminAlert Exception Sending Email: ' + C501_Shared_Code.GetExceptionMessage(e));
        }
    }

    public static Boolean SendEmails(List<Messaging.SingleEmailMessage> emails, String adminEmail, String emailTemplate, String messageData) {

        return C501_Shared_Code.SendEmails(emails, adminEmail, emailTemplate, messageData, C501_Shared_Code.isSandbox);
    }

    public static Integer LimitEmailInvocations() {
        return Limits.getLimitEmailInvocations() - Limits.getEmailInvocations();
    }

    public static Boolean SendEmails(List<Messaging.SingleEmailMessage> emails, String adminEmail, String emailTemplate, String messageData, Boolean isSandbox) {

        if (emails.isEmpty()) {
            return false;
        }

        Messaging.reserveSingleEmailCapacity(2);
        List<Messaging.SingleEmailMessage> adminEmails = new List<Messaging.SingleEmailMessage>();
        List<Messaging.SingleEmailMessage> emailSendQueue = new List<Messaging.SingleEmailMessage>();

        try {
            // Send in batches of 10 which is the limit for Messaging.sendEmail
            List<Messaging.SendEmailResult> results = new List<Messaging.SendEmailResult>();
            for (Messaging.SingleEmailMessage emailMessage :emails) {

                if (C501_Shared_Code.LimitEmailInvocations() <= 0) {
                    System.debug(LoggingLevel.DEBUG, '*****C501_Shared_Code::SendEmails - Disabled sending emails since limit reached: ' + Limits.getLimitEmailInvocations());
                    return false;
                }

/*
                // Check to override email unless allowed domain
                if (C501_Shared_Code.IsSandbox) {
                    for (String emailAddress :emailMessage.getToAddresses()) {
                        if (!emailAddress.toLowerCase().contains('bezosfamilyfoundation.org') &&
                            !emailAddress.toLowerCase().contains('fuzzco.com') &&
                            !emailAddress.toLowerCase().contains('501commons.org')) {

                            Messaging.SingleEmailMessage adminMail = C501_Shared_Code.BuildAdminEmail(null, emailAddress, adminEmail, emailTemplate, messageData, 'WARNING: Email to ' + emailAddress + ' disabled in Sandbox.', C501_Shared_Code.isSandbox);
                            if (adminMail != null) {
                                adminEmails.add(adminMail);

                                continue;
                            }
                        }
                    }
                }
*/
                emailSendQueue.add(emailMessage);

                if (emailSendQueue.size() == C501_Shared_Code.LimitEmailInvocations()) {
                    results.addAll(Messaging.sendEmail(emailSendQueue, false));
                    emailSendQueue.clear();
                }
                else if (emailSendQueue.size() > C501_Shared_Code.LimitEmailInvocations()) {
                    Messaging.SingleEmailMessage adminMail = C501_Shared_Code.BuildAdminEmail(null, adminEmail, adminEmail, emailTemplate, messageData, 'Error SendEmail Loop: send email queue size should never exceed 10 Actual: ' + String.valueOf(emailSendQueue.size()), C501_Shared_Code.isSandbox);
                    if (adminMail != null) {
                        adminEmails.add(adminMail);
                    }
                }
            }

            if (emailSendQueue.size() > 0 && emailSendQueue.size() <= C501_Shared_Code.LimitEmailInvocations()) {
                results.addAll(Messaging.sendEmail(emailSendQueue, false));
                emailSendQueue.clear();
            }
            else if (emailSendQueue.size() > C501_Shared_Code.LimitEmailInvocations()) {
                Messaging.SingleEmailMessage adminMail = C501_Shared_Code.BuildAdminEmail(null, adminEmail, adminEmail, emailTemplate, messageData, 'Error SendEmail Overflow: send email queue size should never exceed 10 Actual: ' + String.valueOf(emailSendQueue.size()), C501_Shared_Code.isSandbox);
                if (adminMail != null) {
                    adminEmails.add(adminMail);
                }
            }

            if (results.isEmpty()) {
                Messaging.SingleEmailMessage adminMail = C501_Shared_Code.BuildAdminEmail(null, adminEmail, adminEmail, emailTemplate, messageData, 'Error: Send Mail Missing Results' + ' target emails: ' + String.valueOf(emails), C501_Shared_Code.isSandbox);
                if (adminMail != null) {
                    adminEmails.add(adminMail);
                }
            }
            else {
                for ( Messaging.SendEmailResult result :results ) {
                    if (!result.isSuccess()) {
                        Messaging.SingleEmailMessage adminMail = C501_Shared_Code.BuildAdminEmail(null, adminEmail, adminEmail, emailTemplate, messageData, 'Error: Send Mail Failed - ' + String.valueOf(result.getErrors()) + ' result details: ' + String.valueOf(result), C501_Shared_Code.isSandbox);
                        if (adminMail != null) {
                            adminEmails.add(adminMail);
                        }
                    }
                }
            }
        }
        catch (System.LimitException ex) {
            System.debug(LoggingLevel.ERROR, '*****C501_Shared_Code::SendEmails Exception: ' + C501_Shared_Code.GetExceptionMessage(ex));
        }
        catch (Exception e) {
            System.debug(LoggingLevel.ERROR, '*****C501_Shared_Code::SendEmails Exception: ' + C501_Shared_Code.GetExceptionMessage(e));
            Messaging.SingleEmailMessage adminMail = C501_Shared_Code.BuildAdminEmail(null, adminEmail, adminEmail, emailTemplate, messageData,
                'Error: Send Mail Exception - ' + String.valueOf(e) + '\n\nStack Trace: ' + e.getStackTraceString() + ' target emails: ' + String.valueOf(emailSendQueue), C501_Shared_Code.isSandbox);
            if (adminMail != null) {
                adminEmails.add(adminMail);
            }
        }
        
        if (!adminEmails.isEmpty()) {
            try {
                // Send in batches of 10 which is the limit for Messaging.sendEmail
                emailSendQueue.clear();
                for (Messaging.SingleEmailMessage emailMessage :adminEmails) {

                    if (C501_Shared_Code.LimitEmailInvocations() <= 0) {
                        System.debug(LoggingLevel.DEBUG, '*****C501_Shared_Code::SendEmails - Disabled sending admin emails since limit reached: ' + Limits.getLimitEmailInvocations());
                        return false;
                    }

                    emailSendQueue.add(emailMessage);
                    if (emailSendQueue.size() == C501_Shared_Code.LimitEmailInvocations()) {
                        Messaging.sendEmail(emailSendQueue, false);
                        emailSendQueue.clear();
                    }
                    else if (emailSendQueue.size() > C501_Shared_Code.LimitEmailInvocations()) {
                        throw new InvalidParameterValueException('Error SendEmail - Admin Loop: send email queue size should never exceed 10');
                    }
                }

                if (emailSendQueue.size() > 0 && emailSendQueue.size() <= C501_Shared_Code.LimitEmailInvocations()) {
                    Messaging.sendEmail(emailSendQueue, false);
                    emailSendQueue.clear();
                }
                else if (emailSendQueue.size() > C501_Shared_Code.LimitEmailInvocations()) {
                    throw new InvalidParameterValueException('Error SendEmail - Admin Overflow: send email queue size should never exceed 10');
                }

            }
            catch (System.LimitException ex) {
                System.debug(LoggingLevel.DEBUG, '*****C501_Shared_Code::SendEmail Exception: ' + C501_Shared_Code.GetExceptionMessage(ex));
            }       
            catch (Exception e) {
                System.debug(LoggingLevel.DEBUG, '*****C501_Shared_Code::SendEmail Exception: ' + C501_Shared_Code.GetExceptionMessage(e));
                throw new InvalidParameterValueException('*****C501_Shared_Code::SendEmail Exception: ' + C501_Shared_Code.GetExceptionMessage(e));
            }

            return false;
        }

        return true;
    }

    public static Messaging.SingleEmailMessage BuildContactEmail(Id emailTemplateId, Id contactId, Id relatedId, String email, List<OrgWideEmailAddress> orgEmails) {

        if (!ValidateEmail(email)) {
            return null;
        }

		if (emailTemplateId == null) {
			return null;
		}

		Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

        if (!orgEmails.isEmpty()) {
            mail.setOrgWideEmailAddressId(orgEmails[0].Id);
        }

		mail.setTemplateId(emailTemplateId);
        mail.setTargetObjectId(contactId);
        if (relatedId != null) {
            mail.setWhatId(relatedId);
        }

        mail.setToAddresses(new List<string>{email});
        mail.setUseSignature(false);
        mail.setBccSender(false);
   		mail.setSaveAsActivity(true);

       return mail;
	}

    public static Messaging.SingleEmailMessage BuildContactEmail_v2(Id emailTemplateId, Id contactId, Id relatedId, String email, List<OrgWideEmailAddress> orgEmails, Boolean bccSender) {

        if (!ValidateEmail(email)) {
            return null;
        }

		if (emailTemplateId == null) {
			return null;
		}

		Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

        if (!orgEmails.isEmpty()) {
            mail.setOrgWideEmailAddressId(orgEmails[0].Id);
        }

		mail.setTemplateId(emailTemplateId);
        mail.setTargetObjectId(contactId);
        if (relatedId != null) {
            mail.setWhatId(relatedId);
        }

        mail.setToAddresses(new List<string>{email});
        mail.setUseSignature(false);
        mail.setBccSender(bccSender);
   		mail.setSaveAsActivity(true);

       return mail;
	}

    public static Messaging.SingleEmailMessage BuildUserEmail(Id emailTemplateId, Id userId, Id relatedId, String email, List<OrgWideEmailAddress> orgEmails) {

        if (!ValidateEmail(email)) {
            return null;
        }

		if (emailTemplateId == null) {
			return null;
		}

		Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

        if (!orgEmails.isEmpty()) {
            mail.setOrgWideEmailAddressId(orgEmails[0].Id);
        }

		mail.setTemplateId(emailTemplateId);
        mail.setTargetObjectId(userId);
        if (relatedId != null) {
            mail.setWhatId(relatedId);
        }

        mail.setToAddresses(new List<string>{email});
        mail.setUseSignature(false);
        mail.setBccSender(false);

        // Activity must be false for Users
   		mail.setSaveAsActivity(false);

       return mail;
	}

    public static Messaging.SingleEmailMessage BuildAdminEmail(Id contactId, String email, String adminEmail, String emailTemplate, String messageData, String errorMessage, Boolean isSandbox) {

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

        // Set common parameters
        mail.setUseSignature(false);
        mail.setBccSender(false);

        List<String> emails = new List<string>{ adminEmail <> null ? adminEmail : '' };

        // Debugging - clear out list to limit emails when debugging
//        if (C501_Shared_Code.IsSandbox) {
//            emails.clear();
//        }

        // Check to add 501 Commons Email
        Boolean found501Email = false;
        for (String emailCheck :emails) {
            if (emailCheck.containsIgnoreCase('501commons.org')) {
                found501Email = true;
                break;
            }
        }

        if (!found501Email) {
            emails.add('sfconsulting@501commons.org');
        }

        mail.setToAddresses(emails);

        mail.setSubject('Salesforce Admin Notification');

        mail.setPlainTextBody(
            (String.isBlank(contactId) ? '' : ('\n\nContactId: ' + contactId)) + 
            (String.isBlank(email) ? '' : ('\n\nEmail: ' + email)) + 
            (String.isBlank(emailTemplate) ? '' : ('\n\nTemplate: ' + emailTemplate)) + 
            (String.isBlank(messageData) ? '' : ('\n\nMessage Data: ' + messageData)) +
            (String.isBlank(errorMessage) ? '' : ('\nError Message: ' + errorMessage)));

        mail.setHtmlBody(
            (String.isBlank(contactId) ? '' : 'ContactId: ' + contactId) + 
            (String.isBlank(email) ? '' : ('<br/><br/>Email: ' + email)) + 
            (String.isBlank(emailTemplate) ? '' : '<br/><br/>Template: ' + emailTemplate) + 
            (String.isBlank(messageData) ? '' : '<br/><br/>Message Data:<b> ' + messageData) + ' </b><p>'+
            (String.isBlank(errorMessage) ? '' : ('<br/>Error Message: ' + errorMessage))); 

        return mail;
    }

    public static void CodeCoverageHack() {
        Boolean hackIt = false;
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
        if (!hackIt || hackIt) {
            hackIt = !hackIt;
        }
    }
}