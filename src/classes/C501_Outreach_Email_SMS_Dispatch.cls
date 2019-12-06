public with sharing class C501_Outreach_Email_SMS_Dispatch {
    @InvocableMethod(
        label = 'Outreach Automation Dispatch'
        description = 'Receives input of campaign ID from Mass Action Scheduler and dispatches to Outreach Automation'
    )
    public static void C501_Outreach_Run( List<ID> campaigns ) {
        
      Imagine_Settings__c is = Imagine_Settings__c.getOrgDefaults();
        String replyemail = is.Reply_Email__c;
        String smsPrefix = is.SMS_Template_Prefix__c;
        String emailPrefix = is.Email_Template_Prefix__c;

        for(ID camp:campaigns){
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

   // public class dispatchInput {

    //    @InvocableVariable(
    //        label = 'Campagin ID'
    //    )
    //    public ID campaignId;

        /* other invocable variables defined here */

  //  }
}