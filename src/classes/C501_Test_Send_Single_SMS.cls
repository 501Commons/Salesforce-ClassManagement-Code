@IsTest (SeeAllData=false) 
public with sharing class C501_Test_Send_Single_SMS {
@testSetup
static void C501_Send_Single_SMS() 
{
   test.startTest();
    test.stopTest();
}
static testMethod void test_callSMSService_UseCase1(){
    TwilioConfig__c tc = new TwilioConfig__c();
            tc.Name = 'default';
            tc.AccountSid__c = 'xxxxx';
            tc.AuthToken__c = 'xxxxx';
            tc.messServiceID__c = 'xxxxx';
            tc.fromNumber__c = '2065551212';
            insert tc;
    
    C501_Send_Single_SMS.SendSingle_Future('2064840462','Test Messge');
 }
static testMethod void test_callSMSService_UseCase2(){
    TwilioConfig__c tc = new TwilioConfig__c();
            tc.Name = 'default';
            tc.AccountSid__c = 'xxxxx';
            tc.AuthToken__c = 'xxxxx';
            tc.messServiceID__c = 'xxxxx';
            tc.fromNumber__c = '2065551212';
            insert tc;

     C501_Twilio_Outbound.TwilioOutboundInput outreach;
            outreach = new C501_Twilio_Outbound.TwilioOutboundInput();
            outreach.contactId = '';
            outreach.contactMphone = '2064840462';
            outreach.message = 'Test';
            
            
            C501_Twilio_Outbound.doThing(
                
                new List<C501_Twilio_Outbound.TwilioOutboundInput>{ outreach }      
            );
 }
}