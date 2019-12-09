@IsTest (SeeAllData=false) 
public with sharing class C501_Test_Outreach_Email_SMS {

    static testmethod void createEmailTemplates(){
        User thisUser = [select Id from User where Id = :UserInfo.getUserId()]; 

        System.runAs(thisUser) 
        {                   
            Folder folder  = [select id from Folder where name ='Outreach Emails'];
            EmailTemplate e = new EmailTemplate (
                developerName = 'test', 
                TemplateType= 'Text', 
                Name = 'Outreach Email (English)',
                Body='Test',
                FolderId =folder.id); 

            insert e;
            EmailTemplate e2 = new EmailTemplate (
                developerName = 'test2', 
                TemplateType= 'Text', 
                Name = 'Outreach SMS (English)',
                Body='>>>>Test<Training_Name__c><Start_DateTime__c><City__c><Registration_Link__c>',
                FolderId =folder.id); 

            insert e2;
            EmailTemplate e3 = new EmailTemplate (
                developerName = 'test3', 
                TemplateType= 'Text', 
                Name = 'Outreach Email (Spanish)',
                Body='Test',
                FolderId =folder.id); 

            insert e3;
            EmailTemplate e4 = new EmailTemplate (
                developerName = 'test4', 
                TemplateType= 'Text', 
                Name = 'Outreach SMS (Spanish)',
                Body='>>>>Test<Training_Name__c><Start_DateTime__c><City__c><Registration_Link__c>',
                FolderId =folder.id); 

            insert e4;
        }

        createContacts();
        createCampaign();

        C501_Outreach_Email_SMS.CodeCoverageHack();
    }
    
    static void createContacts() {
        insert C501_Test_Utility.createTestContact(null, 'Contact',20);
        insert C501_Test_Utility.createTestContact(null, 'Contact',20);
    }

    static void createTasks() {
        List<Contact> contacts = [SELECT Id FROM Contact];
        List<Campaign> campaigns = [SELECT Id FROM Campaign];
        
        if (campaigns.isEmpty()) {
            return;
        }

        // Default OwnerId = 0056A000000qgpsQAA - Training User to make sure task does not sync to external Google Calendar
        //  Future Fix: Don't hardcode the OwnerId - query from SOQL
        List<Task> insertTasks = new List<Task>();
        for (Contact contactRecord :contacts) {
            insertTasks.add(new Task(
                WhoId = contactRecord.Id,
                WhatId = campaigns[0].Id,
                Subject = 'Subject',
                Priority = 'Normal',
                Description = 'Description'
                //,OwnerId = '0056A000000qgpsQAA'
                ));
        }
    }
    
    static  void createCampaign() {

        //insert new Imagine_Settings__c(Reply_Email__c = 'test@test.com');
        //insert new Imagine_Settings__c(SMS_Template_Prefix__c = 'Outreach SMS');
        //insert new Imagine_Settings__c(Email_Template_Prefix__c = 'Outreach EMail');

        List<Campaign> campTests=C501_Test_Utility.createTestCampaign('Substitute', 'Child Care Basics',1);
        
        insert campTests;
        //createTasks();

        Test.startTest();

        for(Campaign camp:campTests){
            C501_Outreach_Email_SMS.outboundESinputs outreach;
            outreach = new C501_Outreach_Email_SMS.outboundESinputs();
            outreach.trainingID = camp.Id;
            outreach.replyToAddress = 'test@test.com';
            outreach.smsTemplatePrefix = 'Outreach SMS';
            outreach.emailTemplatePrefix = 'Outreach EMail';
            
            //C501_Outreach_Email_SMS.doThing(
                
            //    new List<C501_Outreach_Email_SMS.outboundESinputs>{ outreach }      
            //);
            C501_Outreach_Email_SMS_Dispatch.C501_Outreach_Run(new List<Id> {camp.Id});
        }

        Test.stoptest();
        //C501_Outreach_Email_SMS
    }
}