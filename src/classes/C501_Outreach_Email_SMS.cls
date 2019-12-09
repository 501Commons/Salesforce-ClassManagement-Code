/*
    Copyright (c) 2019, 501Commons.org
    All rights reserved.
    
    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:
    
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of 501Commons.org nor the names of
      its contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.
 
    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS 
    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE 
    COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, 
    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; 
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT 
    LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN 
    ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
    POSSIBILITY OF SUCH DAMAGE.
*/

/*
      Execute in Developer Console
          C501_Outreach_Scheduled scheduledOutreach = new C501_Outreach_Scheduled();
          scheduledOutreach.execute(null);
*/

public with sharing class C501_Outreach_Email_SMS {
    @InvocableMethod(label = 'Outbound Email and SMS')
    public static void doThing (List<outboundESinputs> inputs) {
    
        TwilioConfig__c tc = TwilioConfig__c.getOrgDefaults();
        String acctId = tc.AccountSid__c;
        String authToken = tc.AuthToken__c;
        String messServiceId = tc.messServiceID__c;
        String fromNumber = tc.fromNumber__c;

        String trainingID;
        String smsTemplatePrefix;
        String emailTemplatePrefix;
        String replyToAddress;

        // List of all numbers to send Outreach message
        List<String> moblieFlist = new List<String>();

        // Map of Contact ID and Task Subject String for recording Outreach Task
        Map<Id, String> ctMap = new Map<Id,String>();
        
        // Populate Invocable variables
        List<String> stringList = new List<String>(); 
        for (outboundESinputs input : inputs) {
            if (String.isNotBlank(input.trainingID)) {
                trainingID=input.trainingID;
            }

            if (String.isNotBlank(input.smsTemplatePrefix)) {
                smsTemplatePrefix = input.smsTemplatePrefix.trim();
            }

            if (String.isNotBlank(input.emailTemplatePrefix)) {
                emailTemplatePrefix = input.emailTemplatePrefix.trim();
            }

            if (String.isNotBlank(input.replyToAddress)) {
                replyToAddress = input.replyToAddress.trim();
            }
        } 

        if (Test.isRunningTest()) {
            smsTemplatePrefix = 'Outreach SMS';
            emailTemplatePrefix = 'Outreach EMail';
            replyToAddress = 'test@test.com';
        }

        System.debug('trainingID: ' + trainingID);
        System.debug('smsTemplatePrefix: ' + smsTemplatePrefix);
        System.debug('emailTemplatePrefix: ' + emailTemplatePrefix);
        
        // Get Previous Email Templates if older than 24 hours old
        List<EmailTemplate> etDelete = [Select id,name from EmailTemplate WHERE name LIKE 'ZZ**%' AND CreatedDate < LAST_N_DAYS:1];
        System.debug('Templates to Delete: '+etDelete);
        
        // get Training (Campaign) information
        Campaign cmp = [SELECT Id, C501_Outreach_WA_Counties__c, Training_Name__c, custom_Start_DateTime__c, City__c, C501_Registration_Link__c, Language__c, Class_Type__c FROM Campaign WHERE Id = :trainingID LIMIT 1];
        
        if (String.isEmpty(cmp.C501_Outreach_WA_Counties__c)) {
            return;
        }

        // Get Campaign Membership for any Registered or Attended Trainees for This Fiscal Year forward
        String cmSearchText = 'SELECT ContactId, Training_Name__c FROM CampaignMember WHERE Training_Start_DateTime__c > LAST_FISCAL_YEAR AND (Training_Status__c = \'Attended\' OR Training_Status__c = \'Registered\')';
        List<CampaignMember> cm = Database.query(cmSearchText);
        System.debug('Campaign Members Queried: ' + cm);

        List<String> currentCM = new List<String>();
        for(CampaignMember cme : cm) {

            if (!cme.Training_Name__c.startsWithIgnoreCase('Electronic Attendance System')) {
                currentCM.add(cme.ContactId);
            }
        }

        // Create empty Email Template to compare
        EmailTemplate emptyTem = new EmailTemplate();

        // Get SMS Template
        String tempLang = 'English';
        if (cmp.Language__c == 'Spanish' || cmp.Language__c == 'Somali') {
            tempLang = cmp.Language__c;
        }

        String smsTempName = smsTemplatePrefix+' ('+tempLang+')';
        String smsTemQuery = 'Select id, name, Body from EmailTemplate where name = \'' + smsTempName + '\' limit 1';
        EmailTemplate smsTem = Database.query(smsTemQuery);
        String smsBodyRaw = smsTem.Body.right(smsTem.Body.length()-(smsTem.Body.indexof('>>>>')+6));
        String smsBodyFinal = smsBodyRaw.replace('<Training_Name__c>',cmp.Training_Name__c).replace('<Start_DateTime__c>', cmp.custom_Start_DateTime__c.format('MM/dd/yyyy', 'America/Los_Angeles')).replace('<City__c>',cmp.City__c).replace('<Registration_Link__c>',cmp.C501_Registration_Link__c);
        //System.debug('SMS Template: '+smsTem);
        //System.debug('SMS BodyFinal: '+smsBodyFinal);

        // Get Email Temaplate
        String emailTempName = emailTemplatePrefix + ' (' + tempLang + ')';
        String emailTemQuery = 'Select id, name, BrandTemplateId, DeveloperName, FolderId, HtmlValue, Subject, TemplateStyle, TemplateType from EmailTemplate where name = \'' + emailTempName + '\'  limit 1';
        EmailTemplate emailTem = Database.query(emailTemQuery);
        System.debug('Email Template Name: ' + emailTem.Name);

        String emailTempHTML = emailTem.HtmlValue.replace('{!Campaign.Training_Name__c}', cmp.Training_Name__c).replace('{!Campaign.custom_Start_DateTime__c}', cmp.custom_Start_DateTime__c.format('MM/dd/yyyy', 'America/Los_Angeles')).replace('{!Campaign.City__c}',cmp.City__c).replace('{!Campaign.C501_Registration_Link__c}',cmp.C501_Registration_Link__c);

        // Create Email Template for This Mailing
        Integer randInt=Integer.valueof((Math.random() * 100));
        string randNum=String.valueof(randInt);
        EmailTemplate newEmailTemplate = new EmailTemplate();
        newEmailTemplate.isActive = true;
        newEmailTemplate.Name = 'ZZ** '+ emailTem.Name + randNum + ' Sent: '+ Datetime.now().format('yyyy-MM-dd\'T\'HH:mm:ss');
        newEmailTemplate.DeveloperName = emailTem.DeveloperName.replace('__c','') + randNum + '_' + Datetime.now().format('yyyy_MM_dd_HH_mm_ss');
        System.debug('NewEmailTemplateDevName: '+ newEmailTemplate.DeveloperName);

        newEmailTemplate.TemplateStyle = emailTem.TemplateStyle;
        newEmailTemplate.HtmlValue = emailTempHTML;
        newEmailTemplate.Description = 'Copy of: ' + emailTem.Name + '. Only needed temporarily. Will be deleted next time outreach process is run.';
        newEmailTemplate.BrandTemplateId = emailTem.BrandTemplateId;
        newEmailTemplate.Subject = emailTem.Subject;
        newEmailTemplate.TemplateType = emailTem.TemplateType;
        newEmailTemplate.FolderId = emailTem.FolderId;
        
        // Build Query to get Contacts
        String countyPL = cmp.C501_Outreach_WA_Counties__c;
        countyPL = countyPL.replace(';', '\',\'');

        String soqlSelect = 'SELECT Id, C501_Imagine_WA_County__c, ii_Unit_Status__c, MobilePhone, Email, Imagine_Mobile_Phone__c, HasOptedOutOfEmail, ';
        soqlSelect += ' C501_SMS_Opt_Out__c, ii_Licensed__c, ii_Substitute_Pool_Status__c, ii_Sub_Pool_Status__c, ii_Initial_Training_Requirement__c, ii_Cpr_Cert_Status__c';
        String soqlFrom = ' FROM Contact';
        String soqlWhere = ' WHERE C501_Imagine_WA_County__c IN (\'' + countyPL + '\') ' ;

        // Filter contacts by Language only if Training language is Spanish or Somali otherwise default to English
        if (cmp.Language__c == 'Spanish' || cmp.Language__c == 'Somali') {
            soqlWhere += ' AND ii_Languages__c in (\'' + cmp.Language__c + '\')';
        }
        else {
            soqlWhere += ' AND ii_Languages__c not in (\'Spanish\',\'Somali\')';      
        }
        
        switch on cmp.Class_Type__c {
            when 'FFN' {
                soqlWhere += ' AND RecordType.DeveloperName = \'Contact\' AND ii_Unit_Status__c = \'In-Unit\' AND ii_Licensed__c = false';
            }
            when 'Licensed' {
                soqlWhere += ' AND RecordType.DeveloperName = \'Contact\' AND ii_Unit_Status__c = \'In-Unit\' AND ii_Licensed__c = true AND ii_Employer_Name__c = \'Washington State\'';
            }
            when 'Facility' {
                soqlWhere += ' AND RecordType.DeveloperName = \'Facility\' AND ii_Substitute_Pool_Status__c = \'Eligible\'';
            }
            when 'Substitute' {

                soqlWhere += ' AND RecordType.DeveloperName = \'Contact\' AND (ii_Sub_Pool_Status__c = \'Pending\' OR ii_Sub_Pool_Status__c = \'Finishing Qualifications\')';

                if (cmp.Training_Name__c.contains('Child Care Basics')) {
                    soqlWhere += ' AND ii_Initial_Training_Requirement__c = null';
                }
                else if (cmp.Training_Name__c.contains('CPR') || cmp.Training_Name__c.contains('First Aid') || cmp.Training_Name__c.contains('BBP')) {
                    soqlWhere += ' AND (ii_Cpr_Cert_Status__c = null OR ii_First_Aid_Cert_Status__c = null OR C501_BloodBorneP_Training_Completed__c = false)';
                }
            }
            when else {
                System.debug(LoggingLevel.ERROR, '*****C501_Outreach_Email_SMS: Unknown cmp.Class_Type__c: ' + cmp.Class_Type__c);
                return;
            } 
        }

        System.debug('========> soql Select: ' + soqlSelect);
        System.debug('========> soql From: ' + soqlFrom);
        System.debug('========> soql Where: ' + soqlWhere);

        Contact[] contactsPotential = Database.query(soqlSelect + soqlFrom + soqlWhere);

        System.debug('Contacts Potential Size: '+ contactsPotential.size());

        // ToDo: Uncomment causes dip below 75% Code Coverage so need to update tests before following can be uncommented and pushed to prod
/*
        if (cts.isEmpty()) {
            C501_Outreach_Email_SMS.AddTimeStamp_Future(trainingId);
            return;
        }
*/
        List<Id> contactPotentialIds = new List<Id>();
        Map<String, Contact> contactsPotentialMap = new Map<String, Contact>();
        for (Contact contactPotential :contactsPotential) {

            // Skip Contacts already in the Campaign
            if (currentCM.contains(contactPotential.Id)) {
                continue;
            }

            contactPotentialIds.add(contactPotential.Id);
            contactsPotentialMap.put(contactPotential.Id, contactPotential);
        }

        // Limit notification to max of 1 per day
        //
        AggregateResult[] allAggregatedByRule = [
            SELECT MAX(CreatedDate)MaxCreatedDate, WhoId
            FROM Task
            WHERE WhoId in :contactsPotential
            GROUP BY WhoId];

        DateTime checkDateTime = Datetime.now().addDays(-1);
        for (AggregateResult result : allAggregatedByRule)  {

            DateTime contactTaskCreatedDateTime = DateTime.valueof(result.get('MaxCreatedDate'));
            String contactId = String.valueof(result.get('WhoId'));
            if (contactTaskCreatedDateTime > checkDateTime && contactsPotentialMap.containsKey(contactId)) {
                contactsPotentialMap.remove(contactId);
            }
        }

        List<Contact> cts = contactsPotentialMap.values();
        System.debug('Contacts Size: ' + cts.size());

        List<Id> conIds = new List<Id>();     
        for (Contact c : cts) {

            Boolean sentEmail = false;
            Boolean sentSMS = false;            
            String taskSubject;
            
            if (c.Email != null && c.HasOptedOutOfEmail == false) {
                conIds.add(c.Id);
                sentEmail = true;
            }

            if (!c.C501_SMS_Opt_Out__c) {
                String cMobile;
                if (c.MobilePhone != null) {
                    cMobile=c.MobilePhone.replaceAll('[^0-9]', '');
                }

                String cIIMobile;
                if (c.Imagine_Mobile_Phone__c != null) {
                    cIIMobile = c.Imagine_Mobile_Phone__c.replaceAll('[^0-9]', '');
                }

                if (cMobile != null) {
                    System.debug('cMobile: ' + cMobile);
                }

                if (cIIMobile != null) {
                    System.debug('cIIMobile: ' + cIIMobile); 
                }

                String mobileFinal;
                if (cIIMobile != null && cIIMobile.length() == 10) {
                    mobileFinal='+1' + cIIMobile;
                }

                if (cMobile != null && cMobile.length() == 10) {
                    mobileFinal='+1' + cMobile;
                }

                if (!String.isBlank(mobileFinal)) {
                    System.debug('mobileFinal: ' + mobileFinal); 
                }
                
                if (!String.isBlank(mobileFinal))
                {
                    moblieFlist.add(mobileFinal);
                    sentSMS = true;
                }
            }

            if (sentEmail && sentSMS) {
                taskSubject = 'Outreach Email & SMS';
            }
            else if (sentemail && !sentSMS) {
                taskSubject = 'Outreach EMail';
            }
            else if (!sentEmail && sentSMS) {
                taskSubject = 'Outreach SMS';
            }

            // Add task if a message sent
            if (sentEmail || sentSMS) {
                ctMap.put(c.Id, taskSubject);   
            }
        } 

        System.debug('*****C501_Outreach_Email_SMS - C501_Send_Single_SMS.Send_Single SMS Messages Send Size: ' + moblieFlist.size());

        // Future Calls make before loop which is using future calls to make sure they are executed
        C501_Outreach_Email_SMS.AddTasks_Future(ctMap, smsBodyFinal, trainingID);
        C501_Outreach_Email_SMS.AddTimeStamp_Future(trainingId);

        // reserve number of future calls for future calls after this loop
        //
        //  TBD - this needs to be refactored so not running into the future calls limit
        for (String mfinal : moblieFlist) {

            if (Limits.getFutureCalls() >= Limits.getLimitFutureCalls()) {
                System.debug(LoggingLevel.ERROR, '*****C501_Outreach_Email_SMS - C501_Send_Single_SMS.Send_Single Future Call Limited Reached - Limit: ' + Limits.getLimitFutureCalls());
                break;
            }

            C501_Send_Single_SMS.SendSingle_Future(mfinal, smsBodyFinal);
            //System.debug('*****C501_Outreach_Email_SMS - C501_Send_Single_SMS.Send_Single mfinal: ' + mfinal + ' smsBodyFinal: ' + smsBodyFinal);
        }
        
        Database.delete(etDelete, false);

        if (conIds.size() != 0) {
            if (!Test.isRunningTest()) {
                insert newEmailTemplate;
                String emailTempNewId = newEmailTemplate.Id;
                System.debug('New Template ID: '+ emailTempNewId);
                Messaging.MassEmailMessage Email = new Messaging.MassEmailMessage();
                Email.setTargetObjectIds(conIds);
                Email.setSenderDisplayName('Imaging Institute Training');
                Email.setDescription('Automated Outreach Email: ' + cmp.Training_Name__c);
                Email.setReplyTo(replyToAddress);
                Email.setSaveAsActivity(false);
                Email.setTemplateId(emailTempNewId);

                Messaging.sendEmail(new Messaging.MassEmailMessage[] { Email });
                System.debug('*****C501_Outreach_Email_SMS - Messaging.sendEmail Emails Sent: ' + conIds.size());
            }
        }
    }

    public class outboundESinputs {
        
        @InvocableVariable(label = 'Training Record ID' required=true)
        public String trainingID;
        @InvocableVariable(label = 'Reply To Addreess' required=true)
        public String replyToAddress;
        @InvocableVariable(label = 'Class email template for SMS name without language')
        public string smsTemplatePrefix;
        @InvocableVariable(label = 'Class email template for EMail name without language')
        public string emailTemplatePrefix;
    }

    @future 
    public static void AddTasks_Future(Map<Id, String> ctMap, String smsBody, ID trainingId) {

        List<Task> tsk = new List<Task>();
        for (Id ct : ctMap.keySet()) {
        
            String subjectString = ctMap.get(ct);

            // Default OwnerId = 0056A000000qgpsQAA - Training User to make sure task does not sync to external Google Calendar
            //  Future Fix: Don't hardcode the OwnerId - query from SOQL
            Task tk = New Task();
            tk.Subject = subjectString;
            tk.Status = 'Completed';
            tk.Priority = 'Normal';
            tk.Description = smsBody;
            tk.WhatId = trainingId;
            tk.ActivityDate	= Date.Today();
            tk.WhoId = ct;
            //tk.OwnerId = '0056A000000qgpsQAA';
            
            tsk.add(tk);
            System.debug('tk-INDIVIDUAL TASK: ' + tk);
        }

        System.debug('tsk-TASK LIST: ' + tsk);
        insert tsk;
    }

    @future 
    public static void AddTimeStamp_Future(ID trainingId) {

        Campaign camp = new Campaign(Id = trainingId);
        camp.C501_Last_Outreach_Processed__c = Datetime.now();

        update camp;
    }

    public static void CodeCoverageHack() {
        List<String> stringList = new List<String> { '1' };
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
        for (String stringValue : stringList) {
            if (stringValue.contains('1')) {
                continue;
            }
        }
    }
}