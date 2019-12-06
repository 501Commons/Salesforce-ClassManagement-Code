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

global  class C501_Outreach_Batch implements Database.Batchable<sObject>, Database.AllowsCallouts { 

    global String query;
    global Database.querylocator start(Database.BatchableContext BC) {
        System.debug(LoggingLevel.DEBUG, '***** C501_Outreach_Batch::start - query: ' + query);
        return Database.getQueryLocator(query);
    }
    global void execute(Database.BatchableContext info, List<sObject> scope) {

        System.debug(LoggingLevel.DEBUG, '***** C501_Outreach_Batch::execute - scope: ' + scope);

        List<Id> campaignIds = new List<Id>();
        for (sObject scopeRecord :scope) {
            campaignIds.add(((Campaign)scopeRecord).Id);
        }

        if (campaignIds.isEmpty()) {
            String errorMessage = '***** C501_Outreach_Batch::execute - No Campaign';
            System.debug(LoggingLevel.ERROR, errorMessage);

            return;
        }

        //String campaignId = String.valueOf(campaignIds[0]);
        Imagine_Settings__c is = Imagine_Settings__c.getOrgDefaults();
        String replyemail = is.Reply_Email__c;
        String smsPrefix = is.SMS_Template_Prefix__c;
        String emailPrefix = is.Email_Template_Prefix__c;

        for(Id camp:campaignIds){
            C501_Outreach_Email_SMS.outboundESinputs outreach;
            outreach = new C501_Outreach_Email_SMS.outboundESinputs();
            outreach.trainingID = camp;
            outreach.replyToAddress = replyemail;
            outreach.smsTemplatePrefix = smsPrefix;
            outreach.emailTemplatePrefix = emailPrefix;
            
            C501_Outreach_Email_SMS.doThing(
                new List<C501_Outreach_Email_SMS.outboundESinputs>{ outreach }      
            );
        }
    }

    global void finish(Database.BatchableContext info) {
    }

    
}